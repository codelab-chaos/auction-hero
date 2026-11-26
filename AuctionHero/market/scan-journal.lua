-- Scan journal: every full scan after the first, and every live check, kept as
-- the change from the state before it. The saved scan is the newest state;
-- walking the changes back from it rebuilds any earlier scan exactly.
--
-- A listing is one line of a scan: which item variant, how many in each
-- auction, the starting bid, the buyout, the current bid and the time left
-- band. A change says, per listing, how many auctions of it came (+) or
-- went (-). A listing whose time left ticked down to the next band went
-- from one band and came in the next.
--
-- Kept in ns.db.scanJournal:
--   place     the market the journal is of; another market starts it again
--   variants  the item variants the changes point to, each a copy of a
--             scan's variant entry (name, icon, ..., itemID, link)
--   deltas    oldest first, each:
--     kind      "scan" (a full scan) or "patch" (a live check of one item)
--     time      when the state after the change was seen
--     from      when the state before it was seen (scans only)
--     itemID    the item a patch is of
--     bands     the time left bands the state before it was read with
--     auctions  auctions in the state after it (scans only)
--     size      how many listings changed
--     changes   "variant:count:minBid:buyout:bid:band=+n;..." packed in one string
local _, ns = ...
local Bus = ns.Bus

local ScanJournal = {}
ns.ScanJournal = ScanJournal

local SOURCE = "replicate"
local SECONDS_PER_DAY = 86400

local pending -- { old, new }: a scan replaced and not yet journaled
local byIdentity -- identity -> variant number, for the journal in hand

local function Journal()
	local journal = ns.db.scanJournal
	if not journal then
		journal = { variants = {}, deltas = {} }
		ns.db.scanJournal = journal
		byIdentity = nil
	end
	return journal
end

function ScanJournal:Days()
	local days = ns.db.journalDays
	if days == nil then
		return ns.JournalRule.defaultDays
	end
	return days
end

function ScanJournal:SetDays(days)
	ns.db.journalDays = math.max(0, math.floor(days))
	if ns.db.journalDays == 0 then
		self:Clear()
	else
		self:Trim(GetServerTime())
	end
	return ns.db.journalDays
end

function ScanJournal:IsOn()
	return self:Days() > 0
end

function ScanJournal:Clear()
	ns.db.scanJournal = nil
	byIdentity = nil
end

-- ========= Listings =========================================================
-- Where a listing's parts sit in a scan's rows and variant entries.
local function Reader(snapshot)
	local schema = ns.Schemas[snapshot.meta.schema]
	local index = schema and schema.index
	if not index or not index.variant or not snapshot.variants then
		return nil
	end
	return {
		variant = index.variant, count = index.count, minBid = index.minBid, buyout = index.buyoutPrice,
		bid = index.bidAmount, band = index.timeLeft, copies = index.copies,
	}
end

-- The positions of a variant entry's fields, from the scan schema.
local VARIANT = {}
for _, field in ipairs(ns.Schemas.listings.fields) do
	if field.variant then
		VARIANT[field.id] = field.variant
	end
end
ScanJournal.VARIANT = VARIANT

local function Identity(entry)
	local link = entry[VARIANT.link]
	if link and link ~= "" then
		return link
	end
	return tostring(entry[VARIANT.itemID]) .. ":" .. tostring(entry[VARIANT.name] or "")
end

-- The journal's number for a scan's variant entry, adding it when new.
local function VariantNumber(journal, entry)
	if not byIdentity then
		byIdentity = {}
		for number, known in ipairs(journal.variants) do
			byIdentity[Identity(known)] = number
		end
	end
	local identity = Identity(entry)
	local number = byIdentity[identity]
	if not number then
		local copy = {}
		for place, value in pairs(entry) do
			copy[place] = value
		end
		journal.variants[#journal.variants + 1] = copy
		number = #journal.variants
		byIdentity[identity] = number
	end
	return number
end

-- Adds rows to a tally of listing -> auctions, each counted `sign` times.
local function Tally(journal, snapshot, rows, sign, counts)
	local at = Reader(snapshot)
	if not at then
		return counts
	end
	local variants = snapshot.variants
	for count, row in ipairs(rows) do
		local entry = variants[row[at.variant]]
		if entry then
			local key = VariantNumber(journal, entry) .. ":" .. (row[at.count] or 0) .. ":" .. (row[at.minBid] or 0) .. ":"
				.. (row[at.buyout] or 0) .. ":" .. (row[at.bid] or 0) .. ":" .. (row[at.band] or 0)
			counts[key] = (counts[key] or 0) + sign * (at.copies and row[at.copies] or 1)
		end
		if count % 500 == 0 then
			ns.Breathe()
		end
	end
	return counts
end

-- The changes as one string, and how many listings changed.
local function Pack(counts)
	local parts = {}
	for key, change in pairs(counts) do
		if change ~= 0 then
			parts[#parts + 1] = key .. "=" .. change
		end
	end
	return table.concat(parts, ";"), #parts
end

-- A packed change as a table: listing -> auctions that came (+) or went (-).
function ScanJournal.Unpack(changes)
	local counts = {}
	for key, change in (changes or ""):gmatch("([^;=]+)=(%-?%d+)") do
		counts[key] = tonumber(change)
	end
	return counts
end

-- A listing key's parts: variant number, count, minBid, buyout, bid, band.
function ScanJournal.Parts(key)
	local variant, count, minBid, buyout, bid, band = key:match("^(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)$")
	return tonumber(variant), tonumber(count), tonumber(minBid), tonumber(buyout), tonumber(bid), tonumber(band)
end

function ScanJournal:Variant(number)
	local journal = ns.db.scanJournal
	return journal and journal.variants[number]
end

-- ========= Recording ========================================================
local function Append(journal, delta)
	journal.deltas[#journal.deltas + 1] = delta
end

-- Journals the scan that replaced the one before it, when one is waiting.
-- Runs inside a job. Returns the new change, its counts and the scan before,
-- or nil
-- when there was nothing to compare (the first scan, another market, or the
-- journal is off).
function ScanJournal:RecordScan(snapshot)
	local waiting = pending
	if not waiting or waiting.new ~= snapshot then
		return nil
	end
	pending = nil
	if not self:IsOn() then
		self:Clear()
		return nil
	end
	local old, new = waiting.old, waiting.new
	local journal = Journal()
	if not old or old.meta.place ~= new.meta.place or not Reader(old) or not Reader(new) or (old.meta.time or 0) >= (new.meta.time or 0) then
		-- Nothing to compare with: the journal starts again from this scan.
		self:Clear()
		Journal().place = new.meta.place
		return nil
	end
	if journal.place ~= new.meta.place then
		self:Clear()
		journal = Journal()
		journal.place = new.meta.place
	end
	local counts = Tally(journal, old, old.rows, -1, {})
	Tally(journal, new, new.rows, 1, counts)
	local changes, size = Pack(counts)
	local delta = {
		kind = "scan",
		time = new.meta.time,
		from = old.meta.time,
		bands = old.meta.timeLeftBands,
		auctions = ns.AuctionCount(new),
		before = ns.AuctionCount(old),
		patched = old.meta.patched,
		size = size,
		changes = changes,
	}
	Append(journal, delta)
	self:Trim(new.meta.time)
	return delta, counts, old
end

Bus:On("SNAPSHOT_REPLACED", function(source, old, new)
	if source == SOURCE then
		pending = { old = old, new = new }
	end
end)

-- A live check swapped one item's rows: the journal follows, so the saved
-- scan stays the end of the chain.
Bus:On("SNAPSHOT_PATCHED", function(source, snapshot, removed, added, time, itemID)
	local journal = ns.db.scanJournal
	if source ~= SOURCE or not journal or not ScanJournal:IsOn() or journal.place ~= snapshot.meta.place then
		return
	end
	local counts = Tally(journal, snapshot, removed, -1, {})
	Tally(journal, snapshot, added, 1, counts)
	local changes, size = Pack(counts)
	if size > 0 then
		Append(journal, { kind = "patch", time = time, itemID = itemID, size = size, changes = changes })
	end
end)

-- ========= Keeping it in bounds =============================================
-- Drops changes older than the days kept, and the variants nothing points to
-- any more. The oldest go first, so the chain back from the saved scan holds.
-- Keeps the changes from `first` on, and the variants they point to.
local function KeepFrom(journal, first)
	local kept = {}
	for index = first, #journal.deltas do
		kept[#kept + 1] = journal.deltas[index]
	end
	-- Number the variants still used again, from 1.
	local renumber, variants = {}, {}
	for _, delta in ipairs(kept) do
		delta.changes = delta.changes:gsub("([^;]+)", function(entry)
			local number, rest = entry:match("^(%d+)(.*)$")
			number = tonumber(number)
			if not renumber[number] then
				variants[#variants + 1] = journal.variants[number]
				renumber[number] = #variants
			end
			return renumber[number] .. rest
		end)
		ns.Breathe()
	end
	journal.deltas, journal.variants = kept, variants
	byIdentity = nil
end

function ScanJournal:Trim(now)
	local journal = ns.db.scanJournal
	if not journal then
		return
	end
	local oldest = now - self:Days() * SECONDS_PER_DAY
	local first = 1
	while journal.deltas[first] and journal.deltas[first].time < oldest do
		first = first + 1
	end
	if first > 1 then
		KeepFrom(journal, first)
	end
end

-- When the saved data is too much to save (ns.SavedRule): the older half of
-- the changes goes, and with the last of them the journal itself.
ns.Saved.purgers.journal = function(db)
	local journal = db.scanJournal
	if not journal then
		return false
	end
	local count = #(journal.deltas or {})
	if count <= 1 then
		db.scanJournal = nil
		byIdentity = nil
		return true
	end
	KeepFrom(journal, math.floor(count / 2) + 1)
	return true
end

-- The market was kept under another name: its journal is this one's.
Bus:On("PLACE_RENAMED", function(from, to)
	local journal = ns.db.scanJournal
	if journal and journal.place == from then
		journal.place = to
	end
end)

-- ========= Reading it back ==================================================
-- How many changes are kept (scans, and deltas counting live checks), how far
-- back they reach (seconds), how many listing changes they hold in all, the
-- bytes of their packed text, and how many item variants they point to.
function ScanJournal:Stats()
	local journal = ns.db.scanJournal
	local deltas = journal and journal.deltas or {}
	local scans, size, bytes = 0, 0, 0
	for _, delta in ipairs(deltas) do
		size = size + (delta.size or 0)
		bytes = bytes + #(delta.changes or "")
		if delta.kind == "scan" then
			scans = scans + 1
		end
	end
	local first, last = deltas[1], deltas[#deltas]
	return {
		scans = scans, changes = size, deltas = #deltas, bytes = bytes,
		variants = journal and #journal.variants or 0,
		reach = first and last and (last.time - (first.from or first.time)) or 0,
	}
end

-- The saved scan walked back `back` changes: listing -> auctions. Back 0 is
-- the saved scan itself.
function ScanJournal:Rebuild(back)
	local journal = ns.db.scanJournal
	local snapshot = ns.Store:GetSourceSnapshot(SOURCE)
	if not journal or not snapshot or back > #journal.deltas then
		return nil
	end
	local counts = Tally(journal, snapshot, snapshot.rows, 1, {})
	for index = #journal.deltas, #journal.deltas - back + 1, -1 do
		for key, change in pairs(ScanJournal.Unpack(journal.deltas[index].changes)) do
			local left = (counts[key] or 0) - change
			counts[key] = left ~= 0 and left or nil
		end
		ns.Breathe()
	end
	return counts
end

-- A scan's listings as the journal counts them, for comparing with a rebuild.
function ScanJournal:Listings(snapshot)
	local counts = Tally(Journal(), snapshot, snapshot.rows, 1, {})
	for key, copies in pairs(counts) do
		if copies == 0 then
			counts[key] = nil
		end
	end
	return counts
end

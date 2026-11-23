-- Turnover: what likely happened to each item's auctions between two scans,
-- read from the scan journal's change between them.
--
-- An auction that is gone sold, was taken down by its seller, or ran out of
-- time. None of that is told, so each is a likelihood (ns.TurnoverRule):
-- the scan before said which time left band it was in, and the share of
-- that band the time between the scans reaches past is the chance it ran
-- out. Of the rest, a small share was taken down, more when the same stack
-- was just posted again; the remainder sold.
local _, ns = ...

local Turnover = {}
ns.Turnover = Turnover

local VARIANT = ns.ScanJournal.VARIANT

local function HistoryKey(entry)
	local itemID, name = entry and entry[VARIANT.itemID], entry and entry[VARIANT.name]
	if itemID and name and name ~= "" then
		return itemID .. ":" .. name
	end
end

-- When each item in the scan before was last seen: the scan's time, or a
-- live check's after it.
local function SeenTimes(delta)
	local seen = {}
	for _, entry in ipairs(delta.patched or {}) do
		seen[entry.id] = math.max(seen[entry.id] or 0, entry.time or 0)
	end
	return seen
end

-- The chance an auction in a band ran out within `elapsed` seconds.
local function RanOut(bands, band, elapsed)
	local range = bands[tostring(band)]
	if not range then
		return 1
	end
	if range.max <= range.min then
		return elapsed >= range.min and 1 or 0
	end
	return math.max(0, math.min(1, (elapsed - range.min) / (range.max - range.min)))
end

-- The longest band a scan reads: a fresh post sits in it.
local function LongestBand(bands)
	local longest = 0
	for band in pairs(bands) do
		longest = math.max(longest, tonumber(band) or 0)
	end
	return longest
end

-- Per history key, from one journaled scan, in units (fractions, being
-- likelihoods):
--   sold     likely bought, or ran out with a bid on it
--   expired  likely ran out unsold
--   pulled   likely taken down by the seller
--   watched  minutes the item was watched for (the time between the scans)
--   top      the highest unit price among auctions more likely sold than not
-- Nil when the scan looks cut short (ns.JournalRule.minScanShare).
function Turnover:Read(delta, counts, old)
	if not delta or delta.kind ~= "scan" then
		return nil
	end
	if (delta.auctions or 0) < (delta.before or 0) * ns.JournalRule.minScanShare then
		return nil
	end
	local rule = ns.TurnoverRule
	local bands = delta.bands or ns.Assumptions.timeLeftBands
	local fresh = LongestBand(bands)
	local seen = SeenTimes(delta)
	local function Elapsed(itemID)
		return delta.time - math.max(delta.from, seen[itemID] or 0)
	end

	-- Listings grouped by auction (variant, count, starting bid, buyout): the
	-- band and the bid change while the auction stays.
	local groups, reposted = {}, {}
	local done = 0
	for key, change in pairs(counts) do
		local variant, count, minBid, buyout, bid, band = ns.ScanJournal.Parts(key)
		if variant then
			local id = variant .. ":" .. count .. ":" .. minBid .. ":" .. buyout
			local group = groups[id]
			if not group then
				group = { variant = variant, count = count, buyout = buyout, net = 0, removed = {} }
				groups[id] = group
			end
			group.net = group.net + change
			if change < 0 then
				group.removed[#group.removed + 1] = { band = band, bid = bid, copies = -change }
			elseif band == fresh then
				group.posted = true
			end
		end
		done = done + 1
		if done % 500 == 0 then
			ns.Breathe()
		end
	end
	-- Stacks of an item and size freshly posted in the gap, at a new price.
	for _, group in pairs(groups) do
		if group.posted and group.net > 0 then
			reposted[group.variant .. ":" .. group.count] = true
		end
	end

	local facts = {}
	local function Fact(key)
		local fact = facts[key]
		if not fact then
			fact = { sold = 0, expired = 0, pulled = 0, watched = 0 }
			facts[key] = fact
		end
		return fact
	end
	done = 0
	for _, group in pairs(groups) do
		local entry = group.net < 0 and ns.ScanJournal:Variant(group.variant)
		local key = entry and HistoryKey(entry)
		if key then
			local elapsed = Elapsed(entry[VARIANT.itemID])
			-- Which of the removed auctions are the gone ones is not known (the
			-- rest moved to a shorter band). The likeliest to have run out are
			-- taken first, so sold is never overcounted.
			for _, removed in ipairs(group.removed) do
				removed.ranOut = RanOut(bands, removed.band, elapsed)
			end
			table.sort(group.removed, function(a, b)
				return a.ranOut > b.ranOut
			end)
			local pull = reposted[group.variant .. ":" .. group.count] and rule.repostPullShare or rule.pullShare
			local left = -group.net
			local sold, expired, pulled = 0, 0, 0
			for _, removed in ipairs(group.removed) do
				local copies = math.min(left, removed.copies)
				left = left - copies
				local out = group.buyout > 0 and removed.ranOut or 1 -- no buyout: it can only run out
				local taken = copies * (1 - out)
				if removed.bid > 0 then
					sold = sold + copies * out -- ran out with a bid: the bidder won it
				else
					expired = expired + copies * out
				end
				sold = sold + taken * (1 - pull)
				pulled = pulled + taken * pull
				if left == 0 then
					break
				end
			end
			local fact = Fact(key)
			fact.sold = fact.sold + sold * group.count
			fact.expired = fact.expired + expired * group.count
			fact.pulled = fact.pulled + pulled * group.count
			if group.buyout > 0 and sold > (expired + pulled) then
				fact.top = math.max(fact.top or 0, math.floor(group.buyout / group.count))
			end
		end
		done = done + 1
		if done % 500 == 0 then
			ns.Breathe()
		end
	end

	-- Every item the scan before had was watched, sold or not.
	for count, entry in ipairs(old and old.variants or {}) do
		local key = HistoryKey(entry)
		if key then
			local fact = Fact(key)
			fact.watched = math.max(fact.watched, math.floor(Elapsed(entry[VARIANT.itemID]) / 60))
		end
		if count % 500 == 0 then
			ns.Breathe()
		end
	end
	return facts
end

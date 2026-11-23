-- Turnover: what likely happened to each item's auctions between two scans,
-- read from the scan journal's change between them.
--
-- An auction that is gone sold, was taken down by its seller, or ran out of
-- time. None of that is told, so each is a likelihood, worked out by
-- market\sale-odds.lua from its time left band and its item's sale rate over
-- the gap (how many of the item's auctions that could not have run out
-- vanished anyway). Of those taken rather than run out, a small share was
-- taken down, more when the same stack was just posted again (ns.TurnoverRule).
local _, ns = ...

local Turnover = {}
ns.Turnover = Turnover

local VARIANT = ns.ScanJournal.VARIANT
local SaleOdds = ns.SaleOdds

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

	-- Which of a group's removed auctions are the ones gone is not known (the
	-- rest moved to a shorter band); the likeliest to have run out are taken
	-- first, so sold is never overcounted. Each gone auction is kept with the
	-- item it is of, and the item counts its buyable gone ones by band.
	local gone, goneByBand = {}, {}
	done = 0
	for _, group in pairs(groups) do
		local entry = group.net < 0 and ns.ScanJournal:Variant(group.variant)
		local key = entry and HistoryKey(entry)
		if key then
			local elapsed = Elapsed(entry[VARIANT.itemID])
			for _, removed in ipairs(group.removed) do
				removed.ranOut = SaleOdds.RanOut(bands, removed.band, elapsed)
			end
			table.sort(group.removed, function(a, b)
				return a.ranOut > b.ranOut
			end)
			local left = -group.net
			for _, removed in ipairs(group.removed) do
				local copies = math.min(left, removed.copies)
				left = left - copies
				if copies > 0 then
					gone[#gone + 1] = { key = key, group = group, copies = copies, ranOut = removed.ranOut, bid = removed.bid, range = bands[tostring(removed.band)], elapsed = elapsed }
					if group.buyout > 0 then
						local byBand = goneByBand[key] or {}
						goneByBand[key] = byBand
						byBand[removed.band] = (byBand[removed.band] or 0) + copies
					end
				end
				if left == 0 then
					break
				end
			end
		end
		done = done + 1
		if done % 500 == 0 then
			ns.Breathe()
		end
	end

	-- Each item's buyable auctions in the scan before, by band: what its sale
	-- rate is measured against.
	local startByBand, elapsedOf = {}, {}
	local get = old and ns.RowReader(old)
	for count, row in ipairs(old and old.rows or {}) do
		if (get(row, "buyoutPrice") or 0) > 0 then
			local itemID, name = get(row, "itemID"), get(row, "name")
			if itemID and name and name ~= "" then
				local key = itemID .. ":" .. name
				local band = get(row, "timeLeft")
				local byBand = startByBand[key] or {}
				startByBand[key] = byBand
				byBand[band] = (byBand[band] or 0) + (get(row, "copies") or 1)
				elapsedOf[key] = Elapsed(itemID)
			end
		end
		if count % 500 == 0 then
			ns.Breathe()
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
	-- Each item's sale rate over the gap, false when it cannot be measured.
	local rates = {}
	local function RateOf(key)
		if rates[key] == nil then
			local observed = {}
			for band, start in pairs(startByBand[key] or {}) do
				observed[#observed + 1] = {
					ranOut = SaleOdds.RanOut(bands, band, elapsedOf[key]),
					start = start,
					gone = goneByBand[key] and goneByBand[key][band] or 0,
				}
			end
			rates[key] = SaleOdds.SaleRate(observed, rule) or false
		end
		return rates[key]
	end
	-- An item with an auction that could have run out, and no rate to weigh
	-- it by, is not counted for this gap at all: not as sold, not
	-- as unsold, and not as watched. A blank is better than a guess.
	local unknown = {}
	for _, item in ipairs(gone) do
		if item.ranOut > 0 and item.group.buyout > 0 and item.bid == 0 and not RateOf(item.key) then
			unknown[item.key] = true
		end
	end
	for index, item in ipairs(gone) do
		if not unknown[item.key] then
			local group = item.group
			local pull = reposted[group.variant .. ":" .. group.count] and rule.repostPullShare or rule.pullShare
			local sold, expired, pulled = SaleOdds.Split(item.range, item.elapsed, RateOf(item.key) or 0, pull, item.bid > 0, group.buyout > 0)
			local fact = Fact(item.key)
			local units = item.copies * group.count
			fact.sold = fact.sold + sold * units
			fact.expired = fact.expired + expired * units
			fact.pulled = fact.pulled + pulled * units
			if group.buyout > 0 and sold > expired + pulled then
				fact.top = math.max(fact.top or 0, math.floor(group.buyout / group.count))
			end
		end
		if index % 500 == 0 then
			ns.Breathe()
		end
	end

	-- Every item the scan before had was watched, sold or not, except one
	-- left unknown for this gap.
	for count, entry in ipairs(old and old.variants or {}) do
		local key = HistoryKey(entry)
		if key and not unknown[key] then
			local fact = Fact(key)
			fact.watched = math.max(fact.watched, math.floor(Elapsed(entry[VARIANT.itemID]) / 60))
		end
		if count % 500 == 0 then
			ns.Breathe()
		end
	end
	return facts
end

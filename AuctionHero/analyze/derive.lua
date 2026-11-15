-- Derive: turns a snapshot's rows into per-item numbers and market totals.
-- It reads rows only through the source's "listing" map (data\sources.lua),
-- so it never names a schema field itself.
--
-- Returns:
--   items    array of per-item tables (see NewItem)
--   totals   market-wide numbers, keyed as data\summary.lua expects
--   groups   group id -> { total = n, entries = { { key = k, count = n }, ... } }
local _, ns = ...

local Derive = {}
ns.Derive = Derive

-- ========= Classifiers ======================================================
-- Each takes a listing and returns the key it is counted under, for the
-- breakdowns listed in ns.SummaryGroups.
local function StackBucket(quantity)
	for position, upper in ipairs(ns.StackBuckets) do
		if quantity <= upper then
			return position
		end
	end
	return #ns.StackBuckets + 1
end

local Classifiers = {
	quality = function(listing)
		return listing.quality
	end,
	timeLeft = function(listing)
		return listing.timeLeft
	end,
	owner = function(listing)
		return listing.owner
	end,
	stack = function(listing)
		return StackBucket(listing.quantity)
	end,
	linkType = function(listing)
		return listing.linkType
	end,
	kind = function(listing)
		return listing.kind
	end,
}

-- ========= Reading rows =====================================================
-- Builds a function that fills one reusable listing table from a row.
-- at names the field that feeds each part of a listing, and get reads a field
-- of a row wherever it is kept (see ns.RowReader).
local function ListingReader(source, get)
	local at = source.listing
	local parse = ns.Links.Parse
	local listing = {}

	return function(row)
		local quantity = get(row, at.quantity) or 1
		if quantity < 1 then
			quantity = 1
		end
		local link = at.link and get(row, at.link)
		local parsed = parse(link)
		local buyout = get(row, at.buyout) or 0

		local name = get(row, at.name)
		if name == "" then
			name = nil -- the row's data had not arrived
		end
		listing.itemID = get(row, at.itemID)
		listing.suffix = (at.suffix and get(row, at.suffix)) or parsed.suffix or 0
		listing.name = name
		listing.quality = get(row, at.quality)
		listing.quantity = quantity
		-- A row may stand for several identical auctions.
		listing.copies = at.copies and get(row, at.copies) or 1
		listing.buyout = buyout
		listing.unit = buyout > 0 and (source.priceIsPerStack and buyout / quantity or buyout) or nil
		listing.value = source.priceIsPerStack and buyout or buyout * quantity
		listing.bid = at.bid and get(row, at.bid) or 0
		listing.owner = at.owner and get(row, at.owner)
		listing.timeLeft = at.timeLeft and get(row, at.timeLeft)
		listing.link = link
		listing.linkType = parsed.type
		if at.isCommodity then
			listing.kind = (get(row, at.isPet) and "pet")
				or (get(row, at.isCommodity) and "commodity")
				or (get(row, at.isEquipment) and "equipment")
				or "other"
		end
		-- What tells this variant of the item id apart from the others, if anything.
		local variant = listing[source.variantBy]
		if variant == nil then
			listing.key = listing.itemID .. ":?" -- not loaded, kept apart from the known ones
		elseif variant == 0 then
			listing.key = tostring(listing.itemID)
		else
			listing.key = listing.itemID .. ":" .. variant
		end
		return listing
	end
end

-- ========= Items ============================================================
local function NewItem(key, listing)
	return {
		key = key,
		itemID = listing.itemID,
		suffix = listing.suffix,
		name = listing.name,
		quality = listing.quality,
		link = listing.link,
		kind = listing.kind,
		listings = 0, -- rows for this item
		quantity = 0, -- units for sale
		sellers = 0, -- distinct owners
		value = 0, -- sum of buyouts
		bidOnly = 0, -- rows without a buyout
		rows = {}, -- positions of its rows in the snapshot
		-- minUnit, medianUnit, maxUnit and deal are set by FinishItem
		prices = {}, -- unit price of each row that has a buyout (dropped when finished)
		weights = {}, -- units of each such row (dropped when finished)
		owners = {}, -- owner -> true (dropped when finished)
	}
end

-- Median unit price weighted by units, so one big cheap stack counts for more
-- than one overpriced single.
local function WeightedMedian(prices, weights, order)
	local total = 0
	for _, position in ipairs(order) do
		total = total + weights[position]
	end
	local half, running = total / 2, 0
	for _, position in ipairs(order) do
		running = running + weights[position]
		if running >= half then
			return prices[position]
		end
	end
end

local function FinishItem(item)
	local prices = item.prices
	local count = #prices
	if count > 0 then
		local order = {}
		for position = 1, count do
			order[position] = position
		end
		table.sort(order, function(a, b)
			return prices[a] < prices[b]
		end)
		item.minUnit = math.floor(prices[order[1]])
		item.maxUnit = math.floor(prices[order[count]])
		item.medianUnit = math.floor(WeightedMedian(prices, item.weights, order))
		-- Different prices, not auctions: identical auctions are one seller.
		local different = 0
		for position = 1, count do
			if position == 1 or prices[order[position]] ~= prices[order[position - 1]] then
				different = different + 1
			end
		end
		if different >= ns.DealBadgeRule.minPrices and item.medianUnit > 0 then
			item.deal = math.floor((item.medianUnit - item.minUnit) / item.medianUnit * 100)
		end
	end
	item.prices, item.weights, item.owners = nil, nil, nil
end

-- ========= Groups ===========================================================
local function CountInto(counts, key, times)
	if key == nil then
		key = false -- shown as "Unknown"
	end
	counts[key] = (counts[key] or 0) + (times or 1)
end

local function SortKey(value)
	-- false (unknown) sorts last, numbers before strings.
	if value == false then
		return 2, 0
	elseif type(value) == "number" then
		return 0, value
	end
	return 1, tostring(value)
end

local function FinishGroup(definition, counts)
	local entries, total = {}, 0
	for key, count in pairs(counts) do
		entries[#entries + 1] = { key = key, count = count }
		total = total + count
	end
	if definition.order == "key" then
		table.sort(entries, function(a, b)
			local rankA, valueA = SortKey(a.key)
			local rankB, valueB = SortKey(b.key)
			if rankA ~= rankB then
				return rankA < rankB
			end
			return valueA < valueB
		end)
	else
		table.sort(entries, function(a, b)
			if a.count ~= b.count then
				return a.count > b.count
			end
			return tostring(a.key) < tostring(b.key)
		end)
	end
	if definition.top then
		for position = #entries, definition.top + 1, -1 do
			entries[position] = nil
		end
	end
	return { total = total, entries = entries }
end

local function Applies(definition, source)
	if definition.only == "listings" then
		return not source.aggregated
	elseif definition.only == "aggregated" then
		return source.aggregated
	end
	return true
end
Derive.Applies = Applies

-- ========= Run ==============================================================
function Derive:Run(snapshot)
	local source = ns.SourceById[snapshot.meta.source]
	local read = ListingReader(source, ns.RowReader(snapshot))

	local groupDefinitions, groupCounts = {}, {}
	for _, definition in ipairs(ns.SummaryGroups) do
		if Applies(definition, source) and Classifiers[definition.by] then
			groupDefinitions[#groupDefinitions + 1] = definition
			groupCounts[definition.id] = {}
		end
	end

	local items, byKey = {}, {}
	local totals = {
		rows = ns.AuctionCount(snapshot),
		units = 0,
		value = 0,
		withBuyout = 0,
		bidOnly = 0,
		withBids = 0,
		stacked = 0,
		priceIsPerStack = source.priceIsPerStack,
	}
	local allOwners, sellerCount = {}, 0

	for position, row in ipairs(snapshot.rows) do
		local listing = read(row)
		local key = listing.key
		local item = byKey[key]
		if not item then
			item = NewItem(key, listing)
			byKey[key] = item
			items[#items + 1] = item
		end

		-- Everything below counts auctions, so a row counts once per copy.
		local copies = listing.copies
		item.listings = item.listings + copies
		item.quantity = item.quantity + listing.quantity * copies
		item.rows[#item.rows + 1] = position
		item.name = item.name or listing.name
		item.link = item.link or listing.link
		totals.units = totals.units + listing.quantity * copies

		if listing.unit then
			item.prices[#item.prices + 1] = listing.unit
			item.weights[#item.weights + 1] = listing.quantity * copies
			item.value = item.value + listing.value * copies
			totals.value = totals.value + listing.value * copies
			totals.withBuyout = totals.withBuyout + copies
		else
			item.bidOnly = item.bidOnly + copies
			totals.bidOnly = totals.bidOnly + copies
		end
		if listing.bid > 0 then
			totals.withBids = totals.withBids + copies
		end
		if listing.quantity > 1 then
			totals.stacked = totals.stacked + copies
		end

		local owner = listing.owner
		if owner then
			if not item.owners[owner] then
				item.owners[owner] = true
				item.sellers = item.sellers + 1
			end
			if not allOwners[owner] then
				allOwners[owner] = true
				sellerCount = sellerCount + 1
			end
		end

		for _, definition in ipairs(groupDefinitions) do
			CountInto(groupCounts[definition.id], Classifiers[definition.by](listing), copies)
		end

		if position % 100 == 0 then
			ns.Breathe()
		end
	end

	totals.items = #items
	totals.sellers = sellerCount
	totals.singleListing, totals.singleSeller, totals.deals = 0, 0, 0
	for position, item in ipairs(items) do
		FinishItem(item)
		if item.listings == 1 then
			totals.singleListing = totals.singleListing + 1
		end
		if item.sellers == 1 then
			totals.singleSeller = totals.singleSeller + 1
		end
		if item.deal and item.deal >= ns.DealBadgeRule.percent then
			totals.deals = totals.deals + 1
		end
		if position % 50 == 0 then
			ns.Breathe()
		end
	end

	local groups = {}
	for _, definition in ipairs(groupDefinitions) do
		local group = FinishGroup(definition, groupCounts[definition.id])
		-- A breakdown where nothing had a value says nothing, so leave it out.
		local onlyUnknown = #group.entries == 1 and group.entries[1].key == false
		if not onlyUnknown and #group.entries > 0 then
			groups[definition.id] = group
		end
	end

	return { items = items, byKey = byKey, totals = totals, groups = groups }
end

-- Market: turns a full scan into items with a price ladder. This is what the
-- trading tabs read. Pure data in, plain tables out.
--
-- An item:
--   key, itemID, name, quality, icon, link, level, levelType
--   classID, subClassID, equipLoc, commodity   (from the scan's item catalog)
--   tiers      price ladder, cheapest per unit first. A tier is every auction
--              with the same stack size, price and time left:
--              { unit, stack, buyout, copies, units, timeLeft }
--   listings   auctions, counting copies       units    units with a buyout
--   bidOnly    auctions without a buyout
--   min, median, max   unit prices. The median is weighted by units
local _, ns = ...

local Market = {}
ns.Market = Market

local function WeightedMedian(tiers, totalUnits)
	local running = 0
	for _, tier in ipairs(tiers) do
		running = running + tier.units
		if running >= totalUnits / 2 then
			return tier.unit
		end
	end
end

-- Units for sale at each different price, cheapest first: { unit, units }.
-- Worked out when first asked for and kept on the item.
function Market.PricePoints(item)
	if not item.pricePoints then
		local points = {}
		for _, tier in ipairs(item.tiers) do
			local last = points[#points]
			if last and last.unit == tier.unit then
				last.units = last.units + tier.units
			else
				points[#points + 1] = { unit = tier.unit, units = tier.units }
			end
		end
		item.pricePoints = points
	end
	return item.pricePoints
end

local function Finish(item)
	item.tierByKey = nil
	local tiers = item.tiers
	table.sort(tiers, function(a, b)
		if a.unit ~= b.unit then
			return a.unit < b.unit
		end
		return a.stack < b.stack
	end)
	-- How many different prices the item is listed at. Identical auctions are
	-- almost always one seller, so they are one opinion of the price however
	-- many of them there are. This, not the number of auctions, is how much
	-- there is to judge a price by.
	item.priceCount = 0
	for index, tier in ipairs(tiers) do
		if index == 1 or tier.unit ~= tiers[index - 1].unit then
			item.priceCount = item.priceCount + 1
		end
	end
	if #tiers > 0 then
		item.min = tiers[1].unit
		item.max = tiers[#tiers].unit
		item.median = WeightedMedian(tiers, item.units)
		-- The floor: the price reached once the cheapest few units are skipped.
		-- It is what a buyer pays for the item when a stray low listing is
		-- gone, and so what a low price is measured against. An item with too
		-- few units for sale has no floor.
		local rule = ns.BaselineRule
		local skip = math.max(rule.floorMinUnits, math.ceil(item.units * rule.floorShare))
		local running = 0
		for _, tier in ipairs(tiers) do
			running = running + tier.units
			if running >= skip then
				item.floor = tier.unit
				break
			end
		end
	end
end

-- Which field feeds each part of a listing in this snapshot, and the function
-- that reads a field of one of its rows.
local function Places(snapshot)
	local source = ns.SourceById[snapshot.meta.source]
	if not source or source.aggregated or not snapshot.rows then
		return nil
	end
	return source.listing, ns.RowReader(snapshot)
end

-- Adds one row to the items being built. A row may stand for several
-- identical auctions.
local function AddRow(items, byKey, row, at, get, catalog)
	local itemID = get(row, at.itemID)
	local name = get(row, at.name)
	if not name or name == "" then
		-- Its details never arrived. An item with one name can still be
		-- named from its id; gear could be any of its variants, so it is
		-- left out.
		name = ns.ItemNames.Fallback(itemID)
		if not name then
			return
		end
	end
	local key = itemID .. ":" .. name
	local item = byKey[key]
	if not item then
		local known = catalog[itemID] or {}
		item = {
			key = key,
			itemID = itemID,
			name = name,
			quality = get(row, at.quality),
			icon = get(row, at.icon),
			link = get(row, at.link),
			level = get(row, at.level),
			levelType = get(row, at.levelType),
			usable = get(row, "usable") == true,
			type = known.type,
			subType = known.subType,
			classID = known.classID,
			subClassID = known.subClassID,
			equipLoc = known.equipLoc,
			commodity = known.commodity,
			tiers = {},
			tierByKey = {},
			listings = 0,
			units = 0,
			bidOnly = 0,
		}
		byKey[key] = item
		items[#items + 1] = item
	end

	local stack = ns.AuctionUnits(itemID, get(row, at.quantity))
	local buyout = get(row, at.buyout) or 0
	local copies = at.copies and get(row, at.copies) or 1
	item.listings = item.listings + copies
	if buyout > 0 then
		local timeLeft = get(row, at.timeLeft) or 0
		local tierKey = stack .. ":" .. buyout .. ":" .. timeLeft
		local tier = item.tierByKey[tierKey]
		if not tier then
			tier = { unit = math.floor(buyout / stack), stack = stack, buyout = buyout, copies = 0, units = 0, timeLeft = timeLeft }
			item.tierByKey[tierKey] = tier
			item.tiers[#item.tiers + 1] = tier
		end
		tier.copies = tier.copies + copies
		tier.units = tier.units + stack * copies
		item.units = item.units + stack * copies
	else
		item.bidOnly = item.bidOnly + copies
	end
end

-- Returns { items = {...}, byKey = {...} }, or nil when the snapshot's source
-- has no individual auctions to build ladders from.
function Market:Build(snapshot)
	local at, get = Places(snapshot)
	if not at then
		return nil
	end
	local catalog = snapshot.items or {}
	local items, byKey = {}, {}

	for count, row in ipairs(snapshot.rows) do
		AddRow(items, byKey, row, at, get, catalog)
		if count % 200 == 0 then
			ns.Breathe()
		end
	end

	for count, item in ipairs(items) do
		Finish(item)
		if count % 100 == 0 then
			ns.Breathe()
		end
	end
	return { items = items, byKey = byKey, time = snapshot.meta.time, place = snapshot.meta.place, listings = ns.AuctionCount(snapshot), stale = snapshot.meta.stale }
end

-- Replaces everything a built market holds for one item id with what these
-- rows say, in place, so every tab reading the market sees it at once. The
-- rows are raw rows of the snapshot's own shape. With a name, only that
-- variant of the item is replaced ("of the Elder", not "of the Owl"); without
-- one, everything under the item id.
-- Returns the items now held for that id, each marked with checkedAt.
function Market:Patch(market, snapshot, itemID, rows, time, name)
	local at, get = Places(snapshot)
	if not at then
		return {}
	end
	local kept = {}
	for _, item in ipairs(market.items) do
		if item.itemID == itemID and (not name or item.name == name) then
			market.byKey[item.key] = nil
		else
			kept[#kept + 1] = item
		end
	end
	local fresh, byKey = {}, {}
	for _, row in ipairs(rows) do
		AddRow(fresh, byKey, row, at, get, snapshot.items or {})
	end
	for _, item in ipairs(fresh) do
		Finish(item)
		item.checkedAt = time
		kept[#kept + 1] = item
		market.byKey[item.key] = item
	end
	-- The same table is kept, so whoever holds market.items holds the new list.
	for index = #market.items, 1, -1 do
		market.items[index] = nil
	end
	for index, item in ipairs(kept) do
		market.items[index] = item
	end
	return fresh
end

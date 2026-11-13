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

local function Finish(item)
	item.tierByKey = nil
	local tiers = item.tiers
	table.sort(tiers, function(a, b)
		if a.unit ~= b.unit then
			return a.unit < b.unit
		end
		return a.stack < b.stack
	end)
	if #tiers > 0 then
		item.min = tiers[1].unit
		item.max = tiers[#tiers].unit
		item.median = WeightedMedian(tiers, item.units)
		-- How far the lowest price sits under the median, for the deal badge.
		local rule = ns.DealBadgeRule
		if item.median and item.median > 0 and (item.listings - item.bidOnly) >= rule.minListings then
			item.deal = math.floor((item.median - item.min) / item.median * 100)
		end
	end
end

-- Returns { items = {...}, byKey = {...} }, or nil when the snapshot's source
-- has no individual auctions to build ladders from.
function Market:Build(snapshot)
	local source = ns.SourceById[snapshot.meta.source]
	if not source or source.aggregated or not snapshot.rows then
		return nil
	end
	local index = ns.Schemas[snapshot.meta.schema].index
	local at = {}
	for part, fieldId in pairs(source.listing) do
		at[part] = index[fieldId]
	end
	local catalog = snapshot.items or {}
	local items, byKey = {}, {}

	for count, row in ipairs(snapshot.rows) do
		local name = row[at.name]
		-- A row whose details never arrived has no name and cannot be told
		-- apart from its item's other variants, so it is left out.
		if name and name ~= "" then
			local itemID = row[at.itemID]
			local key = itemID .. ":" .. name
			local item = byKey[key]
			if not item then
				local known = catalog[itemID] or {}
				item = {
					key = key,
					itemID = itemID,
					name = name,
					quality = row[at.quality],
					icon = row[at.icon],
					link = row[at.link],
					level = row[at.level],
					levelType = row[at.levelType],
					usable = row[index.usable] == true,
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

			local stack = math.max(1, row[at.quantity] or 1)
			local buyout = row[at.buyout] or 0
			item.listings = item.listings + 1
			if buyout > 0 then
				local timeLeft = row[at.timeLeft] or 0
				local tierKey = stack .. ":" .. buyout .. ":" .. timeLeft
				local tier = item.tierByKey[tierKey]
				if not tier then
					tier = { unit = math.floor(buyout / stack), stack = stack, buyout = buyout, copies = 0, units = 0, timeLeft = timeLeft }
					item.tierByKey[tierKey] = tier
					item.tiers[#item.tiers + 1] = tier
				end
				tier.copies = tier.copies + 1
				tier.units = tier.units + stack
				item.units = item.units + stack
			else
				item.bidOnly = item.bidOnly + 1
			end
		end
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
	return { items = items, byKey = byKey, time = snapshot.meta.time, place = snapshot.meta.place, listings = #snapshot.rows, stale = snapshot.meta.stale }
end

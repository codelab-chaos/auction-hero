-- Orders: what buying a quantity of an item would actually involve.
--
-- The game has two ways to buy, and an item only ever uses one of them:
--   Commodities (stackable goods) are bought by the unit. You ask for a
--     quantity and get exactly that, cheapest sellers first, in one purchase.
--   Everything else is bought one whole auction at a time. A stack cannot be
--     split, and every auction is its own purchase.
local _, ns = ...

local Orders = {}
ns.Orders = Orders

function Orders.IsCommodity(item)
	if item.commodity ~= nil then
		return item.commodity
	end
	return item.classID ~= nil and ns.CommodityClassIDs[item.classID] == true
end

-- Fills a quantity from the cheapest unit price up. Returns:
--   byUnit      true for a commodity
--   lines       { tier, units, auctions }: what is taken at each price
--   units       units received. For whole auctions this can exceed what was asked
--   cost, purchases, averageUnit
--   short       units asked for that the market could not supply
function Orders.Fill(item, wanted)
	local byUnit = Orders.IsCommodity(item)
	local lines = {}
	local units, cost, auctions = 0, 0, 0
	for _, tier in ipairs(item.tiers) do
		if units >= wanted then
			break
		end
		if byUnit then
			local take = math.min(tier.units, wanted - units)
			lines[#lines + 1] = { tier = tier, units = take, auctions = 0 }
			units = units + take
			cost = cost + take * tier.unit
		else
			local take = math.min(tier.copies, math.ceil((wanted - units) / tier.stack))
			lines[#lines + 1] = { tier = tier, units = take * tier.stack, auctions = take }
			units = units + take * tier.stack
			cost = cost + take * tier.buyout
			auctions = auctions + take
		end
	end
	return {
		byUnit = byUnit,
		lines = lines,
		units = units,
		cost = cost,
		purchases = units == 0 and 0 or (byUnit and 1 or auctions),
		averageUnit = units > 0 and math.floor(cost / units) or nil,
		short = math.max(0, wanted - units),
	}
end

-- The price of the cheapest single auction, for "can I afford one".
function Orders.CheapestAuction(item)
	local cheapest
	for _, tier in ipairs(item.tiers) do
		local price = Orders.IsCommodity(item) and tier.unit or tier.buyout
		if not cheapest or price < cheapest then
			cheapest = price
		end
	end
	return cheapest
end

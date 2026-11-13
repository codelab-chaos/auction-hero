-- Resell: finds items where buying the cheap end of the ladder and relisting
-- at the usual price would turn a profit, and plans the purchase.
--
-- This reads listings, not sales. A usual price can be propped up by auctions
-- that never sell, so the results are leads to check, not promises.
local _, ns = ...

local Resell = {}
ns.Resell = Resell

-- Plans a purchase for resale. params: { marginPercent, budget, minProfit }.
-- limit caps what is bought: auctions for whole-auction items, units for
-- commodities. Returns nil when there is nothing worth buying, else:
--   item, target (unit price to relist at), byUnit
--   lines { tier, auctions, units }, available (the most limit can be)
--   buyAuctions, buyUnits, cost, averageUnit, revenue, profit, roi
--   competition   units still listed at or under the target after buying
function Resell.Plan(item, params, limit)
	local target = ns.History:Usual(item)
	if not target or (item.listings - item.bidOnly) < ns.ResellMinListings then
		return nil
	end
	local byUnit = ns.Orders.IsCommodity(item)
	local ceiling = target * (1 - params.marginPercent / 100)
	limit = limit or math.huge

	local lines = {}
	local available, buyAuctions, buyUnits, cost, competition = 0, 0, 0, 0, 0
	for _, tier in ipairs(item.tiers) do
		if tier.unit > target then
			break
		end
		local worth = tier.unit <= ceiling
		if byUnit then
			local units = worth and tier.units or 0
			available = available + units
			local take = math.min(units, limit - buyUnits)
			if params.budget > 0 then
				take = math.min(take, math.floor((params.budget - cost) / tier.unit))
			end
			take = math.max(0, take)
			if take > 0 then
				lines[#lines + 1] = { tier = tier, auctions = 0, units = take }
			end
			buyUnits = buyUnits + take
			cost = cost + take * tier.unit
			competition = competition + tier.units - take
		else
			local copies = worth and tier.copies or 0
			available = available + copies
			local take = math.min(copies, limit - buyAuctions)
			if params.budget > 0 then
				take = math.min(take, math.floor((params.budget - cost) / tier.buyout))
			end
			take = math.max(0, take)
			if take > 0 then
				lines[#lines + 1] = { tier = tier, auctions = take, units = take * tier.stack }
			end
			buyAuctions = buyAuctions + take
			buyUnits = buyUnits + take * tier.stack
			cost = cost + take * tier.buyout
			competition = competition + (tier.copies - take) * tier.stack
		end
	end
	if buyUnits == 0 then
		return nil
	end

	local revenue = math.floor(buyUnits * target * (1 - ns.Assumptions.auctionCut))
	local profit = revenue - cost
	return {
		item = item,
		target = target,
		byUnit = byUnit,
		lines = lines,
		available = available,
		buyAuctions = buyAuctions,
		buyUnits = buyUnits,
		cost = cost,
		averageUnit = math.floor(cost / buyUnits),
		revenue = revenue,
		profit = profit,
		roi = math.floor(profit / cost * 100),
		competition = competition,
	}
end

-- Every item worth flipping, each planned as "buy everything cheap enough"
-- and read on the deal meter. Leads under minPips are left out.
function Resell.Leads(items, params, minPips)
	local leads = {}
	for count, item in ipairs(items) do
		local lead = Resell.Plan(item, params)
		if lead and lead.profit >= params.minProfit then
			lead.deal = ns.Signals:Deal(item, lead.buyUnits, lead.cost)
			if lead.deal.known and lead.deal.level.pips >= minPips then
				leads[#leads + 1] = lead
			end
		end
		if count % 200 == 0 then
			ns.Breathe()
		end
	end
	return leads
end

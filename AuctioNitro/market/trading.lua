-- Pure order and resell calculations. Market ladders are observations, never
-- executable orders: the trading controller rechecks the live auction house.
local _, ns = ...
local Trading = {}
ns.Trading = Trading

function Trading:Deal(item)
	local usual = ns.History:Usual(item)
	return usual and usual > 0 and item.min and math.floor((usual - item.min) / usual * 100) or 0
end

function Trading:Order(item, wanted, commodity)
	local order = { units=0, cost=0, auctions=0, lines={} }
	for _, tier in ipairs(item.tiers) do
		local left = wanted - order.units
		if left <= 0 then break end
		local copies = math.min(tier.copies, math.ceil(left / tier.stack))
		local units = commodity and math.min(left, tier.units) or copies * tier.stack
		local cost = commodity and math.ceil(units * tier.buyout / tier.stack) or copies * tier.buyout
		order.units, order.cost = order.units + units, order.cost + cost
		order.auctions = order.auctions + (commodity and 0 or copies)
		order.lines[#order.lines + 1] = { units=units, cost=cost, tier=tier }
	end
	return order
end

function Trading:Resell(item, margin, budget, limit)
	local target = ns.History:Usual(item)
	if not target or item.listings - item.bidOnly < 5 then return end
	local plan = { item=item, target=target, units=0, auctions=0, cost=0, competition=0, available=0 }
	for _, tier in ipairs(item.tiers) do
		if tier.unit > target then break end
		local take = 0
		if tier.unit <= target * (1 - margin / 100) then
			plan.available = plan.available + tier.copies
			take = math.min(tier.copies, (limit or math.huge) - plan.auctions)
			if budget and budget > 0 then take = math.min(take, math.floor((budget - plan.cost) / tier.buyout)) end
			take = math.max(0, take)
		end
		if take > 0 and not plan.first then plan.first = tier end
		plan.auctions, plan.units = plan.auctions + take, plan.units + take * tier.stack
		plan.cost = plan.cost + take * tier.buyout
		plan.competition = plan.competition + (tier.copies - take) * tier.stack
	end
	if plan.units == 0 then return end
	plan.revenue = math.floor(plan.units * target * (1 - ns.Assumptions.auctionCut))
	plan.profit = plan.revenue - plan.cost
	plan.roi = plan.cost > 0 and math.floor(plan.profit / plan.cost * 100) or 0
	return plan
end

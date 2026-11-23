-- Resell leads: a plan always takes the whole cheap load, and the settings
-- only decide which leads are shown.
local ns = Boot()
OpenAuctionHouse()
Scan()
local items = ns.Analysis.market.items
local function leads(extra)
	local params = { marginPercent = 30, budget = 0, minProfit = 0, maxItems = math.huge }
	for name, value in pairs(extra or {}) do
		params[name] = value
	end
	return ns.Resell.Leads(items, params, 1)
end

local all = leads()
checkTrue("there are leads to test with", #all > 0)
for _, lead in ipairs(all) do
	checkTrue("a plan buys something", lead.buyUnits > 0 and lead.cost > 0)
	checkTrue("a plan never buys more than is for sale", lead.buyUnits <= lead.item.units)
end

-- Max items filters by how much of the item is for sale, never trims a plan.
local smallest = math.huge
for _, lead in ipairs(all) do
	smallest = math.min(smallest, ns.Resell.MarketSize(lead.item))
end
check("a limit under every market shows nothing", #leads({ maxItems = smallest - 1 }), 0)
local some = leads({ maxItems = smallest })
checkTrue("a limit at the smallest market shows it", #some > 0)
for _, lead in ipairs(some) do
	checkTrue("shown leads fit the limit", ns.Resell.MarketSize(lead.item) <= smallest)
end

-- I can afford hides loads that cannot be bought out in full.
local cheapest = math.huge
for _, lead in ipairs(all) do
	cheapest = math.min(cheapest, lead.cost)
end
check("too little gold for any load", #leads({ budget = cheapest - 1 }), 0)
for _, lead in ipairs(leads({ budget = cheapest })) do
	check("an affordable load is not trimmed", lead.cost, cheapest)
end

-- Stackable goods count by the stack.
local ore
for _, item in ipairs(items) do
	if item.name == "Copper Ore" then
		ore = item
	end
end
checkTrue("a stackable market counts fewer than its units", ns.Resell.MarketSize(ore) < ore.units)

-- The plan's quantity buttons go dim when they cannot change the number.
ns.SetEnabled("showResell", true)
ShowTab("resell")
local row
for _, frame in ipairs(Frames(function(frame)
	return frame.data ~= nil and frame.data.item ~= nil and frame.scripts.OnMouseUp ~= nil
end)) do
	row = row or frame
end
if row then
	row.scripts.OnMouseUp(row)
	Tick(2)
	local all, plus, minus = ButtonNamed("All"), ButtonNamed("+"), ButtonNamed("-")
	checkTrue("with everything picked, All has nothing to add", all.disabled == true)
	checkTrue("and neither has plus", plus.disabled == true)
	if not minus.disabled then
		minus.scripts.OnClick(minus)
		Tick(2)
		checkTrue("after taking one off, plus works again", ButtonNamed("+").disabled ~= true)
		checkTrue("and so does All", ButtonNamed("All").disabled ~= true)
	end
end

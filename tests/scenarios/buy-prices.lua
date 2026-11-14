-- The Buy list never hides what an item is for sale at: opening an item lists
-- every price with how many are at it, and the price clicked is the one bought.
local ns = Boot()
OpenAuctionHouse()
Scan()
MONEY = 10000000
ShowTab("buy")
local market = ns.Analysis.market

local function rows()
	return Frames(function(frame)
		return frame.data ~= nil and frame.scripts.OnMouseUp ~= nil and (frame.data.key ~= nil or frame.data.item ~= nil)
	end)
end
local function click(frame)
	frame.scripts.OnMouseUp(frame)
	Tick(10)
end
local function itemRow(key)
	for _, frame in ipairs(rows()) do
		if frame.data.key == key then
			return frame
		end
	end
end
local function priceRows(key)
	local found = {}
	for _, frame in ipairs(rows()) do
		if frame.data.item and frame.data.item.key == key and frame.data.point then
			found[#found + 1] = frame
		end
	end
	return found
end

-- A single item with several prices.
local tunic = market.byKey["2006:Tunic of the Bear"]
local points = ns.Market.PricePoints(tunic)
checkTrue("the tunic is for sale at several prices", #points > 2)
check("closed, an item shows no price rows", #priceRows(tunic.key), 0)

click(itemRow(tunic.key))
local shown = priceRows(tunic.key)
checkTrue("opened, it lists its prices", #shown >= 2)
check("cheapest first", shown[1].data.point.unit, points[1].unit)
check("each with how many are at it", shown[2].data.point.units, points[2].units)
local listed = 0
for _, point in ipairs(points) do
	listed = listed + point.units
end
check("and together they are everything for sale", listed, tunic.units)

-- Clicking a price picks that price, not the cheapest.
click(shown[2])
local wantedUnit = points[2].unit
local buy = ButtonNamed("Buy at " .. strip(ns.PlainMoney(wantedUnit)))
checkTrue("the button names the price clicked", buy ~= nil)

-- And that is the price bought: the live auction at it, not a cheaper one.
MOCK.liveNames = { "Tunic of the Bear", "Tunic of the Bear" }
MOCK.livePrice = wantedUnit / 2 -- live auctions at half the price and at the price
buy.scripts.OnClick(buy)
Tick(10)
check("the live auction at that price is offered", ns.Buying.state.total, wantedUnit)
check("not the cheaper one", ns.Buying.state.auctionID, 702)
ns.Buying:Cancel()

-- If nothing is at that price any more, it says so and names the cheapest.
MOCK.livePrice = wantedUnit * 3
buy = ButtonNamed("Buy at " .. strip(ns.PlainMoney(wantedUnit)))
buy.scripts.OnClick(buy)
Tick(10)
check("a price that is gone is not swapped for another", ns.Buying.state.phase, "failed")
checkMatch("and the player is told", ns.Buying.state.message, "^None at .* any more%. The cheapest now is ")
MOCK.livePrice = nil

-- Clicking the item again closes it.
click(itemRow(tunic.key))
check("clicking the item again closes it", #priceRows(tunic.key), 0)

-- Goods sold by the unit: a price means everything up to and including it.
local ore = market.byKey["2001:Copper Ore"]
click(itemRow(ore.key))
local orePrices = priceRows(ore.key)
checkTrue("goods list their prices too", #orePrices >= 2)
click(orePrices[2])
local upTo = ns.Market.PricePoints(ore)[1].units + ns.Market.PricePoints(ore)[2].units
checkTrue("picking the second price asks for everything up to it", ButtonNamed("Buy " .. ns.Comma(upTo)) ~= nil)

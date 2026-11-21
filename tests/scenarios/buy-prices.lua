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
	Tick(20)
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
local buy = ButtonNamed("Buy 1 for " .. strip(ns.PlainMoney(wantedUnit)))
checkTrue("the button names the price clicked", buy ~= nil)

-- And that is the price bought: the live auction at it, not a cheaper one.
MOCK.liveNames = { "Tunic of the Bear", "Tunic of the Bear" }
MOCK.livePrice = wantedUnit / 2 -- live auctions at half the price and at the price
buy.scripts.OnClick(buy)
Tick(20)
check("the live auction at that price is offered", ns.Buying.state.total, wantedUnit)
check("not the cheaper one", ns.Buying.state.auctionID, 702)
checkTrue("at an unchanged price the button says it needs another press", ButtonNamed("Press again: buy 1 for " .. strip(ns.PlainMoney(wantedUnit))) ~= nil)
checkTrue("and says nothing of confirming", ButtonNamed("Confirm: buy 1 for " .. strip(ns.PlainMoney(wantedUnit))) == nil)
checkMatch("its note says the price is unchanged", ns.L.BUY_CHECKED_SAME, "unchanged")
ns.Buying:Cancel()

-- An item that cannot stack is one per auction, whatever count the live
-- search reports, so its price is never split into cheap units.
MOCK.liveCount = 68
buy = ButtonNamed("Buy 1 for " .. strip(ns.PlainMoney(wantedUnit)))
buy.scripts.OnClick(buy)
Tick(20)
check("a junk count is held to one", ns.Buying.state.quantity, 1)
check("and the price is the auction's", ns.Buying.state.total, wantedUnit)
ns.Buying:Cancel()
MOCK.liveCount = nil

-- If nothing is at that price any more, it says so and names the cheapest.
MOCK.livePrice = wantedUnit * 3
buy = ButtonNamed("Buy 1 for " .. strip(ns.PlainMoney(wantedUnit)))
buy.scripts.OnClick(buy)
Tick(20)
check("a price that is gone is not swapped for another", ns.Buying.state.phase, "failed")
checkMatch("and the player is told", ns.Buying.state.message, "^None at .* any more%. The cheapest now is ")
MOCK.livePrice = nil

-- A stacked single item names how many units the auction holds and what the
-- whole stack costs, so a stack is never read as that many at that price.
click(itemRow(tunic.key))
local cloth = market.byKey["2002:Linen Cloth"]
cloth.checkedAt = GetServerTime() -- checked a moment ago: choosing it asks nothing
click(itemRow(cloth.key))
local stacked = Frames(function(frame)
	local n = frame.label and frame.scripts.OnClick and tostring(frame.label.text):match("^Buy (%d+) for .* total$")
	return n and tonumber(n) > 1
end)[1]
checkTrue("a stack names its units and its total", stacked ~= nil)

-- A stack is all or nothing, and the confirm says it is a stack.
local clothPrices = priceRows(cloth.key)
local clothUnit = clothPrices[1].data.point.unit
click(clothPrices[1])
MOCK.livePrice, MOCK.liveQuantity = clothUnit, 94
MOCK.liveNames = { "Linen Cloth" }
stacked = Frames(function(frame)
	return frame.label and frame.scripts.OnClick and tostring(frame.label.text):match("^Buy %d+ for ")
end)[1]
stacked.scripts.OnClick(stacked)
Tick(20)
check("the whole stack is offered", ns.Buying.state.quantity, 94)
checkTrue("the confirm names it a stack", ButtonNamed("Confirm: buy a stack of 94 for " .. strip(ns.PlainMoney(clothUnit * 94)) .. " total") ~= nil)
ns.Buying:Cancel()
MOCK.livePrice, MOCK.liveQuantity, MOCK.liveNames = nil, nil, nil
click(itemRow(cloth.key))
click(itemRow(tunic.key))

-- Clicking the item again closes it.
click(itemRow(tunic.key))
check("clicking the item again closes it", #priceRows(tunic.key), 0)

-- Goods sold by the unit: picking a price starts at one, never the whole lot
-- at that price, and the button says what they cost in all.
local ore = market.byKey["2001:Copper Ore"]
click(itemRow(ore.key))
local orePrices = priceRows(ore.key)
checkTrue("goods list their prices too", #orePrices >= 2)
click(orePrices[2])
local cheapest = ns.Market.PricePoints(ore)[1].unit
checkTrue("picking a price asks for one", ButtonNamed("Buy 1 for " .. strip(ns.PlainMoney(cheapest))) ~= nil)
local plus = Frames(function(frame)
	return frame.label and frame.scripts.OnClick and tostring(frame.label.text) == "+"
end)[1]
plus.scripts.OnClick(plus)
local two = ns.Orders.Fill(ore, 2)
checkTrue("two say both prices added up", ButtonNamed("Buy 2 for " .. strip(ns.PlainMoney(two.cost)) .. " total") ~= nil)

-- The live price comes back above the player's gold: the confirm cannot be
-- pressed, and the note says why instead of looking broken.
local function shownText(pattern)
	return Frames(function(frame)
		return type(frame.text) == "string" and frame.text:find(pattern) ~= nil
	end)[1]
end
local savedMoney = MONEY
MONEY = two.cost + 1
MOCK.quoteUnit = two.cost -- each, so the pair costs about twice the gold
local twoBuy = ButtonNamed("Buy 2 for " .. strip(ns.PlainMoney(two.cost)) .. " total")
twoBuy.scripts.OnClick(twoBuy)
Tick(4)
check("the price is checked", ns.Buying.state.phase, "confirm")
checkTrue("a confirm above your gold says why it cannot be pressed", shownText("more than your") ~= nil)

-- The game lets the checked price lapse: not a failure, nothing spent.
MOCK.quoteLeft = 0
Tick(30)
check("a lapsed price check is not a failure", ns.Buying.state.phase, "expired")
checkTrue("and says it can be checked again", shownText("Press Buy to check it again") ~= nil)
checkTrue("with the Buy button back", ButtonNamed("Buy 2 for " .. strip(ns.PlainMoney(two.cost)) .. " total") ~= nil)
MOCK.quoteLeft, MOCK.quoteUnit, MONEY = nil, nil, savedMoney
ns.Buying:Cancel()

-- A purchase that finds nothing listed by the item's name takes it off the
-- list, with nothing spent and nothing more asked.
local sword
for key, item in pairs(market.byKey) do
	if item.itemID == 2007 then sword = item end
end
click(itemRow(sword.key))
MOCK.browseGone = true
ns.ItemKey:Forget(sword.itemID, sword.name)
local swordBuy = Frames(function(frame)
	return frame.label and frame.scripts.OnClick and tostring(frame.label.text):match("^Buy %d+ for ")
end)[1]
swordBuy.scripts.OnClick(swordBuy)
Tick(20)
check("the purchase finds it gone", ns.Buying.state.gone, true)
check("and it comes off the list", itemRow(sword.key), nil)
check("and out of the market", market.byKey[sword.key], nil)
MOCK.browseGone = false

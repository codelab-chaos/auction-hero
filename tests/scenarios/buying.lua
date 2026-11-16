-- Buying goods sold by the unit: a live price check, then a second press.
local ns = Boot()
OpenAuctionHouse()
Scan()
MONEY = 1000000
local order = { key = "2001:Copper Ore", itemID = 2001, quantity = 5 }
local function phase()
	return ns.Buying.state.phase
end

ns.Buying:Start(order)
check("the first press asks for a quote", BUYS[#BUYS], "start 2001 x5")
check("and waits for it", phase(), "quoting")
Tick(2)
check("the quote arrives", phase(), "confirm")
check("with the server's total", ns.Buying.state.total, 35)
ns.Buying:Confirm()
check("the second press buys", BUYS[#BUYS], "confirm 2001 x5")
Tick(2)
check("bought", phase(), "done")

-- Nothing is spent without the second press.
ns.Buying:Start(order)
Tick(2)
ns.Buying:Cancel()
check("backing out tells the game", BUYS[#BUYS], "cancel")
check("and returns to idle", phase(), "idle")
ns.Buying:Confirm()
check("confirm without a quote does nothing", BUYS[#BUYS], "cancel")

MOCK.quoteUnavailable = true
ns.Buying:Start(order)
Tick(2)
check("a quantity that is gone", phase(), "failed")
MOCK.quoteUnavailable = false

MOCK.quoteSilent = true
ns.Buying:Start(order)
Tick(250)
check("a server that does not answer", phase(), "failed")
MOCK.quoteSilent = false

-- A live price above the player's gold is never confirmed.
MOCK.quoteUnit = 999999
ns.Buying:Start(order)
Tick(2)
ns.Buying:Confirm()
check("price over gold", phase(), "failed")
checkTrue("no purchase was sent", not BUYS[#BUYS]:find("^confirm"))
MOCK.quoteUnit = nil

MOCK.buyFails = true
ns.Buying:Start(order)
Tick(2)
ns.Buying:Confirm()
Tick(2)
check("the server refuses", phase(), "failed")
MOCK.buyFails = false

FireEvent("AUCTION_HOUSE_CLOSED")
local before = #BUYS
ns.Buying:Start(order)
check("closed auction house", phase(), "failed")
check("nothing sent when closed", #BUYS, before)

-- The server can quote again while the confirm is showing. The newest quote
-- is what a confirm spends, so it is the one shown, and a rise is said out loud.
OpenAuctionHouse()
MOCK.quoteUnit = 7
ns.Buying:Start({ key = "2001:Copper Ore", itemID = 2001, quantity = 10 })
Tick(2)
check("a quote to confirm", phase(), "confirm")
check("at the first price", ns.Buying.state.total, 70)
FireEvent("COMMODITY_PRICE_UPDATED", 9, 90)
check("still waiting for a confirm", phase(), "confirm")
check("now at the new total", ns.Buying.state.total, 90)
checkMatch("and it says the price went up", ns.Buying.state.message, "went up by")
FireEvent("COMMODITY_PRICE_UPDATED", 8, 80)
check("a drop is shown too", ns.Buying.state.total, 80)
check("without a warning", ns.Buying.state.message, ns.L.BUY_CONFIRM_PRICE)
ns.Buying:Confirm()
Tick(2)
check("and the confirm goes through", phase(), "done")

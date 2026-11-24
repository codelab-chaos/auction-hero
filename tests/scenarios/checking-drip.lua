-- While a Buy row's price is being checked live, coins drop where its mark
-- goes; once checked, the check mark takes their place.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("buy")
SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
MOCK.liveGoods = { { 150, 3 }, { 180, 10 } }
local ore = ns.Analysis.market.byKey["2001:Copper Ore"]
local function dripping()
	return #Frames(function(frame)
		return frame.coins ~= nil and frame:IsShown()
	end)
end
check("no coins before anything is checked", dripping(), 0)
check("a stale price is checked", ns.LiveCheck:Request(ore), true)
Tick(1)
check("coins drop on the row being checked", dripping(), 1)
Tick(40)
check("and stop once it is checked", dripping(), 0)
checkTrue("the check mark shows instead", #Frames(function(frame)
	return type(frame.text) == "string" and frame.text == ns.PriceFreshness.live.mark
end) > 0)

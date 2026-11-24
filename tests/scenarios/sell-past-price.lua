-- An item nobody is selling in the scan now loaded, but past scans saw: the
-- Sell tab fills in what they saw (the same price the tooltip's "worth" line
-- gives) and says where it came from, instead of "no price to go by".
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("sell")

local function has(pattern)
	return #Frames(function(frame)
		return type(frame.text) == "string" and frame:IsShown() and strip(frame.text):find(strip(pattern), 1, true) ~= nil
	end) > 0
end

-- This scan finds none of what is in the bags.
local market = ns.Window:Market()
local seen = {}
for key in pairs(market.byKey) do
	if ns.Bags:Find(key) then
		seen[key] = ns.History:PastPrice(key)
		market.byKey[key] = nil
	end
end
checkTrue("past scans saw something in the bags", next(seen) ~= nil)
ns.Window:RefreshActive()

local lead = ns.L.SELL_PAST_LAST:match("^(.-)%. ")
checkTrue("says nobody is selling it now, and that the price is from past scans", has(lead))
checkTrue("not that there is no price to go by", not has(ns.L.SELL_NO_PRICE))
local shownPrice = false
for _, past in pairs(seen) do
	local unit = math.max(past.price, ns.MinItemPrice)
	local owned = 0
	for key, other in pairs(seen) do
		if other == past then
			owned = ns.Bags:Find(key).total
		end
	end
	if has(ns.Money(unit)) or has(ns.Money(unit * owned)) then
		shownPrice = true
	end
end
checkTrue("the price past scans saw is filled in", shownPrice)

-- The panel beside the form is about the item: under its listings, what past
-- scans and the ledger know, the same lines as its tooltip.
checkTrue("the price history heading shows", has(ns.L.STAT_HEADING))
local heading = Frames(function(frame)
	return frame.left and frame.left.text == ns.L.STAT_HEADING
end)[1]
heading:GetParent().h = 600 -- a full height panel, as in game
ns.Window:RefreshActive()
checkTrue("with the lowest price the scans saw", has(ns.L.TIP_LOWEST))

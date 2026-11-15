-- Cancelling one of your auctions: pick it, press Cancel auction to see what
-- it costs, press again to cancel.
local ns = Boot()
OpenAuctionHouse()
ShowTab("auctions")
local function phase()
	return ns.Cancelling.state.phase
end
local function tunic()
	for _, auction in ipairs(ns.Owned.auctions) do
		if auction.auctionID == 1 then
			return auction
		end
	end
end

-- A sold auction cannot be cancelled.
ns.Cancelling:Start(ns.Owned.auctions[2])
check("a sold auction is refused", phase(), "failed")
check("and nothing is sent", #CANCELS, 0)

-- The first press only says what it costs.
MOCK.cancelCost = 120
ns.Cancelling:Start(tunic())
check("the first press asks to confirm", phase(), "confirm")
check("with the cost", ns.Cancelling.state.cost, 120)
check("nothing sent yet", #CANCELS, 0)
ns.Cancelling:Back()
check("backing out sends nothing", phase(), "idle")

-- More than the purse holds is refused.
MONEY = 50
ns.Cancelling:Start(tunic())
check("a cost over your gold is refused", phase(), "failed")
MONEY = 50000

-- The second press cancels; the game's answer about this auction finishes it.
ns.Cancelling:Start(tunic())
ns.Cancelling:Confirm()
check("the second press cancels", CANCELS[1], 1)
check("and waits for the answer", phase(), "cancelling")
FireEvent("AUCTION_CANCELED", 999)
check("someone else's cancel is not ours", phase(), "cancelling")
Tick(5)
check("ours finishes it", phase(), "done")
checkTrue("and the list is asked for again, without it", tunic() == nil)

-- No answer: the fresh list settles it.
OWNED[#OWNED + 1] = { auctionID = 3, itemKey = { itemID = 2006 }, status = 0, quantity = 1, buyoutAmount = 500 }
ns.Owned:Request()
Tick(2)
MOCK.cancelSilent = true
ns.Cancelling:Start(ns.Owned.auctions[#ns.Owned.auctions])
ns.Cancelling:Confirm()
Tick(250)
check("gone from the list means cancelled", phase(), "done")
MOCK.cancelSilent = false

OWNED[#OWNED + 1] = { auctionID = 4, itemKey = { itemID = 2006 }, status = 0, quantity = 1, buyoutAmount = 700 }
ns.Owned:Request()
Tick(2)
local kept
for _, auction in ipairs(ns.Owned.auctions) do
	if auction.auctionID == 4 then
		kept = auction
	end
end
MOCK.cancelKept = true
ns.Cancelling:Start(kept)
ns.Cancelling:Confirm()
check("sent for the active one", CANCELS[#CANCELS], 4)
Tick(250)
check("still in the list means not cancelled", phase(), "failed")
check("and it says so", ns.Cancelling.state.message, ns.L.CANCEL_NOT_DONE)
MOCK.cancelKept = false

-- The tab's button follows it: pick a row, then press.
local row = Frames(function(frame)
	return frame.data ~= nil and frame.data.auctionID ~= nil and frame.data.sold == false and frame.scripts.OnMouseUp ~= nil
end)[1]
checkTrue("a row to pick", row ~= nil)
row.scripts.OnMouseUp(row, "LeftButton")
Tick(2)
local button = ButtonNamed("Cancel auction")
checkTrue("the button is there once a row is picked", button ~= nil and not button.disabled)
local sent = #CANCELS
MOCK.cancelCost = 0
button.scripts.OnClick(button)
Tick(2)
local confirm = ButtonNamed("Confirm cancel")
checkTrue("the first press turns it into a confirm", confirm ~= nil)
check("nothing sent on the first press", #CANCELS, sent)
confirm.scripts.OnClick(confirm)
check("the second press cancels the picked auction", CANCELS[#CANCELS], row.data.auctionID)

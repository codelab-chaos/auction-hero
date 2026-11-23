-- Data flows one way into the window: data changes and says so, the shown
-- tab redraws from it once per frame at most, and a view that changes data
-- while it draws is caught.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("ledger")
local W = ns.Window
ENTRY = { kind = "post", name = "Copper Ore", quantity = 1, amount = 0 } -- what the message carries
local function draws()
	return W.timings.ledger.draw.runs
end

-- A burst of messages is one redraw, on the next frame.
local before = draws()
for _ = 1, 5 do
	ns.Bus:Fire("LEDGER_CHANGED", ENTRY)
end
check("nothing is drawn inside the burst", draws(), before)
checkTrue("a draw waits", W:IsRefreshPending())
Tick(1)
check("then one draw for all of it", draws(), before + 1)

-- A data message moves the data version; a view's own message does not.
local version = ns.DataVersion
ns.Bus:Fire("LEDGER_CHANGED", ENTRY)
checkTrue("data changed moves the version", ns.DataVersion > version)
version = ns.DataVersion
ns.Bus:Fire("TAB_SHOWN", "ledger")
check("a view's own message leaves it", ns.DataVersion, version)
Tick(1)

-- A tab whose last draw was slow says it is refreshing for a frame first.
local function noteShown()
	return #Frames(function(frame)
		return frame.text == ns.L.WIN_REFRESHING
	end) > 0
end
W.timings.ledger.draw.last = ns.SlowTabMs + 1
W.timings.ledger.draw.worst = ns.SlowTabMs + 1
before = draws()
ns.Bus:Fire("LEDGER_CHANGED", ENTRY)
checkTrue("slow: it says so before drawing", noteShown())
Tick(1)
check("and shows that for a frame", draws(), before)
Tick(math.ceil(ns.RedrawRule.slowGapSeconds / 0.05) + 1) -- a slow draw waits out the gap since the last
check("then draws", draws(), before + 1)
checkTrue("and the note goes", not noteShown())

-- Fast last time but slow before: slow again only once data has changed.
W.timings.ledger.draw.last = 1
W:RefreshActive()
W.timings.ledger.draw.last = 1
check("nothing changed: not expected to be slow", W.LikelySlow("ledger"), false)
ns.DataChanged("ledger")
check("data changed: expected to be slow again", W.LikelySlow("ledger"), true)
W.timings.ledger.draw.worst = 0

-- A view that changes data while it draws is written to the log, and the
-- redraws it sets off are stopped after a few.
local summary = ns.Ledger.Summary
ns.Ledger.Summary = function(self)
	ns.Bus:Fire("LEDGER_CHANGED", ENTRY)
	return summary(self)
end
W:RefreshActive()
local function logged(event)
	for _, entry in ipairs(AuctionHeroDB.log) do
		if entry.event == "> " .. event then
			return entry
		end
	end
end
checkTrue("the data change during the draw is logged", logged("data changed while drawing") ~= nil)
Tick(10)
checkTrue("the loop is stopped", logged("redraw loop stopped") ~= nil)
check("and nothing waits any more", W:IsRefreshPending(), false)
ns.Ledger.Summary = summary

-- A live check that replaced an item's rows: the list takes them at once and
-- the filter counts are counted again in the background, saying so meanwhile.
ShowTab("buy")
Tick(3)
ns.Bus:Fire("MARKET_PATCHED", 2001)
checkTrue("refreshing is shown while the filters are counted", noteShown())
Tick(30)
checkTrue("and goes when they are in", not noteShown())

-- Requests to the auction house go one at a time, in order. An answer is read
-- once it is quiet, a purchase goes only as part of a press and only when
-- nothing else is in flight, and a price is bought only from the latest search.
local ns = Boot()
OpenAuctionHouse()
local R = ns.Requests
local sent, ended = {}, {}
local function ask(label, itemID)
	return R:Ask({
		kind = "itemSearch", label = label, itemID = itemID,
		send = function() sent[#sent + 1] = label end,
		done = function(outcome) ended[#ended + 1] = label .. " " .. outcome end,
	})
end
local key = function(itemID) return { itemID = itemID } end

ask("first", 1)
ask("second", 2)
check("the first is sent", sent[1], "first")
check("the second waits for it", #sent, 1)
FireEvent("ITEM_SEARCH_RESULTS_UPDATED", key(2))
Tick(10)
check("an answer to another item does not count", #ended, 0)
FireEvent("ITEM_SEARCH_RESULTS_UPDATED", key(1))
check("an answer is not read at once", #ended, 0)
Tick(1)
FireEvent("ITEM_SEARCH_RESULTS_ADDED", key(1)) -- more of it, still arriving
Tick(1)
check("it waits while more may come", #ended, 0)
Tick(2)
check("then, quiet, it is read and ends", ended[1], "first answered")
check("and the second waits a quiet gap", #sent, 1)
Tick(10)
check("before it is sent", sent[2], "second")

-- The game holds the latest search's results, and only those.
FireEvent("ITEM_SEARCH_RESULTS_UPDATED", key(2))
Tick(10)
checkTrue("the latest results are known", R:Holding(2) ~= nil)
check("an earlier search's are not", R:Holding(1), nil)
ask("third", 3)
Tick(10)
check("a new search replaces them", R:Holding(2), nil)
FireEvent("ITEM_SEARCH_RESULTS_UPDATED", key(3))
Tick(10)

-- A purchase is a press: sent at once, or not at all.
ask("fourth", 4)
Tick(10)
check("a search is in flight", sent[#sent], "fourth")
local outcome
local wasSent = R:Press({ kind = "bid", label = "buy", auctionID = 9, send = function() sent[#sent + 1] = "buy" end,
	done = function(how) outcome = how end })
check("a press while another request is in flight is not sent", wasSent, false)
check("it is told the auction house is busy", outcome, "busy")
check("and nothing went", sent[#sent], "fourth")
FireEvent("ITEM_SEARCH_RESULTS_UPDATED", key(4))
Tick(10)

-- A problem reported on a purchase waits for the purchase to land.
outcome = nil
R:Press({ kind = "bid", label = "buy", auctionID = 9, send = function() sent[#sent + 1] = "buy" end,
	done = function(how) outcome = how end })
check("with nothing in flight, the press is sent", sent[#sent], "buy")
FireEvent("AUCTION_HOUSE_SHOW_ERROR", 10)
Tick(1)
FireEvent("AUCTION_HOUSE_PURCHASE_COMPLETED", 9)
Tick(2)
check("a purchase that lands after an error is bought", outcome, "answered")

-- The game refusing to send it is told apart from a refusal by the server.
Tick(10)
outcome = nil
R:Press({ kind = "bid", label = "buy", auctionID = 10,
	send = function() FireEvent("ADDON_ACTION_BLOCKED", "AuctionHero", "UNKNOWN()") end,
	done = function(how) outcome = how end })
check("a blocked purchase says so", outcome, "blocked")

-- No answer at all ends it, and what was queued goes on.
Tick(10)
ask("fifth", 5)
ask("sixth", 6)
Tick(ns.RequestKinds.itemSearch.timeout * 20 + 2)
check("an unanswered request ends", ended[#ended - 0], "fifth unanswered")
Tick(10)
check("and the next is sent", sent[#sent], "sixth")

-- A cancelled request in flight is waited out, not cut off.

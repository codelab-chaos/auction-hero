-- Choosing an item when the scan is no longer fresh asks the auction house
-- about that one item and patches the answer into the scan.
local ns = Boot()
OpenAuctionHouse()
Scan()
local market = ns.Analysis.market
local ore = market.byKey["2001:Copper Ore"]
local before = #SEARCHES
local scanned = ore.units
local scannedListings = ns.ScanJournal:Listings(ns.Store:GetSourceSnapshot("replicate"))

-- A fresh scan is trusted: nothing is asked.
check("a fresh scan needs no check", ns.LiveCheck:Request(ore), false)
Tick(20)
check("and no search is sent", #SEARCHES, before)

-- Past the limit, choosing the item asks about it.
SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
MOCK.liveGoods = { { 150, 3 }, { 180, 10 } }
check("a scanned row carries no freshness mark", ns.LiveCheck:Freshness(ore), nil)
check("a stale scan is checked", ns.LiveCheck:Request(ore), true)
check("while asking, the row says it is being checked", ns.LiveCheck:Freshness(ore), "checking")
check("after a short wait, not at once", #SEARCHES, before)
Tick(20)
check("one search for the item", #SEARCHES, before + 1)

-- The answer replaces the item in the market the tabs read.
ore = market.byKey["2001:Copper Ore"]
check("the market holds what is for sale now", ore.units, 13)
checkTrue("which is not what the scan saw", scanned ~= 13)
check("at the live lowest price", ore.min, 150)
checkTrue("marked with when it was checked", ore.checkedAt ~= nil)
check("and its row says its prices are live", ns.LiveCheck:Freshness(ore), "live")
local points = ns.Market.PricePoints(ore)
check("with the live price points", #points, 2)
check("and their counts", points[2].units, 10)

-- And in the saved scan, which says it was patched.
local snapshot = ns.Store:GetSourceSnapshot("replicate")
local get = ns.RowReader(snapshot)
local rows, units = 0, 0
for _, row in ipairs(snapshot.rows) do
	if get(row, "itemID") == 2001 then
		rows, units = rows + 1, units + get(row, "count") * get(row, "copies")
	end
end
check("the saved scan has the live rows for the item", rows, 2)
check("and their units", units, 13)
check("other items are untouched", get(snapshot.rows[2], "itemID") ~= nil, true)
check("the scan notes the patch", snapshot.meta.patched[1].id, 2001)
checkTrue("and when", snapshot.meta.patched[1].time ~= nil)
check("the same table is what is saved", AuctionHeroDB.snapshots.replicate, snapshot)

-- The scan journal follows the patch, so the scan before it still rebuilds.
local patch = AuctionHeroDB.scanJournal.deltas[1]
check("the journal records the live check", patch and patch.kind, "patch")
check("of the item", patch and patch.itemID, 2001)
local rebuilt, same = ns.ScanJournal:Rebuild(1), true
for key, copies in pairs(scannedListings) do
	same = same and rebuilt[key] == copies
end
for key in pairs(rebuilt) do
	same = same and scannedListings[key] ~= nil
end
checkTrue("walking it back gives the scan as it was", same)

-- A reload builds the market from the saved scan and still knows the check.
local rebuilt = ns.Market:Build(snapshot)
local again
for _, item in ipairs(rebuilt.items) do
	if item.itemID == 2001 then
		again = item
	end
end
check("a rebuilt market keeps when the item was checked", again and again.checkedAt, ore.checkedAt)
check("so its row still says live", again and ns.LiveCheck:Freshness(again), "live")
local restored = again
local other = rebuilt.items[1].itemID ~= 2001 and rebuilt.items[1] or rebuilt.items[2]
check("items never checked are the scan's", other.checkedAt, nil)

-- History is not given a scan it did not have, but a new low is a new low.
local record = ns.History:Get("2001:Copper Ore")
check("a check is not a scan", record.n, 1)
check("no graph point is added", #ns.History:Points("2001:Copper Ore"), 1)

-- A just checked item is not asked about again.
check("a fresh check is trusted", ns.LiveCheck:Request(ore), false)

-- A single item is found by its name, as the game's own window finds it, and
-- only that variant is brought up to date.
local function tunics()
	local names = {}
	for _, item in ipairs(market.items) do
		if item.itemID == 2006 then
			names[#names + 1] = item.name .. " x" .. item.listings
		end
	end
	table.sort(names)
	return table.concat(names, ", ")
end
local scannedTunics = market.byKey["2006:Tunic of the Bear"].listings
MOCK.liveNames = { "Tunic of the Bear", "Tunic of the Bear" }
check("gear is checked too", ns.LiveCheck:Request(market.byKey["2006:Tunic of the Bear"]), true)
Tick(40) -- the key, a quiet gap, then the search
check("its key is asked for by name", BROWSED[#BROWSED], "Tunic of the Bear")
check("and its auctions by that full key, not the bare item id", SEARCHES[#SEARCHES], "search sorts=2 2006 level=12")
check("the variant holds its live auctions", tunics(), "Tunic of the Bear x2")
checkTrue("which is not what the scan saw", scannedTunics ~= 2)

-- Pressing Buy just after a check uses its answer: no second search.
MONEY = 10000000
local bear = market.byKey["2006:Tunic of the Bear"]
checkTrue("the check kept the live auctions", bear.liveAuctions ~= nil and #bear.liveAuctions == 2)
local asked = #SEARCHES
local request = { key = bear.key, itemID = 2006, name = bear.name, single = true, live = bear.liveAuctions, checkedAt = bear.checkedAt }
ns.Buying:Start(request)
check("the confirm comes at once", ns.Buying.state.phase, "confirm")
check("with no second search", #SEARCHES, asked)
check("for the cheapest live auction", ns.Buying.state.auctionID, 701)
check("at its live price", ns.Buying.state.total, 100)
ns.Buying:Confirm()
check("and that auction is the one bought", BUYS[#BUYS], "bid 701 100")
Tick(6)
check("bought", ns.Buying.state.phase, "done")
Tick(20) -- buying an item checks it again

-- At the price pressed, a fresh check: still confirmed, unless the player
-- chose one press.
bear = market.byKey["2006:Tunic of the Bear"]
local bought = #BUYS
local cheapest = bear.liveAuctions[1]
for _, auction in ipairs(bear.liveAuctions) do
	if auction.buyout < cheapest.buyout then cheapest = auction end
end
check("one press is off unless chosen", ns.IsEnabled("buyOnePress"), false)
ns.Buying:Start({ key = bear.key, itemID = 2006, name = bear.name, single = true, live = bear.liveAuctions, checkedAt = bear.checkedAt, price = cheapest.buyout })
check("by default an unchanged price still asks to confirm", ns.Buying.state.phase, "confirm")
check("and nothing is bought yet", #BUYS, bought)
ns.Buying:Cancel()
Tick(1)

-- Chosen: at an unchanged price one press buys.
ns.SetEnabled("buyOnePress", true)
local sentFirst
ns.Bus:On("BUYING_CHANGED", function()
	if sentFirst == nil then sentFirst = #BUYS == bought + 1 end
end)
ns.Buying:Start({ key = bear.key, itemID = 2006, name = bear.name, single = true, live = bear.liveAuctions, checkedAt = bear.checkedAt, price = cheapest.buyout })
check("one press buys at an unchanged price", #BUYS, bought + 1)
check("sent before anything else runs, as the game requires", sentFirst, true)
check("with no confirm to wait on", ns.Buying.state.phase, "buying")
local searched = #SEARCHES
Tick(20)
check("bought", ns.Buying.state.phase, "done")

-- Two in a row: after a purchase the game still holds the item's auctions,
-- so the next one is read from them, with no search a second press could
-- land in the middle of. That press buys at once.
check("the next auction is read with nothing asked", #SEARCHES, searched)
local reread = false
for _, line in ipairs(ns.db.log) do
	if line.event == "> live check reread" then reread = true end
end
check("from what the game holds", reread, true)
bear = market.byKey["2006:Tunic of the Bear"]
local boughtID = tonumber(BUYS[#BUYS]:match("^bid (%d+)"))
local left = true
for _, auction in ipairs(bear.liveAuctions) do
	if auction.auctionID == boughtID then left = false end
end
check("without the auction just bought", left, true)
local nextOne = bear.liveAuctions[1]
bought = #BUYS
ns.Buying:Start({ key = bear.key, itemID = 2006, name = bear.name, single = true, live = bear.liveAuctions, checkedAt = bear.checkedAt, price = nextOne.buyout })
check("the second press buys at once", #BUYS, bought + 1)
check("the next auction", BUYS[#BUYS], "bid " .. nextOne.auctionID .. " " .. nextOne.buyout)
Tick(20)
check("bought again", ns.Buying.state.phase, "done")

-- If the game refuses the purchase anyway, nothing was spent and the next
-- press sends it: no waiting on an answer that cannot come.
bear = market.byKey["2006:Tunic of the Bear"]
cheapest = bear.liveAuctions[1]
for _, auction in ipairs(bear.liveAuctions) do
	if auction.buyout < cheapest.buyout then cheapest = auction end
end
MOCK.blockBids = true
bought = #BUYS
ns.Buying:Start({ key = bear.key, itemID = 2006, name = bear.name, single = true, live = bear.liveAuctions, checkedAt = bear.checkedAt, price = cheapest.buyout })
check("a refused purchase goes back to the confirm at once", ns.Buying.state.phase, "confirm")
check("with nothing bought", #BUYS, bought)
MOCK.blockBids = nil
ns.Buying:Confirm()
check("and the next press buys", #BUYS, bought + 1)
Tick(20)
check("bought", ns.Buying.state.phase, "done")
request.live, request.checkedAt = bear.liveAuctions, bear.checkedAt

-- An older check is not trusted for buying: Buy asks first.
SkipTime(ns.LiveCheckRule.reuseSeconds + 1)
asked = #SEARCHES
ns.Buying:Start(request)
check("a check that is no longer fresh is asked again", ns.Buying.state.phase, "quoting")
Tick(4)
check("with a search", #SEARCHES, asked + 1)
Tick(6)
ns.Buying:Cancel()

-- Auctions that cannot be named are not patched in: the scan stands.
SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
MOCK.liveNames = nil
local kept = market.byKey["2006:Tunic of the Bear"].checkedAt
ns.LiveCheck:Request(market.byKey["2006:Tunic of the Bear"])
Tick(20)
check("unreadable auctions change nothing", market.byKey["2006:Tunic of the Bear"].checkedAt, kept)

-- Results that do not include the item are not proof that it is gone: the
-- lookup may be at fault. Nothing is removed on that alone: the scan's rows
-- stand, and the reason is kept.
SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
MOCK.browseNames = { "Tunic of the Owl" }
ns.ItemKey:Forget(2006, "Tunic of the Bear")
local listed = market.byKey["2006:Tunic of the Bear"].listings
ns.LiveCheck:Request(market.byKey["2006:Tunic of the Bear"])
Tick(20)
checkTrue("an item the lookup cannot find stays in the market", market.byKey["2006:Tunic of the Bear"] ~= nil)
check("with what it had", market.byKey["2006:Tunic of the Bear"].listings, listed)
checkMatch("and the reason is kept for the panel", ns.LiveCheck.problem.text, "could not find this item at the auction house.*1 results")
MOCK.browseNames = nil

-- Nothing at all listed by its name: it is gone, and comes off the list.
SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
MOCK.browseGone = true
ns.ItemKey:Forget(2006, "Tunic of the Bear")
ns.LiveCheck:Request(market.byKey["2006:Tunic of the Bear"])
Tick(20)
check("an item nothing is listed by comes off the list", market.byKey["2006:Tunic of the Bear"], nil)
MOCK.browseGone = false

-- On the Buy tab, choosing a row does it, and the panel says how fresh the prices are.
SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
MOCK.liveGoods = { { 140, 2 } }
ShowTab("buy")
local function has(pattern)
	return #Frames(function(frame)
		return type(frame.text) == "string" and strip(frame.text):find(pattern) ~= nil
	end) > 0
end
local row
for _, frame in ipairs(Frames(function(frame)
	return frame.data ~= nil and frame.data.key == "2001:Copper Ore" and frame.scripts.OnMouseUp ~= nil
end)) do
	row = frame
end
if row then
	local function order()
		local keys = {}
		for _, frame in ipairs(Frames(function(frame)
			return frame.data ~= nil and frame.data.key ~= nil and frame.scripts.OnMouseUp ~= nil
		end)) do
			keys[#keys + 1] = frame.data.key
		end
		return table.concat(keys, " | ")
	end
	local wasLowest = market.byKey["2001:Copper Ore"].min
	row.scripts.OnMouseUp(row)
	checkTrue("the panel says it is checking", has("^checking the auction house"))
	local before = order()
	Tick(20)
	checkTrue("then that the prices are live", has("^checked live, "))
	check("and shows them", market.byKey["2001:Copper Ore"].min, 140)
	-- The numbers changed, but the item stays where the player was looking.
	check("the list keeps its order until the next sort", order(), before)
	checkTrue("and the panel says the prices were updated", wasLowest == 140 or has("^Prices updated$"))
	-- What changed is there when the note is hovered.
	local detail = wasLowest == 140
	for _, frame in ipairs(Frames(function(frame)
		return frame.detail ~= nil
	end)) do
		detail = detail or frame.detail:find("^The one at .* is gone%. 2 for sale now, from 1s 40c%.$") ~= nil
	end
	checkTrue("and what changed when hovered", detail)
end

-- The live mark fades once the check itself is stale.
SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
check("a check gone stale no longer says live", ns.LiveCheck:Freshness(restored), nil)

-- Scans are folded into a price history that is never cleared.
local ns = Boot()
OpenAuctionHouse()
Scan()
local key = "2001:Copper Ore"
local first = ns.Store:GetSourceSnapshot("replicate").meta.time
check("scans remembered after one", ns.History:ScanCount(), 1)
check("the item was seen once", ns.History:Get(key).n, 1)
checkTrue("the scan is saved whole, so the tabs have listings after a login", #AuctioNitroDB.snapshots.replicate.rows > 0)

Tick(400)
Scan()
checkTrue("a second scan replaces the first as current", ns.Store:GetSourceSnapshot("replicate").meta.time > first)
check("scans remembered after two", ns.History:ScanCount(), 2)
check("a second scan is a second graph point, even on the same day", #ns.History:Points(key), 2)
SkipTime(600)
Scan()
check("a third scan soon after updates the newest point", #ns.History:Points(key), 2)
check("and is still counted as a scan", ns.History:ScanCount(), 3)

-- Nothing clears a scan or the history.
SlashCmdList.AUCTIONITRO("clear scan")
SlashCmdList.AUCTIONITRO("clear")
checkTrue("the scan survives a clear command", ns.Store:GetSnapshot() ~= nil)
check("there is no way to clear the store", ns.Store.Clear, nil)
check("the history survives too", ns.History:ScanCount(), 3)

-- Points reach back to the limit, oldest dropped first.
for _ = 1, 40 do
	SkipTime(86400)
	Scan()
end
local points = ns.History:Points(key)
check("graph points are capped", #points, ns.HistoryRule.graphPoints)
check("the kept points are consecutive days", points[#points].day - points[1].day, ns.HistoryRule.graphPoints - 1)
checkTrue("a point carries a price and a supply", points[#points].median > 0 and points[#points].low > 0 and points[#points].units > 0)

ns.History:SetGraphDays(10)
SkipTime(86400)
Scan()
check("a smaller limit trims the points", #ns.History:Points(key), 10)

-- The summaries the History tab shows.
local week = ns.History:InRange(ns.History:Points(key), 7)
check("a 7 day range holds 7 points", #week, 7)
local summary = ns.History:Summarize(week)
checkTrue("a summary has its numbers", summary.usual > 0 and summary.lowest <= summary.usual and summary.days == 7 and summary.scans == 7)
check("no points, no summary", ns.History:Summarize({}), nil)

-- Points saved before every scan had its own point carry a day, not a time.
local record = ns.History:Get(key)
record.h = "20770:150:120:9"
local old = ns.History:Points(key)[1]
check("an old daily point is read as noon of its day", old.time, 20770 * 86400 + 43200)
check("and keeps its day", old.day, 20770)

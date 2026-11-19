-- The Progress tab: an icon tab at the far right with the daily scan, scan
-- confidence, Hero Coins, the last days with a scan, the streak bonuses and
-- the ways to earn.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("progress")
local function shows(pattern)
	return #Frames(function(frame)
		return type(frame.text) == "string" and strip(frame.text):find(pattern) ~= nil
	end) > 0
end
check("the tab opened", ns.charDb.tab, "progress")
checkTrue("today's scan", shows("^One full scan$"))
checkTrue("confidence from one day", shows("^Scanned on 1 of the last 30 days$"))
checkTrue("the days strip", shows("^The last 30 days$"))
checkTrue("the streak bonuses", shows("^3 days in a row$"))
checkTrue("the next bonus", shows("^2 more days to the next$"))
checkTrue("the ways to earn", shows("^Buy through Auction Hero$"))
checkTrue("the day's scan is done", shows("^1/1 today$"))
checkTrue("the latest earnings", shows("^Open a tab for the first time$"))
check("visit, scan and first looks at Buy and Progress", ns.HeroCoins:Balance(), 1 + 10 + 5 + 5)
local days = ns.ScanConfidence:Days()
check("thirty days, oldest first", #days, 30)
checkTrue("today scanned", days[30].scanned)
checkTrue("yesterday not", not days[29].scanned)

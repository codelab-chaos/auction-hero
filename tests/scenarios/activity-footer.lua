-- The footer's list of recent actions.
local ns = Boot()
local function latest()
	local entry = ns.Activity:Latest()
	return entry and strip(entry.text), entry and entry.tone
end
check("empty before anything happens", ns.Activity:Latest(), nil)
OpenAuctionHouse()
check("opening is recorded", (latest()), "Auction house opened")
Scan()
checkMatch("a finished scan and its history", strip(ns.Activity.entries[2].text), "^Scan finished: 300 auctions")
checkMatch("history update", (latest()), "^Price history updated")

ns.SellSearch:Request("2006:Tunic of the Bear")
Tick(3)
ns.Posting:Post({ key = "2006:Tunic of the Bear", commodity = false, duration = 3, quantity = 1, unit = 99, buyout = true })
local text, tone = latest()
checkMatch("a refused post says why", text, "^Could not post Tunic of the Bear")
check("in the failure tone", tone, "bad")
ns.Posting:Post({ key = "2006:Tunic of the Bear", commodity = false, duration = 3, quantity = 1, unit = 500, buyout = true })
Tick(5)
text, tone = latest()
check("a post is recorded", text, "Posted Tunic of the Bear")
check("in the success tone", tone, "good")

for index = 1, 40 do
	ns.Activity:Add("line " .. index)
end
check("the list is capped", #ns.Activity.entries, ns.ActivityLimit)
check("newest first", (latest()), "line 40")

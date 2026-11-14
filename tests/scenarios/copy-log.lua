-- The log as text for the copy box: newest first, one line per entry.
local ns = Boot()
OpenAuctionHouse()
Scan()
ns.EventLog:Note("PostItem", 3, 1, nil, 99)
local text = ns.EventLog:Text()
local lines = select(2, text:gsub("\n", "\n")) + 1
check("one line per entry", lines, #ns.db.log)
checkMatch("the newest entry is first", text, "^%d%d:%d%d:%d%d  > PostItem  3, 1, nil, 99")
local long = ("x"):rep(400)
ns.EventLog:Note("long", long)
checkTrue("long text is cut, not dropped", #ns.db.log[#ns.db.log].detail < 400)

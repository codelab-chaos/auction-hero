-- The History tab: charts from the first scan, with a note until two days
-- are in, and a hover readout.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("history")
local function shows(pattern)
	return #Frames(function(frame)
		return type(frame.text) == "string" and strip(frame.text):find(pattern) ~= nil
	end) > 0
end
checkTrue("one scan already draws, and says it is early", shows("^1 points so far, all on one day"))
checkTrue("with its numbers", shows("^1 of 7$"))

for _ = 1, 12 do
	SkipTime(86400)
	Scan()
end
ns.Window:RefreshActive()
Tick(3)
checkTrue("days seen out of the range", shows("^7 of 7$"))

MOUSE_OVER = true
Tick(3)
checkTrue("hovering reads out a scan", shows("usual .* lowest .* for sale"))
MOUSE_OVER = false
Tick(3)
checkTrue("leaving restores the prompt", shows("^Hover a chart"))

-- A change counts only between points with enough for sale.
local H = ns.History
local thin = H:Summarize({
	{ time = 1, day = 1, median = 10, low = 10, units = 1 },
	{ time = 2, day = 1, median = 10, low = 9, units = 20 },
	{ time = 3, day = 2, median = 15, low = 12, units = 30 },
	{ time = 4, day = 2, median = 90, low = 90, units = 2 },
})
check("thin ends do not count toward the change", thin.change, 50)
check("one well-stocked point is no change", H:Summarize({ { time = 1, day = 1, median = 10, low = 10, units = 50 }, { time = 2, day = 1, median = 99, low = 99, units = 1 } }).change, nil)

checkTrue("rising and falling filters", ButtonNamed("Rising") ~= nil and ButtonNamed("Falling") ~= nil)

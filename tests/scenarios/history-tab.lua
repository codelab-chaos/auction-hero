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
checkTrue("with its numbers", shows("^1 of 30$"))

for _ = 1, 12 do
	SkipTime(86400)
	Scan()
end
ns.Window:RefreshActive()
Tick(3)
checkTrue("days seen out of the range", shows("^13 of 30$"))

MOUSE_OVER = true
Tick(3)
checkTrue("hovering reads out a scan", shows("usual .* lowest .* for sale"))
MOUSE_OVER = false
Tick(3)
checkTrue("leaving restores the prompt", shows("^Hover a chart"))

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
check("the most for sale at one point", thin.most, 30)
checkTrue("how many scans found the item, and the most at once", shows("^Seen in %d+ of 13 scans, at most [%d,]+ at once$"))

-- From the Buy tab, a right click on an item offers its graph.
ShowTab("buy")
local row = Frames(function(frame)
	return frame.data ~= nil and frame.data.key ~= nil and frame.data.tiers ~= nil and frame.scripts.OnMouseUp ~= nil
end)[3]
local picked = row.data
row.scripts.OnMouseUp(row, "RightButton")
local graph = ButtonNamed("View graph")
checkTrue("the menu offers the graph", graph ~= nil)
graph.scripts.OnClick(graph)
check("picking it closes the menu", ButtonNamed("View graph"), nil)
Tick(5)
check("it opens the Graphs tab", AuctionHeroCharDB.tab, "history")
local named = Frames(function(frame)
	return frame.data ~= nil and frame.data.item ~= nil
end)
checkTrue("with the list narrowed to the item", #named >= 1)
for _, shown in ipairs(named) do
	checkTrue("by its name", shown.data.item.name:lower():find(picked.name:lower(), 1, true) ~= nil)
end
checkTrue("and its name in the search box", #Frames(function(frame)
	return frame.placeholder ~= nil and frame.text == picked.name
end) == 1)

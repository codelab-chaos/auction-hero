-- Dragging the line between two list columns moves that line and no other.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("auctions")

local grips = Frames(function(frame)
	return frame.scripts.OnMouseDown and frame.scripts.OnEnter and frame.w == ns.Theme.sizerWidth and frame.h ~= nil
end)
table.sort(grips, function(a, b)
	return a.lastPoint[2] < b.lastPoint[2]
end)
checkTrue("there is a grip between the columns", #grips >= 3)
local function positions()
	local at = {}
	for index, grip in ipairs(grips) do
		at[index] = grip.lastPoint[2]
	end
	return at
end
local function drag(grip, pixels)
	CURSOR_X = 500
	MOUSE_DOWN = true
	grip.scripts.OnMouseDown(grip)
	CURSOR_X = 500 + pixels
	grip.scripts.OnUpdate(grip)
	MOUSE_DOWN = false
	grip.scripts.OnUpdate(grip)
end

for index = 2, 3 do
	local before = positions()
	drag(grips[index], 20)
	local after = positions()
	check("separator " .. index .. " follows the mouse", after[index] - before[index], 20)
	for other = 1, #grips do
		if other ~= index then
			check("separator " .. other .. " stays put", after[other], before[other])
		end
	end
end

local saved = ns.charDb.columnWidths.auctions
checkTrue("dragged widths are remembered for the character", next(saved) ~= nil)
for _, width in pairs(saved) do
	checkTrue("no column goes under the minimum", width >= ns.Theme.columnMin)
end

-- A column cannot be squeezed under its minimum, however far the drag goes.
drag(grips[#grips], -2000)
drag(grips[1], 2000)
for _, width in pairs(saved) do
	checkTrue("still not under the minimum", width >= ns.Theme.columnMin and width <= ns.Theme.columnMax)
end

-- The Buy list's number columns are fixed: only the item's name stretches.
ShowTab("buy")
ns.charDb.columnWidths.buy.deal = 400 -- a width dragged before the column was fixed
ns.Window:RefreshActive()
Tick(2)
local dollar = Frames(function(frame)
	return frame.label and frame.label.text == "$"
end)
check("the deals column is headed with a dollar sign", #dollar, 1)
check("and stays compact despite an old dragged width", dollar[1].w, 32)

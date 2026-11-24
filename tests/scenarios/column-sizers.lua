-- List columns: dragging a line moves that line and no other, wherever the
-- stretchy column is; near the width its text needs, a column snaps to it; a
-- double click fits it to its text; a right click on a heading resets all.
-- Widths kept by the earlier way of sizing are dropped once.
AuctionHeroCharDB = { columnWidths = { auctions = { name = 2000, buyout = 400 } } }
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("auctions")

local saved = ns.charDb.columnWidths.auctions
check("widths from the earlier way are dropped", next(saved), nil)

local function Grips()
	local grips = Frames(function(frame)
		return frame.scripts.OnMouseDown and frame.scripts.OnEnter and frame.w == ns.Theme.sizerWidth and frame.h ~= nil
	end)
	table.sort(grips, function(a, b)
		return a.lastPoint[2] < b.lastPoint[2]
	end)
	return grips
end
local grips = Grips()
local header = grips[1]:GetParent()
local headings = Frames(function(frame)
	return frame.label ~= nil and frame.scripts.OnClick ~= nil and frame:GetParent() == header and frame:IsShown()
end)
checkTrue("a grip on every line between columns", #grips == #headings - 1 and #grips >= 4)

local function Positions()
	local at = {}
	for index, grip in ipairs(grips) do
		at[index] = grip.lastPoint[2]
	end
	return at
end
local now = 100
GetTime = function() return now end
local function Drag(grip, pixels)
	now = now + 1 -- no double click
	CURSOR_X = 500
	MOUSE_DOWN = true
	grip.scripts.OnMouseDown(grip)
	CURSOR_X = 500 + pixels
	grip.scripts.OnUpdate(grip)
	MOUSE_DOWN = false
	grip.scripts.OnUpdate(grip)
end

-- Every line, the name's own included, follows the mouse; no other moves.
-- (Snapping is tested on its own below.)
local snap = ns.Theme.columnSnap
ns.Theme.columnSnap = 0
for index = 1, #grips - 1 do
	local before = Positions()
	Drag(grips[index], 4) -- within what the squeezed 400 pixel list has to give
	local after = Positions()
	check("line " .. index .. " follows the mouse", after[index] - before[index], 4)
	for other = 1, #grips do
		if other ~= index then
			check("line " .. other .. " stays put while " .. index .. " moves", after[other], before[other])
		end
	end
end
ns.Theme.columnSnap = snap
checkTrue("the widths set are remembered for the character", next(saved) ~= nil)

-- However far a drag goes, no column goes under its minimum and the row
-- stays inside the list.
Drag(grips[2], 3000)
Drag(grips[3], -3000)
for _, width in pairs(saved) do
	checkTrue("no column under the minimum", width >= ns.Theme.columnMin)
end
grips = Grips()
checkTrue("the row stays inside the list", grips[#grips].lastPoint[2] <= SCROLLBOX:GetWidth())

-- A right click on a heading puts every width back.
headings[1].scripts.OnClick(headings[1], "RightButton")
check("a right click on a heading resets every width", next(saved), nil)

-- Dragging near the width the text needs snaps to it.
grips = Grips()
local quantity
for _, heading in ipairs(headings) do
	if heading.label.text == ns.L.AUCTIONS_COL_QUANTITY then
		quantity = heading
	end
end
local start = quantity.w
-- Find the text's width by fitting first, then come back and drag near it.
local function GripAfter(heading)
	for _, grip in ipairs(Grips()) do
		if math.abs(grip.lastPoint[2] - (heading.lastPoint[2] + heading.w)) <= ns.Theme.sizerWidth then
			return grip
		end
	end
end
local grip = GripAfter(quantity)
now = now + 1
grip.scripts.OnMouseDown(grip)
now = now + 0.2
grip.scripts.OnMouseDown(grip)
local fits = quantity.w
checkTrue("a double click fits the column to its text", fits ~= start and saved.quantity == fits)
headings[1].scripts.OnClick(headings[1], "RightButton")
grip = GripAfter(quantity)
Drag(grip, fits - quantity.w - (ns.Theme.columnSnap - 2))
check("a drag that ends near the text's width snaps to it", quantity.w, fits)

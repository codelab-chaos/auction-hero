-- loads: ui/column-layout.lua
-- The column layout solver: CSS flexbox's sharing of a row, then columns
-- leaving by priority. First worked examples, then guarantees checked over
-- thousands of random rows.
local CL = NS.ColumnLayout
local GAP = 8

local function Sum(widths, specs)
	local total, count = 0, 0
	for index, spec in ipairs(specs) do
		if widths[index] > 0 then
			total, count = total + widths[index], count + 1
		end
	end
	return total, count
end

do -- A stretchy name column takes what the fixed ones leave.
	local specs = {
		{ basis = 60, min = 60, grow = 1, shrink = 1 },
		{ basis = 80, min = 80, max = 80 },
		{ basis = 50, min = 50, max = 50 },
	}
	local widths = CL.Solve(specs, 500, GAP)
	check("the others keep their widths", widths[2] .. "," .. widths[3], "80,50")
	check("the name fills the rest", widths[1], 500 - GAP * 4 - 80 - 50)
end

do -- Room is shared by grow weight, and a column at its max hands on the rest.
	local specs = {
		{ basis = 0, grow = 1 },
		{ basis = 0, grow = 3 },
	}
	local widths = CL.Solve(specs, 400 + GAP * 3, GAP)
	check("by weight, one to three", widths[1] .. "," .. widths[2], "100,300")
	specs[2].max = 200
	widths = CL.Solve(specs, 400 + GAP * 3, GAP)
	check("a column at its max hands the rest on", widths[1] .. "," .. widths[2], "200,200")
end

do -- Too little room: wide columns give up more, none below its min.
	local specs = {
		{ basis = 300, min = 50, shrink = 1 },
		{ basis = 100, min = 50, shrink = 1 },
	}
	local widths = CL.Solve(specs, 200 + GAP * 3, GAP)
	check("shrunk by width", widths[1] .. "," .. widths[2], "150,50")
	widths = CL.Solve(specs, 60 + GAP * 3, GAP)
	check("never below a min", widths[1] .. "," .. widths[2], "50,50")
end

do -- Out of room: the lowest priority leaves first, before anything is squeezed.
	local specs = {
		{ basis = 100, min = 100, grow = 1, shrink = 1 },
		{ basis = 80, min = 80, priority = 2 },
		{ basis = 80, min = 80, priority = 1 },
		{ basis = 80, min = 80 },
	}
	local widths, dropped = CL.Solve(specs, 100 + 80 + 80 + GAP * 4, GAP)
	checkTrue("priority 1 left", dropped[3])
	check("only it", (dropped[2] or false), false)
	check("its width is 0", widths[3], 0)
	check("the rest fit exactly", (Sum(widths, specs)), 100 + 80 + 80)
	widths, dropped = CL.Solve(specs, 100 + 80 + GAP * 3, GAP)
	checkTrue("then priority 2", dropped[2] and dropped[3])
	widths, dropped = CL.Solve(specs, 50, GAP)
	check("a column with no priority never leaves", widths[1] > 0 and widths[4] > 0, true)
end

do -- A hidden column takes no room and no gap.
	local specs = { { basis = 10, grow = 1 }, { basis = 50, hidden = true } }
	local widths = CL.Solve(specs, 100, GAP)
	check("hidden is 0", widths[2], 0)
	check("the other has its room and one gap each side", widths[1], 100 - GAP * 2)
end

do -- Columns that could shrink stay at their width while one with a priority can leave.
	local specs = {
		{ basis = 100, min = 60, grow = 1, shrink = 1 },
		{ basis = 110, min = 28, shrink = 1 },
		{ basis = 110, min = 28, shrink = 1, priority = 1 },
	}
	local widths, dropped = CL.Solve(specs, 100 + 110 + 100 + GAP * 4, GAP)
	checkTrue("the priority column stepped aside", dropped[3])
	check("the other kept its readable width", widths[2], 110)
end

-- ========= Moving a line ===================================================
-- A row: name (stretchy) | qty | price | an icon column (fixed) | time
local function Row()
	return {
		{ basis = 60, min = 60, grow = 1, shrink = 1 },
		{ basis = 50, min = 28, max = 420, shrink = 1 },
		{ basis = 90, min = 28, max = 420, shrink = 1 },
		{ basis = 18, min = 18, max = 18, fixed = true },
		{ basis = 70, min = 28, max = 420, shrink = 1 },
	}
end
local AVAILABLE = 500

-- The x of the line after each column, from widths.
local function Lines(widths)
	local lines, x = {}, GAP
	for index, width in ipairs(widths) do
		if width > 0 then
			x = x + width
			lines[index] = x
			x = x + GAP
		end
	end
	return lines
end

-- Moves a line and lays the row out again with the widths set.
local function Move(specs, edge, delta, fits, snap)
	local widths = CL.Solve(specs, AVAILABLE, GAP)
	local set, used = CL.MoveEdge(specs, widths, edge, delta, fits, snap)
	for index, size in pairs(set or {}) do
		specs[index].basis, specs[index].grow, specs[index].shrinkLast = size, 0, true
	end
	return widths, CL.Solve(specs, AVAILABLE, GAP), used
end

do -- The line between two plain columns: the stretchy column is on the left.
	local specs = Row()
	local before, after, used = Move(specs, 2, 20)
	local was, now = Lines(before), Lines(after)
	check("the line follows the mouse", now[2] - was[2], 20)
	check("by the whole drag", used, 20)
	check("the line before it stays", now[1], was[1])
	check("the lines after it stay", now[3] .. "," .. now[5], was[3] .. "," .. was[5])
	check("the left column took it", after[2], before[2] + 20)
	check("the right column gave it", after[3], before[3] - 20)
end

do -- The stretchy column's own line: the next resizable column gives the room.
	local specs = Row()
	local before, after = Move(specs, 1, 15)
	local was, now = Lines(before), Lines(after)
	check("the name's line follows the mouse", now[1] - was[1], 15)
	check("the lines further on stay", now[3] .. "," .. now[5], was[3] .. "," .. was[5])
end

do -- The stretchy column on the right of the line gives the room itself.
	local specs = Row()
	table.insert(specs, 1, { basis = 40, min = 28, max = 420, shrink = 1 }) -- a column before the name
	local before, after = Move(specs, 1, 25)
	local was, now = Lines(before), Lines(after)
	check("the line follows the mouse", now[1] - was[1], 25)
	check("the name gave the room", after[2], before[2] - 25)
	check("everything after the name stays", now[3] .. "," .. now[6], was[3] .. "," .. was[6])
end

do -- A fixed icon column is stepped over: the next resizable column gives.
	local specs = Row()
	local before, after = Move(specs, 3, 10) -- the line between price and the icon
	check("price took it", after[3], before[3] + 10)
	check("the icon kept its width", after[4], 18)
	check("time gave it", after[5], before[5] - 10)
end

do -- Limits: neither side goes past its min.
	local specs = Row()
	local before, after, used = Move(specs, 2, 999)
	check("the right column stops at its min", after[3], 28)
	check("so the drag stops there", used, before[3] - 28)
	specs = Row()
	before, after, used = Move(specs, 2, -999)
	check("the left column stops at its min", after[2], 28)
end

do -- Snapping to the width the text needs.
	local specs = Row()
	local widths = CL.Solve(specs, AVAILABLE, GAP)
	local _, used = CL.MoveEdge(specs, widths, 2, 17, widths[2] + 20, 6)
	check("within reach, it snaps to the text", used, 20)
	_, used = CL.MoveEdge(specs, widths, 2, 10, widths[2] + 20, 6)
	check("further off, it does not", used, 10)
end

do -- Nothing resizable on one side: the line cannot move.
	local specs = { { basis = 50, min = 50, max = 50, fixed = true }, { basis = 60, min = 60, grow = 1 } }
	local widths = CL.Solve(specs, 300, GAP)
	check("no column to take it", CL.MoveEdge(specs, widths, 1, 10), nil)
end

-- ========= Guarantees over random rows =====================================
local seed = 424242
local function Random(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n
end

local bad
for trial = 1, 3000 do
	local specs = {}
	for index = 1, 1 + Random(9) do
		local min = Random(60)
		local spec = { basis = Random(250), min = min, max = Random(3) == 0 and min + Random(200) or nil }
		if Random(3) == 0 then spec.grow = 1 + Random(3) end
		if Random(3) > 0 then spec.shrink = 1 + Random(2) end
		if Random(3) == 0 then spec.priority = Random(5) end
		if Random(8) == 0 then spec.hidden = true end
		if Random(4) == 0 then spec.shrinkLast = true end
		specs[index] = spec
	end
	local available = Random(1200)
	local widths, dropped = CL.Solve(specs, available, GAP)
	local total, count = Sum(widths, specs)
	local space = available - GAP * (count + 1)
	for index, spec in ipairs(specs) do
		local inRow = not spec.hidden and not dropped[index]
		if inRow and (widths[index] < math.floor(spec.min or 0) or (spec.max and widths[index] > spec.max + 1)) then
			bad = bad or ("trial " .. trial .. ": column " .. index .. " outside its limits")
		end
		if not inRow and widths[index] ~= 0 then
			bad = bad or ("trial " .. trial .. ": a column out of the row has width")
		end
		if dropped[index] and spec.priority == nil then
			bad = bad or ("trial " .. trial .. ": a column with no priority left the row")
		end
	end
	-- A column steps aside only when the row did not fit with it at the
	-- widths its columns start from.
	for index in pairs(dropped) do
		local need, columns = 0, 0
		for other, spec in ipairs(specs) do
			if not spec.hidden and (widths[other] > 0 or other == index) then
				local start = math.max(spec.min or 0, spec.basis or 0)
				if spec.max then start = math.min(start, math.max(spec.max, spec.min or 0)) end
				need, columns = need + start, columns + 1
			end
		end
		if need + GAP * (columns + 1) <= available then
			bad = bad or ("trial " .. trial .. ": column " .. index .. " stepped aside though the row fit")
		end
	end
	-- Room left over while a growing column is under its max: not shared out.
	if total < space - count then
		for index, spec in ipairs(specs) do
			if widths[index] > 0 and (spec.grow or 0) > 0 and (not spec.max or widths[index] < spec.max - 1) then
				bad = bad or ("trial " .. trial .. ": room left while column " .. index .. " could grow")
			end
		end
	end
	-- A shrinkLast column under its basis while a plain one is over its min.
	for index, spec in ipairs(specs) do
		if widths[index] > 0 and spec.shrinkLast and widths[index] < math.max(spec.min or 0, math.min(spec.basis or 0, spec.max or math.huge)) - 1 then
			for other, plain in ipairs(specs) do
				if widths[other] > 0 and (plain.shrink or 0) > 0 and not plain.shrinkLast and widths[other] > (plain.min or 0) + 1 then
					bad = bad or ("trial " .. trial .. ": a set width gave way before column " .. other)
				end
			end
		end
	end
	-- Over the row while something could still give: not taken.
	if total > space + count then
		for index, spec in ipairs(specs) do
			if widths[index] > 0 and (spec.shrink or 0) > 0 and widths[index] > (spec.min or 0) + 1 then
				bad = bad or ("trial " .. trial .. ": overflow while column " .. index .. " could shrink")
			end
			if widths[index] > 0 and spec.priority ~= nil then
				bad = bad or ("trial " .. trial .. ": overflow while column " .. index .. " could leave")
			end
		end
	end
end
check("every random row keeps every guarantee", bad, nil)

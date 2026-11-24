-- Column layout: how wide each column of a list is. Only numbers in and out,
-- nothing of the game's, so it can be tested on its own
-- (tests/unit/column-layout.lua). Kit.List describes its columns, asks, and
-- draws what comes back.
--
-- It is CSS flexbox's way of sharing a row, which data grids use too:
--   1. Each column starts at its basis, kept between its min and max.
--   2. Room left over goes to the columns that grow, by their grow weight.
--      One that reaches its max stops, and the rest share what remains.
--   3. Too little room: columns that shrink give it up, by their shrink
--      weight times their width (wide ones give more), each down to its min;
--      columns marked shrinkLast only after all the others are at theirs.
--   Before 3: when the columns do not fit at their starting widths, the
--      column with the lowest priority leaves the row first (it is hidden,
--      not squashed), and the row is shared again, until none with a
--      priority is left or they fit. Only then do columns shrink, so what
--      stays is readable. Columns without a priority never leave.
--
-- A column (a "spec"):
--   basis       its starting width
--   min, max    how narrow and how wide it may be (max may be nil: no limit)
--   grow        its share of room left over; 0 or nil for none
--   shrink      its share of room taken when short; 0 or nil for none
--   shrinkLast  it gives room only once the others are at their min (a width
--               the player set, so the edge they dragged stays put)
--   priority    the higher, the longer it stays when room runs out; nil: always
--   hidden      true when it is not in the row at all (empty, say)
local _, ns = ...

local ColumnLayout = {}
ns.ColumnLayout = ColumnLayout

local EPSILON = 0.01

local function Clamp(value, low, high)
	if high and value > high then
		value = high
	end
	if low and value < low then
		value = low
	end
	return value
end

-- Shares `free` (positive: room to hand out, negative: room to take) among
-- the columns in `active`, by weight(index), keeping each within its limits.
-- Columns that hit a limit are frozen and the rest share what is left, as
-- CSS flexbox resolves flexible lengths.
local function Share(specs, widths, active, free, weight)
	local frozen = {}
	for _ = 1, #specs + 1 do
		if math.abs(free) < EPSILON then
			break
		end
		local total = 0
		for index in pairs(active) do
			if not frozen[index] then
				total = total + weight(index)
			end
		end
		if total <= 0 then
			break
		end
		local moved = 0
		for index in pairs(active) do
			if not frozen[index] then
				local spec = specs[index]
				local wanted = widths[index] + free * weight(index) / total
				local width = Clamp(wanted, spec.min, spec.max)
				if width ~= wanted then
					frozen[index] = true
				end
				moved = moved + (width - widths[index])
				widths[index] = width
			end
		end
		free = free - moved
		if moved == 0 then
			break
		end
	end
	return free
end

-- The widths of the columns sharing `available` pixels with `gap` between
-- and around them. Returns widths (by index, 0 for a column not in the row,
-- whole pixels) and the set of indexes that left the row for lack of room.
function ColumnLayout.Solve(specs, available, gap)
	gap = gap or 0
	local dropped = {}
	while true do
		local widths, inRow, count = {}, {}, 0
		for index, spec in ipairs(specs) do
			if not spec.hidden and not dropped[index] then
				inRow[index] = true
				count = count + 1
				widths[index] = Clamp(spec.basis or 0, spec.min, spec.max)
			else
				widths[index] = 0
			end
		end
		local space = available - gap * (count + 1)
		local used = 0
		for index in pairs(inRow) do
			used = used + widths[index]
		end
		local free = space - used
		-- Short even before anything shrinks: a column with a priority steps
		-- aside before the others are squeezed, so what stays is readable.
		local leaving
		if free < -EPSILON then
			for index in pairs(inRow) do
				local priority = specs[index].priority
				if priority and (not leaving or priority < specs[leaving].priority) then
					leaving = index
				end
			end
		end
		if leaving then
			dropped[leaving] = true
		elseif free > 0 then
			local growing = {}
			for index in pairs(inRow) do
				if (specs[index].grow or 0) > 0 then
					growing[index] = true
				end
			end
			Share(specs, widths, growing, free, function(index)
				return specs[index].grow
			end)
		elseif free < 0 then
			-- Columns that shrink give room first; ones marked shrinkLast (a
			-- width the player set) only once the others are at their min.
			for _, last in ipairs({ false, true }) do
				if free < 0 then
					local shrinking, start = {}, {}
					for index in pairs(inRow) do
						if (specs[index].shrink or 0) > 0 and (specs[index].shrinkLast or false) == last then
							shrinking[index] = true
							start[index] = math.max(1, widths[index]) -- weighted by the width it started from, as CSS does
						end
					end
					free = Share(specs, widths, shrinking, free, function(index)
						return specs[index].shrink * start[index]
					end)
				end
			end
		end
		if not leaving then
			-- Whole pixels; what rounding loses goes to the last column that grows.
			local spare, lastGrowing = 0, nil
			for index = 1, #specs do
				if inRow[index] then
					local whole = math.floor(widths[index])
					spare = spare + widths[index] - whole
					widths[index] = whole
					if (specs[index].grow or 0) > 0 then
						lastGrowing = index
					end
				end
			end
			if lastGrowing and free >= 0 then
				widths[lastGrowing] = widths[lastGrowing] + math.floor(spare + 0.5)
			end
			return widths, dropped
		end
	end
end

-- Moving the line after column `edge` by `delta` pixels, from `widths` (as
-- Solve gave them), as a splitter does: only the columns on its two sides
-- change, so the line stays under the mouse and the row keeps its width.
--   on the left   the nearest resizable column at or before the line grows
--                 (or shrinks) by delta
--   on the right  the room comes from the growing column when there is one
--                 there (it takes up the difference by itself), else from the
--                 nearest resizable column after the line
-- delta is held so that neither goes past its min or max, and snapped so the
-- left column lands on `fits` (the width its text needs) when it comes within
-- `snap` pixels of it.
-- Returns the widths to set ({ [index] = width }, the growing column left
-- out) and the delta used, or nil when the line cannot move (nothing
-- resizable on one side). A spec marked fixed is not resizable.
function ColumnLayout.MoveEdge(specs, widths, edge, delta, fits, snap)
	local function InRow(index)
		return specs[index] and not specs[index].hidden and (widths[index] or 0) > 0
	end
	local function Resizable(index)
		return InRow(index) and not specs[index].fixed
	end
	local left
	for index = edge, 1, -1 do
		if Resizable(index) then
			left = index
			break
		end
	end
	local right, growing
	for index = edge + 1, #specs do
		if InRow(index) and (specs[index].grow or 0) > 0 and not specs[index].fixed then
			right, growing = index, true
			break
		end
	end
	if not right then
		for index = edge + 1, #specs do
			if Resizable(index) then
				right = index
				break
			end
		end
	end
	if not left or not right then
		return nil
	end
	local a, b = widths[left], widths[right]
	local leftSpec, rightSpec = specs[left], specs[right]
	local function Hold(d)
		-- The left column within its limits, the right one within its own.
		local low = math.max((leftSpec.min or 0) - a, b - (rightSpec.max or math.huge))
		local high = math.min((leftSpec.max or math.huge) - a, b - (rightSpec.min or 0))
		if high < low then
			return 0
		end
		return math.max(low, math.min(high, d))
	end
	local d = Hold(delta)
	if fits and snap and math.abs(a + d - fits) <= snap then
		d = Hold(fits - a)
	end
	d = math.floor(d + 0.5)
	local set = { [left] = a + d }
	if not growing then
		set[right] = b - d
	end
	return set, d
end

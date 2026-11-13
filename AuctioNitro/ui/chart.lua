-- Charts for the History tab, drawn from the game's own primitives: lines,
-- textures and text. The lab's lab/src/ui/chart.ts carried over.
--
-- A chart is made once and redrawn with :Draw. Its lines, bars and labels are
-- kept and reused, so redrawing does not create new ones each time.
local _, ns = ...
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local Chart = {}
ns.Chart = Chart

local SECONDS_PER_DAY = 86400
local LEFT, RIGHT, TOP = 58, 12, 8 -- room around the plot for labels

-- Copper as short plain text for an axis: 12g, 3s 40c, 85c.
local function AxisMoney(copper)
	copper = math.floor(copper + 0.5)
	local gold = math.floor(copper / 10000)
	local silver = math.floor(copper / 100) % 100
	local rest = copper % 100
	if gold >= 10 then
		return ns.Comma(gold) .. "g"
	elseif gold > 0 then
		return silver > 0 and (gold .. "g " .. silver .. "s") or (gold .. "g")
	elseif silver > 0 then
		return rest > 0 and (silver .. "s " .. rest .. "c") or (silver .. "s")
	end
	return rest .. "c"
end
Chart.AxisMoney = AxisMoney

function Chart.DayLabel(day)
	return date("%b %d", day * SECONDS_PER_DAY + SECONDS_PER_DAY / 2)
end

-- A round number at or above a value, so the top grid line is a tidy figure.
local function NiceCeiling(value)
	if value <= 0 then
		return 1
	end
	local power = 10 ^ math.floor(math.log(value) / math.log(10))
	for _, step in ipairs({ 1, 2, 2.5, 5, 10 }) do
		if step * power >= value then
			return step * power
		end
	end
	return 10 * power
end

-- options: width, height, gridLines, dates (show the dates under the plot),
--   format(value) for the axis labels,
--   onHover(point | nil): called as the mouse moves over the plot
-- Returns the frame, with :Draw(points, marks) where marks is either
--   { lines = { { color, value = function(point) } ... } } or
--   { bars = { color, value = function(point) } }
function Chart.New(parent, options)
	local chart = CreateFrame("Frame", nil, parent)
	chart:SetSize(options.width, options.height)
	local bottom = options.dates and 18 or 4
	local plotWidth = options.width - LEFT - RIGHT
	local plotHeight = options.height - TOP - bottom
	local pools = { line = {}, box = {}, label = {} }
	local used = { line = 0, box = 0, label = 0 }
	local drawn -- { points, x = function(day) } for the hover

	local function Reset()
		for kind, pool in pairs(pools) do
			for _, object in ipairs(pool) do
				object:Hide()
			end
			used[kind] = 0
		end
	end

	local function Line(color, thickness, x1, y1, x2, y2)
		used.line = used.line + 1
		local line = pools.line[used.line]
		if not line then
			line = chart:CreateLine(nil, "ARTWORK")
			pools.line[used.line] = line
		end
		line:SetColorTexture(unpack(color))
		line:SetThickness(thickness)
		line:SetStartPoint("BOTTOMLEFT", chart, x1, y1)
		line:SetEndPoint("BOTTOMLEFT", chart, x2, y2)
		line:Show()
	end

	local function Box(color, x, y, width, height, layer)
		used.box = used.box + 1
		local box = pools.box[used.box]
		if not box then
			box = chart:CreateTexture(nil, "ARTWORK")
			pools.box[used.box] = box
		end
		box:SetDrawLayer(layer or "ARTWORK")
		box:SetColorTexture(unpack(color))
		box:ClearAllPoints()
		box:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x, y)
		box:SetSize(math.max(1, width), math.max(1, height))
		box:Show()
	end

	local function Label(text, justify, point, x, y)
		used.label = used.label + 1
		local label = pools.label[used.label]
		if not label then
			label = Kit.Text(chart, "small", C.muted)
			pools.label[used.label] = label
		end
		label:SetJustifyH(justify)
		label:ClearAllPoints()
		label:SetPoint(point, chart, "BOTTOMLEFT", x, y)
		label:SetText(text)
		label:Show()
	end

	-- The vertical guide that follows the mouse.
	local guide = chart:CreateTexture(nil, "OVERLAY")
	guide:SetColorTexture(C.text[1], C.text[2], C.text[3], 0.5)
	guide:SetSize(1, plotHeight)
	guide:Hide()

	function chart:Draw(points, marks)
		Reset()
		drawn = nil
		guide:Hide()
		if #points == 0 then
			return
		end
		local series = marks.lines or { marks.bars }
		local highest = 1
		for _, point in ipairs(points) do
			for _, entry in ipairs(series) do
				highest = math.max(highest, entry.value(point))
			end
		end
		local top = NiceCeiling(marks.lines and highest * 1.05 or highest)
		local firstDay, lastDay = points[1].day, points[#points].day
		local span = math.max(1, lastDay - firstDay)
		local function X(day)
			return LEFT + (day - firstDay) / span * plotWidth
		end
		local function Y(value)
			return bottom + value / top * plotHeight
		end

		-- Quiet grid lines with their values, so the data carries the picture.
		local gridLines = options.gridLines or 4
		for index = 0, gridLines do
			local value = top / gridLines * index
			local y = math.floor(Y(value) + 0.5)
			local color = index == 0 and { C.muted[1], C.muted[2], C.muted[3], 0.7 } or { C.line[1], C.line[2], C.line[3], 0.6 }
			Box(color, LEFT, y, plotWidth, 1, "BACKGROUND")
			Label(options.format(value), "RIGHT", "RIGHT", LEFT - 6, y)
		end
		if options.dates then
			Label(Chart.DayLabel(firstDay), "LEFT", "BOTTOMLEFT", LEFT, 0)
			Label(Chart.DayLabel(lastDay), "RIGHT", "BOTTOMRIGHT", LEFT + plotWidth, 0)
			if #points > 2 then
				Label(Chart.DayLabel(math.floor((firstDay + lastDay) / 2 + 0.5)), "CENTER", "BOTTOM", LEFT + plotWidth / 2, 0)
			end
		end

		if marks.lines then
			-- Straight segments between the points, and a small square at each.
			for _, entry in ipairs(marks.lines) do
				for index = 2, #points do
					local from, to = points[index - 1], points[index]
					Line(entry.color, 2, X(from.day), Y(entry.value(from)), X(to.day), Y(entry.value(to)))
				end
				for _, point in ipairs(points) do
					Box(entry.color, X(point.day) - 2, Y(entry.value(point)) - 2, 4, 4, "OVERLAY")
				end
			end
		else
			local width = math.max(2, math.min(14, plotWidth / (span + 1) - 2))
			for _, point in ipairs(points) do
				Box(marks.bars.color, X(point.day) - width / 2, bottom, width, Y(marks.bars.value(point)) - bottom)
			end
		end
		drawn = { points = points, X = X }
	end

	-- Hovering reads the nearest day. Checked each frame while the mouse is over.
	local shown
	chart:SetScript("OnUpdate", function(self)
		if not drawn then
			return
		end
		local nearest
		if self:IsMouseOver() then
			local cursorX = GetCursorPosition() / self:GetEffectiveScale() - (self:GetLeft() or 0)
			for _, point in ipairs(drawn.points) do
				if not nearest or math.abs(drawn.X(point.day) - cursorX) < math.abs(drawn.X(nearest.day) - cursorX) then
					nearest = point
				end
			end
		end
		if nearest ~= shown then
			shown = nearest
			guide:SetShown(nearest ~= nil)
			if nearest then
				guide:ClearAllPoints()
				guide:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", math.floor(drawn.X(nearest.day) + 0.5), bottom)
			end
			if options.onHover then
				options.onHover(nearest)
			end
		end
	end)
	return chart
end

-- History tab: pick an item and see how its price and supply have moved.
-- Two charts that never share an axis: prices as lines, units as bars.
-- The layout and behavior follow the lab's concept (lab/src/ui/concept/history.ts).
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local CHART_WIDTH = 572

local state = {
	range = ns.HistoryDefaultRange,
	search = "",
	selectedKey = nil,
	sort = { id = "units", descending = true },
}

local list, detail, prompt, ranges
local parts = {}
local stack

-- ========= The list =========================================================
-- A row is an item the market has now, with what its history says.
-- Reading every item's history is the costly part, so it is done once per
-- market and range and kept until a scan changes the history. Searching and
-- sorting then work on the kept rows.
local cache = { market = nil, range = nil, rows = {} }

local function AllRows()
	local market = ns.Window:Market()
	if cache.market ~= market or cache.range ~= state.range then
		local rows = {}
		for _, item in ipairs(market and market.items or {}) do
			local points = ns.History:InRange(ns.History:Points(item.key), state.range)
			local summary = ns.History:Summarize(points)
			if summary then
				rows[#rows + 1] = { item = item, search = item.name:lower(), usual = summary.usual, change = summary.change }
			end
		end
		cache.market, cache.range, cache.rows = market, state.range, rows
	end
	return cache.rows
end

ns.Bus:On("HISTORY_CHANGED", function()
	cache.market = nil
end)

local function Rows()
	local search = state.search:lower()
	local rows = {}
	for _, row in ipairs(AllRows()) do
		if search == "" or row.search:find(search, 1, true) then
			rows[#rows + 1] = row
		end
	end
	return rows
end

local SORT_VALUES = {
	name = function(row)
		return row.item.name
	end,
	usual = function(row)
		return row.usual
	end,
	change = function(row)
		return row.change
	end,
	units = function(row)
		return row.item.units
	end,
}

local function PaintList(keepScroll)
	local market, reason = ns.Window:Market()
	list:SetEmptyText(market and L.BUY_NOTHING or reason)
	local rows = Rows()
	Kit.SortRows(rows, SORT_VALUES[state.sort.id], state.sort.descending)
	list:SetSort(state.sort.id, state.sort.descending)
	list:SetRows(rows, keepScroll)
	return rows
end

-- ========= The detail =======================================================
local function Tile(parent, label)
	local tile = CreateFrame("Frame", nil, parent)
	Kit.Fill(tile, C.block)
	Kit.Border(tile, C.line)
	local name = Kit.Text(tile, "small", C.muted)
	name:SetPoint("TOPLEFT", 8, -5)
	name:SetText(label)
	tile.value = Kit.Text(tile, "large", C.text)
	tile.value:SetPoint("BOTTOMLEFT", 8, 6)
	return tile
end

-- What the line under the charts says while no point is hovered.
local resting = L.HISTORY_HOVER

local function SetReadout(point)
	if not point then
		parts.readout:SetText(resting)
		return
	end
	parts.readout:SetText(L.HISTORY_READOUT:format(ns.Chart.TimeLabel(point.time, true), ns.Money(point.median), ns.Money(point.low), ns.Comma(point.units)))
end

local function BuildDetail(parent)
	stack = Kit.Stack(parent, 8)

	prompt = Kit.Note(parent, "normal", C.muted, "CENTER")
	prompt:SetPoint("TOPLEFT", 16, -30)
	prompt:SetPoint("TOPRIGHT", -16, -30)
	prompt:SetWidth(540)

	parts.head = CreateFrame("Frame", nil, parent)
	parts.head:SetHeight(34)
	parts.icon = Kit.Icon(parts.head, 32)
	parts.icon:SetPoint("LEFT")
	parts.name = Kit.Text(parts.head, "normal")
	parts.name:SetPoint("TOPLEFT", 40, -2)
	parts.forSale = Kit.Text(parts.head, "small", C.muted)
	parts.forSale:SetPoint("BOTTOMLEFT", 40, 2)
	local rangeItems = {}
	for _, days in ipairs(ns.HistoryRanges) do
		rangeItems[#rangeItems + 1] = { days = days, label = L.HISTORY_DAYS:format(days) }
	end
	ranges = Kit.Choices(parts.head, {
		items = rangeItems,
		joined = true,
		padding = 14,
		isActive = function(option)
			return option.days == state.range
		end,
		onPick = function(option)
			state.range = option.days
			ns.Window:RefreshActive()
		end,
	})
	ranges:SetPoint("RIGHT")

	-- The headline numbers above the charts.
	parts.tiles = CreateFrame("Frame", nil, parent)
	parts.tiles:SetHeight(42)
	parts.tile = {}
	local labels = { L.HISTORY_USUAL, L.HISTORY_LOWEST, L.HISTORY_HIGHEST, L.HISTORY_CHANGE, L.HISTORY_SEEN }
	local width = (CHART_WIDTH - 4 * 6) / #labels
	for index, label in ipairs(labels) do
		local tile = Tile(parts.tiles, label)
		tile:SetSize(width, 42)
		tile:SetPoint("LEFT", (index - 1) * (width + 6), 0)
		parts.tile[index] = tile
	end

	-- The price chart's heading carries its legend: a swatch and name per line.
	parts.priceHead = CreateFrame("Frame", nil, parent)
	parts.priceHead:SetHeight(16)
	local priceLabel = Kit.Text(parts.priceHead, "normal", C.accent)
	priceLabel:SetPoint("LEFT")
	priceLabel:SetText(L.HISTORY_PRICE)
	local right
	for index = #ns.HistorySeries, 1, -1 do
		local entry = ns.HistorySeries[index]
		local name = Kit.Text(parts.priceHead, "small", C.text, "RIGHT")
		if right then
			name:SetPoint("RIGHT", right, "LEFT", -12, 0)
		else
			name:SetPoint("RIGHT")
		end
		name:SetText(entry.label)
		local swatch = parts.priceHead:CreateTexture(nil, "ARTWORK")
		swatch:SetColorTexture(unpack(entry.color))
		swatch:SetSize(10, 3)
		swatch:SetPoint("RIGHT", name, "LEFT", -5, 0)
		right = swatch
	end

	parts.price = CreateFrame("Frame", nil, parent)
	parts.price:SetHeight(190)
	parts.priceChart = ns.Chart.New(parts.price, {
		width = CHART_WIDTH,
		height = 190,
		dates = true,
		format = ns.Chart.AxisMoney,
		onHover = SetReadout,
	})
	parts.priceChart:SetPoint("TOPLEFT")

	parts.unitsHead = CreateFrame("Frame", nil, parent)
	parts.unitsHead:SetHeight(16)
	local unitsLabel = Kit.Text(parts.unitsHead, "normal", C.accent)
	unitsLabel:SetPoint("LEFT")
	unitsLabel:SetText(L.HISTORY_FOR_SALE)

	parts.units = CreateFrame("Frame", nil, parent)
	parts.units:SetHeight(84)
	parts.unitsChart = ns.Chart.New(parts.units, {
		width = CHART_WIDTH,
		height = 84,
		gridLines = 2,
		format = function(value)
			return ns.Comma(value)
		end,
		onHover = SetReadout,
	})
	parts.unitsChart:SetPoint("TOPLEFT")

	parts.readoutRow = CreateFrame("Frame", nil, parent)
	parts.readoutRow:SetHeight(16)
	parts.readout = Kit.Text(parts.readoutRow, "small", C.muted)
	parts.readout:SetPoint("LEFT")
end

local function PaintDetail(rows)
	stack:Reset()
	local market = ns.Window:Market()
	local item = market and state.selectedKey and market.byKey[state.selectedKey]
	prompt:SetShown(item == nil)
	if not item then
		prompt:SetBody(L.HISTORY_PICK)
		return
	end

	parts.icon:SetIcon(item.icon)
	parts.name:SetText(item.name)
	parts.name:SetTextColor(unpack(Kit.QualityColor(item.quality)))
	parts.forSale:SetText(L.HISTORY_NOW:format(ns.Comma(item.units)))
	ranges:Refresh()
	stack:Add(parts.head)

	local points = ns.History:InRange(ns.History:Points(item.key), state.range)
	local summary = ns.History:Summarize(points)
	if not summary then
		prompt:SetBody(L.HISTORY_NONE)
		prompt:ClearAllPoints()
		prompt:SetPoint("TOPLEFT", 16, -80)
		prompt:SetPoint("TOPRIGHT", -16, -80)
		prompt:Show()
		return
	end

	local change = summary.change
	parts.tile[1].value:SetText(ns.Money(summary.usual))
	parts.tile[2].value:SetText(ns.Money(summary.lowest))
	parts.tile[3].value:SetText(ns.Money(summary.highest))
	parts.tile[4].value:SetText(change and ((change > 0 and "+" or "") .. change .. "%") or "")
	parts.tile[4].value:SetTextColor(unpack((not change or change == 0) and C.text or (change > 0 and C.good or C.bad)))
	parts.tile[5].value:SetText(L.HISTORY_SEEN_OF:format(summary.days, state.range))
	stack:Add(parts.tiles, 8)

	stack:Add(parts.priceHead, 10)
	stack:Add(parts.price, 2)
	parts.priceChart:Draw(points, { lines = ns.HistorySeries })
	stack:Add(parts.unitsHead, 4)
	stack:Add(parts.units, 2)
	parts.unitsChart:Draw(points, { bars = ns.HistoryUnits })
	-- A scan or two is a start, not a trend. Say so until two days are in.
	resting = summary.days < 2 and L.HISTORY_PRIMING:format(summary.scans) or L.HISTORY_HOVER
	SetReadout(nil)
	stack:Add(parts.readoutRow, 2)
end

-- ========= The tab ==========================================================
local function Refresh()
	local rows = PaintList(true)
	local market = ns.Window:Market()
	if state.selectedKey and not (market and market.byKey[state.selectedKey]) then
		state.selectedKey = nil
	end
	-- Start on the busiest item, so the tab opens with something in it.
	if not state.selectedKey and rows[1] then
		local busiest = rows[1]
		for _, row in ipairs(rows) do
			if row.item.units > busiest.item.units then
				busiest = row
			end
		end
		state.selectedKey = busiest.item.key
		list:SetRows(rows, true)
	end
	PaintDetail(rows)
end

local function Create(parent)
	local pad = Theme.pad
	local side = Kit.Panel(parent)
	side:SetPoint("TOPLEFT")
	side:SetPoint("BOTTOMLEFT")
	side:SetWidth(Theme.history.list)
	Kit.Split(side, { id = "history.list", edge = "RIGHT", min = Theme.history.list, max = Theme.history.list + Theme.panelGrow, onChange = function()
		ns.Window:RefreshActive()
	end })

	local search = Kit.Input(side, { height = 26, placeholder = L.BUY_SEARCH, onChange = function(text)
		state.search = text
		PaintList()
	end })
	search:SetPoint("TOPLEFT", 8, -8)
	search:SetPoint("TOPRIGHT", -8, -8)

	list = Kit.List(side, {
		id = "history",
		columns = {
			{
				id = "name",
				label = L.BUY_COL_ITEM,
				flex = true,
				icon = function(row)
					return row.item.icon
				end,
				text = function(row)
					return row.item.name
				end,
				color = function(row)
					return Kit.QualityColor(row.item.quality)
				end,
			},
			{ id = "usual", label = L.HISTORY_COL_USUAL, width = 66, align = "RIGHT", text = function(row)
				return ns.Money(row.usual)
			end },
			{
				id = "change",
				label = L.HISTORY_COL_CHANGE,
				width = 40,
				align = "RIGHT",
				text = function(row)
					return row.change and ((row.change > 0 and "+" or "") .. row.change .. "%") or ""
				end,
				color = function(row)
					if not row.change or row.change == 0 then
						return C.muted
					end
					return row.change > 0 and C.good or C.bad
				end,
			},
		},
		empty = L.BUY_NOTHING,
		onClick = function(row)
			state.selectedKey = row.item.key
			ns.Window:RefreshActive()
		end,
		isSelected = function(row)
			return row.item.key == state.selectedKey
		end,
		link = function(row)
			return row.item.link
		end,
		onSort = function(id)
			if state.sort.id == id then
				state.sort.descending = not state.sort.descending
			else
				state.sort = { id = id, descending = id ~= "name" }
			end
			PaintList()
		end,
	})
	list:SetPoint("TOPLEFT", 8, -40)
	list:SetPoint("BOTTOMRIGHT", -8, 8)

	detail = Kit.Panel(parent)
	detail:SetPoint("TOPLEFT", side, "TOPRIGHT", pad, 0)
	detail:SetPoint("BOTTOMRIGHT")
	BuildDetail(detail)

	return { Refresh = Refresh }
end

ns.Window:RegisterTab({ id = "history", label = L.TAB_HISTORY, order = 6, align = "right", Create = Create })

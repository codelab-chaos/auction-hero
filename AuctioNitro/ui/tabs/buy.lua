-- Buy tab: a rail of quick filters, the category checkboxes, the item list,
-- and an order panel that says what buying a quantity really costs.
-- The layout and behavior follow the lab's concept (lab/src/ui/concept/buy.ts).
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color
local Facets = ns.Facets

local ORDER_LINES = 8 -- price points listed in the order panel
local HEADER_HEIGHT, OPTION_HEIGHT = 26, 21

-- What the player has chosen. Kept for the session.
local state = {
	selection = {}, -- ticked boxes and toggles, see market\facets.lua
	open = {}, -- facet id -> expanded
	search = "",
	toggles = {}, -- quick toggle id -> on
	sort = { id = "units", descending = true },
	selectedKey = nil,
	wanted = 1,
}

local market, facets, listable, makeFilter -- rebuilt when the market changes
local rail, sidebar, toolbar, list, order, prompt, searchBox
local railTiles, sideRows, toggleButtons = {}, {}, {}
local Refresh

-- ========= Filtering ========================================================
local function Prepare()
	local current = ns.Window:Market()
	if facets and current == market then
		return
	end
	market = current
	listable = {}
	if market then
		for _, item in ipairs(market.items) do
			if item.units > 0 then
				listable[#listable + 1] = item
			end
		end
	end
	facets = Facets:Build(listable)
	makeFilter = Facets:Filter(facets)
end

local function FilteredItems()
	local search = state.search:lower()
	local passes = makeFilter(state.selection)
	local gold = GetMoney()
	local dealFrom = ns.DealBadgeRule.percent
	local rows = {}
	for _, item in ipairs(listable) do
		local keep = (search == "" or item.name:lower():find(search, 1, true) ~= nil)
			and (not state.toggles.usableOnly or item.usable)
			and (not state.toggles.dealsOnly or (item.deal ~= nil and item.deal >= dealFrom))
			and (not state.toggles.affordableOnly or (ns.Orders.CheapestAuction(item) or math.huge) <= gold)
			and (passes == nil or passes(item))
		if keep then
			rows[#rows + 1] = item
		end
	end
	return rows
end

-- ========= The rail =========================================================
-- Each tile is a checkbox over a color or an icon, named by its tooltip.
local function Tile(index)
	local tile = railTiles[index]
	if not tile then
		tile = CreateFrame("Button", nil, rail)
		tile.fill = Kit.Fill(tile, C.input)
		tile.art = tile:CreateTexture(nil, "ARTWORK")
		tile.art:SetPoint("TOPLEFT", 1, -1)
		tile.art:SetPoint("BOTTOMRIGHT", -1, 1)
		tile.art:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		tile.border = Kit.Border(tile, C.inputBorder, "OVERLAY")
		tile.mark = tile:CreateTexture(nil, "OVERLAY", nil, 2)
		tile.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		Kit.Tip(tile, function(self)
			return { self.tip }
		end)
		tile:SetScript("OnClick", function(self)
			self.onClick()
		end)
		railTiles[index] = tile
	end
	return tile
end

-- A quality's color, dimmed toward the window when the swatch is off.
local function Dim(color)
	local base = C.window
	return { color[1] * 0.28 + base[1] * 0.72, color[2] * 0.28 + base[2] * 0.72, color[3] * 0.28 + base[3] * 0.72, 1 }
end

local function PaintTile(tile, spec, y)
	local height = spec.swatch and Theme.swatch or Theme.tile
	tile:ClearAllPoints()
	tile:SetPoint("TOP", rail, "TOP", 0, -y)
	tile:SetSize(Theme.tile, height)
	tile.tip = spec.tip
	tile.onClick = spec.onClick
	if spec.swatch then
		tile.art:Hide()
		tile.fill:SetColorTexture(unpack(spec.on and spec.color or Dim(spec.color)))
		tile.border:SetColor(spec.on and C.white or Dim({ spec.color[1] * 2, spec.color[2] * 2, spec.color[3] * 2 }))
		tile.mark:SetVertexColor(0, 0, 0)
		tile.mark:ClearAllPoints()
		tile.mark:SetPoint("CENTER")
		tile.mark:SetSize(16, 16)
	else
		tile.fill:SetColorTexture(unpack(C.input))
		tile.art:SetTexture(spec.icon)
		tile.art:SetShown(spec.icon ~= nil)
		tile.art:SetAlpha(spec.on and 1 or 0.7)
		tile.border:SetColor(spec.on and C.accent or C.inputBorder)
		tile.mark:SetVertexColor(1, 1, 1)
		tile.mark:ClearAllPoints()
		tile.mark:SetPoint("CENTER")
		tile.mark:SetSize(26, 26)
	end
	tile.mark:SetShown(spec.on)
	tile:Show()
	return height
end

local function FacetById(id)
	for _, facet in ipairs(facets) do
		if facet.id == id then
			return facet
		end
	end
end

-- The tiles of one rail entry (see ns.BuyRail in data\facets.lua).
local function TilesFor(entry)
	local specs = {}
	local function Add(key, value, on, spec)
		spec.on = on
		spec.onClick = function()
			Facets.Toggle(state.selection, key, value, not on)
			Refresh()
		end
		specs[#specs + 1] = spec
	end

	if entry.quality then
		local facet = FacetById(ns.QualityFacet.id)
		local ticked = state.selection[facet.id] or {}
		for _, option in ipairs(facet.options) do
			Add(facet.id, option.value, ticked[option.value] == true, {
				swatch = true,
				color = Kit.QualityColor(option.quality),
				tip = L.RAIL_TIP:format(facet.label, option.label),
			})
		end
	elseif entry.refine then
		local facet = FacetById(entry.refine)
		if facet and facet.refineOptions then
			local key = Facets.RefineKey(facet.id)
			local ticked = state.selection[key] or {}
			for _, option in ipairs(facet.refineOptions) do
				Add(key, option.value, ticked[option.value] == true, {
					icon = option.icon,
					tip = L.RAIL_TIP:format(facet.refine.label, option.label),
				})
			end
		end
	elseif entry.box then
		local facet = FacetById(entry.of)
		local ticked = facet and state.selection[facet.id] or {}
		for _, option in ipairs(facet and facet.options or {}) do
			if option.label == entry.box then
				Add(facet.id, option.value, ticked[option.value] == true, { icon = option.icon, tip = option.label })
			end
		end
	end
	return specs
end

local railRules = {}
local function PaintRail()
	for _, tile in ipairs(railTiles) do
		tile:Hide()
	end
	for _, rule in ipairs(railRules) do
		rule:Hide()
	end
	local y, used, rules = 6, 0, 0
	for _, section in ipairs(ns.BuyRail) do
		local specs = {}
		for _, entry in ipairs(section) do
			for _, spec in ipairs(TilesFor(entry)) do
				specs[#specs + 1] = spec
			end
		end
		if #specs > 0 then
			if used > 0 then
				rules = rules + 1
				local rule = railRules[rules]
				if not rule then
					rule = Kit.Rule(rail)
					rule:SetWidth(20)
					railRules[rules] = rule
				end
				rule:ClearAllPoints()
				rule:SetPoint("TOP", rail, "TOP", 0, -(y + 2))
				rule:Show()
				y = y + 8
			end
			for _, spec in ipairs(specs) do
				used = used + 1
				y = y + PaintTile(Tile(used), spec, y) + 4
			end
		end
	end
end

-- ========= The category column =============================================
-- One kind of row draws all three cases: a category header, a box inside an
-- open category, and a "flat" box that sits straight in the column.
local function SideRow(index)
	local row = sideRows[index]
	if not row then
		row = CreateFrame("Button", nil, sidebar.content)
		row.fill = Kit.Gradient(row, C.controlTop, C.controlBottom)
		row.border = Kit.Border(row, C.inputBorder)
		row.hover = Kit.Fill(row, C.rowHover, "BORDER")
		row.hover:Hide()
		row.check = Kit.Check(row, 14)
		row.icon = Kit.Icon(row, 16)
		row.label = Kit.Text(row, "normal", C.text)
		row.caret = Kit.Caret(row)
		row.caret:SetPoint("RIGHT", -7, 0)
		row.count = CreateFrame("Frame", nil, row)
		row.count:SetSize(18, 14)
		row.count:SetPoint("RIGHT", row.caret, "LEFT", -6, 0)
		Kit.Fill(row.count, C.accent)
		row.countText = Kit.Text(row.count, "small", C.panel, "CENTER")
		row.countText:SetAllPoints()
		-- The checkbox of a header has its own click, apart from the expander.
		row.checkZone = CreateFrame("Button", nil, row)
		row.checkZone:SetPoint("TOPLEFT")
		row.checkZone:SetPoint("BOTTOMLEFT")
		row.checkZone:SetWidth(26)
		row.checkZone:SetScript("OnClick", function()
			row.onCheck()
		end)
		row:SetScript("OnClick", function(self)
			self.onClick()
		end)
		row:SetScript("OnEnter", function(self)
			self.hover:SetShown(not self.isHeader)
			if self.isHeader then
				self.border:SetColor(C.activeBorder)
			end
		end)
		row:SetScript("OnLeave", function(self)
			self.hover:Hide()
			self.border:SetColor(C.inputBorder)
		end)
		sideRows[index] = row
	end
	return row
end

-- spec: header (bool), label, color, checked, icon, count, open, onClick, onCheck
local function PaintSideRow(row, spec, y)
	local height = spec.header and HEADER_HEIGHT or OPTION_HEIGHT
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", sidebar.content, "TOPLEFT", spec.header and 0 or 8, -y)
	row:SetPoint("TOPRIGHT", sidebar.content, "TOPRIGHT", 0, -y)
	row:SetHeight(height)
	row.isHeader = spec.header
	row.fill:SetShown(spec.header)
	row.onClick = spec.onClick
	row.onCheck = spec.onCheck or spec.onClick
	row.checkZone:SetShown(spec.onCheck ~= nil)

	row.check:ClearAllPoints()
	row.check:SetPoint("LEFT", spec.header and 7 or 2, 0)
	row.check:SetState(spec.checked)

	local x = (spec.header and 7 or 2) + 14 + 6
	row.icon:SetShown(spec.icon ~= nil)
	if spec.icon then
		row.icon:ClearAllPoints()
		row.icon:SetPoint("LEFT", x, 0)
		row.icon:SetIcon(spec.icon)
		x = x + 16 + 6
	end
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", x, 0)
	row.label:SetPoint("RIGHT", spec.expander and -40 or -4, 0)
	row.label:SetText(spec.label)
	row.label:SetTextColor(unpack(spec.header and C.accent or C.text))

	row.caret:SetShown(spec.expander == true)
	row.caret:SetOpen(spec.open == true)
	row.count:SetShown((spec.count or 0) > 0)
	row.countText:SetText(spec.count or "")
	-- Rows that are not headers have no box around them.
	row.border:SetColor(spec.header and C.inputBorder or { 0, 0, 0, 0 })
	row:Show()
	return height
end

local clearButton
local function PaintSidebar()
	for _, row in ipairs(sideRows) do
		row:Hide()
	end
	local y, used = 0, 0
	local function Add(spec)
		used = used + 1
		y = y + PaintSideRow(SideRow(used), spec, y)
	end

	for _, facet in ipairs(facets) do
		if not facet.rail and #facet.options > 0 then
			local ticked = state.selection[facet.id] or {}
			local tickedCount = 0
			for _, option in ipairs(facet.options) do
				if ticked[option.value] then
					tickedCount = tickedCount + 1
				end
			end
			local function ToggleOption(option)
				return function()
					Facets.Toggle(state.selection, facet.id, option.value, not ticked[option.value])
					Refresh()
				end
			end

			if facet.flat then
				-- No header: each box sits straight in the column. A category
				-- with one box takes the category's name.
				for _, option in ipairs(facet.options) do
					Add({
						header = true,
						label = #facet.options == 1 and facet.label or option.label,
						checked = ticked[option.value] == true,
						icon = option.icon,
						onClick = ToggleOption(option),
					})
					y = y + 4
				end
			else
				local all = tickedCount == #facet.options
				local refined = 0
				for _ in pairs(state.selection[Facets.RefineKey(facet.id)] or {}) do
					refined = refined + 1
				end
				local isOpen = state.open[facet.id] == true
				Add({
					header = true,
					expander = true,
					label = facet.label,
					checked = all or (tickedCount > 0 and "some") or false,
					count = (all and 0 or tickedCount) + refined,
					open = isOpen,
					onClick = function()
						state.open[facet.id] = not isOpen
						Refresh()
					end,
					-- The header's own checkbox ticks every box in the category.
					onCheck = function()
						for _, option in ipairs(facet.options) do
							Facets.Toggle(state.selection, facet.id, option.value, not all)
						end
						Refresh()
					end,
				})
				if isOpen then
					y = y + 2
					for _, option in ipairs(facet.options) do
						if not option.inRail then -- it is a tile in the rail
							Add({ label = option.label, checked = ticked[option.value] == true, icon = option.icon, onClick = ToggleOption(option) })
						end
					end
				end
				y = y + 4
			end
		end
	end

	clearButton:SetShown(Facets.AnySelected(state.selection))
	if clearButton:IsShown() then
		clearButton:ClearAllPoints()
		clearButton:SetPoint("TOPLEFT", sidebar.content, "TOPLEFT", 0, -(y + 2))
		clearButton:SetPoint("TOPRIGHT", sidebar.content, "TOPRIGHT", 0, -(y + 2))
		y = y + 26
	end
	sidebar:SetContentHeight(y)
end

-- ========= The list =========================================================
local SORT_VALUES = {
	name = function(item)
		return item.name
	end,
	level = function(item)
		return item.levelType == "REQ_LEVEL_ABBR" and item.level or nil
	end,
	units = function(item)
		return item.units
	end,
	min = function(item)
		return item.min
	end,
	deal = function(item)
		return item.deal
	end,
}

local function PaintList(keepScroll)
	local rows = FilteredItems()
	Kit.SortRows(rows, SORT_VALUES[state.sort.id], state.sort.descending)
	list:SetSort(state.sort.id, state.sort.descending)
	list:SetRows(rows, keepScroll)
end

-- ========= The order panel ==================================================
local parts = {}
local stack

local function PaintOrder()
	stack:Reset()
	local item = market and state.selectedKey and market.byKey[state.selectedKey]
	prompt:SetShown(item == nil)
	if not item then
		return
	end

	local filled = ns.Orders.Fill(item, state.wanted)
	local deal = ns.Signals:Deal(item, filled.units, filled.cost)
	local gold = GetMoney()
	local overBudget = filled.cost > gold

	parts.icon:SetIcon(item.icon)
	parts.name:SetText(item.name)
	parts.name:SetTextColor(unpack(Kit.QualityColor(item.quality)))
	parts.available:SetText(L.BUY_AVAILABLE:format(ns.Comma(item.units)))
	stack:Add(parts.head)

	parts.quantity:SetValue(tostring(state.wanted))
	stack:Add(parts.quantityRow, 8)
	stack:Add(parts.rule1, 8)
	parts.total:Set(L.BUY_TOTAL, ns.Money(filled.cost))
	stack:Add(parts.total, 6)
	parts.average:Set(L.BUY_AVERAGE, ns.Money(filled.averageUnit))
	stack:Add(parts.average, 4)

	-- The deal: a meter and what the order saves. With too few auctions to
	-- know the usual price there is no meter, only a note saying so.
	if deal.known then
		parts.dealMeter:SetReading(deal)
		stack:Add(parts.deal, 2)
		parts.saving:Set(deal.saving >= 0 and L.BUY_SAVE or L.BUY_EXTRA, ns.Money(math.abs(deal.saving)))
		parts.saving.right:SetTextColor(unpack(deal.saving >= 0 and C.good or C.bad))
		stack:Add(parts.saving, 2)
	end
	parts.dealNote:SetBody(deal.reasons[1])
	stack:Add(parts.dealNote, 3)

	if filled.short > 0 then
		parts.warning:SetBody(L.BUY_SHORT:format(ns.Comma(filled.units)), C.bad)
		stack:Add(parts.warning, 3)
	elseif filled.units ~= state.wanted then
		parts.warning:SetBody(L.BUY_GET_MORE:format(ns.Comma(filled.units)))
		stack:Add(parts.warning, 3)
	end
	if overBudget then
		parts.budget:SetBody(L.BUY_OVER_BUDGET, C.bad)
		stack:Add(parts.budget, 3)
	end

	stack:Add(parts.rule2, 8)
	for index = 1, ORDER_LINES do
		local line = filled.lines[index]
		if line then
			local what = filled.byUnit and L.BUY_LINE_UNITS:format(ns.Comma(line.units))
				or L.BUY_LINE_STACKS:format(ns.Comma(line.auctions), ns.Comma(line.tier.stack))
			parts.lines[index]:Set(what, L.EACH:format(ns.Money(line.tier.unit)))
			stack:Add(parts.lines[index], index == 1 and 6 or 0)
		end
	end
	if #filled.lines > ORDER_LINES then
		parts.more:SetBody(L.BUY_MORE_LINES:format(#filled.lines - ORDER_LINES))
		stack:Add(parts.more, 2)
	end

	parts.buy:SetLabel(L.BUY_BUTTON:format(ns.Comma(filled.units)))
	parts.buy:SetDisabled(overBudget or filled.units == 0)
	stack:Add(parts.buy, 10)
	local how = L.BUY_BY_UNIT
	if not filled.byUnit then
		how = filled.purchases == 1 and L.BUY_ONE_AUCTION or L.BUY_AUCTIONS:format(ns.Comma(filled.purchases), ns.Comma(filled.purchases))
	end
	parts.how:SetBody(how)
	stack:Add(parts.how, 4)
end

local function SetWanted(value)
	local item = market and market.byKey[state.selectedKey]
	state.wanted = math.max(1, math.floor(value or 1))
	if item then
		state.wanted = math.min(state.wanted, math.max(1, item.units))
	end
	PaintOrder()
end

local function BuildOrder(parent)
	local width = Theme.buy.order - 16
	stack = Kit.Stack(parent, 8)

	prompt = Kit.Note(parent, "normal", C.muted, "CENTER")
	prompt:SetPoint("TOPLEFT", 16, -30)
	prompt:SetPoint("TOPRIGHT", -16, -30)
	prompt:SetWidth(width - 16)
	prompt:SetBody(L.BUY_PICK)

	parts.head = CreateFrame("Frame", nil, parent)
	parts.head:SetHeight(34)
	parts.icon = Kit.Icon(parts.head, 32)
	parts.icon:SetPoint("LEFT")
	parts.name = Kit.Text(parts.head, "normal")
	parts.name:SetPoint("TOPLEFT", 40, -2)
	parts.name:SetPoint("RIGHT")
	parts.available = Kit.Text(parts.head, "small", C.muted)
	parts.available:SetPoint("BOTTOMLEFT", 40, 2)

	parts.quantityRow = CreateFrame("Frame", nil, parent)
	parts.quantityRow:SetHeight(26)
	local label = Kit.Text(parts.quantityRow, "normal", C.muted)
	label:SetPoint("LEFT")
	label:SetText(L.BUY_QUANTITY)
	local minus = Kit.Button(parts.quantityRow, { text = "-", width = 26, height = 26, onClick = function()
		SetWanted(state.wanted - 1)
	end })
	minus:SetPoint("LEFT", 62, 0)
	parts.quantity = Kit.Input(parts.quantityRow, { width = 64, height = 26, numeric = true, justify = "RIGHT", maxLetters = 6, onChange = function(text)
		SetWanted(tonumber(text) or 1)
	end })
	parts.quantity:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	local plus = Kit.Button(parts.quantityRow, { text = "+", width = 26, height = 26, onClick = function()
		SetWanted(state.wanted + 1)
	end })
	plus:SetPoint("LEFT", parts.quantity, "RIGHT", 4, 0)
	local all = Kit.Button(parts.quantityRow, { text = L.SELL_ALL, height = 26, onClick = function()
		local item = market and market.byKey[state.selectedKey]
		SetWanted(item and item.units or 1)
	end })
	all:SetPoint("LEFT", plus, "RIGHT", 4, 0)

	local function Rule()
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetHeight(1)
		Kit.Fill(holder, C.line)
		return holder
	end
	parts.rule1, parts.rule2 = Rule(), Rule()

	parts.total = Kit.Pair(parent, "total", C.text)
	parts.total:SetHeight(22)
	parts.average = Kit.Pair(parent)
	parts.deal = Kit.Pair(parent)
	parts.deal.left:SetText(L.BUY_DEAL)
	parts.dealMeter = Kit.Meter(parts.deal, ns.DealPips)
	parts.dealMeter:SetPoint("RIGHT")
	parts.deal:EnableMouse(true)
	Kit.Tip(parts.deal, function()
		local item = market and market.byKey[state.selectedKey]
		if not item then
			return nil
		end
		local filled = ns.Orders.Fill(item, state.wanted)
		local deal = ns.Signals:Deal(item, filled.units, filled.cost)
		return deal.known and { deal.level.label, unpack(deal.reasons) } or nil
	end)
	parts.saving = Kit.Pair(parent)

	local function Note()
		local note = Kit.Note(parent, "small", C.muted)
		note:SetWidth(width)
		return note
	end
	parts.dealNote, parts.warning, parts.budget, parts.more, parts.how = Note(), Note(), Note(), Note(), Note()

	parts.lines = {}
	for index = 1, ORDER_LINES do
		parts.lines[index] = Kit.Pair(parent, "small")
		parts.lines[index]:SetHeight(16)
	end

	parts.buy = Kit.Button(parent, { text = "", look = "action", height = 32, width = width, tip = { L.TAB_BUY, L.BUY_NOT_WIRED } })
end

-- ========= The tab ==========================================================
Refresh = function(keepScroll)
	Prepare()
	local _, reason = ns.Window:Market()
	list:SetEmptyText(market and L.BUY_NOTHING or reason)
	for _, button in pairs(toggleButtons) do
		button:SetActive(state.toggles[button.id] == true)
	end
	if market and state.selectedKey and not market.byKey[state.selectedKey] then
		state.selectedKey = nil
	end
	PaintRail()
	PaintSidebar()
	PaintList(keepScroll)
	PaintOrder()
end

local function Create(parent)
	local pad = Theme.pad
	rail = Kit.Panel(parent)
	rail:SetPoint("TOPLEFT")
	rail:SetPoint("BOTTOMLEFT")
	rail:SetWidth(Theme.buy.rail)

	local side = Kit.Panel(parent)
	side:SetPoint("TOPLEFT", rail, "TOPRIGHT", pad, 0)
	side:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", pad, 0)
	side:SetWidth(Theme.buy.sidebar)
	sidebar = Kit.Scroll(side)
	sidebar:SetPoint("TOPLEFT", 8, -8)
	sidebar:SetPoint("BOTTOMRIGHT", -8, 8)
	clearButton = Kit.Button(sidebar.content, { text = L.CLEAR_ALL, size = "small", height = 22, width = 100, onClick = function()
		state.selection = {}
		Refresh()
	end })

	order = Kit.Panel(parent)
	order:SetPoint("TOPRIGHT")
	order:SetPoint("BOTTOMRIGHT")
	order:SetWidth(Theme.buy.order)
	BuildOrder(order)

	-- The search box and the quick toggles share one row.
	toolbar = CreateFrame("Frame", nil, parent)
	toolbar:SetPoint("TOPLEFT", side, "TOPRIGHT", pad, 0)
	toolbar:SetPoint("TOPRIGHT", order, "TOPLEFT", -pad, 0)
	toolbar:SetHeight(26)
	local right
	for index = #ns.BuyToggles, 1, -1 do
		local toggle = ns.BuyToggles[index]
		local button = Kit.Button(toolbar, { text = toggle.label, height = 26, padding = 14, onClick = function()
			state.toggles[toggle.id] = not state.toggles[toggle.id]
			Refresh()
		end })
		button.id = toggle.id
		if right then
			button:SetPoint("RIGHT", right, "LEFT", -5, 0)
		else
			button:SetPoint("RIGHT")
		end
		right = button
		toggleButtons[toggle.id] = button
	end
	searchBox = Kit.Input(toolbar, { height = 26, placeholder = L.BUY_SEARCH, onChange = function(text)
		state.search = text
		PaintList()
	end })
	searchBox:SetPoint("LEFT")
	searchBox:SetPoint("RIGHT", right, "LEFT", -5, 0)

	list = Kit.List(parent, {
		columns = {
			{
				id = "name",
				label = L.BUY_COL_ITEM,
				flex = true,
				icon = function(item)
					return item.icon
				end,
				text = function(item)
					return item.name
				end,
				color = function(item)
					return Kit.QualityColor(item.quality)
				end,
			},
			{ id = "level", label = L.BUY_COL_LEVEL, width = 30, align = "RIGHT", text = function(item)
				return item.levelType == "REQ_LEVEL_ABBR" and tostring(item.level or "") or ""
			end },
			{ id = "units", label = L.BUY_COL_AVAILABLE, width = 58, align = "RIGHT", text = function(item)
				return ns.Comma(item.units)
			end },
			{ id = "min", label = L.BUY_COL_PRICE, width = 84, align = "RIGHT", text = function(item)
				return ns.Money(item.min)
			end },
			{ id = "deal", label = "", width = 42, align = "RIGHT", badge = function(item)
				if item.deal and item.deal >= ns.DealBadgeRule.percent then
					return "-" .. item.deal .. "%"
				end
			end },
		},
		empty = L.BUY_NOTHING,
		onClick = function(item)
			state.selectedKey = item.key
			state.wanted = 1
			PaintList(true)
			PaintOrder()
		end,
		isSelected = function(item)
			return item.key == state.selectedKey
		end,
		link = function(item)
			return item.link
		end,
		onSort = function(id)
			if state.sort.id == id then
				state.sort.descending = not state.sort.descending
			else
				state.sort = { id = id, descending = id ~= "name" } -- numbers start largest first
			end
			PaintList()
		end,
	})
	list:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -6)
	list:SetPoint("BOTTOMRIGHT", order, "BOTTOMLEFT", -pad, 0)

	return { Refresh = function()
		Refresh(true)
	end }
end

ns.Window:RegisterTab({ id = "buy", label = L.TAB_BUY, order = 1, Create = Create })

-- Kit: the window's building blocks, drawn from plain textures and text so
-- they take their look from data\theme.lua and not from the game's stock
-- (red) button art. Every tab is built from these.
local _, ns = ...
local Theme = ns.Theme
local C = Theme.color

local Kit = {}
ns.Kit = Kit

local WHITE = "Interface\\Buttons\\WHITE8x8"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"

-- ========= Text ============================================================
local fonts = {}

-- A font object for a size, made once. Falls back to the game's standard font
-- when the theme's font cannot be loaded.
function Kit.Font(size)
	local font = fonts[size]
	if not font then
		font = CreateFont("AuctioNitroFont" .. size)
		local ok = pcall(font.SetFont, font, Theme.font, size, "")
		if not ok or not font:GetFont() then
			font:SetFont(STANDARD_TEXT_FONT, size, "")
		end
		fonts[size] = font
	end
	return font
end

-- A line of text. size is a key of Theme.fontSize, color a Theme color.
function Kit.Text(parent, size, color, justify)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.Font(Theme.fontSize[size or "normal"]))
	text:SetTextColor(unpack(color or C.text))
	text:SetJustifyH(justify or "LEFT")
	text:SetWordWrap(false)
	return text
end

-- ========= Surfaces ========================================================
function Kit.Fill(frame, color, layer)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetAllPoints()
	texture:SetColorTexture(unpack(color))
	return texture
end

-- A top-to-bottom gradient. Returns the texture, with :SetColors(top, bottom).
function Kit.Gradient(frame, top, bottom, layer)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetAllPoints()
	function texture:SetColors(first, second)
		self:SetColorTexture(1, 1, 1, 1)
		local ok = pcall(self.SetGradient, self, "VERTICAL", CreateColor(unpack(second)), CreateColor(unpack(first)))
		if not ok then
			self:SetColorTexture(unpack(first))
		end
	end
	texture:SetColors(top, bottom)
	return texture
end

-- A one-pixel outline. Returns an object with :SetColor(color).
function Kit.Border(frame, color, layer)
	local edges = {}
	for index = 1, 4 do
		edges[index] = frame:CreateTexture(nil, layer or "BORDER")
	end
	edges[1]:SetPoint("TOPLEFT")
	edges[1]:SetPoint("TOPRIGHT")
	edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT")
	edges[2]:SetPoint("BOTTOMRIGHT")
	edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT")
	edges[3]:SetPoint("BOTTOMLEFT")
	edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT")
	edges[4]:SetPoint("BOTTOMRIGHT")
	edges[4]:SetWidth(1)
	local border = {}
	function border:SetColor(next)
		for _, edge in ipairs(edges) do
			edge:SetColorTexture(unpack(next))
		end
	end
	border:SetColor(color)
	return border
end

-- A bordered panel, the box each column of a tab sits in.
function Kit.Panel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	Kit.Fill(panel, C.panel)
	Kit.Border(panel, C.line)
	return panel
end

-- A thin horizontal rule.
function Kit.Rule(parent, color)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	rule:SetColorTexture(unpack(color or C.line))
	return rule
end

-- ========= Tooltips ========================================================
-- lines is a list of strings, or a function returning one. The first line is
-- the title. Nothing is shown when there are no lines.
function Kit.Tip(frame, lines)
	frame:SetScript("OnEnter", function(self)
		if self.onHover then
			self:onHover(true)
		end
		local list = lines
		if type(lines) == "function" then
			list = lines(self)
		end
		if not list or #list == 0 then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, -2)
		GameTooltip:SetText(list[1], 1, 0.82, 0)
		for index = 2, #list do
			GameTooltip:AddLine(list[index], 0.95, 0.91, 0.84, true)
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function(self)
		if self.onHover then
			self:onHover(false)
		end
		GameTooltip:Hide()
	end)
end

-- ========= Buttons =========================================================
-- Looks, as data: gradient, border and text color when idle and when active.
local BUTTON_LOOKS = {
	control = {
		top = C.controlTop, bottom = C.controlBottom, border = C.inputBorder, text = C.controlText,
		activeTop = C.activeTop, activeBottom = C.activeBottom, activeBorder = C.activeBorder, activeText = C.accent,
	},
	tab = {
		top = C.tabTop, bottom = C.tabBottom, border = C.inputBorder, text = C.tabText,
		activeTop = C.tabActiveTop, activeBottom = C.tabActiveBottom, activeBorder = C.tabActiveBorder, activeText = C.accent,
	},
	action = {
		top = C.actionTop, bottom = C.actionBottom, border = C.actionBorder, text = C.accent,
		hoverTop = C.actionHoverTop, hoverBottom = C.actionHoverBottom,
	},
	header = {
		top = C.controlTop, bottom = C.controlBottom, border = C.inputBorder, text = C.accent,
	},
}

-- A button. options: text, look (a key above), size ("small" | "normal" |
-- "large"), width, height, tip (lines or function), onClick.
-- Returns the button, with :SetActive(on), :SetLabel(text), :SetDisabled(on).
function Kit.Button(parent, options)
	local look = BUTTON_LOOKS[options.look or "control"]
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(options.height or Theme.controlHeight)
	button.fill = Kit.Gradient(button, look.top, look.bottom)
	button.border = Kit.Border(button, look.border)
	button.label = Kit.Text(button, options.size or "normal", look.text, options.justify or "CENTER")
	button.label:SetPoint("LEFT", options.inset or 6, 0)
	button.label:SetPoint("RIGHT", -(options.inset or 6), 0)

	local function Paint()
		local active, hover = button.active, button.hover and not button.disabled
		if active and look.activeTop then
			button.fill:SetColors(look.activeTop, look.activeBottom)
			button.border:SetColor(look.activeBorder)
			button.label:SetTextColor(unpack(look.activeText))
		else
			if hover and look.hoverTop then
				button.fill:SetColors(look.hoverTop, look.hoverBottom)
			else
				button.fill:SetColors(look.top, look.bottom)
			end
			button.border:SetColor(hover and C.activeBorder or look.border)
			button.label:SetTextColor(unpack(look.text))
		end
		button:SetAlpha(button.disabled and 0.4 or 1)
	end

	function button:SetActive(on)
		self.active = on and true or false
		Paint()
	end

	function button:SetDisabled(on)
		self.disabled = on and true or false
		Paint()
	end

	function button:SetLabel(text)
		self.label:SetText(text)
		if not options.width then
			self:SetWidth(math.floor(self.label:GetStringWidth() + 0.5) + (options.padding or 16))
		end
	end

	function button:onHover(on)
		self.hover = on
		Paint()
	end

	Kit.Tip(button, options.tip)
	button:SetScript("OnClick", function(self)
		if not self.disabled and options.onClick then
			options.onClick(self)
		end
	end)
	if options.width then
		button:SetWidth(options.width)
	end
	button:SetLabel(options.text or "")
	Paint()
	return button
end

-- A row of buttons where one (or none) is lit. options: items (each with
-- label and tip), gap, joined (no gap, like one segmented control), isActive
-- (item), onPick(item). Returns the row frame with :Refresh().
function Kit.Choices(parent, options)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(options.height or Theme.controlHeight)
	local gap = options.joined and -1 or (options.gap or 4)
	local buttons = {}
	local x = 0
	for index, item in ipairs(options.items) do
		local button = Kit.Button(row, {
			text = item.label,
			size = options.size or "normal",
			height = options.height,
			padding = options.padding or 16,
			tip = item.tip and { item.label, item.tip } or nil,
			onClick = function()
				options.onPick(item)
			end,
		})
		button:SetPoint("LEFT", x, 0)
		x = x + button:GetWidth() + gap
		buttons[index] = button
	end
	row:SetWidth(math.max(1, x - gap))

	function row:Refresh()
		for index, button in ipairs(buttons) do
			button:SetActive(options.isActive(options.items[index]))
		end
	end
	row:Refresh()
	return row
end

-- ========= Checkbox ========================================================
-- A small box. :SetState(true | false | "some") draws a check, nothing, or a
-- dash for "partly ticked".
function Kit.Check(parent, size)
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(size or 14, size or 14)
	Kit.Fill(box, C.input)
	box.border = Kit.Border(box, C.muted)
	box.mark = box:CreateTexture(nil, "OVERLAY")
	box.mark:SetTexture(CHECK)
	box.mark:SetPoint("TOPLEFT", -3, 3)
	box.mark:SetPoint("BOTTOMRIGHT", 3, -3)
	box.mark:SetVertexColor(unpack(C.accent))
	box.dash = box:CreateTexture(nil, "OVERLAY")
	box.dash:SetColorTexture(unpack(C.accent))
	box.dash:SetPoint("LEFT", 3, 0)
	box.dash:SetPoint("RIGHT", -3, 0)
	box.dash:SetHeight(2)

	function box:SetState(state)
		self.mark:SetShown(state == true)
		self.dash:SetShown(state == "some")
		self.border:SetColor((state == true or state == "some") and C.accent or C.muted)
	end
	box:SetState(false)
	return box
end

-- ========= Icons ===========================================================
-- An item icon with a thin dark edge. :SetIcon(fileID) hides it when nil.
function Kit.Icon(parent, size)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetSize(size, size)
	Kit.Fill(icon, C.black)
	icon.art = icon:CreateTexture(nil, "ARTWORK")
	icon.art:SetPoint("TOPLEFT", 1, -1)
	icon.art:SetPoint("BOTTOMRIGHT", -1, 1)
	icon.art:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	function icon:SetIcon(fileID)
		self.art:SetTexture(fileID)
		self.art:SetShown(fileID ~= nil)
	end
	return icon
end

-- An arrow that points right when closed and down when open.
function Kit.Caret(parent)
	local caret = parent:CreateTexture(nil, "OVERLAY")
	caret:SetTexture(ARROW)
	caret:SetSize(10, 10)
	caret:SetVertexColor(unpack(C.tabText))
	function caret:SetOpen(open)
		self:SetRotation(open and -math.pi / 2 or 0)
	end
	return caret
end

-- ========= Text entry ======================================================
-- options: width, height, numeric, placeholder, maxLetters, justify,
-- onChange(text) for typing only. Returns the edit box.
function Kit.Input(parent, options)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(options.width or 80, options.height or Theme.controlHeight)
	box:SetAutoFocus(false)
	box:SetFontObject(Kit.Font(Theme.fontSize[options.size or "normal"]))
	box:SetTextColor(unpack(C.white))
	box:SetTextInsets(6, options.rightInset or 6, 0, 0)
	box:SetJustifyH(options.justify or "LEFT")
	if options.numeric then
		box:SetNumeric(true)
	end
	if options.maxLetters then
		box:SetMaxLetters(options.maxLetters)
	end
	Kit.Fill(box, C.input)
	box.border = Kit.Border(box, C.inputBorder)

	if options.placeholder then
		box.placeholder = Kit.Text(box, options.size or "normal", C.muted)
		box.placeholder:SetPoint("LEFT", 7, 0)
		box.placeholder:SetText(options.placeholder)
	end
	local function UpdatePlaceholder()
		if box.placeholder then
			box.placeholder:SetShown(box:GetText() == "")
		end
	end

	box:SetScript("OnTextChanged", function(self, userInput)
		UpdatePlaceholder()
		if userInput and options.onChange then
			options.onChange(self:GetText())
		end
	end)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	box:SetScript("OnEditFocusGained", function(self)
		self.border:SetColor(C.accent)
		self:HighlightText()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		self.border:SetColor(C.inputBorder)
		self:HighlightText(0, 0)
	end)

	-- Sets the text without it counting as typing.
	function box:SetValue(text)
		self:SetText(text)
		UpdatePlaceholder()
	end
	return box
end

-- A price as three boxes, gold, silver and copper, the way the game takes a
-- price. options: compact, onChange(copper). Returns the row with
-- :SetAmount(copper) and :GetAmount().
function Kit.MoneyInput(parent, options)
	local compact = options.compact
	local height = compact and 24 or 28
	local parts = {
		{ id = "gold", letter = "g", width = compact and 46 or 76, max = 7, color = C.gold },
		{ id = "silver", letter = "s", width = compact and 34 or 58, max = 2, color = Theme.Hex("#c7c7cf") },
		{ id = "copper", letter = "c", width = compact and 34 or 58, max = 2, color = Theme.Hex("#eda55f") },
	}
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(height)
	local boxes = {}

	function row:GetAmount()
		local gold = tonumber(boxes.gold:GetText()) or 0
		local silver = tonumber(boxes.silver:GetText()) or 0
		local copper = tonumber(boxes.copper:GetText()) or 0
		return gold * 10000 + silver * 100 + copper
	end

	function row:SetAmount(amount)
		amount = math.max(0, math.floor(amount or 0))
		boxes.gold:SetValue(tostring(math.floor(amount / 10000)))
		boxes.silver:SetValue(tostring(math.floor(amount / 100) % 100))
		boxes.copper:SetValue(tostring(amount % 100))
	end

	local x = 0
	for index, part in ipairs(parts) do
		local box = Kit.Input(row, {
			width = part.width,
			height = height,
			numeric = true,
			maxLetters = part.max,
			justify = "RIGHT",
			rightInset = 18,
			size = compact and "normal" or "large",
			onChange = function()
				if options.onChange then
					options.onChange(row:GetAmount())
				end
			end,
		})
		box:SetPoint("LEFT", x, 0)
		local letter = Kit.Text(box, compact and "normal" or "large", part.color, "RIGHT")
		letter:SetPoint("RIGHT", -6, 0)
		letter:SetText(part.letter)
		boxes[part.id] = box
		x = x + part.width + (compact and 3 or 6)
		-- Tab moves to the next box, and wraps around.
		box:SetScript("OnTabPressed", function()
			boxes[parts[index % #parts + 1].id]:SetFocus()
		end)
	end
	row:SetWidth(x)
	row:SetAmount(0)
	return row
end

-- ========= Meter ===========================================================
-- A row of pips. :SetReading(reading) takes a reading from ns.Signals
-- (level.pips, level.tone). Returns the frame.
function Kit.Meter(parent, pips)
	local meter = CreateFrame("Frame", nil, parent)
	meter:SetSize(pips * 9 - 2, 11)
	meter.pips = {}
	for index = 1, pips do
		local pip = meter:CreateTexture(nil, "ARTWORK")
		pip:SetSize(7, 11)
		pip:SetPoint("LEFT", (index - 1) * 9, 0)
		meter.pips[index] = pip
	end
	function meter:SetReading(reading)
		local on = reading and reading.level.pips or 0
		local tone = reading and Theme.tone[reading.level.tone] or C.pipOff
		for index, pip in ipairs(self.pips) do
			pip:SetColorTexture(unpack(index <= on and tone or C.pipOff))
		end
	end
	meter:SetReading(nil)
	return meter
end

-- ========= Slider ==========================================================
-- options: width, onChange(value) for dragging only. Returns the slider with
-- :SetRange(max) (the minimum is always 1) and :SetShownValue(value).
function Kit.Slider(parent, options)
	local slider = CreateFrame("Slider", nil, parent)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(options.width or 160, 16)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	slider:SetMinMaxValues(1, 1)
	slider:SetValue(1)

	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(4)
	track:SetColorTexture(unpack(C.inputBorder))
	slider:SetThumbTexture(WHITE)
	local thumb = slider:GetThumbTexture()
	thumb:SetSize(10, 16)
	thumb:SetVertexColor(unpack(C.accent))

	local settingValue = false
	slider:SetScript("OnValueChanged", function(self, value)
		if not settingValue and options.onChange then
			options.onChange(math.floor(value + 0.5))
		end
	end)

	function slider:SetRange(max)
		settingValue = true
		self:SetMinMaxValues(1, math.max(1, max))
		settingValue = false
		self:SetAlpha(max <= 1 and 0.4 or 1)
		self:EnableMouse(max > 1)
	end

	function slider:SetShownValue(value)
		settingValue = true
		self:SetValue(value)
		settingValue = false
	end
	return slider
end

-- ========= Scrolling =======================================================
-- A plain scrolling area for a column whose content can outgrow it. Build
-- into .content, then call :SetContentHeight(height).
function Kit.Scroll(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll.content = CreateFrame("Frame", nil, scroll)
	scroll.content:SetSize(1, 1)
	scroll:SetScrollChild(scroll.content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = math.max(0, (self.contentHeight or 0) - self:GetHeight())
		local next = math.min(range, math.max(0, self:GetVerticalScroll() - delta * 40))
		self:SetVerticalScroll(next)
	end)
	scroll:SetScript("OnSizeChanged", function(self, width)
		self.content:SetWidth(width)
	end)

	function scroll:SetContentHeight(height)
		self.contentHeight = height
		self.content:SetHeight(math.max(1, height))
		local range = math.max(0, height - self:GetHeight())
		if self:GetVerticalScroll() > range then
			self:SetVerticalScroll(range)
		end
	end
	return scroll
end

-- ========= List ============================================================
-- A table with a header and scrolling rows.
--
-- options:
--   columns     { id, label, width | flex, align, sortable,
--                 text(row) -> string,            what the cell says
--                 color(row) -> color | nil,      its text color
--                 icon(row) -> fileID | nil,      an icon before the text
--                 meter(row) -> reading, pips,    draw a meter instead of text
--                 badge(row) -> string | nil }    draw a tinted badge instead
--   rowHeight, empty (text when there are no rows)
--   onClick(row), isSelected(row), tip(row) -> lines, link(row) -> item link
--   onSort(columnId)
-- Returns the frame with :SetRows(rows, keepScroll) and :SetSort(id, descending).
function Kit.List(parent, options)
	local list = Kit.Panel(parent)
	local columns = options.columns
	local rowHeight = options.rowHeight or Theme.rowHeight
	local scrollWidth = 12
	local sort = {}

	local header = CreateFrame("Frame", nil, list)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(Theme.headerHeight)
	Kit.Fill(header, C.panel2)

	local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 1, -(Theme.headerHeight + 1))
	scrollBox:SetPoint("BOTTOMRIGHT", -(scrollWidth + 4), 1)
	local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 3, -2)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 3, 2)

	local empty = Kit.Text(list, "normal", C.muted, "CENTER")
	empty:SetPoint("TOP", scrollBox, "TOP", 0, -30)
	empty:SetText(options.empty or "")

	-- Where each column sits, worked out from the list's width.
	local left, width = {}, {}
	local function Layout()
		local available = (scrollBox:GetWidth() or 0)
		local fixed, padding = 0, 8
		for _, column in ipairs(columns) do
			fixed = fixed + (column.width or 0)
		end
		local flex = math.max(60, available - fixed - padding * (#columns + 1))
		local x = padding
		for index, column in ipairs(columns) do
			left[index] = x
			width[index] = column.flex and flex or column.width
			x = x + width[index] + padding
		end
	end

	local headers = {}
	local function PaintHeaders()
		for index, column in ipairs(columns) do
			local cell = headers[index]
			if not cell then
				cell = CreateFrame("Button", nil, header)
				cell:SetHeight(Theme.headerHeight)
				cell.label = Kit.Text(cell, "normal", C.accent, column.align)
				cell.label:SetAllPoints()
				cell:SetScript("OnClick", function()
					if column.sortable ~= false and options.onSort then
						options.onSort(column.id)
					end
				end)
				headers[index] = cell
			end
			cell:ClearAllPoints()
			cell:SetPoint("LEFT", left[index], 0)
			cell:SetWidth(width[index])
			local arrow = ""
			if sort.id == column.id then
				arrow = sort.descending and "  v" or "  ^"
			end
			cell.label:SetText((column.label or "") .. arrow)
		end
	end

	local function BuildRow(row)
		row.hover = Kit.Fill(row, C.rowHover, "BACKGROUND")
		row.hover:Hide()
		row.selected = Kit.Fill(row, C.rowSelected, "BACKGROUND")
		row.selected:Hide()
		row.line = Kit.Rule(row)
		row.line:SetPoint("BOTTOMLEFT")
		row.line:SetPoint("BOTTOMRIGHT")
		row.cells = {}
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			self.hover:Show()
			local link = options.link and options.link(self.data)
			local lines = options.tip and options.tip(self.data)
			if link or lines then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if not (link and pcall(GameTooltip.SetHyperlink, GameTooltip, link)) and lines then
					GameTooltip:SetText(lines[1], 1, 0.82, 0)
					for index = 2, #lines do
						GameTooltip:AddLine(lines[index], 0.95, 0.91, 0.84, true)
					end
				end
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function(self)
			self.hover:Hide()
			GameTooltip:Hide()
		end)
		row:SetScript("OnMouseUp", function(self)
			if options.onClick then
				options.onClick(self.data)
			end
		end)
		row.built = true
	end

	local function BuildCell(row, column)
		local cell = { text = Kit.Text(row, "normal", C.text, column.align) }
		if column.icon then
			cell.icon = Kit.Icon(row, rowHeight - 7)
		end
		if column.meter then
			cell.meter = Kit.Meter(row, column.pips or 5)
		end
		if column.badge then
			cell.badge = CreateFrame("Frame", nil, row)
			cell.badge:SetHeight(15)
			Kit.Fill(cell.badge, C.dealBadge)
			cell.badgeText = Kit.Text(cell.badge, "small", C.good, "CENTER")
			cell.badgeText:SetAllPoints()
		end
		return cell
	end

	local function PaintRow(row, data)
		if not row.built then
			BuildRow(row)
		end
		row.data = data
		row.selected:SetShown(options.isSelected ~= nil and options.isSelected(data) == true)
		for index, column in ipairs(columns) do
			local cell = row.cells[index]
			if not cell then
				cell = BuildCell(row, column)
				row.cells[index] = cell
			end
			local x, w = left[index], width[index]
			if cell.icon then
				cell.icon:ClearAllPoints()
				cell.icon:SetPoint("LEFT", x, 0)
				cell.icon:SetIcon(column.icon(data))
				x = x + rowHeight - 1
				w = w - (rowHeight - 1)
			end
			cell.text:ClearAllPoints()
			cell.text:SetPoint("LEFT", x, 0)
			cell.text:SetWidth(math.max(1, w))
			cell.text:SetText(column.text and column.text(data) or "")
			cell.text:SetTextColor(unpack(column.color and column.color(data) or C.text))
			if cell.meter then
				cell.meter:ClearAllPoints()
				cell.meter:SetPoint("LEFT", x, 0)
				cell.meter:SetReading(column.meter(data))
			end
			if cell.badge then
				local label = column.badge(data)
				cell.badge:SetShown(label ~= nil)
				if label then
					cell.badge:ClearAllPoints()
					cell.badge:SetPoint("RIGHT", row, "LEFT", x + w, 0)
					cell.badge:SetWidth(w - 4)
					cell.badgeText:SetText(label)
				end
			end
		end
	end

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(rowHeight)
	view:SetElementInitializer("Frame", PaintRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	function list:SetRows(rows, keepScroll)
		Layout()
		PaintHeaders()
		scrollBox:SetDataProvider(CreateDataProvider(rows), keepScroll and ScrollBoxConstants.RetainScrollPosition or nil)
		empty:SetShown(#rows == 0)
	end

	function list:SetSort(id, descending)
		sort.id, sort.descending = id, descending
	end

	function list:SetEmptyText(text)
		empty:SetText(text)
	end
	return list
end

-- Sorts rows in place by a value function. Empty values always go last.
function Kit.SortRows(rows, read, descending)
	table.sort(rows, function(a, b)
		local x, y = read(a), read(b)
		if x == nil or y == nil then
			return y == nil and x ~= nil
		end
		if type(x) ~= type(y) then
			x, y = tostring(x), tostring(y)
		end
		if descending then
			return x > y
		end
		return x < y
	end)
end

-- A quality's text color, from the game's own table.
function Kit.QualityColor(quality)
	local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color and color.r then
		return { color.r, color.g, color.b, 1 }
	end
	return C.text
end

-- ========= Layout helpers ==================================================
-- A label on the left and a value on the right, on one line.
function Kit.Pair(parent, size, leftColor)
	local pair = CreateFrame("Frame", nil, parent)
	pair:SetHeight(18)
	pair.left = Kit.Text(pair, size or "normal", leftColor or C.muted)
	pair.left:SetPoint("LEFT")
	pair.right = Kit.Text(pair, size or "normal", C.text, "RIGHT")
	pair.right:SetPoint("RIGHT")
	function pair:Set(left, right)
		self.left:SetText(left or "")
		self.right:SetText(right or "")
	end
	return pair
end

-- A paragraph that wraps to its width. :SetBody(text) returns its height.
function Kit.Note(parent, size, color, justify)
	local note = CreateFrame("Frame", nil, parent)
	note.text = Kit.Text(note, size or "small", color or C.muted, justify)
	note.text:SetWordWrap(true)
	note.text:SetPoint("TOPLEFT")
	note.text:SetPoint("TOPRIGHT")
	-- Remember the width asked for: until the frame has been laid out the game
	-- can report a width of zero, which would wrap the text one letter a line.
	local setWidth = note.SetWidth
	function note:SetWidth(width)
		self.wrapWidth = width
		setWidth(self, width)
	end
	function note:SetBody(text, tint)
		local width = self:GetWidth()
		if not width or width < 20 then
			width = self.wrapWidth or 200
		end
		self.text:SetWidth(width)
		self.text:SetText(text or "")
		self.text:SetTextColor(unpack(tint or color or C.muted))
		local height = math.max(12, math.ceil(self.text:GetStringHeight() or 12))
		self:SetHeight(height)
		return height
	end
	return note
end

-- Stacks frames down a column. Call :Reset(), then :Add(frame, gap) for each
-- frame that should show this time. Frames not added are hidden.
function Kit.Stack(parent, inset)
	local stack = { y = inset or 8, known = {} }
	function stack:Reset()
		self.y = inset or 8
		for frame in pairs(self.known) do
			frame:Hide()
		end
	end
	function stack:Add(frame, gap, indent)
		self.known[frame] = true
		self.y = self.y + (gap or 0)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", (inset or 8) + (indent or 0), -self.y)
		frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(inset or 8), -self.y)
		frame:Show()
		self.y = self.y + frame:GetHeight()
		return frame
	end
	return stack
end

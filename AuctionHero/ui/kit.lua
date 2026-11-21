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
		font = CreateFont("AuctionHeroFont" .. size)
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
	-- An icon in place of the text, centred, as big as the button allows.
	if options.icon then
		local size = (options.height or Theme.controlHeight) - 8
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetSize(size, size)
		button.icon:SetPoint("CENTER")
		button.icon:SetTexture(options.icon)
	end

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

-- ========= Stepper =========================================================
-- A whole number in a box with up and down arrows beside it. The arrows and
-- the mouse wheel step it by one; it can also be typed. options: width,
-- limits() returning lowest and highest, onChange(number). Returns the frame
-- with :SetNumber(n), which leaves the box alone while it is being typed in.
function Kit.Stepper(parent, options)
	local height = options.height or Theme.controlHeight
	local arrowWidth = 14
	local stepper = CreateFrame("Frame", nil, parent)
	stepper:SetSize((options.width or 40) + arrowWidth + 2, height)

	local function Clamp(number)
		local low, high = options.limits()
		return math.max(low, math.min(high, math.floor(number)))
	end
	local function Change(number)
		number = Clamp(number)
		stepper.box:SetValue(tostring(number))
		options.onChange(number)
	end

	stepper.box = Kit.Input(stepper, {
		width = options.width or 40,
		height = height,
		numeric = true,
		maxLetters = options.maxLetters or 3,
		justify = "CENTER",
		onChange = function(text)
			local number = tonumber(text)
			if number then
				options.onChange(Clamp(number))
			end
		end,
	})
	stepper.box:SetPoint("LEFT")

	-- Up on top, down below, each half the box's height.
	local function Arrow(step, rotation, point)
		local button = CreateFrame("Button", nil, stepper)
		button:SetSize(arrowWidth, math.floor(height / 2))
		button:SetPoint(point, stepper.box, point == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", 2, 0)
		Kit.Fill(button, C.input)
		button.arrow = button:CreateTexture(nil, "OVERLAY")
		button.arrow:SetTexture(ARROW)
		button.arrow:SetSize(8, 8)
		button.arrow:SetPoint("CENTER")
		button.arrow:SetRotation(rotation)
		button.arrow:SetVertexColor(unpack(C.tabText))
		button.step = step
		button:SetScript("OnClick", function()
			Change((tonumber(stepper.box:GetText()) or 0) + step)
		end)
		button:SetScript("OnEnter", function(self)
			self.arrow:SetVertexColor(unpack(C.accent))
		end)
		button:SetScript("OnLeave", function(self)
			self.arrow:SetVertexColor(unpack(C.tabText))
		end)
		return button
	end
	stepper.up = Arrow(1, math.pi / 2, "TOPLEFT")
	stepper.down = Arrow(-1, -math.pi / 2, "BOTTOMLEFT")

	stepper:EnableMouseWheel(true)
	stepper:SetScript("OnMouseWheel", function(_, delta)
		Change((tonumber(stepper.box:GetText()) or 0) + delta)
	end)

	function stepper:SetNumber(number)
		if not self.box:HasFocus() then
			self.box:SetValue(tostring(number))
		end
	end
	return stepper
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
-- options.bar: a thin bar down the right edge showing where the view is, in
-- this color, drawn only when there is more than fits.
function Kit.Scroll(parent, options)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll.content = CreateFrame("Frame", nil, scroll)
	scroll.content:SetSize(1, 1)
	scroll:SetScrollChild(scroll.content)
	scroll:EnableMouseWheel(true)
	-- Where the view is, as a thumb on the right: its length is the share of
	-- the content in view, its place how far down the view is.
	local function PlaceBar()
		local bar = scroll.bar
		if not bar then
			return
		end
		local view, total = scroll:GetHeight() or 0, scroll.contentHeight or 0
		if total <= view or view <= 0 then
			return bar:Hide()
		end
		local length = math.max(16, math.floor(view * view / total))
		local offset = math.floor((view - length) * scroll:GetVerticalScroll() / (total - view) + 0.5)
		bar:SetHeight(length)
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -offset)
		bar:Show()
	end
	if options and options.bar then
		scroll.bar = scroll:CreateTexture(nil, "OVERLAY")
		scroll.bar:SetColorTexture(unpack(options.bar))
		scroll.bar:SetWidth(3)
		scroll.bar:Hide()
	end

	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = math.max(0, (self.contentHeight or 0) - self:GetHeight())
		local next = math.min(range, math.max(0, self:GetVerticalScroll() - delta * 40))
		self:SetVerticalScroll(next)
		PlaceBar()
	end)
	scroll:SetScript("OnSizeChanged", function(self, width)
		self.content:SetWidth(width)
		PlaceBar()
	end)

	function scroll:SetContentHeight(height)
		self.contentHeight = height
		self.content:SetHeight(math.max(1, height))
		local range = math.max(0, height - self:GetHeight())
		if self:GetVerticalScroll() > range then
			self:SetVerticalScroll(range)
		end
		PlaceBar()
	end
	return scroll
end

-- ========= Sizer ===========================================================
-- A vertical separator that can be dragged left and right. Written once and
-- used wherever two things share a row: list columns, and the panels of a tab.
--
-- options:
--   get()       the current size of whatever this resizes
--   set(size)   called with each new size while dragging
--   direction   1 when dragging right makes it bigger, -1 for the opposite
--   min, max    how small and how big it may go
--   onDone()    called once when the drag ends
-- Returns the frame. The caller places it and gives it a height.
function Kit.Sizer(parent, options)
	local sizer = CreateFrame("Frame", nil, parent)
	sizer:SetWidth(Theme.sizerWidth)
	sizer:SetFrameLevel(parent:GetFrameLevel() + 5)
	sizer:EnableMouse(true)
	local mark = sizer:CreateTexture(nil, "OVERLAY")
	mark:SetColorTexture(unpack(C.accent))
	mark:SetWidth(1)
	mark:SetPoint("TOP", 0, -3)
	mark:SetPoint("BOTTOM", 0, 3)
	mark:SetAlpha(Theme.sizerIdleAlpha)

	local startX, startSize
	local function Stop()
		if not startX then
			return
		end
		startX = nil
		sizer:SetScript("OnUpdate", nil)
		mark:SetAlpha(sizer:IsMouseOver() and Theme.sizerHoverAlpha or Theme.sizerIdleAlpha)
		if options.onDone then
			options.onDone()
		end
	end
	sizer:SetScript("OnEnter", function()
		mark:SetAlpha(Theme.sizerHoverAlpha)
	end)
	sizer:SetScript("OnLeave", function()
		if not startX then
			mark:SetAlpha(Theme.sizerIdleAlpha)
		end
	end)
	sizer:SetScript("OnMouseDown", function(self)
		startX = GetCursorPosition() / self:GetEffectiveScale()
		startSize = options.get()
		local last = startSize
		self:SetScript("OnUpdate", function()
			if not IsMouseButtonDown("LeftButton") then
				return Stop()
			end
			local moved = GetCursorPosition() / self:GetEffectiveScale() - startX
			local wanted = math.floor(startSize + moved * (options.direction or 1) + 0.5)
			wanted = math.max(options.min, math.min(options.max, wanted))
			if wanted ~= last then
				last = wanted
				options.set(wanted)
			end
		end)
	end)
	sizer:SetScript("OnMouseUp", Stop)
	return sizer
end

-- Puts a sizer in the gap beside a panel, so the panel's width can be dragged.
-- The width is kept for the character under options.id.
--
-- options:
--   id        the name the width is saved under
--   edge      "RIGHT" or "LEFT": the side of the panel the sizer sits on
--   min, max  how narrow and how wide the panel may go
--   onChange  called when a drag ends, to redraw what depends on the width
function Kit.Split(panel, options)
	local saved = ns.charDb.panelWidths or {}
	ns.charDb.panelWidths = saved
	if saved[options.id] then
		panel:SetWidth(math.max(options.min, math.min(options.max, saved[options.id])))
	end
	local right = options.edge == "RIGHT"
	local sizer = Kit.Sizer(panel:GetParent(), {
		direction = right and 1 or -1,
		min = options.min,
		max = options.max,
		get = function()
			return panel:GetWidth()
		end,
		set = function(size)
			panel:SetWidth(size)
			saved[options.id] = size
		end,
		onDone = options.onChange,
	})
	local gap = Theme.pad
	sizer:SetWidth(gap)
	if right then
		sizer:SetPoint("TOPLEFT", panel, "TOPRIGHT")
		sizer:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT")
	else
		sizer:SetPoint("TOPRIGHT", panel, "TOPLEFT")
		sizer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT")
	end
	return sizer
end

-- ========= Copy box ========================================================
-- Addons cannot write to the clipboard, so this is the usual way round it: a
-- box of selectable text, opened with everything already selected, so Ctrl+C
-- copies it. Covers its parent; Escape or Close puts it away.
-- Returns the frame with :Open(title, text).
function Kit.CopyBox(parent)
	local cover = CreateFrame("Frame", nil, parent)
	cover:SetAllPoints()
	cover:SetFrameLevel(parent:GetFrameLevel() + 50)
	cover:EnableMouse(true)
	Kit.Fill(cover, C.window)
	Kit.Border(cover, C.border)
	cover:Hide()

	local title = Kit.Text(cover, "normal", C.accent)
	title:SetPoint("TOPLEFT", 10, -9)
	local hint = Kit.Text(cover, "small", C.muted)
	hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
	hint:SetText(ns.L.COPY_HINT)

	local scroll = Kit.Scroll(cover)
	scroll:SetPoint("TOPLEFT", 8, -32)
	scroll:SetPoint("BOTTOMRIGHT", -8, 8)
	Kit.Fill(scroll, C.input)

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(Kit.Font(Theme.fontSize.small))
	box:SetTextColor(unpack(C.text))
	box:SetTextInsets(6, 6, 4, 4)
	box:SetMaxLetters(0)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnSizeChanged", function(_, width)
		box:SetWidth(width)
	end)

	local function SelectAll()
		box:SetFocus()
		box:HighlightText()
	end
	local close = Kit.Button(cover, { text = ns.L.COPY_CLOSE, onClick = function()
		cover:Hide()
	end })
	close:SetPoint("TOPRIGHT", -8, -5)
	local again = Kit.Button(cover, { text = ns.L.COPY_SELECT, onClick = SelectAll })
	again:SetPoint("RIGHT", close, "LEFT", -5, 0)

	-- The text is for reading and copying. Typing puts it back as it was.
	local shown = ""
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(shown)
			self:HighlightText()
		end
		scroll:SetContentHeight(self:GetHeight())
	end)
	box:SetScript("OnEscapePressed", function()
		cover:Hide()
	end)
	cover:SetScript("OnHide", function()
		box:ClearFocus()
	end)

	function cover:Open(heading, text)
		shown = text
		title:SetText(heading)
		box:SetWidth(scroll:GetWidth())
		box:SetText(text)
		scroll:SetVerticalScroll(0)
		self:Show()
		SelectAll()
	end
	return cover
end

-- ========= List ============================================================
-- A table with a header and scrolling rows.
--
-- options:
--   columns     { id, label, width | flex, align, sortable,
--                 fixed = true,                   the width cannot be dragged
--                 fit = true,                     as wide as its widest text
--                                                 (header or row), no wider
--                 hideEmpty = true,               hide when every row is blank
--                 labelColor,                     the header's color
--                 text(row) -> string,            what the cell says
--                 color(row) -> color | nil,      its text color
--                 icon(row) -> fileID | nil,      an icon before the text
--                 meter(row) -> reading, pips,    draw a meter instead of text
--                 badge(row) -> string | nil }    draw a tinted badge instead
--   rowHeight, empty (text when there are no rows), gap (between columns, 8)
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

	-- Widths the player dragged, by column id. A list with an id keeps them
	-- for the character; one without keeps them until the next reload.
	local dragged = {}
	if options.id and ns.charDb then
		ns.charDb.columnWidths = ns.charDb.columnWidths or {}
		ns.charDb.columnWidths[options.id] = ns.charDb.columnWidths[options.id] or {}
		dragged = ns.charDb.columnWidths[options.id]
	end
	-- A fixed column keeps the width it was given: it cannot be dragged, and a
	-- width dragged before it became fixed is ignored.
	local fitted, hidden = {}, {} -- worked out from the rows last set
	local function WidthOf(column)
		if column.fit and fitted[column.id] then
			return fitted[column.id]
		end
		return (not column.fixed and dragged[column.id]) or column.width or 0
	end

	-- Fit the rendered text, including money colors and the smaller badge font.
	-- Reserve either sort marker so changing direction does not move a column.
	local measure = Kit.Text(list, "normal", C.text)
	measure:Hide()
	local badgeMeasure = Kit.Text(list, "small", C.good)
	badgeMeasure:Hide()
	local function Fit(rows)
		local measured, badgeMeasured = {}, {}
		local function TextWidth(text, badge)
			text = tostring(text or "")
			local cache = badge and badgeMeasured or measured
			if not cache[text] then
				local font = badge and badgeMeasure or measure
				font:SetText(text)
				cache[text] = math.ceil(font:GetStringWidth() or 0)
			end
			return cache[text]
		end
		for _, column in ipairs(columns) do
			if column.fit or column.hideEmpty then
				local label = column.label or ""
				local widest = TextWidth(label) + 2
				if column.sortable ~= false then
					widest = math.max(widest, TextWidth("v  " .. label) + 2, TextWidth("^  " .. label) + 2)
				end
				local hasValue = false
				for _, row in ipairs(rows) do
					local text = column.text and column.text(row)
					local badge = column.badge and column.badge(row)
					if text ~= nil and text ~= "" then
						hasValue = true
						widest = math.max(widest, TextWidth(text) + 2)
					end
					if badge ~= nil and badge ~= "" then
						hasValue = true
						widest = math.max(widest, TextWidth(badge, true) + 8)
					end
				end
				fitted[column.id] = column.fit and widest or nil
				hidden[column.id] = column.hideEmpty and not hasValue
			end
		end
	end

	-- Where each column sits, worked out from the list's width.
	local left, width = {}, {}
	local function Layout()
		local available = (scrollBox:GetWidth() or 0)
		local fixed, count, padding = 0, 0, options.gap or 8
		for _, column in ipairs(columns) do
			if not hidden[column.id] then
				count = count + 1
				if not column.flex then
					fixed = fixed + WidthOf(column)
				end
			end
		end
		local flex = math.max(60, available - fixed - padding * (count + 1))
		local x = padding
		for index, column in ipairs(columns) do
			left[index] = x
			width[index] = hidden[column.id] and 0 or (column.flex and flex or WidthOf(column))
			if not hidden[column.id] then
				x = x + width[index] + padding
			end
		end
	end

	local headers, grips = {}, {}
	local PaintHeaders, Repaint

	-- A grip sits on the line between two columns, and the line follows the
	-- mouse. Which widths change to make that happen depends on where the
	-- stretchy column is:
	--   stretchy column to the right of the line: the column on the left of
	--     the line grows, and the stretchy one gives up the room.
	--   stretchy column on the left of the line, or is the left one: the column
	--     on the right shrinks, and what it gives up goes to the column on the
	--     left (by itself when that one is the stretchy column).
	local flexIndex
	for index, column in ipairs(columns) do
		if column.flex then
			flexIndex = index
		end
	end

	local function BuildGrip(index)
		local before, after = columns[index], columns[index + 1]
		local options = { min = Theme.columnMin, max = Theme.columnMax }
		-- No grip on a line whose drag would have to resize a fixed column.
		local resized = (not flexIndex or flexIndex > index) and before or after
		if resized.fixed or (resized == after and not before.flex and before.fixed) then
			return nil
		end
		if not flexIndex or flexIndex > index then
			options.direction = 1
			options.get = function()
				return WidthOf(before)
			end
			options.set = function(size)
				dragged[before.id] = size
				Repaint()
			end
		else
			options.direction = -1
			options.get = function()
				return WidthOf(after)
			end
			options.set = function(size)
				local given = WidthOf(after) - size
				if not before.flex then
					-- Hand the room to the left column, as far as it can take it.
					local grown = math.max(Theme.columnMin, math.min(Theme.columnMax, WidthOf(before) + given))
					given = grown - WidthOf(before)
					dragged[before.id] = grown
				end
				dragged[after.id] = WidthOf(after) - given
				Repaint()
			end
		end
		local grip = Kit.Sizer(header, options)
		grip:SetHeight(Theme.headerHeight)
		return grip
	end

	function PaintHeaders()
		for index = 1, #columns - 1 do
			if grips[index] == nil then
				grips[index] = BuildGrip(index) or false
			end
			local grip = grips[index]
			if grip then
				grip:SetShown(not hidden[columns[index].id] and not hidden[columns[index + 1].id])
				grip:ClearAllPoints()
				grip:SetPoint("LEFT", left[index] + width[index] + (options.gap or 8) / 2 - Theme.sizerWidth / 2, 0)
			end
		end
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
			cell:SetShown(not hidden[column.id])
			cell:ClearAllPoints()
			cell:SetPoint("LEFT", left[index], 0)
			cell:SetWidth(width[index])
			local arrow = ""
			if sort.id == column.id then
				arrow = sort.descending and "v  " or "^  "
			end
			cell.label:SetTextColor(unpack(column.labelColor or C.accent))
			-- Put the marker before the heading, keeping its right edge aligned
			-- with the values underneath in number columns.
			cell.label:SetText(arrow .. (column.label or ""))
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
			local visible = not hidden[column.id]
			cell.text:SetShown(visible)
			if cell.icon then
				cell.icon:ClearAllPoints()
				cell.icon:SetPoint("LEFT", x, 0)
				-- No icon, no box: an empty square looks like something to click.
				local art = column.icon(data)
				cell.icon:SetIcon(art)
				cell.icon:SetShown(visible and art ~= nil)
				x = x + rowHeight - 1
				w = w - (rowHeight - 1)
			end
			cell.text:ClearAllPoints()
			cell.text:SetPoint("LEFT", x, 0)
			cell.text:SetWidth(math.max(1, w))
			cell.text:SetText(column.text and column.text(data) or "")
			cell.text:SetTextColor(unpack(column.color and column.color(data) or C.text))
			if cell.meter then
				cell.meter:SetShown(visible)
				cell.meter:ClearAllPoints()
				cell.meter:SetPoint("LEFT", x, 0)
				cell.meter:SetReading(column.meter(data))
			end
			if cell.badge then
				local label = column.badge(data)
				cell.badge:SetShown(visible and label ~= nil)
				if label then
					cell.badge:ClearAllPoints()
					cell.badge:SetPoint("RIGHT", row, "LEFT", x + w, 0)
					cell.badge:SetWidth(w - 4)
					cell.badgeText:SetText(label)
				end
			end
		end
	end

	-- Lays the columns out again and redraws what is on screen.
	function Repaint()
		Layout()
		PaintHeaders()
		pcall(scrollBox.ForEachFrame, scrollBox, function(row)
			if row.data then
				PaintRow(row, row.data)
			end
		end)
	end

	-- The window can be resized, and the stretchy column follows.
	local lastWidth
	list:SetScript("OnSizeChanged", function(_, newWidth)
		if left[1] and newWidth ~= lastWidth then
			lastWidth = newWidth
			Repaint()
		end
	end)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(rowHeight)
	view:SetElementInitializer("Frame", PaintRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	function list:SetRows(rows, keepScroll)
		Fit(rows)
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

-- Stacks frames down a column. :Paint(draw, ...) calls draw(...), which
-- calls :Add(frame, gap) for each frame that should show this time; frames
-- not added are hidden afterwards. A frame that stays is never hidden, even
-- for a moment, since hiding an edit box takes its keyboard focus and the
-- next key typed would go to the game.
function Kit.Stack(parent, inset)
	local stack = { y = inset or 8, known = {} }
	function stack:Paint(draw, ...)
		self.y = inset or 8
		local added = {}
		self.added = added
		draw(...)
		self.added = nil
		for frame in pairs(self.known) do
			if not added[frame] then
				frame:Hide()
			end
		end
	end
	function stack:Add(frame, gap, indent)
		self.known[frame] = true
		if self.added then
			self.added[frame] = true
		end
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

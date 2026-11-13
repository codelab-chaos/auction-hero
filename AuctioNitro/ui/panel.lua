-- Panel: the AuctioNitro window. It draws whatever table the view model hands
-- it and owns nothing but frames, the filter text and the window position.
local _, ns = ...
local Bus = ns.Bus
local L = ns.L

local Panel = {}
ns.Panel = Panel

-- ========= Layout and colors, as data =======================================
local LAYOUT = {
	width = 860,
	height = 520,
	minWidth = 660,
	minHeight = 320,
	maxWidth = 1400,
	maxHeight = 1100,
	inset = 8,
	gripSize = 16,
	headerHeight = 30,
	tabHeight = 22,
	tabGap = 3,
	controlsHeight = 24,
	progressHeight = 3,
	filterHeight = 24,
	columnsHeight = 18,
	footerHeight = 26,
	rowHeight = 18,
	rowSpacing = 1,
	cellPadding = 6,
	flexMinWidth = 90,
	scrollBarWidth = 12,
	sourceButtonWidth = 110,
	searchWidth = 180,
}

local COLORS = {
	panel = { 0.05, 0.04, 0.08, 0.94 },
	border = { 0.80, 0.65, 0.20, 1 },
	row = { 1, 1, 1, 0.04 },
	rowHeader = { 0.80, 0.65, 0.20, 0.14 },
	hover = { 1, 1, 1, 0.10 },
	tab = { 1, 1, 1, 0.08 },
	tabSelected = { 0.80, 0.65, 0.20, 0.45 },
	columns = { 1, 1, 1, 0.10 },
	bar = { 0.25, 0.75, 0.30, 1 },
	barBack = { 0, 0, 0, 0.5 },
}

local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Where each band of the window starts, measured down from the top edge.
local TOP = {}
TOP.tabs = LAYOUT.headerHeight
TOP.controls = TOP.tabs + LAYOUT.tabHeight + 6
TOP.progress = TOP.controls + LAYOUT.controlsHeight + 2
TOP.filter = TOP.progress + LAYOUT.progressHeight + 4
TOP.columns = TOP.filter + LAYOUT.filterHeight + 4
TOP.list = TOP.columns + LAYOUT.columnsHeight + 2

local frame, scrollBox, scrollBar, emptyText, statusText, progressBar
local cancelButton, searchBox, infoText, allRowsButton, footerText, saveButton, switchButton
local tabs, sourceButtons, columnHeaders = {}, {}, {}

local state = { search = "", itemKey = nil }
local model -- what the view model last built
local columnLeft, columnWidth = {}, {} -- where each column of the model sits
local layoutStamp = 0 -- bumps whenever the columns move, so rows re-anchor

-- ========= Columns ==========================================================
local function ComputeColumns()
	local columns = model.columns
	local available = scrollBox:GetWidth() or 0
	local fixed = 0
	for _, column in ipairs(columns) do
		if not column.flex then
			fixed = fixed + column.width
		end
	end
	local flexWidth = math.max(LAYOUT.flexMinWidth, available - fixed - LAYOUT.cellPadding * (#columns + 1))

	local x = LAYOUT.cellPadding
	for position, column in ipairs(columns) do
		local width = column.flex and flexWidth or column.width
		columnLeft[position] = x
		columnWidth[position] = width
		x = x + width + LAYOUT.cellPadding
	end
	layoutStamp = layoutStamp + 1
end

local function PlaceCell(cell, parent, position, column)
	cell:ClearAllPoints()
	cell:SetPoint("LEFT", parent, "LEFT", columnLeft[position], 0)
	cell:SetWidth(columnWidth[position])
	cell:SetJustifyH(column.align or "LEFT")
end

local function UpdateColumnHeaders()
	local view = model.view
	local sort = view and ns.ViewModel:SortFor(view)
	for position, column in ipairs(model.columns) do
		local header = columnHeaders[position]
		if not header then
			header = CreateFrame("Button", nil, frame)
			header:SetHeight(LAYOUT.columnsHeight)
			header.text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			header.text:SetWordWrap(false)
			header:SetScript("OnClick", function(self)
				Panel:SortBy(self.column)
			end)
			columnHeaders[position] = header
		end
		header.column = column
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", columnLeft[position], LAYOUT.columnsHeight + 2)
		header:SetWidth(columnWidth[position])
		header.text:ClearAllPoints()
		header.text:SetPoint(column.align or "LEFT")
		header.text:SetWidth(columnWidth[position])
		header.text:SetJustifyH(column.align or "LEFT")

		local label = column.label
		if sort and sort.field == column.field then
			label = label .. (sort.descending and " v" or " ^")
		end
		header.text:SetText(label)
		header:EnableMouse(column.sort ~= false and view ~= nil)
		header:Show()
	end
	for position = #model.columns + 1, #columnHeaders do
		columnHeaders[position]:Hide()
	end
end

-- ========= Rows =============================================================
local function ShowTip(row)
	local tip = model.Tip and row.element and model.Tip(row.element)
	if not tip then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
	local shown = false
	if tip.link then
		shown = pcall(GameTooltip.SetHyperlink, GameTooltip, tip.link)
	end
	if not shown then
		GameTooltip:SetText(tip.title or "")
	end
	for _, line in ipairs(tip.lines or {}) do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function BuildRow(row)
	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()

	row.hover = row:CreateTexture(nil, "BORDER")
	row.hover:SetAllPoints()
	row.hover:SetColorTexture(unpack(COLORS.hover))
	row.hover:Hide()

	row.cells = {}
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		self.hover:Show()
		ShowTip(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hover:Hide()
		GameTooltip:Hide()
	end)
	row:SetScript("OnMouseUp", function(self)
		if model.itemKeyOf and self.element then
			Panel:ShowRowsFor(model.itemKeyOf(self.element))
		end
	end)
	row.built = true
end

local function InitRow(row, element)
	if not row.built then
		BuildRow(row)
	end
	row.element = element
	row.background:SetColorTexture(unpack(element.header and COLORS.rowHeader or COLORS.row))

	local columns = model.columns
	local moved = row.stamp ~= layoutStamp
	for position, column in ipairs(columns) do
		local cell = row.cells[position]
		if not cell then
			cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			cell:SetWordWrap(false)
			row.cells[position] = cell
			moved = true
		end
		if moved then
			PlaceCell(cell, row, position, column)
		end
		cell:SetText(model.Cell(element, column))
		cell:Show()
	end
	if moved then
		for position, cell in ipairs(row.cells) do
			if columns[position] then
				PlaceCell(cell, row, position, columns[position])
			end
		end
		row.stamp = layoutStamp
	end
	for position = #columns + 1, #row.cells do
		row.cells[position]:Hide()
	end
end

-- ========= Refresh ==========================================================
local function UpdateTabs()
	for id, tab in pairs(tabs) do
		local color = (id == ns.charDb.view) and COLORS.tabSelected or COLORS.tab
		tab.background:SetColorTexture(unpack(color))
	end
end

local SAVE_STATE_TEXT = {
	disk = L.FOOTER_ON_DISK,
	memory = L.FOOTER_IN_MEMORY,
	never = L.FOOTER_NEVER,
}

-- The other cached snapshot, when there is one to switch to.
local function OtherCachedSource()
	local snapshot = ns.Store:GetSnapshot()
	for _, source in ipairs(ns.Store:GetCachedSources()) do
		if not snapshot or source.id ~= snapshot.meta.source then
			return source
		end
	end
end

local function UpdateFooter()
	local snapshot = ns.Store:GetSnapshot()
	local other = OtherCachedSource()
	switchButton.source = other
	switchButton:SetShown(other ~= nil)
	if other then
		switchButton:SetText(L.SWITCH_TO:format(other.label))
	end
	saveButton:SetShown(ns.Store:GetSaveState() == "memory")

	if not snapshot then
		footerText:SetText(L.FOOTER_NONE)
		return
	end
	local meta = snapshot.meta
	local text = L.FOOTER_SNAPSHOT:format(meta.sourceLabel, ns.Comma(meta.count), date("%Y-%m-%d %H:%M", meta.time))
	if meta.stale then
		text = text .. L.FOOTER_STALE
	end
	footerText:SetText(text .. "  " .. SAVE_STATE_TEXT[ns.Store:GetSaveState()])
end

local function UpdateSourceButtons()
	local enabled = ns.auctionHouseOpen == true and not ns.Downloader:IsRunning()
	for _, button in pairs(sourceButtons) do
		button:SetEnabled(enabled)
	end
	cancelButton:SetShown(ns.Downloader:IsRunning())
end

local function SetIdleStatus()
	if not ns.Downloader:IsRunning() then
		statusText:SetText(ns.auctionHouseOpen and L.STATUS_IDLE_OPEN or L.STATUS_IDLE)
		progressBar:Hide()
	end
end

-- Rebuilds the table for the current view. resetScroll jumps back to the top.
function Panel:Refresh(resetScroll)
	if not frame or not frame:IsShown() then
		return
	end
	model = ns.ViewModel:Build(ns.charDb.view, state)
	ComputeColumns()
	UpdateColumnHeaders()

	local retain = not resetScroll and ScrollBoxConstants.RetainScrollPosition or nil
	scrollBox:SetDataProvider(CreateDataProvider(model.elements), retain)
	emptyText:SetText(model.empty or "")
	emptyText:SetShown(#model.elements == 0)
	infoText:SetText(model.info or "")
	searchBox:SetShown(model.view ~= nil and model.view.search ~= nil)
	allRowsButton:SetShown(model.filteredToItem == true)
	UpdateFooter()
end

function Panel:SelectView(id, keepItem)
	ns.charDb.view = id
	if not keepItem then
		state.itemKey = nil
	end
	UpdateTabs()
	self:Refresh(true)
end

-- Jumps to the Rows view showing only one item's rows.
function Panel:ShowRowsFor(itemKey)
	state.itemKey = itemKey
	self:SelectView("rows", true)
end

-- Click a header to sort by it, click again to flip the direction.
function Panel:SortBy(column)
	local view = model and model.view
	if not view or column.sort == false then
		return
	end
	local current = ns.ViewModel:SortFor(view)
	local descending
	if current and current.field == column.field then
		descending = not current.descending
	else
		descending = column.align == "RIGHT" -- numbers start largest first, text starts at A
	end
	ns.charDb.sort[view.id] = { field = column.field, descending = descending }
	self:Refresh(true)
end

-- ========= Download status ==================================================
local StatusText = {
	waiting = function(s)
		return L.STATUS_WAITING:format(s.source.label)
	end,
	reading = function(s)
		if s.total then
			return L.STATUS_READING:format(s.source.label, ns.Comma(s.done), ns.Comma(s.total))
		end
		return L.STATUS_READING_OPEN:format(s.source.label, ns.Comma(s.done or 0))
	end,
	resolving = function(s)
		return L.STATUS_RESOLVING:format(s.source.label, ns.Comma(s.done), s.pass)
	end,
	done = function(s)
		return L.STATUS_DONE:format(s.source.label, ns.Comma(s.count), ns.Duration(s.elapsed))
	end,
	failed = function(s)
		return "|cffff6060" .. L.STATUS_FAILED:format(s.source.label, L[s.reason] or tostring(s.reason)) .. "|r"
	end,
}

local function OnDownloadState(s)
	if s.phase == "failed" and s.detail then
		ns.Print(s.detail)
	end
	if not frame then
		return
	end
	statusText:SetText(StatusText[s.phase](s))
	if s.phase == "reading" and s.total and s.total > 0 then
		progressBar:SetMinMaxValues(0, s.total)
		progressBar:SetValue(s.done)
		progressBar:Show()
	else
		progressBar:Hide()
	end
	UpdateSourceButtons()
end

-- ========= Construction =====================================================
local function SavePosition()
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	ns.charDb.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function RestorePosition()
	local position = ns.charDb.position
	frame:ClearAllPoints()
	if position then
		frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

local function BuildHeader()
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", LAYOUT.inset + 2, -LAYOUT.inset)
	title:SetText(L.TITLE)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 0, 0)

	-- Drag the header to move the window.
	local drag = CreateFrame("Frame", nil, frame)
	drag:SetPoint("TOPLEFT")
	drag:SetPoint("TOPRIGHT", close, "TOPLEFT")
	drag:SetHeight(LAYOUT.headerHeight)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	drag:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SavePosition()
	end)
end

-- Spreads the tabs evenly across the current window width.
local function LayoutTabs()
	local count = #ns.Views
	local width = frame:GetWidth() or LAYOUT.width
	local tabWidth = (width - LAYOUT.inset * 2 - LAYOUT.tabGap * (count - 1)) / count
	for position, view in ipairs(ns.Views) do
		local tab = tabs[view.id]
		tab:ClearAllPoints()
		tab:SetSize(tabWidth, LAYOUT.tabHeight)
		tab:SetPoint("TOPLEFT", LAYOUT.inset + (position - 1) * (tabWidth + LAYOUT.tabGap), -TOP.tabs)
	end
end

local function BuildTabs()
	for _, view in ipairs(ns.Views) do
		local tab = CreateFrame("Button", nil, frame)
		tab.background = tab:CreateTexture(nil, "BACKGROUND")
		tab.background:SetAllPoints()
		tab:SetNormalFontObject("GameFontHighlightSmall")
		tab:SetHighlightFontObject("GameFontNormalSmall")
		tab:SetText(view.label)
		tab:SetScript("OnClick", function()
			Panel:SelectView(view.id)
		end)
		tabs[view.id] = tab
	end
	LayoutTabs()
end

local function SourceTip(button)
	local source = button.source
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(source.label)
	GameTooltip:AddLine(source.tip, 1, 1, 1, true)
	if not ns.auctionHouseOpen then
		GameTooltip:AddLine(L.SOURCE_NEEDS_AH, 1, 0.4, 0.4, true)
	end
	local last = ns.db.lastFetch[source.id]
	if last and source.cooldownSeconds then
		local ago = GetServerTime() - last
		if ago >= 0 and ago < source.cooldownSeconds then
			local text = L.SOURCE_COOLDOWN:format(ns.Duration(ago), ns.Duration(source.cooldownSeconds))
			GameTooltip:AddLine(text, 1, 0.82, 0, true)
		end
	end
	GameTooltip:Show()
end

-- One button per source in data\sources.lua, then the status line.
local function BuildControls()
	local previous
	for _, source in ipairs(ns.Sources) do
		local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		button:SetSize(LAYOUT.sourceButtonWidth, LAYOUT.controlsHeight)
		if previous then
			button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
		else
			button:SetPoint("TOPLEFT", LAYOUT.inset, -TOP.controls)
		end
		button:SetText(source.label)
		button.source = source
		button:SetMotionScriptsWhileDisabled(true)
		button:SetScript("OnClick", function()
			ns.Downloader:Start(source.id)
		end)
		button:SetScript("OnEnter", SourceTip)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		sourceButtons[source.id] = button
		previous = button
	end

	cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	cancelButton:SetSize(70, LAYOUT.controlsHeight)
	cancelButton:SetPoint("LEFT", previous, "RIGHT", 4, 0)
	cancelButton:SetText(L.CANCEL)
	cancelButton:SetScript("OnClick", function()
		ns.Downloader:Cancel()
	end)
	cancelButton:Hide()

	statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	statusText:SetPoint("LEFT", previous, "RIGHT", 84, 0)
	statusText:SetPoint("RIGHT", frame, "RIGHT", -LAYOUT.inset, 0)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(false)

	progressBar = CreateFrame("StatusBar", nil, frame)
	progressBar:SetPoint("TOPLEFT", LAYOUT.inset, -TOP.progress)
	progressBar:SetPoint("TOPRIGHT", -LAYOUT.inset, -TOP.progress)
	progressBar:SetHeight(LAYOUT.progressHeight)
	progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	progressBar:SetStatusBarColor(unpack(COLORS.bar))
	progressBar.back = progressBar:CreateTexture(nil, "BACKGROUND")
	progressBar.back:SetAllPoints()
	progressBar.back:SetColorTexture(unpack(COLORS.barBack))
	progressBar:Hide()
end

local function BuildFilter()
	searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	searchBox:SetSize(LAYOUT.searchWidth, LAYOUT.filterHeight - 4)
	searchBox:SetPoint("TOPLEFT", LAYOUT.inset + 6, -TOP.filter)
	searchBox:SetAutoFocus(false)
	searchBox:HookScript("OnTextChanged", function(self)
		local text = (self:GetText() or ""):lower()
		if text ~= state.search then
			state.search = text
			state.itemKey = nil
			Panel:Refresh(true)
		end
	end)

	allRowsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	allRowsButton:SetSize(80, LAYOUT.filterHeight - 2)
	allRowsButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
	allRowsButton:SetText(L.SHOW_ALL)
	allRowsButton:SetScript("OnClick", function()
		state.itemKey = nil
		Panel:Refresh(true)
	end)
	allRowsButton:Hide()

	infoText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	infoText:SetPoint("TOPRIGHT", -LAYOUT.inset, -(TOP.filter + 5))
	infoText:SetJustifyH("RIGHT")
end

local function BuildList()
	local bottom = LAYOUT.inset + LAYOUT.footerHeight

	local columnsBack = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	columnsBack:SetPoint("TOPLEFT", LAYOUT.inset, -TOP.columns)
	columnsBack:SetPoint("TOPRIGHT", -LAYOUT.inset, -TOP.columns)
	columnsBack:SetHeight(LAYOUT.columnsHeight)
	columnsBack:SetColorTexture(unpack(COLORS.columns))

	scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", LAYOUT.inset, -TOP.list)
	scrollBox:SetPoint("BOTTOMRIGHT", -(LAYOUT.inset + LAYOUT.scrollBarWidth + 4), bottom)

	scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, -2)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 2)

	local listView = CreateScrollBoxListLinearView()
	listView:SetElementExtent(LAYOUT.rowHeight)
	listView:SetPadding(0, 0, 0, 0, LAYOUT.rowSpacing)
	listView:SetElementInitializer("Frame", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, listView)

	emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("CENTER", scrollBox, "CENTER")
	emptyText:SetWidth(LAYOUT.minWidth - 80)
end

local function FooterTip(button, title, text)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(title)
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function BuildFooter()
	footerText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footerText:SetPoint("BOTTOMLEFT", LAYOUT.inset + 2, LAYOUT.inset + 6)
	footerText:SetJustifyH("LEFT")

	local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	clear:SetSize(70, 22)
	clear:SetPoint("BOTTOMRIGHT", -(LAYOUT.inset + LAYOUT.gripSize), LAYOUT.inset)
	clear:SetText(L.CLEAR)
	clear:SetScript("OnClick", function()
		ns.Store:Clear()
		ns.EventLog:Clear()
	end)

	-- Shown while the snapshot being viewed has not reached the disk.
	saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	saveButton:SetSize(100, 22)
	saveButton:SetPoint("RIGHT", clear, "LEFT", -4, 0)
	saveButton:SetText(L.SAVE_NOW)
	saveButton:SetScript("OnClick", function()
		ReloadUI()
	end)
	FooterTip(saveButton, L.SAVE_NOW, L.SAVE_NOW_TIP)
	saveButton:Hide()

	-- Shown when both sources have a cached snapshot.
	switchButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	switchButton:SetSize(140, 22)
	switchButton:SetPoint("RIGHT", clear, "LEFT", -108, 0)
	switchButton:SetScript("OnClick", function(self)
		if self.source then
			ns.Store:SetActive(self.source.id)
		end
	end)
	FooterTip(switchButton, L.SWITCH_TIP, "")
	switchButton:Hide()
end

local function SaveSize()
	ns.charDb.size = { width = frame:GetWidth(), height = frame:GetHeight() }
end

-- A grip in the bottom right corner. Drag it to resize the window.
local function BuildResizeGrip()
	frame:SetResizable(true)
	frame:SetResizeBounds(LAYOUT.minWidth, LAYOUT.minHeight, LAYOUT.maxWidth, LAYOUT.maxHeight)

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(LAYOUT.gripSize, LAYOUT.gripSize)
	grip:SetPoint("BOTTOMRIGHT", -3, 3)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		SaveSize()
		SavePosition() -- sizing re-anchors the window
	end)

	frame:SetScript("OnSizeChanged", function()
		LayoutTabs()
		Panel:Refresh()
	end)
end

local function Build()
	frame = CreateFrame("Frame", "AuctioNitroPanel", UIParent, "BackdropTemplate")
	local size = ns.charDb.size
	frame:SetSize(size and size.width or LAYOUT.width, size and size.height or LAYOUT.height)
	frame:SetBackdrop(BACKDROP)
	frame:SetBackdropColor(unpack(COLORS.panel))
	frame:SetBackdropBorderColor(unpack(COLORS.border))
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	RestorePosition()

	BuildHeader()
	BuildTabs()
	BuildControls()
	BuildFilter()
	BuildList()
	BuildFooter()
	BuildResizeGrip()

	-- Escape closes the window.
	tinsert(UISpecialFrames, "AuctioNitroPanel")

	frame:SetScript("OnShow", function()
		ns.charDb.shown = true
		UpdateSourceButtons()
		SetIdleStatus()
		Panel:Refresh(true)
		-- Again on the next frame: the first pass runs before the list has its real size.
		C_Timer.After(0, function()
			Panel:Refresh()
		end)
	end)
	frame:SetScript("OnHide", function()
		ns.charDb.shown = false
	end)

	UpdateTabs()
	frame:Hide()
	if ns.charDb.shown then
		frame:Show()
	end
end

function Panel:Toggle()
	if frame then
		frame:SetShown(not frame:IsShown())
	end
end

function Panel:Show()
	if frame then
		frame:Show()
	end
end

Bus:On("READY", Build)

Bus:On("DOWNLOAD_STATE", OnDownloadState)

Bus:On("ANALYSIS_STATE", function(running)
	local snapshot = ns.Store:GetSnapshot()
	if frame and running and snapshot and not ns.Downloader:IsRunning() then
		statusText:SetText(L.STATUS_ANALYZING:format(ns.Comma(snapshot.meta.count)))
	end
end)

Bus:On("ANALYSIS_READY", function()
	Panel:Refresh(true)
end)

Bus:On("SNAPSHOT_CHANGED", function()
	if frame and frame:IsShown() then
		UpdateFooter()
	end
end)

Bus:On("SAVE_STATE_CHANGED", function()
	if frame and frame:IsShown() then
		UpdateFooter()
	end
end)

Bus:On("LOG_ADDED", function()
	if ns.charDb.view == "log" then
		Panel:Refresh()
	end
end)

local function OnAuctionHouseToggled()
	if frame then
		UpdateSourceButtons()
		SetIdleStatus()
	end
end

Bus:On("AH_OPENED", function()
	OnAuctionHouseToggled()
	if ns.IsEnabled("openWithAuctionHouse") then
		Panel:Show()
	end
end)

Bus:On("AH_CLOSED", OnAuctionHouseToggled)

-- Window: the AuctioNitro window. A title bar, a row of tabs, and the body of
-- whichever tab is chosen. Tabs register themselves (see ui\tabs), so this
-- file knows nothing about what any of them shows.
--
-- A tab is registered with:
--   id, label, order
--   debug     true to show the tab only while the debug switch is on
--   Create(parent) -> { Refresh = function() ... end }
-- Refresh is called when the tab is shown and whenever its data changes.
local _, ns = ...
local Bus = ns.Bus
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local Window = { tabs = {} }
ns.Window = Window

local frame, body, goldText, statusText, scanButton
local tabButtons, built = {}, {}

function Window:RegisterTab(tab)
	self.tabs[#self.tabs + 1] = tab
	table.sort(self.tabs, function(a, b)
		return a.order < b.order
	end)
end

-- The tabs to show right now: the debug ones only while the switch is on.
local function VisibleTabs()
	local visible = {}
	for _, tab in ipairs(Window.tabs) do
		if not tab.debug or ns.IsEnabled("debug") then
			visible[#visible + 1] = tab
		end
	end
	return visible
end

-- The market the trading tabs read, or nil with the reason why there is none.
function Window:Market()
	local market = ns.Analysis and ns.Analysis.market
	if market then
		return market
	end
	if ns.AnalysisStatus and ns.AnalysisStatus.phase == "loading" then
		return nil, L.WIN_ANALYZING
	end
	return nil, L.WIN_NO_MARKET
end

function Window:RefreshActive()
	if not frame or not frame:IsShown() then
		return
	end
	goldText:SetText(L.WIN_YOUR_GOLD:format(ns.Money(GetMoney())))
	local tab = built[ns.charDb.tab]
	if tab then
		tab.Refresh()
	end
end

local function ShowTab(id)
	local visible = VisibleTabs()
	local chosen = visible[1]
	for _, tab in ipairs(visible) do
		if tab.id == id then
			chosen = tab
		end
	end
	if not chosen then
		return
	end
	ns.charDb.tab = chosen.id

	for _, button in pairs(tabButtons) do
		button:Hide()
	end
	local x = Theme.pad
	for _, tab in ipairs(visible) do
		local button = tabButtons[tab.id]
		if not button then
			button = Kit.Button(frame, {
				text = tab.label,
				look = "tab",
				size = "large",
				width = Theme.tabWidth,
				height = Theme.tabHeight,
				onClick = function()
					ShowTab(tab.id)
				end,
			})
			tabButtons[tab.id] = button
		end
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", x, -(Theme.titleHeight + 6))
		button:SetActive(tab.id == chosen.id)
		button:Show()
		x = x + Theme.tabWidth + 2
	end

	for id, tab in pairs(built) do
		tab.frame:SetShown(id == chosen.id)
	end
	if not built[chosen.id] then
		local holder = CreateFrame("Frame", nil, body)
		holder:SetAllPoints()
		local tab = chosen.Create(holder)
		tab.frame = holder
		built[chosen.id] = tab
	end
	Window:RefreshActive()
end

-- ========= Scan status ======================================================
local StatusText = {
	waiting = function(state)
		return L.STATUS_WAITING:format(state.source.label)
	end,
	reading = function(state)
		if state.total then
			return L.STATUS_READING:format(state.source.label, ns.Comma(state.done), ns.Comma(state.total))
		end
		return L.STATUS_READING_OPEN:format(state.source.label, ns.Comma(state.done or 0))
	end,
	resolving = function(state)
		return L.STATUS_RESOLVING:format(state.source.label, ns.Comma(state.done), state.pass or 0)
	end,
	done = function(state)
		return L.STATUS_DONE:format(state.source.label, ns.Comma(state.count), ns.Duration(state.elapsed))
	end,
	failed = function(state)
		return L.STATUS_FAILED:format(state.source.label, L[state.reason] or tostring(state.reason))
	end,
}

local function IdleStatus()
	local snapshot = ns.Store:GetSourceSnapshot("replicate")
	if not snapshot then
		return L.WIN_NEEDS_SCAN
	end
	local age = math.max(0, GetServerTime() - (snapshot.meta.time or 0))
	return L.WIN_SCAN_AGE:format(ns.Duration(age), ns.Comma(snapshot.meta.count or 0), ns.Comma(ns.History:ScanCount()))
end

local function UpdateScanBar(state)
	if not frame then
		return
	end
	local running = ns.Downloader:IsRunning()
	scanButton:SetLabel(running and L.CANCEL or L.WIN_SCAN)
	scanButton:SetDisabled(not running and not ns.auctionHouseOpen)
	if state and StatusText[state.phase] then
		statusText:SetText(StatusText[state.phase](state))
		statusText:SetTextColor(unpack(state.phase == "failed" and C.bad or C.muted))
	elseif not running then
		statusText:SetText(IdleStatus())
		statusText:SetTextColor(unpack(C.muted))
	end
end

-- ========= Construction =====================================================
local function SavePosition()
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	ns.charDb.windowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function Build()
	frame = CreateFrame("Frame", "AuctioNitroWindow", UIParent)
	frame:SetSize(Theme.window.width, Theme.window.height)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	Kit.Fill(frame, C.window)
	Kit.Border(frame, C.border, "OVERLAY")

	local position = ns.charDb.windowPosition
	if position then
		frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
	else
		frame:SetPoint("CENTER")
	end

	-- Title bar. Drag it to move the window.
	local title = CreateFrame("Frame", nil, frame)
	title:SetPoint("TOPLEFT", 1, -1)
	title:SetPoint("TOPRIGHT", -1, -1)
	title:SetHeight(Theme.titleHeight)
	Kit.Gradient(title, C.titleTop, C.titleBottom)
	local underline = Kit.Rule(title, C.border)
	underline:SetPoint("BOTTOMLEFT")
	underline:SetPoint("BOTTOMRIGHT")
	title:EnableMouse(true)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	title:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SavePosition()
	end)

	local name = Kit.Text(title, "title", C.accent)
	name:SetPoint("LEFT", 12, 0)
	name:SetText(L.TITLE)

	local close = Kit.Button(title, {
		text = "x",
		width = 22,
		height = 20,
		onClick = function()
			frame:Hide()
		end,
	})
	close:SetPoint("RIGHT", -5, 0)

	goldText = Kit.Text(title, "normal", C.muted, "RIGHT")
	goldText:SetPoint("RIGHT", close, "LEFT", -10, 0)

	scanButton = Kit.Button(title, {
		text = L.WIN_SCAN,
		height = 20,
		tip = { L.WIN_SCAN, L.WIN_SCAN_TIP },
		onClick = function()
			if ns.Downloader:IsRunning() then
				ns.Downloader:Cancel()
			else
				ns.Downloader:Start("replicate")
			end
		end,
	})
	scanButton:SetPoint("LEFT", name, "RIGHT", 14, 0)

	statusText = Kit.Text(title, "small", C.muted)
	statusText:SetPoint("LEFT", scanButton, "RIGHT", 8, 0)
	statusText:SetPoint("RIGHT", goldText, "LEFT", -12, 0)

	-- The line the tabs sit on, and the body under it.
	local tabLine = Kit.Rule(frame, C.line)
	local bodyTop = Theme.titleHeight + 6 + Theme.tabHeight
	tabLine:SetPoint("TOPLEFT", 1, -bodyTop)
	tabLine:SetPoint("TOPRIGHT", -1, -bodyTop)

	body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", Theme.pad, -(bodyTop + Theme.pad))
	body:SetPoint("BOTTOMRIGHT", -Theme.pad, Theme.pad)

	tinsert(UISpecialFrames, "AuctioNitroWindow") -- Escape closes it

	frame:SetScript("OnShow", function()
		ns.charDb.windowShown = true
		UpdateScanBar()
		ShowTab(ns.charDb.tab)
	end)
	frame:SetScript("OnHide", function()
		ns.charDb.windowShown = false
	end)
	frame:RegisterEvent("PLAYER_MONEY")
	frame:SetScript("OnEvent", function()
		Window:RefreshActive()
	end)

	frame:Hide()
	if ns.charDb.windowShown then
		frame:Show()
	end
end

function Window:Toggle()
	if frame then
		frame:SetShown(not frame:IsShown())
	end
end

function Window:Show()
	if frame then
		frame:Show()
	end
end

-- The tab row changes when the debug switch does.
function Window:RebuildTabs()
	if frame and frame:IsShown() then
		ShowTab(ns.charDb.tab)
	end
end

Bus:On("READY", Build)

Bus:On("DOWNLOAD_STATE", function(state)
	if state.phase == "failed" and state.detail then
		ns.Print(state.detail)
	end
	UpdateScanBar(state)
end)

for _, message in ipairs({ "ANALYSIS_READY", "HISTORY_CHANGED", "BAGS_CHANGED" }) do
	Bus:On(message, function()
		Window:RefreshActive()
	end)
end

Bus:On("ANALYSIS_STATE", function(running)
	if frame and running and not ns.Downloader:IsRunning() then
		statusText:SetText(L.WIN_ANALYZING)
	elseif frame and not running then
		UpdateScanBar()
	end
end)

Bus:On("SETTING_CHANGED", function(id)
	if id == "debug" then
		Window:RebuildTabs()
	end
end)

Bus:On("AH_OPENED", function()
	UpdateScanBar()
	if ns.IsEnabled("openWithAuctionHouse") then
		Window:Show()
	end
end)

Bus:On("AH_CLOSED", function()
	UpdateScanBar()
end)

-- Window: the Auction Hero window. A title bar, a row of tabs, and the body of
-- whichever tab is chosen. Tabs register themselves (see ui\tabs), so this
-- file knows nothing about what any of them shows.
--
-- A tab is registered with:
--   id, label, order
--   debug     true to show the tab only while the debug switch is on
--   duringScan true when it can be opened while a scan runs. Other tabs are
--             locked then: opening one builds and reads the market mid-scan.
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

local frame, body, goldText, statusText, footerStatus, scanButton
local tabButtons, built = {}, {}

function Window:RegisterTab(tab)
	self.tabs[#self.tabs + 1] = tab
	table.sort(self.tabs, function(a, b)
		return a.order < b.order
	end)
end

-- The tabs to show right now: the debug ones only while the switch is on,
-- and a tab with a setting (tab.setting) only while that setting is on.
local function VisibleTabs()
	local visible = {}
	for _, tab in ipairs(Window.tabs) do
		if (not tab.debug or ns.IsEnabled("debug")) and (not tab.setting or ns.IsEnabled(tab.setting)) then
			visible[#visible + 1] = tab
		end
	end
	return visible
end
Window.VisibleTabs = VisibleTabs

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

-- ========= Drawing ==========================================================
-- Data flows one way: the data changes and says so on the Bus, and the view
-- shown redraws from it. A view only reads. When to draw is decided by
-- ns.RedrawScheduler (ui\redraw-scheduler.lua): asks merge into one draw, a
-- slow draw gives notice first and comes at most every so often, a draw
-- asked for while one runs comes after it, and draws that keep asking for
-- more are stopped. One more guard: a data message fired while a view draws
-- is written to the event log once (ns.DrawSafeEvents lists the ones that
-- are fine), since a view changing data as it draws is how redraws start
-- feeding themselves.
local scheduler = ns.RedrawScheduler.New(ns.RedrawRule)
local refreshNote -- "Refreshing..." beside the gold
local warned = {}
local busy = {} -- reason -> true while background work for the view runs

-- Whether drawing a tab now is likely to hold the screen still: its last draw
-- did, or one has before and data has changed since it last drew (a tab that
-- keeps its work is only slow when it has to redo it).
function Window.LikelySlow(id)
	local timing = Window.timings[id] and Window.timings[id].draw
	if not timing then
		return false
	end
	return timing.last >= ns.SlowTabMs or (timing.worst >= ns.SlowTabMs and timing.version ~= ns.DataVersion)
end

-- "Refreshing..." shows while a slow draw waits, or work for the view runs
-- in the background.
local function PaintNote()
	if refreshNote then
		refreshNote:SetShown(scheduler:ShowsNotice() or next(busy) ~= nil)
	end
end

-- Draws the shown tab now.
function Window:RefreshActive()
	if not frame or not frame:IsShown() then
		return
	end
	if not scheduler:Begin() then
		return -- a draw is running: this one comes after it
	end
	goldText:SetText(L.WIN_YOUR_GOLD:format(ns.Money(GetMoney())))
	local tab = built[ns.charDb.tab]
	if tab then
		Window.Run(ns.charDb.tab, tab.Refresh)
	end
	if scheduler:Finish(GetTime()) == "loop" then
		ns.EventLog:Note("redraw loop stopped", ns.charDb.tab)
	end
	PaintNote()
end

-- Asks for the shown tab to be drawn on a coming frame (see the scheduler).
function Window:RequestRefresh()
	if not frame or not frame:IsShown() then
		return
	end
	scheduler:Request(GetTime(), Window.LikelySlow(ns.charDb.tab))
	PaintNote()
end

-- Work done in the background for what the player is looking at (a tab
-- recounting its filters, say) shows "Refreshing..." until it is done.
function Window:SetBusy(reason, on)
	busy[reason] = on or nil
	PaintNote()
end

-- Whether a draw is waiting for a coming frame.
function Window:IsRefreshPending()
	return scheduler:IsPending()
end

local drawDriver = CreateFrame("Frame")
drawDriver:SetScript("OnUpdate", function()
	if scheduler:Frame(GetTime()) then
		Window:RefreshActive()
	end
end)

Bus.watch = function(message)
	if scheduler.drawing and ns.DataEvents[message] and not ns.DrawSafeEvents[message] and not warned[message] then
		warned[message] = true
		ns.EventLog:Note("data changed while drawing", ns.charDb.tab, message, debugstack and debugstack(3, 4, 0) or "")
	end
end

-- Runs a tab's drawing. An error is written to the log and said once in
-- chat, with where it happened, instead of leaving a blank tab and no word
-- (the game hides Lua errors unless scriptErrors is on).
--
-- Each run is timed, per tab and phase ("build" the first time it is made,
-- "draw" each refresh), as Window.timings[id][phase] = { last, worst, runs }
-- in milliseconds. A run over ns.SlowTabMs is written to the event log, since
-- the game draws nothing while it lasts (/ah timings lists them).
local told = {}
Window.timings = {}
function Window.Run(id, fn, ...)
	return Window.Timed(id, "draw", fn, ...)
end
function Window.Timed(id, phase, fn, ...)
	local started = debugprofilestop()
	local ok, err = Window.Guarded(id, fn, ...)
	local spent = debugprofilestop() - started
	local byPhase = Window.timings[id] or {}
	Window.timings[id] = byPhase
	local timing = byPhase[phase] or { worst = 0, runs = 0 }
	byPhase[phase] = timing
	timing.last, timing.worst, timing.runs = spent, math.max(timing.worst, spent), timing.runs + 1
	timing.version = ns.DataVersion -- the data it was drawn from
	if spent >= ns.SlowTabMs then
		ns.EventLog:Note("slow tab", id, phase, math.floor(spent))
	end
	return ok, err
end
function Window.Guarded(id, fn, ...)
	local ok, err = xpcall(fn, function(message)
		return tostring(message) .. "\n" .. (debugstack and debugstack(2, 6, 0) or "")
	end, ...)
	if not ok then
		ns.EventLog:Note("tab error", id, err)
		if not told[id] then
			told[id] = true
			ns.Print(L.WIN_TAB_ERROR:format(id, (tostring(err):match("^[^\n]*"))))
		end
	end
	return ok
end

-- Whether a tab can be opened right now: not while a scan runs, unless it
-- says it can.
local function Openable(tab)
	return tab.duringScan or not (ns.Downloader and ns.Downloader:IsRunning())
end

-- Locks the tabs that cannot be opened mid-scan, and unlocks them after.
local function LockTabs()
	for _, tab in ipairs(Window.tabs) do
		local button = tabButtons[tab.id]
		if button then
			button:SetDisabled(not Openable(tab) and tab.id ~= ns.charDb.tab)
		end
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
	-- Tabs run from the left; a tab with align = "right" sits at the right end
	-- instead, in the same order. A tab with an icon shows it in place of its
	-- name, which becomes its tooltip.
	local function Button(tab)
		local button = tabButtons[tab.id]
		if not button then
			button = Kit.Button(frame, {
				text = not tab.icon and tab.label or nil,
				icon = tab.icon,
				tip = tab.icon and { tab.label } or nil,
				look = "tab",
				size = "large",
				width = tab.icon and Theme.tabIconWidth or Theme.tabWidth,
				height = Theme.tabHeight,
				onClick = function()
					if Openable(tab) then
						ShowTab(tab.id)
					end
				end,
			})
			button.tabId = tab.id
			tabButtons[tab.id] = button
		end
		button:ClearAllPoints()
		button:SetActive(tab.id == chosen.id)
		button:Show()
		return button, (tab.icon and Theme.tabIconWidth or Theme.tabWidth) + 2
	end
	local top = -(Theme.titleHeight + 6)
	local left, right = Theme.pad, Theme.pad
	local rightTabs = {}
	for _, tab in ipairs(visible) do
		if tab.align == "right" then
			rightTabs[#rightTabs + 1] = tab
		else
			local button, width = Button(tab)
			button:SetPoint("TOPLEFT", left, top)
			left = left + width
		end
	end
	for index = #rightTabs, 1, -1 do
		local button, width = Button(rightTabs[index])
		button:SetPoint("TOPRIGHT", -right, top)
		right = right + width
	end

	for id, tab in pairs(built) do
		tab.frame:SetShown(id == chosen.id)
	end
	if not built[chosen.id] then
		local holder = CreateFrame("Frame", nil, body)
		holder:SetAllPoints()
		Window.Timed(chosen.id, "build", function()
			local tab = chosen.Create(holder)
			tab.frame = holder
			built[chosen.id] = tab
		end)
	end
	LockTabs()
	-- A tab likely to be slow shows "Refreshing..." first.
	if Window.LikelySlow(chosen.id) then
		Window:RequestRefresh()
	else
		Window:RefreshActive()
	end
	ns.Bus:Fire("TAB_SHOWN", chosen.id)
end

-- Opens a tab on one thing, such as the Graphs tab on an item picked on the
-- Buy tab. The tab says how it takes the thing (Select, given to
-- RegisterTab), so the tab asking knows nothing of the tab asked.
function Window:OpenTab(id, subject)
	for _, tab in ipairs(VisibleTabs()) do
		if tab.id == id and Openable(tab) then
			if tab.Select then
				tab.Select(subject)
			end
			ShowTab(id)
		end
	end
end

-- The right click menu for an item (ns.ItemMenu), as entries for Kit.Menu.
function Window:ItemMenu(key)
	local entries = {}
	for _, entry in ipairs(ns.ItemMenu) do
		for _, tab in ipairs(VisibleTabs()) do
			if tab.id == entry.tab and tab.id ~= ns.charDb.tab and Openable(tab) then
				entries[#entries + 1] = { label = entry.label, onPick = function()
					Window:OpenTab(entry.tab, key)
				end }
			end
		end
	end
	return entries
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

-- Seconds since the last full scan, or nil when there has not been one.
local function ScanAge()
	local snapshot = ns.Store:GetSourceSnapshot("replicate")
	return snapshot and math.max(0, GetServerTime() - (snapshot.meta.time or 0)), snapshot
end

-- Seconds until the server will take another full scan, or 0 when it will.
local function ScanWait()
	local age = ScanAge()
	local cooldown = ns.SourceById.replicate.cooldownSeconds or 0
	return age and math.max(0, cooldown - age) or 0
end

local function IdleStatus()
	local age, snapshot = ScanAge()
	if not snapshot then
		return ns.savedLost and (ns.savedProblem == "trades" and L.WIN_SAVED_LOST_BEFORE or L.WIN_SAVED_LOST) or L.WIN_NEEDS_SCAN
	end
	local scans = ns.History:ScanCount()
	local text
	if scans == 1 then
		text = L.WIN_SCAN_AGE_ONE:format(ns.Ago(age), ns.Comma(snapshot.meta.count or 0))
	else
		text = L.WIN_SCAN_AGE:format(ns.Ago(age), ns.Comma(snapshot.meta.count or 0), ns.Comma(scans))
	end
	local wait = ScanWait()
	if wait > 0 then
		text = text .. L.WIN_SCAN_WAIT:format(math.ceil(wait / 60))
	end
	return text
end

local function UpdateScanBar(state)
	if not frame then
		return
	end
	local running = ns.Downloader:IsRunning()
	scanButton:SetLabel(running and L.CANCEL or L.WIN_SCAN)
	-- A scan can always be cancelled. Starting one needs the auction house
	-- open and the server's wait between full scans to be over.
	scanButton:SetDisabled(not running and (not ns.auctionHouseOpen or ScanWait() > 0))
	-- A running scan has the scan dialog up, which carries its progress under
	-- the bar; saying it here too would only repeat it. A refusal still shows.
	if running and not (state and state.phase == "failed") then
		statusText:SetText("")
	elseif state and StatusText[state.phase] then
		statusText:SetText(StatusText[state.phase](state))
		statusText:SetTextColor(unpack(state.phase == "failed" and C.bad or C.muted))
	elseif not running then
		-- Beside the button: only when the last scan was, or that it is still
		-- being read. The rest of what is known about it sits at the right of
		-- the footer.
		local analysis = ns.AnalysisStatus and ns.AnalysisStatus.phase
		local age = ScanAge()
		if analysis == "loading" then
			statusText:SetText(L.WIN_ANALYZING)
			statusText:SetTextColor(unpack(C.muted))
		elseif analysis == "error" then
			statusText:SetText(L.WIN_ANALYSIS_FAILED)
			statusText:SetTextColor(unpack(C.bad))
		else
			statusText:SetText(age and ns.Ago(age) or "")
			statusText:SetTextColor(unpack(C.muted))
		end
	end
	if footerStatus then
		footerStatus:SetText(IdleStatus())
	end
end

-- ========= Construction =====================================================
local function SavePosition()
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	ns.charDb.windowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function Build()
	frame = CreateFrame("Frame", "AuctionHeroWindow", UIParent)
	local minWidth, minHeight = Theme.windowMin.width, Theme.windowMin.height + Theme.footerHeight
	local maxWidth, maxHeight = Theme.windowMax.width, Theme.windowMax.height
	local size = ns.charDb.windowSize
	frame:SetSize(
		math.max(minWidth, math.min(maxWidth, size and size.width or Theme.window.width)),
		math.max(minHeight, math.min(maxHeight, size and size.height or Theme.window.height + Theme.footerHeight))
	)
	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
	end
	-- Share the normal panel layer so profession windows can come forward.
	frame:SetFrameStrata("MEDIUM")
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

	-- The brand: a gold coin, then the name.
	local brand = title:CreateTexture(nil, "ARTWORK")
	brand:SetSize(Theme.brandIconSize, Theme.brandIconSize)
	brand:SetPoint("LEFT", 10, 0)
	brand:SetTexture(Theme.brandIcon)
	brand:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- without the icon's own frame
	local name = Kit.Text(title, "title", C.accent)
	name:SetPoint("LEFT", brand, "RIGHT", 6, 0)
	name:SetText(L.TITLE)
	local badge = title:CreateTexture(nil, "ARTWORK")
	badge:SetSize(Theme.brandIconSize, Theme.brandIconSize)
	badge:SetPoint("LEFT", name, "RIGHT", 6, 0)
	badge:SetTexture(Theme.titleBadge)
	badge:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	-- "Early Access | feedback welcome": the second part is a link to the
	-- project page, shown as an address to copy.
	local early = Kit.Text(title, "small", C.muted)
	early:SetPoint("LEFT", badge, "RIGHT", 10, 0)
	early:SetText(L.WIN_EARLY_ACCESS)
	local feedback = CreateFrame("Button", nil, title)
	feedback.label = Kit.Text(feedback, "small", C.accent)
	feedback.label:SetPoint("LEFT")
	feedback.label:SetText(L.WIN_FEEDBACK)
	feedback:SetSize(math.floor(feedback.label:GetStringWidth() + 0.5), Theme.titleHeight)
	feedback:SetPoint("LEFT", early, "RIGHT", 0, 0)
	local linkLine = feedback:CreateTexture(nil, "ARTWORK")
	linkLine:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.6)
	linkLine:SetHeight(1)
	linkLine:SetPoint("TOPLEFT", feedback.label, "BOTTOMLEFT", 0, -1)
	linkLine:SetPoint("TOPRIGHT", feedback.label, "BOTTOMRIGHT", 0, -1)
	Kit.Tip(feedback, function()
		return { L.WIN_FEEDBACK, L.WIN_FEEDBACK_TIP, Theme.projectPage }
	end)
	local pageBox
	feedback:SetScript("OnClick", function()
		pageBox = pageBox or Kit.CopyBox(body)
		pageBox:Open(L.WIN_FEEDBACK_COPY, Theme.projectPage)
	end)

	-- The game's own red close button, so closing looks like every other window.
	local close = CreateFrame("Button", nil, title, "UIPanelCloseButtonNoScripts")
	close:SetSize(24, 24)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	close:SetPoint("RIGHT", -3, 0)

	local optionsButton = Kit.Button(title, {
		text = L.OPTIONS,
		height = 20,
		tip = { L.OPTIONS, L.OPTIONS_TIP },
		onClick = function()
			ns.Options:Open()
		end,
	})
	optionsButton:SetPoint("RIGHT", close, "LEFT", -6, 0)

	goldText = Kit.Text(title, "normal", C.muted, "RIGHT")
	goldText:SetPoint("RIGHT", optionsButton, "LEFT", -10, 0)
	-- The addon's version, from its TOC, so a screenshot says which one.
	local versionText = Kit.Text(title, "small", C.muted, "RIGHT")
	versionText:SetPoint("RIGHT", goldText, "LEFT", -12, 0)
	versionText:SetText(L.WIN_VERSION:format(ns.AddonVersion()))
	refreshNote = Kit.Text(title, "small", C.accent, "RIGHT")
	refreshNote:SetPoint("RIGHT", versionText, "LEFT", -10, 0)
	refreshNote:SetText(L.WIN_REFRESHING)
	refreshNote:Hide()

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
	scanButton:SetPoint("LEFT", feedback, "RIGHT", 12, 0)

	statusText = Kit.Text(title, "small", C.muted)
	statusText:SetPoint("LEFT", scanButton, "RIGHT", 8, 0)
	statusText:SetPoint("RIGHT", versionText, "LEFT", -12, 0)

	-- The line the tabs sit on, and the body under it.
	local tabLine = Kit.Rule(frame, C.line)
	local bodyTop = Theme.titleHeight + 6 + Theme.tabHeight
	tabLine:SetPoint("TOPLEFT", 1, -bodyTop)
	tabLine:SetPoint("TOPRIGHT", -1, -bodyTop)

	body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", Theme.pad, -(bodyTop + Theme.pad))
	body:SetPoint("BOTTOMRIGHT", -Theme.pad, Theme.pad + Theme.footerHeight)

	-- The footer: the last thing the addon did. Hovering lists the recent ones.
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetPoint("BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", -1, 1)
	footer:SetHeight(Theme.footerHeight)
	footer:EnableMouse(true)
	Kit.Fill(footer, C.panel)
	local footerLine = Kit.Rule(footer, C.line)
	footerLine:SetPoint("TOPLEFT")
	footerLine:SetPoint("TOPRIGHT")
	-- The corner grip that resizes the window, the same one chat windows use.
	local grip = CreateFrame("Button", nil, footer)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		ns.charDb.windowSize = { width = frame:GetWidth(), height = frame:GetHeight() }
		SavePosition()
		Window:RefreshActive()
	end)

	footerStatus = Kit.Text(footer, "small", C.muted, "RIGHT")
	footerStatus:SetPoint("RIGHT", -22, 0)
	local footerText = Kit.Text(footer, "small", C.muted)
	footerText:SetPoint("LEFT", 10, 0)
	footerText:SetPoint("RIGHT", footerStatus, "LEFT", -16, 0)
	footerText:SetWordWrap(false)
	local tones = { good = C.good, bad = C.bad }
	local function PaintFooter()
		local latest = ns.Activity:Latest()
		footerText:SetText(latest and (latest.clock .. "  " .. latest.text) or L.ACT_NONE)
		footerText:SetTextColor(unpack(latest and tones[latest.tone] or C.muted))
	end
	footer:SetScript("OnEnter", function(self)
		local entries = ns.Activity.entries
		if #entries == 0 then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 0, 2)
		GameTooltip:SetText(L.ACT_TITLE, 1, 0.82, 0)
		for _, entry in ipairs(entries) do
			local color = tones[entry.tone] or C.text
			GameTooltip:AddLine(entry.clock .. "  " .. entry.text, color[1], color[2], color[3])
		end
		GameTooltip:Show()
	end)
	footer:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	ns.Bus:On("ACTIVITY_ADDED", PaintFooter)
	PaintFooter()

	tinsert(UISpecialFrames, "AuctionHeroWindow") -- Escape closes it

	frame:SetScript("OnShow", function()
		frame:Raise() -- come forward when opened, then let clicks switch windows
		ns.charDb.windowShown = true
		UpdateScanBar()
		ShowTab(ns.charDb.tab)
	end)
	frame:SetScript("OnHide", function()
		ns.charDb.windowShown = false
		-- The player's choice: closing this window closes the auction house
		-- too. Never while a scan runs, which closing would throw away.
		if ns.IsEnabled("closeAuctionHouse") and ns.auctionHouseOpen and not ns.Downloader:IsRunning() then
			pcall(C_AuctionHouse.CloseAuctionHouse)
		end
	end)
	-- The scan's age and the wait for the next one move with the clock.
	C_Timer.NewTicker(20, function()
		if frame:IsShown() and not ns.Downloader:IsRunning() then
			UpdateScanBar()
		end
	end)
	frame:RegisterEvent("PLAYER_MONEY")
	frame:SetScript("OnEvent", function()
		Window:RequestRefresh()
	end)

	frame:Hide()
	if ns.charDb.windowShown then
		frame:Show()
	end
end

-- The area under the tabs, for things that cover the whole tab.
function Window:Body()
	return body
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
	LockTabs()
end)

for _, message in ipairs({ "ANALYSIS_READY", "HISTORY_CHANGED", "BAGS_CHANGED" }) do
	Bus:On(message, function()
		Window:RequestRefresh()
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
	for _, tab in ipairs(Window.tabs) do
		if tab.setting == id then
			Window:RebuildTabs()
		end
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

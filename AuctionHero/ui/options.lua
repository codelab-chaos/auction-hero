-- Options: the addon's own settings panel, opened from the Options button in
-- the title bar or /ah options. It covers the tab that is showing and is put
-- away with Close, Escape's close of the window, or the button again.
--
-- It is built from ns.Settings and ns.SettingSections, so a new switch or
-- section there appears here by itself.
-- Nothing is registered in the game's central options.
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local Options = {}
ns.Options = Options

local ROW_HEIGHT = 40 -- a switch: a label and one line of explanation
local NUMBER_ROW_HEIGHT = 52 -- a number: its explanation is longer and may take two lines
local HEADING_HEIGHT = 34 -- a rule and a section name

local panel
local rows = {}

local numberRows = {}
local headings = {} -- a labelled section's rule and heading, with its section

local footprint -- the line at the foot of the panel saying how much is kept

local function Paint()
	local kept = ns.Footprint:Read()
	local size = kept.megabytes and L.OPTIONS_DATA_MB:format(kept.megabytes) or L.OPTIONS_DATA_UNKNOWN
	footprint:SetText(L.OPTIONS_DATA:format(size, ns.Comma(kept.auctions), ns.Comma(kept.items), ns.Comma(kept.points), kept.days))
	for _, heading in ipairs(headings) do
		heading:SetShown(not heading.section.shown or heading.section.shown())
	end
	for _, row in ipairs(rows) do
		row:SetShown(not row.section.shown or row.section.shown())
		row.box:SetState(ns.IsEnabled(row.setting.id))
	end
	for _, row in ipairs(numberRows) do
		row:SetShown(not row.section.shown or row.section.shown())
		-- Leave the box alone while it is being typed in.
		if not row.input:HasFocus() then
			row.input:SetText(tostring(row.numberSetting.get()))
		end
	end
end

-- A rule across the panel with the section's name under it.
local function BuildHeading(parent, section, top)
	local heading = CreateFrame("Frame", nil, parent)
	heading:SetPoint("TOPLEFT", 16, -top)
	heading:SetPoint("TOPRIGHT", -16, -top)
	heading:SetHeight(HEADING_HEIGHT)
	local rule = Kit.Rule(heading)
	rule:SetPoint("TOPLEFT", 0, -8)
	rule:SetPoint("TOPRIGHT", 0, -8)
	local label = Kit.Text(heading, "normal", C.accent)
	label:SetPoint("TOPLEFT", 8, -18)
	label:SetText(section.label)
	heading.section = section
	return heading
end

-- A row for a number: a box to type it in, then its name and explanation.
local function BuildNumberRow(parent, setting, top)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", 16, -top)
	row:SetPoint("TOPRIGHT", -16, -top)
	row:SetHeight(NUMBER_ROW_HEIGHT - 6)
	-- Takes what was typed, kept inside the setting's limits.
	function row.Commit(text)
		local low, high = setting.limits()
		local number = tonumber(text)
		if number then
			setting.set(math.max(low, math.min(high, math.floor(number))))
			ns.Bus:Fire("SETTING_CHANGED", setting.id)
		end
	end
	row.input = Kit.Input(row, { width = 44, numeric = true, maxLetters = 3, justify = "CENTER", onChange = row.Commit })
	row.input:SetPoint("TOPLEFT", 8, -3)
	local low, high = setting.limits()
	local label = Kit.Text(row, "normal", C.text)
	label:SetPoint("TOPLEFT", 62, -5)
	label:SetText(setting.label)
	local tip = Kit.Text(row, "small", C.muted)
	tip:SetPoint("TOPLEFT", 62, -21)
	tip:SetPoint("RIGHT", -8, 0)
	tip:SetPoint("BOTTOM", 0, 2)
	tip:SetJustifyV("TOP")
	tip:SetWordWrap(true)
	tip:SetText((setting.tip or ""):format(low, high))
	row.numberSetting = setting
	return row
end

local function BuildRow(parent, setting, top)
	local row = CreateFrame("Button", nil, parent)
	row:SetPoint("TOPLEFT", 16, -top)
	row:SetPoint("TOPRIGHT", -16, -top)
	row:SetHeight(ROW_HEIGHT - 6)
	row.hover = Kit.Fill(row, C.rowHover, "BACKGROUND")
	row.hover:Hide()
	row.box = Kit.Check(row, 16)
	row.box:SetPoint("TOPLEFT", 8, -5)
	local label = Kit.Text(row, "normal", C.text)
	label:SetPoint("TOPLEFT", 34, -5)
	label:SetText(setting.label)
	local tip = Kit.Text(row, "small", C.muted)
	tip:SetPoint("TOPLEFT", 34, -21)
	tip:SetPoint("RIGHT", -8, 0)
	tip:SetPoint("BOTTOM", 0, 2)
	tip:SetJustifyV("TOP")
	tip:SetWordWrap(true)
	tip:SetText(setting.tip or "")
	row.setting = setting
	row:SetScript("OnEnter", function(self)
		self.hover:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hover:Hide()
	end)
	row:SetScript("OnClick", function()
		ns.SetEnabled(setting.id, not ns.IsEnabled(setting.id))
	end)
	return row
end

local function Build()
	local body = ns.Window:Body()
	panel = CreateFrame("Frame", nil, body)
	panel:SetAllPoints()
	panel:SetFrameLevel(body:GetFrameLevel() + 40)
	panel:EnableMouse(true) -- so clicks do not reach the tab underneath
	Kit.Fill(panel, C.window)
	Kit.Border(panel, C.line)
	panel:Hide()

	local title = Kit.Text(panel, "large", C.accent)
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText(L.OPTIONS)
	local close = Kit.Button(panel, { text = L.COPY_CLOSE, onClick = function()
		panel:Hide()
	end })
	close:SetPoint("TOPRIGHT", -12, -10)

	footprint = Kit.Text(panel, "small", C.muted)
	footprint:SetPoint("BOTTOMLEFT", 24, 12)
	footprint:SetPoint("BOTTOMRIGHT", -24, 12)

	local top = 48
	for _, section in ipairs(ns.SettingSections) do
		if section.label then
			headings[#headings + 1] = BuildHeading(panel, section, top)
			top = top + HEADING_HEIGHT
		end
		for _, setting in ipairs(ns.Settings) do
			if setting.section == section.id then
				local row = BuildRow(panel, setting, top)
				row.section = section
				rows[#rows + 1] = row
				top = top + ROW_HEIGHT
			end
		end
		for _, setting in ipairs(ns.NumberSettings) do
			if setting.section == section.id then
				local row = BuildNumberRow(panel, setting, top)
				row.section = section
				numberRows[#numberRows + 1] = row
				top = top + NUMBER_ROW_HEIGHT
			end
		end
	end
end

-- Shows the panel, or puts it away when it is already showing.
function Options:Open()
	ns.Window:Show()
	if not ns.Window:Body() then
		return
	end
	if not panel then
		Build()
	end
	panel:SetShown(not panel:IsShown())
	Paint()
end

ns.Bus:On("SETTING_CHANGED", function()
	if panel and panel:IsShown() then
		Paint()
	end
end)

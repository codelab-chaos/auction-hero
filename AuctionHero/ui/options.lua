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
local HEADING_HEIGHT = 34 -- a rule and a section name
local TEXT_LEFT = 34 -- where a row's name starts, lined up with the switches' names
-- A number setting's row, by its control: a label and a line of explanation,
-- and for choices room for a warning line under them.
local NUMBER_ROW_HEIGHT = { choices = 62, range = 44 }

local panel
local scroll -- the settings under the title, scrolled with the mouse wheel
local placed = {} -- every heading and row, with where its foot is in the scroll
local rows = {}

local numberRows = {}
local headings = {} -- a labelled section's rule and heading, with its section

local footprint -- the line at the foot of the panel saying how much is kept

local function Paint()
	local kept = ns.Footprint:Read()
	if kept then
		local size = kept.megabytes and L.OPTIONS_DATA_MB:format(kept.megabytes) or L.OPTIONS_DATA_UNKNOWN
		local journal = kept.journal and L.OPTIONS_JOURNAL:format(ns.Comma(kept.journal.scans), ns.Duration(kept.journal.reach), ns.Comma(kept.journal.changes)) or L.OPTIONS_JOURNAL_OFF
		footprint:SetText(L.OPTIONS_DATA:format(size, ns.Comma(kept.auctions), ns.Comma(kept.items), ns.Comma(kept.points), kept.days) .. " " .. journal)
	else
		footprint:SetText(L.TRACK_COUNTING)
	end
	for _, heading in ipairs(headings) do
		heading:SetShown(not heading.section.shown or heading.section.shown())
	end
	for _, row in ipairs(rows) do
		row:SetShown(not row.section.shown or row.section.shown())
		row.box:SetState(ns.IsEnabled(row.setting.id))
	end
	for _, row in ipairs(numberRows) do
		row:SetShown(not row.section.shown or row.section.shown())
		row:Paint()
	end
	-- Scroll only as far as the last row showing.
	local foot = 0
	for _, item in ipairs(placed) do
		if item.frame:IsShown() then
			foot = math.max(foot, item.foot)
		end
	end
	scroll:SetContentHeight(foot + 8)
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

-- A number setting's name and explanation, on the left of its row. The
-- explanation may be worked out each time it is shown.
local function NumberText(row, setting)
	local label = Kit.Text(row, "normal", C.text)
	label:SetPoint("TOPLEFT", TEXT_LEFT, -5)
	label:SetText(setting.label)
	row.tip = Kit.Text(row, "small", C.muted)
	row.tip:SetPoint("TOPLEFT", TEXT_LEFT, -21)
	row.tip:SetJustifyH("LEFT")
	row.tip:SetWordWrap(true)
	local function Tip()
		return type(setting.tip) == "function" and setting.tip() or setting.tip or ""
	end
	row.tip:SetText(Tip())
	return Tip
end

-- One of a few values, as a row of buttons on the right; a warning line under
-- the explanation when the setting has something to say about the pick.
local function BuildChoicesRow(row, setting)
	local Tip = NumberText(row, setting)
	local items = {}
	for _, value in ipairs(setting.choices()) do
		local label = type(setting.format) == "function" and setting.format(value) or setting.format and setting.format:format(value) or tostring(value)
		items[#items + 1] = { label = label, value = value }
	end
	local choices = Kit.Choices(row, {
		items = items,
		size = "small",
		padding = 10,
		isActive = function(item)
			return item.value == setting.get()
		end,
		onPick = function(item)
			setting.set(item.value)
			ns.Bus:Fire("SETTING_CHANGED", setting.id)
		end,
	})
	choices:SetPoint("TOPRIGHT", -8, -3)
	row.tip:SetPoint("RIGHT", choices, "LEFT", -12, 0)
	row.warning = Kit.Text(row, "small", C.bad)
	row.warning:SetPoint("TOPLEFT", TEXT_LEFT, -39)
	row.warning:SetPoint("RIGHT", -8, 0)
	row.warning:SetJustifyH("LEFT")
	row.warning:SetWordWrap(true)
	function row:Paint()
		choices:Refresh()
		self.tip:SetText(Tip())
		local warning = setting.warning and setting.warning()
		self.warning:SetText(warning or "")
		self.warning:SetShown(warning ~= nil)
	end
end

-- Two numbers on one row, under and over: "- [1] -> + [1]", each with arrows.
local function BuildRangeRow(row, setting)
	local Tip = NumberText(row, setting)
	local function Stepper(part)
		return Kit.Stepper(row, {
			width = 34,
			limits = setting.limits,
			onChange = function(number)
				part.set(number)
				ns.Bus:Fire("SETTING_CHANGED", setting.id)
			end,
		})
	end
	local high = Stepper(setting.high)
	high:SetPoint("TOPRIGHT", -8, -3)
	local plus = Kit.Text(row, "normal", C.text)
	plus:SetPoint("RIGHT", high, "LEFT", -4, 0)
	plus:SetText("+")
	local arrow = Kit.Text(row, "normal", C.muted)
	arrow:SetPoint("RIGHT", plus, "LEFT", -10, 0)
	arrow:SetText("->")
	local low = Stepper(setting.low)
	low:SetPoint("RIGHT", arrow, "LEFT", -10, 0)
	local minus = Kit.Text(row, "normal", C.text)
	minus:SetPoint("RIGHT", low, "LEFT", -4, 0)
	minus:SetText("-")
	row.tip:SetPoint("RIGHT", minus, "LEFT", -12, 0)
	row.low, row.high = low, high
	function row:Paint()
		low:SetNumber(setting.low.get())
		high:SetNumber(setting.high.get())
		self.tip:SetText(Tip())
	end
end

local NUMBER_ROWS = { choices = BuildChoicesRow, range = BuildRangeRow }

-- A row for a number setting, built by the kind of control its data names.
local function BuildNumberRow(parent, setting, top)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", 16, -top)
	row:SetPoint("TOPRIGHT", -16, -top)
	row:SetHeight(NUMBER_ROW_HEIGHT[setting.control] - 6)
	row.numberSetting = setting
	NUMBER_ROWS[setting.control](row, setting)
	return row
end

local function BuildRow(parent, setting, top)
	local row = CreateFrame("Button", nil, parent)
	row:SetPoint("TOPLEFT", 16, -top)
	row:SetPoint("TOPRIGHT", -16, -top)
	row:SetHeight(ROW_HEIGHT - 6)
	row.hover = Kit.Fill(row, C.settingsRow, "BACKGROUND")
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
	Kit.Fill(panel, C.settings)
	Kit.Border(panel, C.settingsBorder)
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
	footprint:SetJustifyH("LEFT")
	footprint:SetWordWrap(true)

	-- The settings scroll between the title and the line at the foot.
	scroll = Kit.Scroll(panel, { bar = C.settingsBorder })
	scroll:SetPoint("TOPLEFT", 0, -44)
	scroll:SetPoint("BOTTOMRIGHT", -6, 46)
	local content = scroll.content
	local function Place(frame, top, height)
		placed[#placed + 1] = { frame = frame, foot = top + height }
		return top + height
	end

	local top = 4
	for _, section in ipairs(ns.SettingSections) do
		if section.label then
			local heading = BuildHeading(content, section, top)
			headings[#headings + 1] = heading
			top = Place(heading, top, HEADING_HEIGHT)
		end
		for _, setting in ipairs(ns.Settings) do
			if setting.section == section.id then
				local row = BuildRow(content, setting, top)
				row.section = section
				rows[#rows + 1] = row
				top = Place(row, top, ROW_HEIGHT)
			end
		end
		for _, setting in ipairs(ns.NumberSettings) do
			if setting.section == section.id then
				local row = BuildNumberRow(content, setting, top)
				row.section = section
				numberRows[#numberRows + 1] = row
				top = Place(row, top, NUMBER_ROW_HEIGHT[setting.control])
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

-- A changed setting, or a new count of what is kept.
for _, event in ipairs({ "SETTING_CHANGED", "FOOTPRINT_READY" }) do
	ns.Bus:On(event, function()
		if panel and panel:IsShown() then
			Paint()
		end
	end)
end

-- The progress panel: today's scan with the streak, scan confidence, and the
-- Hero Coin balance. Shown on the scan card (ui\scan-shield.lua) and on the
-- Progress tab (ui\tabs\progress.lua). The rules and the look are
-- data\rewards.lua.
local _, ns = ...
local L, Kit = ns.L, ns.Kit
local Theme = ns.Theme
local C = Theme.color

local ProgressPanel = {}
ns.ProgressPanel = ProgressPanel

-- A panel frame width wide, laid out from its top. panel.height is how tall
-- it is; panel:Paint(earnedFrom) fills it in, and when earnedFrom is given
-- (the session's coins at some moment), says how many came since.
function ProgressPanel.Create(parent, width)
	local look = ns.RewardsLook
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetWidth(width)

	local goalsTitle = Kit.Text(panel, "normal", C.accent)
	goalsTitle:SetPoint("TOPLEFT", 0, 0)
	goalsTitle:SetText(L.GOALS_TITLE)
	panel.streak = Kit.Text(panel, "small", C.muted, "RIGHT")
	panel.streak:SetPoint("TOPRIGHT", 0, 0)
	panel.goals = {}
	for index in ipairs(ns.DailyGoals) do
		local rowY = -20 - (index - 1) * look.rowHeight
		local icon = panel:CreateTexture(nil, "ARTWORK")
		icon:SetSize(14, 14)
		icon:SetPoint("TOPLEFT", 4, rowY)
		local text = Kit.Text(panel, "normal", C.text)
		text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
		panel.goals[index] = { icon = icon, text = text }
	end

	-- Scan confidence: a meter, the level and the days behind it.
	local y = -20 - #ns.DailyGoals * look.rowHeight - 10
	local confidence = CreateFrame("Frame", nil, panel)
	confidence:SetPoint("TOPLEFT", 0, y)
	confidence:SetPoint("TOPRIGHT", 0, y)
	confidence:SetHeight(32)
	confidence:EnableMouse(true)
	Kit.Tip(confidence, { L.SCAN_CONF, L.SCAN_CONF_TIP:format(ns.ScanConfidenceRule.fullAtDays, ns.ScanConfidenceRule.windowDays) })
	local confName = Kit.Text(confidence, "normal", C.accent)
	confName:SetPoint("TOPLEFT")
	confName:SetText(L.SCAN_CONF)
	panel.confMeter = Kit.Meter(confidence, ns.ScanConfidenceRule.pips)
	panel.confMeter:SetPoint("LEFT", confName, "RIGHT", 10, 0)
	panel.confLevel = Kit.Text(confidence, "normal", C.text, "RIGHT")
	panel.confLevel:SetPoint("TOPRIGHT")
	panel.confFacts = Kit.Text(confidence, "small", C.muted)
	panel.confFacts:SetPoint("TOPLEFT", confName, "BOTTOMLEFT", 0, -3)

	-- Hero Coins: the coin, the balance and what today brought.
	y = y - 44
	local coins = CreateFrame("Frame", nil, panel)
	coins:SetPoint("TOPLEFT", 0, y)
	coins:SetPoint("TOPRIGHT", 0, y)
	coins:SetHeight(look.coinSize)
	coins:EnableMouse(true)
	Kit.Tip(coins, { L.HERO_COINS, L.HERO_COINS_TIP })
	local coin = coins:CreateTexture(nil, "ARTWORK")
	coin:SetSize(look.coinSize, look.coinSize)
	coin:SetPoint("LEFT")
	coin:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	coin:SetTexture(ns.HeroCoin.icon)
	panel.balance = Kit.Text(coins, "total", C.gold)
	panel.balance:SetPoint("LEFT", coin, "RIGHT", 10, 0)
	local name = Kit.Text(coins, "normal", C.accent)
	name:SetPoint("LEFT", panel.balance, "RIGHT", 8, 0)
	name:SetText(L.HERO_COINS)
	panel.today = Kit.Text(coins, "small", C.muted, "RIGHT")
	panel.today:SetPoint("RIGHT")
	panel.earned = Kit.Text(panel, "small", C.good)
	panel.earned:SetPoint("TOPLEFT", 0, y - look.coinSize - 8)
	panel.earned:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

	panel.height = -(y - look.coinSize - 8) + 14
	panel:SetHeight(panel.height)
	panel.Paint = ProgressPanel.Paint
	return panel
end

function ProgressPanel.Paint(panel, earnedFrom)
	local Coins = ns.HeroCoins
	local look = ns.RewardsLook
	for index, goal in ipairs(ns.DailyGoals) do
		local row = panel.goals[index]
		local met = Coins:Met(goal.id)
		row.icon:SetTexture(met and look.metIcon or look.openIcon)
		row.icon:SetDesaturated(not met)
		row.text:SetText(goal.label)
		row.text:SetTextColor(unpack(met and C.good or C.text))
	end
	local streak = Coins:Streak()
	panel.streak:SetText(streak == 0 and L.GOALS_STREAK_NONE or streak == 1 and L.GOALS_STREAK_ONE or L.GOALS_STREAK:format(streak))

	local reading = ns.ScanConfidence:Reading()
	panel.confMeter:SetReading(reading)
	panel.confLevel:SetText(L.SCAN_CONF_LINE:format(reading.percent, reading.level.label))
	panel.confLevel:SetTextColor(unpack(Theme.tone[reading.level.tone] or C.text))
	panel.confFacts:SetText(L.SCAN_CONF_FACTS:format(reading.days, reading.window))

	panel.balance:SetText(ns.Comma(Coins:Balance()))
	panel.today:SetText(L.HERO_COINS_TODAY:format(ns.Comma(Coins:TodayTotal())))
	local since = earnedFrom and Coins:EarnedThisSession() - earnedFrom or 0
	panel.earned:SetText(since > 0 and L.HERO_COINS_EARNED:format(ns.Comma(since)) or "")
end

-- Progress tab: the far right icon tab (only Debug, while on, sits after it). Left: today's scan, scan confidence
-- and the Hero Coin balance (the same panel as the scan card), then the
-- latest earnings. Right: the last days with a scan, the streak bonuses and
-- every way to earn with today's count. The rules are data\rewards.lua.
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local panel, days, bonuses, nextBonus, ways, recent

local LEFT_WIDTH = 420

local function Plus(coins)
	return L.HERO_COINS_PLUS:format(ns.Comma(coins))
end

local function WayLabel(id)
	local way = ns.HeroCoins:Way(id)
	return way and way.label or L.EARN_STREAK
end

local function PaintDays()
	for index, day in ipairs(ns.ScanConfidence:Days()) do
		local cell = days[index]
		cell.day = day
		cell.fill:SetColorTexture(unpack(day.scanned and Theme.tone.good or C.pipOff))
	end
end

local function PaintBonuses()
	local streak = ns.HeroCoins:Streak()
	local upcoming
	for _, row in ipairs(bonuses) do
		local reached = streak >= row.bonus.days
		row.text:SetTextColor(unpack(reached and C.good or C.text))
		if not reached and not upcoming then
			upcoming = row.bonus
		end
	end
	nextBonus:SetText(upcoming and L.PROGRESS_NEXT:format(upcoming.days - streak) or L.PROGRESS_ALL_BONUSES)
end

local function PaintWays()
	for _, row in ipairs(ways) do
		local way = row.way
		if way.perKey then
			row.count:SetText(L.EARN_ONCE_EACH)
			row.count:SetTextColor(unpack(C.muted))
		else
			local done = ns.HeroCoins:Today(way.id)
			row.count:SetText(L.EARN_TODAY:format(done, way.perDay))
			row.count:SetTextColor(unpack(done >= way.perDay and C.good or C.muted))
		end
	end
end

local function PaintRecent()
	local entries = ns.HeroCoins:Recent()
	for index, line in ipairs(recent) do
		local entry = entries[index]
		line.text:SetText(entry and WayLabel(entry.way) or (index == 1 and L.HERO_COINS_NONE or ""))
		line.coins:SetText(entry and Plus(entry.coins) or "")
	end
end

local function Refresh()
	if not panel then
		return
	end
	panel:Paint()
	PaintRecent()
	PaintDays()
	PaintBonuses()
	PaintWays()
end

local function Title(parent, text, x, y)
	local title = Kit.Text(parent, "normal", C.accent)
	title:SetPoint("TOPLEFT", x, y)
	title:SetText(text)
	return title
end

-- A label on the left and a small value on the right, across width.
local function Row(parent, x, y, width)
	local text = Kit.Text(parent, "normal", C.text)
	text:SetPoint("TOPLEFT", x, y)
	local value = Kit.Text(parent, "small", C.gold, "RIGHT")
	value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y - 1)
	return text, value
end

local function Create(parent)
	local pad = Theme.pad
	local look = ns.RewardsLook
	local inner = LEFT_WIDTH - pad * 4

	-- Left: the progress panel, as on the scan card, then the latest earnings.
	local left = Kit.Panel(parent)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(LEFT_WIDTH)
	panel = ns.ProgressPanel.Create(left, inner)
	panel:SetPoint("TOPLEFT", pad * 2, -pad * 2)
	local y = -pad * 2 - panel.height
	Title(left, L.HERO_COINS_RECENT, pad * 2, y)
	recent = {}
	for index = 1, look.recent do
		local text, coins = Row(left, pad * 2, y - 20 - (index - 1) * look.rowHeight, inner)
		recent[index] = { text = text, coins = coins }
	end

	-- Right: the last days, the streak bonuses, the ways to earn.
	local right = Kit.Panel(parent)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", pad, 0)
	right:SetPoint("BOTTOMRIGHT")
	local x = pad * 2
	y = -pad * 2
	Title(right, L.PROGRESS_DAYS:format(ns.ScanConfidenceRule.windowDays), x, y)
	days = {}
	local step = look.dayCell + look.dayGap
	for index = 1, ns.ScanConfidenceRule.windowDays do
		local column = (index - 1) % look.dayColumns
		local line = math.floor((index - 1) / look.dayColumns)
		local cell = CreateFrame("Frame", nil, right)
		cell:SetSize(look.dayCell, look.dayCell)
		cell:SetPoint("TOPLEFT", x + column * step, y - 20 - line * step)
		cell.fill = cell:CreateTexture(nil, "ARTWORK")
		cell.fill:SetAllPoints()
		cell:EnableMouse(true)
		Kit.Tip(cell, function()
			local day = cell.day
			return day and { day.day, day.scanned and L.PROGRESS_DAY_SCANNED or L.PROGRESS_DAY_MISSED } or nil
		end)
		days[index] = cell
	end
	local rows = math.ceil(ns.ScanConfidenceRule.windowDays / look.dayColumns)
	local width = look.dayColumns * step - look.dayGap
	local note = Kit.Text(right, "small", C.muted)
	note:SetPoint("TOPLEFT", x, y - 20 - rows * step - 2)
	note:SetText(L.PROGRESS_DAYS_NOTE:format(ns.ScanConfidenceRule.fullAtDays))

	-- The streak bonuses, beside the strip.
	local bx = x + width + pad * 3
	local bonusWidth = 200
	local bonusTitle = Title(right, L.PROGRESS_BONUSES, bx, y)
	nextBonus = Kit.Text(right, "small", C.muted)
	nextBonus:SetPoint("TOPLEFT", bonusTitle, "BOTTOMLEFT", 0, -4)
	bonuses = {}
	for index, bonus in ipairs(ns.StreakBonuses) do
		local text, coins = Row(right, bx, y - 36 - (index - 1) * look.rowHeight, bonusWidth)
		text:SetText(L.PROGRESS_BONUS:format(bonus.days))
		coins:SetText(Plus(bonus.coins))
		bonuses[index] = { bonus = bonus, text = text }
	end

	-- Every way to earn, with today's count against its cap.
	y = y - 20 - rows * step - 30
	Title(right, L.EARN_TITLE, x, y)
	ways = {}
	for index, way in ipairs(ns.HeroCoinWays) do
		local rowY = y - 20 - (index - 1) * look.rowHeight
		local text, coins = Row(right, x, rowY, 300)
		text:SetText(way.label)
		coins:SetText(Plus(way.coins))
		local count = Kit.Text(right, "small", C.muted)
		count:SetPoint("TOPLEFT", x + 310, rowY - 1)
		ways[index] = { way = way, count = count }
	end

	parent:HookScript("OnShow", Refresh)
	Refresh()
	return { Refresh = Refresh }
end

ns.Window:RegisterTab({ id = "progress", label = L.TAB_PROGRESS, order = 9, align = "right", icon = ns.RewardsLook.tabIcon, Create = Create })

-- Scans and coins change what the tab shows, so a shown tab follows them.
for _, event in ipairs({ "HISTORY_CHANGED", "REWARDS_CHANGED" }) do
	ns.Bus:On(event, function()
		if ns.charDb.tab == "progress" then
			ns.Window:RefreshActive()
		end
	end)
end

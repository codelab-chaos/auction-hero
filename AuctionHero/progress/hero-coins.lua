-- Hero Coins: a balance that piles up as the player uses Auction Hero. The
-- ways to earn, their caps and the streak bonuses are data (data\rewards.lua).
-- Nothing here changes a price or a deal.
--
-- Kept for the account, in ns.db.heroCoins:
--   balance   coins held
--   days      day ("2026-11-19") -> { way id -> times paid that day }
--   keys      "explore:buy" -> true, for ways that pay once per key
--   streaks   streak days already paid for the current streak
--   recent    the latest earnings, newest first: { time, way, coins }
local _, ns = ...
local Bus = ns.Bus

local Coins = { earned = 0 }
ns.HeroCoins = Coins

local SECONDS_PER_DAY = 86400
local KEEP_DAYS = 60 -- days of counts kept, for the streak

local ways = {}
for _, way in ipairs(ns.HeroCoinWays) do
	ways[way.id] = way
end

local function Saved()
	ns.db.rewards = nil -- the trinket pouch Hero Coins replaced
	ns.db.heroCoins = ns.db.heroCoins or {}
	local saved = ns.db.heroCoins
	saved.balance = saved.balance or 0
	saved.days = saved.days or {}
	saved.keys = saved.keys or {}
	saved.streaks = saved.streaks or {}
	saved.recent = saved.recent or {}
	return saved
end

local function Day(now)
	local days = Saved().days
	local key = ns.DayKey(now)
	days[key] = days[key] or {}
	return days[key]
end

function Coins:Way(id)
	return ways[id]
end

function Coins:Balance()
	return Saved().balance
end

-- Coins earned this session, for the scan card to say what a scan brought.
function Coins:EarnedThisSession()
	return self.earned
end

-- How many times a way has paid today.
function Coins:Today(wayId, now)
	return Day(now or GetServerTime())[wayId] or 0
end

-- Coins earned today, all ways together.
function Coins:TodayTotal(now)
	local total = 0
	for id, count in pairs(Day(now or GetServerTime())) do
		local way = ways[id]
		total = total + (way and way.coins * count or 0)
	end
	for _, entry in ipairs(Saved().recent) do
		if entry.way == "streak" and ns.DayKey(entry.time) == ns.DayKey(now) then
			total = total + entry.coins
		end
	end
	return total
end

function Coins:Recent()
	return Saved().recent
end

-- Whether the day's goal has been met.
function Coins:Met(goalId, now)
	return self:Today(goalId, now) > 0
end

local function Pay(wayId, coins, now)
	local saved = Saved()
	saved.balance = saved.balance + coins
	Coins.earned = Coins.earned + coins
	table.insert(saved.recent, 1, { time = now, way = wayId, coins = coins })
	while #saved.recent > ns.RewardsLook.keepRecent do
		table.remove(saved.recent)
	end
	ns.EventLog:Note("coins", wayId, coins)
	Bus:Fire("REWARDS_CHANGED", wayId, coins)
end

-- Days in a row, up to today, with a scan. A day not yet scanned today does
-- not break a streak that ran to yesterday.
function Coins:Streak(now)
	now = now or GetServerTime()
	local days = Saved().days
	local count = 0
	local day = now
	if not (days[ns.DayKey(day)] or {}).scan then
		day = day - SECONDS_PER_DAY
	end
	while (days[ns.DayKey(day)] or {}).scan do
		count = count + 1
		day = day - SECONDS_PER_DAY
	end
	return count
end

local function PayStreak(now)
	local streak = Coins:Streak(now)
	local saved = Saved()
	if streak <= 1 then
		saved.streaks = {} -- a new streak starts its bonuses over
	end
	for _, bonus in ipairs(ns.StreakBonuses) do
		if streak >= bonus.days and not saved.streaks[bonus.days] then
			saved.streaks[bonus.days] = true
			Pay("streak", bonus.coins, now)
		end
	end
end

local function Forget(now)
	local days = Saved().days
	local oldest = ns.DayKey(now - KEEP_DAYS * SECONDS_PER_DAY)
	for key in pairs(days) do
		if key < oldest then
			days[key] = nil
		end
	end
end

-- Pays for a way once, within its cap. Returns the coins paid, or 0.
function Coins:Earn(wayId, key, now)
	local way = ways[wayId]
	if not way then
		return 0
	end
	now = now or GetServerTime()
	local saved = Saved()
	if way.perKey then
		local id = wayId .. ":" .. tostring(key)
		if saved.keys[id] then
			return 0
		end
		saved.keys[id] = true
	else
		local today = Day(now)
		if (today[wayId] or 0) >= way.perDay then
			return 0
		end
		today[wayId] = (today[wayId] or 0) + 1
	end
	Pay(wayId, way.coins, now)
	if wayId == "scan" then
		PayStreak(now)
		Forget(now)
	end
	return way.coins
end

for message, trigger in pairs(ns.HeroCoinTriggers) do
	Bus:On(message, function(...)
		local wayId, key = trigger(...)
		if wayId then
			Coins:Earn(wayId, key)
		end
	end)
end

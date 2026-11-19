-- Hero Coins and scan confidence, as data. The rules are applied by
-- progress\hero-coins.lua and progress\scan-confidence.lua, and shown on the
-- scan card (ui\scan-shield.lua) and the Progress tab (ui\tabs\progress.lua).
--
-- Scan confidence says how well the remembered prices cover the market: the
-- more days in the last month with a full scan, the surer a "usual price" and
-- so a deal is. Hero Coins mean nothing in themselves. They pile up as the
-- player uses Auction Hero: a scan a day, buying, posting, selling, looking
-- around. Each way to earn has a daily cap, so nothing pays for hammering the
-- server, and one scan a day is all that is asked.
local _, ns = ...
local L = ns.L

local ICONS = "Interface\\Icons\\"

ns.ScanConfidenceRule = {
	windowDays = 30, -- the days looked back over
	fullAtDays = 20, -- scan on this many of them for full confidence
	pips = 5,
	-- From this percent up, this level.
	levels = {
		{ from = 0, label = L.SCAN_CONF_GUESS, pips = 1, tone = "bad" },
		{ from = 25, label = L.SCAN_CONF_HUNCH, pips = 2, tone = "warn" },
		{ from = 50, label = L.SCAN_CONF_FAIR, pips = 3, tone = "ok" },
		{ from = 75, label = L.SCAN_CONF_SURE, pips = 4, tone = "good" },
		{ from = 100, label = L.SCAN_CONF_ORACLE, pips = 5, tone = "good" },
	},
}

ns.HeroCoin = { label = L.HERO_COINS, icon = ICONS .. "INV_Misc_Coin_01" }

-- The ways to earn, in the order shown.
--   coins    paid each time
--   perDay   how many times a day it pays (the local calendar day)
--   perKey   pays once ever for each key instead (explore: each tab)
ns.HeroCoinWays = {
	{ id = "scan", coins = 10, perDay = 1, label = L.EARN_SCAN },
	{ id = "visit", coins = 1, perDay = 1, label = L.EARN_VISIT },
	{ id = "buy", coins = 2, perDay = 10, label = L.EARN_BUY },
	{ id = "post", coins = 2, perDay = 10, label = L.EARN_POST },
	{ id = "sale", coins = 3, perDay = 20, label = L.EARN_SALE },
	{ id = "explore", coins = 5, perKey = true, label = L.EARN_EXPLORE },
}

-- Which addon message earns what: return the way's id (and a key for a
-- perKey way), or nothing.
ns.HeroCoinTriggers = {
	DOWNLOAD_STATE = function(state)
		return state.phase == "done" and "scan" or nil
	end,
	AH_OPENED = function()
		return "visit"
	end,
	BUYING_CHANGED = function(state)
		return state.phase == "done" and "buy" or nil
	end,
	POSTING_CHANGED = function(state)
		return state.phase == "done" and "post" or nil
	end,
	LEDGER_CHANGED = function(entry)
		return entry and entry.kind == "sale" and "sale" or nil
	end,
	TAB_SHOWN = function(id)
		return "explore", id
	end,
}

-- Days in a row with a scan pay a bonus as each count is reached. A broken
-- streak starts them over.
ns.StreakBonuses = {
	{ days = 3, coins = 15 },
	{ days = 7, coins = 40 },
	{ days = 14, coins = 100 },
	{ days = 30, coins = 250 },
}

-- The day's goal: one full scan. More scans still count for confidence but
-- earn nothing more.
ns.DailyGoals = {
	{ id = "scan", label = L.GOAL_SCAN },
}

-- How the progress panel and the Progress tab draw it all.
ns.RewardsLook = {
	rowHeight = 18,
	coinSize = 28, -- the Hero Coin beside the balance
	recent = 6, -- recent earnings listed on the Progress tab
	keepRecent = 20, -- recent earnings kept
	metIcon = "Interface\\RaidFrame\\ReadyCheck-Ready",
	openIcon = "Interface\\RaidFrame\\ReadyCheck-Waiting",
	tabIcon = ICONS .. "INV_Misc_Bag_10", -- the Progress tab, at the far right
	dayCell = 22, -- a day in the last-days strip
	dayGap = 3,
	dayColumns = 7, -- a week to a line
}

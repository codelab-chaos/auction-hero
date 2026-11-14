-- Feature switches, as data. Flipped with /an set or in the game's options,
-- where every switch here shows up by itself.
local _, ns = ...
local L = ns.L

-- The options panel lists the switches by section, in this order. A section
-- with a label gets a rule and a heading above it. A section with a shown
-- test is left out of the panel while the test fails.
ns.SettingSections = {
	{ id = "general" },
	{
		id = "debug",
		label = L.OPTIONS_DEBUG,
		-- For working on the addon. Listed on a developer's account (/an dev,
		-- remembered on that machine) or while the Debug tab is on (/an debug).
		shown = function()
			return ns.db.dev == true or ns.IsEnabled("debug")
		end,
	},
}

-- In the order the options panel lists them within their section.
ns.Settings = {
	{ id = "openWithAuctionHouse", section = "general", default = true, label = L.SETTING_OPEN_WITH_AH, tip = L.SETTING_OPEN_WITH_AH_TIP },
	{ id = "itemTooltips", section = "general", default = true, label = L.SETTING_ITEM_TOOLTIPS, tip = L.SETTING_ITEM_TOOLTIPS_TIP },
	{ id = "railLarge", section = "general", default = false, label = L.SETTING_RAIL_LARGE, tip = L.SETTING_RAIL_LARGE_TIP },
	{ id = "logEvents", section = "debug", default = true, label = L.SETTING_LOG_EVENTS, tip = L.SETTING_LOG_EVENTS_TIP },
	{ id = "debug", section = "debug", default = false, label = L.SETTING_DEBUG, tip = L.SETTING_DEBUG_TIP },
}

-- Settings that are a number, listed in the options panel after their
-- section's switches. get and set say where the number lives.
ns.NumberSettings = {
	{
		id = "historyDays",
		section = "general",
		label = L.SETTING_HISTORY_DAYS,
		tip = L.SETTING_HISTORY_DAYS_TIP,
		limits = function()
			return ns.HistoryRule.graphPointsMin, ns.HistoryRule.graphPointsMax
		end,
		get = function()
			return ns.History:GraphDays()
		end,
		set = function(days)
			ns.History:SetGraphDays(days)
		end,
	},
}

ns.SettingById = {}
for _, setting in ipairs(ns.Settings) do
	ns.SettingById[setting.id] = setting
end

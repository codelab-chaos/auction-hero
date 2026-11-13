-- Feature switches, as data. Flipped with /an set.
local _, ns = ...
local L = ns.L

ns.Settings = {
	{ id = "persistRows", default = false, label = L.SETTING_PERSIST_ROWS, tip = L.SETTING_PERSIST_ROWS_TIP },
	{ id = "openWithAuctionHouse", default = true, label = L.SETTING_OPEN_WITH_AH, tip = L.SETTING_OPEN_WITH_AH_TIP },
	{ id = "logEvents", default = true, label = L.SETTING_LOG_EVENTS, tip = L.SETTING_LOG_EVENTS_TIP },
	{ id = "debug", default = false, label = L.SETTING_DEBUG, tip = L.SETTING_DEBUG_TIP },
}

ns.SettingById = {}
for _, setting in ipairs(ns.Settings) do
	ns.SettingById[setting.id] = setting
end

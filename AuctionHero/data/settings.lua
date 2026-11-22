-- Feature switches, as data. Flipped with /ah set or in the game's options,
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
		-- For working on the addon. Listed on a developer's account (/ah dev,
		-- remembered on that machine) or while the Debug tab is on (/ah debug).
		shown = function()
			return ns.db.dev == true or ns.IsEnabled("debug")
		end,
	},
}

-- In the order the options panel lists them within their section.
ns.Settings = {
	{ id = "openWithAuctionHouse", section = "general", default = true, label = L.SETTING_OPEN_WITH_AH, tip = L.SETTING_OPEN_WITH_AH_TIP },
	{ id = "closeAuctionHouse", section = "general", default = false, label = L.SETTING_CLOSE_AH, tip = L.SETTING_CLOSE_AH_TIP },
	{ id = "itemTooltips", section = "general", default = true, label = L.SETTING_ITEM_TOOLTIPS, tip = L.SETTING_ITEM_TOOLTIPS_TIP },
	{ id = "railLarge", section = "general", default = false, label = L.SETTING_RAIL_LARGE, tip = L.SETTING_RAIL_LARGE_TIP },
	{ id = "sellBagList", section = "general", default = false, label = L.SETTING_BAG_LIST, tip = L.SETTING_BAG_LIST_TIP },
	{ id = "logEvents", section = "debug", default = true, label = L.SETTING_LOG_EVENTS, tip = L.SETTING_LOG_EVENTS_TIP },
	{ id = "debug", section = "debug", default = false, label = L.SETTING_DEBUG, tip = L.SETTING_DEBUG_TIP },
}

-- Settings that are a number, listed in the options panel after their
-- section's switches. get and set say where the number lives.
ns.NumberSettings = {
	-- One of a few lengths. Picking a shorter one says what goes at the next scan.
	{
		id = "historyDays",
		section = "general",
		control = "choices",
		label = L.SETTING_HISTORY_DAYS,
		tip = L.SETTING_HISTORY_DAYS_TIP,
		choices = function()
			return ns.HistoryRule.dayChoices
		end,
		format = L.SETTING_DAYS,
		get = function()
			return ns.History:GraphDays()
		end,
		set = function(days)
			ns.History:SetGraphDays(days)
		end,
		warning = function()
			local from, now = ns.History:PendingTrim(), ns.History:GraphDays()
			return from and L.SETTING_HISTORY_TRIM:format(from - now, from)
		end,
	},
	-- Two numbers on one row: how far under and over the character's level.
	{
		id = "gearRange",
		section = "general",
		control = "range",
		label = L.SETTING_GEAR_RANGE,
		tip = function()
			local low, high = ns.Gear:LevelRange()
			return L.SETTING_GEAR_RANGE_TIP:format(ns.GearLevelRule.max, UnitLevel("player") or 1, low, high)
		end,
		limits = function()
			return 0, ns.GearLevelRule.max
		end,
		low = {
			get = function()
				return ns.Gear:Offset("below")
			end,
			set = function(levels)
				ns.Gear:SetOffset("below", levels)
			end,
		},
		high = {
			get = function()
				return ns.Gear:Offset("above")
			end,
			set = function(levels)
				ns.Gear:SetOffset("above", levels)
			end,
		},
	},
}

ns.SettingById = {}
for _, setting in ipairs(ns.Settings) do
	ns.SettingById[setting.id] = setting
end

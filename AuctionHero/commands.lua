-- Slash commands: /ah and /auctionhero. Commands are a data table of handlers.
local _, ns = ...
local L = ns.L

local function PrintHelp()
	ns.Print(L.CMD_HELP)
	ns.Print(L.CMD_HELP_TOGGLE)
	ns.Print(L.CMD_HELP_SCAN)
	ns.Print(L.CMD_HELP_CLEAR)
	ns.Print(L.CMD_HELP_SET)
	ns.Print(L.CMD_HELP_DEBUG)
	ns.Print(L.CMD_HELP_HISTORY)
	ns.Print(L.CMD_HELP_OPTIONS)
end

local function PrintSwitch(setting)
	ns.Print(L.CMD_SET_LINE:format(setting.id:lower(), ns.IsEnabled(setting.id) and L.ON or L.OFF, setting.label))
end

-- Switch ids are matched without case, since slash text is lowercased.
local function FindSwitch(name)
	for _, setting in ipairs(ns.Settings) do
		if setting.id:lower() == name then
			return setting
		end
	end
end

local commands = {
	[""] = function()
		ns.Window:Toggle()
	end,
	scan = function()
		ns.Window:Show()
		ns.Downloader:Start("replicate")
	end,
	browse = function()
		ns.Window:Show()
		ns.Downloader:Start("browse")
	end,
	cancel = function()
		ns.Downloader:Cancel()
	end,
	-- How long each tab took to build and draw: the last time and the worst.
	timings = function()
		local ids = {}
		for id in pairs(ns.Window.timings) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		if #ids == 0 then
			ns.Print(L.CMD_TIMINGS_NONE)
		end
		for _, id in ipairs(ids) do
			for _, phase in ipairs({ "build", "draw" }) do
				local timing = ns.Window.timings[id][phase]
				if timing then
					ns.Print(L.CMD_TIMINGS_LINE:format(id, phase, timing.last, timing.worst, timing.runs))
				end
			end
		end
	end,
	-- Shows or hides the Debug tab: /ah debug, or /ah debug on|off.
	-- Marks this account as a developer's: the options panel then always lists
	-- the Debug section, so the Debug tab can be switched on and off from there.
	-- Kept in the saved variables, so it stays set on this machine only.
	dev = function(value)
		local on = not ns.db.dev
		if value == "on" or value == "off" then
			on = value == "on"
		end
		ns.db.dev = on or nil
		ns.Print(on and L.CMD_DEV_ON or L.CMD_DEV_OFF)
		ns.Bus:Fire("SETTING_CHANGED", "dev")
	end,
	debug = function(value)
		local on = not ns.IsEnabled("debug")
		if value == "on" or value == "off" then
			on = value == "on"
		end
		ns.SetEnabled("debug", on)
		ns.Print(on and L.CMD_DEBUG_ON or L.CMD_DEBUG_OFF)
		ns.Window:Show()
	end,
	-- Posts what the Sell tab is showing, from a typed command instead of the
	-- button. A way to tell whether the game treats the two differently.
	post = function()
		local request = ns.SellRequest and ns.SellRequest()
		if request then
			ns.Posting:Post(request)
		else
			ns.Print(L.CMD_POST_NOTHING)
		end
	end,
	-- How many days of prices each item keeps for its graph: /ah history 60.
	-- With no number it says what the setting is.
	history = function(days)
		local number = tonumber(days)
		if number then
			ns.History:SetGraphDays(number)
		end
		ns.Print(L.CMD_HISTORY:format(ns.History:GraphDays(), ns.HistoryRule.graphPointsMin, ns.HistoryRule.graphPointsMax))
	end,
	-- Only the event log can be emptied. Scans and the price history cannot
	-- be cleared at all.
	clear = function(what)
		if what == "log" then
			ns.EventLog:Clear()
			ns.Print(L.CMD_CLEARED_LOG)
		else
			ns.Print(L.CMD_CLEAR_HOW)
		end
	end,
	set = function(name, value)
		if not name then
			for _, setting in ipairs(ns.Settings) do
				PrintSwitch(setting)
			end
			return
		end
		local setting = FindSwitch(name)
		if not setting then
			ns.Print(L.CMD_SET_UNKNOWN:format(name))
			return
		end
		if value == "on" or value == "off" then
			ns.SetEnabled(setting.id, value == "on")
		else
			ns.SetEnabled(setting.id, not ns.IsEnabled(setting.id))
		end
		PrintSwitch(setting)
	end,
	options = function()
		ns.Options:Open()
	end,
	-- Reads the open profession window into the recipe book now and says how
	-- it went, then lists what the book holds.
	recipes = function()
		local done, detail, extra = ns.RecipeBook:SafeRead()
		if done then
			ns.Print(L.CMD_RECIPES_READ:format(detail, extra))
		else
			ns.Print(L.CMD_RECIPES_NOT_READ:format(tostring(detail), ns.EventLog.Describe(extra, 0)))
		end
		for name, book in pairs(ns.RecipeBook:All()) do
			local count = 0
			for _ in pairs(book.recipes) do
				count = count + 1
			end
			ns.Print(L.CMD_RECIPES_BOOK:format(name, count))
		end
	end,
	help = PrintHelp,
}

SLASH_AUCTIONHERO1 = "/ah"
SLASH_AUCTIONHERO2 = "/auctionhero"
SlashCmdList["AUCTIONHERO"] = function(text)
	local words = {}
	for word in (text or ""):lower():gmatch("%S+") do
		words[#words + 1] = word
	end
	local handler = commands[words[1] or ""]
	if handler then
		handler(words[2], words[3])
	else
		PrintHelp()
	end
end

-- Click target for the minimap addon menu (see AddonCompartmentFunc in the TOC).
function AuctionHero_OnAddonCompartmentClick()
	ns.Window:Toggle()
end

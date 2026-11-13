-- Slash commands: /an and /auctionitro. Commands are a data table of handlers.
local _, ns = ...
local L = ns.L

local function PrintHelp()
	ns.Print(L.CMD_HELP)
	ns.Print(L.CMD_HELP_TOGGLE)
	ns.Print(L.CMD_HELP_SCAN)
	ns.Print(L.CMD_HELP_CLEAR)
	ns.Print(L.CMD_HELP_SET)
	ns.Print(L.CMD_HELP_DEBUG)
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
	-- Shows or hides the Debug tab: /an debug, or /an debug on|off.
	debug = function(value)
		local on = not ns.IsEnabled("debug")
		if value == "on" or value == "off" then
			on = value == "on"
		end
		ns.SetEnabled("debug", on)
		ns.Print(on and L.CMD_DEBUG_ON or L.CMD_DEBUG_OFF)
		ns.Window:Show()
	end,
	clear = function()
		ns.Store:Clear()
		ns.EventLog:Clear()
		ns.Print(L.CMD_CLEARED)
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
	help = PrintHelp,
}

SLASH_AUCTIONITRO1 = "/an"
SLASH_AUCTIONITRO2 = "/auctionitro"
SlashCmdList["AUCTIONITRO"] = function(text)
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
function AuctioNitro_OnAddonCompartmentClick()
	ns.Window:Toggle()
end

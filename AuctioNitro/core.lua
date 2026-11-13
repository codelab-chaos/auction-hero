-- Core: the shared addon table, a small message bus, text helpers and startup.
-- Every other file talks through ns.Bus, so modules never call each other directly.
local addonName, ns = ...

ns.name = addonName

-- ========= Message bus ======================================================
-- Messages used across the addon:
--   INIT                       saved variables are loaded
--   READY                      the player is in the world, safe to build UI
--   AH_OPENED / AH_CLOSED      the auction house window opened or closed
--   DOWNLOAD_STATE(state)      a download started, progressed, finished or failed
--   DOWNLOAD_FINISHED(meta, rows, items)  a download produced a snapshot
--   SNAPSHOT_CHANGED           the snapshot being viewed changed, or there is none
--   SAVE_STATE_CHANGED         whether the snapshot will reach the disk changed
--   ANALYSIS_STATE(running)    the analyzer started or stopped
--   ANALYSIS_READY             profile, derived data and the market are ready to show
--   HISTORY_CHANGED            a scan was folded into the price history
--   BAGS_CHANGED               what the player carries changed
--   LOG_ADDED                  the event log got a new line
--   SETTING_CHANGED(id, value) a feature switch was flipped
local Bus = { handlers = {} }
ns.Bus = Bus

function Bus:On(message, handler)
	local list = self.handlers[message]
	if not list then
		list = {}
		self.handlers[message] = list
	end
	list[#list + 1] = handler
end

function Bus:Fire(message, ...)
	local list = self.handlers[message]
	if not list then
		return
	end
	for i = 1, #list do
		list[i](...)
	end
end

-- ========= Text helpers =====================================================

-- 2450 -> "2,450"
function ns.Comma(number)
	local text = tostring(math.floor(number))
	local count
	repeat
		text, count = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- Copper -> "12g 34s 56c". Zero parts on the left are dropped.
function ns.Money(copper)
	if not copper then
		return ""
	end
	copper = math.floor(copper)
	local gold = math.floor(copper / 10000)
	local silver = math.floor(copper / 100) % 100
	local rest = copper % 100
	if gold > 0 then
		return ("|cffffd100%sg|r |cffc7c7cf%02ds|r |cffeda55f%02dc|r"):format(ns.Comma(gold), silver, rest)
	elseif silver > 0 then
		return ("|cffc7c7cf%ds|r |cffeda55f%02dc|r"):format(silver, rest)
	end
	return ("|cffeda55f%dc|r"):format(rest)
end

-- Seconds -> "4s", "3m 05s", "2h 10m"
function ns.Duration(seconds)
	seconds = math.floor(seconds)
	if seconds < 60 then
		return ("%ds"):format(seconds)
	elseif seconds < 3600 then
		return ("%dm %02ds"):format(math.floor(seconds / 60), seconds % 60)
	end
	return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60)
end

function ns.Print(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[" .. ns.L.TITLE .. "]|r " .. text)
end

-- ========= Saved variables ==================================================
local ACCOUNT_DEFAULTS = {
	switches = {}, -- filled from data\settings.lua at startup
	lastFetch = {}, -- source id -> server time of the last download
}

local CHARACTER_DEFAULTS = {
	view = "summary",
	shown = false,
	sort = {}, -- view id -> { field, descending }
}

local function ApplyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			ApplyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

-- ========= Feature switches =================================================
function ns.IsEnabled(id)
	return ns.db.switches[id] == true
end

function ns.SetEnabled(id, value)
	if not ns.SettingById[id] then
		return false
	end
	ns.db.switches[id] = value and true or false
	Bus:Fire("SETTING_CHANGED", id, ns.db.switches[id])
	return true
end

-- ========= Startup ==========================================================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		AuctioNitroDB = AuctioNitroDB or {}
		AuctioNitroCharDB = AuctioNitroCharDB or {}
		for _, setting in ipairs(ns.Settings) do
			ACCOUNT_DEFAULTS.switches[setting.id] = setting.default
		end
		ApplyDefaults(AuctioNitroDB, ACCOUNT_DEFAULTS)
		ApplyDefaults(AuctioNitroCharDB, CHARACTER_DEFAULTS)
		ns.db = AuctioNitroDB
		ns.charDb = AuctioNitroCharDB
		Bus:Fire("INIT")
	elseif event == "PLAYER_LOGIN" then
		Bus:Fire("READY")
	elseif event == "AUCTION_HOUSE_SHOW" then
		ns.auctionHouseOpen = true
		Bus:Fire("AH_OPENED")
	elseif event == "AUCTION_HOUSE_CLOSED" then
		ns.auctionHouseOpen = false
		Bus:Fire("AH_CLOSED")
	end
end)

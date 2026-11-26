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
--   ANALYSIS_STATE(running)    the analyzer started or stopped
--   ANALYSIS_READY             profile, derived data and the market are ready to show
--   HISTORY_CHANGED            a scan was folded into the price history
--   BAGS_CHANGED               what the player carries changed
--   OWNED_CHANGED              the list of the player's own auctions was refreshed
--   POSTING_CHANGED(state)     a post started, needs confirming, finished or failed
--   BUYING_CHANGED(state)      a purchase was quoted, confirmed, finished or failed
--   LOG_ADDED                  the event log got a new line
--   SETTING_CHANGED(id, value) a feature switch was flipped
--   ACTIVITY_ADDED             the footer's list of recent actions got a line
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

-- The addon's version as its TOC says, "?" when the game will not say.
function ns.AddonVersion()
	local read = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local ok, version = pcall(read, "AuctionHero", "Version")
	return ok and version or "?"
end

-- Bus.watch, when set, hears every message first (see ui\window.lua, which
-- uses it to catch a view firing messages while it draws).
function Bus:Fire(message, ...)
	local kind = ns.DataEvents and ns.DataEvents[message]
	if kind then
		ns.DataChanged(kind)
	end
	if self.watch then
		self.watch(message)
	end
	local list = self.handlers[message]
	if not list then
		return
	end
	for i = 1, #list do
		list[i](...)
	end
end

-- ========= Item helpers =====================================================

-- How many units one auction of an item really holds. The auction house's
-- live search can report a count for items that do not stack (a bag listed
-- once comes back as "68"), which would split one price into many cheap
-- units. The count is held to the item's stack size; nil or junk reads as 1.
-- Stack sizes are kept once known, since every scan row asks.
-- How many of an item the player holds: the bags, and the bank too when
-- asked (the game counts it once the bank was opened). This client has only
-- C_Item.GetItemCount; the old global is used where C_Item lacks it.
function ns.ItemCount(itemID, includeBank)
	local count = C_Item and C_Item.GetItemCount
	if not count then
		count = GetItemCount
	end
	if not count or not itemID then
		return 0
	end
	local ok, held = pcall(count, itemID, includeBank == true)
	return ok and tonumber(held) or 0
end

local maxStack = {}
-- How many of an item fit in one bag slot, or nil while the game cannot say.
function ns.MaxStack(itemID)
	local most = itemID and maxStack[itemID]
	if not most and itemID and C_Item and C_Item.GetItemMaxStackSizeByID then
		local ok, read = pcall(C_Item.GetItemMaxStackSizeByID, itemID)
		if ok and type(read) == "number" and read >= 1 then
			most = read
			maxStack[itemID] = read
		end
	end
	return most
end

function ns.AuctionUnits(itemID, quantity)
	quantity = math.max(1, tonumber(quantity) or 1)
	if quantity == 1 or not itemID then
		return quantity
	end
	local most = ns.MaxStack(itemID)
	return most and math.min(quantity, most) or quantity
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
		return ("|cffffd100%sg|r |cffc7c7cf%ds|r |cffeda55f%dc|r"):format(ns.Comma(gold), silver, rest)
	elseif silver > 0 then
		return ("|cffc7c7cf%ds|r |cffeda55f%dc|r"):format(silver, rest)
	end
	return ("|cffeda55f%dc|r"):format(rest)
end

-- Copper -> "12g 34s 56c" with no color codes, for use inside a sentence.
function ns.PlainMoney(copper)
	copper = math.floor(copper or 0)
	local gold = math.floor(copper / 10000)
	local silver = math.floor(copper / 100) % 100
	local rest = copper % 100
	if gold > 0 then
		return ("%sg %ds %dc"):format(ns.Comma(gold), silver, rest)
	elseif silver > 0 then
		return ("%ds %dc"):format(silver, rest)
	end
	return ("%dc"):format(rest)
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

-- Seconds -> how long ago, in the units a person would say: "just now",
-- "12m", "2h 10m", "3d 4h".
function ns.Ago(seconds)
	local minutes = math.floor(seconds / 60)
	if minutes < 1 then
		return ns.L.AGO_NOW
	elseif minutes < 60 then
		return ns.L.AGO_MINUTES:format(minutes)
	elseif minutes < 1440 then
		return ns.L.AGO_HOURS:format(math.floor(minutes / 60), minutes % 60)
	end
	return ns.L.AGO_DAYS:format(math.floor(minutes / 1440), math.floor(minutes / 60) % 24)
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

-- ========= Saved data, in and out ===========================================
-- The large tables are saved packed (saved.lua, ns.SavedRule). They are
-- unpacked before anything reads them, and packed again when the game is
-- about to write them: on logout, exit and /reload.
local function OpenSaved()
	local failed = ns.Saved.Open(ns.db, ns.SavedRule.packed)
	local empty = true
	for _, snapshot in pairs(ns.db.snapshots or {}) do
		empty = empty and next(snapshot.rows or {}) == nil
	end
	for _, market in pairs(ns.db.historyByMarket or {}) do
		empty = empty and next(market.items or {}) == nil
	end
	local trades = type(ns.charDb.ledger) == "table" and next(ns.charDb.ledger) ~= nil
	local problem = ns.Saved.Problem(ns.db, ns.charDb, failed, empty, trades)
	-- Scans that did not come back stay lost until there is a scan again,
	-- however many times the game is loaded in between.
	if not empty then
		ns.db.savedLost = nil
	elseif problem then
		ns.db.savedLost = problem
	end
	ns.savedProblem = problem or ns.db.savedLost
	ns.savedLost = ns.savedProblem == "unpack" or (empty and ns.savedProblem ~= nil)
	ns.savedFailed = failed
end

local function CloseSaved()
	local rule = ns.SavedRule
	local packed, problem = pcall(ns.Saved.Close, ns.db, rule.packed)
	ns.db.savedProblem = not packed and tostring(problem) or nil
	-- Packed or not, what is written has to fit.
	local counted, count, dropped = pcall(ns.Saved.Fit, ns.db, rule)
	ns.db.savedCount = counted and count or nil
	if counted and #dropped > 0 then
		ns.db.savedDropped = dropped
	end
	ns.Saved.Stamp(ns.db, ns.charDb)
end

-- Said once the player can read it: that the addon loaded and which version,
-- then what went wrong with the saved data, if anything did.
local function TellSaved()
	ns.Print(ns.L.LOADED:format(ns.AddonVersion()))
	if ns.savedProblem then
		ns.Print(ns.L["SAVED_PROBLEM_" .. ns.savedProblem])
		ns.EventLog:Note("saved data arrived wrong", ns.savedProblem)
		for _, failure in ipairs(ns.savedFailed or {}) do
			ns.EventLog:Note("saved data did not unpack", failure.path, failure.problem)
		end
	end
	if ns.db.savedProblem then
		ns.Print(ns.L.SAVED_NOT_PACKED)
		ns.EventLog:Note("saved data was not packed", ns.db.savedProblem)
		ns.db.savedProblem = nil
	end
	if ns.db.savedDropped then
		local names = {}
		for index, id in ipairs(ns.db.savedDropped) do
			names[index] = ns.L["SAVED_DROP_" .. id] or id
		end
		ns.Print(ns.L.SAVED_DROPPED:format(table.concat(names, ", ")))
		ns.db.savedDropped = nil
	end
end

Bus:On("SNAPSHOT_CHANGED", function()
	if ns.Store and ns.Store:GetSnapshot() then
		ns.savedLost = false
		ns.db.savedLost = nil
	end
end)

-- ========= Startup ==========================================================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		AuctionHeroDB = AuctionHeroDB or {}
		AuctionHeroCharDB = AuctionHeroCharDB or {}
		for _, setting in ipairs(ns.Settings) do
			ACCOUNT_DEFAULTS.switches[setting.id] = setting.default
		end
		ApplyDefaults(AuctionHeroDB, ACCOUNT_DEFAULTS)
		ApplyDefaults(AuctionHeroCharDB, CHARACTER_DEFAULTS)
		ns.db = AuctionHeroDB
		ns.charDb = AuctionHeroCharDB
		OpenSaved()
		Bus:Fire("INIT")
	elseif event == "PLAYER_LOGIN" then
		Bus:Fire("READY")
		C_Timer.After(ns.SavedRule.tellSeconds, TellSaved)
	elseif event == "PLAYER_LOGOUT" then
		CloseSaved()
	elseif event == "AUCTION_HOUSE_SHOW" then
		ns.auctionHouseOpen = true
		Bus:Fire("AH_OPENED")
	elseif event == "AUCTION_HOUSE_CLOSED" then
		ns.auctionHouseOpen = false
		Bus:Fire("AH_CLOSED")
	end
end)

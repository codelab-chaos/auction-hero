-- A fake of the game client, enough to run the addon without the game.
--
-- Anything the addon calls that is not defined here returns a stub that
-- accepts any PascalCase method, so new UI code runs without additions. What
-- is defined here is the part the scenarios look at: frames and their scripts,
-- timers, a fake auction house, bags, posting, searching and buying.
-- MOCK holds the knobs a scenario can turn (see where each is read).
unpack = table.unpack
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
local clock, prof = 0, 0
function GetTime() return clock end
function GetServerTime() return 1794500000 + math.floor(clock) end
function debugprofilestop() prof = prof + 1.5; return prof end
function GetBuildInfo() return "1.60.1", "70888", "Nov 10 2026", 16001 end
function GetRealmName() return "TestRealm" end
function UnitFactionGroup() return "Alliance" end
-- The character, what it wears and the stats of items by link. Scenarios set these.
PLAYER = { level = 12, class = "ROGUE" }
EQUIPPED = {} -- inventory slot -> item link
ITEM_STATS = {} -- item link -> what GetItemStats returns
function UnitLevel() return PLAYER.level end
function UnitClass() return "Class", PLAYER.class end
function GetInventoryItemLink(_, slot) return EQUIPPED[slot] end
function GetItemStats(link) return ITEM_STATS[link] end
ITEM_QUALITY_COLORS = {}
for q = 0, 5 do ITEM_QUALITY_COLORS[q] = { hex = "|cff00000" .. q }; _G["ITEM_QUALITY" .. q .. "_DESC"] = "Q" .. q end
Enum = { AuctionHouseSortOrder = { Price = 0, Name = 1 } }
ScrollBoxConstants = { RetainScrollPosition = true }
SlashCmdList, UISpecialFrames = {}, {}
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) CHAT[#CHAT + 1] = text end }

local frames, timers = {}, {}
FRAMES_REF = frames
local Stub = {}
local function NewStub(kind)
	local o = { __kind = kind, scripts = {}, events = {}, shown = true, text = "" }
	frames[#frames + 1] = o
	return setmetatable(o, Stub)
end
local real = {
	SetScript = function(self, name, fn) self.scripts[name] = fn end,
	HookScript = function(self, name, fn) self.scripts[name] = fn end,
	GetScript = function(self, name) return self.scripts[name] end,
	RegisterEvent = function(self, event)
		if event == "NOT_A_REAL_EVENT" then error("unknown event") end
		self.events[event] = true
	end,
	Show = function(self) local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end,
	Hide = function(self)
		local was = self.shown; self.shown = false
		-- As in the game, hiding a frame takes the keyboard focus from any
		-- edit box in it.
		local focus = KEYBOARD_FOCUS
		while focus do
			if focus == self then KEYBOARD_FOCUS = nil break end
			focus = rawget(focus, "parentFrame")
		end
		if was and self.scripts.OnHide then self.scripts.OnHide(self) end
	end,
	SetFocus = function(self) KEYBOARD_FOCUS = self end,
	ClearFocus = function(self) if KEYBOARD_FOCUS == self then KEYBOARD_FOCUS = nil end end,
	HasFocus = function(self) return KEYBOARD_FOCUS == self end,
	SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
	IsShown = function(self) return self.shown end,
	SetText = function(self, t) assert(t == nil or type(t) == "string" or type(t) == "number", "SetText got " .. type(t)); self.text = t end,
	GetText = function(self) return self.text end,
	GetWidth = function(self) return rawget(self, "w") or 400 end,
	SetWidth = function(self, w) assert(type(w) == "number", "SetWidth needs a number") rawset(self, "w", w) end,
	SetSize = function(self, w, h) assert(type(w) == "number" and type(h) == "number", "SetSize needs numbers") rawset(self, "w", w) rawset(self, "h", h) end,
	SetHeight = function(self, h) assert(type(h) == "number", "SetHeight needs a number") rawset(self, "h", h) end,
	GetStringWidth = function(self)
		local text = tostring(self.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		return #text * 6
	end,
	GetStringHeight = function() return 12 end,
	GetEffectiveScale = function() return 1 end,
	GetFrameLevel = function() return 1 end,
	GetLeft = function() return 100 end,
	IsMouseOver = function() return MOUSE_OVER == true end,
	GetFont = function() return "font", 12, "" end,
	GetThumbTexture = function(self) return self end,
	GetVerticalScroll = function() return 0 end,
	SetDesaturated = function(self, on) rawset(self, "desaturated", on == true) end,
	IsDesaturated = function(self) return rawget(self, "desaturated") == true end,
	SetColorTexture = function(self, r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetColorTexture needs numbers") end,
	SetTextColor = function(self, r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetTextColor needs numbers") end,
	SetPoint = function(self, point, a, b, c, d) assert(type(point) == "string", "SetPoint needs a point name") rawset(self, "lastPoint", { point, a, b, c, d }) end,
	SetValue = function(self, v) rawset(self, "value", v) if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end,
	Click = function(self) if self.scripts.OnClick then self.scripts.OnClick(self) end end,
	GetHeight = function(self) return rawget(self, "h") or 20 end,
	GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
	ForEachFrame = function(self, callback)
		for _, frame in ipairs(rawget(self, "rowsDrawn") or {}) do callback(frame) end
	end,
	SetDataProvider = function(self, provider)
		self.provider = provider
		self.rowsDrawn = {}
		for i = 1, math.min(25, #provider.elements) do
			local pool = rawget(self, "pool") or {}
			rawset(self, "pool", pool)
			local row = pool[i] or NewStub("Row")
			pool[i] = row
			row.shown = true
			self.view.init(row, provider.elements[i])
			self.rowsDrawn[i] = row
		end
		-- Rows left over from a longer list are put away, as the game does.
		local pool = rawget(self, "pool") or {}
		for i = math.min(25, #provider.elements) + 1, #pool do
			pool[i].shown = false
		end
	end,
}
Stub.__index = function(self, key)
	if real[key] then return real[key] end
	if type(key) == "string" and key:find("^Create") then
		return function() return NewStub(key) end
	end
	if type(key) == "string" and key:find("^%u") then
		return function() end
	end
	return nil
end
function CreateFrame(kind, name, parent) local f = NewStub(kind) rawset(f, "parentFrame", parent) rawset(f, "GetParent", function(self) return rawget(self, "parentFrame") end) return f end
UIParent = NewStub("UIParent")
function GetCurrentKeyBoardFocus() return KEYBOARD_FOCUS end
GameTooltip = NewStub("GameTooltip")
TIP = {}
rawset(GameTooltip, "SetText", function(_, t) TIP = { t } end)
rawset(GameTooltip, "AddLine", function(_, t) TIP[#TIP + 1] = t end)
rawset(GameTooltip, "AddDoubleLine", function(_, left, right) TIP[#TIP + 1] = left .. ": " .. right end)
rawset(GameTooltip, "SetHyperlink", function(_, l) TIP = { "LINK " .. l } end)
rawset(GameTooltip, "GetItem", function(self) return self.itemName, self.itemLink end)
rawset(GameTooltip, "SetRecipeResultItem", function(self, recipeID)
	if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
	local recipe = CRAFTING_RECIPES[recipeID]
	self.itemLink = recipe and recipe.output and recipe.output.hyperlink
	self.itemName = self.itemLink and self.itemLink:match("|h%[(.-)%]|h")
	TIP = { self.itemName or "Recipe" }
	if self.scripts.OnTooltipSetItem then self.scripts.OnTooltipSetItem(self) end
end)
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, callback, owner)
	self.callbacks[event] = self.callbacks[event] or {}
	table.insert(self.callbacks[event], { callback, owner })
end
function EventRegistry:TriggerEvent(event, ...)
	for _, entry in ipairs(self.callbacks[event] or {}) do entry[1](entry[2], ...) end
end
function CreateDataProvider(tbl) return { elements = tbl } end
function CreateScrollBoxListLinearView()
	return { SetElementExtent = function() end, SetPadding = function() end,
		SetElementInitializer = function(self, _, fn) self.init = fn end }
end
ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, _, view) box.view = view; SCROLLBOX = box end }
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = clock + (delay or 0), fn = fn } end }
-- A ticker runs every `delay` seconds until cancelled (or `iterations` runs).
function C_Timer.NewTicker(delay, fn, iterations)
	local ticker = { cancelled = false }
	function ticker:Cancel() self.cancelled = true end
	function ticker:IsCancelled() return self.cancelled end
	local runs = 0
	local function step()
		if ticker.cancelled then return end
		runs = runs + 1
		fn(ticker)
		if not ticker.cancelled and (not iterations or runs < iterations) then
			C_Timer.After(delay, step)
		end
	end
	C_Timer.After(delay, step)
	return ticker
end

function FireEvent(event, ...)
	for i = 1, #frames do
		local f = frames[i]
		if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
end
function Tick(n)
	for _ = 1, n or 1 do
		clock = clock + 0.05
		local all = timers; timers = {}
		for _, timer in ipairs(all) do
			if timer.at <= clock then timer.fn() else timers[#timers + 1] = timer end
		end
		for i = 1, #frames do
			local f = frames[i]
			if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.05) end
		end
	end
end

-- ===== Fake auction house =====
local NAMES = { "Copper Ore", "Linen Cloth", "Light Leather", "Tigerseye", "Silverleaf", "Tunic of the Bear", "Sword of the Monkey" }
-- Small on purpose: no scenario depends on the size, and every scenario scans.
local N = 300
NAMES_REF = NAMES
local replicate, firstRead = {}, {}
for i = 0, N - 1 do
	local which = (i * 3) % #NAMES + 1
	local gear = which >= 6
	local count = gear and 1 or ((i * 13) % 20 + 1)
	local unit = which * 100 + (i * 31) % 90
	if i % 97 == 0 then unit = math.floor(unit * 0.4) end -- a deal now and then
	local buyout = (i % 11 == 0) and 0 or unit * count
	local suffix = gear and (i % 3) + 5 or 0
	replicate[i] = { NAMES[which], 134000 + which, count, which % 5, true, gear and 20 or 0, gear and "REQ_LEVEL_ABBR" or nil,
		math.floor(unit * count * 0.8), 0, buyout, (i % 17 == 0) and 50 or 0, nil, nil, "Seller" .. (i % 40), nil, 0, 2000 + which, true,
		link = ("|cff1eff00|Hitem:%d:%d:0:0:0:0:%d:0:25|h[%s]|h|r"):format(2000 + which, i % 50 == 0 and 77 or 0, suffix, NAMES[which]),
		timeLeft = i % 4 + 1 }
end
MOCK = { replicateDelay = 3, replicateAnswers = true }
local pendingReplicate
C_AuctionHouse = {}
function C_AuctionHouse.ReplicateItems()
	if MOCK.replicateAnswers then C_Timer.After(0, function() C_Timer.After(0, function() FireEvent("REPLICATE_ITEM_LIST_UPDATE") end) end) end
end
-- MOCK.repeats adds that many auctions to the end of the list, each an exact
-- copy of one of the first few, the way a real auction house is full of
-- identical auctions.
local function Auction(i) return replicate[i < N and i or (i - N) % 7] end
function C_AuctionHouse.GetNumReplicateItems() return MOCK.empty and 0 or N + (MOCK.repeats or 0) end
function C_AuctionHouse.GetReplicateItemInfo(i)
	local r = Auction(i)
	if i % 9 == 0 and not firstRead[i] then
		firstRead[i] = true
		return nil, nil, r[3], r[4], nil, r[6], r[7], r[8], r[9], r[10], r[11], nil, nil, r[14], nil, r[16], r[17], false
	end
	return table.unpack(r, 1, 18)
end
function C_AuctionHouse.GetReplicateItemLink(i) if i % 9 == 0 and firstRead[i] == true and not Auction(i).linked then Auction(i).linked = true return nil end return Auction(i).link end
function C_AuctionHouse.GetReplicateItemTimeLeft(i) return Auction(i).timeLeft end
function C_AuctionHouse.IsThrottledMessageSystemReady() return true end
local browse, pages = {}, 0
local function Page(from, to)
	for id = from, to do
		browse[#browse + 1] = { itemKey = { itemID = id, itemLevel = 0, itemSuffix = id % 4 == 0 and 9 or 0, battlePetSpeciesID = 0 },
			totalQuantity = id % 30 + 1, minPrice = id * 3, containsOwnerItem = false }
	end
end
-- A browse by name answers with the key of each variant for sale under that
-- name's item, the way the game's own window finds an item. MOCK.browseNames
-- lists the variants (the name asked for, when left out); MOCK.browseGone
-- means the auction house lists none.
BROWSED = {}
local function BrowseByName(name)
	BROWSED[#BROWSED + 1] = name
	browse, pages = {}, 3
	local itemID
	for index, known in ipairs(NAMES_REF) do
		if known:match("^(%S+)") == name:match("^(%S+)") then itemID = 2000 + index end
	end
	if itemID and not MOCK.browseGone then
		for position, variant in ipairs(MOCK.browseNames or { name }) do
			browse[#browse + 1] = { itemKey = { itemID = itemID, itemLevel = 12, itemSuffix = 100 + position, battlePetSpeciesID = 0, mockName = variant }, totalQuantity = 1, minPrice = 1, containsOwnerItem = false }
		end
	end
	C_Timer.After(0, function() FireEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end)
end
function C_AuctionHouse.SendBrowseQuery(q)
	assert(#q.sorts == 2)
	if q.searchString ~= "" then return BrowseByName(q.searchString) end
	browse, pages = {}, 1; Page(1000, 1049)
	C_Timer.After(0, function() FireEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end)
end
function C_AuctionHouse.HasFullBrowseResults() return pages >= 3 end
function C_AuctionHouse.RequestMoreBrowseResults()
	pages = pages + 1; Page(1000 + (pages - 1) * 50, 1049 + (pages - 1) * 50)
	C_Timer.After(0, function() FireEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", {}) end)
end
function C_AuctionHouse.GetBrowseResults() return browse end
local asked = {}
function C_AuctionHouse.GetItemKeyInfo(key)
	if key.itemID % 10 == 0 and not asked[key.itemID] then asked[key.itemID] = true return nil end
	return { itemName = "Item " .. key.itemID, quality = key.itemID % 5, iconFileID = 1, isCommodity = key.itemID % 2 == 0, isEquipment = key.itemID % 2 == 1, isPet = false }
end
function C_AuctionHouse.GetItemKeyRequiredLevel(key) return key.itemID % 60 end
-- MOCK_ITEM_CLASS[id or link] = { classID, subClassID } for items that are not armor.
MOCK_ITEM_CLASS = {}
C_Item = { GetItemInfoInstant = function(id)
	local class = MOCK_ITEM_CLASS[id]
	if class then return id, "Container", "Bag", "INVTYPE_BAG", 1, class[1], class[2] end
	return id, "Armor", "Leather", "INVTYPE_CHEST", 1, 4, 2
end }
function C_AuctionHouse.MakeItemKey(id) return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 } end
function C_AuctionHouse.GetItemKeyInfo(key) return { itemName = "x", quality = 1, iconFileID = 1, isCommodity = key.itemID % 2 == 0, isEquipment = false, isPet = false } end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function CreateFont(name) return CreateFrame("Font") end
function CreateColor(r, g, b, a) assert(type(r) == "number") return { r = r, g = g, b = b, a = a } end
MONEY = 50000
function GetMoney() return MONEY end
NUM_BAG_SLOTS = 4
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
local BAG = {
	{ id = 2003, name = "Light Leather", count = 20 }, { id = 2003, name = "Light Leather", count = 20 }, { id = 2003, name = "Light Leather", count = 13 },
	{ id = 2001, name = "Copper Ore", count = 7 }, { id = 2006, name = "Tunic of the Bear", count = 1 }, { id = 9999, name = "Thing Nobody Sells", count = 1 },
	{ id = 2002, name = "Soulbound Thing", count = 1, bound = true },
}
-- Bags past the backpack, by bag index: MOCK_BAGS[5] is a reagent bag.
MOCK_BAGS = {}
-- A bag slot's size when it is not just its items: MOCK_BAG_SIZES[1] = 10.
MOCK_BAG_SIZES = {}
-- Tooltip lines by item id, as C_TooltipInfo gives them; nil while unloaded.
MOCK_TOOLTIPS = {}
C_TooltipInfo = { GetItemByID = function(id)
	local lines = {}
	for _, text in ipairs(MOCK_TOOLTIPS[id] or {}) do lines[#lines + 1] = { leftText = text } end
	return { lines = lines }
end }
local function BagList(bag) if bag == 0 then return BAG end return MOCK_BAGS[bag] or {} end
C_Container = {
	GetContainerNumSlots = function(bag) return MOCK_BAG_SIZES[bag] or #BagList(bag) end,
	GetContainerItemInfo = function(bag, slot)
		local it = BagList(bag)[slot]; if not it then return nil end
		return { iconFileID = 134000 + slot, stackCount = it.count, quality = 1, itemID = it.id, isBound = it.bound or false,
			hyperlink = ("|cff1eff00|Hitem:%d::::::::25|h[%s]|h|r"):format(it.id, it.name) }
	end,
}
function C_AuctionHouse.IsSellItemValid() return true end
for q = 0, 5 do ITEM_QUALITY_COLORS[q].r, ITEM_QUALITY_COLORS[q].g, ITEM_QUALITY_COLORS[q].b = 0.1 * q, 0.5, 0.2 end

function ALL_FRAMES() local copy = {} for i = 1, #FRAMES_REF do copy[i] = FRAMES_REF[i] end return copy end
-- ===== posting =====
POSTS = {}
MOCK.needsConfirm = false
MOCK.postError = false
Enum.ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 }
Enum.AuctionHouseError = { NotEnoughMoney = 0, ItemNotFound = 4 }
C_Item.DoesItemExist = function(loc) return loc ~= nil end
-- How many of an item the bags hold: MOCK.bagCounts[itemID], or none.
function GetItemCount(itemID) return (MOCK.bagCounts or {})[itemID] or 0 end
INVTYPE_CHEST = "Chest"
C_Item.GetItemID = function(loc) local info = C_Container.GetContainerItemInfo(loc.bag, loc.slot) return info and info.itemID end
function C_AuctionHouse.GetItemCommodityStatus(loc) local id = C_Item.GetItemID(loc) return (id == 2003 or id == 2001) and 2 or 1 end
function C_AuctionHouse.CalculateCommodityDeposit(id, duration, qty) return qty * duration end
function C_AuctionHouse.CalculateItemDeposit(loc, duration, qty) return 100 * duration * qty end
local function Created(n) for i = 1, n do C_Timer.After(0, function() FireEvent("AUCTION_HOUSE_AUCTION_CREATED", 1000 + i) end) end end
function C_AuctionHouse.PostCommodity(loc, duration, qty, unit)
	POSTS[#POSTS + 1] = { "commodity", C_Item.GetItemID(loc), duration, qty, unit }
	if MOCK.postError then C_Timer.After(0, function() FireEvent("AUCTION_HOUSE_SHOW_ERROR", 4) end) return false end
	if MOCK.needsConfirm then return true end
	Created(1); return false
end
function C_AuctionHouse.ConfirmPostCommodity(loc, duration, qty, unit) POSTS[#POSTS + 1] = { "confirm", C_Item.GetItemID(loc), duration, qty, unit }; Created(1) end
function C_AuctionHouse.PostItem(loc, duration, qty, bid, buyout)
	POSTS[#POSTS + 1] = { "item", C_Item.GetItemID(loc), duration, qty, tostring(bid), tostring(buyout) }
	Created(qty); return false
end
function C_AuctionHouse.ConfirmPostItem() end
Enum.AuctionStatus = { Active = 0, Sold = 1 }
function C_AuctionHouse.QueryOwnedAuctions(sorts) assert(type(sorts) == "table") C_Timer.After(0, function() FireEvent("OWNED_AUCTIONS_UPDATED") end) end
-- The player's auctions. A cancel takes one away and says so, unless
-- MOCK.cancelSilent (no answer) or MOCK.cancelKept (no answer, still up).
OWNED = {
	{ auctionID = 1, itemKey = { itemID = 2006 }, itemLink = "|cff1eff00|Hitem:2006|h[Tunic of the Bear]|h|r", status = 0, quantity = 1, timeLeftSeconds = 86000, buyoutAmount = 990 },
	{ auctionID = 2, itemKey = { itemID = 2003 }, status = 1, quantity = 20, buyoutAmount = 4000, bidAmount = 0 },
}
function C_AuctionHouse.GetOwnedAuctions() return OWNED end
CANCELS = {}
function C_AuctionHouse.GetCancelCost() return MOCK.cancelCost or 0 end
function C_AuctionHouse.CanCancelAuction(id) return true end
function C_AuctionHouse.CancelAuction(id)
	CANCELS[#CANCELS + 1] = id
	if MOCK.cancelKept then return end
	for index, auction in ipairs(OWNED) do
		if auction.auctionID == id then table.remove(OWNED, index) break end
	end
	if not MOCK.cancelSilent then C_Timer.After(0, function() FireEvent("AUCTION_CANCELED", id) end) end
end
function GetCursorPosition() return CURSOR_X or 300, 300 end
function IsMouseButtonDown() return MOUSE_DOWN == true end
SEARCHES = {}
function C_AuctionHouse.GetItemKeyFromItem(loc) local id = C_Item.GetItemID(loc) return id and { itemID = id, itemLevel = 12, itemSuffix = 3, battlePetSpeciesID = 0 } end
function C_AuctionHouse.GetItemKeyInfo(key) return { itemName = key.mockName or ("item " .. key.itemID), isEquipment = key.itemID == 2006, isCommodity = key.itemID == 2003 or key.itemID == 2001 } end
local function Searched(kind, key)
	SEARCHES[#SEARCHES + 1] = kind .. " " .. key.itemID .. " level=" .. key.itemLevel
	LAST_SEARCH = kind
	local commodity = key.itemID == 2003 or key.itemID == 2001
	-- An item search is answered the way Forever answers it, as seen in game.
	C_Timer.After(0, function() FireEvent(commodity and "COMMODITY_SEARCH_RESULTS_UPDATED" or "AUCTION_HOUSE_NEW_RESULTS_RECEIVED", commodity and key.itemID or key) end)
end
function C_AuctionHouse.SendSearchQuery(key, sorts, separate) assert(separate == false) Searched("search sorts=" .. #sorts, key) end
function C_AuctionHouse.SendSellSearchQuery(key, sorts, separate) assert(#sorts == 2 and separate == false) Searched("sellsearch", key) end
-- As on Forever: a single item searched for by its id alone finds nothing.
-- Only the full key from a browse result does.
-- (What the sell form's own query returns for gear on Forever is not yet known; here it answers.)
local function Findable(key) return key.itemID == 2001 or key.itemID == 2003 or (key.itemSuffix or 0) ~= 0 or LAST_SEARCH == "sellsearch" end
function C_AuctionHouse.GetNumItemSearchResults(key) return Findable(key) and (MOCK.liveCount or 2) or 0 end
-- Two live auctions per search. MOCK.liveNames names them (for telling a
-- variant apart); MOCK.liveMine marks the first as the player's own.
function C_AuctionHouse.GetItemSearchResultInfo(key, i)
	local name = MOCK.liveNames and MOCK.liveNames[i]
	return { auctionID = 700 + i, buyoutAmount = (MOCK.livePrice or 100) * i * (MOCK.liveQuantity or 1), quantity = MOCK.liveCount or MOCK.liveQuantity or 1, containsOwnerItem = MOCK.liveMine == true and i == 1,
		itemLink = name and ("|cff1eff00|Hitem:" .. key.itemID .. "|h[" .. name .. "]|h|r") or nil }
end
function C_AuctionHouse.HasFullItemSearchResults() return true end
function C_AuctionHouse.RequestMoreItemSearchResults() end
function C_AuctionHouse.GetNumCommoditySearchResults() return MOCK.liveGoods and #MOCK.liveGoods or 1 end
function C_AuctionHouse.GetCommoditySearchResultInfo(id, i)
	local live = MOCK.liveGoods and MOCK.liveGoods[i]
	return { unitPrice = live and live[1] or 7, quantity = live and live[2] or 40, containsOwnerItem = false }
end
OPTIONS = {}
Settings = { VarType = { Boolean = "boolean", Number = "number" } }
function Settings.RegisterVerticalLayoutCategory(name) return { name = name, GetID = function() return 77 end } end
function Settings.RegisterAddOnCategory(category) OPTIONS.category = category.name end
function Settings.RegisterAddOnSetting(category, variable, key, tbl, kind, name, default)
	assert(type(tbl) == "table" and type(tbl[key]) == kind, "setting " .. key .. " is not a " .. kind)
	local s = { key = key, tbl = tbl }
	function s:SetValueChangedCallback(fn) self.changed = fn end
	function s:Set(v) self.tbl[self.key] = v; self.changed(self, v) end
	OPTIONS[key] = s
	return s
end
function Settings.CreateSliderOptions(min, max, rate) return { min = min, max = max, SetLabelFormatter = function() end } end
function Settings.CreateSlider(category, setting, options) setting.control = "slider " .. options.min .. "-" .. options.max end
function Settings.CreateCheckbox(category, setting) setting.control = "checkbox" end
function Settings.OpenToCategory(id) OPTIONS.opened = id end
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
BUYS = {}
function C_AuctionHouse.StartCommoditiesPurchase(id, qty)
	BUYS[#BUYS + 1] = "start " .. id .. " x" .. qty
	if MOCK.quoteUnavailable then C_Timer.After(0, function() FireEvent("COMMODITY_PRICE_UNAVAILABLE") end) return end
	if MOCK.quoteSilent then return end
	C_Timer.After(0, function() FireEvent("COMMODITY_PRICE_UPDATED", MOCK.quoteUnit or 7, (MOCK.quoteUnit or 7) * qty) end)
end
function C_AuctionHouse.ConfirmCommoditiesPurchase(id, qty)
	BUYS[#BUYS + 1] = "confirm " .. id .. " x" .. qty
	C_Timer.After(0, function() FireEvent(MOCK.buyFails and "COMMODITY_PURCHASE_FAILED" or "COMMODITY_PURCHASE_SUCCEEDED") end)
end
function C_AuctionHouse.CancelCommoditiesPurchase() BUYS[#BUYS + 1] = "cancel" end
function C_AuctionHouse.GetQuoteDurationRemaining() return MOCK.quoteLeft or 20 end

-- Hooks run after the function they watch, with the same arguments.
function hooksecurefunc(owner, name, hook)
	local original = owner[name]
	owner[name] = function(...)
		local results = { original(...) }
		hook(...)
		return (table.unpack or unpack)(results)
	end
end
C_Item.GetItemNameByID = function(id) return "item " .. id end
-- Gear never stacks. MOCK.liveCount is a count the live search reports
-- without the price covering it, as the game does for bags.
C_Item.GetItemMaxStackSizeByID = function(id) return (id == 2006 or id == 2007) and 1 or 200 end

CRAFTING_RECIPES = {}
C_TradeSkillUI = {
	GetRecipeSchematic = function(recipeID)
		if MOCK.recipeAPIFails then error("recipe data not available") end
		local recipe = CRAFTING_RECIPES[recipeID]
		return recipe and recipe.schematic
	end,
	GetRecipeOutputItemData = function(recipeID)
		if MOCK.recipeAPIFails then error("recipe data not available") end
		local recipe = CRAFTING_RECIPES[recipeID]
		return recipe and recipe.output
	end,
}

-- Buying a single item out. MOCK.bidFails leaves it unanswered.
function C_AuctionHouse.PlaceBid(auctionID, amount)
	-- The game refuses a purchase that is not part of the player's press.
	if MOCK.blockBids then
		FireEvent("ADDON_ACTION_BLOCKED", "AuctionHero", "UNKNOWN()")
		return
	end
	BUYS[#BUYS + 1] = "bid " .. auctionID .. " " .. amount
	if MOCK.bidTakesGold then MONEY = MONEY - amount end
	if not MOCK.bidFails then C_Timer.After(0, function() FireEvent("AUCTION_HOUSE_PURCHASE_COMPLETED", auctionID) end) end
end

-- The game's Open All tells C_Mail when it starts and stops taking the mail.
C_Mail = { SetOpeningAll = function() end }
-- The mailbox: MAIL is a list of { kind, item, bid, buyout, deposit, cut, subject, daysLeft }.
MAIL = {}
function GetInboxNumItems() return #MAIL end
function GetInboxInvoiceInfo(index) local m = MAIL[index] return m[1], m[2], "Buyer", m[3], m[4], m[5], m[6] end
function GetInboxHeaderInfo(index) local m = MAIL[index] return nil, nil, "Auction House", m[7], 0, 0, m[8] end

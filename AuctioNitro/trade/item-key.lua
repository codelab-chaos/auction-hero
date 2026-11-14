-- Item keys: finds the key the auction house knows an item by.
--
-- A single item can only be searched for by its full key: item id, and for
-- gear the level and variant that tell "of the Elder" from "of the Owl". A
-- scan gives the id and the name but not that key, and a key made from the id
-- alone finds nothing (seen on Forever: no auctions back for an item the
-- game's own window listed five of).
--
-- So the key is asked for the way the game's window does it: browse for the
-- name, and take the key of the result with this id and this name. Keys are
-- kept for the session.
--
-- It only reads. Nothing is bought here.
local _, ns = ...
local Bus = ns.Bus

local ItemKey = {}
ns.ItemKey = ItemKey

local ANSWER_SECONDS = 10
local PAGES = 5 -- pages of browse results to look through

local known = {} -- "itemID:name" -> item key
local asking -- { itemID, name, done, pages, sent }
local attempt = 0 -- counts requests, so a late timer cannot touch a newer one

local function Finish(itemKey, problem, found)
	local done = asking and asking.done
	asking = nil
	attempt = attempt + 1
	if done then
		done(itemKey, problem, found)
	end
end

-- Looks through the browse results for the item. Returns its key, or nil and
-- whether some results could not be named yet.
local function Find()
	local unnamed = false
	local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
	for _, result in ipairs(ok and results or {}) do
		local itemKey = result.itemKey
		if itemKey and itemKey.itemID == asking.itemID then
			local known, info = pcall(C_AuctionHouse.GetItemKeyInfo, itemKey)
			if not known or not info or not info.itemName then
				unnamed = true -- the game is still loading this one
			elseif info.itemName == asking.name then
				return itemKey
			end
		end
	end
	return nil, unnamed
end

local function Look()
	if not asking or not asking.sent then
		return
	end
	local itemKey, unnamed = Find()
	if itemKey then
		known[asking.itemID .. ":" .. asking.name] = itemKey
		ns.EventLog:Note("item key found", asking.itemID, asking.name, itemKey.itemLevel, itemKey.itemSuffix)
		return Finish(itemKey)
	end
	if unnamed then
		return -- ITEM_KEY_ITEM_INFO_RECEIVED will bring us back
	end
	local full = select(2, pcall(C_AuctionHouse.HasFullBrowseResults))
	if full == false and asking.pages < PAGES then
		asking.pages = asking.pages + 1
		if pcall(C_AuctionHouse.RequestMoreBrowseResults) then
			return
		end
	end
	-- Nothing by this name with this id among the results. Say what was there
	-- instead, so "not found" can be told from "looked for it the wrong way".
	local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
	results = ok and results or {}
	local seen = {}
	for index = 1, math.min(#results, 4) do
		local itemKey = results[index].itemKey or {}
		local named, info = pcall(C_AuctionHouse.GetItemKeyInfo, itemKey)
		seen[#seen + 1] = ("%s \"%s\" level %s variant %s"):format(tostring(itemKey.itemID), tostring(named and info and info.itemName), tostring(itemKey.itemLevel), tostring(itemKey.itemSuffix))
	end
	local found = ("%d results%s"):format(#results, #seen > 0 and (": " .. table.concat(seen, "; ")) or "")
	ns.EventLog:Note("item key not found", asking.itemID, asking.name, found)
	Finish(nil, "gone", found)
end

local function Send()
	if not C_AuctionHouse.IsThrottledMessageSystemReady() then
		return -- sent when the game says it is ready
	end
	local ok, problem = pcall(C_AuctionHouse.SendBrowseQuery, {
		searchString = asking.name,
		sorts = {
			{ sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false },
			{ sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
		},
		filters = {},
	})
	ns.EventLog:Note("item key asked", asking.itemID, asking.name, ok, problem)
	if not ok then
		return Finish(nil, "refused")
	end
	asking.sent = true
end

-- Finds the key for an item of this id and name, then calls done(itemKey),
-- or done(nil, problem, found) where problem is "gone" (no result has this id
-- and name), "unanswered" or "refused", and found says what the browse did
-- return. A newer request drops an older one unanswered.
function ItemKey:Resolve(itemID, name, done)
	local itemKey = known[itemID .. ":" .. name]
	if itemKey then
		return done(itemKey)
	end
	if not ns.auctionHouseOpen then
		return done(nil, "refused")
	end
	attempt = attempt + 1
	asking = { itemID = itemID, name = name, done = done, pages = 1 }
	local mine = attempt
	C_Timer.After(ANSWER_SECONDS, function()
		if mine == attempt and asking then
			ns.EventLog:Note("item key unanswered", itemID, name)
			Finish(nil, "unanswered")
		end
	end)
	Send()
end

-- Forgets a key, when a search by it finds nothing the game's window would.
function ItemKey:Forget(itemID, name)
	known[itemID .. ":" .. name] = nil
end

local frame = CreateFrame("Frame")
for _, event in ipairs({
	"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
	"AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
	"AUCTION_HOUSE_BROWSE_FAILURE",
	"ITEM_KEY_ITEM_INFO_RECEIVED",
	"AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
}) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event)
	if not asking then
		return
	end
	if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if not asking.sent then
			Send()
		end
	elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
		if asking.sent then
			Finish(nil, "refused")
		end
	else
		Look()
	end
end)

Bus:On("AH_CLOSED", function()
	asking = nil
	attempt = attempt + 1
end)

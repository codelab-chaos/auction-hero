-- Sell search: asks the game for the live listings of the item being sold.
--
-- The game's own sell form does this the moment an item is put in it, before
-- it will post. We do the same when an item is picked on the Sell tab, so a
-- post goes out in the same order of requests as one from the game's form.
--
-- The state, published as SELL_SEARCH_CHANGED:
--   key       the bag item asked about
--   phase     "waiting" (the game is busy), "sent" or "done"
--   listings  { unit, quantity, buyout, mine } cheapest first, once done
local _, ns = ...
local Bus = ns.Bus

local SellSearch = { state = { phase = "idle" } }
ns.SellSearch = SellSearch

local wanted -- { key, itemKey, itemID, commodity, equipment } for the search in hand

local function Publish(phase, listings)
	SellSearch.state = { key = wanted and wanted.key, phase = phase, listings = listings }
	Bus:Fire("SELL_SEARCH_CHANGED", SellSearch.state)
end

local function Send()
	if not wanted or not ns.auctionHouseOpen then
		return
	end
	if not C_AuctionHouse.IsThrottledMessageSystemReady() then
		return Publish("waiting")
	end
	-- The same sort orders the game's sell form sends: cheapest buyout, then
	-- bid, for single items, and none for goods sold by the unit.
	local sorts = wanted.commodity and {}
		or {
			{ sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
			{ sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false },
		}
	-- Equipment is searched by item id alone, so every variant of it comes back.
	local call = wanted.equipment and C_AuctionHouse.SendSellSearchQuery or C_AuctionHouse.SendSearchQuery
	local ok, problem = pcall(call, wanted.itemKey, sorts, false)
	ns.EventLog:Note(wanted.equipment and "SendSellSearchQuery" or "SendSearchQuery", wanted.itemID, ok, problem)
	Publish(ok and "sent" or "waiting")
end

-- Asks for the listings of a bag item. Safe to call again for the same item.
function SellSearch:Request(key)
	if not ns.auctionHouseOpen or not key then
		return
	end
	if wanted and wanted.key == key and self.state.phase ~= "idle" then
		return
	end
	local location = ns.Posting.Locate(key)
	local itemKey = location and C_AuctionHouse.GetItemKeyFromItem(location)
	if not itemKey then
		return
	end
	local info = C_AuctionHouse.GetItemKeyInfo(itemKey)
	local equipment = info and info.isEquipment or false
	if equipment then
		itemKey.itemLevel, itemKey.itemSuffix = 0, 0
	end
	wanted = {
		key = key,
		itemKey = itemKey,
		itemID = itemKey.itemID,
		commodity = C_AuctionHouse.GetItemCommodityStatus(location) == Enum.ItemCommodityStatus.Commodity,
		equipment = equipment,
	}
	Send()
end

-- True once the game has been asked about this item (answered or not).
function SellSearch:Asked(key)
	local state = self.state
	return state.key == key and (state.phase == "sent" or state.phase == "done")
end

local function ReadItems()
	local listings = {}
	local count = C_AuctionHouse.GetNumItemSearchResults(wanted.itemKey) or 0
	for index = 1, count do
		local info = C_AuctionHouse.GetItemSearchResultInfo(wanted.itemKey, index)
		if info and info.buyoutAmount then
			local quantity = math.max(1, info.quantity or 1)
			listings[#listings + 1] = { unit = math.floor(info.buyoutAmount / quantity), quantity = quantity, buyout = info.buyoutAmount, mine = info.containsOwnerItem }
		end
	end
	return listings, count
end

local function ReadCommodity()
	local listings = {}
	local count = C_AuctionHouse.GetNumCommoditySearchResults(wanted.itemID) or 0
	for index = 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(wanted.itemID, index)
		if info then
			listings[#listings + 1] = { unit = info.unitPrice, quantity = info.quantity, buyout = info.unitPrice * info.quantity, mine = info.containsOwnerItem }
		end
	end
	return listings, count
end

local frame = CreateFrame("Frame")
-- Forever answers an item search with AUCTION_HOUSE_NEW_RESULTS_RECEIVED,
-- where other clients send ITEM_SEARCH_RESULTS_UPDATED. Both are taken.
for _, event in ipairs({ "AUCTION_HOUSE_NEW_RESULTS_RECEIVED", "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, subject)
	if not wanted then
		return
	end
	if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if SellSearch.state.phase == "waiting" then
			Send()
		end
		return
	end
	if SellSearch.state.phase ~= "sent" or (event == "COMMODITY_SEARCH_RESULTS_UPDATED") ~= wanted.commodity then
		return
	end
	-- The Buy tab, a live check and the game's own window search too. Only an
	-- answer about this item counts: the event names the item searched for.
	local itemID = wanted.commodity and subject or (type(subject) == "table" and subject.itemID)
	if itemID and itemID ~= wanted.itemID then
		return
	end
	local ok, listings, count = pcall(wanted.commodity and ReadCommodity or ReadItems)
	ns.EventLog:Note("sell search answered", wanted.itemID, ok and count or tostring(listings))
	Publish("done", ok and listings or {})
end)

Bus:On("AH_CLOSED", function()
	wanted = nil
	SellSearch.state = { phase = "idle" }
end)

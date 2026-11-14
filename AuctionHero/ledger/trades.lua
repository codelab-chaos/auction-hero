-- Trades: writes a ledger entry when gold is spent at the auction house.
--
-- It watches the game's own buy and post calls, so a trade is recorded whether
-- it was made from this addon's window or the game's. A call is only an
-- attempt: the entry is written when the game says it went through.
local _, ns = ...
local Bus = ns.Bus

local quote -- the server's last price for goods sold by the unit: { unit, total }
local buying -- goods being bought: { itemID, quantity, amount }
local searched -- the item key last searched for, to find a single auction in
local bidding = {} -- auctionID -> a single item being bought out
local posting -- the last post sent, waiting for the game's answer

local function NameOf(itemID)
	local ok, name = pcall(C_Item.GetItemNameByID, itemID)
	return ok and name or ("item " .. tostring(itemID))
end

-- The auction about to be bought, from the search results it was picked in.
local function FindAuction(auctionID)
	if not searched then
		return nil
	end
	local ok, count = pcall(C_AuctionHouse.GetNumItemSearchResults, searched)
	for index = 1, ok and count or 0 do
		local found, info = pcall(C_AuctionHouse.GetItemSearchResultInfo, searched, index)
		if found and info and info.auctionID == auctionID then
			return info
		end
	end
end

local function Posted(location, duration, quantity, itemID, deposit)
	if not itemID then
		return
	end
	posting = { itemID = itemID, quantity = quantity or 1, amount = deposit or 0 }
end

local hooks = {
	ConfirmCommoditiesPurchase = function(itemID, quantity)
		buying = { itemID = itemID, quantity = quantity, amount = quote and quote.total }
	end,
	SendSearchQuery = function(itemKey)
		searched = itemKey
	end,
	-- Buying a single item out is a bid of its full buyout.
	PlaceBid = function(auctionID, amount)
		-- A purchase made from this addon knows exactly what it is buying.
		local mine = ns.Buying:Pending()
		if mine and mine.auctionID == auctionID then
			bidding[auctionID] = { itemID = mine.itemID, name = mine.name, quantity = mine.quantity, amount = amount }
			return
		end
		local info = FindAuction(auctionID)
		bidding[auctionID] = {
			itemID = searched and searched.itemID,
			name = info and info.itemLink and info.itemLink:match("|h%[(.-)%]|h"),
			quantity = info and info.quantity or 1,
			amount = amount,
		}
	end,
	PostCommodity = function(location, duration, quantity)
		local ok, itemID = pcall(C_Item.GetItemID, location)
		local priced, deposit = pcall(C_AuctionHouse.CalculateCommodityDeposit, ok and itemID, duration, quantity)
		Posted(location, duration, quantity, ok and itemID, priced and deposit)
	end,
	PostItem = function(location, duration, quantity)
		local ok, itemID = pcall(C_Item.GetItemID, location)
		local priced, deposit = pcall(C_AuctionHouse.CalculateItemDeposit, location, duration, quantity)
		Posted(location, duration, quantity, ok and itemID, priced and deposit)
	end,
}
-- Equipment is searched with the sell form's query. Either way the key is kept.
hooks.SendSellSearchQuery = hooks.SendSearchQuery
-- A post the game asked the player to confirm is sent again with the same details.
hooks.ConfirmPostCommodity = hooks.PostCommodity
hooks.ConfirmPostItem = hooks.PostItem

for name, hook in pairs(hooks) do
	if C_AuctionHouse[name] then
		hooksecurefunc(C_AuctionHouse, name, hook)
	end
end

local function Record(kind, trade)
	if not trade then
		return
	end
	if not trade.amount then
		-- A purchase with no price would put a wrong number in the books.
		return ns.EventLog:Note("ledger skipped", kind, trade.itemID, "no price")
	end
	ns.Ledger:Add({
		kind = kind,
		itemID = trade.itemID,
		name = trade.name or NameOf(trade.itemID),
		quantity = trade.quantity,
		amount = trade.amount,
	})
end

local handlers = {
	COMMODITY_PRICE_UPDATED = function(unit, total)
		quote = { unit = unit, total = total }
	end,
	COMMODITY_PURCHASE_SUCCEEDED = function()
		Record("buy", buying)
		buying = nil
	end,
	COMMODITY_PURCHASE_FAILED = function()
		buying = nil
	end,
	AUCTION_HOUSE_PURCHASE_COMPLETED = function(auctionID)
		Record("buy", bidding[auctionID])
		bidding[auctionID] = nil
	end,
	-- One post of several single items is answered once per auction made.
	AUCTION_HOUSE_AUCTION_CREATED = function()
		Record("post", posting)
		posting = nil
	end,
}

local frame = CreateFrame("Frame")
for event in pairs(handlers) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	handlers[event](...)
end)

-- A purchase made from this addon can also be known to have gone through by
-- the gold leaving, when the game sends no word of its own.
Bus:On("BUYING_CHANGED", function(state)
	if state.phase == "done" and state.auctionID and bidding[state.auctionID] then
		Record("buy", bidding[state.auctionID])
		bidding[state.auctionID] = nil
	end
end)

-- Nothing started at one visit can finish at the next.
Bus:On("AH_CLOSED", function()
	quote, buying, posting, searched, bidding = nil, nil, nil, nil, {}
end)

-- Owned: the player's own auctions, asked from the game.
-- The list is only as fresh as the last answer, so it is asked again when the
-- auction house opens, when a post finishes, and when the player asks.
--
-- An entry: auctionID, itemID, name, icon, quality, link, quantity,
--           buyout, bid, sold (true once it has sold), secondsLeft
local _, ns = ...
local Bus = ns.Bus

local Owned = { auctions = {}, asked = false }
ns.Owned = Owned

local function Read()
	local auctions = {}
	local ok, list = pcall(C_AuctionHouse.GetOwnedAuctions)
	for _, info in ipairs(ok and list or {}) do
		local keyInfo = info.itemKey and C_AuctionHouse.GetItemKeyInfo(info.itemKey)
		auctions[#auctions + 1] = {
			auctionID = info.auctionID,
			itemID = info.itemKey and info.itemKey.itemID,
			name = (info.itemLink and info.itemLink:match("|h%[(.-)%]|h")) or (keyInfo and keyInfo.itemName) or "?",
			icon = keyInfo and keyInfo.iconFileID,
			quality = keyInfo and keyInfo.quality,
			link = info.itemLink,
			quantity = info.quantity or 1,
			buyout = info.buyoutAmount,
			bid = info.bidAmount,
			sold = info.status == Enum.AuctionStatus.Sold,
			secondsLeft = info.timeLeftSeconds,
		}
	end
	Owned.auctions = auctions
	Bus:Fire("OWNED_CHANGED")
end

-- Asks the game for the list. The answer arrives a moment later.
-- The game takes one auction house request at a time and drops what collides,
-- so when it is busy (its own window asks for things as it opens) the request
-- waits for the game to say it is ready.
function Owned:Request()
	if not ns.auctionHouseOpen then
		return false
	end
	if not C_AuctionHouse.IsThrottledMessageSystemReady() then
		self.waiting = true
		return false
	end
	self.waiting = false
	self.asked = true
	local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
	return (pcall(C_AuctionHouse.QueryOwnedAuctions, sorts))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
frame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
frame:SetScript("OnEvent", function(_, event)
	if event == "OWNED_AUCTIONS_UPDATED" then
		-- The game's own window asks too. Any answer serves.
		Owned.waiting = false
		Read()
	elseif Owned.waiting then
		Owned:Request()
	end
end)

Bus:On("AH_CLOSED", function()
	Owned.waiting = false
end)

Bus:On("AH_OPENED", function()
	Owned:Request()
end)

-- A finished post changes the list.
Bus:On("POSTING_CHANGED", function(state)
	if state.phase == "done" then
		Owned:Request()
	end
end)

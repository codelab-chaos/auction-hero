-- Gear the game has not loaded yet comes with an empty name in its link. The
-- Auctions tab says it is loading, asks the game for the item, and shows the
-- name once the game has it.
local keyInfo = C_AuctionHouse.GetItemKeyInfo
C_AuctionHouse.GetItemKeyInfo = function(key)
	local info = keyInfo(key)
	if key.itemID == 2006 then
		info.itemName = nil -- not loaded yet
	end
	return info
end
local byID = C_Item.GetItemNameByID
local loaded = false
C_Item.GetItemNameByID = function(id)
	if id == 2006 and not loaded then
		return nil
	end
	return byID and byID(id)
end
local asked = {}
C_Item.RequestLoadItemDataByID = function(id)
	asked[id] = true
end
OWNED[1].itemLink = "|cff1eff00|Hitem:2006|h[]|h|r"

local ns = Boot()
OpenAuctionHouse()
ShowTab("auctions")
Tick(5)
local function shows(text)
	return #Frames(function(frame)
		return frame.text == text
	end) > 0
end
local tunic
for _, auction in ipairs(ns.Owned.auctions) do
	if auction.itemID == 2006 then
		tunic = auction
	end
end
check("an empty name is no name", tunic.name, ns.L.AUCTIONS_NAME_LOADING)
checkTrue("the row says it is loading, not blank", shows(ns.L.AUCTIONS_NAME_LOADING))
checkTrue("and the game is asked for the item", asked[2006])

-- The game loads the item: the name shows.
OWNED[1].itemLink = "|cff1eff00|Hitem:2006|h[Tunic of the Bear]|h|r"
loaded = true
FireEvent("GET_ITEM_INFO_RECEIVED", 2006, true)
Tick(20)
checkTrue("the name shows once the game has it", shows("Tunic of the Bear"))

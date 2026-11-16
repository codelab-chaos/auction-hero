-- Item names for auctions whose details never arrived. A full scan can end
-- with rows that have an item id but no name or link, and a row with no name
-- is left out of the market, so a busy item can vanish from the Buy tab while
-- it is still for sale.
--
-- An item that cannot be equipped has only one name, so its name can come from
-- the item id alone. Gear can carry a random suffix ("of the Bear") that only
-- the row's own details tell apart, so it is never guessed.
local _, ns = ...

local ItemNames = {}
ns.ItemNames = ItemNames

local known = {} -- itemID -> name, once found; an item's name never changes

local function Equippable(itemID)
	local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, itemID)
	return not ok or (equipLoc ~= nil and equipLoc ~= "")
end

local function LookUp(itemID)
	if C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, itemID)
		if ok and name and name ~= "" then
			return name
		end
	end
	local info = C_Item.GetItemInfo or GetItemInfo
	if info then
		local ok, name = pcall(info, itemID)
		if ok and name and name ~= "" then
			return name
		end
	end
end

-- The name a nameless row of this item can safely take, or nil. Asking also
-- starts loading the item, so a later look may find it.
function ItemNames.Fallback(itemID)
	if not itemID then
		return nil
	end
	if known[itemID] then
		return known[itemID]
	end
	if Equippable(itemID) then
		return nil
	end
	known[itemID] = LookUp(itemID)
	return known[itemID]
end

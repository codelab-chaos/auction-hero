-- Bags: what the player carries that could be auctioned, grouped by item.
-- An item spread over several bag slots (three stacks of leather) is one
-- entry with a total, and keeps its slots so each can be shown.
--
-- An entry: key, itemID, name, quality, icon, link, total, classID,
--           slots = { { bag, slot, count, icon } }
local _, ns = ...
local Bus = ns.Bus

local Bags = { items = {}, slots = {} }
ns.Bags = Bags

-- Every sellable bag slot in bag order, for drawing the bags as a grid.
function Bags:Slots()
	return self.slots
end

function Bags:Find(key)
	for _, item in ipairs(self.items) do
		if item.key == key then
			return item
		end
	end
end

local function Sellable(bag, slot, info)
	if not info.hyperlink or info.isBound then
		return false
	end
	-- The game can only say for sure while the auction house is open.
	if ns.auctionHouseOpen then
		local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
		local ok, valid = pcall(C_AuctionHouse.IsSellItemValid, location, false)
		return ok and valid == true
	end
	return true
end

function Bags:Refresh()
	local items, byKey, slots = {}, {}, {}
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and Sellable(bag, slot, info) then
				local name = info.hyperlink:match("|h%[(.-)%]|h")
				if name then
					local key = info.itemID .. ":" .. name
					local item = byKey[key]
					if not item then
						local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
						item = {
							key = key,
							itemID = info.itemID,
							name = name,
							quality = info.quality,
							icon = info.iconFileID,
							link = info.hyperlink,
							classID = classID,
							subClassID = subClassID,
							total = 0,
							slots = {},
						}
						byKey[key] = item
						items[#items + 1] = item
					end
					local entry = { bag = bag, slot = slot, count = info.stackCount or 1, icon = info.iconFileID, item = item }
					item.total = item.total + entry.count
					item.slots[#item.slots + 1] = entry
					slots[#slots + 1] = entry
				end
			end
		end
	end
	self.items, self.slots = items, slots
	Bus:Fire("BAGS_CHANGED")
end

-- Bag events come in bursts. Refresh once, on the next frame.
local queued = false
local function Schedule()
	if queued then
		return
	end
	queued = true
	C_Timer.After(0, function()
		queued = false
		Bags:Refresh()
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", Schedule)
Bus:On("READY", Schedule)
Bus:On("AH_OPENED", Schedule)
Bus:On("AH_CLOSED", Schedule)

-- Resolve bag locations afresh before posting; a cached slot can change.
local _, ns = ...
local Inventory = { items={}, byKey={} }
ns.Inventory = Inventory

function Inventory:Refresh()
	local items, byKey = {}, {}
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and not info.isBound then
				local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
				local name = info.hyperlink:match("|h%[(.-)%]|h")
				local valid = not ns.auctionHouseOpen or C_AuctionHouse.IsSellItemValid(location, false)
				if name and valid then
					local id, kind, sub, equip, icon, class, subclass = C_Item.GetItemInfoInstant(info.hyperlink)
					local key = id .. ":" .. name
					local item = byKey[key]
					if not item then
						item = { key=key, itemID=id, name=name, link=info.hyperlink, icon=icon,
							quality=info.quality, classID=class, subClassID=subclass, type=kind, subType=sub,
							equipLoc=equip, count=0, slots={} }
						byKey[key], items[#items+1] = item, item
					end
					item.count = item.count + info.stackCount
					item.slots[#item.slots+1] = { bag=bag, slot=slot, count=info.stackCount, locked=info.isLocked }
					if ns.auctionHouseOpen then
						local status=C_AuctionHouse.GetItemCommodityStatus(location)
						if status ~= 0 then item.commodity = status == 2 end
					end
				end
			end
		end
	end
	table.sort(items, function(a,b) return a.name < b.name end)
	self.items, self.byKey = items, byKey
	ns.Bus:Fire("BAGS_CHANGED")
end

function Inventory:Locate(key)
	self:Refresh()
	local item = self.byKey[key]
	for _, slot in ipairs(item and item.slots or {}) do
		if not slot.locked then return ItemLocation:CreateFromBagAndSlot(slot.bag, slot.slot), item end
	end
end

local queued = false
local function Schedule()
	if queued then return end
	queued = true
	C_Timer.After(0, function() queued = false; Inventory:Refresh() end)
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", Schedule)
ns.Bus:On("READY", Schedule)
ns.Bus:On("AH_OPENED", Schedule)
ns.Bus:On("AH_CLOSED", Schedule)

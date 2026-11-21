-- Incoming: gear bought at the auction house that has not reached the bags
-- yet, a reminder of what is on its way in the mail while shopping for more.
-- Only gear this character can wear counts. The Buy tab marks gear for a
-- slot with something incoming, names it beside that gear, and lists it all
-- when nothing is picked.
--
-- Kept per character across reloads and logins, until the item reaches the
-- bags (taken from the mail) or the mail would have run out
-- (ns.IncomingRule). Nothing here changes what "Better" compares against
-- (inventory\gear.lua).
--
-- An entry: name, itemID, equipLoc, amount (copper paid), time, had (how many
-- the bags held when it was bought)
local _, ns = ...
local Bus = ns.Bus

local Incoming = { entries = {} }
ns.Incoming = Incoming

-- The slots an equip location fills, as a set.
local function SlotsOf(equipLoc)
	local set = {}
	for _, slot in ipairs(ns.GearSlots[equipLoc] or {}) do
		set[slot] = true
	end
	return set
end

-- The equip location of gear this character can wear, or nil when the item
-- is not gear or the class cannot wear it (plate bought for an alt, say).
-- The same rule as "Better" (inventory\gear.lua).
local function EquipLoc(itemID)
	if not itemID or not C_Item or not C_Item.GetItemInfoInstant then
		return nil
	end
	local ok, _, _, _, equipLoc, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
	if not ok or (classID ~= 2 and classID ~= 4) or not ns.GearSlots[equipLoc] then
		return nil
	end
	if not ns.Gear:CanWear({ classID = classID, subClassID = subClassID }) then
		return nil
	end
	return equipLoc
end

local function InBags(itemID)
	local ok, count = pcall(GetItemCount, itemID)
	return ok and count or 0
end

function Incoming:Add(entry)
	local equipLoc = EquipLoc(entry.itemID)
	if not equipLoc then
		return nil
	end
	local incoming = {
		name = entry.name,
		itemID = entry.itemID,
		equipLoc = equipLoc,
		amount = entry.amount,
		time = entry.time or GetServerTime(),
		had = InBags(entry.itemID),
	}
	self.entries[#self.entries + 1] = incoming
	Bus:Fire("INCOMING_CHANGED", incoming)
	return incoming
end

-- Drops what has reached the bags, and what the mail would have returned.
function Incoming:Collect()
	local oldest = GetServerTime() - ns.IncomingRule.keepDays * 86400
	local changed = false
	for index = #self.entries, 1, -1 do
		local entry = self.entries[index]
		if entry.time < oldest or InBags(entry.itemID) > (entry.had or 0) then
			table.remove(self.entries, index)
			changed = true
		end
	end
	if changed then
		Bus:Fire("INCOMING_CHANGED")
	end
end

-- Everything incoming, newest first.
function Incoming:All()
	local found = {}
	for index = #self.entries, 1, -1 do
		found[#found + 1] = self.entries[index]
	end
	return found
end

-- What is incoming for any slot an item at equipLoc would fill, newest first.
function Incoming:ForSlot(equipLoc)
	local wanted = SlotsOf(equipLoc)
	local found = {}
	for _, entry in ipairs(self:All()) do
		for slot in pairs(SlotsOf(entry.equipLoc)) do
			if wanted[slot] then
				found[#found + 1] = entry
				break
			end
		end
	end
	return found
end

Bus:On("INIT", function()
	ns.charDb.incoming = ns.charDb.incoming or {}
	for _, entry in ipairs(Incoming.entries) do -- bought before the saved data loaded
		table.insert(ns.charDb.incoming, entry)
	end
	Incoming.entries = ns.charDb.incoming
end)

Bus:On("LEDGER_CHANGED", function(entry)
	if entry and entry.kind == "buy" then
		Incoming:Add(entry)
	end
end)

-- Taken from the mail: it is in the bags now.
local frame = CreateFrame("Frame")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	Incoming:Collect()
end)

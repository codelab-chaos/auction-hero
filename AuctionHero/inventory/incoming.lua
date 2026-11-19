-- Incoming: gear bought this session, a light reminder of what is on its way
-- in the mail. When the Buy tab shows a piece of gear, it names what was
-- bought for the same slot, so an upgrade is weighed against it by eye.
--
-- It is kept for this session only: a /reload or a new login starts empty.
-- Nothing here changes what "Better" compares against (inventory\gear.lua).
--
-- An entry: name, itemID, equipLoc, amount (copper paid), time
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

-- The equip location of a piece of gear, or nil when the item is not gear.
local function EquipLoc(itemID)
	if not itemID or not C_Item or not C_Item.GetItemInfoInstant then
		return nil
	end
	local ok, _, _, _, equipLoc, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
	if not ok or (classID ~= 2 and classID ~= 4) or not ns.GearSlots[equipLoc] then
		return nil
	end
	return equipLoc
end

function Incoming:Add(entry)
	local equipLoc = EquipLoc(entry.itemID)
	if not equipLoc then
		return nil
	end
	local incoming = { name = entry.name, itemID = entry.itemID, equipLoc = equipLoc, amount = entry.amount, time = entry.time or GetServerTime() }
	self.entries[#self.entries + 1] = incoming
	Bus:Fire("INCOMING_CHANGED", incoming)
	return incoming
end

-- What was bought this session for any slot an item at equipLoc would fill,
-- newest first.
function Incoming:ForSlot(equipLoc)
	local wanted = SlotsOf(equipLoc)
	local found = {}
	for index = #self.entries, 1, -1 do
		local entry = self.entries[index]
		for slot in pairs(SlotsOf(entry.equipLoc)) do
			if wanted[slot] then
				found[#found + 1] = entry
				break
			end
		end
	end
	return found
end

Bus:On("LEDGER_CHANGED", function(entry)
	if entry and entry.kind == "buy" then
		Incoming:Add(entry)
	end
end)

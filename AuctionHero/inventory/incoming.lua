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
-- the bags held when it was bought), and once the scan has named them, link
-- (the exact variant) and icon
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
	return ns.ItemCount(itemID)
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
	self:Link(incoming)
	self:Icon(incoming)
	self.entries[#self.entries + 1] = incoming
	Bus:Fire("INCOMING_CHANGED", incoming)
	return incoming
end

-- What the scan lists under an entry's id and name: the exact variant, with
-- its link and icon. nil when it is in no scan at hand.
local function Listed(entry)
	local market = ns.Analysis and ns.Analysis.market
	return market and market.byKey[tostring(entry.itemID) .. ":" .. tostring(entry.name)]
end

-- The link to show an entry by, and whether it names the exact variant
-- bought ("of the Bear", not the plain tunic). Kept once it is exact.
function Incoming:Link(entry)
	if not entry.link then
		local listed = Listed(entry)
		entry.link = listed and listed.link or nil
	end
	if entry.link then
		return entry.link, true
	end
	return "item:" .. entry.itemID, false
end

function Incoming:Icon(entry)
	if not entry.icon then
		local listed = Listed(entry)
		entry.icon = listed and listed.icon or nil
	end
	if not entry.icon and C_Item and C_Item.GetItemInfoInstant then
		local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, entry.itemID)
		entry.icon = ok and icon or nil
	end
	return entry.icon
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

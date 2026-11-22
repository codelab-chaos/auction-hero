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

-- The items carried, grouped by class in ns.BagCategoryOrder, each group
-- led by a heading row { heading = name }. options (all optional):
--   classes     only items of these classes ({ [classID] = true })
--   sort        { field = "name" | "total", descending } within each group;
--               without it, by subclass, then name
local Group
function Bags:Grouped(options)
	return Group(self.items, options or {})
end

local rank = {}
for position, classID in ipairs(ns.BagCategoryOrder) do
	rank[classID] = position
end
local function ClassRank(classID)
	return rank[classID] or (#ns.BagCategoryOrder + 1 + (classID or 99))
end

local function ClassName(classID)
	local read = classID and (C_Item.GetItemClassInfo or GetItemClassInfo)
	local name = read and read(classID)
	return (name and name ~= "") and name or ns.L.SELL_BAGS_OTHER
end

Group = function(items, options)
	local sorted = {}
	for _, item in ipairs(items) do
		if not options.classes or options.classes[item.classID] then
			sorted[#sorted + 1] = item
		end
	end
	local sort = options.sort
	table.sort(sorted, function(a, b)
		local ra, rb = ClassRank(a.classID), ClassRank(b.classID)
		if ra ~= rb then
			return ra < rb
		end
		if sort and a[sort.field] ~= b[sort.field] then
			if sort.descending then
				return a[sort.field] > b[sort.field]
			end
			return a[sort.field] < b[sort.field]
		end
		if not sort and (a.subClassID or 0) ~= (b.subClassID or 0) then
			return (a.subClassID or 0) < (b.subClassID or 0)
		end
		return a.name < b.name
	end)
	local rows, current = {}, false
	for _, item in ipairs(sorted) do
		local group = ClassRank(item.classID)
		if group ~= current then
			current = group
			rows[#rows + 1] = { heading = ClassName(item.classID) }
		end
		rows[#rows + 1] = item
	end
	return rows
end

function Bags:Find(key)
	for _, item in ipairs(self.items) do
		if item.key == key then
			return item
		end
	end
end

-- Everything carried is offered except soulbound items, which can never be
-- posted. Whether the auction house takes the rest is the game's call when
-- posting: a refusal comes back as a post error (see trade\posting.lua), so
-- nothing is hidden here on a guess.
local function Sellable(info)
	return info.hyperlink ~= nil and not info.isBound
end

-- The bags the player carries, by container id. The backpack is 0 and the
-- bag slots follow it, but a reagent bag's number differs between clients and
-- a client may not name it anywhere. So every container is also asked which
-- equipment slot holds it: one in the player's own bag slots is carried. Bank
-- bags sit in the bank's slots, and nothing can be posted from them.
local CARRIED_SLOTS = { "Bag0Slot", "Bag1Slot", "Bag2Slot", "Bag3Slot", "ReagentBag0Slot" }
local CARRIED_NAMES = { "^Backpack$", "^Bag_%d+$", "^ReagentBag" } -- in Enum.BagIndex
local PROBE_TO = 12 -- the highest container id asked about

local function NamedCarried(name)
	for _, pattern in ipairs(CARRIED_NAMES) do
		if name:find(pattern) then
			return true
		end
	end
	return false
end

-- The inventory ids of the player's own bag slots, as a set.
local function CarriedSlotIds()
	local ids = {}
	if not GetInventorySlotInfo then
		return ids
	end
	for _, slotName in ipairs(CARRIED_SLOTS) do
		local ok, id = pcall(GetInventorySlotInfo, slotName)
		if ok and type(id) == "number" then
			ids[id] = true
		end
	end
	return ids
end

local function CarriedBags()
	local seen, bags = {}, {}
	local function Add(bag)
		if type(bag) == "number" and bag >= 0 and not seen[bag] then
			seen[bag] = true
			bags[#bags + 1] = bag
		end
	end
	for bag = 0, NUM_BAG_SLOTS or 4 do
		Add(bag)
	end
	local index = Enum and Enum.BagIndex
	if type(index) == "table" then
		for name, bag in pairs(index) do
			if type(name) == "string" and NamedCarried(name) then
				Add(bag)
			end
		end
	end
	local toSlot = C_Container.ContainerIDToInventoryID
	local slotIds = CarriedSlotIds()
	if toSlot and next(slotIds) then
		for bag = 1, PROBE_TO do
			local ok, id = pcall(toSlot, bag)
			if ok and slotIds[id] then
				Add(bag)
			end
		end
	end
	table.sort(bags)
	return bags
end

-- Items whose data was asked for, by id, until it arrives.
local loading = {}

local function Load(itemID)
	if itemID and not loading[itemID] and C_Item.RequestLoadItemDataByID then
		loading[itemID] = true
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
end

-- Which bags were read, for the event log, noted only when it changes.
local lastNote

function Bags:Refresh()
	local items, byKey, slots = {}, {}, {}
	local bags = CarriedBags()
	for _, bag in ipairs(bags) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local sellable = info and Sellable(info)
			if sellable then
				local name = info.hyperlink:match("|h%[(.-)%]|h")
				if name == "" then
					-- Right after logging in an item's data may not have
					-- loaded: its link has no name yet. Ask for it, and read
					-- the bags again when it arrives (see the event below).
					Load(info.itemID)
					name = nil
				end
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
	local note = table.concat(bags, ",")
	if note ~= lastNote and ns.EventLog then
		lastNote = note
		ns.EventLog:Note("bags read", "bags " .. note, #slots .. " slots")
	end
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
frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
frame:SetScript("OnEvent", function(_, event, itemID)
	if event == "ITEM_DATA_LOAD_RESULT" then
		if not loading[itemID] then
			return
		end
		loading[itemID] = nil
	end
	Schedule()
end)
Bus:On("READY", Schedule)
Bus:On("AH_OPENED", Schedule)
Bus:On("AH_CLOSED", Schedule)

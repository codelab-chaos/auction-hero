-- Bag size: whether a bag for sale is bigger than the bag it would replace.
-- With gear (inventory\gear.lua) it makes the Buy tab's "Better" toggle.
--
-- Bags are compared kind with kind. A herb bag holds only herbs, so it is an
-- upgrade only over the herb bags the character carries; a general bag is an
-- upgrade over the smallest general bag, and over an empty bag slot. A kind
-- the character does not carry counts only when the player has picked that
-- kind in the filters: looking for one, any bigger than the smallest bag
-- carried will do.
-- A bag's size is not in the item's info, only on its tooltip ("12 Slot
-- Bag"), so it is read from there once per item and kept. An item the
-- client has not loaded yet has no tooltip; it is asked for, and the list is
-- told to look again once it arrives.
local _, ns = ...
local Bus = ns.Bus

local BagSize = {}
ns.BagSize = BagSize

local CONTAINER_CLASS = 1 -- Enum.ItemClass.Container
local GENERAL = 0 -- the container subclass of an ordinary bag
local FIRST_BAG = 1 -- bag 0 is the backpack, which cannot be swapped

local sizes = {} -- itemID -> slots, once read
local asked = {} -- itemID -> true while waiting on the item's data

-- "12 Slot Bag" in the game's own words, so it reads in any language.
local SLOTS_PATTERN = (CONTAINER_SLOTS and CONTAINER_SLOTS:gsub("%%d", "(%%d+)"):gsub("%%s", ".+")) or "(%d+) Slot"

local function SlotsIn(lines)
	for _, text in ipairs(lines) do
		local slots = type(text) == "string" and text:match(SLOTS_PATTERN)
		if slots then
			return tonumber(slots)
		end
	end
end

-- The left-hand lines of an item's tooltip, or an empty list.
local scanner
local function TooltipLines(itemID)
	local lines = {}
	if C_TooltipInfo and C_TooltipInfo.GetItemByID then
		local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
		for _, line in ipairs(ok and data and data.lines or {}) do
			lines[#lines + 1] = line.leftText
		end
		return lines
	end
	if not scanner then
		scanner = CreateFrame("GameTooltip", "AuctionHeroBagScanner", nil, "GameTooltipTemplate")
	end
	scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanner:ClearLines()
	pcall(scanner.SetItemByID, scanner, itemID)
	for index = 1, scanner:NumLines() or 0 do
		local left = _G["AuctionHeroBagScannerTextLeft" .. index]
		lines[#lines + 1] = left and left:GetText()
	end
	scanner:Hide()
	return lines
end

-- How many slots a bag has, or nil while that cannot be read yet.
function BagSize:Slots(itemID)
	if not itemID then
		return nil
	end
	local known = sizes[itemID]
	if known then
		return known
	end
	local slots = SlotsIn(TooltipLines(itemID))
	if slots then
		sizes[itemID] = slots
		asked[itemID] = nil
	elseif not asked[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
		asked[itemID] = true
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
	return slots
end

-- The kind of bag in a bag slot (its container subclass), or nil when the
-- slot is empty. A bag whose kind cannot be read is taken as an ordinary one.
local function KindIn(bag)
	local toSlot = C_Container.ContainerIDToInventoryID
	local ok, slot = false, nil
	if toSlot then
		ok, slot = pcall(toSlot, bag)
	end
	local link = ok and slot and GetInventoryItemLink("player", slot)
	if not link then
		return nil
	end
	local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(link)
	return classID == CONTAINER_CLASS and subClassID or GENERAL
end

-- What the character carries: the fewest slots of each kind of bag, by
-- container subclass, and the fewest of any kind. An empty bag slot is a
-- general one of size 0.
function BagSize:Carried()
	local byKind, smallest = {}, nil
	for bag = FIRST_BAG, NUM_BAG_SLOTS or 4 do
		local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
		slots = ok and slots or 0
		local kind = slots > 0 and KindIn(bag) or GENERAL
		byKind[kind] = math.min(byKind[kind] or slots, slots)
		smallest = math.min(smallest or slots, slots)
	end
	return byKind, smallest or 0
end

-- How many more slots a bag for sale has than the bag it would replace, or
-- nil when it is not a bag, its size cannot be read yet, or it is of a kind
-- the character neither carries nor looks for. Fixed as things stand now:
-- build one per pass over the list. picked is a set of container
-- subclasses the player chose in the filters, or nil.
function BagSize:Gains(picked)
	local byKind, smallest = self:Carried()
	return function(item)
		if item.classID ~= CONTAINER_CLASS then
			return nil
		end
		local against = byKind[item.subClassID or GENERAL]
		if against == nil and picked and picked[item.subClassID] then
			against = smallest
		end
		local slots = against and self:Slots(item.itemID)
		return slots and slots - against or nil
	end
end

-- A test for "a bigger bag than the one it would replace".
function BagSize:Better(picked)
	local gain = self:Gains(picked)
	return function(item)
		local by = gain(item)
		return by ~= nil and by > 0
	end
end

-- Slots gained per gold at the bag's cheapest auction, or nil when it gains
-- none, is known to be unusable, or has no price. Bags in "Picks".
function BagSize:ValuePerGold(priceOf, picked)
	local gain = self:Gains(picked)
	return function(item)
		if item.usable == false then
			return nil
		end
		local by = gain(item)
		local price = by and by > 0 and priceOf(item)
		if not price or price <= 0 then
			return nil
		end
		return by / (price / ns.GearCopperPerGold)
	end
end

-- A bag was swapped, or a bag's data arrived: what is better changed. Data
-- for many items can arrive at once, so the news goes out once a moment later.
local pending = false
local function Changed()
	if pending then
		return
	end
	pending = true
	C_Timer.After(0.5, function()
		pending = false
		Bus:Fire("GEAR_CHANGED")
	end)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "BAG_CONTAINER_UPDATE", "GET_ITEM_INFO_RECEIVED" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, itemID)
	if event == "GET_ITEM_INFO_RECEIVED" then
		if not asked[itemID] then
			return
		end
		asked[itemID] = nil
	end
	Changed()
end)

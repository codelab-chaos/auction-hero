-- Gear: whether an item for sale beats what the character wears, and whether
-- its required level is near the character's. The Buy tab's "Better" and
-- "Near level" toggles. The rules are data\gear.lua.
--
-- An item is better when the character's class can wear it, by the time its
-- required level lets them, and its stats, weighted for the class, add up to
-- more than what is worn in that slot. An empty slot is beaten by anything
-- with a stat the class values. When stats cannot be read for either side,
-- the item is not called better.
local _, ns = ...
local Bus = ns.Bus

local Gear = {}
ns.Gear = Gear

local REQUIRED_LEVEL = "REQ_LEVEL_ABBR"
local scores = {} -- item link -> weighted score, for this character's class

local function Class()
	local _, class = UnitClass("player")
	return class
end

local function Level()
	return UnitLevel("player") or 1
end

local function RequiredLevel(item)
	return item.levelType == REQUIRED_LEVEL and item.level or nil
end

local function ReadStats(link)
	local read = (C_Item and C_Item.GetItemStats) or GetItemStats
	if not read then
		return nil
	end
	local ok, stats = pcall(read, link)
	return ok and type(stats) == "table" and stats or nil
end

-- An item's stats added up with the class's weights, or nil when they cannot
-- be read yet. Kept per link: a link names one exact variant.
function Gear:Score(link)
	if not link then
		return nil
	end
	if scores[link] then
		return scores[link]
	end
	local weights = ns.GearStatWeights[Class()]
	local stats = weights and ReadStats(link)
	if not stats then
		return nil
	end
	local score = 0
	for stat, weight in pairs(weights) do
		for _, key in ipairs(ns.GearStatKeys[stat] or {}) do
			score = score + (tonumber(stats[key]) or 0) * weight
		end
	end
	scores[link] = score
	return score
end

-- What is worn in an inventory slot scores, 0 when the slot is empty.
local function Worn(slot)
	local link = GetInventoryItemLink("player", slot)
	if not link then
		return 0
	end
	return Gear:Score(link)
end

-- What an item worn at equipLoc would be measured against: the weaker of
-- its slots, and both hands for a two-handed weapon. nil when unknown.
function Gear:WornScore(equipLoc)
	local slots = ns.GearSlots[equipLoc]
	if not slots then
		return nil
	end
	local weakest
	for _, slot in ipairs(slots) do
		local score = Worn(slot)
		if score == nil then
			return nil
		end
		weakest = weakest and math.min(weakest, score) or score
	end
	if ns.GearBothHands[equipLoc] then
		local offHand = Worn(17)
		if offHand == nil then
			return nil
		end
		weakest = weakest + offHand
	end
	return weakest
end

-- Whether the class can wear the item once its required level allows. A
-- level of 0 asks about today: the character's level, nothing bought ahead.
function Gear:CanWear(item, class, level)
	class = class or Class()
	local early = level ~= 0 -- level 0: as things stand today, not a level early
	level = (level == nil or level == 0) and Level() or level
	if item.classID == 4 then
		local from = (ns.GearArmor[class] or {})[item.subClassID]
		local by = early and math.max(level, RequiredLevel(item) or 0) or level
		return from ~= nil and from <= by
	elseif item.classID == 2 then
		return (ns.GearWeapons[class] or {})[item.subClassID] == true
	end
	return false
end

-- How much better an item is than what is worn in its slot, in weighted
-- stat points (negative when worse), or nil when the class cannot wear it
-- by the given level or the stats cannot be read. Fixed as things stand now:
-- build one per pass over the list, what is worn is looked up once per slot.
function Gear:Gains(level)
	local class = Class()
	level = level or Level()
	local worn = {} -- equipLoc -> score, or false when unknown
	return function(item)
		if not ns.GearSlots[item.equipLoc] or not self:CanWear(item, class, level) then
			return nil
		end
		local against = worn[item.equipLoc]
		if against == nil then
			against = self:WornScore(item.equipLoc) or false
			worn[item.equipLoc] = against
		end
		local score = against and self:Score(item.link)
		if not score then
			return nil
		end
		return score - against
	end
end

-- A test for "better than what you wear". Gear the class gets at a level
-- counts from that level on (see CanWear), so it can be bought a level early.
function Gear:Better()
	local gain = self:Gains()
	return function(item)
		local by = gain(item)
		return by ~= nil and by > 0
	end
end

-- What one gold buys of an upgrade the character can wear today: gain per
-- gold at the item's cheapest auction, or nil when it is no upgrade, needs
-- a higher level, is known to be unusable, or has no price. "Picks".
function Gear:ValuePerGold(priceOf)
	local level = Level()
	local gain = self:Gains(0) -- wearable now: no buying ahead of the level
	return function(item)
		local required = RequiredLevel(item)
		if item.usable == false or (required and required > level) then
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

-- ========= Near level =======================================================
local function Offsets()
	ns.charDb.gearLevels = ns.charDb.gearLevels or {}
	return ns.charDb.gearLevels
end

-- How far under and over the character's level "Near level" reaches.
function Gear:Offset(side)
	return Offsets()[side] or ns.GearLevelRule[side]
end

function Gear:SetOffset(side, levels)
	Offsets()[side] = math.max(0, math.min(ns.GearLevelRule.max, math.floor(levels)))
	Bus:Fire("GEAR_CHANGED")
end

-- The required levels "Near level" shows, lowest and highest.
function Gear:LevelRange()
	local level = Level()
	return math.max(1, level - self:Offset("below")), level + self:Offset("above")
end

-- A test for "its required level is near mine", fixed as things stand now.
function Gear:Near()
	local low, high = self:LevelRange()
	return function(item)
		local required = RequiredLevel(item)
		return required ~= nil and required >= low and required <= high
	end
end

-- What is worn, or the character's level, changed: what is better changed too.
local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function()
	Bus:Fire("GEAR_CHANGED")
end)

-- Gear: what the Buy tab's "Better" and "Near level" toggles go by, as data.
-- The logic that applies it is inventory\gear.lua.
--
-- The stat weights are a starting point for levelling, not a theorycraft
-- result: tune them here. A weight is what one point of the stat is worth
-- next to one point of the class's main stat.
local _, ns = ...

-- The equipped slots an item worn in each equip location would replace
-- (the game's inventory slot ids). With two slots (rings, trinkets) it is
-- measured against the weaker of the two.
ns.GearSlots = {
	INVTYPE_HEAD = { 1 },
	INVTYPE_NECK = { 2 },
	INVTYPE_SHOULDER = { 3 },
	INVTYPE_BODY = { 4 },
	INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 },
	INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 },
	INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16 },
	INVTYPE_WEAPONMAINHAND = { 16 },
	INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_SHIELD = { 17 },
	INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 },
	INVTYPE_RANGEDRIGHT = { 18 },
	INVTYPE_THROWN = { 18 },
	INVTYPE_RELIC = { 18 },
}

-- A two-handed weapon also takes the off hand's place, so it is measured
-- against what both hands hold.
ns.GearBothHands = { INVTYPE_2HWEAPON = true }

-- The stats a weight can name, and the keys GetItemStats reports them under.
-- Spell damage and healing have had more than one key over the game's life,
-- so each is looked up under all of them.
ns.GearStatKeys = {
	str = { "ITEM_MOD_STRENGTH_SHORT" },
	agi = { "ITEM_MOD_AGILITY_SHORT" },
	sta = { "ITEM_MOD_STAMINA_SHORT" },
	int = { "ITEM_MOD_INTELLECT_SHORT" },
	spi = { "ITEM_MOD_SPIRIT_SHORT" },
	armor = { "RESISTANCE0_NAME" },
	dps = { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" },
	ap = { "ITEM_MOD_ATTACK_POWER_SHORT" },
	spell = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" },
	heal = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
}

-- Per class (the game's class file name). A stat a class has no weight for
-- counts for nothing.
ns.GearStatWeights = {
	WARRIOR = { str = 1, sta = 0.8, agi = 0.6, armor = 0.02, dps = 3, ap = 0.5 },
	PALADIN = { str = 1, sta = 0.8, int = 0.5, agi = 0.3, spi = 0.2, armor = 0.02, dps = 3, ap = 0.5, spell = 0.6, heal = 0.4 },
	HUNTER = { agi = 1, sta = 0.6, int = 0.4, spi = 0.2, str = 0.1, armor = 0.01, dps = 2, ap = 0.5 },
	ROGUE = { agi = 1, sta = 0.6, str = 0.5, armor = 0.01, dps = 3, ap = 0.5 },
	PRIEST = { int = 1, spi = 0.8, sta = 0.6, armor = 0.005, dps = 1, spell = 0.8, heal = 0.6 },
	SHAMAN = { int = 0.8, str = 0.7, sta = 0.7, agi = 0.5, spi = 0.3, armor = 0.01, dps = 2, ap = 0.4, spell = 0.7, heal = 0.5 },
	MAGE = { int = 1, sta = 0.6, spi = 0.6, armor = 0.005, dps = 1, spell = 0.9 },
	WARLOCK = { int = 0.8, sta = 0.9, spi = 0.5, armor = 0.005, dps = 1, spell = 0.9 },
	DRUID = { int = 0.8, sta = 0.7, str = 0.6, agi = 0.6, spi = 0.5, armor = 0.01, ap = 0.4, spell = 0.7, heal = 0.5 },
}

-- What each class can wear: armor subclass id -> the level it can from.
-- 0 misc (rings, necks, trinkets), 1 cloth (and every cloak), 2 leather,
-- 3 mail, 4 plate, 6 shield, 7 libram, 8 idol, 9 totem.
local ANY = { [0] = 1, [1] = 1 }
local function Armor(extra)
	local kinds = { [0] = 1, [1] = 1 }
	for id, level in pairs(extra) do
		kinds[id] = level
	end
	return kinds
end
ns.GearArmor = {
	WARRIOR = Armor({ [2] = 1, [3] = 1, [4] = 40, [6] = 1 }),
	PALADIN = Armor({ [2] = 1, [3] = 1, [4] = 40, [6] = 1, [7] = 1 }),
	HUNTER = Armor({ [2] = 1, [3] = 40 }),
	ROGUE = Armor({ [2] = 1 }),
	PRIEST = ANY,
	SHAMAN = Armor({ [2] = 1, [3] = 40, [6] = 1, [9] = 1 }),
	MAGE = ANY,
	WARLOCK = ANY,
	DRUID = Armor({ [2] = 1, [8] = 1 }),
}

-- The weapon kinds each class can learn (weapon subclass ids):
-- 0 one-handed axe, 1 two-handed axe, 2 bow, 3 gun, 4 one-handed mace,
-- 5 two-handed mace, 6 polearm, 7 one-handed sword, 8 two-handed sword,
-- 10 staff, 13 fist weapon, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local function Kinds(list)
	local set = {}
	for _, id in ipairs(list) do
		set[id] = true
	end
	return set
end
ns.GearWeapons = {
	WARRIOR = Kinds({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }),
	PALADIN = Kinds({ 0, 1, 4, 5, 6, 7, 8 }),
	HUNTER = Kinds({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }),
	ROGUE = Kinds({ 2, 3, 4, 7, 13, 15, 16, 18 }),
	PRIEST = Kinds({ 4, 10, 15, 19 }),
	SHAMAN = Kinds({ 0, 1, 4, 5, 10, 13, 15 }),
	MAGE = Kinds({ 7, 10, 15, 19 }),
	WARLOCK = Kinds({ 7, 10, 15, 19 }),
	DRUID = Kinds({ 4, 5, 10, 13, 15 }),
}

-- "Near level": required levels this far under and over your own are shown.
-- Changed in the options panel; kept per character.
ns.GearLevelRule = { below = 1, above = 1, max = 10 }

-- "Picks" weighs gain against gold.
ns.GearCopperPerGold = 10000

-- Bags gain slots, not stat points, so the two cannot be ranked together.
-- Sorted by gain, bags follow the gear as a group of their own: their sort
-- value is their extra slots less this, far under any stat gain.
ns.BagGainSortOffset = 100000

-- Gear bought and still in the mail (inventory\incoming.lua). Mail is
-- returned after 30 days, so nothing is incoming for longer. The icon heads
-- the Buy list's column for it, where gear for a slot with something
-- incoming shows what was bought, iconSize wide.
ns.IncomingRule = {
	keepDays = 30,
	icon = "|TInterface\\Icons\\INV_Letter_15:14:14|t",
	iconSize = 16,
}

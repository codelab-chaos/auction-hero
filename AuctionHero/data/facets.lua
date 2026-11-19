-- Facets: the Buy tab's filters, as data. This is the lab's
-- lab/src/config/facets.ts carried over.
--
-- A facet is a group of checkboxes. Ticking boxes in one group means "any of
-- these". Groups combine as "and", except groups that share a dimension:
-- those are one question asked in several places, so they combine as "any of
-- these" too. Every category shares the "type" dimension, so ticking Leather
-- and Swords shows both.
--
-- Category fields:
--   classIDs   the game's item class ids (Enum.ItemClass)
--   slots      only items worn in these equip slots belong
--   notSlots   items worn in these equip slots do not
--   boxes      the checkboxes to offer in place of the game's raw subtypes.
--              An item goes in the first box it fits: { label, subClassIDs,
--              slots, inRail }. Items that fit none keep their own subtype
--   keepOrder  list the boxes in the order written, not alphabetically
--   iconSlots  the equip slot that best pictures a box
--   flat       no header and no expander: the boxes sit straight in the column
--   refine     on/off toggles that narrow only this category's items:
--              { label, options = { { label, slots, pictureSubClass } } }
local _, ns = ...
local L = ns.L

local BODY_SLOTS = {
	{ label = L.SLOT_HEAD, slots = { "INVTYPE_HEAD" } },
	{ label = L.SLOT_SHOULDER, slots = { "INVTYPE_SHOULDER" } },
	{ label = L.SLOT_CHEST, slots = { "INVTYPE_CHEST", "INVTYPE_ROBE" } }, -- a robe is a chest piece
	{ label = L.SLOT_WAIST, slots = { "INVTYPE_WAIST" } },
	{ label = L.SLOT_LEGS, slots = { "INVTYPE_LEGS" } },
	{ label = L.SLOT_FEET, slots = { "INVTYPE_FEET" } },
	{ label = L.SLOT_WRIST, slots = { "INVTYPE_WRIST" } },
	{ label = L.SLOT_HANDS, slots = { "INVTYPE_HAND" } },
}

local BODY_SLOT_NAMES = {}
for _, entry in ipairs(BODY_SLOTS) do
	for _, slot in ipairs(entry.slots) do
		BODY_SLOT_NAMES[#BODY_SLOT_NAMES + 1] = slot
	end
end

-- How a weapon is held: in one hand, in two, or at range (bows, guns,
-- crossbows, wands and thrown weapons). pictureSubClass picks the icon: a
-- one-handed sword, a two-handed axe and a bow, so the tiles look different
-- at a glance.
local WEAPON_HANDS = {
	{ label = L.HAND_ONE, slots = { "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND" }, pictureSubClass = 7 },
	{ label = L.HAND_TWO, slots = { "INVTYPE_2HWEAPON" }, pictureSubClass = 1 },
	{ label = L.HAND_RANGED, slots = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN" }, pictureSubClass = 2 },
}

-- The auction house's top-level categories. The game has one Armor class; we
-- show it as Armor (the eight body slots, where material applies) and
-- Accessories (everything else it calls armor). The game files every cloak as
-- Cloth, which is why that split is by slot.
ns.ItemCategories = {
	{
		id = "weapons",
		label = L.CAT_WEAPONS,
		classIDs = { 2 },
		boxes = {
			{ label = L.BOX_SWORDS, subClassIDs = { 7, 8 } },
			{ label = L.BOX_AXES, subClassIDs = { 0, 1 } },
			{ label = L.BOX_MACES, subClassIDs = { 4, 5 } },
		},
		refine = { label = L.CAT_WEAPONS, options = WEAPON_HANDS },
	},
	{
		id = "armor",
		label = L.CAT_ARMOR,
		classIDs = { 4 },
		slots = BODY_SLOT_NAMES,
		boxes = {
			{ label = L.BOX_CLOTH, subClassIDs = { 1 } },
			{ label = L.BOX_LEATHER, subClassIDs = { 2 } },
			{ label = L.BOX_MAIL, subClassIDs = { 3 } },
			{ label = L.BOX_PLATE, subClassIDs = { 4 } },
		},
		keepOrder = true,
		iconSlots = { "INVTYPE_CHEST", "INVTYPE_ROBE" },
		refine = { label = L.CAT_ARMOR, options = BODY_SLOTS },
	},
	{
		id = "accessories",
		label = L.CAT_ACCESSORIES,
		classIDs = { 4 },
		notSlots = BODY_SLOT_NAMES,
		boxes = {
			{ label = L.BOX_CLOAKS, slots = { "INVTYPE_CLOAK" }, inRail = true },
			{ label = L.BOX_NECK, slots = { "INVTYPE_NECK" }, inRail = true },
			{ label = L.BOX_FINGER, slots = { "INVTYPE_FINGER" }, inRail = true },
			{ label = L.BOX_TRINKET, slots = { "INVTYPE_TRINKET" } },
			{ label = L.BOX_OFF_HAND, slots = { "INVTYPE_HOLDABLE" } },
			{ label = L.BOX_SHIELD, slots = { "INVTYPE_SHIELD" }, inRail = true },
			{ label = L.BOX_SHIRT, slots = { "INVTYPE_BODY" } },
			{ label = L.BOX_TABARD, slots = { "INVTYPE_TABARD" } },
			{ label = L.BOX_RELICS, subClassIDs = { 7, 8, 9 } }, -- libram, idol, totem
		},
	},
	{ id = "containers", label = L.CAT_CONTAINERS, classIDs = { 1, 11 } }, -- bags, and quivers and ammo pouches
	{ id = "consumables", label = L.CAT_CONSUMABLES, classIDs = { 0 } },
	{ id = "trade-goods", label = L.CAT_TRADE_GOODS, classIDs = { 7, 5 } }, -- and reagents
	{ id = "recipes", label = L.CAT_RECIPES, classIDs = { 9 } },
	{ id = "misc", label = L.CAT_MISC, classIDs = { 15, 13 } }, -- and keys
	-- The categories whose boxes sit straight in the column go last.
	{ id = "projectile", label = L.CAT_PROJECTILE, classIDs = { 6 }, flat = true },
	{ id = "quest", label = L.CAT_QUEST, classIDs = { 12 }, flat = true },
}

-- The quality facet: its boxes are color swatches, square tiles at the top of the category column.
ns.QualityFacet = { id = "quality", label = L.FACET_QUALITY, qualities = { 0, 1, 2, 3, 4, 5 } } -- poor to legendary

-- The left strip, top to bottom, as sections with a divider between them.
-- An entry is one of:
--   { quality = true }      the quality swatches
--   { refine = id }         the toggles of that category's refine
--   { box = label, of = id } one box of a category
ns.BuyRail = {
	-- What goes in your hands: one-hand, two-hand and ranged, then shields.
	{ { refine = "weapons" }, { box = L.BOX_SHIELD, of = "accessories" } },
	-- What you wear: the body slots, then the back.
	{ { refine = "armor" }, { box = L.BOX_CLOAKS, of = "accessories" } },
	-- What you wear that is not armor: necklaces and rings.
	{ { box = L.BOX_NECK, of = "accessories" }, { box = L.BOX_FINGER, of = "accessories" } },
}

-- The quality squares' icons, by quality: icons the game has had since the
-- start, since Forever does not carry later expansions' art. desaturate
-- draws it in gray. A quality with no icon here, or whose icon the game
-- does not have, is a plain square of its color.
local ICONS = "Interface\\Icons\\"
ns.QualityIcons = {
	[0] = { icon = ICONS .. "inv_stone_06" }, -- poor
	[1] = { icon = ICONS .. "inv_misc_gem_diamond_01", desaturate = true }, -- common
	[2] = { icon = ICONS .. "inv_misc_gem_emerald_01" }, -- uncommon
	[3] = { icon = ICONS .. "inv_misc_gem_sapphire_01" }, -- rare
	[4] = { icon = ICONS .. "inv_misc_gem_amethyst_01" }, -- epic
	[5] = { icon = ICONS .. "inv_misc_gem_opal_01" }, -- legendary
}

-- The top of the category column: rows of square tiles, one row per entry
-- (the same entries as the rail's). Moving an entry between here and
-- ns.BuyRail moves its tiles.
ns.BuySidebarTop = {
	{ quality = true },
}

-- The quick toggles beside the search box.
-- Left to right. sort: how the list is sorted when the toggle is turned on.
-- turnsOn: the toggles turned on with it.
ns.BuyToggles = {
	{ id = "suggested", label = L.BUY_SUGGESTED, tip = L.BUY_SUGGESTED_TIP, sort = { id = "gain", descending = true }, turnsOn = { "usableOnly", "affordableOnly" } },
	{ id = "usableOnly", label = L.BUY_CAN_USE, tip = L.BUY_CAN_USE_TIP },
	{ id = "affordableOnly", label = L.BUY_CAN_AFFORD, tip = L.BUY_CAN_AFFORD_TIP },
	{ id = "betterOnly", label = L.BUY_BETTER, tip = L.BUY_BETTER_TIP },
	{ id = "nearLevel", label = L.BUY_NEAR_LEVEL, tip = L.BUY_NEAR_LEVEL_TIP },
	{ id = "dealsOnly", label = L.BUY_DEALS, tip = L.BUY_DEALS_TIP },
}

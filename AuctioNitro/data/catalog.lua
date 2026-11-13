-- The lab's categories, expressed with client class and slot ids.
local _, ns = ...
local body = { INVTYPE_HEAD=true, INVTYPE_SHOULDER=true, INVTYPE_CHEST=true, INVTYPE_ROBE=true,
	INVTYPE_WAIST=true, INVTYPE_LEGS=true, INVTYPE_FEET=true, INVTYPE_WRIST=true, INVTYPE_HAND=true }
ns.Categories = {
	{ id="all", label="All items", match=function() return true end },
	{ id="weapons", label="Weapons", match=function(i) return i.classID == 2 end },
	{ id="armor", label="Armor", match=function(i) return i.classID == 4 and body[i.equipLoc] end },
	{ id="accessories", label="Accessories", match=function(i) return i.classID == 4 and not body[i.equipLoc] end },
	{ id="containers", label="Containers", match=function(i) return i.classID == 1 or i.classID == 11 end },
	{ id="consumables", label="Consumables", match=function(i) return i.classID == 0 end },
	{ id="trade", label="Trade goods", match=function(i) return i.classID == 7 or i.classID == 5 end },
	{ id="recipes", label="Recipes", match=function(i) return i.classID == 9 end },
	{ id="ammo", label="Projectile", match=function(i) return i.classID == 6 end },
	{ id="quest", label="Quest items", match=function(i) return i.classID == 12 end },
	{ id="misc", label="Miscellaneous", match=function(i) return i.classID == 15 or i.classID == 13 end },
}
ns.SlotNames = { INVTYPE_HEAD="Head", INVTYPE_NECK="Neck", INVTYPE_SHOULDER="Shoulder", INVTYPE_CHEST="Chest",
	INVTYPE_ROBE="Chest", INVTYPE_WAIST="Waist", INVTYPE_LEGS="Legs", INVTYPE_FEET="Feet", INVTYPE_WRIST="Wrist",
	INVTYPE_HAND="Hands", INVTYPE_FINGER="Finger", INVTYPE_TRINKET="Trinket", INVTYPE_CLOAK="Back", INVTYPE_WEAPON="One-hand",
	INVTYPE_2HWEAPON="Two-hand", INVTYPE_SHIELD="Shield", INVTYPE_HOLDABLE="Off-hand", INVTYPE_RANGED="Ranged",
	INVTYPE_RANGEDRIGHT="Ranged", INVTYPE_WEAPONMAINHAND="Main hand", INVTYPE_WEAPONOFFHAND="Off hand",
	INVTYPE_BODY="Shirt", INVTYPE_TABARD="Tabard", INVTYPE_RELIC="Relic", INVTYPE_BAG="Bag", INVTYPE_AMMO="Ammo" }

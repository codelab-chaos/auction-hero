-- Gear: the Buy tab's "Better" (beats what you wear, by stats weighted for
-- your class) and "Near level" (required level near yours) toggles.
local ns = Boot()

local function item(link, classID, subClassID, equipLoc, level)
	return { link = link, classID = classID, subClassID = subClassID, equipLoc = equipLoc, level = level, levelType = level and "REQ_LEVEL_ABBR" or nil }
end

-- A level 12 rogue in a leather chest with 3 agility and 30 armor.
PLAYER.level, PLAYER.class = 12, "ROGUE"
EQUIPPED[5] = "worn-chest"
ITEM_STATS["worn-chest"] = { ITEM_MOD_AGILITY_SHORT = 3, RESISTANCE0_NAME = 30 }
ITEM_STATS["agile-chest"] = { ITEM_MOD_AGILITY_SHORT = 5, RESISTANCE0_NAME = 30 }
ITEM_STATS["wise-chest"] = { ITEM_MOD_INTELLECT_SHORT = 9, RESISTANCE0_NAME = 30 }
ITEM_STATS["mail-chest"] = { ITEM_MOD_AGILITY_SHORT = 8, RESISTANCE0_NAME = 90 }
ITEM_STATS["ring"] = { ITEM_MOD_STAMINA_SHORT = 2 }
ITEM_STATS["staff"] = { ITEM_MOD_AGILITY_SHORT = 20, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 }

check("a rogue weighs agility", ns.Gear:Score("worn-chest"), 3 + 30 * 0.01)
local better = ns.Gear:Better()
checkTrue("more agility in the same slot is better", better(item("agile-chest", 4, 2, "INVTYPE_CHEST", 11)))
checkTrue("intellect is worth nothing to a rogue", not better(item("wise-chest", 4, 2, "INVTYPE_CHEST", 11)))
checkTrue("a rogue cannot wear mail, however good", not better(item("mail-chest", 4, 3, "INVTYPE_CHEST", 11)))
checkTrue("nor learn staves", not better(item("staff", 2, 10, "INVTYPE_2HWEAPON", 11)))
checkTrue("an empty slot is beaten by any stat the class values", better(item("ring", 4, 0, "INVTYPE_FINGER", 10)))
checkTrue("an item whose stats cannot be read is not called better", not better(item("unknown", 4, 2, "INVTYPE_CHEST", 11)))

-- How much better, and what a gold of it costs.
local gain = ns.Gear:Gains()
check("gain is the score over what is worn", gain(item("agile-chest", 4, 2, "INVTYPE_CHEST", 11)), 2)
check("and goes negative when worse", gain(item("wise-chest", 4, 2, "INVTYPE_CHEST", 11)), -3)
local prices = { ["agile-chest"] = 20000, ["ring"] = 10000, ["later-chest"] = 1000 }
ITEM_STATS["later-chest"] = { ITEM_MOD_AGILITY_SHORT = 50, RESISTANCE0_NAME = 30 }
local value = ns.Gear:ValuePerGold(function(it)
	return prices[it.link]
end)
check("suggested weighs gain per gold", value(item("agile-chest", 4, 2, "INVTYPE_CHEST", 11)), 1)
check("a cheap ring for an empty slot", value(item("ring", 4, 0, "INVTYPE_FINGER", 10)), 2 * 0.6)
checkTrue("nothing it cannot wear today", value(item("later-chest", 4, 2, "INVTYPE_CHEST", 13)) == nil)
checkTrue("nothing the game says it cannot use", value({ link = "agile-chest", classID = 4, subClassID = 2, equipLoc = "INVTYPE_CHEST", usable = false }) == nil)
checkTrue("nothing that is worse", value(item("wise-chest", 4, 2, "INVTYPE_CHEST", 11)) == nil)

-- A hunter wears mail from level 40, and can buy for it a level early.
PLAYER.class = "HUNTER"
checkTrue("a hunter at 12 cannot wear mail", not ns.Gear:CanWear(item("mail-chest", 4, 3, "INVTYPE_CHEST", 11)))
checkTrue("mail that needs level 40 is wearable then", ns.Gear:CanWear(item("mail-chest", 4, 3, "INVTYPE_CHEST", 40)))
PLAYER.class = "ROGUE"

-- Near level: at 12, one under and one over by default.
local low, high = ns.Gear:LevelRange()
check("near level starts one under", low, 11)
check("and ends one over", high, 13)
local near = ns.Gear:Near()
checkTrue("13 is near 12", near(item("a", 4, 2, "INVTYPE_CHEST", 13)))
checkTrue("14 is not", not near(item("a", 4, 2, "INVTYPE_CHEST", 14)))
checkTrue("an item with no required level is not", not near(item("a", 7, 0, nil, nil)))
ns.Gear:SetOffset("below", 3)
ns.Gear:SetOffset("above", 99)
low, high = ns.Gear:LevelRange()
check("the range is set per side", low, 9)
check("and held to its limit", high, 12 + ns.GearLevelRule.max)
ns.Gear:SetOffset("below", 1)
ns.Gear:SetOffset("above", 1)

-- On the Buy tab: the toggles sit beside the search box.
OpenAuctionHouse()
Scan()
ShowTab("buy")
checkTrue("Can use is now just Use", ButtonNamed("Use") ~= nil)
checkTrue("Better is a toggle", ButtonNamed("Better") ~= nil)
checkTrue("so is Picks", ButtonNamed("Picks") ~= nil)
local picks, use = ButtonNamed("Picks"), ButtonNamed("Use")
check("Picks comes first", ns.BuyToggles[1].id, "suggested")
check("and sorts by gain", ns.BuyToggles[1].sort.id, "gain")
check("biggest first", ns.BuyToggles[1].sort.descending, true)
check("then Use", ns.BuyToggles[2].id, "usableOnly")
check("then Afford", ns.BuyToggles[3].id, "affordableOnly")
picks.scripts.OnClick(picks)
checkTrue("turning Picks on turns Use on too", use.active)
local afford = ButtonNamed("Afford")
checkTrue("and Afford", afford.active)
picks.scripts.OnClick(picks)
use.scripts.OnClick(use)
afford.scripts.OnClick(afford)
checkTrue("each turns off by itself", not picks.active and not use.active and not afford.active)

local function rows()
	return Frames(function(frame)
		return frame.data ~= nil and frame.data.key ~= nil and frame.data.tiers ~= nil and frame.scripts.OnMouseUp ~= nil
	end)
end
-- The test auction house's gear needs level 20.
PLAYER.level = 20
ButtonNamed("Near level").scripts.OnClick(ButtonNamed("Near level"))
Tick(5)
local shown = rows()
checkTrue("at 20, near level lists the level 20 gear", #shown > 0)
for _, row in ipairs(shown) do
	check("and only what needs a level near 20", row.data.level, 20)
end
PLAYER.level = 12
FireEvent("PLAYER_LEVEL_UP")
Tick(5)
check("at 12 nothing for sale needs a level near it", #rows(), 0)

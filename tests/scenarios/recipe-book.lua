-- The recipes this character knows are read when a profession window opens
-- and kept, so what can be made is known after the window closes.
local ns = Boot()

CRAFTING_RECIPES[101] = { schematic = { name = "Linen Bag", outputItemID = 4238, quantityMin = 1, quantityMax = 1,
	reagentSlotSchematics = {
		{ required = true, quantityRequired = 3, reagents = { { itemID = 2996 } } },
		{ required = true, quantityRequired = 1, reagents = { { itemID = 2320 } } },
		{ required = false, quantityRequired = 1, reagents = { { itemID = 9999 } } },
	} } }
CRAFTING_RECIPES[102] = { schematic = { name = "Bolt of Linen", outputItemID = 2996, quantityMin = 1, quantityMax = 1,
	reagentSlotSchematics = { { required = true, quantityRequired = 2, reagents = { { itemID = 2589 } } } } } }
CRAFTING_RECIPES[103] = { schematic = { name = "Not Learned Yet", outputItemID = 5000 } }
local learned = { [101] = true, [102] = true }
C_TradeSkillUI.GetAllRecipeIDs = function() return { 101, 102, 103 } end
C_TradeSkillUI.GetRecipeInfo = function(id)
	return { name = CRAFTING_RECIPES[id].schematic.name, icon = 1, learned = learned[id] == true,
		relativeDifficulty = id == 101 and 0 or 3, numSkillUps = id == 101 and 2 or 0, canSkillUp = id == 101 }
end
-- As the game answers: the child profession has no id here, the base one does.
C_TradeSkillUI.GetChildProfessionInfo = function() return { professionID = 0, professionName = "", maxSkillLevel = 0 } end
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionID = 197, professionName = "Tailoring", skillLevel = 75, maxSkillLevel = 150 } end
C_TradeSkillUI.IsTradeSkillReady = function() return true end

-- The spellbook's list: two primary slots (one empty here), then secondary.
GetProfessions = function() return 1, nil, nil, 4 end
GetProfessionInfo = function(index)
	if index == 1 then return "Tailoring", 136249 end
	if index == 4 then return "Fishing", 136245 end
end
FireEvent("TRADE_SKILL_SHOW")
FireEvent("TRADE_SKILL_LIST_UPDATE")
check("nothing is read while the list is still arriving", ns.charDb.recipeBook, nil)
Tick(20)
local book = ns.RecipeBook:All().Tailoring
checkTrue("the profession is kept", book ~= nil)
check("with its skill", book.skill, 75)
check("and its icon, from the spellbook", book.icon, 136249)
check("learned recipes only", book.recipes[103], nil)
local bag = book.recipes[101]
check("each recipe knows what it makes", bag.itemID, 4238)
check("and its required materials, optional ones left out", #bag.reagents, 2)
check("with how many of each", bag.reagents[1].count, 3)
check("its skill-up color", bag.difficulty, 0)
check("and the points it gives", bag.skillUps, 2)
check("a recipe that can no longer skill up is gray", book.recipes[102].difficulty, 3)

-- Another player's linked profession is not this character's.
C_TradeSkillUI.IsTradeSkillLinked = function() return true end
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionID = 164, professionName = "Blacksmithing", maxSkillLevel = 150 } end
FireEvent("TRADE_SKILL_SHOW")
Tick(20)
check("a linked profession is not kept", ns.RecipeBook:All().Blacksmithing, nil)
C_TradeSkillUI.IsTradeSkillLinked = nil

-- A child profession is kept under its parent's name.
C_TradeSkillUI.GetChildProfessionInfo = function() return { professionID = 2540, professionName = "Classic Cooking", parentProfessionName = "Cooking", skillLevel = 40, maxSkillLevel = 75 } end
FireEvent("TRADE_SKILL_LIST_UPDATE")
Tick(20)
check("a child profession is kept under its parent's name", ns.RecipeBook:All().Cooking and ns.RecipeBook:All().Cooking.skill, 40)

-- /ah recipes reads now and says how it went.
CHAT = {}
SlashCmdList.AUCTIONHERO("recipes")
checkMatch("the command says what it read", table.concat(CHAT, "\n"), "read Cooking, 2 learned recipes")
checkMatch("and lists the book", table.concat(CHAT, "\n"), "Tailoring: 2 recipes kept")

-- Crafting quotes value the product, account for yield, and keep unknown
-- materials from turning into an invented profit.
local ns = Boot()
local now = GetServerTime()
local function item(id, name, price)
	return { itemID = id, name = name, key = id .. ":" .. name, min = price, units = 20,
		tiers = { { unit = price, units = 20 } } }
end
local product = item(2006, "Tunic of the Bear", 20000)
local ore = item(2001, "Copper Ore", 100)
local cloth = item(2002, "Linen Cloth", 50)
local market = { time = now, items = { product, ore, cloth }, byKey = {} }
for _, entry in ipairs(market.items) do market.byKey[entry.key] = entry end
ns.Analysis = { market = market }
local names = { [2006] = product.name, [2001] = ore.name, [2002] = cloth.name, [9998] = "Unseen Material" }
C_Item.GetItemNameByID = function(id) return names[id] end
local function link(id, name) return "|Hitem:" .. id .. "::::|h[" .. name .. "]|h" end
local schematic = {
	outputItemID = 2006, quantityMin = 2, quantityMax = 2,
	reagentSlotSchematics = {
		{ dataSlotIndex = 1, required = true, quantityRequired = 2, reagents = { { itemID = 2001 } } },
		{ dataSlotIndex = 2, required = true, quantityRequired = 1, reagents = { { itemID = 2002 } } },
		{ dataSlotIndex = 3, required = false, quantityRequired = 1, reagents = { { itemID = 2002 } } },
	},
}
CRAFTING_RECIPES[123] = { schematic = schematic, output = { itemID = 2006, hyperlink = link(2006, product.name) } }

local quote = ns.Crafting:Recipe(123)
check("quote is for the crafted item", quote.quote.price, 20000)
check("a fresh exact scan quote needs no historical estimate", quote.quote.estimated, false)
check("buying the required materials costs 2s 50c", quote.materialsCost, 250)
check("unselected optional materials are excluded", quote.unknownMaterials, 0)
check("two outputs are included in the margin", quote.marginMin, 39750)
product.min = 100
check("a craft that costs more than its output shows a loss", ns.Crafting:Recipe(123).marginMin, -50)
product.min = 20000

local allocations = {
	{ dataSlotIndex = 1, quantity = 2, reagent = { itemID = 2001 } },
	{ dataSlotIndex = 3, quantity = 1, reagent = { itemID = 2002 } },
}
check("selected optional materials are included", ns.Crafting:Recipe(123, allocations).materialsCost, 300)
schematic.quantityMax = 4
quote = ns.Crafting:Recipe(123)
check("variable yield preserves the conservative margin", quote.marginMin, 39750)
check("and shows the upper margin separately", quote.marginMax, 79750)
schematic.quantityMax = 2

schematic.reagentSlotSchematics[2].reagents = { { itemID = 9998 } }
quote = ns.Crafting:Recipe(123)
check("unseen materials are counted", quote.unknownMaterials, 1)
check("known material costs remain available", quote.materialsCost, 200)
check("a missing price never becomes free materials or profit", quote.marginMin, nil)
schematic.reagentSlotSchematics[2].reagents = { { itemID = 2002 }, { itemID = 9998 } }
check("unallocated alternatives remain unknown", ns.Crafting:Recipe(123).unknownMaterials, 1)
allocations[#allocations + 1] = { dataSlotIndex = 2, quantity = 1, reagent = { itemID = 2002 } }
check("an explicit material choice can be valued", ns.Crafting:Recipe(123, allocations).unknownMaterials, 0)
schematic.reagentSlotSchematics[2].reagents = { { itemID = 2002 } }

market.time = now - 3600
quote = ns.Crafting:Recipe(123)
check("an old scan is marked as an estimate", quote.quote.estimated, true)
check("with its actual age", quote.quote.age, 3600)
market.time = now
quote = ns.Crafting:Quote(2006, "Tunic of the Owl")
check("another suffix is explicitly an estimate", quote.estimated, true)
check("identified as a different variant", quote.variants, true)

local store = ns.db.historyByMarket["TestRealm / Alliance"].items
local function history(price, stamp)
	return { n = 1, lo = price, hi = price, h = stamp .. ":" .. price .. ":" .. price .. ":5" }
end
store[product.key] = history(18000, now - 86400)
market.byKey[product.key], market.items = nil, { ore, cloth }
quote = ns.Crafting:Recipe(123)
check("an absent output can use its last observed price", quote.quote.price, 18000)
check("history is always an estimate", quote.quote.estimated, true)
check("history carries its age", quote.quote.age, 86400)
store[product.key] = nil
quote = ns.Crafting:Recipe(123)
check("no data means no made-up estimate", quote.quote, nil)
check("and no made-up margin", quote.marginMin, nil)
market.byKey[product.key], market.items = product, { product, ore, cloth }

-- Hovering a profession recipe shows its output prices next to that row.
local function has(label)
	for _, text in ipairs(TIP) do
		text = strip(text)
		if text:sub(1, #label + 2) == label .. ": " then return text end
	end
end
EventRegistry:TriggerEvent("Professions.RecipeListOnEnter", CreateFrame("Button"), { recipeInfo = { recipeID = 123, learned = false } })
checkMatch("unlearned recipe rows also show the output", has("Makes"), "Tunic of the Bear.*x2")
checkMatch("with a flat per-item price", has("Going rate (each)"), "2g 0s 0c")
checkMatch("and the one-craft material total", has("Est. materials / craft"), "2s 50c")
checkMatch("margin is explicitly before fees", has("Est. margin before fees"), "+3g 97s 50c")
local count = #TIP
ns.RecipeTooltip.OnRecipe(GameTooltip, 123)
check("one recipe block per tooltip population", #TIP, count)
GameTooltip:SetRecipeResultItem(123)
check("reusing a tooltip clears the marker before rebuilding", #TIP, count)

-- Missing materials stay visibly incomplete in the tooltip.
schematic.reagentSlotSchematics[2].reagents = { { itemID = 9998 } }
GameTooltip:SetRecipeResultItem(123)
checkMatch("known cost is only a lower bound", has("Est. materials / craft"), "At least 2s 0c %(1 unpriced%)")
check("unknown costs never produce a green profit claim", has("Est. margin before fees"), "Est. margin before fees: Unknown")
schematic.reagentSlotSchematics[2].reagents = { { itemID = 2002 } }

-- A recipe item's own asking price is separate from its embedded output.
local instant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id)
	if id == 9000 then return id, "Recipe", "Blacksmithing", "", 1, 9, 4 end
	return instant(id)
end
store["9000:Plans: Tunic of the Bear"] = history(4000, now)
RecipeProductTipTextLeft1 = { GetText = function() return "Plans: Tunic of the Bear" end }
local tip = { lines = {} }
function tip:GetName() return "RecipeProductTip" end
function tip:GetItem() return product.name, link(2006, product.name) end
function tip:AddLine(text) self.lines[#self.lines + 1] = strip(text) end
function tip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. ": " .. strip(right) end
ns.ItemTooltip.OnItem(tip, { id = 9000 })
local own, made
for _, text in ipairs(tip.lines) do
	if text:find("^Lowest: ") then own = text end
	if text:find("^Going rate %(each%): ") then made = text end
end
checkMatch("the recipe still quotes its own price", own, "40s 0c")
checkMatch("the product gets a separately labeled price", made, "2g 0s 0c")

-- Historical and missing output prices are labeled in the rendered tooltip.
market.byKey[product.key], market.items = nil, { ore, cloth }
store[product.key] = history(18000, now - 86400)
GameTooltip:SetRecipeResultItem(123)
checkMatch("historical output is labeled Est.", has("Est. going rate (each)"), "1g 80s 0c.*1d 0h ago")
store[product.key] = nil
GameTooltip:SetRecipeResultItem(123)
check("unseen output stays explicitly unknown", has("Going rate (each)"), "Going rate (each): Unknown")

ns.db.switches.itemTooltips = false
GameTooltip:SetRecipeResultItem(123)
check("the existing tooltip switch disables crafting prices", #TIP, 1)
ns.db.switches.itemTooltips = true
MOCK.recipeAPIFails = true
check("unavailable profession data does not break a tooltip", ns.Crafting:Recipe(123), nil)

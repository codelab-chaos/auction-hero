-- Crafted outputs in tooltips, both on profession rows and on recipe items.
-- Recipe-item prices remain separate from the prices of what they make.
local _, ns = ...
local L, C = ns.L, ns.Theme.color
local RecipeTooltip = {}
ns.RecipeTooltip = RecipeTooltip

local function Enabled()
	return ns.db and ns.IsEnabled("itemTooltips")
end

local function Signed(value)
	return (value < 0 and "-" or "+") .. ns.Money(math.abs(value))
end

local function Append(tooltip, result)
	if not Enabled() or not result or tooltip.auctionHeroRecipeAdded then return false end
	tooltip.auctionHeroRecipeAdded = true
	tooltip:AddLine(" ")
	if not tooltip.auctionHeroAdded then
		tooltip:AddLine(L.TITLE, C.accent[1], C.accent[2], C.accent[3])
	end
	tooltip:AddLine(L.RECIPE_HEADING, C.accent[1], C.accent[2], C.accent[3])
	local function Line(label, text, color)
		color = color or C.text
		tooltip:AddDoubleLine(label, text, C.muted[1], C.muted[2], C.muted[3], color[1], color[2], color[3])
	end
	local name = result.link or result.name or L.RECIPE_ITEM_UNKNOWN:format(result.itemID)
	local low, high = result.quantityMin, result.quantityMax
	if low and high and low > 0 then
		name = (low == high and L.RECIPE_YIELD or L.RECIPE_YIELD_RANGE):format(name, low, high)
	end
	Line(L.RECIPE_MAKES, name)
	local quote = result.quote
	local label = quote and (quote.variants and L.RECIPE_RATE_VARIANTS or quote.estimated and L.RECIPE_RATE_EST) or L.RECIPE_RATE
	local price = quote and ns.Money(quote.price) or L.RECIPE_UNKNOWN
	if quote and quote.age then
		price = L.RECIPE_QUOTE_AGE:format(price, ns.Ago(quote.age))
	end
	Line(label or L.RECIPE_RATE, price, quote and C.text or C.muted)
	if result.unknownMaterials ~= nil then
		local cost = ns.Money(result.materialsCost)
		if result.unknownMaterials > 0 then
			cost = result.materialsCost > 0 and L.RECIPE_MATS_PARTIAL:format(cost, result.unknownMaterials) or L.RECIPE_UNKNOWN
		end
		Line(L.RECIPE_MATS, cost)
		local margin, color = L.RECIPE_UNKNOWN, C.muted
		if result.marginMin ~= nil then
			margin = Signed(result.marginMin)
			if result.marginMax ~= result.marginMin then
				margin = L.RECIPE_MARGIN_RANGE:format(margin, Signed(result.marginMax))
			end
			color = result.marginMin > 0 and C.good or result.marginMax < 0 and C.bad or C.accent
		end
		Line(L.RECIPE_MARGIN, margin, color)
	end
	tooltip:AddLine(L.RECIPE_PRICE_NOTE, C.muted[1], C.muted[2], C.muted[3], true)
	return true
end

function RecipeTooltip.OnRecipe(tooltip, recipeID, reagents, allocationGUID, recipeLevel, qualityID)
	if not Enabled() or tooltip.auctionHeroRecipeAdded then return end
	local result = ns.Crafting:Recipe(recipeID, reagents, allocationGUID, recipeLevel, qualityID)
	if Append(tooltip, result) and tooltip.Show then tooltip:Show() end
end

function RecipeTooltip.OnItem(tooltip, data)
	if not Enabled() or tooltip.auctionHeroRecipeAdded or not tooltip.GetItem then return end
	local name, link = tooltip:GetItem()
	local shownID = link and tonumber(link:match("item:(%d+)"))
	local itemID = data and data.id or shownID
	if not itemID or not C_Item or not C_Item.GetItemInfoInstant then return end
	local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
	local recipeClass = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
	if not ok or classID ~= recipeClass then return end
	-- Modern recipe tooltips may expose the embedded product as GetItem().
	-- It is useful here only under an explicit crafted-output heading.
	if shownID and shownID ~= itemID then
		Append(tooltip, { itemID = shownID, name = name, link = link, quote = ns.Crafting:Quote(shownID, name) })
		return
	end
	-- Some clients expose a crafting spell directly on the recipe item.
	-- A learning spell that cannot resolve to a product is left alone.
	local getSpell = C_Item.GetItemSpell or GetItemSpell
	if getSpell then
		local success, _, spellID = pcall(getSpell, itemID)
		if success and spellID then RecipeTooltip.OnRecipe(tooltip, spellID) end
	end
end

for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
	if tooltip and type(tooltip.SetRecipeResultItem) == "function" then
		hooksecurefunc(tooltip, "SetRecipeResultItem", RecipeTooltip.OnRecipe)
	end
end

-- This event is emitted by Forever's recipe rows, including unlearned ones.
-- Show the native result tooltip next to the row, then append our prices.
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("Professions.RecipeListOnEnter", function(_, button, data)
		if not Enabled() then return end
		local info = data and data.recipeInfo
		if not info or not info.recipeID then return end
		if Professions and Professions.GetHighestLearnedRecipe then
			info = Professions.GetHighestLearnedRecipe(info) or info
		end
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetRecipeResultItem(info.recipeID, nil, nil, info.unlockedRecipeLevel)
		RecipeTooltip.OnRecipe(GameTooltip, info.recipeID, nil, nil, info.unlockedRecipeLevel)
		GameTooltip:Show()
	end, RecipeTooltip)
end

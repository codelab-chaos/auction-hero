-- Craft plan: what each recipe in the recipe book is worth making today.
-- For every recipe: what it sells for (the market's asking price of what it
-- makes), what its materials cost to buy, the profit between them, how many
-- the bags and bank already hold the materials for, and what is left to buy
-- for one craft. Prices are quotes from the scan (market\crafting.lua),
-- never a promise of a sale.
--
-- A row: recipeID, profession, name, icon, itemID, itemName, quality,
--   units (made per craft, the average when it varies),
--   sale (per craft), saleEstimated, cost (materials, per craft),
--   unpriced (materials with no price), canMake, toBuy,
--   profit     the cash a craft brings in: the sale less what is left to buy.
--              Materials already held (skinned, gathered, bought before)
--              count as free.
--   vsMats     the sale less the market value of every material: when it is
--              below zero, selling the materials beats crafting with them.
--   difficulty, skillUps   from the recipe book (see market\recipe-book.lua)
--   pointCost  for a sure skill-up that loses against selling the raw goods:
--              what each skill point costs
--   verdict    the first of ns.CraftVerdicts that holds
--   reagents = { { itemID, name, count, have, price } }
local _, ns = ...
local CraftPlan = {}
ns.CraftPlan = CraftPlan

local function Held(itemID)
	-- The bank is counted too: the game keeps its count once it was opened.
	return ns.ItemCount(itemID, true)
end

local function Row(profession, recipeID, recipe)
	local crafting = ns.Crafting
	local itemName = recipe.itemID and crafting:ItemName(recipe.itemID)
	local quote = recipe.itemID and crafting:Quote(recipe.itemID, itemName)
	local low, high = recipe.quantityMin or 1, recipe.quantityMax or recipe.quantityMin or 1
	local units = (math.max(1, low) + math.max(1, high)) / 2
	local row = {
		recipeID = recipeID,
		profession = profession,
		name = recipe.name or itemName or ("#" .. recipeID),
		icon = recipe.icon,
		itemID = recipe.itemID,
		itemName = itemName,
		units = units,
		sale = quote and math.floor(quote.price * units),
		saleEstimated = quote and quote.estimated,
		cost = 0,
		unpriced = 0,
		toBuy = 0,
		reagents = {},
	}
	local canMake
	for _, reagent in ipairs(recipe.reagents or {}) do
		local name = crafting:ItemName(reagent.itemID)
		local price = crafting:Quote(reagent.itemID, name)
		local have = Held(reagent.itemID)
		row.reagents[#row.reagents + 1] = { itemID = reagent.itemID, name = name, count = reagent.count, have = have, price = price and price.price }
		local enough = math.floor(have / reagent.count)
		canMake = canMake and math.min(canMake, enough) or enough
		local short = math.max(0, reagent.count - have)
		if price then
			row.cost = row.cost + price.price * reagent.count
			row.toBuy = row.toBuy + price.price * short
		else
			row.unpriced = row.unpriced + 1
			-- Short of a material with no price: what is left to buy is unknown.
			row.toBuyUnknown = row.toBuyUnknown or short > 0
		end
	end
	if row.toBuyUnknown then
		row.toBuy = nil
	end
	row.canMake = canMake or 0
	if row.sale and row.toBuy then
		row.profit = row.sale - row.toBuy
	end
	if row.sale and row.unpriced == 0 then
		row.vsMats = row.sale - row.cost
	end
	row.difficulty, row.skillUps = recipe.difficulty, recipe.skillUps
	local look = recipe.difficulty and ns.CraftDifficulty[recipe.difficulty]
	if look and look.sure and row.vsMats and row.vsMats < 0 then
		row.pointCost = math.floor(-row.vsMats / math.max(1, row.skillUps or 1))
	end
	for _, verdict in ipairs(ns.CraftVerdicts) do
		if verdict.when(row) then
			row.verdict = verdict
			break
		end
	end
	return row
end

-- Every recipe that makes an item, from every profession in the book, or
-- from one when a name is given.
function CraftPlan:Rows(profession)
	local rows = {}
	for name, book in pairs(ns.RecipeBook:All()) do
		if not profession or profession == name then
			for recipeID, recipe in pairs(book.recipes or {}) do
				if recipe.itemID then
					rows[#rows + 1] = Row(name, recipeID, recipe)
				end
			end
		end
	end
	return rows
end

-- The professions in the book that make items, sorted, for the filters.
function CraftPlan:Professions()
	local names = {}
	for name, book in pairs(ns.RecipeBook:All()) do
		for _, recipe in pairs(book.recipes or {}) do
			if recipe.itemID then
				names[#names + 1] = name
				break
			end
		end
	end
	table.sort(names)
	return names
end

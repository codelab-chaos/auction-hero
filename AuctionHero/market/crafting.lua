-- Recipe output prices and the cost of buying its materials. All quotes are
-- asking prices from this character's market, never a promise of a sale.
local _, ns = ...
local Crafting = {}
ns.Crafting = Crafting

local function Read(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	return ok and value or nil
end

local requested = {}
function Crafting:ItemName(itemID, link)
	local name = link and link:match("|h%[(.-)%]|h")
	if name then return name end
	name = C_Item and Read(C_Item.GetItemNameByID, itemID)
	if not name and C_Item then
		name = Read(C_Item.GetItemInfo or GetItemInfo, itemID)
	end
	if not name and not requested[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
		requested[itemID] = true
		Read(C_Item.RequestLoadItemDataByID, itemID)
	end
	return name
end

local function Quote(price, time, name, estimated, variants)
	if not price or price <= 0 then return nil end
	local age = time and math.max(0, GetServerTime() - time)
	return {
		price = price, name = name, age = age, variants = variants,
		estimated = estimated or age == nil or age > ns.RecipePriceRule.freshSeconds,
	}
end

function Crafting:Quote(itemID, name)
	if not itemID then return nil end
	local market = ns.Analysis and ns.Analysis.market
	local key = name and (itemID .. ":" .. name)
	local live = market and key and market.byKey[key]
	if live and live.units > 0 and live.min then
		return Quote(live.min, market.time, live.name, false)
	end
	-- Prefer a historical quote for this exact item over a different suffix.
	if key then
		local points = ns.History:Points(key)
		local last = points[#points]
		if last then return Quote(last.low, last.time, name, true) end
	end
	-- An uncached name or random-suffix output can still have an estimate,
	-- explicitly identified as a quote from other variants of that item ID.
	local lowest, count
	for _, item in ipairs(market and market.items or {}) do
		if item.itemID == itemID and item.units > 0 and item.min and item.min > 0 then
			count = (count or 0) + 1
			if not lowest or item.min < lowest.min then lowest = item end
		end
	end
	if lowest then
		local variants = (name and name ~= lowest.name) or count > 1
		return Quote(lowest.min, market.time, lowest.name, variants, variants)
	end
end

-- Reagents passed by the profession window describe the player's actual
-- allocations. Unselected optional reagents do not count toward a craft.
function Crafting:Recipe(recipeID, reagents, allocationGUID, recipeLevel, qualityID)
	if not C_TradeSkillUI then return nil end
	local schematic = Read(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
	local output = Read(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, reagents, allocationGUID, qualityID)
	local link = output and output.hyperlink
	local itemID = output and output.itemID
	if not itemID or itemID <= 0 then itemID = link and tonumber(link:match("item:(%d+)")) end
	if not itemID or itemID <= 0 then itemID = schematic and schematic.outputItemID end
	if not itemID or itemID <= 0 then return nil end
	local name = self:ItemName(itemID, link)
	local result = {
		itemID = itemID, name = name, link = link, quote = self:Quote(itemID, name),
		quantityMin = schematic and schematic.quantityMin,
		quantityMax = schematic and schematic.quantityMax,
		materialsCost = 0, unknownMaterials = 0,
	}
	local selected = {}
	for _, allocation in ipairs(reagents or {}) do
		local slot = allocation.dataSlotIndex
		if slot then
			selected[slot] = selected[slot] or {}
			selected[slot][#selected[slot] + 1] = allocation
		end
	end
	local function AddMaterial(reagent, quantity)
		if quantity <= 0 then return end
		local id = reagent and reagent.itemID
		local quote = id and self:Quote(id, self:ItemName(id))
		if quote then
			result.materialsCost = result.materialsCost + quote.price * quantity
		else
			result.unknownMaterials = result.unknownMaterials + 1
		end
	end
	if not schematic or not schematic.reagentSlotSchematics then
		result.unknownMaterials = 1
	else
		for _, slot in ipairs(schematic.reagentSlotSchematics) do
			local allocations = selected[slot.dataSlotIndex]
			if allocations and #allocations > 0 then
				local allocated = 0
				for _, allocation in ipairs(allocations) do
					local quantity = math.max(0, allocation.quantity or 0)
					allocated = allocated + quantity
					AddMaterial(allocation.reagent, quantity)
				end
				if slot.required ~= false and allocated < (slot.quantityRequired or 0) then
					result.unknownMaterials = result.unknownMaterials + 1
				end
			elseif slot.required ~= false and (slot.quantityRequired or 0) > 0 then
				-- Several alternatives need an allocation before their cost can
				-- be quoted. Do not silently pick a different material/quality.
				local choices = slot.reagents or {}
				AddMaterial(#choices == 1 and choices[1] or nil, slot.quantityRequired)
			end
		end
	end
	local low, high = result.quantityMin, result.quantityMax
	if result.quote and result.unknownMaterials == 0 and low and high and low > 0 and high >= low then
		result.marginMin = math.floor(result.quote.price * low - result.materialsCost)
		result.marginMax = math.floor(result.quote.price * high - result.materialsCost)
	end
	return result
end

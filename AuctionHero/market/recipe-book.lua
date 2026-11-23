-- Recipe book: the recipes this character knows, by profession, read from
-- the game while a profession window is open (the only time it lists them)
-- and kept in the character's saved data, so what can be made is known when
-- the window is closed.
--
-- charDb.recipeBook[professionName] = {
--   readAt, skill, maxSkill, icon (the profession's, from the spellbook),
--   recipes = { [recipeID] = { name, icon, itemID, quantityMin, quantityMax,
--                              difficulty, skillUps,
--                              reagents = { { itemID, count } } } },
-- difficulty is the game's skill-up color as of the read (0 orange, 1 yellow,
-- 2 green, 3 gray: Enum.TradeskillRelativeDifficulty); skillUps the points an
-- orange craft gives. Both change as the skill rises, and are read again each
-- time the window opens.
-- }
-- A reagent slot with several choices keeps its first; optional slots are
-- left out, since a craft does not need them.
local _, ns = ...
local Bus = ns.Bus
local Rule = ns.RecipeBookRule

local RecipeBook = {}
ns.RecipeBook = RecipeBook

local function Read(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
end

function RecipeBook:All()
	return ns.charDb and ns.charDb.recipeBook or {}
end

-- What the game says about the open window, the way the game's own
-- profession window reads it (Professions.GetProfessionInfo in
-- Blizzard_Professions.lua): the child profession, or the base one when the
-- child has no id, named by its parent ("Tailoring", not an expansion tier).
local function Probe()
	local api = C_TradeSkillUI
	local info = Read(api.GetChildProfessionInfo)
	if not info or not info.professionID or info.professionID == 0 then
		info = Read(api.GetBaseProfessionInfo)
	end
	return {
		notMine = Read(api.IsTradeSkillLinked) or Read(api.IsTradeSkillGuild) or Read(api.IsTradeSkillGuildMember)
			or Read(api.IsNPCCrafting) or Read(api.IsRuneforging),
		ready = Read(api.IsTradeSkillReady),
		info = info,
	}
end

-- The open window's profession, or nil and why: another player's, a
-- guild's or an NPC's recipes are not this character's.
local function OpenProfession()
	local api = C_TradeSkillUI
	if not api then
		return nil, "no C_TradeSkillUI"
	end
	local probe = Probe()
	local info = probe.info
	if probe.notMine then
		return nil, "not yours", probe
	end
	if probe.ready == false then
		return nil, "not ready", probe
	end
	if not info or not info.professionID or info.professionID == 0 or (info.maxSkillLevel or 0) == 0 then
		return nil, "no profession", probe
	end
	local name = info.parentProfessionName or info.professionName
	if not name or name == "" then
		return nil, "no profession name", probe
	end
	return { professionName = name, skillLevel = info.skillLevel, maxSkillLevel = info.maxSkillLevel }, nil, probe
end

local function ReadRecipe(recipeID)
	local api = C_TradeSkillUI
	local info = Read(api.GetRecipeInfo, recipeID)
	if not info or info.learned == false then
		return nil
	end
	local schematic = Read(api.GetRecipeSchematic, recipeID, false)
	if not schematic then
		return nil
	end
	local reagents = {}
	for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
		local first = slot.reagents and slot.reagents[1]
		local needed = slot.quantityRequired or 0
		if slot.required ~= false and first and first.itemID and needed > 0 then
			reagents[#reagents + 1] = { itemID = first.itemID, count = needed }
		end
	end
	local itemID = schematic.outputItemID
	if not itemID or itemID <= 0 then
		local output = Read(api.GetRecipeOutputItemData, recipeID)
		itemID = output and output.itemID
	end
	return {
		name = info.name or schematic.name,
		icon = info.icon,
		itemID = itemID and itemID > 0 and itemID or nil,
		quantityMin = schematic.quantityMin,
		quantityMax = schematic.quantityMax,
		difficulty = info.canSkillUp ~= false and info.relativeDifficulty or 3,
		skillUps = info.numSkillUps,
		reagents = reagents,
	}
end

-- A profession's icon, as the spellbook shows it: GetProfessions lists the
-- character's professions by index and GetProfessionInfo names each one.
local function ProfessionIcon(name)
	if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
		return nil
	end
	-- Up to six slots (two primary, then secondary ones), any of them nil.
	local indexes = { pcall(GetProfessions) }
	if not table.remove(indexes, 1) then
		return nil
	end
	for index = 1, 10 do
		local slot = indexes[index]
		if slot then
			local ok, slotName, texture = pcall(GetProfessionInfo, slot)
			if ok and slotName == name then
				return texture
			end
		end
	end
end

-- A profession's icon: the one kept with its recipes, or the spellbook's
-- for a book read before icons were kept.
function RecipeBook:Icon(name)
	local book = self:All()[name]
	return book and book.icon or ProfessionIcon(name)
end

local lastWhy -- the last reason a read did not happen, so it is logged once

-- Reads the open profession's learned recipes into the book.
function RecipeBook:Read()
	local profession, why, probe = OpenProfession()
	local ids = profession and Read(C_TradeSkillUI.GetAllRecipeIDs)
	if not ids or #ids == 0 then
		why = why or "no recipes listed"
		-- Said once per reason, not on every list update.
		if why ~= lastWhy then
			lastWhy = why
			ns.EventLog:Note("recipe book not read", why, probe)
		end
		return false, why, probe
	end
	lastWhy = nil
	local recipes, count, made = {}, 0, 0
	for _, recipeID in ipairs(ids) do
		local recipe = ReadRecipe(recipeID)
		if recipe then
			recipes[recipeID] = recipe
			count = count + 1
			if recipe.itemID then
				made = made + 1
			end
		end
	end
	ns.charDb.recipeBook = ns.charDb.recipeBook or {}
	ns.charDb.recipeBook[profession.professionName] = {
		readAt = GetServerTime(),
		skill = profession.skillLevel,
		maxSkill = profession.maxSkillLevel,
		icon = ProfessionIcon(profession.professionName),
		recipes = recipes,
	}
	ns.EventLog:Note("recipe book read", profession.professionName, #ids .. " listed", count .. " learned", made .. " make an item")
	Bus:Fire("RECIPE_BOOK_CHANGED", profession.professionName)
	return true, profession.professionName, count
end

-- Reads, and any error goes in the log instead of stopping the read silently.
function RecipeBook:SafeRead()
	local ok, done, detail, extra = pcall(self.Read, self)
	if not ok then
		ns.EventLog:Note("recipe book error", done)
		return false, tostring(done)
	end
	return done, detail, extra
end

-- The list fills in over several events as the window opens: read once it
-- has been quiet for a moment.
local pending = false
local function Schedule()
	if pending then
		return
	end
	pending = true
	C_Timer.After(Rule.quietSeconds, function()
		pending = false
		RecipeBook:SafeRead()
	end)
end

local watcher = CreateFrame("Frame")
for _, event in ipairs(Rule.events) do
	pcall(watcher.RegisterEvent, watcher, event)
end
watcher:SetScript("OnEvent", Schedule)

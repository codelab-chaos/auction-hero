-- Craft tab: what your professions can make, and what it is worth. One row
-- per recipe in the recipe book (market\recipe-book.lua), priced by the craft
-- plan (market\craft-plan.lua): sells for, materials, profit, how many your
-- bags and bank hold the materials for, and what is left to buy.
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local ALL = "all"
local state = { profession = ALL, ready = false, filter = nil, sort = { id = "verdict", descending = false } }
local list, summary, professionBar, readyBox, filterBar
local bar
local FilterById

local SORT_VALUES = {
	name = function(row) return row.name end,
	profession = function(row) return row.profession end,
	sale = function(row) return row.sale end,
	cost = function(row) return row.unpriced == 0 and row.cost or nil end,
	profit = function(row) return row.profit end,
	vsMats = function(row) return row.vsMats end,
	-- In the order of ns.CraftVerdicts (make first), then the cheapest point,
	-- then the most profit.
	verdict = function(row)
		local rank = 0
		for index, verdict in ipairs(ns.CraftVerdicts) do
			if verdict == row.verdict then
				rank = index
			end
		end
		return rank * 1e9 + (row.pointCost or 0) - math.min(row.profit or 0, 1e8) / 1e3
	end,
	canMake = function(row) return row.canMake end,
	toBuy = function(row) return row.toBuy end,
}

local function Signed(copper)
	if copper < 0 then
		return "-" .. ns.Money(-copper)
	end
	return ns.Money(copper)
end

-- The materials, one line each, for the row's tooltip.
local function Tip(row)
	local lines = { row.name }
	for _, reagent in ipairs(row.reagents) do
		local price = reagent.price and L.CRAFT_TIP_EACH:format(ns.Money(reagent.price)) or L.CRAFT_TIP_NO_PRICE
		local color = reagent.have >= reagent.count and "|cff4fd16b" or "|cffd0d0d0"
		lines[#lines + 1] = color .. L.CRAFT_TIP_REAGENT:format(reagent.count, reagent.name or ("#" .. reagent.itemID), reagent.have, price) .. "|r"
	end
	if row.saleEstimated then
		lines[#lines + 1] = L.CRAFT_TIP_ESTIMATED
	end
	if row.verdict then
		local label = row.verdict.id == "level"
			and row.verdict.label:format(row.pointCost and ns.PlainMoney(row.pointCost) or L.CRAFT_POINT_FREE)
			or row.verdict.label
		table.insert(lines, 2, L.CRAFT_TIP_VERDICT:format(label) .. " (" .. row.profession .. ")")
	end
	lines[#lines + 1] = " "
	if row.sale and row.vsMats then
		lines[#lines + 1] = L.CRAFT_TIP_MATH:format(ns.Money(row.sale), ns.Money(row.cost))
		if row.vsMats >= 0 then
			lines[#lines + 1] = L.CRAFT_TIP_MAKE_WINS:format(ns.Money(row.vsMats))
		else
			lines[#lines + 1] = L.CRAFT_TIP_SELL_WINS:format(ns.Money(-row.vsMats))
		end
	end
	if row.pointCost then
		lines[#lines + 1] = L.CRAFT_TIP_POINT_COST:format(ns.Money(row.pointCost))
	end
	lines[#lines + 1] = L.CRAFT_TIP_PROFIT
	return lines
end

function FilterById(id)
	for _, filter in ipairs(ns.CraftFilters) do
		if filter.id == id then
			return filter
		end
	end
end

-- The profession filter: All, then each profession in the book. Rebuilt
-- when the book gains one.
local shownProfessions
local function PaintProfessions()
	local names = ns.CraftPlan:Professions()
	local key = table.concat(names, ",")
	if key ~= shownProfessions then
		shownProfessions = key
		if professionBar then
			professionBar:Hide()
		end
		local items = { { id = ALL, label = L.CRAFT_ALL } }
		local books = ns.RecipeBook:All()
		for _, name in ipairs(names) do
			local book = books[name]
			local count = 0
			for _ in pairs(book.recipes or {}) do
				count = count + 1
			end
			-- Its icon, with its name and skill in the tooltip; the name
			-- alone when the icon is not known yet.
			items[#items + 1] = {
				id = name,
				label = name,
				icon = ns.RecipeBook:Icon(name),
				tip = L.CRAFT_PROFESSION_TIP:format(book.skill or 0, book.maxSkill or 0, count),
			}
		end
		professionBar = Kit.Choices(bar, {
			items = items,
			padding = 14,
			height = 28,
			isActive = function(item)
				return item.id == state.profession
			end,
			onPick = function(item)
				state.profession = item.id
				ns.Window:RefreshActive()
			end,
		})
		professionBar:SetPoint("LEFT", 8, 0)
		filterBar:ClearAllPoints()
		filterBar:SetPoint("LEFT", professionBar, "RIGHT", 16, 0)
	end
	professionBar:Refresh()
end

local function Refresh()
	PaintProfessions()
	filterBar:Refresh()
	readyBox:SetActive(state.ready)
	local rows = {}
	for _, row in ipairs(ns.CraftPlan:Rows(state.profession ~= ALL and state.profession or nil)) do
		local filter = state.filter and FilterById(state.filter)
		local shown = not filter or (row.verdict and filter.verdicts[row.verdict.id])
		if shown and (not state.ready or row.canMake > 0) then
			rows[#rows + 1] = row
		end
	end
	Kit.SortRows(rows, SORT_VALUES[state.sort.id], state.sort.descending)
	list:SetSort(state.sort.id, state.sort.descending)
	if not next(ns.RecipeBook:All()) then
		list:SetEmptyText(L.CRAFT_EMPTY_BOOK)
	elseif state.ready then
		list:SetEmptyText(L.CRAFT_EMPTY_READY)
	else
		list:SetEmptyText(L.CRAFT_EMPTY)
	end
	list:SetRows(rows, true)
	summary:SetText(ns.Window:Market() and L.CRAFT_SUMMARY or L.CRAFT_NO_SCAN)
end

local function Create(parent)
	bar = Kit.Panel(parent)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(36)
	readyBox = Kit.Button(bar, { text = L.CRAFT_READY, padding = 14, tip = { L.CRAFT_READY, L.CRAFT_READY_TIP }, onClick = function()
		state.ready = not state.ready
		ns.Window:RefreshActive()
	end })
	-- Worth it, Level Up, Sell raw: one at a time, pressed again to clear.
	filterBar = Kit.Choices(bar, {
		items = ns.CraftFilters,
		padding = 14,
		isActive = function(filter)
			return filter.id == state.filter
		end,
		onPick = function(filter)
			state.filter = state.filter ~= filter.id and filter.id or nil
			ns.Window:RefreshActive()
		end,
	})
	readyBox:SetPoint("LEFT", filterBar, "RIGHT", 16, 0)
	summary = Kit.Text(bar, "small", C.muted, "RIGHT")
	summary:SetPoint("RIGHT", -10, 0)

	list = Kit.List(parent, {
		id = "craft",
		columns = {
			{ id = "name", label = L.CRAFT_COL_RECIPE, flex = true,
				icon = function(row) return row.icon end,
				text = function(row) return row.name end,
				-- In its skill-up color, as the profession window shows it.
				color = function(row)
					local look = row.difficulty and ns.CraftDifficulty[row.difficulty]
					return look and look.color or C.text
				end },
			{ id = "verdict", label = L.CRAFT_COL_VERDICT, width = 96, align = "CENTER",
				text = function(row)
					local verdict = row.verdict
					if not verdict then
						return ""
					end
					if verdict.id == "level" then
						return verdict.mark:format(row.pointCost and ns.PlainMoney(row.pointCost) or L.CRAFT_POINT_FREE)
					end
					return verdict.mark
				end,
				color = function(row) return row.verdict and row.verdict.color or C.muted end },
			-- The profession as its icon; its name is on the filter's tooltip.
			{ id = "profession", label = L.CRAFT_COL_PROF, width = 52, align = "CENTER",
				icon = function(row) return ns.RecipeBook:Icon(row.profession) end },
			{ id = "sale", label = L.CRAFT_COL_SALE, width = 100, align = "RIGHT", text = function(row)
				return row.sale and ((row.saleEstimated and "~" or "") .. ns.Money(row.sale)) or L.CRAFT_NO_PRICE
			end },
			{ id = "cost", label = L.CRAFT_COL_COST, width = 100, align = "RIGHT", text = function(row)
				if row.unpriced > 0 then
					return L.CRAFT_NO_PRICE
				end
				return ns.Money(row.cost)
			end },
			{ id = "profit", label = L.CRAFT_COL_PROFIT, width = 100, align = "RIGHT",
				text = function(row) return row.profit and Signed(row.profit) or "" end,
				color = function(row) return row.profit and (row.profit > 0 and C.good or C.bad) or C.muted end },
			{ id = "vsMats", label = L.CRAFT_COL_VS_MATS, width = 110, align = "RIGHT",
				text = function(row) return row.vsMats and Signed(row.vsMats) or "" end,
				color = function(row) return row.vsMats and (row.vsMats > 0 and C.good or C.bad) or C.muted end },
			{ id = "canMake", label = L.CRAFT_COL_CAN_MAKE, width = 66, align = "RIGHT",
				text = function(row) return row.canMake > 0 and ns.Comma(row.canMake) or "" end,
				color = function() return C.good end },
			{ id = "toBuy", label = L.CRAFT_COL_TO_BUY, width = 100, align = "RIGHT", text = function(row)
				if row.toBuy == nil then
					return L.CRAFT_NO_PRICE
				end
				return row.toBuy == 0 and L.CRAFT_HAVE_ALL or ns.Money(row.toBuy)
			end },
		},
		tip = Tip,
		link = function(row)
			return row.itemID and ("item:" .. row.itemID) or nil
		end,
		onSort = function(id)
			if state.sort.id == id then
				state.sort.descending = not state.sort.descending
			else
				state.sort = { id = id, descending = id ~= "name" and id ~= "profession" and id ~= "verdict" }
			end
			ns.Window:RefreshActive()
		end,
	})
	-- Verdicts are read from asking prices, not sales: a light word to say so.
	local look = ns.CraftDisclaimerLook
	local disclaimer = CreateFrame("Frame", nil, parent)
	disclaimer:SetPoint("BOTTOMRIGHT", -4, 0)
	disclaimer:SetHeight(look.iconSize)
	local words = Kit.Text(disclaimer, "normal", C.gold, "RIGHT")
	local font, size = words:GetFont()
	if font then
		words:SetFont(font, size, look.outline) -- bold, as far as the game's fonts go
	end
	words:SetPoint("RIGHT")
	words:SetText(L.CRAFT_DISCLAIMER)
	local goblin = disclaimer:CreateTexture(nil, "ARTWORK")
	goblin:SetSize(look.iconSize, look.iconSize)
	goblin:SetTexture(look.icon)
	goblin:SetPoint("RIGHT", words, "LEFT", -6, 0)
	disclaimer:SetWidth((words:GetStringWidth() or 240) + look.iconSize + 8)
	disclaimer:EnableMouse(true)
	Kit.Tip(disclaimer, { L.CRAFT_DISCLAIMER, L.CRAFT_DISCLAIMER_TIP })

	list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
	list:SetPoint("BOTTOMRIGHT", 0, ns.CraftDisclaimerLook.iconSize + 4)
	return { Refresh = Refresh }
end

ns.Window:RegisterTab({ id = "craft", label = L.TAB_CRAFT, order = 3.5, Create = Create })

ns.Bus:On("RECIPE_BOOK_CHANGED", function()
	if list and ns.charDb.tab == "craft" then
		ns.Window:RequestRefresh()
	end
end)

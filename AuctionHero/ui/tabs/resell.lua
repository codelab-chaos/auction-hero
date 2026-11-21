-- Resell tab: a short list of things worth buying to sell again, and for the
-- one you pick, the whole plan: what to buy, what to relist it at, and what is
-- left after the auction house's cut.
-- The layout and behavior follow the lab's concept (lab/src/ui/concept/resell.ts).
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local PLAN_LINES = 5 -- price points listed at the bottom of the plan

local state = {
	margin = ns.ResellDefaultMargin,
	maxItems = ns.ResellMaxItems,
	minProfit = ns.ResellDefaultMinProfit,
	affordOnly = false,
	topOnly = false,
	sort = { id = "profit", descending = true },
	selectedKey = nil,
	limit = nil, -- auctions (or units) to buy. nil means everything worth buying
}

local list, plan, prompt, margins, maxInput, affordButton, topButton, profitInput
local parts = {}
local stack
local leads = {} -- the last list of leads worked out
local Refresh, PaintPlan

local function Params()
	return {
		marginPercent = state.margin,
		budget = state.affordOnly and GetMoney() or 0,
		minProfit = state.minProfit,
		maxItems = state.maxItems,
	}
end

local function SelectedLead()
	for _, lead in ipairs(leads) do
		if lead.item.key == state.selectedKey then
			return lead
		end
	end
end

-- ========= The list =========================================================
local SORT_VALUES = {
	name = function(lead)
		return lead.item.name
	end,
	deal = function(lead)
		return lead.deal.level.pips
	end,
	forSale = function(lead)
		return lead.item.units
	end,
	units = function(lead)
		return lead.buyUnits
	end,
	cost = function(lead)
		return lead.cost
	end,
	profit = function(lead)
		return lead.profit
	end,
}

local function PaintList(keepScroll)
	local market, reason = ns.Window:Market()
	list:SetEmptyText(market and L.RESELL_NOTHING or reason)
	leads = market and ns.Resell.Leads(market.items, Params(), state.topOnly and ns.DealPips or ns.ResellMinPips) or {}
	Kit.SortRows(leads, SORT_VALUES[state.sort.id], state.sort.descending)
	list:SetSort(state.sort.id, state.sort.descending)
	list:SetRows(leads, keepScroll)
end

-- ========= The plan =========================================================
local function SetLimit(value, available)
	local wanted = math.max(1, math.min(available, math.floor(value or 1)))
	state.limit = wanted < available and wanted or nil
	PaintPlan()
end

-- A numbered step heading: "1 Buy".
local function Step(parent, number, title)
	local step = CreateFrame("Frame", nil, parent)
	step:SetHeight(18)
	local badge = CreateFrame("Frame", nil, step)
	badge:SetSize(16, 16)
	badge:SetPoint("LEFT")
	Kit.Fill(badge, C.accent)
	local digit = Kit.Text(badge, "small", C.panel, "CENTER")
	digit:SetAllPoints()
	digit:SetText(number)
	local label = Kit.Text(step, "normal", C.accent)
	label:SetPoint("LEFT", 22, 0)
	label:SetText(title)
	return step
end

local function Rule(parent)
	local rule = CreateFrame("Frame", nil, parent)
	rule:SetHeight(1)
	Kit.Fill(rule, C.line)
	return rule
end

local function BuildPlan(parent)
	local width = Theme.resell.plan - 16
	stack = Kit.Stack(parent, 8)

	prompt = Kit.Note(parent, "normal", C.muted, "CENTER")
	prompt:SetPoint("TOPLEFT", 16, -30)
	prompt:SetPoint("TOPRIGHT", -16, -30)
	prompt:SetWidth(width - 16)
	prompt:SetBody(L.RESELL_PICK)

	parts.head = CreateFrame("Frame", nil, parent)
	parts.head:SetHeight(34)
	parts.icon = Kit.Icon(parts.head, 32)
	parts.icon:SetPoint("LEFT")
	parts.name = Kit.Text(parts.head, "normal")
	parts.name:SetPoint("TOPLEFT", 40, -2)
	parts.name:SetPoint("RIGHT")
	parts.forSale = Kit.Text(parts.head, "small", C.muted)
	parts.forSale:SetPoint("BOTTOMLEFT", 40, 2)

	parts.rule1, parts.rule2, parts.rule3, parts.rule4 = Rule(parent), Rule(parent), Rule(parent), Rule(parent)
	parts.step1 = Step(parent, "1", L.RESELL_STEP_BUY)
	parts.step2 = Step(parent, "2", L.RESELL_STEP_RELIST)
	parts.step3 = Step(parent, "3", L.RESELL_STEP_KEEP)

	-- How many to buy, counted in what the game sells: whole auctions, or
	-- units for a commodity.
	parts.limitRow = CreateFrame("Frame", nil, parent)
	parts.limitRow:SetHeight(26)
	parts.limitLabel = Kit.Text(parts.limitRow, "normal", C.muted)
	parts.limitLabel:SetPoint("LEFT")
	local function Current()
		local lead = SelectedLead()
		local planned = lead and (ns.Resell.Plan(lead.item, Params(), state.limit) or lead)
		return lead, planned
	end
	local function Count(planned)
		return planned.byUnit and planned.buyUnits or planned.buyAuctions
	end
	parts.limitMinus = Kit.Button(parts.limitRow, { text = "-", width = 26, height = 26, onClick = function()
		local lead, planned = Current()
		if lead then
			SetLimit(Count(planned) - 1, lead.available)
		end
	end })
	parts.limitMinus:SetPoint("LEFT", 60, 0)
	parts.limit = Kit.Input(parts.limitRow, { width = 60, height = 26, numeric = true, justify = "RIGHT", maxLetters = 6, onNumber = function(number)
		local lead = Current()
		if lead then
			SetLimit(number, lead.available)
		end
	end })
	parts.limit:SetPoint("LEFT", parts.limitMinus, "RIGHT", 4, 0)
	parts.limitPlus = Kit.Button(parts.limitRow, { text = "+", width = 26, height = 26, onClick = function()
		local lead, planned = Current()
		if lead then
			SetLimit(Count(planned) + 1, lead.available)
		end
	end })
	parts.limitPlus:SetPoint("LEFT", parts.limit, "RIGHT", 4, 0)
	parts.limitAll = Kit.Button(parts.limitRow, { text = L.SELL_ALL, height = 26, onClick = function()
		local lead = Current()
		if lead then
			SetLimit(lead.available, lead.available)
		end
	end })
	parts.limitAll:SetPoint("LEFT", parts.limitPlus, "RIGHT", 4, 0)
	parts.limitOf = Kit.Text(parts.limitRow, "small", C.muted)
	parts.limitOf:SetPoint("LEFT", parts.limitAll, "RIGHT", 6, 0)

	-- The game sells one auction per press, so the button buys the next one
	-- on the list and says exactly what that is.
	parts.buy = Kit.Button(parent, { text = "", look = "action", height = 40, width = width, tip = { L.TAB_RESELL, L.BUY_NOT_WIRED } })
	parts.buy.label:ClearAllPoints()
	parts.buy.label:SetPoint("TOP", 0, -6)
	parts.buySub = Kit.Text(parts.buy, "small", C.text, "CENTER")
	parts.buySub:SetPoint("BOTTOM", 0, 6)

	parts.confidence = CreateFrame("Frame", nil, parent)
	parts.confidence:SetHeight(38)
	Kit.Fill(parts.confidence, C.block)
	Kit.Border(parts.confidence, C.line)
	local confidenceName = Kit.Text(parts.confidence, "normal", C.text)
	confidenceName:SetPoint("TOPLEFT", 8, -6)
	confidenceName:SetText(L.CONFIDENCE)
	parts.confidenceLevel = Kit.Text(parts.confidence, "normal", C.text, "RIGHT")
	parts.confidenceLevel:SetPoint("TOPRIGHT", -8, -6)
	parts.confidenceMeter = Kit.Meter(parts.confidence, ns.ConfidencePips)
	parts.confidenceMeter:SetPoint("RIGHT", parts.confidenceLevel, "LEFT", -6, 0)
	parts.confidenceFacts = Kit.Text(parts.confidence, "small", C.muted)
	parts.confidenceFacts:SetPoint("BOTTOMLEFT", 8, 6)
	parts.confidenceFacts:SetPoint("RIGHT", -8, 0)
	parts.confidence:EnableMouse(true)
	Kit.Tip(parts.confidence, function()
		local lead = SelectedLead()
		return lead and { L.CONFIDENCE, unpack(ns.Signals:Confidence(lead.item).reasons) } or nil
	end)

	parts.average, parts.cost = Kit.Pair(parent), Kit.Pair(parent)
	parts.usual, parts.back = Kit.Pair(parent), Kit.Pair(parent)
	parts.profit = Kit.Pair(parent, "total", C.text)
	parts.profit:SetHeight(22)
	parts.roi = Kit.Pair(parent)
	parts.competition = Kit.Note(parent, "small", C.muted)
	parts.competition:SetWidth(width)

	parts.linesLabel = CreateFrame("Frame", nil, parent)
	parts.linesLabel:SetHeight(14)
	local linesText = Kit.Text(parts.linesLabel, "normal", C.accent)
	linesText:SetPoint("LEFT")
	linesText:SetText(L.RESELL_THE_AUCTIONS)
	parts.lines = {}
	for index = 1, PLAN_LINES do
		parts.lines[index] = Kit.Pair(parent, "small")
		parts.lines[index]:SetHeight(16)
	end
	parts.more = Kit.Note(parent, "small", C.muted)
	parts.more:SetWidth(width)
end

local DrawPlan
PaintPlan = function()
	stack:Paint(DrawPlan)
end
DrawPlan = function()
	local full = SelectedLead()
	prompt:SetShown(full == nil)
	if not full then
		return
	end
	local item = full.item
	-- The list plans "everything worth buying". Here the player picks how
	-- much of that to take, and the rest of the plan follows.
	local lead = ns.Resell.Plan(item, Params(), state.limit) or full
	local count = lead.byUnit and lead.buyUnits or lead.buyAuctions
	local cut = math.floor(ns.Assumptions.auctionCut * 100 + 0.5)

	parts.icon:SetIcon(item.icon)
	parts.name:SetText(item.name)
	parts.name:SetTextColor(unpack(Kit.QualityColor(item.quality)))
	parts.forSale:SetText(L.RESELL_FOR_SALE:format(ns.Comma(item.units), ns.Comma(item.listings)))
	stack:Add(parts.head)

	stack:Add(parts.rule1, 6)
	stack:Add(parts.step1, 6)
	parts.limitLabel:SetText(lead.byUnit and L.RESELL_UNITS or L.RESELL_AUCTIONS)
	parts.limit:SetValue(tostring(count))
	parts.limitOf:SetText(L.SELL_OF:format(ns.Comma(full.available)))
	-- A button that cannot change the number says so by going dim: with one
	-- auction worth buying there is nothing to add and nothing to take away.
	parts.limitMinus:SetDisabled(count <= 1)
	parts.limitPlus:SetDisabled(count >= full.available)
	parts.limitAll:SetDisabled(count >= full.available)
	stack:Add(parts.limitRow, 4)

	local next = lead.lines[1]
	if lead.byUnit then
		parts.buy:SetLabel(L.RESELL_BUY_UNITS:format(ns.Comma(lead.buyUnits)))
		parts.buySub:SetText(L.BUY_BY_UNIT)
	else
		parts.buy:SetLabel(lead.buyAuctions > 1 and L.RESELL_BUY_NEXT:format(ns.Comma(lead.buyAuctions)) or L.RESELL_BUY_ONE)
		parts.buySub:SetText(next and L.RESELL_NEXT:format(ns.Comma(next.tier.stack), ns.Money(next.tier.unit)) or "")
	end
	stack:Add(parts.buy, 6)

	local reading = ns.Signals:Confidence(item)
	parts.confidenceMeter:SetReading(reading)
	parts.confidenceLevel:SetText(reading.level.label)
	parts.confidenceFacts:SetText(ns.Signals:ConfidenceLine(reading))
	stack:Add(parts.confidence, 6)

	parts.average:Set(L.RESELL_AVERAGE:format(ns.Comma(lead.buyUnits)), ns.Money(lead.averageUnit))
	stack:Add(parts.average, 6)
	parts.cost:Set(L.RESELL_COST, ns.Money(lead.cost))
	stack:Add(parts.cost, 2)

	stack:Add(parts.rule2, 6)
	stack:Add(parts.step2, 6)
	parts.usual:Set(L.RESELL_USUAL, ns.Money(lead.target))
	stack:Add(parts.usual, 4)
	parts.back:Set(L.RESELL_RETURN:format(cut), ns.Money(lead.revenue))
	stack:Add(parts.back, 2)

	stack:Add(parts.rule3, 6)
	stack:Add(parts.step3, 6)
	parts.profit:Set(L.RESELL_PROFIT, ns.Money(lead.profit))
	stack:Add(parts.profit, 4)
	parts.roi:Set(L.RESELL_ROI, ns.Comma(lead.roi) .. "%")
	stack:Add(parts.roi, 2)

	local crowded = lead.competition > lead.buyUnits * 3
	parts.competition:SetBody(lead.competition == 0 and L.RESELL_CLEAR or L.RESELL_COMPETITION:format(ns.Comma(lead.competition)), crowded and C.bad or C.muted)
	stack:Add(parts.competition, 6)

	-- The auction-by-auction detail is the least interesting part, so it goes last.
	stack:Add(parts.rule4, 6)
	stack:Add(parts.linesLabel, 6)
	for index = 1, PLAN_LINES do
		local line = lead.lines[index]
		if line then
			local what = lead.byUnit and L.BUY_LINE_UNITS:format(ns.Comma(line.units))
				or L.BUY_LINE_STACKS:format(ns.Comma(line.auctions), ns.Comma(line.tier.stack))
			parts.lines[index]:Set(what, L.EACH:format(ns.Money(line.tier.unit)))
			stack:Add(parts.lines[index], index == 1 and 4 or 0)
		end
	end
	if #lead.lines > PLAN_LINES then
		parts.more:SetBody(L.BUY_MORE_LINES:format(#lead.lines - PLAN_LINES))
		stack:Add(parts.more, 2)
	end
end

-- ========= The tab ==========================================================
Refresh = function(keepScroll)
	margins:Refresh()
	affordButton:SetActive(state.affordOnly)
	topButton:SetActive(state.topOnly)
	PaintList(keepScroll)
	if state.selectedKey and not SelectedLead() then
		state.selectedKey, state.limit = nil, nil
	end
	PaintPlan()
end

local function Create(parent)
	local pad = Theme.pad
	plan = Kit.Panel(parent)
	plan:SetPoint("TOPRIGHT")
	plan:SetPoint("BOTTOMRIGHT")
	plan:SetWidth(Theme.resell.plan)
	Kit.Split(plan, { id = "resell.plan", edge = "LEFT", min = Theme.resell.plan, max = Theme.resell.plan + Theme.panelGrow, onChange = function()
		ns.Window:RefreshActive()
	end })
	BuildPlan(plan)

	-- The settings bar: two labelled controls on the left (how big a discount,
	-- how much profit), then the two on/off filters on the right.
	local bar = Kit.Panel(parent)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT", plan, "TOPLEFT", -pad, 0)
	bar:SetHeight(66)

	local discountLabel = Kit.Text(bar, "normal", C.accent)
	discountLabel:SetPoint("TOPLEFT", 8, -12)
	discountLabel:SetText(L.RESELL_DISCOUNT)
	local marginItems = {}
	for _, percent in ipairs(ns.ResellMargins) do
		marginItems[#marginItems + 1] = { percent = percent, label = percent .. "%", tip = L.RESELL_DISCOUNT_TIP:format(percent) }
	end
	margins = Kit.Choices(bar, {
		items = marginItems,
		joined = true,
		padding = 14,
		isActive = function(option)
			return option.percent == state.margin
		end,
		onPick = function(option)
			state.margin = option.percent
			Refresh()
		end,
	})
	margins:SetPoint("LEFT", discountLabel, "RIGHT", 6, 0)

	-- How many of one item to buy at most. Whatever is bought has to be
	-- relisted and sold, so this keeps a lead to a size worth taking on.
	local maxLabel = Kit.Text(bar, "normal", C.accent)
	maxLabel:SetPoint("LEFT", margins, "RIGHT", 16, 0)
	maxLabel:SetText(L.RESELL_MAX_BUY)
	maxInput = Kit.Input(bar, { width = 50, numeric = true, maxLetters = 5, justify = "CENTER", onNumber = function(number)
		state.maxItems = math.max(1, number)
		state.limit = nil
		Refresh()
	end })
	maxInput:SetPoint("LEFT", maxLabel, "RIGHT", 6, 0)
	maxInput:SetText(tostring(state.maxItems))
	Kit.Tip(maxInput, { L.RESELL_MAX_BUY, L.RESELL_MAX_BUY_TIP })

	local profitLabel = Kit.Text(bar, "normal", C.accent)
	profitLabel:SetPoint("TOPLEFT", 8, -42)
	profitLabel:SetText(L.RESELL_MIN_PROFIT)
	profitInput = Kit.MoneyInput(bar, { compact = true, onChange = function(copper)
		state.minProfit = copper
		PaintList()
		PaintPlan()
	end })
	profitInput:SetPoint("LEFT", profitLabel, "RIGHT", 6, 0)
	profitInput:SetAmount(state.minProfit)

	topButton = Kit.Button(bar, { text = L.RESELL_TOP, padding = 14, tip = { L.RESELL_TOP, L.RESELL_TOP_TIP }, onClick = function()
		state.topOnly = not state.topOnly
		Refresh()
	end })
	topButton:SetPoint("BOTTOMRIGHT", -6, 6)
	affordButton = Kit.Button(bar, { text = L.RESELL_AFFORD, padding = 14, tip = { L.RESELL_AFFORD, L.RESELL_AFFORD_TIP }, onClick = function()
		state.affordOnly = not state.affordOnly
		Refresh()
	end })
	affordButton:SetPoint("RIGHT", topButton, "LEFT", -5, 0)

	list = Kit.List(parent, {
		id = "resell",
		columns = {
			{
				id = "name",
				label = L.BUY_COL_ITEM,
				flex = true,
				icon = function(lead)
					return lead.item.icon
				end,
				text = function(lead)
					return lead.item.name
				end,
				color = function(lead)
					return Kit.QualityColor(lead.item.quality)
				end,
			},
			{ id = "deal", label = L.RESELL_COL_DEAL, width = 50, pips = ns.DealPips, meter = function(lead)
				return lead.deal
			end },
			{ id = "forSale", label = L.RESELL_COL_FOR_SALE, width = 54, align = "RIGHT", color = function()
				return C.muted
			end, text = function(lead)
				return ns.Comma(lead.item.units)
			end },
			{ id = "units", label = L.RESELL_COL_BUY, width = 46, align = "RIGHT", text = function(lead)
				return ns.Comma(lead.buyUnits)
			end },
			{ id = "cost", label = L.RESELL_COL_COST, width = 92, align = "RIGHT", text = function(lead)
				return ns.Money(lead.cost)
			end },
			{ id = "profit", label = L.RESELL_COL_PROFIT, width = 92, align = "RIGHT", text = function(lead)
				return ns.Money(lead.profit)
			end },
		},
		empty = L.RESELL_NOTHING,
		onClick = function(lead)
			state.selectedKey, state.limit = lead.item.key, nil
			list:SetRows(leads, true)
			PaintPlan()
		end,
		isSelected = function(lead)
			return lead.item.key == state.selectedKey
		end,
		link = function(lead)
			return lead.item.link
		end,
		onSort = function(id)
			if state.sort.id == id then
				state.sort.descending = not state.sort.descending
			else
				state.sort = { id = id, descending = id ~= "name" }
			end
			PaintList()
		end,
	})
	list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
	list:SetPoint("BOTTOMRIGHT", plan, "BOTTOMLEFT", -pad, 0)

	return { Refresh = function()
		Refresh(true)
	end }
end

ns.Window:RegisterTab({ id = "resell", label = L.TAB_RESELL, order = 3, Create = Create })

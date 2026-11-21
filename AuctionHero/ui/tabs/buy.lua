-- Buy tab: a rail of quick filters, the category checkboxes, the item list,
-- and an order panel that says what buying a quantity really costs.
-- The layout and behavior follow the lab's concept (lab/src/ui/concept/buy.ts).
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color
local Facets = ns.Facets

local ORDER_LINES = 8 -- price points listed in the order panel
local PRICE_ROWS = 15 -- prices listed under an opened item, at most
local STAT_LINES = 10 -- lines of scan facts under the Buy button, at most
local LADDER_ROWS = 10 -- prices listed under "For sale now", at most
local LADDER_ROW_HEIGHT = 16
local LADDER_BAR_AT = 110 -- where the bars start, from the left of a row
local LADDER_BAR = 110 -- the longest a bar gets
local HEADER_HEIGHT, OPTION_HEIGHT = 26, 21

-- What the player has chosen. Kept for the session.
local state = {
	selection = {}, -- ticked boxes and toggles, see market\facets.lua
	open = {}, -- facet id -> expanded
	search = "",
	toggles = {}, -- quick toggle id -> on
	sort = { id = "units", descending = true },
	selectedKey = nil,
	wanted = 1,
}

local market, facets, listable, makeFilter -- rebuilt when the market changes
local rail, sidebar, toolbar, list, order, prompt, searchBox
local railView, railContent, railFades -- the rail scrolls when it is taller than the window
local railScroll = 0
local railTiles, sideTiles, sideRows, toggleButtons = {}, {}, {}, {}
local Refresh
local lastOrder -- item key -> where it stood in the list as last sorted
local gainOf, valueOf -- gear gain and gain per gold, rebuilt each time the list is painted
local bagGainOf, bagValueOf -- the same for bags, in slots

-- ========= Filtering ========================================================
local function Prepare()
	local current = ns.Window:Market()
	if facets and current == market then
		return
	end
	if current ~= market then
		lastOrder = nil -- a new scan: nothing to hold the old order for
	end
	market = current
	listable = {}
	if market then
		for _, item in ipairs(market.items) do
			if item.units > 0 then
				listable[#listable + 1] = item
			end
		end
	end
	facets = Facets:Build(listable)
	makeFilter = Facets:Filter(facets)
end

-- Bag kinds ticked in the filters: a kind the player looks for counts even
-- when none is carried.
local function PickedBagKinds()
	local picked = {}
	for value in pairs(state.selection.containers or {}) do
		local subClassID = tonumber(tostring(value):match("^1:(%d+)$"))
		if subClassID then
			picked[subClassID] = true
		end
	end
	return picked
end

local function FilteredItems()
	local search = state.search:lower()
	local passes = makeFilter(state.selection)
	local gold = GetMoney()
	local dealFrom = ns.DealBadgeRule.percent
	-- Better: gear that beats what you wear, or a bag that holds more than
	-- the one it would replace.
	local better
	if state.toggles.betterOnly then
		local gear = ns.Gear:Better()
		better = function(item)
			local slots = bagGainOf and bagGainOf(item)
			return gear(item) or (slots ~= nil and slots > 0)
		end
	end
	local near = state.toggles.nearLevel and ns.Gear:Near()
	local suggested = state.toggles.suggested and function(item)
		return valueOf(item) or bagValueOf(item)
	end
	local rows = {}
	for _, item in ipairs(listable) do
		local keep = (search == "" or item.name:lower():find(search, 1, true) ~= nil)
			and (not state.toggles.usableOnly or item.usable)
			and (not state.toggles.dealsOnly or (item.deal ~= nil and item.deal >= dealFrom))
			and (not state.toggles.affordableOnly or (ns.Orders.CheapestAuction(item) or math.huge) <= gold)
			and (not better or better(item))
			and (not near or near(item))
			and (not suggested or suggested(item) ~= nil)
			and (passes == nil or passes(item))
		if keep then
			rows[#rows + 1] = item
		end
	end
	return rows
end

-- ========= The rail =========================================================
-- Each tile is a checkbox over a color or an icon, named by its tooltip.
-- Tiles are kept in pools: the rail's, and the row at the top of the
-- category column.
local function Tile(pool, parent, index)
	local tile = pool[index]
	if not tile then
		tile = CreateFrame("Button", nil, parent)
		tile.fill = Kit.Fill(tile, C.input)
		tile.art = tile:CreateTexture(nil, "ARTWORK")
		tile.art:SetPoint("TOPLEFT", 1, -1)
		tile.art:SetPoint("BOTTOMRIGHT", -1, 1)
		tile.art:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		tile.border = Kit.Border(tile, C.inputBorder, "OVERLAY")
		tile.mark = tile:CreateTexture(nil, "OVERLAY", nil, 2)
		tile.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		Kit.Tip(tile, function(self)
			return { self.tip }
		end)
		tile:SetScript("OnClick", function(self)
			self.onClick()
		end)
		pool[index] = tile
	end
	return tile
end

-- A quality's color, dimmed toward the window when the swatch is off.
local function Dim(color)
	local base = C.window
	return { color[1] * 0.28 + base[1] * 0.72, color[2] * 0.28 + base[2] * 0.72, color[3] * 0.28 + base[3] * 0.72, 1 }
end

-- The rail has two sizes, switched by the strip beside it. Swatches keep
-- their share of the tile size.
local function TileSize()
	return ns.IsEnabled("railLarge") and math.floor(Theme.tile * Theme.tileLargeScale + 0.5) or Theme.tile
end

local function TileHeight(spec, size)
	return spec.swatch and math.floor(size * Theme.swatch / Theme.tile + 0.5) or size
end

-- Whether the game has an icon file. Asked once per path.
local iconKnown = {}
local function HasIcon(path)
	if iconKnown[path] == nil then
		iconKnown[path] = not GetFileIDFromPath or GetFileIDFromPath(path) ~= nil
	end
	return iconKnown[path]
end

-- Paints a tile's look. Where it goes is up to the caller.
local function PaintTile(tile, spec, width, height)
	tile:SetSize(width, height)
	tile.tip = spec.tip
	tile.onClick = spec.onClick
	tile.art:SetDesaturated(spec.desaturate == true)
	-- A swatch with an icon: the icon, faded when off, in its quality's color.
	-- Without one, or when the game has no such icon, a square of the color.
	local pictured = spec.swatch and spec.icon and HasIcon(spec.icon) and tile.art:SetTexture(spec.icon) ~= false
	if pictured then
		tile.fill:SetColorTexture(unpack(C.input))
		tile.art:Show()
		tile.art:SetAlpha(spec.on and 1 or Theme.swatchIconOff)
		tile.border:SetColor(spec.on and spec.color or Dim({ spec.color[1] * 2, spec.color[2] * 2, spec.color[3] * 2 }))
		tile.mark:SetVertexColor(1, 1, 1)
		tile.mark:ClearAllPoints()
		tile.mark:SetPoint("CENTER")
		tile.mark:SetSize(width, width)
	elseif spec.swatch then
		tile.art:Hide()
		tile.fill:SetColorTexture(unpack(spec.on and spec.color or Dim(spec.color)))
		tile.border:SetColor(spec.on and C.white or Dim({ spec.color[1] * 2, spec.color[2] * 2, spec.color[3] * 2 }))
		tile.mark:SetVertexColor(0, 0, 0)
		tile.mark:ClearAllPoints()
		tile.mark:SetPoint("CENTER")
		local side = math.min(width, height) + 4
		tile.mark:SetSize(side, side)
	else
		tile.fill:SetColorTexture(unpack(C.input))
		tile.art:SetTexture(spec.icon)
		tile.art:SetShown(spec.icon ~= nil)
		-- In gray until ticked, then in its own colors.
		local off = not spec.on and Theme.tileIconOffGray
		tile.art:SetDesaturated(off or spec.desaturate == true)
		tile.art:SetAlpha(off and Theme.tileIconOff or 1)
		tile.border:SetColor(spec.on and C.accent or C.inputBorder)
		tile.mark:SetVertexColor(1, 1, 1)
		tile.mark:ClearAllPoints()
		tile.mark:SetPoint("CENTER")
		tile.mark:SetSize(width, width)
	end
	tile.mark:SetShown(spec.on)
	tile:Show()
	return height
end

local function FacetById(id)
	for _, facet in ipairs(facets) do
		if facet.id == id then
			return facet
		end
	end
end

-- The tiles of one rail entry (see ns.BuyRail in data\facets.lua).
local function TilesFor(entry)
	local specs = {}
	local function Add(key, value, on, spec)
		-- An icon tile with no icon is a blank square that says nothing. That
		-- happens before the first scan, when there are no items to picture it.
		if not spec.swatch and not spec.icon then
			return
		end
		spec.on = on
		spec.onClick = function()
			Facets.Toggle(state.selection, key, value, not on)
			Refresh()
		end
		specs[#specs + 1] = spec
	end

	if entry.quality then
		local facet = FacetById(ns.QualityFacet.id)
		local ticked = state.selection[facet.id] or {}
		for _, option in ipairs(facet.options) do
			local look = ns.QualityIcons[option.quality] or {}
			Add(facet.id, option.value, ticked[option.value] == true, {
				swatch = true,
				color = Kit.QualityColor(option.quality),
				icon = look.icon,
				desaturate = look.desaturate,
				tip = L.RAIL_TIP:format(facet.label, option.label),
			})
		end
	elseif entry.refine then
		local facet = FacetById(entry.refine)
		if facet and facet.refineOptions then
			local key = Facets.RefineKey(facet.id)
			local ticked = state.selection[key] or {}
			for _, option in ipairs(facet.refineOptions) do
				Add(key, option.value, ticked[option.value] == true, {
					icon = option.icon,
					tip = L.RAIL_TIP:format(facet.refine.label, option.label),
				})
			end
		end
	elseif entry.box then
		local facet = FacetById(entry.of)
		local ticked = facet and state.selection[facet.id] or {}
		for _, option in ipairs(facet and facet.options or {}) do
			if option.label == entry.box then
				Add(facet.id, option.value, ticked[option.value] == true, { icon = option.icon, tip = option.label })
			end
		end
	end
	return specs
end

local railRules = {}
local RAIL_TOP, TILE_GAP, RULE_GAP = 6, 4, 8

-- The rail keeps its tiles at the size chosen and scrolls, with the mouse
-- wheel, when they run taller than the window. A fade at either end says
-- there is more that way.
local function ScrollRail(offset)
	local room = railView:GetHeight() or 0
	local most = math.max(0, (railContent:GetHeight() or 0) - room)
	railScroll = math.max(0, math.min(most, offset))
	railContent:ClearAllPoints()
	railContent:SetPoint("TOPLEFT", railView, "TOPLEFT", 0, railScroll)
	railContent:SetPoint("TOPRIGHT", railView, "TOPRIGHT", 0, railScroll)
	railFades.top:SetShown(railScroll > 0)
	railFades.bottom:SetShown(railScroll < most)
end

local function PaintRail()
	rail:SetWidth(TileSize() + Theme.buy.rail - Theme.tile)
	for _, tile in ipairs(railTiles) do
		tile:Hide()
	end
	for _, rule in ipairs(railRules) do
		rule:Hide()
	end
	local size = TileSize()
	local y, used, rules = RAIL_TOP, 0, 0
	for _, section in ipairs(ns.BuyRail) do
		local specs = {}
		for _, entry in ipairs(section) do
			for _, spec in ipairs(TilesFor(entry)) do
				specs[#specs + 1] = spec
			end
		end
		if #specs > 0 then
			if used > 0 then
				rules = rules + 1
				local rule = railRules[rules]
				if not rule then
					rule = Kit.Rule(railContent)
					rule:SetWidth(20)
					railRules[rules] = rule
				end
				rule:ClearAllPoints()
				rule:SetPoint("TOP", railContent, "TOP", 0, -(y + 2))
				rule:Show()
				y = y + RULE_GAP
			end
			for _, spec in ipairs(specs) do
				used = used + 1
				local tile, height = Tile(railTiles, railContent, used), TileHeight(spec, size)
				tile:ClearAllPoints()
				tile:SetPoint("TOP", railContent, "TOP", 0, -y)
				y = y + PaintTile(tile, spec, size, height) + TILE_GAP
			end
		end
	end
	railContent:SetHeight(y)
	ScrollRail(railScroll)
end

-- ========= The category column =============================================
-- One kind of row draws all three cases: a category header, a box inside an
-- open category, and a "flat" box that sits straight in the column.
local function SideRow(index)
	local row = sideRows[index]
	if not row then
		row = CreateFrame("Button", nil, sidebar.content)
		row.fill = Kit.Gradient(row, C.controlTop, C.controlBottom)
		row.border = Kit.Border(row, C.inputBorder)
		row.hover = Kit.Fill(row, C.rowHover, "BORDER")
		row.hover:Hide()
		row.check = Kit.Check(row, 14)
		row.icon = Kit.Icon(row, 16)
		row.label = Kit.Text(row, "normal", C.text)
		row.caret = Kit.Caret(row)
		row.caret:SetPoint("RIGHT", -7, 0)
		row.count = CreateFrame("Frame", nil, row)
		row.count:SetSize(18, 14)
		row.count:SetPoint("RIGHT", row.caret, "LEFT", -6, 0)
		Kit.Fill(row.count, C.accent)
		row.countText = Kit.Text(row.count, "small", C.panel, "CENTER")
		row.countText:SetAllPoints()
		-- The checkbox of a header has its own click, apart from the expander.
		row.checkZone = CreateFrame("Button", nil, row)
		row.checkZone:SetPoint("TOPLEFT")
		row.checkZone:SetPoint("BOTTOMLEFT")
		row.checkZone:SetWidth(26)
		row.checkZone:SetScript("OnClick", function()
			row.onCheck()
		end)
		row:SetScript("OnClick", function(self)
			self.onClick()
		end)
		row:SetScript("OnEnter", function(self)
			self.hover:SetShown(not self.isHeader)
			if self.isHeader then
				self.border:SetColor(C.activeBorder)
			end
		end)
		row:SetScript("OnLeave", function(self)
			self.hover:Hide()
			self.border:SetColor(C.inputBorder)
		end)
		sideRows[index] = row
	end
	return row
end

-- spec: header (bool), label, color, checked, icon, count, open, onClick, onCheck
local function PaintSideRow(row, spec, y)
	local height = spec.header and HEADER_HEIGHT or OPTION_HEIGHT
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", sidebar.content, "TOPLEFT", spec.header and 0 or 8, -y)
	row:SetPoint("TOPRIGHT", sidebar.content, "TOPRIGHT", 0, -y)
	row:SetHeight(height)
	row.isHeader = spec.header
	row.fill:SetShown(spec.header)
	row.onClick = spec.onClick
	row.onCheck = spec.onCheck or spec.onClick
	row.checkZone:SetShown(spec.onCheck ~= nil)

	row.check:ClearAllPoints()
	row.check:SetPoint("LEFT", spec.header and 7 or 2, 0)
	row.check:SetState(spec.checked)

	local x = (spec.header and 7 or 2) + 14 + 6
	row.icon:SetShown(spec.icon ~= nil)
	if spec.icon then
		row.icon:ClearAllPoints()
		row.icon:SetPoint("LEFT", x, 0)
		row.icon:SetIcon(spec.icon)
		x = x + 16 + 6
	end
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", x, 0)
	row.label:SetPoint("RIGHT", spec.expander and -40 or -4, 0)
	row.label:SetText(spec.label)
	row.label:SetTextColor(unpack(spec.header and C.accent or C.text))

	row.caret:SetShown(spec.expander == true)
	row.caret:SetOpen(spec.open == true)
	row.count:SetShown((spec.count or 0) > 0)
	row.countText:SetText(spec.count or "")
	-- Rows that are not headers have no box around them.
	row.border:SetColor(spec.header and C.inputBorder or { 0, 0, 0, 0 })
	row:Show()
	return height
end

local clearButton
local function PaintSidebar()
	for _, row in ipairs(sideRows) do
		row:Hide()
	end
	local y, used = 0, 0
	local function Add(spec)
		used = used + 1
		y = y + PaintSideRow(SideRow(used), spec, y)
	end

	-- The rows of square tiles at the top (see ns.BuySidebarTop), each as
	-- wide as the column allows and no bigger than a rail tile.
	for _, tile in ipairs(sideTiles) do
		tile:Hide()
	end
	local tiles = 0
	local width = sidebar.content:GetWidth()
	if not width or width < 40 then
		width = Theme.buy.sidebar - 16
	end
	for _, entry in ipairs(ns.BuySidebarTop) do
		local specs = TilesFor(entry)
		if #specs > 0 then
			local gap = Theme.sideTileGap
			local size = math.min(Theme.tile, math.floor((width - gap * (#specs - 1)) / #specs))
			for index, spec in ipairs(specs) do
				tiles = tiles + 1
				local tile = Tile(sideTiles, sidebar.content, tiles)
				tile:ClearAllPoints()
				tile:SetPoint("TOPLEFT", sidebar.content, "TOPLEFT", (index - 1) * (size + gap), -y)
				PaintTile(tile, spec, size, size)
			end
			y = y + size + 8
		end
	end

	for _, facet in ipairs(facets) do
		if not facet.rail and #facet.options > 0 then
			local ticked = state.selection[facet.id] or {}
			local tickedCount = 0
			for _, option in ipairs(facet.options) do
				if ticked[option.value] then
					tickedCount = tickedCount + 1
				end
			end
			local function ToggleOption(option)
				return function()
					Facets.Toggle(state.selection, facet.id, option.value, not ticked[option.value])
					Refresh()
				end
			end

			if facet.flat then
				-- No header: each box sits straight in the column. A category
				-- with one box takes the category's name.
				for _, option in ipairs(facet.options) do
					Add({
						header = true,
						label = #facet.options == 1 and facet.label or option.label,
						checked = ticked[option.value] == true,
						icon = option.icon,
						onClick = ToggleOption(option),
					})
					y = y + 4
				end
			else
				local all = tickedCount == #facet.options
				local refined = 0
				for _ in pairs(state.selection[Facets.RefineKey(facet.id)] or {}) do
					refined = refined + 1
				end
				local isOpen = state.open[facet.id] == true
				Add({
					header = true,
					expander = true,
					label = facet.label,
					checked = all or (tickedCount > 0 and "some") or false,
					count = (all and 0 or tickedCount) + refined,
					open = isOpen,
					onClick = function()
						state.open[facet.id] = not isOpen
						Refresh()
					end,
					-- The header's own checkbox ticks every box in the category.
					onCheck = function()
						for _, option in ipairs(facet.options) do
							Facets.Toggle(state.selection, facet.id, option.value, not all)
						end
						Refresh()
					end,
				})
				if isOpen then
					y = y + 2
					for _, option in ipairs(facet.options) do
						if not option.inRail then -- it is a tile in the rail
							Add({ label = option.label, checked = ticked[option.value] == true, icon = option.icon, onClick = ToggleOption(option) })
						end
					end
				end
				y = y + 4
			end
		end
	end

	clearButton:SetShown(Facets.AnySelected(state.selection))
	if clearButton:IsShown() then
		clearButton:ClearAllPoints()
		clearButton:SetPoint("TOPLEFT", sidebar.content, "TOPLEFT", 0, -(y + 2))
		clearButton:SetPoint("TOPRIGHT", sidebar.content, "TOPRIGHT", 0, -(y + 2))
		y = y + 26
	end
	sidebar:SetContentHeight(y)
end

-- ========= The list =========================================================
local SORT_VALUES = {
	name = function(item)
		return item.name
	end,
	level = function(item)
		return item.levelType == "REQ_LEVEL_ABBR" and item.level or nil
	end,
	units = function(item)
		return item.units
	end,
	min = function(item)
		return item.min
	end,
	deal = function(item)
		return item.deal
	end,
	gain = function(item)
		local gain = gainOf and gainOf(item)
		if gain and gain > 0 then
			return gain
		end
		local slots = bagGainOf and bagGainOf(item)
		return slots and slots > 0 and slots - ns.BagGainSortOffset or nil
	end,
}

-- How far a unit price sits under what the item would otherwise cost, in
-- percent, or nil when it does not.
local function DealAt(item, unit)
	local baseline = ns.Signals:Baseline(item)
	if baseline and unit < baseline.price then
		return math.floor((baseline.price - unit) / baseline.price * 100)
	end
end

-- The rows under an opened item: one for each price it is listed at, with how
-- many are at that price. A price row is { item, point = { unit, units } }.
-- Nothing about what is for sale is left for the player to guess.
local function PriceRows(item)
	local rows = {}
	local points = ns.Market.PricePoints(item)
	for index = 1, math.min(#points, PRICE_ROWS) do
		rows[#rows + 1] = { item = item, point = points[index] }
	end
	if #points > PRICE_ROWS then
		rows[#rows + 1] = { item = item, more = #points - PRICE_ROWS, upTo = points[#points].unit }
	end
	return rows
end

-- The list is sorted when the player sorts or filters it. A change that
-- comes from elsewhere (a live check, a purchase) keeps every item where it
-- stood, so what the player is looking at does not jump away: an item whose
-- bargain has just sold stays put, with its new numbers, until the next sort.
local function PaintList(keepScroll)
	gainOf = ns.Gear:Gains()
	valueOf = ns.Gear:ValuePerGold(ns.Orders.CheapestAuction)
	local picked = PickedBagKinds()
	bagGainOf = ns.BagSize:Gains(picked)
	bagValueOf = ns.BagSize:ValuePerGold(ns.Orders.CheapestAuction, picked)
	local items = FilteredItems()
	if keepScroll and lastOrder then
		-- The chosen item stays even when it no longer passes the filters.
		local chosen = market and state.selectedKey and market.byKey[state.selectedKey]
		if chosen and lastOrder[chosen.key] then
			local listed = false
			for _, item in ipairs(items) do
				listed = listed or item == chosen
			end
			if not listed then
				items[#items + 1] = chosen
			end
		end
		Kit.SortRows(items, function(item)
			return lastOrder[item.key] or math.huge
		end, false)
	else
		Kit.SortRows(items, SORT_VALUES[state.sort.id], state.sort.descending)
	end
	lastOrder = {}
	for index, item in ipairs(items) do
		lastOrder[item.key] = index
	end
	local rows = {}
	for _, item in ipairs(items) do
		rows[#rows + 1] = item
		if item.key == state.openKey then
			for _, row in ipairs(PriceRows(item)) do
				rows[#rows + 1] = row
			end
		end
	end
	list:SetSort(state.sort.id, state.sort.descending)
	list:SetRows(rows, keepScroll)
end

-- ========= The order panel ==================================================
local parts = {}
local PaintStats -- defined below PaintOrder, which calls it
local stack

-- The order as it stands: for a single item, the auction at the price picked
-- in the list when one was picked, else from the cheapest up.
local function Filled(item)
	if state.selectedUnit and not ns.Orders.IsCommodity(item) then
		local picked = ns.Orders.FillAt(item, state.selectedUnit)
		if picked then
			return picked
		end
	end
	return ns.Orders.Fill(item, state.wanted)
end

-- One incoming purchase, as "Name (Slot, price, when)".
local function IncomingText(bought, now)
	return L.BUY_INCOMING_ITEM:format(bought.name, ns.PlainMoney(bought.amount or 0), ns.Ago(math.max(0, now - bought.time)))
end

-- With nothing picked: what to do, and the gear already on its way.
local function PickPrompt()
	local all = ns.Incoming:All()
	if #all == 0 then
		return L.BUY_PICK
	end
	local names, now = {}, GetServerTime()
	for _, bought in ipairs(all) do
		names[#names + 1] = L.BUY_INCOMING_SLOT:format(bought.name, _G[bought.equipLoc] or bought.equipLoc, ns.PlainMoney(bought.amount or 0))
	end
	return L.BUY_PICK .. "\n\n" .. L.BUY_INCOMING_ALL:format(table.concat(names, ", "))
end

-- What the Buy button says: how many and what they cost in all, never a
-- count beside a price of each, which reads as that many at that price.
-- Goods: the whole order. A single item: its cheapest auction, whole.
local function BuyLabel(filled)
	local count, total
	if filled.byUnit then
		count, total = filled.units, filled.cost
	else
		local first = filled.lines[1]
		if not first then
			return L.BUY_BUTTON_AUCTION
		end
		count, total = first.tier.stack or 1, first.tier.buyout
	end
	if count == 1 then
		return L.BUY_BUTTON_ONE:format(ns.PlainMoney(total))
	end
	return L.BUY_BUTTON_MANY:format(ns.Comma(count), ns.PlainMoney(total))
end

local DrawOrder
local function PaintOrder()
	stack:Paint(DrawOrder)
end
DrawOrder = function()
	local item = market and state.selectedKey and market.byKey[state.selectedKey]
	prompt:SetShown(item == nil)
	-- A live check can find that what was chosen has gone since the scan.
	prompt:SetBody(state.gone and L.BUY_GONE:format(state.gone) or PickPrompt())
	if not item then
		return
	end

	local filled = Filled(item)
	local deal = ns.Signals:Deal(item, filled.units, filled.cost)
	local gold = GetMoney()
	local overBudget = filled.cost > gold

	parts.icon:SetIcon(item.icon)
	parts.name:SetText(item.name)
	parts.name:SetTextColor(unpack(Kit.QualityColor(item.quality)))
	parts.available:SetText(L.BUY_AVAILABLE:format(ns.Comma(item.units)))
	stack:Add(parts.head)

	-- Gear bought this session for the same slot, still in the mail.
	local incoming = item.equipLoc and ns.Incoming:ForSlot(item.equipLoc) or {}
	if #incoming > 0 then
		local names, now = {}, GetServerTime()
		for _, bought in ipairs(incoming) do
			names[#names + 1] = IncomingText(bought, now)
		end
		parts.incoming:SetBody(L.BUY_INCOMING:format(table.concat(names, ", ")))
		stack:Add(parts.incoming, 4)
	end

	-- The price that was picked has gone since the scan: say so in two words,
	-- and what changed when hovered.
	if state.goneUnit then
		parts.changed.detail = L.BUY_PRICE_WENT:format(ns.PlainMoney(state.goneUnit), ns.Comma(item.units), ns.PlainMoney(item.min or 0))
		parts.changed:SetBody(L.BUY_PRICES_UPDATED, C.bad)
		stack:Add(parts.changed, 6)
	end

	parts.quantity:SetValue(tostring(state.wanted))
	stack:Add(parts.quantityRow, 8)
	-- Goods bought by the unit can be had in whole stacks with one press.
	local stackSize = ns.Orders.IsCommodity(item) and ns.MaxStack(item.itemID)
	if stackSize and stackSize > 1 then
		for index, count in ipairs(ns.BuyStackPresets) do
			local button = parts.stackButtons[index]
			local units = count * stackSize
			button.units = units
			button:SetDisabled(units > item.units)
			button.tipLines = { button.label:GetText(), L.BUY_STACKS_TIP:format(ns.Comma(units), ns.Comma(stackSize)),
				units > item.units and L.BUY_STACKS_SHORT:format(ns.Comma(item.units)) or nil }
		end
		stack:Add(parts.stackRow, 4)
	end
	stack:Add(parts.rule1, 8)
	parts.total:Set(L.BUY_TOTAL, ns.Money(filled.cost))
	stack:Add(parts.total, 6)
	parts.average:Set(L.BUY_AVERAGE, ns.Money(filled.averageUnit))
	stack:Add(parts.average, 4)

	-- The deal: a meter and what the order saves. With too few auctions to
	-- know the usual price there is no meter, only a note saying so.
	if deal.known then
		parts.dealMeter:SetReading(deal)
		stack:Add(parts.deal, 2)
		parts.saving:Set(deal.saving >= 0 and L.BUY_SAVE or L.BUY_EXTRA, ns.Money(math.abs(deal.saving)))
		parts.saving.right:SetTextColor(unpack(deal.saving >= 0 and C.good or C.bad))
		stack:Add(parts.saving, 2)
	end
	parts.dealNote:SetBody(deal.reasons[1])
	stack:Add(parts.dealNote, 3)

	if filled.short > 0 then
		parts.warning:SetBody(L.BUY_SHORT:format(ns.Comma(filled.units)), C.bad)
		stack:Add(parts.warning, 3)
	elseif filled.units ~= state.wanted then
		parts.warning:SetBody(L.BUY_GET_MORE:format(ns.Comma(filled.units)))
		stack:Add(parts.warning, 3)
	end
	if overBudget then
		parts.budget:SetBody(L.BUY_OVER_BUDGET, C.bad)
		stack:Add(parts.budget, 3)
	end

	stack:Add(parts.rule2, 8)
	for index = 1, ORDER_LINES do
		local line = filled.lines[index]
		if line then
			local what = filled.byUnit and L.BUY_LINE_UNITS:format(ns.Comma(line.units))
				or L.BUY_LINE_STACKS:format(ns.Comma(line.auctions), ns.Comma(line.tier.stack))
			parts.lines[index]:Set(what, L.EACH:format(ns.Money(line.tier.unit)))
			stack:Add(parts.lines[index], index == 1 and 6 or 0)
		end
	end
	if #filled.lines > ORDER_LINES then
		parts.more:SetBody(L.BUY_MORE_LINES:format(#filled.lines - ORDER_LINES))
		stack:Add(parts.more, 2)
	end

	-- The button follows a purchase as it goes: check the price, confirm, done.
	local buying = ns.Buying.state
	local mine = buying.key == item.key and buying.phase ~= "idle"
	-- "Confirm" only when the price is not what the button said: unchanged, the
	-- button keeps its words and the next press buys.
	local unchanged = mine and buying.phase == "confirm" and (filled.byUnit and buying.total == filled.cost
		or not filled.byUnit and filled.lines[1] ~= nil and buying.unit == filled.lines[1].tier.unit and (buying.quantity or 1) == (filled.lines[1].tier.stack or 1))
	if unchanged then
		-- The press checked the price and bought nothing (the game only buys
		-- on a press, and the check could not be skipped). Same price, but the
		-- button must not look as if the press went through.
		parts.buy:SetLabel(L.BUY_PRESS_AGAIN:format((BuyLabel(filled):gsub("^%u", string.lower))))
		parts.buy:SetDisabled(buying.total > gold)
	elseif mine and buying.phase == "confirm" then
		-- A single item's auction is all or nothing: say "stack of" so a stack
		-- of 94 is not read as 94 single purchases.
		local count = buying.quantity or 1
		local label = count == 1 and L.BUY_CONFIRM_ONE:format(ns.PlainMoney(buying.total))
			or (filled.byUnit and L.BUY_CONFIRM_BUTTON or L.BUY_CONFIRM_STACK):format(ns.Comma(count), ns.PlainMoney(buying.total))
		parts.buy:SetLabel(label)
		parts.buy:SetDisabled(buying.total > gold)
	elseif mine and (buying.phase == "quoting" or buying.phase == "buying") then
		parts.buy:SetLabel(buying.message)
		parts.buy:SetDisabled(true)
	elseif filled.byUnit then
		parts.buy:SetLabel(BuyLabel(filled))
		parts.buy:SetDisabled(overBudget or filled.units == 0)
	else
		-- A single item is bought one auction at a time, the cheapest first.
		local first = filled.lines[1]
		parts.buy:SetLabel(BuyLabel(filled))
		parts.buy:SetDisabled(not first or first.tier.buyout > gold)
	end
	stack:Add(parts.buy, 10)
	parts.buyStatus:SetShown(mine)
	if mine then
		local tone = buying.phase == "failed" and C.bad or (buying.phase == "done" and C.good or C.muted)
		local message = buying.message or ""
		if buying.phase == "confirm" and (buying.total or 0) > gold then
			-- The button is greyed out: say why, or it only looks broken.
			message, tone = L.BUY_CONFIRM_OVER_GOLD:format(ns.PlainMoney(buying.total), ns.PlainMoney(gold)), C.bad
		elseif unchanged and message == L.BUY_CONFIRM_PRICE then
			message = L.BUY_CHECKED_SAME
		elseif buying.phase == "confirm" and not filled.byUnit and (buying.quantity or 1) > 1 and message == L.BUY_CONFIRM_PRICE then
			message = L.BUY_CONFIRM_STACK_NOTE:format(ns.Comma(buying.quantity), ns.Comma(buying.quantity))
		elseif buying.phase == "confirm" and message == L.BUY_CONFIRM_PRICE then
			message = L.BUY_CONFIRM_CHANGED
		end
		parts.buyStatus:SetBody(message, tone)
		stack:Add(parts.buyStatus, 4)
	end
	PaintStats(item)

	local how = L.BUY_BY_UNIT
	if not filled.byUnit then
		how = filled.purchases == 1 and L.BUY_ONE_AUCTION or L.BUY_AUCTIONS:format(ns.Comma(filled.purchases), ns.Comma(filled.purchases))
	end
	-- How the purchase will go is in the button's tooltip, not under it.
	parts.buy.how = how
	parts.buy.note = filled.byUnit and L.BUY_HOW or L.BUY_HOW_AUCTION
end

-- Under the Buy button: what the scans show about the item (the tooltip's
-- lines and more), then every price it is listed at now with how many are at
-- each. The list of prices takes whatever room is left, and no more.
function PaintStats(item)
	stack:Add(parts.rule3, 10)
	parts.statsHead:Set(L.STAT_HEADING, "")
	stack:Add(parts.statsHead, 6)
	local shown = 0
	for _, rules in ipairs({ ns.TooltipLines, ns.ItemStatLines }) do
		for _, line in ipairs(ns.ItemTooltip:Lines(item.itemID, item.name, rules, true)) do
			if shown < STAT_LINES then
				shown = shown + 1
				parts.stats[shown]:Set(line[1], line[2])
				stack:Add(parts.stats[shown], 1)
			end
		end
	end

	local points = ns.Market.PricePoints(item)
	stack:Add(parts.rule4, 8)
	parts.ladderHead:Set(L.STAT_FOR_SALE, L.STAT_FOR_SALE_COUNT:format(ns.Comma(item.units)))
	stack:Add(parts.ladderHead, 6)
	-- How fresh these prices are: checked live, being checked, or the scan's.
	local check = ns.LiveCheck.state
	local now = GetServerTime()
	local from
	if check.itemID == item.itemID and (check.phase == "waiting" or check.phase == "sent") then
		from = L.STAT_CHECKING
	elseif item.checkedAt then
		from = L.STAT_CHECKED:format(ns.Ago(math.max(0, now - item.checkedAt)))
	else
		from = L.STAT_FROM_SCAN:format(ns.Ago(math.max(0, now - (market.time or now))))
	end
	-- A check that failed says so, and why: stale prices should not pass as checked.
	local problem = ns.LiveCheck.problem
	if problem and problem.itemID == item.itemID and not item.checkedAt then
		from = problem.text
	end
	parts.ladderFrom:Set(from, "")
	stack:Add(parts.ladderFrom, 0)
	-- How many rows fit above the bottom of the panel, keeping one for "and more".
	local room = math.floor(((order:GetHeight() or 0) - stack.y - 8) / LADDER_ROW_HEIGHT)
	local rows = math.max(1, math.min(LADDER_ROWS, room))
	if #points > rows then
		rows = math.max(1, rows - 1)
	end
	local most = 1
	for index = 1, math.min(rows, #points) do
		most = math.max(most, points[index].units)
	end
	for index = 1, math.min(rows, #points) do
		local point, row = points[index], parts.ladder[index]
		row:Set(ns.Money(point.unit), ns.Comma(point.units))
		row.bar:SetWidth(math.max(2, math.floor(LADDER_BAR * point.units / most)))
		stack:Add(row, 0)
	end
	if #points > rows then
		parts.ladderMore:Set(L.STAT_MORE_PRICES:format(ns.Comma(#points - rows), ns.Money(points[#points].unit)), "")
		stack:Add(parts.ladderMore, 0)
	end
end

local function SetWanted(value)
	ns.Buying:Cancel() -- a price check is for one quantity
	state.selectedUnit = nil -- a typed quantity is no longer "up to this price"
	local item = market and market.byKey[state.selectedKey]
	state.wanted = math.max(1, math.floor(value or 1))
	if item then
		state.wanted = math.min(state.wanted, math.max(1, item.units))
	end
	PaintOrder()
end

local function BuildOrder(parent)
	local width = Theme.buy.order - 16
	stack = Kit.Stack(parent, 8)

	prompt = Kit.Note(parent, "normal", C.muted, "CENTER")
	prompt:SetPoint("TOPLEFT", 16, -30)
	prompt:SetPoint("TOPRIGHT", -16, -30)
	prompt:SetWidth(width - 16)
	prompt:SetBody(PickPrompt())

	parts.head = CreateFrame("Frame", nil, parent)
	parts.head:SetHeight(34)
	parts.icon = Kit.Icon(parts.head, 32)
	parts.icon:SetPoint("LEFT")
	parts.name = Kit.Text(parts.head, "normal")
	parts.name:SetPoint("TOPLEFT", 40, -2)
	parts.name:SetPoint("RIGHT")
	parts.available = Kit.Text(parts.head, "small", C.muted)
	parts.available:SetPoint("BOTTOMLEFT", 40, 2)

	parts.quantityRow = CreateFrame("Frame", nil, parent)
	parts.quantityRow:SetHeight(26)
	local label = Kit.Text(parts.quantityRow, "normal", C.muted)
	label:SetPoint("LEFT")
	label:SetText(L.BUY_QUANTITY)
	local minus = Kit.Button(parts.quantityRow, { text = "-", width = 26, height = 26, onClick = function()
		SetWanted(state.wanted - 1)
	end })
	minus:SetPoint("LEFT", 62, 0)
	parts.quantity = Kit.Input(parts.quantityRow, { width = 64, height = 26, numeric = true, justify = "RIGHT", maxLetters = 6, onNumber = SetWanted })
	parts.quantity:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	local plus = Kit.Button(parts.quantityRow, { text = "+", width = 26, height = 26, onClick = function()
		SetWanted(state.wanted + 1)
	end })
	plus:SetPoint("LEFT", parts.quantity, "RIGHT", 4, 0)
	local all = Kit.Button(parts.quantityRow, { text = L.SELL_ALL, height = 26, onClick = function()
		local item = market and market.byKey[state.selectedKey]
		SetWanted(item and item.units or 1)
	end })
	all:SetPoint("LEFT", plus, "RIGHT", 4, 0)

	-- Whole stacks, under the quantity: 1, 2, 5 (ns.BuyStackPresets).
	parts.stackRow = CreateFrame("Frame", nil, parent)
	parts.stackRow:SetHeight(22)
	parts.stackButtons = {}
	local previous
	for index, count in ipairs(ns.BuyStackPresets) do
		local button
		button = Kit.Button(parts.stackRow, {
			text = count == 1 and L.BUY_STACKS_ONE or L.BUY_STACKS_MANY:format(count),
			height = 22,
			size = "small",
			tip = function()
				return button.tipLines
			end,
			onClick = function()
				SetWanted(button.units)
			end,
		})
		if previous then
			button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
		else
			button:SetPoint("LEFT", 62, 0)
		end
		parts.stackButtons[index] = button
		previous = button
	end

	local function Rule()
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetHeight(1)
		Kit.Fill(holder, C.line)
		return holder
	end
	parts.rule1, parts.rule2, parts.rule3, parts.rule4 = Rule(), Rule(), Rule(), Rule()

	-- The scan facts and the list of prices under the Buy button.
	parts.statsHead = Kit.Pair(parent, "normal", C.accent)
	parts.ladderHead = Kit.Pair(parent, "normal", C.accent)
	parts.stats, parts.ladder = {}, {}
	for index = 1, STAT_LINES do
		parts.stats[index] = Kit.Pair(parent, "small")
		parts.stats[index]:SetHeight(LADDER_ROW_HEIGHT)
	end
	for index = 1, LADDER_ROWS do
		local row = Kit.Pair(parent, "small", C.text)
		row:SetHeight(LADDER_ROW_HEIGHT)
		-- A bar for how many are at the price, against the most at any price shown.
		row.bar = row:CreateTexture(nil, "ARTWORK")
		row.bar:SetColorTexture(unpack(C.accent))
		row.bar:SetAlpha(0.35)
		row.bar:SetHeight(LADDER_ROW_HEIGHT - 6)
		row.bar:SetPoint("LEFT", LADDER_BAR_AT, 0)
		parts.ladder[index] = row
	end
	parts.ladderFrom = Kit.Pair(parent, "small")
	parts.ladderFrom:SetHeight(LADDER_ROW_HEIGHT)
	parts.ladderMore = Kit.Pair(parent, "small")
	parts.ladderMore:SetHeight(LADDER_ROW_HEIGHT)

	parts.total = Kit.Pair(parent, "total", C.text)
	parts.total:SetHeight(22)
	parts.average = Kit.Pair(parent)
	parts.deal = Kit.Pair(parent)
	parts.deal.left:SetText(L.BUY_DEAL)
	parts.dealMeter = Kit.Meter(parts.deal, ns.DealPips)
	parts.dealMeter:SetPoint("RIGHT")
	parts.deal:EnableMouse(true)
	Kit.Tip(parts.deal, function()
		local item = market and market.byKey[state.selectedKey]
		if not item then
			return nil
		end
		local filled = ns.Orders.Fill(item, state.wanted)
		local deal = ns.Signals:Deal(item, filled.units, filled.cost)
		return deal.known and { deal.level.label, unpack(deal.reasons) } or nil
	end)
	parts.saving = Kit.Pair(parent)

	local function Note()
		local note = Kit.Note(parent, "small", C.muted)
		note:SetWidth(width)
		return note
	end
	parts.dealNote, parts.warning, parts.budget, parts.more, parts.buyStatus = Note(), Note(), Note(), Note(), Note()
	parts.incoming = Note()
	parts.incoming:EnableMouse(true)
	Kit.Tip(parts.incoming, function()
		return { L.BUY_INCOMING_TIP }
	end)
	parts.changed = Note()
	parts.changed:EnableMouse(true)
	Kit.Tip(parts.changed, function(self)
		return { L.BUY_PRICES_UPDATED, self.detail }
	end)

	parts.lines = {}
	for index = 1, ORDER_LINES do
		parts.lines[index] = Kit.Pair(parent, "small")
		parts.lines[index]:SetHeight(16)
	end

	-- One press does one thing: the first asks the server for the live price,
	-- the second buys at it. A single item is one auction per pair of presses.
	parts.buy = Kit.Button(parent, { text = "", look = "action", height = 32, width = width, onClick = function()
		local item = market and state.selectedKey and market.byKey[state.selectedKey]
		local filled = item and Filled(item)
		if not filled or filled.units == 0 then
			return
		end
		local buying = ns.Buying.state
		if buying.phase == "confirm" and buying.key == item.key then
			ns.Buying:Confirm()
		elseif filled.byUnit then
			ns.Buying:Start({ key = item.key, itemID = item.itemID, quantity = filled.units })
		else
			-- Buy at the price shown on the button, and only at that price.
			ns.Buying:Start({
				key = item.key,
				itemID = item.itemID,
				name = item.name,
				single = true,
				price = filled.lines[1].tier.unit,
				-- A live check a moment ago saves asking again.
				live = item.liveAuctions,
				checkedAt = item.checkedAt,
			})
		end
	end })
	Kit.Tip(parts.buy, function(self)
		return { L.TAB_BUY, self.how, self.note }
	end)
end

-- ========= The tab ==========================================================
Refresh = function(keepScroll)
	Prepare()
	local _, reason = ns.Window:Market()
	list:SetEmptyText(market and L.BUY_NOTHING or reason)
	for _, button in pairs(toggleButtons) do
		button:SetActive(state.toggles[button.id] == true)
	end
	if market and state.selectedKey and not market.byKey[state.selectedKey] then
		state.selectedKey = nil
	end
	PaintRail()
	PaintSidebar()
	PaintList(keepScroll)
	PaintOrder()
end

local function Create(parent)
	local pad = Theme.pad
	rail = Kit.Panel(parent)
	rail:SetPoint("TOPLEFT")
	rail:SetPoint("BOTTOMLEFT")
	rail:SetWidth(Theme.buy.rail)
	-- The tiles sit in a view the height of the rail, and scroll in it.
	railView = CreateFrame("Frame", nil, rail)
	railView:SetPoint("TOPLEFT", 1, -1)
	railView:SetPoint("BOTTOMRIGHT", -1, 1)
	railView:SetClipsChildren(true)
	railContent = CreateFrame("Frame", nil, railView)
	railContent:SetHeight(1)
	railView:EnableMouseWheel(true)
	railView:SetScript("OnMouseWheel", function(_, delta)
		ScrollRail(railScroll - delta * (TileSize() + TILE_GAP) * Theme.railWheelTiles)
	end)
	-- A window made taller or shorter changes how far the rail can scroll.
	railView:SetScript("OnSizeChanged", function()
		if facets then
			ScrollRail(railScroll)
		end
	end)
	-- The fades sit on a layer above the tiles.
	local edges = CreateFrame("Frame", nil, railView)
	edges:SetAllPoints()
	edges:SetFrameLevel(railContent:GetFrameLevel() + 10)
	local clear = { C.panel[1], C.panel[2], C.panel[3], 0 }
	railFades = {
		top = Kit.Gradient(edges, C.panel, clear, "OVERLAY"),
		bottom = Kit.Gradient(edges, clear, C.panel, "OVERLAY"),
	}
	for side, fade in pairs(railFades) do
		fade:ClearAllPoints()
		fade:SetPoint(side == "top" and "TOPLEFT" or "BOTTOMLEFT")
		fade:SetPoint(side == "top" and "TOPRIGHT" or "BOTTOMRIGHT")
		fade:SetHeight(Theme.railFade)
		fade:Hide()
	end

	-- The strip between the rail and the filters: one click makes the rail's
	-- icons bigger, another puts them back.
	local widen = CreateFrame("Button", nil, parent)
	widen:SetPoint("TOPLEFT", rail, "TOPRIGHT")
	widen:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT")
	widen:SetWidth(pad)
	widen.glow = Kit.Fill(widen, C.rowHover)
	widen.glow:Hide()
	widen.arrow = Kit.Text(widen, "small", C.accent, "CENTER")
	widen.arrow:SetPoint("CENTER")
	local function PaintWiden()
		widen.arrow:SetText(ns.IsEnabled("railLarge") and "<" or ">")
	end
	widen.onHover = function(self, over)
		self.glow:SetShown(over)
	end
	Kit.Tip(widen, function()
		return { ns.IsEnabled("railLarge") and L.BUY_RAIL_SMALLER or L.BUY_RAIL_BIGGER }
	end)
	widen:SetScript("OnClick", function()
		ns.SetEnabled("railLarge", not ns.IsEnabled("railLarge"))
		PaintWiden()
	end)
	ns.Bus:On("SETTING_CHANGED", PaintWiden)
	PaintWiden()

	local side = Kit.Panel(parent)
	side:SetPoint("TOPLEFT", rail, "TOPRIGHT", pad, 0)
	side:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", pad, 0)
	side:SetWidth(Theme.buy.sidebar)
	sidebar = Kit.Scroll(side)
	sidebar:SetPoint("TOPLEFT", 8, -8)
	sidebar:SetPoint("BOTTOMRIGHT", -8, 8)
	clearButton = Kit.Button(sidebar.content, { text = L.CLEAR_ALL, size = "small", height = 22, width = 100, onClick = function()
		state.selection = {}
		Refresh()
	end })

	order = Kit.Panel(parent)
	order:SetPoint("TOPRIGHT")
	order:SetPoint("BOTTOMRIGHT")
	order:SetWidth(Theme.buy.order)
	Kit.Split(order, { id = "buy.order", edge = "LEFT", min = Theme.buy.order, max = Theme.buy.order + Theme.panelGrow, onChange = function()
		ns.Window:RefreshActive()
	end })
	BuildOrder(order)

	-- The search box and the quick toggles share one row.
	toolbar = CreateFrame("Frame", nil, parent)
	toolbar:SetPoint("TOPLEFT", side, "TOPRIGHT", pad, 0)
	toolbar:SetPoint("TOPRIGHT", order, "TOPLEFT", -pad, 0)
	toolbar:SetHeight(26)
	local right
	for index = #ns.BuyToggles, 1, -1 do
		local toggle = ns.BuyToggles[index]
		local button = Kit.Button(toolbar, { text = toggle.label, height = 26, padding = 12, tip = { toggle.label, toggle.tip }, onClick = function()
			state.toggles[toggle.id] = not state.toggles[toggle.id]
			if state.toggles[toggle.id] then
				if toggle.sort then
					state.sort = { id = toggle.sort.id, descending = toggle.sort.descending }
				end
				for _, id in ipairs(toggle.turnsOn or {}) do
					state.toggles[id] = true
				end
			end
			Refresh()
		end })
		button.id = toggle.id
		if right then
			button:SetPoint("RIGHT", right, "LEFT", -5, 0)
		else
			button:SetPoint("RIGHT")
		end
		right = button
		toggleButtons[toggle.id] = button
	end
	searchBox = Kit.Input(toolbar, { height = 26, placeholder = L.BUY_SEARCH, onChange = function(text)
		state.search = text
		PaintList()
	end })
	searchBox:SetPoint("LEFT")
	searchBox:SetPoint("RIGHT", right, "LEFT", -5, 0)

	list = Kit.List(parent, {
		id = "buy",
		gap = 6, -- the number columns sit close, as thin as they can
		columns = {
			{
				id = "name",
				label = L.BUY_COL_ITEM,
				flex = true,
				icon = function(row)
					return row.icon
				end,
				text = function(row)
					if row.point then
						return L.BUY_ROW_PRICE
					elseif row.more then
						return L.BUY_ROW_MORE:format(ns.Comma(row.more), ns.Money(row.upTo))
					end
					return row.name
				end,
				color = function(row)
					if row.item then
						return C.muted
					end
					return Kit.QualityColor(row.quality)
				end,
			},
			-- Level, for sale, from and gain fit their widest text, no wider.
			{ id = "level", label = L.BUY_COL_LEVEL, width = 44, fixed = true, fit = true, align = "RIGHT", text = function(row)
				return not row.item and row.levelType == "REQ_LEVEL_ABBR" and tostring(row.level or "") or ""
			end },
			-- An item's row gives the total and the lowest price. Its price rows
			-- give how many are at each price.
			{ id = "units", label = L.BUY_COL_AVAILABLE, width = 64, fixed = true, fit = true, align = "RIGHT", text = function(row)
				if row.more then
					return ""
				end
				return ns.Comma(row.point and row.point.units or row.units)
			end },
			{ id = "min", label = L.BUY_COL_FROM, width = 96, fixed = true, fit = true, align = "RIGHT", text = function(row)
				if row.more then
					return ""
				end
				return ns.Money(row.point and row.point.unit or row.min)
			end },
			-- How much better than what you wear for gear, in weighted stat
			-- points; for a bag, how many more slots than the one it replaces.
			{ id = "gain", label = L.BUY_COL_GAIN, width = 48, fixed = true, fit = true, hideEmpty = true, align = "RIGHT", text = function(row)
				if row.item then
					return ""
				end
				local slots = bagGainOf and bagGainOf(row)
				if slots then
					return slots > 0 and L.BUY_GAIN_SLOTS:format(slots) or ""
				end
				local gain = SORT_VALUES.gain(row)
				return gain and ("+%.1f"):format(gain) or ""
			end },
			-- A letter beside gear for a slot you already bought for, still in
			-- the mail. The column only shows while something is incoming.
			{ id = "incoming", label = ns.IncomingRule.icon, width = 18, fixed = true, hideEmpty = true, sortable = false, align = "CENTER", text = function(row)
				if row.item or not row.equipLoc then
					return ""
				end
				return #ns.Incoming:ForSlot(row.equipLoc) > 0 and ns.IncomingRule.icon or ""
			end },
			-- Four characters (-99%) and a little padding, independent of the header.
			{ id = "deal", label = L.BUY_COL_DEAL, labelColor = C.good, width = 32, fixed = true, align = "RIGHT", badge = function(row)
				local deal = row.deal
				if row.item then
					-- Each price is judged by itself: the cheap one may be a deal
					-- and the rest not.
					deal = row.point and row.item.deal and DealAt(row.item, row.point.unit)
				end
				if deal and deal >= ns.DealBadgeRule.percent then
					return "-" .. deal .. "%"
				end
			end },
		},
		empty = L.BUY_NOTHING,
		onClick = function(row)
			if row.more then
				return
			end
			ns.Buying:Cancel() -- a price check is for one item at one price
			if row.point then
				-- A price under an opened item: this is the one to buy.
				local item = row.item
				state.selectedKey, state.selectedName, state.gone = item.key, item.name, nil
				state.selectedUnit = row.point.unit
				state.seenUnit, state.goneUnit = row.point.unit, nil
				if ns.Orders.IsCommodity(item) then
					-- Start at one: the quantity box adds more, and goods are
					-- always filled from the cheapest up.
					state.wanted = 1
				end
			else
				-- An item: open it to show every price, or close it again.
				local item = row
				local reopen = state.openKey ~= item.key
				state.openKey = reopen and item.key or nil
				state.selectedKey, state.selectedName, state.gone = item.key, item.name, nil
				state.selectedUnit = nil
				state.seenUnit, state.goneUnit = item.min, nil
				state.wanted = 1
				-- When the scan is no longer fresh, ask what the item looks like now.
				-- A single item is asked about again unless checked a moment ago,
				-- so pressing Buy can buy it in one press.
				ns.LiveCheck:Request(item, not ns.Orders.IsCommodity(item) and not ns.LiveCheck:FreshForBuying(item))
			end
			PaintList(true)
			PaintOrder()
		end,
		isSelected = function(row)
			if row.point then
				return row.item.key == state.selectedKey and row.point.unit == state.selectedUnit
			end
			return not row.item and row.key == state.selectedKey and state.selectedUnit == nil
		end,
		link = function(row)
			return row.link
		end,
		onSort = function(id)
			if state.sort.id == id then
				state.sort.descending = not state.sort.descending
			else
				state.sort = { id = id, descending = id ~= "name" } -- numbers start largest first
			end
			PaintList()
		end,
	})
	list:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -6)
	list:SetPoint("BOTTOMRIGHT", order, "BOTTOMLEFT", -pad, 0)

	return { Refresh = function()
		Refresh(true)
	end }
end

ns.Window:RegisterTab({ id = "buy", label = L.TAB_BUY, order = 1, Create = Create })

-- The rail's icon size is a setting.
ns.Bus:On("SETTING_CHANGED", function(id)
	if id == "railLarge" and rail and ns.charDb.tab == "buy" then
		ns.Window:RefreshActive()
	end
end)

-- What you wear, your level or the Near level range changed.
ns.Bus:On("GEAR_CHANGED", function()
	if list and ns.charDb.tab == "buy" then
		ns.Window:RefreshActive()
	end
end)

-- A live check replaced an item's listings. The list is rebuilt from the
-- market, and if what was chosen is no longer for sale the panel says so.
ns.Bus:On("MARKET_PATCHED", function()
	facets = nil
	if state.selectedKey and market and not market.byKey[state.selectedKey] then
		state.gone, state.selectedKey, state.selectedUnit = state.selectedName, nil, nil
	end
	-- The price being looked at (the one picked, or the cheapest) may be gone too.
	local chosen = state.selectedKey and market and market.byKey[state.selectedKey]
	if chosen and state.seenUnit and not ns.Orders.FillAt(chosen, state.seenUnit) then
		state.goneUnit, state.selectedUnit, state.seenUnit = state.seenUnit, nil, chosen.min
	end
	if order and ns.charDb.tab == "buy" then
		ns.Window:RefreshActive()
	end
end)

-- The panel says when the chosen item is being checked.
ns.Bus:On("LIVE_CHECK_CHANGED", function()
	if order and ns.charDb.tab == "buy" then
		ns.Window:RefreshActive()
	end
end)

-- Gear was bought: the panel names it beside gear for the same slot.
ns.Bus:On("INCOMING_CHANGED", function()
	if order and ns.charDb.tab == "buy" then
		ns.Window:RefreshActive()
	end
end)

-- The order panel follows a purchase as it goes.
ns.Bus:On("BUYING_CHANGED", function(buying)
	-- What was just bought is no longer for sale: look again. The same after a
	-- purchase that did not go through, so the next press is not aimed at an
	-- auction that has since gone to someone else.
	local attempted = buying.phase == "done" or (buying.phase == "failed" and buying.auctionID ~= nil)
	if buying.phase == "failed" and buying.gone and market and buying.key and market.byKey[buying.key] then
		-- Nothing listed by its name any more: off the list it comes.
		ns.LiveCheck:Gone(market.byKey[buying.key])
	elseif attempted and market and buying.key and market.byKey[buying.key] then
		-- Bought: read the next auction from what the game already holds, so
		-- the next press buys at once. Otherwise, or after a failure, ask.
		local item = market.byKey[buying.key]
		if not (buying.phase == "done" and ns.LiveCheck:Reread(item, buying.auctionID)) then
			ns.LiveCheck:Request(item, true)
		end
	end
	if order and ns.charDb.tab == "buy" then
		ns.Window:RefreshActive()
	end
end)

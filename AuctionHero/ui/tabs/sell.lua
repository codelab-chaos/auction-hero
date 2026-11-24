-- Sell tab: your bags on the left, a price already filled in from a rule in
-- the middle, and the competition on the right with your auctions slotted in.
-- The layout and behavior follow the lab's concept (lab/src/ui/concept/sell.ts).
--
-- An item can sit in several bag slots (three stacks of leather). Picking any
-- of them picks the item, and the form works from the total across all of them.
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local LADDER_ROWS = 9
local HISTORY_LINES = 12 -- lines of price history under the competition, at most
local HISTORY_ROW_HEIGHT = 16
local HISTORY_GAP = 12
local BAG_COLUMNS = 4
local BAG_TOP = 56 -- below the title and the filters
local LABEL_WIDTH = 86 -- the name column of the form's control rows

local state = {
	key = nil, -- the chosen bag item
	saleType = "buyout",
	ruleId = ns.DefaultPriceRule,
	customUnit = nil, -- set when the player types a price
	customBid = nil, -- set when the player types a starting bid
	perAuction = 1,
	auctions = 1,
	duration = ns.DefaultDuration,
}

local bags, form, ladder, bagHint, formHint
local bagList, bagFilters
local bagTiles = {}
local gridEmpty -- says so when a filter leaves the grid empty
local parts, ladderRows = {}, {}
local stack
local Refresh, PaintForm, PaintLadder, PaintHistory, PaintSummary, PaintPostButton, PressPost, ChanceTip

-- ========= What is being sold ===============================================
local function Owned()
	return state.key and ns.Bags:Find(state.key)
end

-- Why there is no market to read yet (the scan is still being read, or there
-- is none), or nil when there is one.
local function MarketPending()
	local market, reason = ns.Window:Market()
	return not market and reason or nil
end

-- The market's view of the chosen item, or nil when nobody is selling it.
local function Listed()
	local market = ns.Window:Market()
	return market and state.key and market.byKey[state.key]
end

local function SaleType()
	for _, type in ipairs(ns.SaleTypes) do
		if type.id == state.saleType then
			return type
		end
	end
	return ns.SaleTypes[1]
end

-- Whether the chosen item is sold by the unit. The game's own answer wins
-- when the auction house is open to give one. Otherwise it is our best guess.
local function IsCommodity()
	local known = state.key and ns.Posting:IsCommodity(state.key)
	if known ~= nil then
		return known
	end
	local listed, owned = Listed(), Owned()
	return (listed or owned) ~= nil and ns.Orders.IsCommodity(listed or owned)
end

-- What past scans say the chosen item goes for (History:PastPrice), when
-- nobody is selling it in the scan now loaded. Nil when it is listed now or
-- no scan ever saw it.
local function Past()
	if not state.key or Listed() or not ns.Window:Market() then
		return nil
	end
	return ns.History:PastPrice(state.key)
end

local function UnitPrice()
	if state.customUnit then
		return state.customUnit
	end
	local listed = Listed()
	if not listed then
		-- Nobody selling it now: the price rules have nothing to read, so
		-- past scans go by (the warning under the form says so).
		local past = Past()
		if past and not IsCommodity() then
			return math.max(past.price, ns.MinItemPrice)
		end
		return past and past.price
	end
	for _, rule in ipairs(ns.PriceRules) do
		if rule.id == state.ruleId then
			local price = rule.price(listed, ns.History:Usual(listed))
			-- A rule never suggests less than the server will take.
			if price and not IsCommodity() then
				price = math.max(price, ns.MinItemPrice)
			end
			return price
		end
	end
end

-- True when a typed price is under what the server takes for a single item.
local function TooCheap()
	local unit = UnitPrice()
	return unit ~= nil and not IsCommodity() and unit < ns.MinItemPrice
end

local function StartingBid()
	if state.customBid then
		return state.customBid
	end
	local unit = UnitPrice()
	return unit and math.max(1, math.floor(unit * ns.StartingBidShare))
end

local function Choose(key)
	ns.Posting:Cancel()
	state.key = key
	ns.SellSearch:Request(key)
	state.customUnit, state.customBid = nil, nil
	local owned = Owned()
	local total = owned and owned.total or 1
	if IsCommodity() then
		-- A commodity is one listing of a quantity.
		state.perAuction, state.auctions = total, 1
	else
		-- Everything else is sold one to an auction.
		state.perAuction, state.auctions = 1, total
	end
	Refresh()
end

-- ========= Bags =============================================================
-- One row per item, its slots added up, grouped by kind under a heading
-- (ns.Bags:Grouped). A heading row is { heading = name } and cannot be picked.
-- The filter and sort picked, kept for the character.
local function BagView()
	ns.charDb.sellBags = ns.charDb.sellBags or { filter = "all" }
	return ns.charDb.sellBags
end

local function BagFilter()
	for _, filter in ipairs(ns.BagFilters) do
		if filter.id == BagView().filter then
			return filter
		end
	end
	return ns.BagFilters[1]
end

local function BuildBagList(parent)
	bagList = Kit.List(parent, {
		rowHeight = Theme.bagRow,
		columns = {
			{
				id = "name",
				label = L.SELL_BAGS_ITEM,
				flex = true,
				icon = function(row)
					return row.icon
				end,
				iconEdge = function(row)
					return row.quality and Kit.QualityColor(row.quality)
				end,
				text = function(row)
					return row.heading or row.name
				end,
				color = function(row)
					return row.heading and C.accent or Kit.QualityColor(row.quality)
				end,
			},
			{
				id = "count",
				label = L.SELL_BAGS_COUNT,
				fit = true,
				fixed = true,
				align = "RIGHT",
				text = function(row)
					return row.total and ns.Comma(row.total) or ""
				end,
			},
		},
		isSelected = function(row)
			return row.key ~= nil and row.key == state.key
		end,
		link = function(row)
			return row.link
		end,
		onClick = function(row)
			if row.key then
				Choose(row.key)
			end
		end,
		-- Sorting is within each group: name, then count, then back to the
		-- usual order (by kind, then name).
		onSort = function(columnId)
			local field = columnId == "count" and "total" or "name"
			local view, current = BagView(), BagView().sort
			if not current or current.field ~= field then
				view.sort = { field = field, descending = field == "total" }
			elseif current.descending == (field == "total") then
				view.sort = { field = field, descending = not current.descending }
			else
				view.sort = nil
			end
			ns.Window:RefreshActive()
		end,
	})
	return bagList
end

-- The grid: one tile per bag slot, in the list's order (same kinds
-- together), each framed in its item's rarity color.
local function BagTile(index)
	local tile = bagTiles[index]
	if not tile then
		tile = CreateFrame("Button", nil, bags)
		tile:SetSize(Theme.bagSlot, Theme.bagSlot)
		Kit.Fill(tile, C.input)
		tile.art = tile:CreateTexture(nil, "ARTWORK")
		tile.art:SetPoint("TOPLEFT", 2, -2)
		tile.art:SetPoint("BOTTOMRIGHT", -2, 2)
		tile.art:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		tile.border = Kit.Border(tile, C.inputBorder, "OVERLAY")
		tile.count = Kit.Text(tile, "small", C.white, "RIGHT")
		tile.count:SetPoint("BOTTOMRIGHT", -3, 2)
		tile:SetScript("OnClick", function(self)
			Choose(self.slot.item.key)
		end)
		tile:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if not pcall(GameTooltip.SetHyperlink, GameTooltip, self.slot.item.link) then
				GameTooltip:SetText(self.slot.item.name)
			end
			GameTooltip:Show()
		end)
		tile:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		bagTiles[index] = tile
	end
	return tile
end

local function PaintGrid(rows)
	for _, tile in ipairs(bagTiles) do
		tile:Hide()
	end
	if not rows then
		return
	end
	local step = Theme.bagSlot + 4
	local index = 0
	for _, row in ipairs(rows) do
		for _, slot in ipairs(row.slots or {}) do
			index = index + 1
			local tile = BagTile(index)
			local column, line = (index - 1) % BAG_COLUMNS, math.floor((index - 1) / BAG_COLUMNS)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", bags, "TOPLEFT", 8 + column * step, -(BAG_TOP + line * step))
			tile.slot = slot
			tile.art:SetTexture(slot.icon)
			tile.count:SetText(slot.count > 1 and slot.count or "")
			-- The chosen item is lit; the rest wear their rarity.
			local chosen = row.key == state.key
			tile.border:SetColor(chosen and C.accent or Kit.QualityColor(row.quality))
			tile:Show()
		end
	end
end

local function PaintBags()
	local view = BagView()
	local carried = #ns.Bags.items > 0
	local asList = ns.IsEnabled("sellBagList")
	bagHint:SetShown(not carried)
	bagFilters:SetShown(carried)
	bagFilters:Refresh()
	local sort = asList and view.sort or nil
	local rows = ns.Bags:Grouped({ classes = BagFilter().classes, sort = sort })
	bagList:SetShown(carried and asList)
	PaintGrid(carried and not asList and rows or nil)
	gridEmpty:SetShown(carried and not asList and #rows == 0)
	if asList then
		bagList:SetSort(sort and (sort.field == "total" and "count" or "name"), sort and sort.descending)
		bagList:SetEmptyText(L.SELL_BAGS_NONE_HERE)
		bagList:SetRows(rows, true)
	end
end

-- The first item in the list, for picking one when nothing is.
local function FirstItem()
	for _, row in ipairs(ns.Bags:Grouped()) do
		if row.key then
			return row
		end
	end
end

-- ========= The form =========================================================
-- A row with its name on the left: used for Sale, the sliders and Duration.
local function NamedRow(parent, name, height)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(height or 24)
	row.name = Kit.Text(row, "normal", C.accent)
	row.name:SetPoint("LEFT")
	row.name:SetText(name)
	return row
end

-- A slider with a box beside it to type the number, and how many there are
-- at most. Typing past the most posts the most; the box shows that once it
-- loses focus. :SetLimit(most, value) updates all three.
local function SliderRow(parent, name, onChange)
	local row = NamedRow(parent, name, 26)
	row.most, row.current = 1, 1
	row.value = Kit.Text(row, "normal", C.muted, "LEFT")
	row.value:SetPoint("RIGHT")
	row.value:SetWidth(64)
	local function Pick(number)
		number = math.max(1, math.min(row.most, number))
		row.current = number
		row.slider:SetShownValue(number)
		onChange(number)
	end
	row.input = Kit.Input(row, { width = 64, height = 26, numeric = true, justify = "RIGHT", maxLetters = 6, onNumber = Pick, onDone = function(box)
		box:SetValue(tostring(row.current))
	end })
	row.input:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
	row.slider = Kit.Slider(row, { onChange = function(number)
		row.current = number
		row.input:SetValue(tostring(number))
		onChange(number)
	end })
	row.slider:SetPoint("LEFT", LABEL_WIDTH, 0)
	row.slider:SetPoint("RIGHT", row.input, "LEFT", -10, 0)

	function row:SetLimit(most, value)
		self.most, self.current = math.max(1, most), value
		self.value:SetText(L.SELL_OF:format(ns.Comma(self.most)))
		self.slider:SetRange(self.most)
		self.slider:SetShownValue(value)
		if not self.input:HasFocus() then
			self.input:SetValue(tostring(value))
		end
	end
	return row
end

local function BuildForm(parent)
	stack = Kit.Stack(parent, 8)

	formHint = Kit.Note(parent, "normal", C.muted, "CENTER")
	formHint:SetPoint("TOPLEFT", 16, -30)
	formHint:SetPoint("TOPRIGHT", -16, -30)
	formHint:SetWidth(380)
	formHint:SetBody(L.SELL_PICK)

	parts.head = CreateFrame("Frame", nil, parent)
	parts.head:SetHeight(42)
	parts.icon = Kit.Icon(parts.head, 40)
	parts.icon:SetPoint("LEFT")
	parts.name = Kit.Text(parts.head, "large")
	parts.name:SetPoint("TOPLEFT", 48, -4)
	parts.name:SetPoint("RIGHT")
	parts.have = Kit.Text(parts.head, "small", C.muted)
	parts.have:SetPoint("BOTTOMLEFT", 48, 5)

	parts.saleRow = NamedRow(parent, L.SELL_SALE)
	parts.sale = Kit.Choices(parts.saleRow, {
		items = ns.SaleTypes,
		padding = 14,
		isActive = function(type)
			return type.id == state.saleType
		end,
		onPick = function(type)
			state.saleType = type.id
			ns.Posting:Cancel()
			Refresh()
		end,
	})
	parts.sale:SetPoint("LEFT", LABEL_WIDTH, 0)

	parts.priceLabel = CreateFrame("Frame", nil, parent)
	parts.priceLabel:SetHeight(14)
	parts.priceLabel.text = Kit.Text(parts.priceLabel, "normal", C.accent)
	parts.priceLabel.text:SetPoint("LEFT")

	-- Three boxes, like the game: gold, silver, copper. They start on the
	-- rule's price, and typing in any of them makes the price your own.
	parts.priceRow = CreateFrame("Frame", nil, parent)
	parts.priceRow:SetHeight(28)
	parts.price = Kit.MoneyInput(parts.priceRow, {
		onChange = function(copper)
			state.customUnit = math.max(1, copper)
			ns.Posting:Cancel()
			parts.rules:Refresh()
			PaintSummary()
			PaintLadder()
		end,
	})
	parts.price:SetPoint("LEFT")

	parts.rulesRow = CreateFrame("Frame", nil, parent)
	parts.rulesRow:SetHeight(24)
	parts.rules = Kit.Choices(parts.rulesRow, {
		items = ns.PriceRules,
		padding = 12,
		isActive = function(rule)
			return state.customUnit == nil and rule.id == state.ruleId
		end,
		onPick = function(rule)
			state.ruleId = rule.id
			ns.Posting:Cancel()
			state.customUnit = nil
			Refresh()
		end,
	})
	parts.rules:SetPoint("LEFT")

	-- How likely the price is to sell: the verdict, and what it is from.
	parts.chance = Kit.Pair(parent, "small")
	parts.chance:EnableMouse(true)
	Kit.Tip(parts.chance, function()
		return ChanceTip()
	end)

	-- With both a buy now price and bids, the starting bid gets its own entry.
	parts.bidRow = NamedRow(parent, L.SELL_STARTING_BID)
	parts.bid = Kit.MoneyInput(parts.bidRow, {
		compact = true,
		onChange = function(copper)
			state.customBid = math.max(1, copper)
			ns.Posting:Cancel()
			PaintSummary()
		end,
	})
	parts.bid:SetPoint("LEFT", LABEL_WIDTH, 0)
	local each = Kit.Text(parts.bidRow, "small", C.muted)
	each:SetPoint("LEFT", parts.bid, "RIGHT", 6, 0)
	each:SetText(L.SELL_EACH)

	-- Price confidence: one line and the facts under it. The reasons are in
	-- the tooltip.
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
		local reading = ns.Signals:Confidence(Listed())
		return { L.CONFIDENCE, unpack(reading.reasons) }
	end)

	parts.quantityRow = SliderRow(parent, L.SELL_QUANTITY, function(value)
		state.perAuction = value
		ns.Posting:Cancel()
		PaintSummary()
		PaintLadder()
	end)
	parts.auctionsRow = SliderRow(parent, L.SELL_AUCTIONS, function(value)
		state.auctions = value
		ns.Posting:Cancel()
		PaintSummary()
		PaintLadder()
	end)

	parts.durationRow = NamedRow(parent, L.SELL_DURATION)
	parts.duration = Kit.Choices(parts.durationRow, {
		items = ns.Durations,
		padding = 14,
		isActive = function(option)
			return option.index == state.duration
		end,
		onPick = function(option)
			state.duration = option.index
			ns.Posting:Cancel()
			PaintForm() -- the deposit depends on the duration
		end,
	})
	parts.duration:SetPoint("LEFT", LABEL_WIDTH, 0)

	parts.posting = Kit.Pair(parent)
	parts.rule = CreateFrame("Frame", nil, parent)
	parts.rule:SetHeight(1)
	Kit.Fill(parts.rule, C.line)
	parts.total = Kit.Pair(parent, "total", C.text)
	parts.total:SetHeight(22)
	parts.warning = Kit.Note(parent, "small", C.bad)
	parts.warning:SetWidth(400)
	parts.receive = Kit.Pair(parent)
	parts.receive:EnableMouse(true)
	Kit.Tip(parts.receive, { L.SELL_BUYOUT, L.SELL_RECEIVE_TIP })

	parts.deposit = Kit.Pair(parent)
	parts.post = Kit.Button(parent, { text = L.SELL_POST, look = "action", height = 32, width = 300, onClick = function()
		PressPost()
	end })
	parts.status = Kit.Note(parent, "small", C.muted)
	parts.status:SetWidth(400)
end

-- ========= Posting ==========================================================
-- The button says what the next press does: post, or confirm when the game
-- has asked for a second press.
PaintPostButton = function()
	local posting = ns.Posting.state
	local mine = posting.key == state.key
	if mine and posting.phase == "confirm" then
		parts.post:SetLabel(L.SELL_CONFIRM)
		parts.post:SetDisabled(false)
	elseif mine and posting.phase == "posting" then
		parts.post:SetLabel(L.SELL_POSTING_NOW)
		parts.post:SetDisabled(true)
	else
		parts.post:SetLabel(state.auctions > 1 and L.SELL_POST_MANY:format(ns.Comma(state.auctions)) or L.SELL_POST)
		parts.post:SetDisabled(UnitPrice() == nil or Owned() == nil)
	end
end

-- What pressing Post would send, or nil when there is nothing to send.
local function BuildRequest()
	local owned, unit = Owned(), UnitPrice()
	if not owned or not unit then
		return nil
	end
	if TooCheap() then
		return nil -- the form already says the price is too low
	end
	local type = SaleType()
	local commodity = IsCommodity()
	local bids = not commodity and type.bids
	if bids and type.buyout and (StartingBid() or 0) >= unit then
		return nil -- the form already says the bid is too high
	end
	return {
		key = owned.key,
		commodity = commodity,
		duration = state.duration,
		quantity = commodity and state.perAuction or state.auctions,
		unit = unit,
		bid = bids and type.buyout and StartingBid() or nil,
		buyout = commodity or type.buyout,
	}
end
ns.SellRequest = BuildRequest -- for the /ah post command

-- One press, one action: start the post, or confirm the one waiting.
PressPost = function()
	local posting = ns.Posting.state
	if posting.phase == "confirm" and posting.key == state.key then
		return ns.Posting:Confirm()
	end
	local request = BuildRequest()
	if request then
		ns.Posting:Post(request)
	end
end

-- ========= Chance to sell ===================================================
local function Chance()
	local listed = Listed()
	return listed and ns.SellChance:Judge(listed, UnitPrice(), state.perAuction * state.auctions, state.duration)
end

-- Only how many are listed at or under the price shows: a fact. The chance
-- to sell built on sales between scans is shelved (ns.TurnoverRule.shown).
local function PaintChance()
	local reading = Chance()
	if not reading then
		return
	end
	local ahead = reading.ahead > 0 and L.CHANCE_AHEAD:format(ns.Comma(reading.ahead)) or L.CHANCE_NONE_AHEAD
	local level = ns.TurnoverRule.shown and reading.level
	if ns.TurnoverRule.shown and reading.perDay and reading.sold > 0 then
		ahead = L.CHANCE_RATE:format(ahead, ns.Comma(math.max(1, math.floor(reading.perDay + 0.5))))
	end
	parts.chance:Set(level and level.label or L.CHANCE_UNKNOWN, ahead)
	parts.chance.left:SetTextColor(unpack(level and C[level.color] or C.muted))
end

ChanceTip = function()
	local reading = Chance()
	local lines = { L.CHANCE_TIP_HEAD }
	if reading then
		lines[#lines + 1] = L.CHANCE_TIP_AHEAD:format(ns.Comma(reading.ahead))
	end
	return lines
end

-- The numbers under the form. Redrawn alone while a slider moves.
PaintSummary = function()
	local owned = Owned()
	if not owned then
		return
	end
	local type = SaleType()
	local commodity = IsCommodity()
	local total = owned.total
	local posting = state.perAuction * state.auctions
	local unit = UnitPrice()

	parts.quantityRow:SetLimit(total, state.perAuction)
	parts.auctionsRow:SetLimit(math.floor(total / state.perAuction), state.auctions)
	PaintChance()
	PaintPostButton()
	local deposit = ns.Posting:Deposit(owned.key, commodity, state.duration, commodity and state.perAuction or state.auctions)
	parts.deposit:Set(L.SELL_DEPOSIT, deposit and ns.Money(deposit) or "")
	parts.deposit.known = deposit ~= nil

	local left = L.SELL_POSTING:format(ns.Comma(posting), ns.Comma(total))
	if posting < total then
		left = left .. L.SELL_KEEPING:format(ns.Comma(total - posting))
	end
	if not unit then
		parts.posting:Set(left, "")
		parts.total:Set(L.SELL_BUYOUT, "")
		parts.receive:Set("", "")
		parts.warning:SetBody(MarketPending() or L.SELL_NO_PRICE, C.muted)
		parts.warning:Show()
		return
	end

	local each = unit * state.perAuction
	local all = each * state.auctions
	local many = state.auctions > 1
	parts.posting:Set(left, many and L.SELL_EACH_AUCTION_PRICE:format(ns.Money(each)) or "")
	local totalLabel
	if type.buyout or commodity then
		totalLabel = many and L.SELL_ALL_BUYOUTS or L.SELL_BUYOUT
	else
		totalLabel = many and L.SELL_ALL_BIDS or L.SELL_BID
	end
	parts.total:Set(totalLabel, ns.Money(all))
	local cut = math.floor(ns.Assumptions.auctionCut * 100 + 0.5)
	local receiveLabel = (type.buyout or commodity) and L.SELL_RECEIVE or L.SELL_RECEIVE_BIDS
	parts.receive:Set(receiveLabel:format(cut), ns.Money(math.floor(all * (1 - ns.Assumptions.auctionCut))))

	local bid = StartingBid()
	local bidTooHigh = not commodity and type.buyout and type.bids and bid ~= nil and bid >= unit
	local tooCheap = TooCheap()
	local past = not state.customUnit and Past()
	parts.warning:SetShown(bidTooHigh or tooCheap or past ~= nil)
	if past then
		local when = ns.Ago(math.max(0, GetServerTime() - past.time))
		parts.warning:SetBody((past.typical and L.SELL_PAST_TYPICAL or L.SELL_PAST_LAST):format(when), C.muted)
	end
	if tooCheap then
		parts.warning:SetBody(L.SELL_TOO_CHEAP:format(ns.Money(ns.MinItemPrice)), C.bad)
	elseif bidTooHigh then
		parts.warning:SetBody(L.SELL_BID_TOO_HIGH, C.bad)
	end
end

local DrawForm
PaintForm = function()
	stack:Paint(DrawForm)
end
DrawForm = function()
	local owned = Owned()
	formHint:SetShown(owned == nil)
	if not owned then
		return
	end
	local listed = Listed()
	local type = SaleType()
	local commodity = IsCommodity()
	local total = owned.total

	parts.icon:SetIcon(owned.icon)
	parts.name:SetText(owned.name)
	parts.name:SetTextColor(unpack(Kit.QualityColor(owned.quality)))
	parts.have:SetText(#owned.slots > 1 and L.SELL_HAVE_STACKS:format(ns.Comma(total), #owned.slots) or L.SELL_HAVE:format(ns.Comma(total)))
	stack:Add(parts.head)

	-- Commodities are unit-price listings: no bids, and no splitting into auctions.
	if not commodity then
		parts.sale:Refresh()
		stack:Add(parts.saleRow, 8)
	end

	parts.priceLabel.text:SetText((type.buyout or commodity) and L.SELL_PRICE_EACH or L.SELL_BID_EACH)
	stack:Add(parts.priceLabel, 8)
	parts.price:SetAmount(UnitPrice() or 0)
	stack:Add(parts.priceRow, 4)
	parts.rules:Refresh()
	stack:Add(parts.rulesRow, 6)
	if listed then
		stack:Add(parts.chance, 4)
	end

	if not commodity and type.buyout and type.bids then
		parts.bid:SetAmount(StartingBid() or 0)
		stack:Add(parts.bidRow, 6)
	end

	local reading = ns.Signals:Confidence(listed)
	parts.confidenceMeter:SetReading(reading)
	parts.confidenceLevel:SetText(reading.level.label)
	parts.confidenceFacts:SetText(ns.Signals:ConfidenceLine(reading))
	stack:Add(parts.confidence, 8)

	if commodity then
		stack:Add(parts.quantityRow, 8)
	elseif total > 1 then
		stack:Add(parts.auctionsRow, 8)
	end

	parts.duration:Refresh()
	stack:Add(parts.durationRow, 8)
	stack:Add(parts.posting, 8)
	stack:Add(parts.rule, 4)
	stack:Add(parts.total, 4)
	PaintSummary()
	if parts.warning:IsShown() then
		stack:Add(parts.warning, 2)
	end
	stack:Add(parts.receive, 2)
	-- The deposit comes from the game, so it only shows with the auction house open.
	if parts.deposit.known then
		stack:Add(parts.deposit, 2)
	end
	stack:Add(parts.post, 10)
	local posting = ns.Posting.state
	if posting.message and posting.key == owned.key then
		parts.status:SetBody(posting.message, posting.phase == "failed" and C.bad or (posting.phase == "done" and C.good or C.muted))
		stack:Add(parts.status, 4)
	end
end

-- ========= The competition ==================================================
local function LadderRow(index)
	local row = ladderRows[index]
	if not row then
		row = Kit.Pair(ladder, "normal", C.text)
		row:SetHeight(20)
		row.fill = Kit.Fill(row, C.you)
		ladderRows[index] = row
	end
	return row
end

PaintLadder = function()
	for _, row in ipairs(ladderRows) do
		row:Hide()
	end
	local owned, listed = Owned(), Listed()
	parts.ladderKey:SetShown(owned ~= nil)
	parts.ladderNote:Hide()
	parts.ladderMarket:Hide()
	if not owned then
		return
	end
	local commodity = IsCommodity()
	local unit = UnitPrice()
	local y, used = 46, 0
	local function Add(left, right, you)
		used = used + 1
		local row = LadderRow(used)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", ladder, "TOPLEFT", 8, -y)
		row:SetPoint("TOPRIGHT", ladder, "TOPRIGHT", -8, -y)
		row:Set(left, right)
		row.fill:SetShown(you == true)
		row:Show()
		y = y + 21
	end
	local function You()
		local what = commodity and L.SELL_YOU_UNITS:format(ns.Comma(state.perAuction))
			or L.SELL_YOU:format(ns.Comma(state.auctions), ns.Comma(state.perAuction))
		Add(what, ns.Money(unit), true)
	end

	local placed, shown, unitsAhead = unit == nil, 0, 0
	for _, tier in ipairs(listed and listed.tiers or {}) do
		if not placed and tier.unit >= unit then
			You()
			placed = true
		end
		if not placed then
			unitsAhead = unitsAhead + tier.units
		end
		if shown < LADDER_ROWS then
			Add(L.SELL_LADDER_ROW:format(ns.Comma(tier.copies), ns.Comma(tier.stack)), ns.Money(tier.unit))
			shown = shown + 1
		end
	end
	if not placed then
		You()
	end

	local note = MarketPending() or L.SELL_NOT_LISTED
	if listed then
		note = unitsAhead == 0 and L.SELL_CHEAPEST or L.SELL_AHEAD:format(ns.Comma(unitsAhead))
	end
	parts.ladderNote:ClearAllPoints()
	parts.ladderNote:SetPoint("TOPLEFT", ladder, "TOPLEFT", 8, -(y + 6))
	parts.ladderNote:SetPoint("TOPRIGHT", ladder, "TOPRIGHT", -8, -(y + 6))
	y = y + 6 + parts.ladderNote:SetBody(note)
	parts.ladderNote:Show()
	if listed then
		parts.ladderMarket:ClearAllPoints()
		parts.ladderMarket:SetPoint("TOPLEFT", parts.ladderNote, "BOTTOMLEFT", 0, -4)
		parts.ladderMarket:SetPoint("TOPRIGHT", parts.ladderNote, "BOTTOMRIGHT", 0, -4)
		y = y + 4 + parts.ladderMarket:SetBody(L.SELL_MARKET:format(ns.Comma(listed.listings), ns.Money(ns.History:Usual(listed))))
		parts.ladderMarket:Show()
	end
	PaintHistory(owned, y + HISTORY_GAP)
end

-- Under the competition: what past scans and the ledger know about the item,
-- the same lines its tooltip and the Buy tab show (ns.TooltipLines and
-- ns.ItemStatLines), so its price history and the player's own sales are
-- there to price by. As many lines as fit above the bottom of the panel.
PaintHistory = function(owned, y)
	for _, row in ipairs(parts.history) do
		row:Hide()
	end
	parts.historyHead:Hide()
	local itemID, name = owned.key:match("^(%d+):(.+)$")
	if not itemID then
		return
	end
	local lines = {}
	for _, rules in ipairs({ ns.TooltipLines, ns.ItemStatLines }) do
		for _, line in ipairs(ns.ItemTooltip:Lines(tonumber(itemID), name, rules)) do
			lines[#lines + 1] = line
		end
	end
	if #lines == 0 then
		return
	end
	local function Place(row)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", ladder, "TOPLEFT", 8, -y)
		row:SetPoint("TOPRIGHT", ladder, "TOPRIGHT", -8, -y)
		row:Show()
		y = y + HISTORY_ROW_HEIGHT
	end
	Place(parts.historyHead)
	y = y + 4
	local room = math.floor(((ladder:GetHeight() or 0) - y - 8) / HISTORY_ROW_HEIGHT)
	for index = 1, math.min(#lines, #parts.history, math.max(0, room)) do
		local row = parts.history[index]
		Place(row)
		row:Set(lines[index][1], lines[index][2])
	end
end

-- ========= The tab ==========================================================
Refresh = function()
	-- What was chosen may have been sold or moved since.
	if state.key and not ns.Bags:Find(state.key) then
		state.key = nil
	end
	if not state.key then
		local first = FirstItem()
		if first then
			return Choose(first.key)
		end
	end
	PaintBags()
	PaintForm()
	PaintLadder()
end

local function Create(parent)
	local pad = Theme.pad
	bags = Kit.Panel(parent)
	bags:SetPoint("TOPLEFT")
	bags:SetPoint("BOTTOMLEFT")
	bags:SetWidth(Theme.sell.bags)
	Kit.Split(bags, { id = "sell.bags", edge = "RIGHT", min = Theme.sell.bags, max = Theme.sell.bags + Theme.panelGrow, onChange = function()
		ns.Window:RefreshActive()
	end })
	local bagsLabel = Kit.Text(bags, "normal", C.accent)
	bagsLabel:SetPoint("TOPLEFT", 8, -9)
	bagsLabel:SetText(L.SELL_BAGS)
	bagHint = Kit.Note(bags, "small", C.muted)
	bagHint:SetPoint("TOPLEFT", 8, -32)
	bagHint:SetPoint("TOPRIGHT", -8, -32)
	bagHint:SetWidth(Theme.sell.bags - 16)
	bagHint:SetBody(L.SELL_BAGS_EMPTY)
	bagFilters = Kit.Choices(bags, {
		items = ns.BagFilters,
		size = "small",
		height = 22,
		padding = 12,
		isActive = function(filter)
			return filter.id == BagFilter().id
		end,
		onPick = function(filter)
			BagView().filter = filter.id
			ns.Window:RefreshActive()
		end,
	})
	bagFilters:SetPoint("TOPLEFT", 8, -30)
	BuildBagList(bags)
	gridEmpty = Kit.Note(bags, "small", C.muted)
	gridEmpty:SetPoint("TOPLEFT", 8, -BAG_TOP)
	gridEmpty:SetPoint("TOPRIGHT", -8, -BAG_TOP)
	gridEmpty:SetWidth(Theme.sell.bags - 16)
	gridEmpty:SetBody(L.SELL_BAGS_NONE_HERE)
	bagList:SetPoint("TOPLEFT", 4, -BAG_TOP)
	bagList:SetPoint("BOTTOMRIGHT", -4, 4)

	ladder = Kit.Panel(parent)
	ladder:SetPoint("TOPRIGHT")
	ladder:SetPoint("BOTTOMRIGHT")
	ladder:SetWidth(Theme.sell.competition)
	Kit.Split(ladder, { id = "sell.competition", edge = "LEFT", min = Theme.sell.competition, max = Theme.sell.competition + Theme.panelGrow, onChange = function()
		ns.Window:RefreshActive()
	end })
	local ladderLabel = Kit.Text(ladder, "normal", C.accent)
	ladderLabel:SetPoint("TOPLEFT", 8, -9)
	ladderLabel:SetText(L.SELL_COMPETITION)
	parts.ladderKey = Kit.Text(ladder, "small", C.muted)
	parts.ladderKey:SetPoint("TOPLEFT", 8, -27)
	parts.ladderKey:SetText(L.SELL_COMPETITION_KEY)
	parts.ladderNote = Kit.Note(ladder, "small", C.muted)
	parts.ladderNote:SetWidth(Theme.sell.competition - 16)
	parts.ladderMarket = Kit.Note(ladder, "small", C.muted)
	parts.ladderMarket:SetWidth(Theme.sell.competition - 16)
	parts.historyHead = Kit.Pair(ladder, "normal", C.accent)
	parts.historyHead:Set(L.STAT_HEADING, "")
	parts.history = {}
	for index = 1, HISTORY_LINES do
		parts.history[index] = Kit.Pair(ladder, "small")
		parts.history[index]:SetHeight(HISTORY_ROW_HEIGHT)
	end

	form = Kit.Panel(parent)
	form:SetPoint("TOPLEFT", bags, "TOPRIGHT", pad, 0)
	form:SetPoint("BOTTOMRIGHT", ladder, "BOTTOMLEFT", -pad, 0)
	BuildForm(form)

	return { Refresh = Refresh }
end

ns.Window:RegisterTab({ id = "sell", label = L.TAB_SELL, order = 2, Create = Create })

-- The form follows a post as it goes: sending, confirm, done or refused.
ns.Bus:On("POSTING_CHANGED", function()
	if form and ns.charDb.tab == "sell" then
		ns.Window:RequestRefresh()
	end
	-- The game is asked for the item's live listings, as its own sell form does.
	ns.SellSearch:Request(state.key)
end)

ns.Bus:On("SETTING_CHANGED", function(id)
	if id == "sellBagList" then
		ns.Window:RequestRefresh()
	end
end)

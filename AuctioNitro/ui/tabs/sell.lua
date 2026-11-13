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
local BAG_COLUMNS = 4
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
local bagTiles, parts, ladderRows = {}, {}, {}
local stack
local Refresh, PaintForm, PaintLadder, PaintSummary, PaintPostButton, PressPost

-- ========= What is being sold ===============================================
local function Owned()
	return state.key and ns.Bags:Find(state.key)
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

local function UnitPrice()
	if state.customUnit then
		return state.customUnit
	end
	local listed = Listed()
	if not listed then
		return nil
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

local function PaintBags()
	for _, tile in ipairs(bagTiles) do
		tile:Hide()
	end
	local slots = ns.Bags:Slots()
	bagHint:SetShown(#slots == 0)
	local step = Theme.bagSlot + 4
	for index, slot in ipairs(slots) do
		local tile = BagTile(index)
		local column, row = (index - 1) % BAG_COLUMNS, math.floor((index - 1) / BAG_COLUMNS)
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", bags, "TOPLEFT", 8 + column * step, -(30 + row * step))
		tile.slot = slot
		tile.art:SetTexture(slot.icon)
		tile.count:SetText(slot.count > 1 and slot.count or "")
		local chosen = slot.item.key == state.key
		tile.border:SetColor(chosen and C.accent or C.inputBorder)
		tile:Show()
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

local function SliderRow(parent, name, onChange)
	local row = NamedRow(parent, name, 22)
	row.value = Kit.Text(row, "normal", C.muted, "RIGHT")
	row.value:SetPoint("RIGHT")
	row.value:SetWidth(76)
	row.slider = Kit.Slider(row, { onChange = onChange })
	row.slider:SetPoint("LEFT", LABEL_WIDTH, 0)
	row.slider:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
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
ns.SellRequest = BuildRequest -- for the /an post command

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

	parts.quantityRow.value:SetText(ns.Comma(state.perAuction) .. " " .. L.SELL_OF:format(ns.Comma(total)))
	parts.auctionsRow.value:SetText(ns.Comma(state.auctions) .. " " .. L.SELL_OF:format(ns.Comma(math.max(1, math.floor(total / state.perAuction)))))
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
		parts.warning:SetBody(L.SELL_NO_PRICE, C.muted)
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
	parts.warning:SetShown(bidTooHigh or tooCheap)
	if tooCheap then
		parts.warning:SetBody(L.SELL_TOO_CHEAP:format(ns.Money(ns.MinItemPrice)), C.bad)
	elseif bidTooHigh then
		parts.warning:SetBody(L.SELL_BID_TOO_HIGH, C.bad)
	end
end

PaintForm = function()
	stack:Reset()
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
		parts.quantityRow.slider:SetRange(total)
		parts.quantityRow.slider:SetShownValue(state.perAuction)
		stack:Add(parts.quantityRow, 8)
	elseif total > 1 then
		parts.auctionsRow.slider:SetRange(total)
		parts.auctionsRow.slider:SetShownValue(state.auctions)
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

	local note = L.SELL_NOT_LISTED
	if listed then
		note = unitsAhead == 0 and L.SELL_CHEAPEST or L.SELL_AHEAD:format(ns.Comma(unitsAhead))
	end
	parts.ladderNote:ClearAllPoints()
	parts.ladderNote:SetPoint("TOPLEFT", ladder, "TOPLEFT", 8, -(y + 6))
	parts.ladderNote:SetPoint("TOPRIGHT", ladder, "TOPRIGHT", -8, -(y + 6))
	parts.ladderNote:SetBody(note)
	parts.ladderNote:Show()
	if listed then
		parts.ladderMarket:ClearAllPoints()
		parts.ladderMarket:SetPoint("TOPLEFT", parts.ladderNote, "BOTTOMLEFT", 0, -4)
		parts.ladderMarket:SetPoint("TOPRIGHT", parts.ladderNote, "BOTTOMRIGHT", 0, -4)
		parts.ladderMarket:SetBody(L.SELL_MARKET:format(ns.Comma(listed.listings), ns.Money(ns.History:Usual(listed))))
		parts.ladderMarket:Show()
	end
end

-- ========= The tab ==========================================================
Refresh = function()
	-- What was chosen may have been sold or moved since.
	if state.key and not ns.Bags:Find(state.key) then
		state.key = nil
	end
	if not state.key then
		local first = ns.Bags:Slots()[1]
		if first then
			return Choose(first.item.key)
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
	local bagsLabel = Kit.Text(bags, "normal", C.accent)
	bagsLabel:SetPoint("TOPLEFT", 8, -9)
	bagsLabel:SetText(L.SELL_BAGS)
	bagHint = Kit.Note(bags, "small", C.muted)
	bagHint:SetPoint("TOPLEFT", 8, -32)
	bagHint:SetPoint("TOPRIGHT", -8, -32)
	bagHint:SetWidth(Theme.sell.bags - 16)
	bagHint:SetBody(L.SELL_BAGS_EMPTY)

	ladder = Kit.Panel(parent)
	ladder:SetPoint("TOPRIGHT")
	ladder:SetPoint("BOTTOMRIGHT")
	ladder:SetWidth(Theme.sell.competition)
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
		ns.Window:RefreshActive()
	end
	-- The game is asked for the item's live listings, as its own sell form does.
	ns.SellSearch:Request(state.key)
end)

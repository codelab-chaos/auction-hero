-- Buying: buys from the auction house, goods and single items both.
--
-- Nothing here runs by itself. A purchase is two presses, the same two the
-- game's own window asks for:
--   1. Start asks the server for the live price.
--   2. Confirm, pressed after reading that price, spends the gold.
-- Scan prices are never spent on: only what the server says right now is.
--
-- The two kinds of thing are bought in different ways (see `ways` below):
--   goods         sold by the unit (cloth, ore, potions). The server quotes a
--                 price for the quantity, and one purchase fills it from the
--                 cheapest sellers up.
--   single items  gear, recipes and the like. The live auctions are searched,
--                 the cheapest one of this exact item is offered, and one
--                 purchase buys that one auction.
--
-- The state, published as BUYING_CHANGED:
--   phase     "idle", "quoting", "confirm", "buying", "done", "failed" or
--             "expired" (a price check the game let lapse: nothing went wrong)
--   key       the market item
--   quantity  units: asked for (goods), or in the auction found (single items)
--   unit, total   the live price, once the server has answered
--   auctionID     the auction being bought, for a single item
--   message   what to tell the player
local _, ns = ...
local Bus = ns.Bus
local L = ns.L

local Buying = { state = { phase = "idle" } }
ns.Buying = Buying

-- How long to wait on the server is data: ns.AnswerSeconds (data\trading.lua).
-- How many pages of live auctions to read through looking for the item.
local SEARCH_PAGES = 5

-- The purchase in hand:
--   { key, itemID, quantity, way }                               for goods
--   { key, itemID, name, way, itemKey, pages, auctionID, gold }  for a single item
local order
local deadlines -- the waits on the server while quoting and buying (see trade\deadlines.lua)

local function Publish(phase, message, extra)
	local state = { phase = phase, message = message, key = order and order.key, quantity = order and order.quantity }
	for name, value in pairs(extra or {}) do
		state[name] = value
	end
	Buying.state = state
	deadlines:Enter(phase)
	Bus:Fire("BUYING_CHANGED", state)
end

local function Fail(message, gone)
	-- A purchase that was sent keeps its auction in the state, so whoever
	-- listens can tell a refused purchase from a search that found nothing.
	-- gone: the auction house has nothing listed by the item's name.
	local sent = Buying.state.phase == "buying" and Buying.state.auctionID or nil
	Publish("failed", message, { auctionID = sent, gone = gone })
	order = nil
end

local function Done()
	Publish("done", L.BUY_DONE, { unit = Buying.state.unit, total = Buying.state.total, auctionID = Buying.state.auctionID })
	order = nil
end

-- Why a purchase cannot be started right now, or nil when it can.
-- A single item's searches wait their turn (trade\requests.lua); goods are
-- quoted at once, so they need the auction house free.
local function Blocked(single)
	if not ns.auctionHouseOpen then
		return L.POST_NEEDS_AH
	elseif ns.Downloader:IsRunning() then
		return L.POST_SCANNING
	elseif not single and (ns.Requests:Busy() or not C_AuctionHouse.IsThrottledMessageSystemReady()) then
		return L.POST_BUSY
	end
end

-- ========= Goods sold by the unit ===========================================
local goods = {}

function goods.Start(request)
	-- Ask the game first, before anything else happens in this press.
	local ok, problem = pcall(C_AuctionHouse.StartCommoditiesPurchase, request.itemID, request.quantity)
	order = { key = request.key, itemID = request.itemID, quantity = request.quantity, way = goods }
	ns.EventLog:Note("StartCommoditiesPurchase", request.itemID, request.quantity, ok, problem)
	return ok, problem
end

function goods.Confirm()
	local ok, problem = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, order.itemID, order.quantity)
	ns.EventLog:Note("ConfirmCommoditiesPurchase", order.itemID, order.quantity, ok, problem)
	return ok, problem
end

function goods.Cancel()
	pcall(C_AuctionHouse.CancelCommoditiesPurchase)
	ns.EventLog:Note("CancelCommoditiesPurchase")
end

-- The server did not answer in time.
function goods.TimedOut()
	pcall(C_AuctionHouse.CancelCommoditiesPurchase)
	Fail(L.BUY_NO_ANSWER)
end

goods.events = {
	-- The first quote leads to the confirm. The server can quote again while
	-- the confirm is showing (Blizzard's own dialog watches for it); the newest
	-- quote is what a confirm spends, so it replaces what is shown. A rise is
	-- said out loud, with how much, so the confirm button is never pressed on
	-- a total lower than the real one.
	COMMODITY_PRICE_UPDATED = function(unit, total)
		local phase = Buying.state.phase
		if phase == "quoting" then
			Publish("confirm", L.BUY_CONFIRM_PRICE, { unit = unit, total = total })
		elseif phase == "confirm" and total ~= Buying.state.total then
			local rise = total - (Buying.state.total or 0)
			ns.EventLog:Note("commodity price changed", order.itemID, Buying.state.total, total)
			Publish("confirm", rise > 0 and L.BUY_PRICE_ROSE:format(ns.PlainMoney(rise)) or L.BUY_CONFIRM_PRICE, { unit = unit, total = total })
		end
	end,
	COMMODITY_PRICE_UNAVAILABLE = function()
		if Buying.state.phase == "quoting" or Buying.state.phase == "confirm" then
			Fail(L.BUY_UNAVAILABLE)
		end
	end,
	COMMODITY_PURCHASE_SUCCEEDED = function()
		if Buying.state.phase == "buying" then
			Done()
		end
	end,
	COMMODITY_PURCHASE_FAILED = function()
		if Buying.state.phase == "buying" or Buying.state.phase == "confirm" then
			Fail(L.BUY_FAILED)
		end
	end,
}

-- ========= Single items =====================================================
-- Searching and buying go through trade\requests.lua, which keeps them in
-- order and waits on the answers: no waits of its own here.
local single = { managed = true }
local BLOCKED = {} -- single.Confirm's answer when the game refused to send the purchase

-- The cheapest live auction of exactly this item, with a buyout, that is not
-- the player's own. An item id covers every variant of a piece of gear ("of
-- the Bear", "of the Owl"), so the name in the auction's link must match.
-- When the player picked a price in the list, only an auction at that unit
-- price counts.
-- Returns the auction, whether any auction's name could not be read, and the
-- cheapest price the item is at when none is at the price picked.
local function CheapestLive()
	local best, unread, cheapest
	local ok, count = pcall(C_AuctionHouse.GetNumItemSearchResults, order.itemKey)
	for index = 1, ok and count or 0 do
		local found, info = pcall(C_AuctionHouse.GetItemSearchResultInfo, order.itemKey, index)
		if found and info and (info.buyoutAmount or 0) > 0 and not info.containsOwnerItem then
			local name = info.itemLink and info.itemLink:match("|h%[(.-)%]|h")
			if not name then
				unread = true
			elseif name == order.name then
				local quantity = ns.AuctionUnits(order.itemID, info.quantity)
				local unit = math.floor(info.buyoutAmount / quantity)
				if order.price and unit ~= order.price then
					-- The player picked a price. Only an auction at it will do.
					cheapest = math.min(cheapest or unit, unit)
				elseif not best or info.buyoutAmount / quantity < best.buyout / best.quantity then
					best = { auctionID = info.auctionID, buyout = info.buyoutAmount, quantity = quantity }
				end
			end
		end
	end
	return best, unread, cheapest
end

-- The cheapest of a list of auctions, at the price picked when one was:
-- { auctionID, buyout, quantity }, skipping the player's own.
local function Pick(auctions, price)
	local best
	for _, auction in ipairs(auctions) do
		local unit = math.floor(auction.buyout / auction.quantity)
		if auction.buyout > 0 and not auction.mine and (not price or unit == price) then
			if not best or unit < math.floor(best.buyout / best.quantity) then
				best = auction
			end
		end
	end
	return best
end

local Answered -- reads the search's answer; below

-- Asks for the live auctions of the item, by the key the auction house
-- knows it by (see trade\item-key.lua). It waits its turn behind anything
-- already asked.
local function Search()
	local mine = order
	local sorts = {
		{ sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
		{ sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false },
	}
	mine.request = ns.Requests:Ask({
		kind = "itemSearch",
		label = "buy search",
		itemID = mine.itemID,
		itemKey = mine.itemKey,
		send = function()
			return C_AuctionHouse.SendSearchQuery(mine.itemKey, sorts, false)
		end,
		read = function(request, last)
			if order ~= mine or Buying.state.phase ~= "quoting" then
				return nil
			end
			return Answered(request, last)
		end,
		done = function(outcome)
			if order ~= mine or Buying.state.phase ~= "quoting" then
				return
			end
			if outcome ~= "answered" then
				Fail(L.BUY_NO_ANSWER)
			end
		end,
	})
end

function single.Start(request)
	-- The item was checked live a moment ago (see trade\live-check.lua) and
	-- the game still holds that answer: it is the one a search now would
	-- give, so use it and ask nothing.
	local holds = ns.Requests:Holding(request.itemID, ns.LiveCheckRule.reuseSeconds)
	local fresh = holds and request.live and request.checkedAt and GetServerTime() - request.checkedAt <= ns.LiveCheckRule.reuseSeconds
	local known = fresh and Pick(request.live, request.price)
	if known then
		order = { key = request.key, itemID = request.itemID, name = request.name, price = request.price, way = single, auctionID = known.auctionID, quantity = known.quantity }
		ns.EventLog:Note("buy from live check", request.itemID, known.auctionID, known.buyout, known.quantity)
		-- At the price the player pressed: nothing to confirm, it is bought now.
		local unit = math.floor(known.buyout / known.quantity)
		return true, nil, { unit = unit, total = known.buyout, auctionID = known.auctionID, now = request.price == unit }
	end
	-- First the item's key, then its live auctions. Both are only questions.
	order = { key = request.key, itemID = request.itemID, name = request.name, price = request.price, way = single, pages = 1 }
	local mine = order
	ns.ItemKey:Resolve(request.itemID, request.name, function(itemKey, problem, found)
		-- A key already known comes back at once, before this press has been
		-- announced. A moment later is soon enough.
		C_Timer.After(0, function()
			if order ~= mine or Buying.state.phase ~= "quoting" then
				return -- backed out of, or overtaken, while the key was being found
			end
			if not itemKey then
				local missing = problem == "none" or problem == "gone"
				return Fail(missing and L.BUY_NOT_FOUND:format(found or "") or L.BUY_NO_ANSWER, problem == "none")
			end
			order.itemKey = itemKey
			Search()
		end)
	end)
	return true
end

-- The gold left the purse: the purchase went through, whatever else was said.
local function Paid()
	return order and order.gold and GetMoney() <= order.gold - Buying.state.total
end

-- How a purchase ended, as trade\requests.lua tells it.
local function Bought(mine, outcome, request)
	if order ~= mine then
		return
	end
	if outcome == "busy" or outcome == "blocked" then
		-- It never left: nothing was spent, and the next press sends it.
		return Publish("confirm", outcome == "busy" and L.BUY_WAIT_BUSY or L.BUY_CHECKED_SAME, { unit = mine.unit, total = mine.total, auctionID = mine.auctionID })
	end
	if outcome == "answered" or Paid() then
		return Done()
	end
	if outcome == "closed" then
		return
	end
	-- State what is known and no more: the gold before and now.
	local now = GetMoney()
	ns.EventLog:Note("buy not confirmed", mine.auctionID, request.errorCode, "gold", mine.gold, now)
	if request.errorCode ~= nil then
		return Fail(L.BUY_PROBLEM:format(tostring(request.errorCode), ns.PlainMoney(mine.gold or now), ns.PlainMoney(now)))
	end
	Fail(outcome == "refused" and L.BUY_FAILED or L.BUY_NO_CONFIRM)
end

-- Sends the purchase, now, as part of the press. total: what to pay. Returns
-- whether it left; BLOCKED and busy come back through Bought.
function single.Confirm(total, unit)
	local mine = order
	mine.total, mine.unit = total or Buying.state.total, unit or Buying.state.unit
	mine.gold = GetMoney()
	local sent = false
	local outcome
	ns.Requests:Press({
		kind = "bid",
		label = "purchase",
		auctionID = mine.auctionID,
		itemID = mine.itemID,
		send = function()
			return C_AuctionHouse.PlaceBid(mine.auctionID, mine.total)
		end,
		onSend = function()
			sent = true
		end,
		done = function(how, _, request)
			outcome = how
			-- Turned away at once: the press is answered where it was made.
			if not sent then
				return
			end
			Bought(mine, how, request)
		end,
	})
	ns.EventLog:Note("PlaceBid", mine.auctionID, mine.total, sent, outcome)
	if not sent then
		return false, outcome == "busy" and "busy" or BLOCKED
	end
	return true
end

-- A search leaves nothing to take back.
function single.Cancel() end

-- Waits belong to the requests (trade\requests.lua).
function single.TimedOut() end

-- The live auctions arrived and are quiet. Offer the cheapest one of this
-- item, or read on.
function Answered(request, last)
	local best, unread, cheapest = CheapestLive()
	-- What the game handed back, for the log: how many auctions, whether that
	-- is all of them, and what the first one looks like.
	local counted, count = pcall(C_AuctionHouse.GetNumItemSearchResults, order.itemKey)
	local _, whole = pcall(C_AuctionHouse.HasFullItemSearchResults, order.itemKey)
	local _, first = pcall(C_AuctionHouse.GetItemSearchResultInfo, order.itemKey, 1)
	first = type(first) == "table" and first or {}
	ns.EventLog:Note("buy answered", order.itemID, counted and count, whole, "wanted", order.name, order.price, "first", first.auctionID, first.itemLink, first.buyoutAmount, first.quantity, first.itemKey)
	if best then
		order.auctionID = best.auctionID
		order.quantity = best.quantity
		ns.EventLog:Note("buy found", order.itemID, best.auctionID, best.buyout, best.quantity)
		Publish("confirm", L.BUY_CONFIRM_PRICE, { unit = math.floor(best.buyout / best.quantity), total = best.buyout, auctionID = best.auctionID })
		return true
	end
	-- Not on this page. The list is cheapest first, so it may be further on.
	if whole == false and order.pages < SEARCH_PAGES and not last then
		order.pages = order.pages + 1
		return request:More(function()
			return C_AuctionHouse.RequestMoreItemSearchResults(order.itemKey)
		end)
	end
	if cheapest then
		-- It is for sale, but not at the price picked any more.
		Fail(L.BUY_PRICE_GONE:format(ns.PlainMoney(order.price), ns.PlainMoney(cheapest)))
	elseif unread then
		Fail(L.BUY_UNREADABLE)
	else
		-- Say what was found, so "none" is never a guess: how many auctions came
		-- back for the item, and what the first of them is called.
		local seen = counted and count or 0
		local firstName = first.itemLink and first.itemLink:match("|h%[(.-)%]|h")
		if seen > 0 then
			Fail(L.BUY_NOT_AMONG:format(ns.Comma(seen), whole == false and L.BUY_AND_MORE or "", order.name, tostring(firstName or first.itemLink)))
		else
			Fail(L.BUY_ITEM_GONE)
		end
	end
	return true
end

single.events = {
	-- The gold leaving is as good an answer as any.
	PLAYER_MONEY = function()
		if Buying.state.phase == "buying" and Paid() then
			Done()
		end
	end,
}

-- ========= The two presses ==================================================
-- Asking for a price and buying both wait on the server. Entering either
-- phase starts the wait; any other phase ends it.
local function AnswerSeconds()
	if order and order.way.managed then
		return nil
	end
	return ns.AnswerSeconds.buy
end
deadlines = ns.Deadlines({ quoting = AnswerSeconds, buying = AnswerSeconds }, function(phase)
	if order then
		order.way.TimedOut(phase)
	end
end)

-- The first press: asks the server for the live price.
-- request: { key, itemID, quantity } for goods, or
--          { key, itemID, name, single = true, price, live, checkedAt } for a single item.
--          live and checkedAt are the item's auctions from a live check, and when.
--          price is the unit price picked in the list, or nil for the cheapest.
function Buying:Start(request)
	local phase = self.state.phase
	if phase == "quoting" or phase == "buying" then
		return
	end
	local blocked = Blocked(request.single)
	if blocked then
		order = { key = request.key, quantity = request.quantity }
		ns.EventLog:Note("buy refused", blocked)
		return Fail(blocked)
	end
	local way = request.single and single or goods
	local ok, problem, ready = way.Start(request)
	if not ok then
		return Fail(tostring(problem))
	end
	if ready then
		-- The live price is already known. At the price pressed, buy it in
		-- this same press; otherwise it waits for a confirm.
		local now = ready.now and ready.total <= GetMoney()
		ready.now = nil
		if now then
			-- The game takes a purchase only as part of the player's press, so
			-- it is sent first, before anything else runs: telling the window
			-- (BUYING_CHANGED) first made the game refuse it.
			local sent, failure = way.Confirm(ready.total, ready.unit)
			if failure == BLOCKED or failure == "busy" then
				-- Nothing left and nothing was spent: the next press sends it.
				return Publish("confirm", failure == "busy" and L.BUY_WAIT_BUSY or L.BUY_CHECKED_SAME, ready)
			elseif not sent then
				return Fail(tostring(failure))
			end
			return Publish("buying", L.BUY_BUYING, ready)
		end
		return Publish("confirm", L.BUY_CONFIRM_PRICE, ready)
	end
	Publish("quoting", L.BUY_QUOTING)
end

-- The second press: spends the gold at the price shown.
function Buying:Confirm()
	local state = self.state
	if state.phase ~= "confirm" or not order then
		return
	end
	if state.total > GetMoney() then
		order.way.Cancel()
		return Fail(L.BUY_OVER_GOLD)
	end
	-- A single item's price was read from the game's latest search. If another
	-- search has replaced it since, that price is not known to hold: read it again.
	if order.way == single and not ns.Requests:Holding(order.itemID) then
		ns.EventLog:Note("buy search again", order.itemID, "another search came in between")
		Publish("quoting", L.BUY_QUOTING)
		order.pages = 1
		return Search()
	end
	local ok, problem = order.way.Confirm()
	if problem == BLOCKED or problem == "busy" then
		return Publish("confirm", problem == "busy" and L.BUY_WAIT_BUSY or L.BUY_CHECKED_SAME, { unit = state.unit, total = state.total, auctionID = state.auctionID })
	elseif not ok then
		return Fail(tostring(problem))
	end
	Publish("buying", L.BUY_BUYING, { unit = state.unit, total = state.total, auctionID = state.auctionID })
end

-- Backs out of a price that has not been confirmed. Nothing has been spent.
function Buying:Cancel()
	local phase = self.state.phase
	if (phase == "quoting" or phase == "confirm") and order then
		order.way.Cancel()
	end
	if phase ~= "buying" and phase ~= "idle" then
		order = nil
		Publish("idle")
	end
end

-- The single item being bought right now, for the ledger: { auctionID, itemID, name, quantity }.
function Buying:Pending()
	if order and order.way == single and order.auctionID then
		return { auctionID = order.auctionID, itemID = order.itemID, name = order.name, quantity = order.quantity }
	end
end

local frame = CreateFrame("Frame")
for _, way in ipairs({ goods, single }) do
	for event in pairs(way.events) do
		pcall(frame.RegisterEvent, frame, event)
	end
end
frame:SetScript("OnEvent", function(_, event, ...)
	local handler = order and order.way and order.way.events[event]
	if handler then
		handler(...)
	end
end)

-- A quote for goods only lasts a short while. When the game drops it, so do we.
C_Timer.NewTicker(1, function()
	if Buying.state.phase == "confirm" and order and order.way == goods then
		local ok, left = pcall(C_AuctionHouse.GetQuoteDurationRemaining)
		if ok and left == 0 then
			Publish("expired", L.BUY_QUOTE_EXPIRED)
			order = nil
		end
	end
end)

Bus:On("AH_CLOSED", function()
	if Buying.state.phase ~= "idle" then
		order = nil
		Publish("idle")
	end
end)

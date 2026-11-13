-- Posting: puts an item from the bags up for auction.
--
-- Nothing here runs by itself. Post and Confirm are only ever called from a
-- button press, and each press does one thing. The game checks that too.
--
-- The state, published as POSTING_CHANGED:
--   phase     "idle", "posting", "confirm", "done" or "failed"
--   key       the bag item being posted
--   message   what to tell the player
--   created, expected   auctions made so far, and how many were asked for
local _, ns = ...
local Bus = ns.Bus
local L = ns.L

local Posting = { state = { phase = "idle" } }
ns.Posting = Posting

local pending -- the arguments of a post waiting for the player's confirmation
local sent -- the last post sent: { confirm, args, key, itemID, had }
local attempt = 0 -- counts posts, so a late timer cannot touch a newer one

-- How long to wait for the game to answer a post before deciding by the bags.
local ANSWER_SECONDS = 8

local function Publish(state)
	Posting.state = state
	Bus:Fire("POSTING_CHANGED", state)
end

local function Fail(message, key)
	pending = nil
	Publish({ phase = "failed", message = message, key = key or Posting.state.key })
end

-- The bag slot to post from, checked afresh: bags change between the click
-- that chose the item and the click that posts it.
local function Locate(key)
	local owned = ns.Bags:Find(key)
	for _, slot in ipairs(owned and owned.slots or {}) do
		local location = ItemLocation:CreateFromBagAndSlot(slot.bag, slot.slot)
		if C_Item.DoesItemExist(location) and C_Item.GetItemID(location) == owned.itemID then
			return location, owned
		end
	end
end

Posting.Locate = Locate

-- Whether the game sells this bag item by the unit. Nil while it cannot say.
function Posting:IsCommodity(key)
	if not ns.auctionHouseOpen then
		return nil
	end
	local location = Locate(key)
	if not location then
		return nil
	end
	local ok, status = pcall(C_AuctionHouse.GetItemCommodityStatus, location)
	if ok and status == Enum.ItemCommodityStatus.Commodity then
		return true
	elseif ok and status == Enum.ItemCommodityStatus.Item then
		return false
	end
	return nil
end

-- The deposit the game will charge, or nil when it cannot say (the auction
-- house is closed, or the item is not in the bags any more).
function Posting:Deposit(key, commodity, duration, quantity)
	if not ns.auctionHouseOpen then
		return nil
	end
	local location, owned = Locate(key)
	if not location then
		return nil
	end
	local ok, deposit
	if commodity then
		ok, deposit = pcall(C_AuctionHouse.CalculateCommodityDeposit, owned.itemID, duration, quantity)
	else
		ok, deposit = pcall(C_AuctionHouse.CalculateItemDeposit, location, duration, quantity)
	end
	return ok and deposit or nil
end

-- True when fewer of the posted item are in the bags than when it was sent.
local function LeftTheBags()
	if not sent then
		return false
	end
	local owned = ns.Bags:Find(sent.key)
	return (owned and owned.total or 0) < sent.had
end

local function Done()
	local state = Posting.state
	state.phase = "done"
	state.message = (state.expected or 1) > 1 and L.POST_DONE_MANY:format(ns.Comma(state.expected)) or L.POST_DONE
	Publish(state)
end

local function AskToConfirm()
	if not sent then
		return
	end
	pending = { confirm = sent.confirm, args = sent.args }
	local state = Posting.state
	state.phase, state.message = "confirm", L.POST_CONFIRM
	Publish(state)
end

-- What might make the game refuse a post, for the log: combat, and any of the
-- game's addon restrictions that are active right now.
local function Circumstances()
	local notes = { "combat=" .. tostring(InCombatLockdown and InCombatLockdown() or false) }
	local restrictions = C_RestrictedActions and Enum.AddOnRestrictionType
	if restrictions and C_RestrictedActions.IsAddOnRestrictionActive then
		for name, value in pairs(restrictions) do
			local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, value)
			if ok and active then
				notes[#notes + 1] = "restricted:" .. name
			end
		end
	end
	return table.concat(notes, " ")
end

-- Why a post cannot be started right now, or nil when it can.
local function Blocked()
	if not ns.auctionHouseOpen then
		return L.POST_NEEDS_AH
	elseif ns.Downloader:IsRunning() then
		return L.POST_SCANNING
	elseif not C_AuctionHouse.IsThrottledMessageSystemReady() then
		return L.POST_BUSY
	end
end

-- Starts a post. request:
--   key        the bag item
--   commodity  true to post a quantity at a unit price
--   duration   1, 2 or 3
--   quantity   units for a commodity, auctions for anything else
--   unit       price each, in copper (the buyout, or the bid when there is no buyout)
--   bid        starting bid each, or nil
--   buyout     false to post for bids only
function Posting:Post(request)
	if self.state.phase == "posting" then
		return
	end
	local blocked = Blocked()
	if blocked then
		ns.EventLog:Note("post refused", blocked)
		return Fail(blocked, request.key)
	end
	local location = Locate(request.key)
	if not location then
		return Fail(L.POST_NOT_IN_BAGS, request.key)
	end
	-- The game's sell form looks up an item's live listings before it posts.
	-- A post waits until we have asked for them too.
	if not ns.SellSearch:Asked(request.key) then
		ns.SellSearch:Request(request.key)
		ns.EventLog:Note("post refused", "live listings not asked for yet")
		return Fail(L.POST_NOT_READY, request.key)
	end
	if not C_AuctionHouse.IsSellItemValid(location, false) then
		return Fail(L.POST_NOT_SELLABLE, request.key)
	end

	-- The same checks the game's own sell form makes before it posts. It will
	-- not post an item it cannot classify, and it posts each kind its own way:
	-- sending one kind as the other is a request the server may never answer.
	local statusOk, status = pcall(C_AuctionHouse.GetItemCommodityStatus, location)
	local isCommodity = statusOk and status == Enum.ItemCommodityStatus.Commodity
	if not statusOk or status == Enum.ItemCommodityStatus.Unknown or isCommodity ~= (request.commodity == true) then
		ns.EventLog:Note("post refused", "status=" .. tostring(status) .. " asked commodity=" .. tostring(request.commodity))
		return Fail(L.POST_NOT_READY, request.key)
	end
	if not request.commodity and request.unit < ns.MinItemPrice then
		ns.EventLog:Note("post refused", "price under the floor", request.unit)
		return Fail(L.SELL_TOO_CHEAP:format(ns.Money(ns.MinItemPrice)), request.key)
	end
	local deposit = self:Deposit(request.key, request.commodity, request.duration, request.quantity)
	if deposit and GetMoney() < deposit then
		return Fail(L.POST_NO_DEPOSIT, request.key)
	end

	local call, confirm, args
	if request.commodity then
		call, confirm = C_AuctionHouse.PostCommodity, C_AuctionHouse.ConfirmPostCommodity
		args = { location, request.duration, request.quantity, request.unit }
	else
		call, confirm = C_AuctionHouse.PostItem, C_AuctionHouse.ConfirmPostItem
		local buyout = request.buyout ~= false and request.unit or nil
		local bid = request.buyout == false and request.unit or request.bid
		args = { location, request.duration, request.quantity, bid, buyout }
	end

	-- What the game says about this post, for the log.
	local kind = "status=" .. tostring(statusOk and status) .. " item=" .. tostring(C_Item.GetItemID(location)) .. " copper=" .. tostring(C_AuctionHouse.SupportsCopperValues and C_AuctionHouse.SupportsCopperValues()) .. " deposit=" .. tostring(deposit) .. " money=" .. tostring(GetMoney())

	local owned = ns.Bags:Find(request.key)
	sent = { confirm = confirm, args = args, key = request.key, had = owned and owned.total or 0 }
	attempt = attempt + 1
	local mine = attempt

	-- Ask the game first, before anything else happens in this press. The game
	-- only accepts a post as the direct result of a real click or key press,
	-- so nothing of ours runs between the press and the request.
	local ok, needsConfirmation = pcall(call, unpack(args, 1, 5))

	Publish({ phase = "posting", key = request.key, message = L.POST_SENDING, created = 0, expected = request.commodity and 1 or request.quantity })
	ns.EventLog:Note("state", Circumstances() .. " " .. kind)
	ns.EventLog:Note(request.commodity and "PostCommodity" or "PostItem", request.duration, request.quantity, args[4], args[5])
	ns.EventLog:Note("returned", ok, needsConfirmation)
	if not ok then
		return Fail(tostring(needsConfirmation), request.key)
	end
	-- The game asks for a second press when a price looks like a mistake.
	if needsConfirmation then
		return AskToConfirm()
	end

	-- The game does not always say a post went through. If it stays silent,
	-- the bags settle it: the item leaving them means it was posted.
	C_Timer.After(ANSWER_SECONDS, function()
		if mine == attempt and Posting.state.phase == "posting" then
			if LeftTheBags() then
				Done()
			else
				Fail(L.POST_NO_ANSWER)
			end
		end
	end)
end

-- The second press, when the game asked for one.
function Posting:Confirm()
	if self.state.phase ~= "confirm" or not pending then
		return
	end
	local waiting = pending
	pending = nil
	local state = self.state
	state.phase, state.message = "posting", L.POST_SENDING
	Publish(state)
	local ok, err = pcall(waiting.confirm, unpack(waiting.args, 1, 5))
	if not ok then
		Fail(tostring(err))
	end
end

-- Backs out of a post waiting for confirmation.
function Posting:Cancel()
	if self.state.phase == "confirm" then
		pending = nil
		Publish({ phase = "idle" })
	end
end

-- The name of an auction house error code, for when the game gives no text.
local function ErrorName(code)
	for name, value in pairs(Enum.AuctionHouseError or {}) do
		if value == code then
			return name
		end
	end
	return tostring(code)
end

local frame = CreateFrame("Frame")
local EVENTS = {
	AUCTION_HOUSE_AUCTION_CREATED = function(state)
		state.created = (state.created or 0) + 1
		if state.created >= (state.expected or 1) then
			state.phase = "done"
			state.message = state.created > 1 and L.POST_DONE_MANY:format(ns.Comma(state.created)) or L.POST_DONE
		else
			state.message = L.POST_PROGRESS:format(ns.Comma(state.created), ns.Comma(state.expected))
		end
		Publish(state)
	end,
	AUCTION_MULTISELL_UPDATE = function(state, created, total)
		state.message = L.POST_PROGRESS:format(ns.Comma(created or 0), ns.Comma(total or state.expected or 0))
		Publish(state)
	end,
	AUCTION_MULTISELL_FAILURE = function()
		Fail(L.POST_STOPPED)
	end,
	-- The game's own way of asking for a second press.
	AUCTION_HOUSE_POST_WARNING = function()
		AskToConfirm()
	end,
	-- The game refusing an addon's call. It names the addon and the function.
	-- "Blocked" means the game wanted something it did not get, such as a
	-- real key press or click. "Forbidden" means addons may not do this at all.
	ADDON_ACTION_BLOCKED = function(_, addon, what)
		if addon == ns.name then
			Fail(L.POST_BLOCKED:format(tostring(what)))
		end
	end,
	ADDON_ACTION_FORBIDDEN = function(_, addon, what)
		if addon == ns.name then
			Fail(L.POST_FORBIDDEN:format(tostring(what)))
		end
	end,
	AUCTION_HOUSE_POST_ERROR = function()
		Fail(L.POST_REFUSED)
	end,
	AUCTION_HOUSE_SHOW_ERROR = function(_, code)
		Fail(L.POST_ERROR:format(ErrorName(code)))
	end,
}
for event in pairs(EVENTS) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	-- These events also fire for things the player does elsewhere. Only a
	-- post of ours in flight is listening.
	if Posting.state.phase == "posting" then
		EVENTS[event](Posting.state, ...)
	end
end)

-- The item leaving the bags is proof enough that the post went through.
Bus:On("BAGS_CHANGED", function()
	if Posting.state.phase == "posting" and LeftTheBags() then
		Done()
	end
end)

Bus:On("AH_CLOSED", function()
	pending = nil
	if Posting.state.phase == "posting" or Posting.state.phase == "confirm" then
		Publish({ phase = "idle" })
	end
end)

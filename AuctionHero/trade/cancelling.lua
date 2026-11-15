-- Cancelling: takes one of the player's own auctions down.
--
-- Two presses, as the game's own window asks: the first shows what cancelling
-- costs (the game keeps the deposit, and may charge more), the second cancels.
-- The game only takes a cancel as the direct result of a click.
--
-- The game answers with AUCTION_CANCELED and the auction's id. That event also
-- fires for other players' auctions while a scan runs, so only our id counts.
-- When no answer comes, the list of owned auctions is asked for again and
-- settles it: the auction gone from it means it was cancelled.
--
-- The state, published as CANCEL_CHANGED:
--   phase      "idle", "confirm", "cancelling", "checking", "done" or "failed"
--   auctionID  the auction being cancelled
--   cost       what cancelling costs, in copper, once known
--   message    what to tell the player
local _, ns = ...
local Bus = ns.Bus
local L = ns.L

local Cancelling = { state = { phase = "idle" } }
ns.Cancelling = Cancelling

local deadlines -- the waits on the game (see trade\deadlines.lua)

local function Publish(phase, message, extra)
	local state = { phase = phase, message = message }
	for name, value in pairs(extra or {}) do
		state[name] = value
	end
	Cancelling.state = state
	deadlines:Enter(phase)
	Bus:Fire("CANCEL_CHANGED", state)
end

local function Keep(extra)
	extra = extra or {}
	extra.auctionID = Cancelling.state.auctionID
	extra.cost = Cancelling.state.cost
	return extra
end

local function Fail(message)
	Publish("failed", message, Keep())
end

local function Owned(auctionID)
	for _, auction in ipairs(ns.Owned.auctions) do
		if auction.auctionID == auctionID then
			return auction
		end
	end
end

-- No answer while cancelling: ask for the list again and let it decide.
-- No list either: say so, and the list stands as it was.
deadlines = ns.Deadlines({
	cancelling = ns.AnswerSeconds.cancel,
	checking = ns.AnswerSeconds.cancel,
}, function(phase)
	if phase == "cancelling" then
		Publish("checking", L.CANCEL_CHECKING, Keep())
		ns.Owned:Request()
	else
		Fail(L.CANCEL_NO_ANSWER)
	end
end)

-- The first press: what cancelling this auction costs.
function Cancelling:Start(auction)
	local phase = self.state.phase
	if phase == "cancelling" or phase == "checking" or not auction then
		return
	end
	local extra = { auctionID = auction.auctionID }
	if not ns.auctionHouseOpen then
		return Publish("failed", L.POST_NEEDS_AH, extra)
	elseif auction.sold then
		return Publish("failed", L.CANCEL_SOLD, extra)
	end
	local can = select(2, pcall(C_AuctionHouse.CanCancelAuction, auction.auctionID))
	if can == false then
		return Publish("failed", L.CANCEL_NOT_ALLOWED, extra)
	end
	local ok, cost = pcall(C_AuctionHouse.GetCancelCost, auction.auctionID)
	extra.cost = ok and cost or 0
	if extra.cost > GetMoney() then
		return Publish("failed", L.CANCEL_OVER_GOLD, extra)
	end
	Publish("confirm", extra.cost > 0 and L.CANCEL_CONFIRM_COST or L.CANCEL_CONFIRM, extra)
end

-- The second press: cancels it.
function Cancelling:Confirm()
	local state = self.state
	if state.phase ~= "confirm" then
		return
	end
	if not ns.auctionHouseOpen then
		return Fail(L.POST_NEEDS_AH)
	elseif not C_AuctionHouse.IsThrottledMessageSystemReady() then
		return Fail(L.POST_BUSY)
	end
	local ok, problem = pcall(C_AuctionHouse.CancelAuction, state.auctionID)
	ns.EventLog:Note("CancelAuction", state.auctionID, state.cost, ok, problem)
	if not ok then
		return Fail(tostring(problem))
	end
	Publish("cancelling", L.CANCEL_SENDING, Keep())
end

-- Backs out of a cancel not yet pressed. Nothing has been sent.
function Cancelling:Back()
	local phase = self.state.phase
	if phase ~= "cancelling" and phase ~= "checking" and phase ~= "idle" then
		Publish("idle")
	end
end

local function Cancelled()
	Publish("done", L.CANCEL_DONE, Keep())
	ns.Owned:Request()
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_CANCELED", "AUCTION_HOUSE_SHOW_ERROR" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, value)
	if Cancelling.state.phase ~= "cancelling" then
		return
	end
	if event == "AUCTION_CANCELED" and value == Cancelling.state.auctionID then
		Cancelled()
	elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
		Fail(L.POST_ERROR:format(tostring(value)))
	end
end)

-- The fresh list settles a cancel the game did not answer.
Bus:On("OWNED_CHANGED", function()
	if Cancelling.state.phase == "checking" then
		if Owned(Cancelling.state.auctionID) then
			Fail(L.CANCEL_NOT_DONE)
		else
			Publish("done", L.CANCEL_DONE, Keep())
		end
	end
end)

Bus:On("AH_CLOSED", function()
	if Cancelling.state.phase ~= "idle" then
		Publish("idle")
	end
end)

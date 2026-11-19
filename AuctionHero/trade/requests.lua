-- Requests: every request to the auction house goes through here, one at a
-- time, in order. The kinds of request and how each is answered are data
-- (data\requests.lua).
--
-- One request is in flight at most. It is answered, refused, blocked or
-- unanswered before the next is sent, and a short gap follows it so the
-- game's own follow-ups are not crossed. An answer is read only once it has
-- gone quiet. A request that is no longer wanted is still waited out: it is
-- cancelled, not cut off, so the order holds.
--
-- It also knows which item's search results the game holds now. A purchase
-- uses an auction from those results only while they are the latest, so the
-- price bought is the price that was read.
--
-- A request (spec):
--   kind      a key of ns.RequestKinds
--   label     what it is for, for the log ("live check", "buy search")
--   itemID, itemKey, auctionID   what it is about, to match its answers
--   send      function(): sends it. Returns false and a problem if it could not.
--   read      function(request): reads the answer once it is quiet. Returns
--             "more" after asking for the next page (request:More), "wait"
--             to wait for more of the answer, or a result.
--   done      function(outcome, result, request). outcome is "answered",
--             "error" (request.errorCode), "unanswered", "blocked" (the game
--             would not send it), "refused", "busy" (a press while another
--             request is in flight) or "closed".
--   onSend    function(request), called as it leaves.
local _, ns = ...
local Bus = ns.Bus

local Requests = { queue = {} }
ns.Requests = Requests

local current -- the request in flight
local holding -- { itemID, itemKey, kind, time }: whose search results the game holds
local lastEnded = 0 -- GetTime() when the last request ended
local pumpLater = false

local function Ready()
	return C_AuctionHouse.IsThrottledMessageSystemReady() and not (ns.Downloader and ns.Downloader:IsRunning())
end

local Pump

local function Finish(request, outcome, result)
	if current ~= request then
		return
	end
	current = nil
	request.ended = true
	lastEnded = GetTime()
	if request.kind.search then
		holding = outcome == "answered" and { itemID = request.itemID, itemKey = request.itemKey, kind = request.kindName, time = GetServerTime() } or nil
	end
	ns.EventLog:Note("request " .. outcome, request.label, request.itemID or request.auctionID, request.errorCode)
	if not request.cancelled and request.done then
		request.done(outcome, result, request)
	end
	Pump()
end

-- The answer has gone quiet: read it.
local function Read(request)
	if current ~= request then
		return
	end
	local result = request.read and request.read(request)
	if result == "more" or result == "wait" then
		return
	end
	Finish(request, "answered", result)
end

-- Starts (or restarts) a wait that belongs to the request's current step.
local function Wait(request, seconds, fn)
	request.step = (request.step or 0) + 1
	local step = request.step
	C_Timer.After(seconds, function()
		if current == request and request.step == step then
			fn()
		end
	end)
end

local function Unanswered(request)
	Wait(request, request.kind.timeout, function()
		Finish(request, request.errorCode and "error" or "unanswered")
	end)
end

-- Sends the next page of an answer, as part of the same request.
local function SendMore(request)
	local more = request.more
	request.more = nil
	local ok, problem = pcall(more)
	ns.EventLog:Note("request more", request.label, request.itemID, ok, problem)
	if not ok then
		return Finish(request, "answered", request.read and request.read(request, true))
	end
	Unanswered(request)
end

function Requests.More(request, fn)
	request.more = fn
	if C_AuctionHouse.IsThrottledMessageSystemReady() then
		SendMore(request)
	end
	return "more"
end

local function Send(request)
	current = request
	request.sending, request.blocked = true, nil
	if request.kind.search then
		holding = nil -- the results the game holds are being replaced
	end
	local ok, sent, problem = pcall(request.send)
	request.sending = nil
	ns.EventLog:Note("request sent", request.label, request.itemID or request.auctionID, ok and sent ~= false, problem or (not ok and sent) or nil)
	if request.blocked then
		return Finish(request, "blocked")
	elseif not ok or sent == false then
		return Finish(request, "refused", tostring(problem or sent))
	end
	if request.onSend then
		request.onSend(request)
	end
	Unanswered(request)
end

-- Sends the next request when nothing is in flight and the game is ready.
function Pump()
	if current or #Requests.queue == 0 or not ns.auctionHouseOpen then
		return
	end
	local wait = ns.RequestRules.gapSeconds - (GetTime() - lastEnded)
	if wait > 0 then
		if not pumpLater then
			pumpLater = true
			C_Timer.After(wait, function()
				pumpLater = false
				Pump()
			end)
		end
		return
	end
	if not Ready() then
		return -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY, or the scan ending, brings us back
	end
	Send(table.remove(Requests.queue, 1))
end

local function Make(spec)
	local request = setmetatable(spec, { __index = Requests })
	request.kindName = spec.kind
	request.kind = assert(ns.RequestKinds[spec.kind], "unknown request kind")
	return request
end

-- Queues a request. Returns it, to cancel later.
function Requests:Ask(spec)
	local request = Make(spec)
	if not ns.auctionHouseOpen then
		if request.done then
			request.done("closed", nil, request)
		end
		return request
	end
	table.insert(self.queue, request)
	Pump()
	return request
end

-- Sends a request now, as part of the player's press, or not at all: the game
-- refuses a purchase sent later. With another request in flight it is not
-- sent, and done hears "busy". Returns whether it left for the game; done
-- still says how it ended, "blocked" included.
function Requests:Press(spec)
	local request = Make(spec)
	if current or not ns.auctionHouseOpen or not Ready() then
		ns.EventLog:Note("request busy", request.label, request.auctionID, current and current.label)
		if request.done then
			request.done(ns.auctionHouseOpen and "busy" or "closed", nil, request)
		end
		return false
	end
	Send(request)
	return true
end

-- No longer wanted. A queued request is dropped; one in flight is waited out,
-- and its done is not called.
function Requests:Cancel(request)
	if not request or request.ended then
		return
	end
	request.cancelled = true
	for index, queued in ipairs(self.queue) do
		if queued == request then
			table.remove(self.queue, index)
			return
		end
	end
end

-- Whether a request is in flight or waiting.
function Requests:Busy()
	return current ~= nil or #self.queue > 0
end

-- The search results the game holds now, when they are this item's from a
-- search that ended at most `seconds` ago: { itemID, itemKey, kind, time }.
function Requests:Holding(itemID, seconds)
	if holding and holding.itemID == itemID and not current
		and (not seconds or GetServerTime() - holding.time <= seconds) then
		return holding
	end
end

-- ========= Answers ==========================================================
local function Matches(how, request, subject)
	if how == "any" then
		return true
	elseif how == "itemKey" then
		return type(subject) == "table" and subject.itemID == request.itemID
	elseif how == "itemID" then
		return subject == request.itemID
	elseif how == "auctionID" then
		return subject == request.auctionID
	end
end

local events = {}
for _, kind in pairs(ns.RequestKinds) do
	for _, list in ipairs({ kind.answers or {}, kind.errors or {}, kind.rereads or {} }) do
		for event in pairs(list) do
			events[event] = true
		end
	end
end
events.AUCTION_HOUSE_THROTTLED_SYSTEM_READY = true
events.ADDON_ACTION_BLOCKED = true

local frame = CreateFrame("Frame")
for event in pairs(events) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, subject)
	if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if current and current.more then
			SendMore(current)
		end
		return Pump()
	end
	local request = current
	if not request then
		return
	end
	local kind = request.kind
	if event == "ADDON_ACTION_BLOCKED" then
		if subject == ns.name then
			if request.sending then
				request.blocked = true
			elseif kind.press then
				Finish(request, "blocked")
			end
		end
		return
	end
	local how = kind.answers and kind.answers[event]
	if how and Matches(how, request, subject) then
		request.answered = true
		Wait(request, kind.settle, function()
			Read(request)
		end)
	elseif kind.errors and kind.errors[event] then
		request.errorCode = subject
		Wait(request, kind.errorSettle or 0, function()
			Finish(request, "error")
		end)
	elseif kind.rereads and kind.rereads[event] and request.answered then
		Wait(request, kind.settle, function()
			Read(request)
		end)
	end
end)

-- A scan ended: what waited on it can go.
Bus:On("DOWNLOAD_STATE", function()
	Pump()
end)

Bus:On("AH_CLOSED", function()
	local queued = Requests.queue
	Requests.queue = {}
	holding = nil
	if current then
		Finish(current, "closed")
	end
	for _, request in ipairs(queued) do
		if not request.cancelled and request.done then
			request.done("closed", nil, request)
		end
	end
end)

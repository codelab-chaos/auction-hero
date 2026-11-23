-- Redraw scheduler: decides when the window's shown tab is drawn. It is only
-- the decisions, with the time handed in, and calls nothing of the game's,
-- so it can be tested on its own (tests/unit/redraw-scheduler.lua). The
-- window (ui\window.lua) asks it, does the drawing, and tells it after.
--
-- The rules (ns.RedrawRule):
--   * Many asks before a draw are one draw.
--   * A draw expected to be slow first waits noticeFrames frames, so the
--     "Refreshing..." notice is on screen while it holds the screen still.
--   * A slow draw comes at most once every slowGapSeconds: asks in between
--     wait and become one draw at the end of the gap (a throttle with a
--     trailing draw, so the last change is always drawn, and a stream of
--     changes cannot hold the screen still frame after frame).
--   * An ask made while a draw runs is never drawn inside it, only after.
--   * Draws that each ask for another while drawing, loopLimit times in a
--     row, are a view feeding itself: the scheduler stops asking.
local _, ns = ...

local Scheduler = {}
Scheduler.__index = Scheduler
ns.RedrawScheduler = Scheduler

function Scheduler.New(rule)
	return setmetatable({
		rule = rule,
		pending = false, -- a draw is waiting
		notice = false, -- the waiting draw is expected to be slow: say so
		wait = 0, -- frames still to pass before it
		notBefore = 0, -- and the earliest time for it
		lastDraw = -math.huge, -- when the last draw ended
		drawing = false,
		loops = 0, -- draws in a row that asked for another while drawing
	}, Scheduler)
end

-- Asks for a draw. slow: the draw is expected to hold the screen still.
-- Returns whether the notice should show.
function Scheduler:Request(now, slow)
	local rule = self.rule
	if self.pending then
		-- Already waiting: a slow ask makes it a slow draw.
		if slow and not self.notice then
			self.notice = true
			self.wait = math.max(self.wait, rule.noticeFrames)
			self.notBefore = math.max(self.notBefore, self.lastDraw + rule.slowGapSeconds)
		end
		return self.notice
	end
	self.pending = true
	self.notice = slow and true or false
	self.wait = slow and rule.noticeFrames or 0
	self.notBefore = slow and (self.lastDraw + rule.slowGapSeconds) or now
	return self.notice
end

-- Called once a frame. True when the waiting draw should run now.
function Scheduler:Frame(now)
	if not self.pending or self.drawing then
		return false
	end
	if self.wait > 0 then
		self.wait = self.wait - 1
		return false
	end
	return now >= self.notBefore
end

-- Before any draw, asked for or not. False when a draw is already running:
-- this one is kept for after it instead of being run inside it.
function Scheduler:Begin()
	if self.drawing then
		self.pending = true
		return false
	end
	self.drawing = true
	self.pending, self.notice, self.wait = false, false, 0
	return true
end

-- After a draw. Returns "loop" when draws have kept asking for more while
-- drawing (the waiting ask is then dropped), else nil.
function Scheduler:Finish(now)
	self.drawing = false
	self.lastDraw = now
	if not self.pending then
		self.loops = 0
		return nil
	end
	self.loops = self.loops + 1
	if self.loops >= self.rule.loopLimit then
		self.pending, self.notice, self.loops = false, false, 0
		return "loop"
	end
end

-- Whether a draw is waiting, and whether it is one to give notice of.
function Scheduler:IsPending()
	return self.pending
end

function Scheduler:ShowsNotice()
	return self.pending and self.notice
end

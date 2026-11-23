-- loads: data/theme.lua, ui/redraw-scheduler.lua
-- The redraw scheduler's rules, with made-up times: no game, no window.
local S = NS.RedrawScheduler
local RULE = NS.RedrawRule
local FRAME = 1 / 60

-- Draws as the window does: Begin, the draw (which may ask for more), Finish.
local function Draw(s, now, during)
	if not s:Begin() then
		return false
	end
	if during then
		during()
	end
	return true, s:Finish(now)
end

-- Runs frames from `from` for `seconds`, drawing when told to, and returns
-- the times of the draws.
local function Run(s, from, seconds, onFrame)
	local drawn = {}
	local now = from
	while now < from + seconds do
		if onFrame then
			onFrame(now)
		end
		if s:Frame(now) then
			Draw(s, now)
			drawn[#drawn + 1] = now
		end
		now = now + FRAME
	end
	return drawn
end

do -- Nothing asked, nothing drawn.
	local s = S.New(RULE)
	check("starts with nothing waiting", s:IsPending(), false)
	check("and a frame draws nothing", s:Frame(0), false)
end

do -- A fast draw comes on the next frame, and many asks are one draw.
	local s = S.New(RULE)
	check("a fast ask gives no notice", s:Request(0, false), false)
	for _ = 1, 9 do
		s:Request(0, false)
	end
	check("it is waiting", s:IsPending(), true)
	check("the next frame draws it", s:Frame(0), true)
	Draw(s, 0)
	check("ten asks were one draw", s:IsPending(), false)
	check("and no more frames draw", s:Frame(FRAME), false)
end

do -- A slow draw gives notice for a frame, then waits out the gap.
	local s = S.New(RULE)
	Draw(s, 10)
	check("a slow ask gives notice", s:Request(10.1, true), true)
	check("and shows it", s:ShowsNotice(), true)
	check("the notice frame draws nothing", s:Frame(10.1), false)
	check("nor before the gap since the last draw", s:Frame(10 + RULE.slowGapSeconds - 0.01), false)
	check("the gap over, it draws", s:Frame(10 + RULE.slowGapSeconds), true)
	Draw(s, 10.3)
	check("and the notice goes", s:ShowsNotice(), false)
end

do -- A slow draw after a quiet spell waits only the notice frames.
	local s = S.New(RULE)
	Draw(s, 0)
	s:Request(100, true)
	local frames = 0
	while not s:Frame(100 + frames * FRAME) do
		frames = frames + 1
	end
	check("only the notice frames pass first", frames, RULE.noticeFrames)
end

do -- A fast ask waiting becomes slow when a slow one joins it.
	local s = S.New(RULE)
	Draw(s, 5)
	s:Request(5.01, false)
	check("asked slow too, it gives notice", s:Request(5.01, true), true)
	check("and waits the notice frame", s:Frame(5.01), false)
	check("and the gap", s:Frame(5.1), false)
	check("then draws", s:Frame(5 + RULE.slowGapSeconds), true)
end

do -- A stream of slow asks is drawn at most once a gap, and the last is drawn.
	local s = S.New(RULE)
	local seconds = 2
	local drawn = Run(s, 0, seconds, function(now)
		s:Request(now, true) -- a change every frame
	end)
	checkTrue("never more than one draw a gap (" .. #drawn .. " in " .. seconds .. "s)", #drawn <= seconds / RULE.slowGapSeconds + 1)
	checkTrue("but it keeps drawing", #drawn >= seconds / RULE.slowGapSeconds - 1)
	for index = 2, #drawn do
		checkTrue("draws a gap apart", drawn[index] - drawn[index - 1] >= RULE.slowGapSeconds - 1e-9)
	end
	-- The asks stop: what was asked last is still drawn.
	local last = drawn[#drawn]
	s:Request(last + FRAME, true)
	local after = Run(s, last + FRAME, 1)
	check("the last change is drawn", #after, 1)
end

do -- A stream of fast asks is drawn every frame: fast tabs are not held back.
	local s = S.New(RULE)
	local drawn = Run(s, 0, 1, function(now)
		s:Request(now, false)
	end)
	checkTrue("a fast tab draws each frame", #drawn >= 59)
end

do -- An ask made while a draw runs is drawn after it, never inside it.
	local s = S.New(RULE)
	s:Request(0, false)
	check("the frame says draw", s:Frame(0), true)
	local inner
	Draw(s, 0, function()
		inner = s:Begin() -- a draw asked for from inside the draw
	end)
	check("not run inside the running one", inner, false)
	check("but kept for after it", s:IsPending(), true)
	check("and drawn on the next frame", s:Frame(FRAME), true)
	check("no frame draws while one runs", (function()
		s:Begin()
		local during = s:Frame(FRAME)
		s:Finish(FRAME)
		return during
	end)(), false)
end

do -- Draws that keep asking for more while drawing are stopped.
	local s = S.New(RULE)
	local verdict
	s:Request(0, false)
	for n = 1, RULE.loopLimit do
		check("frame " .. n .. " draws", s:Frame(n * FRAME), true)
		local _, result = Draw(s, n * FRAME, function()
			s:Request(n * FRAME, false) -- the view changes what it draws from
		end)
		verdict = result
	end
	check("after the limit it is a loop", verdict, "loop")
	check("and nothing waits any more", s:IsPending(), false)
end

do -- One draw that asks again is not a loop, and a clean draw starts the count again.
	local s = S.New(RULE)
	for round = 1, 3 do
		s:Request(round, false)
		s:Frame(round)
		local _, first = Draw(s, round, function()
			s:Request(round, false)
		end)
		check("one ask during a draw is fine", first, nil)
		s:Frame(round + FRAME)
		local _, second = Draw(s, round + FRAME)
		check("a clean draw after it", second, nil)
	end
end

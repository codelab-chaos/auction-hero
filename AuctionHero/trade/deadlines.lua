-- Deadlines: the "ask the game, then wait for its answer" guard every trade
-- flow needs (posting, buying, live checks, item keys).
--
-- A flow says, as data, which of its phases are waiting on the game and for
-- how long (see ns.AnswerSeconds in data\trading.lua). Entering one of those
-- phases starts its wait; entering any phase ends the wait before it. So:
--   - a phase that waits on the game can never be entered without a deadline,
--     whichever code path enters it;
--   - a late timer can never act on a newer request, because each entry is a
--     new turn and a timer only runs in the turn that started it.
local _, ns = ...

-- waits    phase -> seconds, or a function returning seconds (nil: no wait)
-- expired  called with the phase when its wait runs out, still in that turn
function ns.Deadlines(waits, expired)
	local flow = { turn = 0 }

	-- The flow is now in this phase: a new turn, and its wait if it has one.
	function flow:Enter(phase)
		self.turn = self.turn + 1
		local seconds = waits[phase]
		if type(seconds) == "function" then
			seconds = seconds()
		end
		if seconds then
			self:Later(seconds, function()
				expired(phase)
			end)
		end
	end

	-- Ends the current turn without entering a phase: anything waiting in it
	-- is dropped.
	function flow:Drop()
		self.turn = self.turn + 1
	end

	-- Runs fn after a moment, only if the flow is still in the same turn.
	function flow:Later(seconds, fn)
		local mine = self.turn
		C_Timer.After(seconds, function()
			if mine == self.turn then
				fn()
			end
		end)
	end

	-- The current turn, for a callback to check it is still wanted.
	function flow:Turn()
		return self.turn
	end

	return flow
end

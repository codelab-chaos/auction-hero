-- Short ages for list columns: "45m", "5h", "3d", by the steps in
-- ns.AgeSteps (data\theme.lua). Nothing of the game's is called, so it can
-- be tested on its own (tests/unit/age.lua).
local _, ns = ...

-- seconds -> "45m" | "5h" | "3d". Under a minute reads as 1m: it happened.
function ns.ShortAge(seconds)
	seconds = math.max(0, seconds or 0)
	for _, step in ipairs(ns.AgeSteps) do
		if not step.under or seconds < step.under then
			return math.max(1, math.floor(seconds / step.unit)) .. step.suffix
		end
	end
end

-- loads: data/theme.lua, ui/coin-motion.lua
-- The coin drip's motion: coins stay in their box, only ever fall during a
-- fall, fade within 0 to 1, and never move in step.
local M = NS.CoinMotion
local rule = NS.CoinDrip
local inside, falling, bright = true, true, true
local last = {}
for step = 0, 600 do
	local now = step / 120
	for index = 1, rule.count do
		local left, top, alpha = M.At(rule, index, now)
		inside = inside and left >= 0 and left + rule.size <= rule.width and top >= 0 and top + rule.size <= rule.height + 1e-9
		bright = bright and alpha >= 0 and alpha <= 1
		local before = last[index]
		-- Within a fall, a coin only goes down; a jump back up is a new fall.
		if before and top < before.top and before.top - top < (rule.height - rule.size) * 0.5 then
			falling = false
		end
		last[index] = { top = top }
	end
end
checkTrue("coins stay inside their box", inside)
checkTrue("they only fall, and start again at the top", falling)
checkTrue("brightness stays between 0 and 1", bright)
local _, top1 = M.At(rule, 1, 0.3)
local _, top2 = M.At(rule, 2, 0.3)
checkTrue("no two coins at the same height", top1 ~= top2)
local _, startTop, startAlpha = M.At(rule, 1, 0)
check("a fall starts at the top", startTop, 0)
check("unseen as it starts", startAlpha, 0)

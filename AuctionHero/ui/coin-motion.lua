-- Coin motion: where each coin of a coin drip is at a moment, and how
-- bright. Only numbers, nothing of the game's, so it can be tested on its own
-- (tests/unit/coin-motion.lua). Kit.CoinDrip draws it.
local _, ns = ...

local CoinMotion = {}
ns.CoinMotion = CoinMotion

-- For coin `index` of a drip at time `now` (seconds): its left and top
-- offsets inside the box (top grows downward) and its brightness, 0 to 1.
-- Coins are spread evenly through a fall so they never line up, and each
-- falls in its own column across the box.
function CoinMotion.At(rule, index, now)
	local position = now / rule.fallSeconds + (index - 1) / rule.count
	local share = position - math.floor(position)
	local room = math.max(0, rule.height - rule.size)
	local top = room * share ^ rule.gravity
	local columns = math.max(0, rule.width - rule.size)
	local left = rule.count > 1 and columns * (index - 1) / (rule.count - 1) or columns / 2
	local fade = math.min(1, share / rule.fadeIn, (1 - share) / rule.fadeOut)
	return left, top, math.max(0, math.min(1, fade))
end

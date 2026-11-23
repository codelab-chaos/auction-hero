-- Sell chance: how likely an auction is to sell at a price, for the Sell tab.
--
-- Buyers take the cheapest first, so what matters is how many units sit at
-- or under the price (ahead of yours) and how fast the item sells. How fast
-- comes from the scan journal's counts on the item's history (sold units per
-- minute watched). Ahead and yours, divided by that rate, is how long it
-- should take to sell, measured in listing lengths (ns.SellChanceLevels).
local _, ns = ...

local SellChance = {}
ns.SellChance = SellChance

-- Units listed at or under a unit price.
local function Ahead(item, unit)
	local ahead = 0
	for _, tier in ipairs(item and item.tiers or {}) do
		if tier.unit > unit then
			break
		end
		ahead = ahead + tier.units
	end
	return ahead
end

-- For an item as the market holds it, the unit price asked, the units being
-- posted and the duration index chosen:
--   ahead    units listed at or under the price
--   sold     units likely sold, expired and pulled the likely rest of what
--            went, over watched (hours) of scans
--   perDay   sold a day, nil until watched long enough
--   top      the highest unit price seen selling
--   over     true when the price is over every price seen selling
--   level    an entry of ns.SellChanceLevels, nil until watched long enough
function SellChance:Judge(item, unit, units, duration)
	local rule = ns.SellChanceRule
	local reading = { ahead = unit and Ahead(item, unit) or 0 }
	local seen = item and ns.History:Turnover(item.key, rule.days)
	if not unit or not seen then
		return reading
	end
	reading.sold, reading.expired, reading.pulled = seen.sold, seen.expired, seen.pulled
	reading.watched = seen.watched / 60
	reading.top = seen.top
	reading.over = seen.top ~= nil and unit > seen.top
	if reading.watched < rule.minWatchedHours then
		return reading
	end
	local levels = ns.SellChanceLevels
	reading.perDay = seen.sold / reading.watched * 24
	if seen.sold == 0 then
		reading.level = levels[#levels]
		return reading
	end
	local hours = (reading.ahead + (units or 1)) / (seen.sold / reading.watched)
	local window = ns.Assumptions.durationHours[duration] or ns.Assumptions.durationHours[#ns.Assumptions.durationHours]
	local share = hours / window
	for index, level in ipairs(levels) do
		if not level.within or share <= level.within then
			-- Priced over every sale seen: no better than the next level down.
			if reading.over and index < #levels and index == 1 then
				level = levels[2]
			end
			reading.level = level
			break
		end
	end
	return reading
end

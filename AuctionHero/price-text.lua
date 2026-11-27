-- PriceText: a price as a player types it ("5g", "20s", "1g 50s"), in copper,
-- and whether a price is inside a range. The coins are data (ns.PriceUnits,
-- data\theme.lua). Nothing of the game's is called, so it can be tested on
-- its own (tests/unit/price-text.lua).
local _, ns = ...

local PriceText = {}
ns.PriceText = PriceText

-- text -> copper, or nil when it is empty or does not read as a price.
-- units: the coins, largest first, each { letter, copper }. A number with no
-- letter is the coin after the one before it, the first coin when alone.
function PriceText.Parse(text, units)
	local rest = (text or ""):lower():gsub("%s+", "")
	if rest == "" then
		return nil
	end
	local total, nextUnit = 0, 1
	while rest ~= "" do
		local digits, letter, after = rest:match("^([%d%.]+)(%a?)(.*)$")
		local number = digits and tonumber(digits)
		if not number then
			return nil
		end
		local at = letter == "" and nextUnit or nil
		for index, unit in ipairs(units) do
			if unit.letter == letter then
				at = index
			end
		end
		if not at or not units[at] then
			return nil
		end
		total = total + number * units[at].copper
		nextUnit = at + 1
		rest = after
	end
	return math.floor(total + 0.5)
end

-- Whether a price is no less than low and no more than high. A limit that is
-- nil is no limit; no price at all is inside nothing.
function PriceText.Within(price, low, high)
	return price ~= nil and (not low or price >= low) and (not high or price <= high)
end

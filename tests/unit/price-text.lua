-- loads: data/theme.lua, price-text.lua
-- PriceText: a typed price in copper, and whether a price is in a range.
local units = NS.PriceUnits
local function P(text)
	return NS.PriceText.Parse(text, units)
end
check("gold", P("5g"), 50000)
check("silver", P("20s"), 2000)
check("copper", P("7c"), 7)
check("all three", P("1g 50s 25c"), 15025)
check("without spaces, in capitals", P("1G50S"), 15000)
check("a number alone is gold", P("5"), 50000)
check("a number after gold is silver", P("1g 50"), 15000)
check("a number after silver is copper", P("20s5"), 2005)
check("a part of a coin", P("1.5g"), 15000)
check("half typed still reads", P("1."), 10000)
check("nothing is no price", P(""), nil)
check("spaces are nothing", P("  "), nil)
check("a word is no price", P("cheap"), nil)
check("an unknown coin is no price", P("5x"), nil)
check("a number after copper is no price", P("5c 3"), nil)
check("a letter alone is no price", P("g"), nil)

local W = NS.PriceText.Within
check("inside both limits", W(500, 100, 1000), true)
check("the limits themselves are inside", W(100, 100, 100), true)
check("under the least", W(99, 100, nil), false)
check("over the most", W(1001, nil, 1000), false)
check("no limits take any price", W(5, nil, nil), true)
check("no price is inside nothing", W(nil, nil, 1000), false)

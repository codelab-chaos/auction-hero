-- Deals: a price is a deal against the price you would otherwise pay. That
-- is today's floor (the price once the cheapest few units are skipped), held
-- down to the item's usual lowest price once past scans can say what it is.
local ns = Boot()

-- A full scan row: name, count, buyout and item id in their schema places.
local function row(name, itemID, count, buyout)
	return { name, 1, count, 2, true, 0, nil, buyout, 0, buyout, 0, nil, nil, nil, nil, 0, itemID, true, "|Hitem:" .. itemID .. "|h[" .. name .. "]|h", 4 }
end
local function many(rows, name, itemID, copies, buyout)
	for _ = 1, copies do
		rows[#rows + 1] = row(name, itemID, 1, buyout)
	end
end
local function market(rows)
	local built = ns.Market:Build({ meta = { source = "replicate", schema = "replicate", time = 1, place = "Test" }, rows = rows })
	for _, item in ipairs(built.items) do
		ns.Signals:Rate(item)
	end
	return built.byKey
end
local function history(key, lows)
	local points = {}
	for index, low in ipairs(lows) do
		points[index] = (1794000000 + index * 40000) .. ":" .. low .. ":" .. low .. ":10"
	end
	ns.db.historyByMarket["TestRealm / Alliance"] = ns.db.historyByMarket["TestRealm / Alliance"] or { items = {}, folded = {}, scans = 0 }
	ns.db.historyByMarket["TestRealm / Alliance"].items[key] = { u = lows[#lows], m = lows[#lows], lo = lows[1], hi = lows[#lows], n = #lows, d = #lows, f = 1, l = 1, h = table.concat(points, ";") }
end

-- The two cases from the game.
-- Field Guide: one stray unit at 6s 97c, fifty more from 8s 96c up.
local rows = {}
many(rows, "Field Guide", 1, 1, 697)
many(rows, "Field Guide", 1, 5, 896)
many(rows, "Field Guide", 1, 13, 897)
many(rows, "Field Guide", 1, 15, 997)
many(rows, "Field Guide", 1, 17, 998)
-- The blueprint: one at 12s, seven at 60s, and scans that saw it from 49s up.
many(rows, "Blueprint", 2, 1, 1200)
many(rows, "Blueprint", 2, 7, 6000)
history("2:Blueprint", { 4900, 5840, 5940, 4900, 5000, 5955, 1200 })
-- One of a kind: nothing to measure it against.
many(rows, "Lone", 3, 1, 500)
local items = market(rows)
local guide, blueprint, lone = items["1:Field Guide"], items["2:Blueprint"], items["3:Lone"]

check("the floor skips the stray cheap unit", guide.floor, 897)
check("one cheap unit is measured against what the rest cost", guide.deal, 22)
check("and it says how many are at that price", guide.dealUnits, 1)
checkTrue("which is under the bar for a badge", guide.deal < ns.DealBadgeRule.percent)
local reading = ns.Signals:Deal(guide, 1, 697)
check("the deal meter reads it", reading.known, true)
checkMatch("against the price you would otherwise pay", reading.reasons[1], "^22%% under the 8s 97c you would otherwise pay")
checkMatch("and says past scans cannot back it yet", reading.reasons[2], "Past scans cannot back it yet")
check("buying into the floor is no deal at all", ns.Signals:Deal(guide, 6, 697 + 5 * 896).level, ns.DealLevels.fair)

check("the blueprint's floor today is the 60s wall", blueprint.floor, 6000)
check("but past scans hold the baseline to its usual low", ns.Signals:Baseline(blueprint).price, 5000)
check("12s is far under that", blueprint.deal, 76)
checkTrue("so it earns a badge", blueprint.deal >= ns.DealBadgeRule.percent)
reading = ns.Signals:Deal(blueprint, 1, 1200)
check("and a strong reading, backed by history", reading.level, ns.DealLevels.resell)
checkMatch("which it says", reading.reasons[2], "what past scans show")
checkMatch("with the caveat that these are asking prices", reading.reasons[3], "asking prices")

check("one of a kind has no floor", lone.floor, nil)
check("so no deal is claimed", lone.deal, nil)
check("and the meter says it cannot tell", ns.Signals:Deal(lone, 1, 500).known, false)

-- Asking prices that crept up do not turn an ordinary price into a deal.
rows = {}
many(rows, "Crept", 4, 3, 1000)
many(rows, "Crept", 4, 9, 2000)
history("4:Crept", { 950, 1000, 1050, 1000 })
local crept = market(rows)["4:Crept"]
check("the baseline stays at the usual low", ns.Signals:Baseline(crept).price, 1000)
check("so the old normal price is not a deal", crept.deal, nil)

-- Two listings far apart, and no past scans: no telling which is the odd one.
rows = {}
many(rows, "Pair", 5, 1, 1000)
many(rows, "Pair", 5, 1, 9000)
local pair = market(rows)["5:Pair"]
check("two prices and no history earn no badge", pair.deal, nil)
check("though the meter still reads the order", ns.Signals:Deal(pair, 1, 1000).level, ns.DealLevels.great)

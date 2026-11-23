-- The scan journal keeps each scan as the change from the one before, so an
-- earlier scan can be rebuilt exactly, and counts what sold between them.
local ns = Boot()
ns.TurnoverRule.shown = true -- shelved for players; the counting is still tested
OpenAuctionHouse()
Scan()
local J = ns.ScanJournal
local KEY = "2003:Light Leather"

check("the first scan has nothing to compare with", J:Stats().scans, 0)
checkTrue("the journal is on by default", J:IsOn())

-- An hour on, some leather is gone. How each one is split between sold,
-- ran out and taken down is the sale odds' job (tests/unit/sale-odds.lua).
-- Here: that every unit gone is accounted for once, and that what could not
-- have run out counts as sold, and what must have run out does not.
local first = ns.Store:GetSourceSnapshot("replicate")
local before = J:Listings(first)
local gone = {}
MOCK.gone = {}
for i = 0, 299 do
	local r = REPLICATE_REF[i]
	if r[17] == 2003 and #gone < 12 then
		gone[#gone + 1] = r
		MOCK.gone[i] = true
	end
end
local function Bounds(elapsed)
	local bands, pull = ns.Assumptions.timeLeftBands, ns.TurnoverRule.pullShare
	local total, safeSold, mustRunOut, sellable, top = 0, 0, 0, 0, 0
	for _, r in ipairs(gone) do
		local range = bands[tostring(r.timeLeft)]
		total = total + r[3]
		if r[10] > 0 or r[11] > 0 then
			sellable = sellable + r[3] -- a buyout, or a bid that wins at the end
		end
		if r[10] > 0 and range.min > elapsed then
			safeSold = safeSold + r[3] * (1 - pull) -- could not have run out
			top = math.max(top, math.floor(r[10] / r[3]))
		elseif range.max <= elapsed and r[11] == 0 then
			mustRunOut = mustRunOut + r[3] -- had to run out, with no bid
		end
	end
	return total, safeSold, mustRunOut, sellable, top
end
local function near(label, got, want)
	checkTrue(label .. " (" .. tostring(got) .. " for " .. want .. ")", got and math.abs(got - want) < 0.5)
end
SkipTime(3600)
Scan()

local stats = J:Stats()
check("the second scan is journaled", stats.scans, 1)
checkTrue("reaching back an hour", stats.reach >= 3600 and stats.reach < 3660)

-- Walking back one change gives the first scan, listing for listing.
local rebuilt = J:Rebuild(1)
local same, listings = true, 0
for key, copies in pairs(before) do
	listings = listings + 1
	if rebuilt[key] ~= copies then
		same = false
	end
end
for key in pairs(rebuilt) do
	if not before[key] then
		same = false
	end
end
checkTrue("the first scan rebuilds exactly", same and listings > 0)
check("and back 0 is the saved scan", next(J:Rebuild(0)) ~= nil, true)

local seen = ns.History:Turnover(KEY, 7)
checkTrue("the leather's history has sales", seen ~= nil)
local delta = AuctionHeroDB.scanJournal.deltas[1]
local total, safeSold, mustRunOut, sellable, top = Bounds(delta.time - delta.from)
checkTrue("some could not have run out, some must have", safeSold > 0 and mustRunOut > 0)
near("every unit gone is counted once", seen.sold + seen.expired + seen.pulled, total)
checkTrue("what could not have run out counts as sold", seen.sold >= safeSold - 0.5)
checkTrue("nothing that cannot sell is sold", seen.sold <= sellable + 0.5)
checkTrue("what had to run out is not sold", seen.expired >= mustRunOut - 0.5)
checkTrue("pulled is the smallest", seen.pulled < seen.sold)
check("watched for the hour between", seen.watched, 60)
checkTrue("the highest price likely sold is at least the dearest sure one", seen.top >= top)
-- Gone with lots of time left while the same stack was posted again cheaper:
-- that looks like a seller taking theirs down to undercut.
local leatherVariant
for key in pairs(before) do
	local variant = J.Parts(key)
	local entry = J:Variant(variant)
	if entry and entry[J.VARIANT.itemID] == 2003 and entry[J.VARIANT.name] == "Light Leather" then
		leatherVariant = variant
	end
end
local function Pair(reposted)
	local counts = { [leatherVariant .. ":5:0:500:0:4"] = -1 }
	if reposted then
		counts[leatherVariant .. ":5:0:450:0:4"] = 1
	end
	return ns.Turnover:Read({ kind = "scan", time = 4600, from = 1000, auctions = 1, before = 1 }, counts, nil)[KEY]
end
near("alone, a pull is unlikely", Pair(false).pulled, 5 * ns.TurnoverRule.pullShare)
near("with a fresh repost, much likelier", Pair(true).pulled, 5 * ns.TurnoverRule.repostPullShare)
near("and the rest sold", Pair(true).sold, 5 * (1 - ns.TurnoverRule.repostPullShare))
check("an item that lost nothing sold nothing", ns.History:Turnover("2001:Copper Ore", 7).sold, 0)

-- An hour is not long enough to judge.
local market = ns.Window:Market()
local leather = market.byKey[KEY]
local early = ns.SellChance:Judge(leather, leather.min, 1, 3)
check("too early for a verdict", early.level, nil)
checkTrue("but it counts what is cheaper", early.ahead > 0)
check("nothing is under the lowest price but itself", early.ahead, leather.tiers[1].units)

-- Ninety minutes more, nothing else goes. The scans share a graph point, so
-- the counts add up on it.
local soldBefore = ns.History:Turnover(KEY, 7).sold
SkipTime(5400)
Scan()
seen = ns.History:Turnover(KEY, 7)
near("the sales stay on the shared point", seen.sold, soldBefore)
check("and the watching adds up", seen.watched, 150)
local watchedHours = seen.watched / 60
check("two changes kept", J:Stats().scans, 2)

leather = ns.Window:Market().byKey[KEY]
local reading = ns.SellChance:Judge(leather, leather.min, 1, 3)
checkTrue("now there is a verdict", reading.level ~= nil)
near("from the rate", reading.perDay, seen.sold / watchedHours * 24)
local dear = ns.SellChance:Judge(leather, leather.max * 10, 1, 3)
checkTrue("a price over every sale seen says so", dear.over)
check("everything listed is ahead of it", dear.ahead, leather.units)

-- The Sell tab says it under the price rules.
ShowTab("sell")
local tile = Frames(function(frame)
	return frame.slot ~= nil and frame.scripts.OnClick ~= nil and frame.slot.item and frame.slot.item.name == "Light Leather"
end)[1]
tile.scripts.OnClick(tile)
Tick(5)
local labels = {}
for _, level in ipairs(ns.SellChanceLevels) do
	labels[level.label] = true
end
checkTrue("the sell form shows the chance", #Frames(function(frame)
	return type(frame.text) == "string" and labels[frame.text]
end) > 0)
checkTrue("with what it is from", #Frames(function(frame)
	return type(frame.text) == "string" and frame.text:find("sell a day$") ~= nil
end) > 0)

-- Turned off, the journal is dropped and nothing more is kept.
J:SetDays(0)
check("off keeps nothing", AuctionHeroDB.scanJournal, nil)
SkipTime(3600)
Scan()
check("and journals nothing", AuctionHeroDB.scanJournal, nil)
J:SetDays(7)

-- Old changes fall off, and the variants nothing points to go with them.
SkipTime(3600)
Scan()
SkipTime(3600)
Scan()
check("back on, it starts again", J:Stats().scans, 2)
SkipTime(8 * 86400)
J:Trim(GetServerTime())
check("changes older than the days kept are dropped", J:Stats().scans, 0)
check("and their variants", #AuctionHeroDB.scanJournal.variants, 0)

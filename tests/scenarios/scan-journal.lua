-- The scan journal keeps each scan as the change from the one before, so an
-- earlier scan can be rebuilt exactly, and counts what sold between them.
local ns = Boot()
OpenAuctionHouse()
Scan()
local J = ns.ScanJournal
local KEY = "2003:Light Leather"

check("the first scan has nothing to compare with", J:Stats().scans, 0)
checkTrue("the journal is on by default", J:IsOn())

-- An hour on, some leather is gone. Each is split by likelihood: the share
-- of its time left band the hour reaches past ran out, a small share of the
-- rest was taken down, and the remainder sold.
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
local function Expected(elapsed)
	local bands, pull = ns.Assumptions.timeLeftBands, ns.TurnoverRule.pullShare
	local sold, expired, pulled, top = 0, 0, 0, 0
	for _, r in ipairs(gone) do
		local range = bands[tostring(r.timeLeft)]
		local out = r[10] == 0 and 1 or math.max(0, math.min(1, (elapsed - range.min) / (range.max - range.min)))
		if r[11] > 0 then
			sold = sold + r[3] * out
		else
			expired = expired + r[3] * out
		end
		sold = sold + r[3] * (1 - out) * (1 - pull)
		pulled = pulled + r[3] * (1 - out) * pull
		if r[10] > 0 and out < 0.5 then
			top = math.max(top, math.floor(r[10] / r[3]))
		end
	end
	return sold, expired, pulled, top
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
local sold, expired, pulled, top = Expected(delta.time - delta.from)
checkTrue("some of each outcome", sold > 0 and expired > 0 and pulled > 0)
near("sold: likely bought", seen.sold, sold)
near("expired: likely ran out", seen.expired, expired)
near("pulled: rarely, so a small share", seen.pulled, pulled)
checkTrue("pulled is the smallest", seen.pulled < seen.sold)
check("watched for the hour between", seen.watched, 60)
check("the highest price likely sold", seen.top, top)
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
SkipTime(5400)
Scan()
seen = ns.History:Turnover(KEY, 7)
near("the sales stay on the shared point", seen.sold, sold)
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

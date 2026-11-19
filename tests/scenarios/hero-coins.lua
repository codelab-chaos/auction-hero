-- Hero Coins pile up from using Auction Hero, each way capped per day, plus
-- streak bonuses for scanning days in a row. Scan confidence says how many of
-- the last days had a scan. Both show on the scan card and the Progress tab.
local ns = Boot()
local Coins, DAY, HOUR = ns.HeroCoins, 86400, 3600
local now = GetServerTime()
local t = date("*t", now)
local noon = now - (t.hour * HOUR + t.min * 60 + t.sec) + 12 * HOUR + 7 * DAY -- a local day's middle

check("no coins to start", Coins:Balance(), 0)
OpenAuctionHouse()
check("opening the auction house pays one, and the tab it shows a first look", Coins:Balance(), 6)
ns.Bus:Fire("AH_OPENED")
check("once a day", Coins:Balance(), 6)

-- Scans, by the clock given, so the day is known.
Coins:Earn("scan", nil, noon - 5 * HOUR)
check("the day's first scan pays ten", Coins:Balance(), 16)
check("and meets the day's goal", Coins:Met("scan", noon), true)
Coins:Earn("scan", nil, noon)
Coins:Earn("scan", nil, noon + HOUR)
check("more scans that day pay nothing more", Coins:Balance(), 16)

-- Caps per day, and once per key.
for _ = 1, 12 do
	Coins:Earn("buy", nil, noon)
end
check("buys pay up to the day's cap", Coins:Today("buy", noon), 10)
check("ten of them", Coins:Balance(), 36)
Coins:Earn("buy", nil, noon + DAY)
check("and again the next day", Coins:Balance(), 38)
ns.Bus:Fire("TAB_SHOWN", "ledger")
ns.Bus:Fire("TAB_SHOWN", "ledger")
check("a tab's first look pays five, once", Coins:Balance(), 43)
ns.Bus:Fire("LEDGER_CHANGED", { kind = "sale", quantity = 1, name = "Linen Cloth", amount = 100 })
ns.Bus:Fire("LEDGER_CHANGED", { kind = "buy", quantity = 1, name = "Linen Cloth", amount = 100 })
check("a sale pays three, a ledger buy nothing", Coins:Balance(), 46)
check("the latest earning first", Coins:Recent()[1].way, "sale")

-- Days in a row.
check("one day is a streak of one", Coins:Streak(noon), 1)
Coins:Earn("scan", nil, noon + DAY)
check("two days", Coins:Streak(noon + DAY), 2)
local before = Coins:Balance()
Coins:Earn("scan", nil, noon + 2 * DAY)
check("three days pay the scan and a bonus of fifteen", Coins:Balance(), before + 25)
check("a day not yet scanned does not break the streak", Coins:Streak(noon + 3 * DAY), 3)
check("a day missed does", Coins:Streak(noon + 4 * DAY), 0)
Coins:Earn("scan", nil, noon + 5 * DAY)
Coins:Earn("scan", nil, noon + 6 * DAY)
before = Coins:Balance()
Coins:Earn("scan", nil, noon + 7 * DAY)
check("a new streak of three earns the bonus again", Coins:Balance(), before + 25)

-- Scan confidence: days with a scan among the last thirty.
local times = {}
local ScanTimes = ns.History.ScanTimes
ns.History.ScanTimes = function() return times end
local reading = ns.ScanConfidence:Reading(noon)
check("no scans, no confidence", reading.percent, 0)
check("is a guess", reading.level.label, ns.L.SCAN_CONF_GUESS)
for day = 0, 9 do
	times[#times + 1] = noon - day * DAY
	times[#times + 1] = noon - day * DAY - HOUR -- two scans in a day count as one day
end
times[#times + 1] = noon - 40 * DAY -- too long ago to count
reading = ns.ScanConfidence:Reading(noon)
check("ten days scanned", reading.days, 10)
check("are half of the twenty for full confidence", reading.percent, 50)
check("fairly sure", reading.level.label, ns.L.SCAN_CONF_FAIR)
for day = 10, 25 do
	times[#times + 1] = noon - day * DAY
end
check("it tops out at full", ns.ScanConfidence:Reading(noon).percent, 100)
ns.History.ScanTimes = ScanTimes

-- The scan card shows it.
Scan()
ShowTab("buy")
ns.Bus:Fire("DOWNLOAD_STATE", { phase = "waiting", source = { id = "replicate" } })
Tick(5)
local function shows(pattern)
	return #Frames(function(frame)
		return type(frame.text) == "string" and frame.text:match(pattern) ~= nil
	end) > 0
end
checkTrue("the card shows the day's scan", shows("^One full scan$"))
checkTrue("the streak", shows("^Streak: %d+ days$") or shows("^Streak: 1 day$") or shows("^No streak yet$"))
checkTrue("scan confidence", shows("^%d+%%  "))
checkTrue("and the balance", shows("^" .. ns.Comma(Coins:Balance()) .. "$"))

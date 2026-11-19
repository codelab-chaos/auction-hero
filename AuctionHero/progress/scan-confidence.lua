-- Scan confidence: how well the remembered prices cover the market, from how
-- many of the last days had a full scan (ns.ScanConfidenceRule, data\rewards.lua).
-- A deal is a price under what something usually costs; the usual cost is
-- only as good as the scans behind it.
local _, ns = ...

local ScanConfidence = {}
ns.ScanConfidence = ScanConfidence

local SECONDS_PER_DAY = 86400

-- The local calendar day of a server time, as "2026-11-19".
function ns.DayKey(time)
	return date("%Y-%m-%d", time or GetServerTime())
end

-- The last window days, oldest first: { { day = "2026-11-19", time, scanned } }.
function ScanConfidence:Days(now)
	local rule = ns.ScanConfidenceRule
	now = now or GetServerTime()
	local from = now - rule.windowDays * SECONDS_PER_DAY
	local scanned = {}
	for _, time in ipairs(ns.History:ScanTimes()) do
		if time > from and time <= now then
			scanned[ns.DayKey(time)] = true
		end
	end
	local days = {}
	for back = rule.windowDays - 1, 0, -1 do
		local time = now - back * SECONDS_PER_DAY
		local day = ns.DayKey(time)
		days[#days + 1] = { day = day, time = time, scanned = scanned[day] == true }
	end
	return days
end

-- { percent, days, window, level }: days is how many of the last window days
-- had a scan, level the rule's level for the percent.
function ScanConfidence:Reading(now)
	local rule = ns.ScanConfidenceRule
	local count = 0
	for _, day in ipairs(self:Days(now)) do
		if day.scanned then
			count = count + 1
		end
	end
	local percent = math.min(100, math.floor(count / rule.fullAtDays * 100 + 0.5))
	local level = rule.levels[1]
	for _, candidate in ipairs(rule.levels) do
		if percent >= candidate.from then
			level = candidate
		end
	end
	return { percent = percent, days = count, window = rule.windowDays, level = level }
end

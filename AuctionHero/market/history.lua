-- History: the price memory. Every full scan is folded into one small record
-- per item (see ns.HistoryRule in data\trading.lua for the fields), so the
-- addon knows what things usually go for without keeping old scans.
local _, ns = ...
local Bus = ns.Bus

local History = {}
ns.History = History

local SECONDS_PER_DAY = 86400

local function Scope()
	return (GetRealmName() or "?") .. " / " .. (UnitFactionGroup("player") or "?")
end
local function Store(scope)
	scope = scope or Scope()
	local stores = ns.db.historyByMarket
	if not stores[scope] then stores[scope] = { items={}, folded={}, scans=0 } end
	return stores[scope]
end

function History:Get(key)
	return Store().items[key]
end

-- How many scans have been folded in.
function History:ScanCount()
	return Store().scans
end

-- What an item usually goes for: its remembered price once enough scans have
-- seen it, otherwise the current scan's median.
function History:Usual(item)
	local record = Store().items[item.key]
	if record and record.n >= ns.HistoryRule.trustAfterScans then
		return record.u
	end
	return item.median
end

-- How many days back an item's graph points reach: the player's choice, else the default.
function History:GraphDays()
	return ns.db.graphDays or ns.HistoryRule.graphPoints
end

-- Sets how many days of points to keep, within the allowed range. Records are
-- trimmed to a shorter length as scans next touch them, not all at once, so
-- until the next scan the longest length since the last one is remembered:
-- going back to it before then loses nothing.
function History:SetGraphDays(days)
	local rule = ns.HistoryRule
	local before = self:GraphDays()
	ns.db.graphDays = math.max(rule.graphPointsMin, math.min(rule.graphPointsMax, math.floor(days)))
	local from = math.max(ns.db.graphTrimFrom or before, before)
	ns.db.graphTrimFrom = ns.db.graphDays < from and from or nil
	return ns.db.graphDays
end

-- The longer length the graphs still reach until the next scan trims them,
-- or nil when nothing is waiting to be trimmed.
function History:PendingTrim()
	return ns.db.graphTrimFrom
end

-- A graph point as it is stored: "time:median:lowest:units". Points written
-- before every scan had its own point carry a day number instead of a time;
-- those are read as noon of that day.
local function PointTime(stamp)
	stamp = tonumber(stamp)
	return stamp < 10000000 and stamp * SECONDS_PER_DAY + SECONDS_PER_DAY / 2 or stamp
end

-- Adds a scan's point to a record's graph string.
--
-- Points are kept at least ns.HistoryRule.pointHours apart. The newest scan
-- always shows as the last point: a scan made sooner than that after the
-- point before last replaces the last one instead of adding to it. So one
-- scan is one point, a second scan is a second point, and from there a new
-- point is added each time the spacing has passed. Points older than the
-- graph's reach are dropped.
local function AddPoint(packed, time, median, low, units, lowUnits)
	local spacing = ns.HistoryRule.pointHours * 3600
	local oldest = time - History:GraphDays() * SECONDS_PER_DAY
	local kept, times = {}, {}
	for stamp, rest in (packed or ""):gmatch("(%d+)(:[^;]+)") do
		local at = PointTime(stamp)
		if at > oldest then
			kept[#kept + 1] = at .. rest
			times[#times + 1] = at
		end
	end
	local point = time .. ":" .. median .. ":" .. low .. ":" .. units .. ":" .. (lowUnits or 0)
	local settled = times[#times - 1] -- the point before the last
	if settled and time - settled < spacing then
		kept[#kept] = point
	else
		kept[#kept + 1] = point
	end
	return table.concat(kept, ";")
end

local function Update(record, median, low, units, day, time, lowUnits)
	local rule = ns.HistoryRule
	if not record then
		return {
			u = median, m = median, lo = low, hi = median, n = 1, d = 1, f = day, l = day,
			lou = lowUnits, lot = time,
			h = AddPoint(nil, time, median, low, units, lowUnits),
		}
	end
	record.u = math.floor(record.u + (median - record.u) * rule.smoothing + 0.5)
	record.m = median
	-- The lowest price ever seen, with how many were at it and when. Seen at
	-- that price again, the count and the time are brought up to date.
	if low <= record.lo then
		record.lo, record.lou, record.lot = low, lowUnits, time
	end
	record.hi = math.max(record.hi, median)
	record.n = record.n + 1
	if day ~= record.l then
		record.d = record.d + 1
		record.l = day
	end
	record.h = AddPoint(record.h, time, median, low, units, lowUnits)
	return record
end

-- An item's graph points, oldest first: { time, day, median, low, units, lowUnits }.
-- time is the scan's server time. day is that time in days since 1970.
-- lowUnits is how many were at the lowest price, nil for points saved before
-- that was kept.
function History:Points(key)
	local record = self:Get(key)
	local points = {}
	if record and record.h then
		for chunk in record.h:gmatch("[^;]+") do
			local stamp, median, low, units, lowUnits = chunk:match("^(%d+):(%d+):(%d+):(%d+):?(%d*)")
			if stamp then
				local time = PointTime(stamp)
				points[#points + 1] = {
					time = time,
					day = math.floor(time / SECONDS_PER_DAY),
					median = tonumber(median),
					low = tonumber(low),
					units = tonumber(units),
					lowUnits = tonumber(lowUnits),
				}
			end
		end
	end
	return points
end

-- What an item's lowest price usually is: the middle of the lows its graph
-- points hold. Nil until enough points are in to say (ns.BaselineRule).
function History:TypicalLow(key)
	local points = self:Points(key)
	if #points < ns.BaselineRule.historyPoints then
		return nil
	end
	local lows = {}
	for index, point in ipairs(points) do
		lows[index] = point.low
	end
	table.sort(lows)
	return lows[math.ceil(#lows / 2)]
end

-- The points inside the last `days` days, counted back from the newest point.
function History:InRange(points, days)
	local newest = points[#points]
	local kept = {}
	if newest then
		for _, point in ipairs(points) do
			if point.time > newest.time - days * SECONDS_PER_DAY then
				kept[#kept + 1] = point
			end
		end
	end
	return kept
end

-- The headline numbers for a run of points, or nil when there are none:
--   usual (the newest median), lowest, highest,
--   scans (how many points) and days (how many different days they fall on),
--   change: percent the usual price moved from the first point to the last
function History:Summarize(points)
	local first, last = points[1], points[#points]
	if not first then
		return nil
	end
	local lowest, highest = first.low, first.median
	local days, lastDay = 0, nil
	for _, point in ipairs(points) do
		lowest = math.min(lowest, point.low)
		highest = math.max(highest, point.median)
		if point.day ~= lastDay then
			days, lastDay = days + 1, point.day
		end
	end
	local change
	if #points > 1 and first.median > 0 then
		change = math.floor((last.median - first.median) / first.median * 100 + 0.5)
	end
	return { usual = last.median, lowest = lowest, highest = highest, change = change, scans = #points, days = days }
end

-- A price seen outside a full scan (a live check of one item). It is not a
-- scan, so it adds no point and counts for nothing else, but a new lowest
-- price is a real one however it was seen.
function History:SawLow(key, low, units, time)
	local record = self:Get(key)
	if record and low and low < record.lo then
		record.lo, record.lou, record.lot = low, units, time
	end
end

-- Folds one scan's market into the records. Runs inside a job.
-- A scan is only ever folded once, however often it is analyzed.
function History:Fold(market)
	if not market or not market.time or market.stale then return false end
	local store = Store(market.place)
	if store.folded[market.time] then
		return false
	end
	ns.db.graphTrimFrom = nil -- this scan trims what it sees to the current length
	local day = math.floor(market.time / SECONDS_PER_DAY)
	local records = store.items

	for count, item in ipairs(market.items) do
		if item.median then
			local cheapest = ns.Market.PricePoints(item)[1]
			records[item.key] = Update(records[item.key], item.median, item.min, item.units, day, market.time, cheapest and cheapest.units)
		end
		if count % 200 == 0 then
			ns.Breathe()
		end
	end

	-- Forget what has not been seen for a long while.
	local oldest = day - ns.HistoryRule.forgetDays
	local count = 0
	for key, record in pairs(records) do
		if record.l < oldest then
			records[key] = nil
		end
		count = count + 1
		if count % 500 == 0 then
			ns.Breathe()
		end
	end

	store.folded[market.time] = true
	store.scans = store.scans + 1
	return true
end

function History:Clear()
	ns.db.historyByMarket[Scope()] = { items = {}, folded = {}, scans = 0 }
	Bus:Fire("HISTORY_CHANGED")
end

Bus:On("INIT", function()
	ns.db.historyByMarket = ns.db.historyByMarket or {}
	local legacy = ns.db.history
	if type(legacy) == "table" and type(legacy.items) == "table" then
		local snapshot = ns.Store and ns.Store:GetSourceSnapshot("replicate")
		local scope = snapshot and snapshot.meta.place or Scope()
		if not ns.db.historyByMarket[scope] then
			legacy.folded, legacy.scans = legacy.folded or {}, legacy.scans or 0
			ns.db.historyByMarket[scope] = legacy
		end
	end
	ns.db.history = nil
	Store()
end)

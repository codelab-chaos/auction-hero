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

-- When each remembered scan was taken (server times), in no order.
function History:ScanTimes()
	local times = {}
	for time in pairs(Store().folded) do
		times[#times + 1] = time
	end
	return times
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
	local rule = ns.HistoryRule
	-- A longer length saved before the cap is read as the cap.
	return math.min(ns.db.graphDays or rule.graphPoints, rule.graphPointsMax)
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
		-- The sales counted on the point being replaced carry over to it.
		local turnover = kept[#kept] and kept[#kept]:match("^%d+:%d+:%d+:%d+:%d+(:.+)$")
		kept[#kept] = point .. (turnover or "")
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

-- An item's graph points, oldest first: { time, day, median, low, units,
-- lowUnits, sold, expired, pulled, watched, top }.
-- time is the scan's server time. day is that time in days since 1970.
-- lowUnits is how many were at the lowest price, nil for points saved before
-- that was kept. sold, expired, pulled (likely units), watched (minutes) and
-- top are what the scan
-- journal counted going while the point's scans watched (market\turnover.lua),
-- nil until it has counted any.
function History:Points(key)
	local record = self:Get(key)
	local points = {}
	if record and record.h then
		for chunk in record.h:gmatch("[^;]+") do
			local stamp, median, low, units, lowUnits = chunk:match("^(%d+):(%d+):(%d+):(%d+):?(%d*)")
			if stamp then
				local time = PointTime(stamp)
				local sold, expired, pulled, watched, top = chunk:match("^%d+:%d+:%d+:%d+:%d+:([%d%.]+):([%d%.]+):([%d%.]+):(%d+):(%d+)")
				points[#points + 1] = {
					time = time,
					day = math.floor(time / SECONDS_PER_DAY),
					median = tonumber(median),
					low = tonumber(low),
					units = tonumber(units),
					lowUnits = tonumber(lowUnits),
					sold = tonumber(sold),
					expired = tonumber(expired),
					pulled = tonumber(pulled),
					watched = tonumber(watched),
					top = tonumber(top) ~= 0 and tonumber(top) or nil,
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

-- What past scans say an item goes for, for when nobody is selling it now:
-- its typical lowest price when enough points are in, else the lowest the
-- newest point saw. The same order the tooltip's "worth" line uses, so the
-- two agree. Returns { price, typical, time (of the newest point) } or nil.
function History:PastPrice(key)
	local points = self:Points(key)
	local newest = points[#points]
	if not newest then
		return nil
	end
	local typical = self:TypicalLow(key)
	return { price = typical or newest.low, typical = typical ~= nil, time = newest.time }
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
--   change: percent the usual price moved from the first point to the last,
--     counting only points with enough for sale (nil when fewer than two)
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
	local from, to
	for _, point in ipairs(points) do
		if point.units >= ns.HistoryRule.changeMinUnits then
			from = from or point
			to = point
		end
	end
	local change
	if from and to ~= from and from.median > 0 then
		change = math.floor((to.median - from.median) / from.median * 100 + 0.5)
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

-- A likely count as kept on a point: whole, or to a tenth.
local function Tenths(value)
	local text = ("%.1f"):format(value)
	return (text:gsub("%.0$", ""))
end

-- Adds what a scan pair saw going (ns.Turnover:Read) to each item's newest
-- point. Scans close together share a point, so their counts add up on it.
-- Runs inside a job.
function History:AddTurnover(place, facts)
	if not facts then
		return false
	end
	local records = Store(place).items
	local count = 0
	for key, fact in pairs(facts) do
		local record = records[key]
		if record and record.h then
			local head, last = record.h:match("^(.-)([^;]+)$")
			local base = last:match("^(%d+:%d+:%d+:%d+:%d+)") or (last:match("^(%d+:%d+:%d+:%d+)") .. ":0")
			local sold, expired, pulled, watched, top = last:match("^%d+:%d+:%d+:%d+:%d+:([%d%.]+):([%d%.]+):([%d%.]+):(%d+):(%d+)")
			last = base .. ":" .. Tenths((tonumber(sold) or 0) + fact.sold) .. ":" .. Tenths((tonumber(expired) or 0) + fact.expired)
				.. ":" .. Tenths((tonumber(pulled) or 0) + fact.pulled) .. ":" .. ((tonumber(watched) or 0) + fact.watched)
				.. ":" .. math.max(tonumber(top) or 0, fact.top or 0)
			record.h = head .. last
		end
		count = count + 1
		if count % 200 == 0 then
			ns.Breathe()
		end
	end
	return true
end

-- What an item has likely done over the last `days` days, or nil when no
-- scan pair has watched it: { sold, expired, pulled, watched (minutes), top },
-- the counts in units, likely ones so not always whole.
function History:Turnover(key, days)
	local since = GetServerTime() - days * SECONDS_PER_DAY
	local total
	for _, point in ipairs(self:Points(key)) do
		if point.watched and point.time > since then
			total = total or { sold = 0, expired = 0, pulled = 0, watched = 0 }
			total.sold = total.sold + point.sold
			total.expired = total.expired + point.expired
			total.pulled = total.pulled + point.pulled
			total.watched = total.watched + point.watched
			if point.top then
				total.top = math.max(total.top or 0, point.top)
			end
		end
	end
	return total
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

-- Counts of sales kept under an earlier way of counting them are cleared,
-- once, when the way changes (ns.TurnoverRule.model): a count that was wrong
-- must not keep feeding what the Sell tab says. The points themselves stay.
-- Runs as a job; every point of every item is looked at.
function History:ClearOldTurnover()
	if ns.db.turnoverModel == ns.TurnoverRule.model then
		return
	end
	ns.Jobs:Run(function()
		local count, cleared = 0, 0
		for _, market in pairs(ns.db.historyByMarket or {}) do
			for _, record in pairs(market.items or {}) do
				if record.h and record.h ~= "" then
					local kept, changed = {}, false
					for chunk in record.h:gmatch("[^;]+") do
						local base = chunk:match("^(%d+:%d+:%d+:%d+:%d+):")
						kept[#kept + 1] = base or chunk
						changed = changed or base ~= nil
					end
					if changed then
						record.h = table.concat(kept, ";")
						cleared = cleared + 1
					end
				end
				count = count + 1
				if count % 200 == 0 then
					ns.Breathe()
				end
			end
		end
		return cleared
	end, function(cleared)
		ns.db.turnoverModel = ns.TurnoverRule.model
		if cleared > 0 then
			Bus:Fire("HISTORY_CHANGED")
		end
	end, function(message)
		ns.EventLog:Note("clearing old sales failed", message)
	end)
end

Bus:On("READY", function()
	History:ClearOldTurnover()
end)

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

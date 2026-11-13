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

-- How many daily points an item keeps: the player's choice, else the default.
function History:GraphDays()
	return ns.db.graphDays or ns.HistoryRule.graphPoints
end

-- Sets how many daily points to keep, within the allowed range. Records are
-- trimmed to a shorter length as scans next touch them, not all at once.
function History:SetGraphDays(days)
	local rule = ns.HistoryRule
	ns.db.graphDays = math.max(rule.graphPointsMin, math.min(rule.graphPointsMax, math.floor(days)))
	return ns.db.graphDays
end

-- Adds today's point to a record's graph string, replacing today's earlier
-- point if there is one, and dropping the oldest past the limit.
local function AddPoint(packed, day, median, low, units)
	local point = day .. ":" .. median .. ":" .. low .. ":" .. units
	if not packed or packed == "" then
		return point
	end
	local points = {}
	for existing in packed:gmatch("[^;]+") do
		points[#points + 1] = existing
	end
	local lastDay = tonumber(points[#points]:match("^(%d+)"))
	if lastDay == day then
		points[#points] = point
	else
		points[#points + 1] = point
	end
	local first = math.max(1, #points - History:GraphDays() + 1)
	return table.concat(points, ";", first)
end

local function Update(record, median, low, units, day)
	local rule = ns.HistoryRule
	if not record then
		return { u = median, m = median, lo = low, hi = median, n = 1, d = 1, f = day, l = day, h = AddPoint(nil, day, median, low, units) }
	end
	record.u = math.floor(record.u + (median - record.u) * rule.smoothing + 0.5)
	record.m = median
	record.lo = math.min(record.lo, low)
	record.hi = math.max(record.hi, median)
	record.n = record.n + 1
	if day ~= record.l then
		record.d = record.d + 1
		record.l = day
	end
	record.h = AddPoint(record.h, day, median, low, units)
	return record
end

-- An item's graph points, oldest first: { day, median, low, units }.
-- day is days since 1970, so day * 86400 is a time the game can format.
function History:Points(key)
	local record = self:Get(key)
	local points = {}
	if record and record.h then
		for day, median, low, units in record.h:gmatch("(%d+):(%d+):(%d+):(%d+)") do
			points[#points + 1] = { day = tonumber(day), median = tonumber(median), low = tonumber(low), units = tonumber(units) }
		end
	end
	return points
end

-- The points inside the last `days` days, counted back from the newest point.
function History:InRange(points, days)
	local newest = points[#points]
	local kept = {}
	if newest then
		for _, point in ipairs(points) do
			if point.day > newest.day - days then
				kept[#kept + 1] = point
			end
		end
	end
	return kept
end

-- The headline numbers for a run of points, or nil when there are none:
--   usual (the newest median), lowest, highest, days,
--   change: percent the usual price moved from the first point to the last
function History:Summarize(points)
	local first, last = points[1], points[#points]
	if not first then
		return nil
	end
	local lowest, highest = first.low, first.median
	for _, point in ipairs(points) do
		lowest = math.min(lowest, point.low)
		highest = math.max(highest, point.median)
	end
	local change
	if #points > 1 and first.median > 0 then
		change = math.floor((last.median - first.median) / first.median * 100 + 0.5)
	end
	return { usual = last.median, lowest = lowest, highest = highest, change = change, days = #points }
end

-- Folds one scan's market into the records. Runs inside a job.
-- A scan is only ever folded once, however often it is analyzed.
function History:Fold(market)
	if not market or not market.time or market.stale then return false end
	local store = Store(market.place)
	if store.folded[market.time] then
		return false
	end
	local day = math.floor(market.time / SECONDS_PER_DAY)
	local records = store.items

	for count, item in ipairs(market.items) do
		if item.median then
			records[item.key] = Update(records[item.key], item.median, item.min, item.units, day)
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

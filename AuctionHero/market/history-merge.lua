-- History merge: two price histories of one market as one. A market can end
-- up kept under two names (market\place.lua); this puts them back together
-- without losing a point of either.
--
-- Holds no game state and calls nothing of the game's, so it can be tested
-- on its own (tests/unit/history-merge.lua).
local _, ns = ...

local HistoryMerge = {}
ns.HistoryMerge = HistoryMerge

local SECONDS_PER_DAY = 86400

-- A point's time, as market\history.lua reads it: old points carry a day.
local function PointTime(stamp)
	stamp = tonumber(stamp)
	return stamp < 10000000 and stamp * SECONDS_PER_DAY + SECONDS_PER_DAY / 2 or stamp
end

-- Two graph strings as one, oldest point first. Of two points at one time,
-- the one saying more (with sales counted) is kept.
function HistoryMerge.Points(a, b)
	local byTime, times = {}, {}
	for _, packed in ipairs({ a or "", b or "" }) do
		for chunk in packed:gmatch("[^;]+") do
			local stamp = chunk:match("^(%d+):")
			if stamp then
				local time = PointTime(stamp)
				if not byTime[time] then
					times[#times + 1] = time
					byTime[time] = chunk
				elseif #chunk > #byTime[time] then
					byTime[time] = chunk
				end
			end
		end
	end
	table.sort(times)
	local kept = {}
	for index, time in ipairs(times) do
		kept[index] = byTime[time]
	end
	return table.concat(kept, ";")
end

-- Two records of one item as one. The one seen last says what it goes for
-- now; the lowest, the highest and the counts are of both.
function HistoryMerge.Record(a, b)
	if not a or not b then
		return a or b
	end
	local newer, older = a, b
	if (b.l or 0) > (a.l or 0) then
		newer, older = b, a
	end
	local merged = {}
	for key, value in pairs(newer) do
		merged[key] = value
	end
	if (older.lo or math.huge) < (newer.lo or math.huge) then
		merged.lo, merged.lou, merged.lot = older.lo, older.lou, older.lot
	end
	merged.hi = math.max(newer.hi or 0, older.hi or 0)
	merged.n = (newer.n or 0) + (older.n or 0)
	-- A day both saw is one day.
	merged.d = (newer.d or 0) + (older.d or 0) - ((older.l ~= nil and older.l == newer.f) and 1 or 0)
	merged.f = math.min(newer.f or older.f, older.f or newer.f)
	merged.l = math.max(newer.l or 0, older.l or 0)
	merged.h = HistoryMerge.Points(a.h, b.h)
	return merged
end

-- Folds one market's history into another: { items, folded, scans }. A scan
-- both remember counts once. breathe, when given, is called now and then.
function HistoryMerge.Markets(into, from, breathe)
	into.items, into.folded = into.items or {}, into.folded or {}
	local count = 0
	for key, record in pairs(from.items or {}) do
		into.items[key] = HistoryMerge.Record(into.items[key], record)
		count = count + 1
		if breathe and count % 200 == 0 then
			breathe()
		end
	end
	local scans = into.scans or 0
	for time in pairs(from.folded or {}) do
		if not into.folded[time] then
			into.folded[time] = true
			scans = scans + 1
		end
	end
	into.scans = scans
	return into
end

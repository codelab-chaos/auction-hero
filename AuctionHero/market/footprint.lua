-- Footprint: how much data the addon is holding, for the options panel and
-- the Progress tab.
-- It only measures. Nothing here changes what is kept.
local _, ns = ...

local Footprint = {}
ns.Footprint = Footprint

local BYTES_PER_MB = 1024 * 1024

-- The addon's memory as the game counts it, in bytes, or nil when the client
-- cannot say.
local function Memory()
	local update = UpdateAddOnMemoryUsage
	local usage = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
	if not usage then
		return nil
	end
	if update then
		pcall(update)
	end
	local ok, kilobytes = pcall(usage, "AuctionHero")
	return ok and kilobytes and kilobytes * 1024 or nil
end

-- What is counted, once a count is in:
-- megabytes   the addon's memory, nil when the client cannot say
-- auctions    auctions in the saved scan, variants the item variants in it,
--             scanAge seconds since it was made (nil without one)
-- items       items with a price history, points the graph points across
--             all of them, days how far back the points reach, scans how
--             many scans the history holds, markets how many realms and
--             factions it holds
-- watched     items the scan journal has counted sales for, sold the likely
--             units sold across them in the last ns.SellChanceRule.days
-- journal     the scan journal's ns.ScanJournal:Stats(), nil when it is off
-- ledger      sales and purchases recorded for this character
-- logged      entries in the event log
--
-- Counting walks every price history record, which takes long enough to be
-- felt, so it runs as a job and only after something it counts changed.
-- FOOTPRINT_READY says a new count is in.
local counted -- the last count
local stale = true
local counting = false

local function Count()
	local items, points, watched, sold, scans, markets = 0, 0, 0, 0, 0, 0
	local since = GetServerTime() - ns.SellChanceRule.days * 86400
	for _, market in pairs(ns.db.historyByMarket or {}) do
		markets = markets + 1
		scans = scans + (market.scans or 0)
		for _, record in pairs(market.items or {}) do
			items = items + 1
			local packed = record.h
			if packed and packed ~= "" then
				local seen = false
				-- One pass over the points, each read from its start: patterns
				-- that are not anchored crawl on strings this long.
				for chunk in packed:gmatch("[^;]+") do
					points = points + 1
					local stamp, units = chunk:match("^(%d+):%d+:%d+:%d+:%d+:([%d%.]+):")
					if stamp then
						seen = true
						if tonumber(stamp) > since then
							sold = sold + tonumber(units)
						end
					end
				end
				if seen then
					watched = watched + 1
				end
			end
			if items % 200 == 0 then
				ns.Breathe()
			end
		end
	end
	local snapshot = ns.Store:GetSourceSnapshot("replicate") or ns.Store:GetSnapshot()
	local memory = Memory()
	return {
		megabytes = memory and memory / BYTES_PER_MB,
		auctions = snapshot and snapshot.rows and ns.AuctionCount(snapshot) or 0,
		variants = snapshot and snapshot.variants and #snapshot.variants or 0,
		scanAge = snapshot and snapshot.meta.time and math.max(0, GetServerTime() - snapshot.meta.time) or nil,
		time = GetServerTime(),
		items = items,
		points = points,
		days = ns.History:GraphDays(),
		scans = scans,
		markets = markets,
		watched = watched,
		sold = sold,
		journal = ns.ScanJournal:IsOn() and ns.ScanJournal:Stats() or nil,
		ledger = #(ns.charDb.ledger or {}),
		logged = #(ns.db.log or {}),
	}
end

-- The last count, or nil before the first is in. Asking starts a new count
-- when something has changed since; FOOTPRINT_READY follows it.
function Footprint:Read()
	if stale and not counting then
		counting, stale = true, false
		ns.Jobs:Run(Count, function(result)
			counting, counted = false, result
			ns.Bus:Fire("FOOTPRINT_READY")
		end, function(message)
			counting = false
			ns.EventLog:Note("footprint failed", message)
		end)
	end
	if counted and counted.scanAge then
		-- The scan ages while the count stands still.
		counted.scanAge = counted.scanAge + (GetServerTime() - counted.time)
		counted.time = GetServerTime()
	end
	return counted
end

-- Whether a count is under way.
function Footprint:IsCounting()
	return counting
end

for _, event in ipairs({ "HISTORY_CHANGED", "ANALYSIS_READY", "LEDGER_CHANGED", "SETTING_CHANGED", "SNAPSHOT_PATCHED", "SNAPSHOT_CHANGED" }) do
	ns.Bus:On(event, function()
		stale = true
	end)
end

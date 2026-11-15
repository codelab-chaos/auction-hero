-- Footprint: how much data the addon is holding, for the options panel.
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

-- megabytes   the addon's memory, nil when the client cannot say
-- auctions    rows in the saved scan
-- items       items with a price history
-- points      graph points across all of them
-- days        how far back the points reach
function Footprint:Read()
	local items, points = 0, 0
	local store = ns.db.historyByMarket or {}
	for _, market in pairs(store) do
		for _, record in pairs(market.items or {}) do
			items = items + 1
			if record.h and record.h ~= "" then
				points = points + 1 + select(2, record.h:gsub(";", ";"))
			end
		end
	end
	local snapshot = ns.Store:GetSnapshot()
	local memory = Memory()
	return {
		megabytes = memory and memory / BYTES_PER_MB,
		auctions = snapshot and snapshot.rows and ns.AuctionCount(snapshot) or 0,
		items = items,
		points = points,
		days = ns.History:GraphDays(),
	}
end

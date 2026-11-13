-- Browse fetcher: pages through an empty browse search, which lists every item
-- with its lowest price and total quantity. Runs inside a job (see jobs.lua).
-- Returns rows and an info table, or nil and a failure reason key.
local _, ns = ...
local Jobs = ns.Jobs

local counts = { updated = 0, added = 0, failed = 0 }
local EVENTS = {
	AUCTION_HOUSE_BROWSE_RESULTS_UPDATED = "updated",
	AUCTION_HOUSE_BROWSE_RESULTS_ADDED = "added",
	AUCTION_HOUSE_BROWSE_FAILURE = "failed",
}

local watcher = CreateFrame("Frame")
for event in pairs(EVENTS) do
	watcher:RegisterEvent(event)
end
watcher:SetScript("OnEvent", function(_, event)
	local counter = EVENTS[event]
	counts[counter] = counts[counter] + 1
end)

-- Waits until check() is true. Returns nil and a reason key when it gives up.
local function WaitFor(ctx, seconds, check)
	local deadline = GetTime() + seconds
	while not check() do
		if ctx.cancelled then
			return nil, ctx.reason
		end
		if GetTime() > deadline then
			return nil, "FAIL_TIMEOUT"
		end
		Jobs.Sleep(0.1)
	end
	return true
end

local function WaitForThrottle(ctx, seconds)
	return WaitFor(ctx, seconds, function()
		return C_AuctionHouse.IsThrottledMessageSystemReady()
	end)
end

-- Adds what GetItemKeyInfo knows. Returns false while the item is still loading.
local function Resolve(row, itemKey, at)
	local keyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey)
	if not keyInfo then
		return false
	end
	row[at.name] = keyInfo.itemName
	row[at.quality] = keyInfo.quality
	row[at.iconFileID] = keyInfo.iconFileID
	row[at.isCommodity] = keyInfo.isCommodity
	row[at.isEquipment] = keyInfo.isEquipment
	row[at.isPet] = keyInfo.isPet
	row[at.requiredLevel] = C_AuctionHouse.GetItemKeyRequiredLevel(itemKey)
	return true
end

ns.Fetchers.browse = function(source, ctx)
	local schema = ns.Schemas[source.schema]
	local at = schema.index
	local info = { incomplete = 0 }

	local ok, reason = WaitForThrottle(ctx, source.timeoutSeconds)
	if not ok then
		return nil, reason
	end

	local updated, failed = counts.updated, counts.failed
	C_AuctionHouse.SendBrowseQuery({
		searchString = "",
		sorts = {
			{ sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false },
			{ sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
		},
		filters = {},
	})
	ctx:Progress("waiting")
	ok, reason = WaitFor(ctx, source.timeoutSeconds, function()
		return counts.updated ~= updated or counts.failed ~= failed
	end)
	if not ok then
		return nil, reason
	end
	if counts.failed ~= failed then
		return nil, "FAIL_BROWSE"
	end

	-- Keep asking for the next page until the server says that was the last one.
	while not C_AuctionHouse.HasFullBrowseResults() do
		ok, reason = WaitForThrottle(ctx, source.timeoutSeconds)
		if not ok then
			return nil, reason
		end
		local added = counts.added
		failed = counts.failed
		C_AuctionHouse.RequestMoreBrowseResults()
		ok, reason = WaitFor(ctx, source.timeoutSeconds, function()
			return counts.added ~= added or counts.failed ~= failed or C_AuctionHouse.HasFullBrowseResults()
		end)
		if not ok then
			return nil, reason
		end
		if counts.failed ~= failed then
			return nil, "FAIL_BROWSE"
		end
		ctx:Progress("reading", #C_AuctionHouse.GetBrowseResults())
	end

	local results = C_AuctionHouse.GetBrowseResults()
	if #results == 0 then
		return nil, "FAIL_EMPTY"
	end

	local rows, pending = {}, {}
	for position, result in ipairs(results) do
		local itemKey = result.itemKey
		local row = {}
		row[at.itemID] = itemKey.itemID
		row[at.itemLevel] = itemKey.itemLevel
		row[at.itemSuffix] = itemKey.itemSuffix
		row[at.battlePetSpeciesID] = itemKey.battlePetSpeciesID
		row[at.totalQuantity] = result.totalQuantity
		row[at.minPrice] = result.minPrice
		row[at.containsOwnerItem] = result.containsOwnerItem
		row[at.appearanceLink] = result.appearanceLink
		rows[position] = row
		if not Resolve(row, itemKey, at) then
			pending[#pending + 1] = position
		end
		if position % 100 == 0 then
			ns.Breathe()
		end
	end

	-- Asking for key info starts the item load. Try the unfinished ones again.
	for pass = 1, source.retryPasses do
		if #pending == 0 then
			break
		end
		ctx:Progress("resolving", #pending, #rows, pass)
		Jobs.Sleep(source.retrySeconds)
		if ctx.cancelled then
			return nil, ctx.reason
		end
		local still = {}
		for count, position in ipairs(pending) do
			if not Resolve(rows[position], results[position].itemKey, at) then
				still[#still + 1] = position
			end
			if count % 100 == 0 then
				ns.Breathe()
			end
		end
		pending = still
	end
	info.incomplete = #pending

	return rows, info
end

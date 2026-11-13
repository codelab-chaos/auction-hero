-- Replicate fetcher: downloads every auction with C_AuctionHouse.ReplicateItems.
-- Runs inside a job (see jobs.lua), so it can wait and spread work over frames.
-- Returns rows and an info table, or nil and a failure reason key.
local _, ns = ...
local Jobs = ns.Jobs

local updates = 0 -- REPLICATE_ITEM_LIST_UPDATE events seen so far
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
watcher:SetScript("OnEvent", function()
	updates = updates + 1
end)

-- Packs every return value and says how many there were, nils included.
local function Pack(...)
	return { ... }, select("#", ...)
end

local function ReadRow(index, schema)
	local row, returned = Pack(C_AuctionHouse.GetReplicateItemInfo(index))
	row[schema.index.link] = C_AuctionHouse.GetReplicateItemLink(index)
	row[schema.index.timeLeft] = C_AuctionHouse.GetReplicateItemTimeLeft(index)
	return row, returned
end

local function IsComplete(row, schema)
	return row[schema.index.hasAllInfo] == true and row[schema.index.link] ~= nil
end

-- Whether an item is a commodity (bought by the unit) or is sold one auction
-- at a time. Nil while the client has not loaded the item yet.
local function CommodityOf(itemID)
	local keyInfo = C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(itemID))
	if keyInfo then
		return keyInfo.isCommodity
	end
end

-- What the client knows about each item id without asking the server: its
-- type, subtype and equip slot. Kept once per item id, not once per row.
local function CatalogItems(rows, schema)
	local itemIdAt = schema.index.itemID
	local items = {}
	for count, row in ipairs(rows) do
		local itemID = row[itemIdAt]
		if itemID and not items[itemID] then
			local _, itemType, itemSubType, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
			-- Commodities are bought by the unit, other items one auction at a time.
			-- Nil when the client has not loaded the item yet.
			items[itemID] = {
				commodity = CommodityOf(itemID),
				type = itemType,
				subType = itemSubType,
				equipLoc = equipLoc,
				classID = classID,
				subClassID = subClassID,
			}
		end
		if count % 500 == 0 then
			ns.Breathe()
		end
	end
	return items
end

-- Asking whether an item is a commodity starts a lookup that answers a moment
-- later, so most come back empty the first time. Ask again a few times.
local function ResolveCommodities(items, source, ctx)
	for _ = 1, source.commodityPasses do
		local unknown = 0
		for _, info in pairs(items) do
			if info.commodity == nil then
				unknown = unknown + 1
			end
		end
		if unknown == 0 or ctx.cancelled then
			return
		end
		ctx:Progress("resolving", unknown, unknown, 0)
		Jobs.Sleep(source.retrySeconds)
		local count = 0
		for itemID, info in pairs(items) do
			if info.commodity == nil then
				info.commodity = CommodityOf(itemID)
				count = count + 1
				if count % 200 == 0 then
					ns.Breathe()
				end
			end
		end
	end
end

ns.Fetchers.replicate = function(source, ctx)
	local schema = ns.Schemas[source.schema]
	local info = { returns = 0, incomplete = 0 }

	-- Ask, then wait for the server to say the list is ready.
	local seen = updates
	C_AuctionHouse.ReplicateItems()
	ctx:Progress("waiting")
	local deadline = GetTime() + source.timeoutSeconds
	while updates == seen do
		if ctx.cancelled then
			return nil, ctx.reason
		end
		if GetTime() > deadline then
			-- No answer. If an earlier list is still in memory, read that instead.
			if C_AuctionHouse.GetNumReplicateItems() == 0 then
				return nil, "FAIL_TIMEOUT"
			end
			info.stale = true
			break
		end
		Jobs.Sleep(0.2)
	end

	local total = C_AuctionHouse.GetNumReplicateItems()
	if total == 0 then
		return nil, "FAIL_EMPTY"
	end

	-- The replicate list is numbered from 0.
	local rows = {}
	for index = 0, total - 1 do
		local row, returned = ReadRow(index, schema)
		rows[index + 1] = row
		if returned > info.returns then
			info.returns = returned
		end
		if index % 200 == 0 then
			if ctx.cancelled then
				return nil, ctx.reason
			end
			ctx:Progress("reading", index, total)
			ns.Breathe()
		end
	end

	-- Row details keep arriving after the list is ready: the server sends many
	-- more REPLICATE_ITEM_LIST_UPDATE events, and reading a row also asks the
	-- client to load its item. Re-read the unfinished rows until they are all in,
	-- or the server has gone quiet, or we have waited long enough.
	local pending = {}
	for position = 1, total do
		if not IsComplete(rows[position], schema) then
			pending[#pending + 1] = position
		end
	end
	local giveUpAt = GetTime() + source.resolveSeconds
	local quietSince = GetTime()
	local pass = 0
	while #pending > 0 do
		if GetTime() - quietSince > source.settleSeconds or GetTime() > giveUpAt then
			-- Late list updates are the server still talking, but they stop
			-- counting once the rows have stopped filling in.
			break
		end
		pass = pass + 1
		ctx:Progress("resolving", #pending, total, pass)
		Jobs.Sleep(source.retrySeconds)
		if ctx.cancelled then
			return nil, ctx.reason
		end
		local still = {}
		for count, position in ipairs(pending) do
			local row = ReadRow(position - 1, schema)
			rows[position] = row
			if not IsComplete(row, schema) then
				still[#still + 1] = position
			end
			if count % 200 == 0 then
				ns.Breathe()
			end
		end
		-- A handful of rows resolving per pass is a trickle, not progress. Only a
		-- real drop keeps us waiting.
		if #pending - #still >= math.max(source.resolveMinRows, #pending * source.resolveMinShare) then
			quietSince = GetTime()
		end
		pending = still
	end

	local incomplete = 0
	for position = 1, total do
		if not IsComplete(rows[position], schema) then
			incomplete = incomplete + 1
		end
	end
	info.incomplete = incomplete
	info.items = CatalogItems(rows, schema)
	ResolveCommodities(info.items, source, ctx)

	return rows, info
end

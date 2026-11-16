-- Replicate fetcher: downloads every auction with C_AuctionHouse.ReplicateItems.
-- Runs inside a job (see jobs.lua), so it can wait and spread work over frames.
-- The game answers with one row per auction (the source's wire schema). Once
-- they are all read, they are folded into the shape a scan is kept in (the
-- source's schema): one entry per distinct item, one row per distinct listing.
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

-- Folds one row per auction into the kept shape. Which wire field goes where
-- is read off the kept schema, so the two schemas are all that has to agree.
-- Returns the rows and the variants they point into.
local function Fold(wireRows, wire, kept)
	local variantFields, rowFields = {}, {}
	for position, field in ipairs(kept.fields) do
		local from = wire.index[field.id]
		if field.variant and from then
			variantFields[field.variant] = from
		elseif from and not field.virtual then
			rowFields[#rowFields + 1] = { from = from, to = position }
		end
	end
	local variantAt, copiesAt = kept.index.variant, kept.index.copies
	local variants, variantByKey = {}, {}
	local rows, rowByKey = {}, {}
	local parts = {}

	for count, wireRow in ipairs(wireRows) do
		for place = 1, kept.variants do
			parts[place] = tostring(wireRow[variantFields[place]])
		end
		local variantKey = table.concat(parts, "\031", 1, kept.variants)
		local variant = variantByKey[variantKey]
		if not variant then
			local entry = {}
			for place = 1, kept.variants do
				entry[place] = wireRow[variantFields[place]]
			end
			variant = #variants + 1
			variants[variant] = entry
			variantByKey[variantKey] = variant
		end

		parts[1] = variant
		for place, field in ipairs(rowFields) do
			parts[place + 1] = tostring(wireRow[field.from])
		end
		local rowKey = table.concat(parts, "\031", 1, #rowFields + 1)
		local row = rowByKey[rowKey]
		if row then
			row[copiesAt] = row[copiesAt] + 1
		else
			row = {}
			for _, field in ipairs(rowFields) do
				row[field.to] = wireRow[field.from]
			end
			row[variantAt], row[copiesAt] = variant, 1
			rows[#rows + 1] = row
			rowByKey[rowKey] = row
		end
		if count % 500 == 0 then
			ns.Breathe()
		end
	end
	return rows, variants
end

ns.Fetchers.replicate = function(source, ctx)
	local schema = ns.Schemas[source.wire]
	local info = { returns = 0, incomplete = 0 }
	-- Save the actual client boundaries for offline expiry estimates. Raw
	-- replicate bands are 1..4; the modern API takes the named enum values.
	local bands = Enum.AuctionHouseTimeLeftBand
	if bands and C_AuctionHouse.GetTimeLeftBandInfo then
		info.timeLeftBands = {}
		for raw, name in ipairs({ "Short", "Medium", "Long", "VeryLong" }) do
			local ok, low, high = pcall(C_AuctionHouse.GetTimeLeftBandInfo, bands[name])
			if ok and type(low) == "number" and type(high) == "number" and low >= 0 and high >= low then
				info.timeLeftBands[tostring(raw)] = { min = low, max = high }
			end
		end
	end

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

	-- Rows still without details keep their item id. Name the ones whose item
	-- has only one name, so they are not lost from the market.
	local incomplete = 0
	local nameAt, itemIdAt = schema.index.name, schema.index.itemID
	for position = 1, total do
		local row = rows[position]
		if not IsComplete(row, schema) then
			incomplete = incomplete + 1
			if row[nameAt] == nil or row[nameAt] == "" then
				row[nameAt] = ns.ItemNames.Fallback(row[itemIdAt])
			end
		end
		if position % 500 == 0 then
			ns.Breathe()
		end
	end
	info.incomplete = incomplete
	info.items = CatalogItems(rows, schema)
	ResolveCommodities(info.items, source, ctx)

	info.count = total -- auctions, which is more than the rows they fold into
	local kept
	kept, info.variants = Fold(rows, schema, ns.Schemas[source.schema])
	return kept, info
end

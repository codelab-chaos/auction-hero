-- Live check: brings one item's listings up to date.
--
-- A scan ages. When an item is chosen to buy and the scan is no longer fresh
-- (ns.LiveCheckRule), this asks the auction house for that one item as it is
-- now and patches the answer in: into the market the tabs read, and into the
-- saved scan, which notes that the item was patched and when.
--
-- It only reads. Nothing is bought here.
--
-- The state, published as LIVE_CHECK_CHANGED:
--   phase    "idle", "waiting" (about to ask), "sent" or "done"
--   itemID   the item asked about
-- MARKET_PATCHED (itemID) follows a check that changed the market.
local _, ns = ...
local Bus = ns.Bus

local LiveCheck = { state = { phase = "idle" } }
ns.LiveCheck = LiveCheck

local SOURCE = "replicate" -- the scan that is patched

local wanted -- { itemID, itemKey, commodity, name, request } for the check in hand
local turn = 0 -- a newer check overtakes an older one still settling

local function Publish(phase)
	LiveCheck.state = { phase = phase, itemID = wanted and wanted.itemID }
	Bus:Fire("LIVE_CHECK_CHANGED", LiveCheck.state)
end

local function Finish()
	wanted = nil
	Publish("idle")
end

-- Whether an item's listings are old enough to be worth asking about.
function LiveCheck:IsStale(item)
	local snapshot = ns.Store:GetSourceSnapshot(SOURCE)
	local seen = item.checkedAt or (snapshot and snapshot.meta.time) or 0
	return GetServerTime() - seen >= ns.LiveCheckRule.staleMinutes * 60
end

-- Whether a check is recent enough to buy from without asking again.
function LiveCheck:FreshForBuying(item)
	return item.checkedAt ~= nil and GetServerTime() - item.checkedAt <= ns.LiveCheckRule.reuseSeconds
end

-- The game's time left bands run 0 to 3 in a search and 1 to 4 in a scan.
local function Band(info)
	return (info.timeLeft or 3) + 1
end

-- A scan row for one live auction: a copy of a row the scan already has for
-- the item (for its icon, quality and level), with the live details set.
local function Row(snapshot, template, details)
	return ns.MakeRow(snapshot, template, details)
end

-- The scan's rows for this item, by name, to copy from. A row whose details
-- never arrived has no name; copying it would make every live row nameless,
-- and the market leaves nameless rows out, so the item would vanish. A named
-- row is preferred, the one wanted first.
local function Templates(snapshot)
	local get = ns.RowReader(snapshot)
	local byName, named, nameless = {}, nil, nil
	for _, row in ipairs(snapshot.rows) do
		if get(row, "itemID") == wanted.itemID then
			local name = get(row, "name")
			if name and name ~= "" then
				byName[name] = byName[name] or row
				named = named or row
			else
				nameless = nameless or row
			end
		end
	end
	return byName, byName[wanted.name] or named or nameless
end

-- The live auctions as scan rows, or nil when they could not be read. For
-- single items it also returns the auctions themselves by item name, each
-- { auctionID, buyout, quantity, mine }, for the Buy button to use.
local function ReadRows(snapshot)
	local byName, any = Templates(snapshot)
	if not any then
		return nil
	end
	local rows, auctions = {}, {}
	if wanted.commodity then
		local ok, count = pcall(C_AuctionHouse.GetNumCommoditySearchResults, wanted.itemID)
		for index = 1, ok and count or 0 do
			local found, info = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, wanted.itemID, index)
			if found and info and info.unitPrice and (info.quantity or 0) > 0 then
				-- Goods have one name per id: the one the player chose.
				rows[#rows + 1] = Row(snapshot, any, { name = wanted.name, count = info.quantity, buyoutPrice = info.unitPrice * info.quantity, minBid = 0, bidAmount = 0, timeLeft = 4 })
			end
		end
		return rows
	end
	local ok, count = pcall(C_AuctionHouse.GetNumItemSearchResults, wanted.itemKey)
	for index = 1, ok and count or 0 do
		local found, info = pcall(C_AuctionHouse.GetItemSearchResultInfo, wanted.itemKey, index)
		local name = found and info and info.itemLink and info.itemLink:match("|h%[(.-)%]|h")
		if name and name ~= wanted.name then
			-- Another variant of the item. The search was for this one only.
		elseif name then
			local units = ns.AuctionUnits(wanted.itemID, info.quantity)
			auctions[name] = auctions[name] or {}
			table.insert(auctions[name], {
				auctionID = info.auctionID,
				buyout = info.buyoutAmount or 0,
				quantity = units,
				mine = info.containsOwnerItem == true,
			})
			rows[#rows + 1] = Row(snapshot, byName[name] or any, {
				name = name,
				link = info.itemLink,
				count = units,
				buyoutPrice = info.buyoutAmount or 0,
				minBid = info.minBid or 0,
				bidAmount = info.bidAmount or 0,
				timeLeft = Band(info),
			})
		elseif found and info then
			-- An auction that cannot be named cannot be placed among the variants.
			return nil, nil, "an auction came back without a name"
		end
	end
	return rows, auctions
end

-- Puts what the auction house has now for an item into the market the tabs
-- read and into the saved scan. No rows takes the item off the list until a
-- scan sees it again.
local function Patch(snapshot, market, itemID, name, rows, auctions)
	local time = GetServerTime()
	ns.Store:PatchItem(SOURCE, itemID, rows, time, name)
	for _, item in ipairs(ns.Market:Patch(market, snapshot, itemID, rows, time, name)) do
		item.liveAuctions = auctions and auctions[item.name]
		ns.Signals:Rate(item)
		local cheapest = ns.Market.PricePoints(item)[1]
		if cheapest then
			ns.History:SawLow(item.key, cheapest.unit, cheapest.units, time)
		end
	end
	Bus:Fire("MARKET_PATCHED", itemID)
end

-- The auction house has none of an item by its name (a purchase looked and
-- found nothing listed at all): it comes off the list. Nothing is asked.
function LiveCheck:Gone(item)
	local snapshot = ns.Store:GetSourceSnapshot(SOURCE)
	local market = ns.Analysis and ns.Analysis.market
	if not (item and snapshot and market and ns.Schemas[snapshot.meta.schema]) then
		return
	end
	ns.EventLog:Note("live check gone", item.itemID, item.name)
	Patch(snapshot, market, item.itemID, item.name, {}, {})
end

-- Reads the answer once it is quiet. A long list comes a page at a time, and
-- patching in part of it would wipe out what is on the pages not yet read,
-- so the rest is asked for first.
local function Read(request, last)
	if not wanted.commodity and not last then
		local full = select(2, pcall(C_AuctionHouse.HasFullItemSearchResults, wanted.itemKey))
		if full == false then
			wanted.pages = (wanted.pages or 1) + 1
			if wanted.pages <= ns.LiveCheckRule.maxPages then
				return request:More(function()
					return C_AuctionHouse.RequestMoreItemSearchResults(wanted.itemKey)
				end)
			end
			LiveCheck.problem = { itemID = wanted.itemID, text = ns.L.STAT_CHECK_TOO_LONG }
			ns.EventLog:Note("live check gave up", wanted.itemID, "more than", ns.LiveCheckRule.maxPages, "pages")
			return { tooLong = true }
		end
	end
	return { read = true }
end

local function Answered(gone)
	local snapshot = ns.Store:GetSourceSnapshot(SOURCE)
	local market = ns.Analysis and ns.Analysis.market
	local schema = snapshot and ns.Schemas[snapshot.meta.schema]
	if not (snapshot and market and schema) then
		return Finish()
	end
	local rows, auctions, problem
	if gone then
		rows, auctions = {}, {}
	else
		rows, auctions, problem = ReadRows(snapshot)
	end
	local itemID = wanted.itemID
	LiveCheck.problem = not rows and { itemID = itemID, text = ns.L.STAT_CHECK_UNREAD:format(problem or "") } or nil
	ns.EventLog:Note("live check answered", itemID, rows and #rows or "could not be read, so the scan stands")
	if not wanted.commodity and not gone then
		-- What the game handed back, for the log.
		local counted, count = pcall(C_AuctionHouse.GetNumItemSearchResults, wanted.itemKey)
		local _, whole = pcall(C_AuctionHouse.HasFullItemSearchResults, wanted.itemKey)
		local _, first = pcall(C_AuctionHouse.GetItemSearchResultInfo, wanted.itemKey, 1)
		first = type(first) == "table" and first or {}
		ns.EventLog:Note("live check saw", itemID, counted and count, whole, "first", first.auctionID, first.itemLink, first.buyoutAmount, first.quantity, first.itemKey)
	end
	if not rows then
		return Finish()
	end

	-- Goods are one item per id. A single item is patched by name: the search
	-- was for one variant, and the others are left as the scan saw them.
	Patch(snapshot, market, itemID, not wanted.commodity and wanted.name or nil, rows, auctions)
	Publish("done")
	wanted = nil
end

-- Queues the search for the item. It goes when the auction house is free:
-- never across a purchase or another search (see trade\requests.lua).
local function Send()
	if not wanted or not ns.auctionHouseOpen then
		return Finish()
	end
	local mine = wanted
	local sorts = mine.commodity and {}
		or {
			{ sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
			{ sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false },
		}
	mine.request = ns.Requests:Ask({
		kind = mine.commodity and "commoditySearch" or "itemSearch",
		label = "live check",
		itemID = mine.itemID,
		itemKey = mine.itemKey,
		send = function()
			return C_AuctionHouse.SendSearchQuery(mine.itemKey, sorts, false)
		end,
		onSend = function()
			if wanted == mine then
				Publish("sent")
			end
		end,
		read = function(request, last)
			return Read(request, last)
		end,
		done = function(outcome, result)
			if wanted ~= mine then
				return
			end
			if outcome ~= "answered" or not result or result.tooLong then
				if outcome ~= "answered" then
					ns.EventLog:Note("live check " .. outcome, mine.itemID)
				end
				return Finish()
			end
			Answered(false)
		end,
	})
end

-- Asks about an item of the market, if what is known about it is stale, or
-- whatever its age when forced (after buying some of it, say). Asking again
-- for another item drops the first. Returns true when a check is on its way.
function LiveCheck:Request(item, force)
	if not item or not ns.auctionHouseOpen or not (force or self:IsStale(item)) then
		return false
	end
	if wanted and wanted.itemID == item.itemID and wanted.name == item.name and self.state.phase ~= "idle" then
		return true
	end
	-- A newer item overtakes the one before: its search, if not yet sent, goes.
	if wanted then
		ns.Requests:Cancel(wanted.request)
	end
	local commodity = ns.Orders.IsCommodity(item)
	wanted = { itemID = item.itemID, name = item.name, commodity = commodity }
	Publish("waiting")
	turn = turn + 1
	local mine = turn

	-- Asks once the item's key is known and the player has settled on the row.
	local function Ready(itemKey)
		if mine ~= turn or not wanted then
			return
		end
		wanted.itemKey = itemKey
		Send()
	end

	C_Timer.After(ns.LiveCheckRule.settleSeconds, function()
		if mine ~= turn or not wanted then
			return
		end
		if commodity then
			-- Goods are known by their id alone.
			local made, itemKey = pcall(C_AuctionHouse.MakeItemKey, item.itemID)
			if not made or not itemKey then
				ns.EventLog:Note("live check dropped", item.itemID, "no item key", tostring(itemKey))
				return Finish()
			end
			return Ready(itemKey)
		end
		-- A single item is known by a fuller key, which has to be asked for.
		ns.ItemKey:Resolve(item.itemID, item.name, function(itemKey, problem, found)
			if mine ~= turn or not wanted then
				return
			end
			if itemKey then
				return Ready(itemKey)
			end
			-- Nothing at all listed by its name: it is gone, and comes off the
			-- list until a scan sees it again.
			if problem == "none" then
				return Answered(true)
			end
			-- Results that do not include it are not proof that it is gone: the
			-- lookup may be at fault. Nothing is removed on that alone. The
			-- scan's rows stand, and the panel says what the lookup found instead.
			local text = problem == "gone" and ns.L.STAT_CHECK_NOT_FOUND:format(found or "") or ns.L.STAT_CHECK_UNREAD:format(problem or "")
			LiveCheck.problem = { itemID = item.itemID, text = text }
			Finish()
		end)
	end)
	return true
end

Bus:On("AH_CLOSED", function()
	if wanted then
		Finish()
	end
end)

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
local ANSWER_SECONDS = 10

local wanted -- { itemID, itemKey, commodity, equipment } for the check in hand
local attempt = 0 -- counts requests, so a late timer cannot touch a newer one

local function Publish(phase)
	LiveCheck.state = { phase = phase, itemID = wanted and wanted.itemID }
	Bus:Fire("LIVE_CHECK_CHANGED", LiveCheck.state)
end

local function Finish()
	attempt = attempt + 1
	wanted = nil
	Publish("idle")
end

-- Whether an item's listings are old enough to be worth asking about.
function LiveCheck:IsStale(item)
	local snapshot = ns.Store:GetSourceSnapshot(SOURCE)
	local seen = item.checkedAt or (snapshot and snapshot.meta.time) or 0
	return GetServerTime() - seen >= ns.LiveCheckRule.staleMinutes * 60
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

-- The scan's rows for this item, by name, to copy from.
local function Templates(snapshot)
	local get = ns.RowReader(snapshot)
	local byName, any = {}, nil
	for _, row in ipairs(snapshot.rows) do
		if get(row, "itemID") == wanted.itemID then
			any = any or row
			local name = get(row, "name")
			if name and name ~= "" then
				byName[name] = byName[name] or row
			end
		end
	end
	return byName, any
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
				rows[#rows + 1] = Row(snapshot, any, { count = info.quantity, buyoutPrice = info.unitPrice * info.quantity, minBid = 0, bidAmount = 0, timeLeft = 4 })
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
			auctions[name] = auctions[name] or {}
			table.insert(auctions[name], {
				auctionID = info.auctionID,
				buyout = info.buyoutAmount or 0,
				quantity = math.max(1, info.quantity or 1),
				mine = info.containsOwnerItem == true,
			})
			rows[#rows + 1] = Row(snapshot, byName[name] or any, {
				name = name,
				link = info.itemLink,
				count = math.max(1, info.quantity or 1),
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

local function Answered()
	local snapshot = ns.Store:GetSourceSnapshot(SOURCE)
	local market = ns.Analysis and ns.Analysis.market
	local schema = snapshot and ns.Schemas[snapshot.meta.schema]
	if not (snapshot and market and schema) then
		return Finish()
	end
	local gone = wanted.itemKey == false -- the auction house lists none of it
	-- A long list comes a page at a time. Patching in part of it would wipe
	-- out what is on the pages not yet read, so ask for the rest first.
	if not wanted.commodity and not gone then
		local full = select(2, pcall(C_AuctionHouse.HasFullItemSearchResults, wanted.itemKey))
		if full == false then
			wanted.pages = (wanted.pages or 1) + 1
			if wanted.pages <= ns.LiveCheckRule.maxPages and pcall(C_AuctionHouse.RequestMoreItemSearchResults, wanted.itemKey) then
				return -- the next page arrives as another answer
			end
			LiveCheck.problem = { itemID = wanted.itemID, text = ns.L.STAT_CHECK_TOO_LONG }
			ns.EventLog:Note("live check gave up", wanted.itemID, "more than", ns.LiveCheckRule.maxPages, "pages")
			return Finish()
		end
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

	local time = GetServerTime()
	-- Goods are one item per id. A single item is patched by name: the search
	-- was for one variant, and the others are left as the scan saw them.
	local name = not wanted.commodity and wanted.name or nil
	ns.Store:PatchItem(SOURCE, itemID, rows, time, name)
	for _, item in ipairs(ns.Market:Patch(market, snapshot, itemID, rows, time, name)) do
		item.liveAuctions = auctions and auctions[item.name]
		ns.Signals:Rate(item)
		local cheapest = ns.Market.PricePoints(item)[1]
		if cheapest then
			ns.History:SawLow(item.key, cheapest.unit, cheapest.units, time)
		end
	end
	Publish("done")
	wanted = nil
	Bus:Fire("MARKET_PATCHED", itemID)
end

local function Send()
	if not wanted or not ns.auctionHouseOpen then
		return Finish()
	end
	-- Never in the way of a scan or a purchase.
	if ns.Downloader:IsRunning() or ns.Buying.state.phase == "quoting" or ns.Buying.state.phase == "buying" then
		ns.EventLog:Note("live check dropped", wanted.itemID, "a scan or a purchase is under way")
		return Finish()
	end
	-- The game takes one request at a time. When it is busy, wait for it to
	-- say it is ready (see the event handler) instead of giving up.
	if not C_AuctionHouse.IsThrottledMessageSystemReady() then
		ns.EventLog:Note("live check waiting", wanted.itemID, "the auction house is busy")
		return
	end
	local sorts = wanted.commodity and {}
		or {
			{ sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
			{ sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false },
		}
	local ok, problem = pcall(C_AuctionHouse.SendSearchQuery, wanted.itemKey, sorts, false)
	ns.EventLog:Note("live check", wanted.itemID, wanted.commodity and "goods" or "item", wanted.itemKey.itemLevel, wanted.itemKey.itemSuffix, ok, problem)
	if not ok then
		return Finish()
	end
	Publish("sent")
	local mine = attempt
	C_Timer.After(ANSWER_SECONDS, function()
		if mine == attempt and LiveCheck.state.phase == "sent" then
			ns.EventLog:Note("live check unanswered", wanted and wanted.itemID)
			Finish()
		end
	end)
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
	attempt = attempt + 1
	local mine = attempt
	local commodity = ns.Orders.IsCommodity(item)
	wanted = { itemID = item.itemID, name = item.name, commodity = commodity }
	Publish("waiting")

	-- Asks once the item's key is known and the player has settled on the row.
	local function Ready(itemKey)
		if mine ~= attempt or not wanted then
			return
		end
		wanted.itemKey = itemKey
		wanted.settled = true
		Send()
	end

	C_Timer.After(ns.LiveCheckRule.settleSeconds, function()
		if mine ~= attempt or not wanted then
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
			if mine ~= attempt or not wanted then
				return
			end
			if itemKey then
				return Ready(itemKey)
			end
			-- Not finding an item is not proof that it is gone: the lookup may
			-- be at fault. Nothing is removed on that alone. The scan's rows
			-- stand, and the panel says what the lookup found instead.
			local text = problem == "gone" and ns.L.STAT_CHECK_NOT_FOUND:format(found or "") or ns.L.STAT_CHECK_UNREAD:format(problem or "")
			LiveCheck.problem = { itemID = item.itemID, text = text }
			Finish()
		end)
	end)
	return true
end

local frame = CreateFrame("Frame")
-- Forever answers an item search with AUCTION_HOUSE_NEW_RESULTS_RECEIVED,
-- where other clients send ITEM_SEARCH_RESULTS_UPDATED. Both are taken.
for _, event in ipairs({ "AUCTION_HOUSE_NEW_RESULTS_RECEIVED", "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, subject)
	if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		-- The game was busy when we wanted to ask. It is ready now.
		if wanted and LiveCheck.state.phase == "waiting" and wanted.settled then
			Send()
		end
		return
	end
	if not wanted or LiveCheck.state.phase ~= "sent" then
		return
	end
	-- The game's own window and the Buy button search too. Only our answer counts.
	local commodity = event == "COMMODITY_SEARCH_RESULTS_UPDATED"
	local itemID = commodity and subject or (type(subject) == "table" and subject.itemID)
	if commodity ~= wanted.commodity or (itemID and itemID ~= wanted.itemID) then
		return
	end
	-- Read the results a moment later, once they have settled.
	local mine = attempt
	C_Timer.After(ns.SearchSettleSeconds, function()
		if mine == attempt and wanted and LiveCheck.state.phase == "sent" then
			Answered()
		end
	end)
end)

Bus:On("AH_CLOSED", function()
	if wanted then
		Finish()
	end
end)

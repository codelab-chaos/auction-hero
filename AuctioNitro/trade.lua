-- Live trading. Search/quote events only update the display. Every purchase,
-- post and confirmation is issued from an explicit button press.
local _, ns = ...
local AH = C_AuctionHouse
local Trade = { state={ phase="idle" } }
ns.Trade = Trade

local function Publish(state)
	Trade.state = state
	ns.Bus:Fire("TRADE_CHANGED", state)
end
local function Fail(text)
	local old = Trade.state
	if old.commodity and (old.phase == "quote" or old.phase == "quoting") then AH.CancelCommoditiesPurchase() end
	Publish({ phase="error", message=text })
end
local function Invoke(fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then Fail(tostring(result)) end
	return ok, result
end
function Trade:IsBusy()
	local phase = self.state.phase
	return phase == "searching" or phase == "quoting" or phase == "purchasing" or phase == "posting"
end
function Trade:Ready()
	if not ns.auctionHouseOpen then Fail("Open the auction house first."); return false end
	if InCombatLockdown() then Fail("Trading is unavailable in combat."); return false end
	if ns.Downloader:IsRunning() then Fail("Wait for the scan to finish."); return false end
	if not AH.IsThrottledMessageSystemReady() then Fail("The auction house is busy. Try again shortly."); return false end
	return true
end
function Trade:Cancel()
	if self.state.phase == "purchasing" or self.state.phase == "posting" then return false end
	if self.state.commodity and (self.state.phase == "quote" or self.state.phase == "quoting") then AH.CancelCommoditiesPurchase() end
	if self.state.phase == "post-confirm" and AH.CancelSell then AH.CancelSell() end
	Publish({ phase="idle" })
	return true
end

local function Expire(state, seconds)
	C_Timer.After(seconds, function()
		if Trade.state == state and (Trade:IsBusy() or state.phase == "quote" or state.phase == "item" or state.phase == "post-confirm") then
			if state.commodity and (state.phase == "quote" or state.phase == "quoting") then AH.CancelCommoditiesPurchase() end
			if state.phase == "post-confirm" and AH.CancelSell then AH.CancelSell() end
			Fail("The request expired. Check the current price again.")
		end
	end)
end

function Trade:Search(item, quantity)
	if self:IsBusy() or not self:Cancel() or not self:Ready() then return end
	local key = AH.MakeItemKey(item.itemID)
	local info = AH.GetItemKeyInfo(key)
	if not info then Fail("Item details are loading. Check the price again shortly."); return end
	local state = { phase="searching", item=item, key=key, quantity=math.max(1, math.floor(quantity or 1)),
		commodity=info.isCommodity, message="Checking current listings..." }
	Publish(state)
	local sorts = { { sortOrder=Enum.AuctionHouseSortOrder.Price, reverseSort=false } }
	local ok, err = pcall(AH.SendSearchQuery, key, sorts, true)
	if not ok then Fail(tostring(err)); return end
	Expire(state, 30)
end

local function ReadResults(state)
	if state.commodity then
		local left, cost = state.quantity, 0
		for i = 1, AH.GetNumCommoditySearchResults(state.item.itemID) do
			local row = AH.GetCommoditySearchResultInfo(state.item.itemID, i)
			if row then
				local take = math.min(left, math.max(0, row.quantity - (row.numOwnerItems or 0)))
				cost, left = cost + take * row.unitPrice, left - take
				if left == 0 then break end
			end
		end
		if left == 0 then
			state.phase, state.cost, state.message = "commodity", cost, "Current listings checked. Request a purchase quote."
			Publish(state)
			return
		end
		if not AH.HasFullCommoditySearchResults(state.item.itemID) then
			if AH.IsThrottledMessageSystemReady() then AH.RequestMoreCommoditySearchResults(state.item.itemID) end
			return
		end
	else
		local best
		for i = 1, AH.GetNumItemSearchResults(state.key) do
			local row = AH.GetItemSearchResultInfo(state.key, i)
			local name = row and row.itemLink and row.itemLink:match("|h%[(.-)%]|h")
			if row and name == state.item.name and not row.containsOwnerItem and not row.containsAccountItem
				and row.buyoutAmount and row.buyoutAmount > 0 and row.quantity > 0 then
				if not best or row.buyoutAmount / row.quantity < best.buyoutAmount / best.quantity then best = row end
			end
		end
		if best then
			state.phase, state.auctionID, state.cost, state.units = "item", best.auctionID, best.buyoutAmount, best.quantity
			state.message = "Current auction checked. This press buys one whole auction."
			Publish(state)
			return
		end
		if not AH.HasFullItemSearchResults(state.key) then
			if AH.IsThrottledMessageSystemReady() then AH.RequestMoreItemSearchResults(state.key) end
			return
		end
	end
	Fail("No matching stock is available at the auction house.")
end

function Trade:Buy()
	local state = self.state
	if self:IsBusy() or not self:Ready() then return end
	if state.phase == "commodity" then
		if state.cost > GetMoney() then Fail("Not enough gold."); return end
		state.phase, state.message = "quoting", "Requesting the current purchase quote..."
		Publish(state)
		Invoke(AH.StartCommoditiesPurchase, state.item.itemID, state.quantity)
		Expire(state, 15)
	elseif state.phase == "quote" then
		if AH.GetQuoteDurationRemaining() <= 0 then self:Cancel(); Fail("The quote expired. Check the current price again."); return end
		if state.cost > GetMoney() then self:Cancel(); Fail("Not enough gold."); return end
		state.phase, state.message = "purchasing", "Buying..."
		Publish(state)
		Invoke(AH.ConfirmCommoditiesPurchase, state.item.itemID, state.quantity)
		Expire(state, 30)
	elseif state.phase == "item" then
		-- Results may have changed after the button was drawn. Require the same
		-- auction id, variant, stack quantity and total buyout at click time.
		local matched = false
		for i = 1, AH.GetNumItemSearchResults(state.key) do
			local row = AH.GetItemSearchResultInfo(state.key, i)
			if row and row.auctionID == state.auctionID and row.buyoutAmount == state.cost and row.quantity == state.units
				and row.itemLink and row.itemLink:match("|h%[(.-)%]|h") == state.item.name
				and not row.containsOwnerItem and not row.containsAccountItem then matched = true; break end
		end
		if not matched then Fail("That auction changed. Check the current price again."); return end
		if state.cost > GetMoney() then Fail("Not enough gold."); return end
		state.phase, state.message = "purchasing", "Buying..."
		Publish(state)
		Invoke(AH.PlaceBid, state.auctionID, state.cost)
		Expire(state, 30)
	end
end

function Trade:Post(key, quantity, unitPrice, bidUnit, duration, saleType)
	if self:IsBusy() or not self:Ready() then return end
	if self.state.phase == "post-confirm" then
		local p = self.state.post
		if p.key ~= key or p.quantity ~= quantity or p.unitPrice ~= unitPrice or p.bidUnit ~= bidUnit or p.duration ~= duration or p.saleType ~= saleType then
			self:Cancel(); Fail("The form changed. Review it and post again."); return
		end
		local link = C_Item.GetItemLink(p.location)
		if link ~= p.link or not AH.IsSellItemValid(p.location, false) then self:Cancel(); Fail("The bag item changed. Select it again."); return end
		local state = { phase="posting", post=p, message="Posting..." }
		Publish(state)
		if p.commodity then Invoke(AH.ConfirmPostCommodity, p.location, p.duration, p.quantity, p.unitPrice)
		else Invoke(AH.ConfirmPostItem, p.location, p.duration, p.quantity, p.bid, p.buyout) end
		Expire(state, 30)
		return
	end
	if not self:Cancel() then return end
	local location, item = ns.Inventory:Locate(key)
	if not location or not AH.IsSellItemValid(location, false) then Fail("That item cannot be posted right now."); return end
	local status = AH.GetItemCommodityStatus(location)
	if status == 0 then Fail("Item details are loading. Try again shortly."); return end
	local commodity = status == 2
	quantity, unitPrice, bidUnit = tonumber(quantity), tonumber(unitPrice), tonumber(bidUnit)
	if not quantity or quantity < 1 or quantity ~= math.floor(quantity) or quantity > AH.GetAvailablePostCount(location) then Fail("Check the quantity in your bags."); return end
	if not unitPrice or unitPrice < 1 or unitPrice ~= math.floor(unitPrice) or not bidUnit or bidUnit < 1 or bidUnit ~= math.floor(bidUnit) then Fail("Enter a valid price."); return end
	if duration ~= 1 and duration ~= 2 and duration ~= 3 then Fail("Choose a duration."); return end
	if saleType ~= "buyout" and saleType ~= "both" and saleType ~= "bids" then Fail("Choose a sale type."); return end
	if commodity and saleType ~= "buyout" then Fail("Commodities use a buyout price."); return end
	if saleType == "both" and bidUnit >= unitPrice then Fail("The starting bid must be below the buyout."); return end
	if not AH.SupportsCopperValues() and (unitPrice % 100 ~= 0 or (saleType ~= "buyout" and bidUnit % 100 ~= 0)) then Fail("This auction house only accepts whole silver prices."); return end
	local deposit = commodity and AH.CalculateCommodityDeposit(item.itemID, duration, quantity) or AH.CalculateItemDeposit(location, duration, quantity)
	if not deposit then Fail("The deposit is not ready. Try again."); return end
	if deposit > GetMoney() then Fail("Not enough gold for the deposit."); return end
	local p = { key=key, location=location, link=C_Item.GetItemLink(location), quantity=quantity,
		unitPrice=unitPrice, bidUnit=bidUnit, duration=duration, saleType=saleType, commodity=commodity,
		bid=saleType ~= "buyout" and bidUnit * quantity or nil, buyout=saleType ~= "bids" and unitPrice * quantity or nil }
	local state = { phase="posting", post=p, message="Posting..." }
	Publish(state)
	local ok, confirm
	if commodity then ok, confirm = Invoke(AH.PostCommodity, location, duration, quantity, unitPrice)
	else ok, confirm = Invoke(AH.PostItem, location, duration, quantity, p.bid, p.buyout) end
	if not ok then return end
	if self.state == state and confirm then state.phase, state.message = "post-confirm", "Review the price, then confirm this post."; Publish(state) end
	Expire(state, 30)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED", "COMMODITY_SEARCH_RESULTS_UPDATED",
	"COMMODITY_SEARCH_RESULTS_ADDED", "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED",
	"COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_POST_ERROR",
	"AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "AUCTION_HOUSE_SHOW_ERROR" }) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, arg1, arg2)
	local state = Trade.state
	if state.phase == "searching" then
		if (event:match("^ITEM_SEARCH_RESULTS") and type(arg1) == "table" and arg1.itemID == state.key.itemID)
			or (event:match("^COMMODITY_SEARCH_RESULTS") and arg1 == state.item.itemID)
			or event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then ReadResults(state) end
	elseif event == "COMMODITY_PRICE_UPDATED" and (state.phase == "quoting" or state.phase == "quote") then
		if type(arg1) ~= "number" or type(arg2) ~= "number" or arg1 <= 0 or arg2 <= 0 then Fail("Invalid purchase quote. Check the current price again."); return end
		state.cost, state.unitPrice, state.phase = arg2, arg1, "quote"
		state.message = "Quote ready. Review the total and press Buy to confirm."
		Publish(state)
	elseif event == "COMMODITY_PRICE_UNAVAILABLE" and state.commodity then
		Trade:Cancel(); Fail("The purchase quote is unavailable. Check the price again.")
	elseif (event == "COMMODITY_PURCHASE_SUCCEEDED" and state.commodity and state.phase == "purchasing")
		or (event == "AUCTION_HOUSE_PURCHASE_COMPLETED" and state.phase == "purchasing" and arg1 == state.auctionID) then
		Publish({ phase="done", message="Purchase complete. Check the current price before buying again." })
	elseif event == "AUCTION_HOUSE_AUCTION_CREATED" and state.phase == "posting" then
		local post = state.post
		Publish({ phase="done", message="Auction posted." })
		ns.Bus:Fire("POST_SUCCEEDED", post)
	elseif (event == "AUCTION_HOUSE_POST_ERROR" and state.phase == "posting")
		or (event == "COMMODITY_PURCHASE_FAILED" and state.phase == "purchasing")
		or (event == "AUCTION_HOUSE_SHOW_ERROR" and Trade:IsBusy()) then
		Fail("The auction house rejected the action. Check the current price or your bags and try again.")
	end
end)
ns.Bus:On("AH_CLOSED", function()
	if Trade.state.commodity and (Trade.state.phase == "quote" or Trade.state.phase == "quoting") then AH.CancelCommoditiesPurchase() end
	Publish({ phase="idle", message="Auction house closed." })
end)

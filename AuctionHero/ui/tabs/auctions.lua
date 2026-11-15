-- Auctions tab: what the player has up for sale right now, and what has sold.
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local state = { sort = { id = "time", descending = false } }
local list, summary, cancelButton, note

local SORT_VALUES = {
	name = function(auction)
		return auction.name
	end,
	quantity = function(auction)
		return auction.quantity
	end,
	buyout = function(auction)
		return auction.buyout
	end,
	bid = function(auction)
		return auction.bid
	end,
	time = function(auction)
		return auction.secondsLeft
	end,
	status = function(auction)
		return auction.sold and 1 or 0
	end,
}

-- The auction picked in the list, while it is still one of ours.
local function Picked()
	for _, auction in ipairs(ns.Owned.auctions) do
		if auction.auctionID == state.picked then
			return auction
		end
	end
end

-- The cancel button follows the cancel as it goes: pick, confirm, cancelling.
local function PaintCancel()
	local cancel = ns.Cancelling.state
	local picked = Picked()
	local mine = picked and cancel.auctionID == picked.auctionID
	if mine and cancel.phase == "confirm" then
		cancelButton:SetLabel(cancel.cost and cancel.cost > 0 and L.AUCTIONS_CANCEL_CONFIRM_COST:format(ns.PlainMoney(cancel.cost)) or L.AUCTIONS_CANCEL_CONFIRM)
		cancelButton:SetDisabled(false)
	elseif cancel.phase == "cancelling" or cancel.phase == "checking" then
		cancelButton:SetLabel(L.CANCEL_SENDING)
		cancelButton:SetDisabled(true)
	else
		cancelButton:SetLabel(L.AUCTIONS_CANCEL)
		cancelButton:SetDisabled(not picked or picked.sold or not ns.auctionHouseOpen)
	end
	local say = cancel.phase ~= "idle" and cancel.message or ""
	note:SetText(say)
	note:SetTextColor(unpack(cancel.phase == "failed" and C.bad or cancel.phase == "done" and C.good or C.muted))
end

local function Refresh()
	local rows = {}
	local active, sold, value = 0, 0, 0
	for _, auction in ipairs(ns.Owned.auctions) do
		rows[#rows + 1] = auction
		if auction.sold then
			sold = sold + 1
		else
			active = active + 1
			value = value + (auction.buyout or 0)
		end
	end
	Kit.SortRows(rows, SORT_VALUES[state.sort.id], state.sort.descending)
	list:SetSort(state.sort.id, state.sort.descending)
	if not ns.auctionHouseOpen and not ns.Owned.asked then
		list:SetEmptyText(L.AUCTIONS_NEEDS_AH)
	else
		list:SetEmptyText(L.AUCTIONS_NONE)
	end
	list:SetRows(rows, true)
	summary:SetText(L.AUCTIONS_SUMMARY:format(ns.Comma(active), ns.Comma(sold), ns.Money(value)))
	PaintCancel()
end

local function Create(parent)
	local bar = Kit.Panel(parent)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(36)
	summary = Kit.Text(bar, "normal", C.text)
	summary:SetPoint("LEFT", 10, 0)
	local refresh = Kit.Button(bar, { text = L.AUCTIONS_REFRESH, padding = 16, tip = { L.AUCTIONS_REFRESH, L.AUCTIONS_REFRESH_TIP }, onClick = function()
		ns.Owned:Request()
	end })
	refresh:SetPoint("RIGHT", -6, 0)
	cancelButton = Kit.Button(bar, { text = L.AUCTIONS_CANCEL, padding = 16, tip = { L.AUCTIONS_CANCEL, L.AUCTIONS_CANCEL_TIP }, onClick = function()
		local picked = Picked()
		if ns.Cancelling.state.phase == "confirm" and picked and ns.Cancelling.state.auctionID == picked.auctionID then
			ns.Cancelling:Confirm()
		else
			ns.Cancelling:Start(picked)
		end
	end })
	cancelButton:SetPoint("RIGHT", refresh, "LEFT", -6, 0)
	note = Kit.Text(bar, "small", C.muted)
	note:SetPoint("LEFT", summary, "RIGHT", 16, 0)
	note:SetPoint("RIGHT", cancelButton, "LEFT", -12, 0)
	note:SetJustifyH("RIGHT")

	list = Kit.List(parent, {
		id = "auctions",
		columns = {
			{
				id = "name",
				label = L.BUY_COL_ITEM,
				flex = true,
				icon = function(auction)
					return auction.icon
				end,
				text = function(auction)
					return auction.name
				end,
				color = function(auction)
					return Kit.QualityColor(auction.quality)
				end,
			},
			{ id = "quantity", label = L.AUCTIONS_COL_QUANTITY, width = 50, align = "RIGHT", text = function(auction)
				return ns.Comma(auction.quantity)
			end },
			{ id = "buyout", label = L.SELL_BUYOUT, width = 110, align = "RIGHT", text = function(auction)
				return auction.buyout and ns.Money(auction.buyout) or ""
			end },
			{ id = "bid", label = L.AUCTIONS_COL_BID, width = 110, align = "RIGHT", text = function(auction)
				return auction.bid and auction.bid > 0 and ns.Money(auction.bid) or ""
			end },
			{ id = "time", label = L.AUCTIONS_COL_TIME, width = 90, align = "RIGHT", text = function(auction)
				return auction.secondsLeft and ns.Duration(auction.secondsLeft) or ""
			end },
			{
				id = "status",
				label = L.AUCTIONS_COL_STATUS,
				width = 70,
				align = "RIGHT",
				text = function(auction)
					return auction.sold and L.AUCTIONS_SOLD or L.AUCTIONS_ACTIVE
				end,
				color = function(auction)
					return auction.sold and C.good or C.muted
				end,
			},
		},
		empty = L.AUCTIONS_NONE,
		-- Picking a row chooses the auction to cancel; picking another backs
		-- out of a cancel waiting for its confirm.
		onClick = function(auction)
			if state.picked ~= auction.auctionID then
				ns.Cancelling:Back()
			end
			state.picked = auction.auctionID
			Refresh()
		end,
		isSelected = function(auction)
			return auction.auctionID == state.picked
		end,
		link = function(auction)
			return auction.link
		end,
		onSort = function(id)
			if state.sort.id == id then
				state.sort.descending = not state.sort.descending
			else
				state.sort = { id = id, descending = id == "buyout" or id == "bid" }
			end
			Refresh()
		end,
	})
	list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
	list:SetPoint("BOTTOMRIGHT")

	-- Ask as soon as the tab is first opened.
	ns.Owned:Request()
	return { Refresh = Refresh }
end

ns.Window:RegisterTab({ id = "auctions", label = L.TAB_AUCTIONS, order = 4, Create = Create })

ns.Bus:On("CANCEL_CHANGED", function()
	if list and ns.charDb.tab == "auctions" then
		ns.Window:RefreshActive()
	end
end)

ns.Bus:On("OWNED_CHANGED", function()
	if list and ns.charDb.tab == "auctions" then
		ns.Window:RefreshActive()
	end
end)

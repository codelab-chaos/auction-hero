-- What Auction Hero adds to an item's tooltip, as data: one rule per line, in
-- order. A rule returns the text for the right-hand side, or nothing to leave
-- its line out. An item nothing is known about gets no lines at all.
--
-- A rule is handed:
--   record   the item's price memory (see ns.HistoryRule), or nil
--   last     its newest daily point: { day, median, low, units }, or nil
--   now      the server time
--   trades   the item's row of the ledger's summary, or nil
--   live     the item in the scan now loaded, with its price ladder, or nil
local _, ns = ...
local L = ns.L

-- Older asking prices remain useful, but are presented as estimates.
ns.RecipePriceRule = { freshSeconds = 15 * 60 }

-- Units for sale at each different price, cheapest first (see market\market.lua).
local function Prices(live)
	return ns.Market.PricePoints(live)
end

-- A price with how many of everything for sale are at it.
local function Quote(point, live)
	return L.TIP_PRICE_OF:format(ns.Money(point.unit), ns.Comma(point.units), ns.Comma(live.units))
end

-- Every price quoted here is one an auction is listed at, with how many are
-- at it. Nothing is an average, and nothing claims to be what the item sells
-- for: a scan sees asking prices only. The one confirmed sale price is the
-- player's own, from the ledger.
ns.TooltipLines = {
	{
		label = L.TIP_LOWEST,
		text = function(info)
			local live = info.live
			if live and live.min then
				return Quote(Prices(live)[1], live)
			end
			-- Not in the scan now loaded: what the last scan to see it saw.
			return info.last and L.TIP_LOWEST_THEN:format(ns.Money(info.last.low), ns.Comma(info.last.units))
		end,
	},
	{
		-- What you pay if the cheapest is gone.
		label = L.TIP_NEXT,
		text = function(info)
			local second = info.live and Prices(info.live)[2]
			return second and Quote(second, info.live)
		end,
	},
	{
		-- The price most of them share, when it is not one of the two above.
		label = L.TIP_COMMON,
		text = function(info)
			local live = info.live
			if not live then
				return nil
			end
			local points = Prices(live)
			local common, at = nil, 0
			for index, point in ipairs(points) do
				if point.units > (common and common.units or 1) then
					common, at = point, index
				end
			end
			return common and at > 2 and Quote(common, live)
		end,
	},
	{
		label = L.TIP_RANGE,
		text = function(info)
			local record = info.record
			return record and record.n > 1 and record.lo < record.hi and L.TIP_RANGE_VALUE:format(ns.Money(record.lo), ns.Money(record.hi))
		end,
	},
	{
		label = L.TIP_SEEN,
		text = function(info)
			return info.last and ns.Ago(math.max(0, info.now - info.last.time))
		end,
	},
	{
		trades = true, -- from the ledger, not the scans
		label = L.TIP_PAID,
		text = function(info)
			local trades = info.trades
			return trades and trades.held > 0 and L.TIP_PAID_VALUE:format(ns.Money(math.floor(trades.heldCost / trades.held)), ns.Comma(trades.held))
		end,
	},
	{
		trades = true,
		label = L.TIP_SOLD,
		text = function(info)
			return info.trades and info.trades.lastSale and ns.Money(info.trades.lastSale)
		end,
	},
}

-- More about an item than a tooltip has room for, shown under the Buy button
-- with the lines above: how much scanning stands behind the prices.
ns.ItemStatLines = {
	{
		label = L.STAT_SCANS,
		text = function(info)
			local record = info.record
			if not record then
				return nil
			end
			return (record.n == 1 and L.STAT_SCANS_ONE or L.STAT_SCANS_MANY):format(ns.Comma(record.n))
				.. " "
				.. (record.d == 1 and L.STAT_DAYS_ONE or L.STAT_DAYS_MANY):format(ns.Comma(record.d))
		end,
	},
	{
		label = L.STAT_USUAL_LOW,
		text = function(info)
			return info.typicalLow and ns.Money(info.typicalLow)
		end,
	},
	{
		label = L.STAT_LOWEST_EVER,
		text = function(info)
			local record = info.record
			if not record then
				return nil
			end
			if record.lou and record.lot then
				return L.STAT_LOWEST_EVER_VALUE:format(ns.Money(record.lo), ns.Comma(record.lou), ns.Ago(math.max(0, info.now - record.lot)))
			end
			return ns.Money(record.lo)
		end,
	},
}

-- Trading rules, as data: how prices are suggested, how sure we are of them,
-- and how the price history is kept. The lab (lab/src/config) holds the same
-- tables in TypeScript, since that is where they are tried out first.
local _, ns = ...
local L = ns.L

-- Things we assume because the game does not tell us.
ns.Assumptions = {
	-- Share of a sale the auction house keeps. 5% is the Classic rule, not yet
	-- confirmed on Forever.
	auctionCut = 0.05,
}

-- ========= Price rules ======================================================
-- Each looks at an item's price ladder and says what unit price to post at.
--   label  the word on the button
--   tip    what the rule does and when you would pick it
--   price  function(item, usual) -> copper per unit, or nil when it cannot say
local OUTLIER_SHARE_OF_USUAL = 0.5

ns.PriceRules = {
	{
		id = "match",
		label = L.RULE_MATCH,
		tip = L.RULE_MATCH_TIP,
		price = function(item)
			return item.min
		end,
	},
	{
		id = "undercut",
		label = L.RULE_UNDERCUT,
		tip = L.RULE_UNDERCUT_TIP,
		price = function(item)
			return item.min and math.max(1, item.min - 1)
		end,
	},
	{
		id = "quick",
		label = L.RULE_QUICK,
		tip = L.RULE_QUICK_TIP,
		price = function(item)
			return item.min and math.max(1, math.floor(item.min * 0.95))
		end,
	},
	{
		id = "skip",
		label = L.RULE_SKIP,
		tip = L.RULE_SKIP_TIP,
		price = function(item, usual)
			if not usual then
				return nil
			end
			local floor = usual * OUTLIER_SHARE_OF_USUAL
			for _, tier in ipairs(item.tiers) do
				if tier.unit >= floor then
					return math.max(1, tier.unit - 1)
				end
			end
		end,
	},
	{
		id = "usual",
		label = L.RULE_USUAL,
		tip = L.RULE_USUAL_TIP,
		price = function(_, usual)
			return usual
		end,
	},
}
ns.DefaultPriceRule = "skip"

-- The lowest price the server takes for an auction of a single item (gear and
-- the like), in copper. Goods sold by the unit have no such floor. Read from
-- real scans: of about 100,000 single-item auctions none was under 1 silver,
-- while goods sold by the unit go down to 1 copper. A post under the floor is
-- never answered, and the auction house stops responding until you log out.
ns.MinItemPrice = 100

-- ========= Sale types and durations ========================================
ns.SaleTypes = {
	{ id = "buyout", label = L.SALE_BUYOUT, tip = L.SALE_BUYOUT_TIP, buyout = true, bids = false },
	{ id = "both", label = L.SALE_BOTH, tip = L.SALE_BOTH_TIP, buyout = true, bids = true },
	{ id = "bids", label = L.SALE_BIDS, tip = L.SALE_BIDS_TIP, buyout = false, bids = true },
}

-- When bids are on, the starting bid begins at this share of the price.
ns.StartingBidShare = 0.8

-- The game offers three durations by index. What each means in hours is not
-- confirmed on Forever yet, so they are named by position.
ns.Durations = {
	{ index = 1, label = L.DURATION_SHORT, tip = L.DURATION_SHORT_TIP },
	{ index = 2, label = L.DURATION_MEDIUM, tip = L.DURATION_MEDIUM_TIP },
	{ index = 3, label = L.DURATION_LONG, tip = L.DURATION_LONG_TIP },
}
ns.DefaultDuration = 3

-- ========= Price confidence =================================================
-- How far to trust a price read off an item's auctions. Scored 0 to 100:
-- the number of different prices sets the base, how well they agree scales it,
-- and how many scans have seen the item caps it.
--   min   lowest score that earns the level
--   pips  filled pips on the meter
--   tone  the pip color, a key of the meter's tones
ns.ConfidenceLevels = {
	{ id = "none", label = L.CONFIDENCE_NONE, min = 0, pips = 0, tone = "bad" },
	{ id = "low", label = L.CONFIDENCE_LOW, min = 1, pips = 1, tone = "bad" },
	{ id = "fair", label = L.CONFIDENCE_FAIR, min = 30, pips = 2, tone = "warn" },
	{ id = "good", label = L.CONFIDENCE_GOOD, min = 55, pips = 3, tone = "ok" },
	{ id = "high", label = L.CONFIDENCE_HIGH, min = 80, pips = 4, tone = "good" },
}
ns.ConfidencePips = 4

ns.ConfidenceRule = {
	-- More different prices to compare means a steadier price. Identical
	-- auctions count once: six auctions at one price are one seller's opinion.
	depth = {
		{ prices = 1, score = 15 },
		{ prices = 2, score = 30 },
		{ prices = 4, score = 60 },
		{ prices = 8, score = 85 },
		{ prices = 15, score = 100 },
	},
	-- Units priced within this share of the usual price count as agreeing on it.
	agreementBand = 0.25,
	-- How much of the depth score survives when nothing agrees.
	agreementFloor = 0.5,
	-- Below this share of agreeing units, say so.
	agreementWarning = 0.5,
	-- A price seen in one scan is a snapshot. Each further scan that sees the
	-- item lets more of the score through, up to the full score.
	scans = {
		{ scans = 1, share = 0.75 },
		{ scans = 2, share = 0.85 },
		{ scans = 3, share = 0.92 },
		{ scans = 5, share = 1 },
	},
}

-- ========= Price history ====================================================
-- One small record per item, updated by every scan and never growing:
--   u   usual price: a running average of the scan medians
--   m   the last scan's median
--   lo  lowest price ever seen       hi  highest median ever seen
--   lou how many were at that lowest price, and lot when (nil on old records)
--   n   scans that saw the item      d   days that saw it
--   f   first day seen               l   last day seen (days since 1970)
--   h   the points a price graph is drawn from, newest last, packed into
--       one string as "time:median:lowest:units:unitsAtLowest" joined by
--       ";" (older points lack the last number). Points are
--       at least pointHours apart, and the newest scan is always the last
ns.HistoryRule = {
	-- How much a new scan moves the usual price. 0.3 means a new scan counts
	-- for 30% and everything before it for 70%.
	smoothing = 0.3,
	-- How many days back each item's graph points reach. Older ones fall off.
	-- This is the starting value: the player can change it with /ah history,
	-- within the limits below. A point is about 25 bytes.
	graphPoints = 30,
	graphPointsMin = 7,
	graphPointsMax = 30,
	-- The lengths offered in the settings, in days.
	dayChoices = { 7, 14, 30 },
	-- The least time between two kept points, in hours. Scans made closer
	-- together than this update the newest point instead of adding one.
	pointHours = 8,
	-- Items not seen for this many days are dropped.
	forgetDays = 45,
	-- The usual price comes from history once this many scans have seen the
	-- item. Before that, it is the current scan's median.
	trustAfterScans = 2,
}

-- How long each flow waits on the game before deciding by other evidence or
-- giving up, in seconds (see trade\deadlines.lua). Single items, live checks
-- and item keys wait as their request kind says (data\requests.lua).
ns.AnswerSeconds = {
	post = 8, -- then the bags decide: the item gone means it was posted
	buy = 10, -- a quote or a purchase of goods
	cancel = 10, -- then the list of owned auctions is asked for again to settle it
}

-- ========= Live checks ======================================================
-- A scan ages. Choosing an item to buy asks the auction house for that one
-- item's listings as they are now, and patches them into the scan.
ns.LiveCheckRule = {
	-- A scan newer than this is trusted as it is, and so is an item checked
	-- this recently. In minutes.
	staleMinutes = 5,
	-- Wait this long after an item is chosen before asking, so clicking down a
	-- list does not send a request for every row. In seconds.
	settleSeconds = 0.4,
	-- A check this recent is as good as asking again: pressing Buy on a single
	-- item at the price the check saw buys it in that one press. Choosing a
	-- single item checks it again once its last check is older. In seconds.
	reuseSeconds = 60,
	-- A long list of auctions comes a page at a time. Read at most this many.
	maxPages = 20,
}

-- ========= Buying ===========================================================
-- Commodities are bought by the unit: ask for 40 and you get exactly 40, from
-- the cheapest sellers up, in one purchase. Everything else is bought one
-- whole auction at a time. The scan says which an item is when the game had
-- the answer ready. For the rest we go by item class.
ns.CommodityClassIDs = { [0] = true, [5] = true, [6] = true, [7] = true, [12] = true, [15] = true }

-- The order the Sell tab groups your bags in, by item class: what is most
-- often sold first. A class not listed comes after these, by class number.
--   7 trade goods, 0 consumables, 5 reagents, 6 projectiles, 1 containers,
--   2 weapons, 4 armor, 9 recipes, 3 gems, 15 miscellaneous, 12 quest
ns.BagCategoryOrder = { 7, 0, 5, 6, 1, 2, 4, 9, 3, 15, 12 }

-- The Sell tab's bag filters, left to right. classes: the item classes it
-- shows; none means everything.
ns.BagFilters = {
	{ id = "all", label = L.SELL_FILTER_ALL },
	{ id = "gear", label = L.SELL_FILTER_GEAR, tip = L.SELL_FILTER_GEAR_TIP, classes = { [2] = true, [4] = true } },
	{ id = "trade", label = L.SELL_FILTER_TRADE, tip = L.SELL_FILTER_TRADE_TIP, classes = { [7] = true, [5] = true, [3] = true, [9] = true } },
	{ id = "use", label = L.SELL_FILTER_USE, tip = L.SELL_FILTER_USE_TIP, classes = { [0] = true, [6] = true } },
}

-- Quick quantities for goods bought by the unit, in whole stacks (a stack is
-- what one bag slot holds: 200 arrows, 20 cloth). One button each.
ns.BuyStackPresets = { 1, 2, 5 }

-- ========= Deals ============================================================
-- A price is a deal against the price you would otherwise pay: the baseline.
--   floorShare      the baseline starts from today's floor, the price reached
--                   once this share of the units for sale is skipped, so a
--                   stray low listing is not the price of all the others
--   floorMinUnits   and never fewer units than this
--   historyPoints   once an item has this many graph points, the baseline is
--                   also held down to its usual lowest price, so asking prices
--                   that have crept up cannot make an ordinary price a deal
ns.BaselineRule = { floorShare = 0.2, floorMinUnits = 2, historyPoints = 3 }

-- A list row gets a deal badge when its cheapest price sits this far under
-- the baseline, and the baseline has something behind it: past scans, or at
-- least minPrices different prices today.
ns.DealBadgeRule = { percent = 30, minPrices = 3 }

-- ========= The deal meter ===================================================
-- How good a buy is: how far the price you would pay sits under the item's
-- usual price. It is judged on the whole order, so buying deeper into the
-- ladder makes the deal worse. Five steps, one pip each.
ns.DealLevels = {
	over = { id = "over", label = L.DEAL_OVER, pips = 1, tone = "bad" },
	fair = { id = "fair", label = L.DEAL_FAIR, pips = 2, tone = "warn" },
	great = { id = "great", label = L.DEAL_GREAT, pips = 3, tone = "good" },
	confident = { id = "confident", label = L.DEAL_CONFIDENT, pips = 4, tone = "good" },
	resell = { id = "resell", label = L.DEAL_RESELL, pips = 5, tone = "good" },
}
ns.DealPips = 5

ns.DealRule = {
	fairBand = 10, -- percent over the baseline that still counts as fair
	greatFrom = 15, -- percent under the baseline that makes it great to buy
	-- A great price is a confident one when past scans back the baseline, or
	-- failing that when today's prices agree this well (an id from
	-- ns.ConfidenceLevels).
	confidentNeeds = "good",
	resellFrom = 30, -- percent under that leaves room to resell
}

-- ========= Reselling ========================================================
-- How far under the usual price an auction must be to be worth buying to sell
-- again. The middle one is the starting choice.
ns.ResellMargins = { 15, 30, 50 }
ns.ResellDefaultMargin = 30
ns.ResellMinListings = 5 -- ignore thin markets
-- The most units of an item that may be for sale, in all, for it to be shown
-- as a lead. Reselling means buying the market out and relisting it, so only
-- small markets are worth showing.
ns.ResellMaxItems = 10
ns.ResellMinPips = 4 -- a lead needs at least this deal reading to be listed
ns.ResellDefaultMinProfit = 5000 -- copper

-- ========= History charts ===================================================
-- How far back a chart can look, in days, and where it starts.
ns.HistoryRanges = { 3, 7, 14, 30 }
ns.HistoryDefaultRange = 30

-- The two price lines. The colors were checked as a pair on the window's dark
-- panel for color-blind separation and contrast.
ns.HistorySeries = {
	{
		label = L.HISTORY_SERIES_USUAL,
		color = ns.Theme.Hex("#bf8a2a"),
		value = function(point)
			return point.median
		end,
	},
	{
		label = L.HISTORY_SERIES_LOW,
		color = ns.Theme.Hex("#4a8fd6"),
		value = function(point)
			return point.low
		end,
	},
}

-- One muted color for the units bars: they show an amount, not an identity.
ns.HistoryUnits = {
	color = ns.Theme.Hex("#8f7f63"),
	value = function(point)
		return point.units
	end,
}

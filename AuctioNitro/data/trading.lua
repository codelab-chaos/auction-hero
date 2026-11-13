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
-- the number of auctions sets the base, how well sellers agree scales it,
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
	-- More auctions to compare with means a steadier price.
	depth = {
		{ auctions = 1, score = 15 },
		{ auctions = 2, score = 30 },
		{ auctions = 5, score = 60 },
		{ auctions = 15, score = 85 },
		{ auctions = 40, score = 100 },
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
--   n   scans that saw the item      d   days that saw it
--   f   first day seen               l   last day seen (days since 1970)
ns.HistoryRule = {
	-- How much a new scan moves the usual price. 0.3 means a new scan counts
	-- for 30% and everything before it for 70%.
	smoothing = 0.3,
	-- Items not seen for this many days are dropped.
	forgetDays = 45,
	-- The usual price comes from history once this many scans have seen the
	-- item. Before that, it is the current scan's median.
	trustAfterScans = 2,
}

-- ========= Buying ===========================================================
-- Commodities are bought by the unit: ask for 40 and you get exactly 40, from
-- the cheapest sellers up, in one purchase. Everything else is bought one
-- whole auction at a time. The scan says which an item is when the game had
-- the answer ready. For the rest we go by item class.
ns.CommodityClassIDs = { [0] = true, [5] = true, [6] = true, [7] = true, [12] = true, [15] = true }

-- An item is flagged as a deal in lists when its lowest price sits this far
-- under its usual price and it has at least this many auctions.
ns.DealBadgeRule = { percent = 30, minListings = 3 }

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
	fairBand = 10, -- percent over the usual price that still counts as fair
	greatFrom = 15, -- percent under the usual price that makes it great to buy
	confidentNeeds = "good", -- an id from ns.ConfidenceLevels
	resellFrom = 30, -- percent under that leaves room to resell
	resellNeeds = "high",
	-- Below this price confidence there is no deal reading at all.
	needsConfidence = "fair",
}

-- ========= Reselling ========================================================
-- How far under the usual price an auction must be to be worth buying to sell
-- again. The middle one is the starting choice.
ns.ResellMargins = { 15, 30, 50 }
ns.ResellDefaultMargin = 30
ns.ResellMinListings = 5 -- ignore thin markets
ns.ResellMinPips = 4 -- a lead needs at least this deal reading to be listed
ns.ResellDefaultMinProfit = 5000 -- copper

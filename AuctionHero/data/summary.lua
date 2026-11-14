-- What the Summary view shows, as data. Values come from the snapshot's meta
-- table (from = "meta") or from the derive step's totals (from = "totals").
--
--   format   how to print the value, a key of ns.Format in ui\view-model.lua
--   hideZero true hides the line when the value is 0, for numbers a source may not have
--   only     "listings" hides the line for sources whose rows are already one
--            item each. "aggregated" hides it for the others.
local _, ns = ...
local L = ns.L

ns.SummarySections = {
	{
		label = L.SUM_SECTION_SNAPSHOT,
		lines = {
			{ label = L.SUM_SOURCE, from = "meta", field = "sourceLabel", format = "text" },
			{ label = L.SUM_CAPTURED, from = "meta", field = "time", format = "date" },
			{ label = L.SUM_ELAPSED, from = "meta", field = "elapsed", format = "duration" },
			{ label = L.SUM_REALM, from = "meta", field = "place", format = "text" },
			{ label = L.SUM_BUILD, from = "meta", field = "build", format = "text" },
			{ label = L.SUM_ROWS, from = "meta", field = "count", format = "number" },
			{ label = L.SUM_RETURNS, from = "meta", field = "returns", format = "returns", only = "listings" },
			{ label = L.SUM_INCOMPLETE, from = "meta", field = "incomplete", format = "number" },
			{ label = L.SUM_PRICE_NOTE, from = "totals", field = "priceIsPerStack", format = "priceNote" },
		},
	},
	{
		label = L.SUM_SECTION_MARKET,
		lines = {
			{ label = L.SUM_ITEMS, from = "totals", field = "items", format = "number" },
			{ label = L.SUM_UNITS, from = "totals", field = "units", format = "number" },
			{ label = L.SUM_VALUE, from = "totals", field = "value", format = "money", only = "listings" },
			{ label = L.SUM_SELLERS, from = "totals", field = "sellers", format = "number", only = "listings", hideZero = true },
			{ label = L.SUM_WITH_BUYOUT, from = "totals", field = "withBuyout", format = "share", only = "listings" },
			{ label = L.SUM_BID_ONLY, from = "totals", field = "bidOnly", format = "share", only = "listings" },
			{ label = L.SUM_WITH_BIDS, from = "totals", field = "withBids", format = "share", only = "listings" },
			{ label = L.SUM_STACKED, from = "totals", field = "stacked", format = "share", only = "listings" },
			{ label = L.SUM_SINGLE_LISTING, from = "totals", field = "singleListing", format = "number", only = "listings" },
			{ label = L.SUM_SINGLE_SELLER, from = "totals", field = "singleSeller", format = "number", only = "listings", hideZero = true },
			{ label = L.SUM_DEALS, from = "totals", field = "deals", format = "number", only = "listings" },
		},
	},
}

-- Breakdowns the derive step counts. Each becomes a block of lines in the Summary.
--   by      a key of the derive step's classifiers (analyze\derive.lua)
--   order   "key" keeps the natural order of the keys, "count" puts the largest first
--   top     keep only the N largest
--   only    as above
ns.SummaryGroups = {
	{ id = "quality", label = L.GROUP_QUALITY, by = "quality", order = "key" },
	{ id = "kind", label = L.GROUP_KIND, by = "kind", order = "count", only = "aggregated" },
	{ id = "linkType", label = L.GROUP_LINK, by = "linkType", order = "count", only = "listings" },
	{ id = "timeLeft", label = L.GROUP_TIME_LEFT, by = "timeLeft", order = "key", only = "listings" },
	{ id = "stack", label = L.GROUP_STACK, by = "stack", order = "key", only = "listings" },
	{ id = "sellers", label = L.GROUP_SELLERS, by = "owner", order = "count", only = "listings", top = 10 },
}

-- Stack size buckets for the "By stack size" breakdown. Upper bounds, in order.
-- Anything larger lands in one last bucket.
ns.StackBuckets = { 1, 5, 10, 20, 100, 200 }

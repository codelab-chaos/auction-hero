-- Sources: the ways to download the auction feed, as data.
-- The code that talks to the server lives in feed\<id>.lua and registers itself
-- in ns.Fetchers under the same id.
--
--   schema            which entry of ns.Schemas its rows follow
--   cooldownSeconds   reported server cooldown, shown as a hint only
--   timeoutSeconds    how long to wait for the server before giving up
--   retrySeconds      wait between passes over rows whose data had not arrived
--   retryPasses       how many such passes, for sources that count them
--   settleSeconds     stop waiting once the server has sent nothing for this long
--   resolveSeconds    never wait longer than this for missing row data
--   resolveMinRows    a pass must fill in at least this many rows...
--   resolveMinShare   ...or this share of what is still missing, to count as
--                     progress worth waiting on. On a real scan about 7,000
--                     rows never fill in, and a few stragglers per pass kept
--                     the wait going to the full limit
--   commodityPasses   how many times to ask again whether items are commodities
--   variantBy         what tells two variants of one item id apart ("of the Bear"
--                     and "of the Owl"): the listing part to add to the item key
--   aggregated        true when a row is already one item, not one auction
--   priceIsPerStack   true when the buyout covers the whole stack
--   listing           which schema field feeds each part of a listing.
--                     This is the only place the derive step learns field names.
local _, ns = ...
local L = ns.L

ns.Sources = {
	{
		id = "replicate",
		label = L.SOURCE_REPLICATE,
		tip = L.SOURCE_REPLICATE_TIP,
		schema = "replicate",
		cooldownSeconds = 900,
		timeoutSeconds = 45,
		retrySeconds = 1.5,
		settleSeconds = 6,
		resolveSeconds = 120,
		resolveMinRows = 25,
		resolveMinShare = 0.01,
		commodityPasses = 4,
		aggregated = false,
		priceIsPerStack = true, -- confirmed on a real scan, 2026-11-12
		-- Links carry no suffix id on Forever. Variants differ by bonus ids, and
		-- the name is the readable form of that difference.
		variantBy = "name",
		listing = {
			itemID = "itemID",
			name = "name",
			quality = "qualityID",
			quantity = "count",
			buyout = "buyoutPrice",
			minBid = "minBid",
			bid = "bidAmount",
			-- No owner: the full scan never returns seller or bidder names.
			timeLeft = "timeLeft",
			link = "link",
			icon = "texture",
			level = "level",
			levelType = "levelType",
		},
	},
	{
		id = "browse",
		label = L.SOURCE_BROWSE,
		tip = L.SOURCE_BROWSE_TIP,
		schema = "browse",
		timeoutSeconds = 20,
		retryPasses = 4,
		retrySeconds = 1.5,
		aggregated = true,
		priceIsPerStack = false,
		variantBy = "suffix",
		listing = {
			itemID = "itemID",
			suffix = "itemSuffix",
			name = "name",
			quality = "quality",
			quantity = "totalQuantity",
			buyout = "minPrice",
			isCommodity = "isCommodity",
			isEquipment = "isEquipment",
			isPet = "isPet",
		},
	},
}

ns.SourceById = {}
for _, source in ipairs(ns.Sources) do
	ns.SourceById[source.id] = source
end

-- feed\<id>.lua files add their fetch function here.
ns.Fetchers = {}

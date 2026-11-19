-- The kinds of request sent to the auction house, as data. trade\requests.lua
-- sends them one at a time and decides, from this table, when each is answered.
--
-- A kind:
--   answers   events that answer it, each with how to tell the answer is to
--             this request and not another: "any", "itemKey" (the event's
--             item key has the request's itemID) or "itemID" or "auctionID"
--             (the event's first value is the request's)
--   errors    events that report a problem with it. A problem is not yet the
--             end: errorSettle seconds later it is, unless an answer came.
--   rereads   events after which results already in hand are read again
--             (item names arriving), without a new request
--   timeout   seconds without an answer before it ends unanswered
--   settle    seconds an answer must stay quiet before it is read. An answer
--             can come in several parts; reading the first part reads half.
--   search    true when it replaces the search results the game holds
--   press     true when the game only takes it as part of the player's press
local _, ns = ...

ns.RequestKinds = {
	browse = {
		answers = { AUCTION_HOUSE_BROWSE_RESULTS_UPDATED = "any", AUCTION_HOUSE_BROWSE_RESULTS_ADDED = "any" },
		errors = { AUCTION_HOUSE_BROWSE_FAILURE = true },
		rereads = { ITEM_KEY_ITEM_INFO_RECEIVED = true },
		timeout = 10,
		settle = 0.1,
		errorSettle = 0,
		search = true,
	},
	-- Forever answers an item search with AUCTION_HOUSE_NEW_RESULTS_RECEIVED
	-- and the item's key, where other clients send ITEM_SEARCH_RESULTS_UPDATED.
	itemSearch = {
		answers = {
			AUCTION_HOUSE_NEW_RESULTS_RECEIVED = "itemKey",
			ITEM_SEARCH_RESULTS_UPDATED = "itemKey",
			ITEM_SEARCH_RESULTS_ADDED = "itemKey",
		},
		timeout = 10,
		settle = 0.1,
		search = true,
	},
	commoditySearch = {
		answers = {
			AUCTION_HOUSE_NEW_RESULTS_RECEIVED = "itemKey",
			COMMODITY_SEARCH_RESULTS_UPDATED = "itemID",
			COMMODITY_SEARCH_RESULTS_ADDED = "itemID",
		},
		timeout = 10,
		settle = 0.1,
		search = true,
	},
	-- Buying one auction outright. Forever reports error 10 on purchases that
	-- then go through, so a problem waits a moment for the purchase to land.
	bid = {
		answers = { AUCTION_HOUSE_PURCHASE_COMPLETED = "auctionID" },
		errors = { AUCTION_HOUSE_SHOW_ERROR = true },
		timeout = 15,
		settle = 0,
		errorSettle = 3,
		press = true,
	},
}

ns.RequestRules = {
	-- Quiet time after one request ends before the next is sent, so the game's
	-- own follow-up messages (it asks for the bids list after a purchase) are
	-- not crossed by ours. In seconds.
	gapSeconds = 0.25,
}

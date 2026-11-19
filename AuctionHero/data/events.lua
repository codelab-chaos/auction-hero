-- The auction house events the log records, as data.
-- An event the client does not know is skipped, so this list can run ahead of a build.
local _, ns = ...

ns.LoggedEvents = {
	-- The game refusing something an addon tried to do.
	"ADDON_ACTION_BLOCKED",
	"ADDON_ACTION_FORBIDDEN",
	"UI_ERROR_MESSAGE",
	"AUCTION_HOUSE_SHOW",
	"AUCTION_HOUSE_CLOSED",
	"AUCTION_HOUSE_DISABLED",
	"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
	"AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
	"AUCTION_HOUSE_BROWSE_FAILURE",
	"AUCTION_HOUSE_NEW_RESULTS_RECEIVED",
	"ITEM_SEARCH_RESULTS_UPDATED",
	"ITEM_SEARCH_RESULTS_ADDED",
	"COMMODITY_SEARCH_RESULTS_UPDATED",
	"COMMODITY_SEARCH_RESULTS_ADDED",
	"COMMODITY_SEARCH_RESULTS_RECEIVED",
	"COMMODITY_PRICE_UPDATED",
	"COMMODITY_PRICE_UNAVAILABLE",
	"COMMODITY_PURCHASED",
	"COMMODITY_PURCHASE_SUCCEEDED",
	"COMMODITY_PURCHASE_FAILED",
	"ITEM_PURCHASED",
	"REPLICATE_ITEM_LIST_UPDATE",
	"OWNED_AUCTIONS_UPDATED",
	"BIDS_UPDATED",
	"BID_ADDED",
	"AUCTION_CANCELED",
	"AUCTION_HOUSE_AUCTION_CREATED",
	"AUCTION_HOUSE_AUCTIONS_EXPIRED",
	"AUCTION_HOUSE_PURCHASE_COMPLETED",
	"AUCTION_HOUSE_NEW_BID_RECEIVED",
	"AUCTION_HOUSE_POST_ERROR",
	"AUCTION_HOUSE_POST_WARNING",
	"AUCTION_HOUSE_SHOW_ERROR",
	"AUCTION_HOUSE_SHOW_NOTIFICATION",
	"AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION",
	"AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION",
	"AUCTION_HOUSE_ITEM_DELIVERY_DELAY_UPDATE",
	"AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_SENT",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
	"AUCTION_MULTISELL_START",
	"AUCTION_MULTISELL_UPDATE",
	"AUCTION_MULTISELL_FAILURE",
	"AUCTION_HOUSE_SCRIPT_DEPRECATED",
	"AUCTION_HOUSE_FAVORITES_UPDATED",
	-- The mailbox: what the game says while mail is read and taken.
	"MAIL_SHOW",
	"MAIL_CLOSED",
	"MAIL_INBOX_UPDATE",
	"MAIL_FAILED",
	"MAIL_SUCCESS",
	"CLOSE_INBOX_ITEM",
	-- Some errors reach the player only as a line in chat.
	"CHAT_MSG_SYSTEM",
}

-- Requests to the server the log records, whoever makes them: this addon,
-- the game's own windows or another addon. Each line says which, so two
-- windows asking at once can be told apart. A name the client does not have
-- is skipped.
ns.LoggedCalls = {
	C_AuctionHouse = {
		"SendBrowseQuery", "RequestMoreBrowseResults", "SendSearchQuery", "SendSellSearchQuery",
		"RequestMoreItemSearchResults", "RequestMoreCommoditySearchResults", "RefreshItemSearchResults",
		"RefreshCommoditySearchResults", "PlaceBid", "StartCommoditiesPurchase", "ConfirmCommoditiesPurchase",
		"CancelCommoditiesPurchase", "QueryOwnedAuctions", "QueryBids", "CancelAuction", "ReplicateItems",
		"PostItem", "PostCommodity", "ConfirmPostItem", "ConfirmPostCommodity", "SearchForFavorites",
	},
	C_Mail = { "SetOpeningAll" },
	_G = {
		"CheckInbox", "GetInboxText", "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem",
		"DeleteInboxItem", "ReturnInboxItem",
	},
}

-- The game's pop-ups, by name, as they show.
ns.LogPopups = true

-- Events that fire once per item while data loads. Logged as a running count
-- on one line instead of one line each.
ns.LoggedEventsCollapsed = {
	REPLICATE_ITEM_LIST_UPDATE = true,
	AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED = true,
	AUCTION_HOUSE_THROTTLED_MESSAGE_SENT = true,
	AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED = true,
	AUCTION_HOUSE_THROTTLED_SYSTEM_READY = true,
	-- Fires in bursts of dozens, which pushed everything else out of the log.
	AUCTION_CANCELED = true,
	MAIL_INBOX_UPDATE = true,
}

ns.LogLimit = 600

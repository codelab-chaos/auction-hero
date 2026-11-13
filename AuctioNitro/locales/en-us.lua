-- Display strings only, so data files stay language-free.
local _, ns = ...

ns.L = {
	TITLE = "AuctioNitro",

	-- Views (tabs)
	VIEW_SUMMARY = "Summary",
	VIEW_MODEL = "Model",
	VIEW_ITEMS = "Items",
	VIEW_ROWS = "Rows",
	VIEW_LOG = "Log",

	-- Sources
	SOURCE_REPLICATE = "Full scan",
	SOURCE_REPLICATE_TIP = "Asks the server for every auction (ReplicateItems). One row per auction. Reported to be limited to once every 15 minutes.",
	SOURCE_BROWSE = "Browse sweep",
	SOURCE_BROWSE_TIP = "Pages through an empty browse search. One row per item with its lowest price and total quantity. No cooldown, but less detail.",
	SOURCE_NEEDS_AH = "Open the auction house first.",
	SOURCE_COOLDOWN = "Last run %s ago. The reported cooldown is %s.",

	-- Download status
	STATUS_IDLE = "Open the auction house and pick a download.",
	STATUS_IDLE_OPEN = "Ready. Pick a download.",
	STATUS_WAITING = "%s: waiting for the server...",
	STATUS_READING = "%s: reading %s of %s",
	STATUS_READING_OPEN = "%s: %s read so far",
	STATUS_RESOLVING = "%s: waiting on item data for %s rows (pass %d)",
	STATUS_DONE = "%s: %s rows in %s",
	STATUS_FAILED = "%s failed: %s",
	STATUS_ANALYZING = "Analyzing %s rows...",
	CANCEL = "Cancel",
	CLEAR = "Clear",

	-- Failure reasons
	FAIL_CANCELLED = "cancelled",
	FAIL_TIMEOUT = "no answer from the server. It may be on cooldown.",
	FAIL_CLOSED = "the auction house closed",
	FAIL_BUSY = "a download is already running",
	FAIL_BROWSE = "the server rejected the browse search",
	FAIL_EMPTY = "the server returned no auctions",
	FAIL_ERROR = "an addon error, see chat",

	-- Panel
	SEARCH = "Filter",
	EMPTY_NO_SNAPSHOT = "No snapshot yet. Open the auction house and pick a download.",
	EMPTY_NO_MATCH = "Nothing matches the filter.",
	EMPTY_LOG = "No auction house events seen yet.",
	EMPTY_ANALYZING = "Analyzing...",
	INFO_ROWS = "%s shown",
	INFO_ROWS_CAPPED = "%s of %s shown. Filter to narrow it down.",
	INFO_ROWS_FOR = "%s rows for %s",
	FOOTER_NONE = "No snapshot",
	FOOTER_SNAPSHOT = "%s, %s rows, %s",
	FOOTER_STALE = " (older data, the server did not answer)",
	FOOTER_ON_DISK = "|cff40d040saved on disk|r",
	FOOTER_IN_MEMORY = "|cffffd100in memory, not on disk yet|r",
	FOOTER_NEVER = "|cffff6060in memory only, saving rows is off|r",
	SAVE_NOW = "Save to disk",
	SAVE_NOW_TIP = "The game only writes addon data on a reload, logout or exit. This reloads the UI so the download is written now.",
	SWITCH_TO = "View %s",
	SWITCH_TIP = "Both downloads are cached. This switches which one the tabs show.",
	TIP_ITEM_CLICK = "Click to see this item's rows.",
	SHOW_ALL = "All rows",

	-- Column headers
	COL_LABEL = "What",
	COL_VALUE = "Value",
	COL_INDEX = "#",
	COL_FIELD = "Field",
	COL_TYPES = "Types seen",
	COL_FILLED = "Filled",
	COL_VALUES = "Values",
	COL_ITEM = "Item",
	COL_LISTINGS = "Listings",
	COL_UNITS = "Units",
	COL_SELLERS = "Sellers",
	COL_MIN = "Lowest",
	COL_MEDIAN = "Median",
	COL_MAX = "Highest",
	COL_DEAL = "Below median",
	COL_ID = "ID",
	COL_COUNT = "Count",
	COL_BUYOUT = "Buyout",
	COL_UNIT = "Per unit",
	COL_MIN_BID = "Min bid",
	COL_BID = "Bid",
	COL_OWNER = "Owner",
	COL_TIME_LEFT = "Time",
	COL_LEVEL = "Lvl",
	COL_TIME = "Time",
	COL_EVENT = "Event",
	COL_DETAIL = "Payload",
	COL_LEVEL_REQ = "Req",
	COL_KIND = "Kind",

	-- Summary rows
	SUM_SECTION_SNAPSHOT = "Snapshot",
	SUM_SECTION_MARKET = "Market",
	SUM_SOURCE = "Source",
	SUM_CAPTURED = "Captured",
	SUM_ELAPSED = "Download time",
	SUM_REALM = "Realm and faction",
	SUM_BUILD = "Client build",
	SUM_ROWS = "Rows",
	SUM_RETURNS = "Values per row from the API",
	SUM_RETURNS_MISMATCH = "%d (expected %d, the schema needs updating)",
	SUM_INCOMPLETE = "Rows still missing item data",
	SUM_ITEMS = "Distinct items",
	SUM_UNITS = "Total units for sale",
	SUM_SELLERS = "Distinct sellers",
	SUM_WITH_BUYOUT = "Rows with a buyout",
	SUM_BID_ONLY = "Bid-only rows",
	SUM_WITH_BIDS = "Rows that have a bid",
	SUM_VALUE = "Total buyout value",
	SUM_SINGLE_SELLER = "Items with one seller",
	SUM_SINGLE_LISTING = "Items with one listing",
	SUM_DEALS = "Items whose lowest price is 30%+ under their median",
	SUM_STACKED = "Rows with more than one unit",
	SUM_PRICE_NOTE = "Price assumption",
	SUM_PRICE_PER_STACK = "buyout is for the whole stack",
	SUM_PRICE_PER_UNIT = "price is already per unit",
	GROUP_QUALITY = "By quality",
	GROUP_TIME_LEFT = "By time left",
	GROUP_STACK = "By stack size",
	GROUP_SELLERS = "Top sellers by rows",
	GROUP_KIND = "By kind",
	GROUP_LINK = "By link type",
	KIND_COMMODITY = "Commodity",
	KIND_EQUIPMENT = "Equipment",
	KIND_PET = "Pet",
	KIND_OTHER = "Other item",
	UNKNOWN = "Unknown",
	NONE = "none",
	YES = "yes",
	NO = "no",
	TIME_BAND = "Band %s",
	MANY = "%d+ distinct",
	DISTINCT = "%d distinct",
	EXAMPLES = "e.g. %s",
	RANGE = "%s to %s",

	-- Settings
	SETTING_PERSIST_ROWS = "Keep the raw rows in saved variables",
	SETTING_PERSIST_ROWS_TIP = "Saves the whole scan, not only the price history, so it can be read from the saved variables file. Off by default: a full scan is about 40 MB and slows logging in and out.",
	SETTING_OPEN_WITH_AH = "Open with the auction house",
	SETTING_OPEN_WITH_AH_TIP = "Shows this window whenever the auction house opens.",
	SETTING_LOG_EVENTS = "Record auction house events",
	SETTING_LOG_EVENTS_TIP = "Keeps a log of the auction house events the client fires, with their payloads.",
	ON = "on",
	OFF = "off",

	-- Commands
	CMD_HELP = "Commands:",
	CMD_HELP_TOGGLE = "/an  show or hide the window",
	CMD_HELP_SCAN = "/an scan | browse | cancel  start or stop a download; /an data  open the scan inspector",
	CMD_HELP_CLEAR = "/an clear log  empty the event log",
	CMD_HELP_SET = "/an set [name] [on|off]  list or flip a switch",
	CMD_CLEARED = "Snapshot and log cleared.",
	CMD_SET_LINE = "%s: %s  (%s)",
	CMD_SET_UNKNOWN = "No switch called %s.",
}

-- ========= The trading window ==============================================
local L = ns.L

L.WIN_SCAN = "Scan"
L.WIN_SCAN_TIP = "Download every auction. Reported to be limited to once every 15 minutes."
L.WIN_DEBUG = "Data"
L.WIN_DEBUG_TIP = "The raw scan views: summary, row model, items, rows and the event log."
L.WIN_NO_SCAN = "No scan yet. Open the auction house and press Scan."
L.WIN_SCAN_AGE = "Scanned %s ago, %s auctions, %s scans remembered"
L.WIN_SCAN_AGE_ONE = "Scanned %s ago, %s auctions, 1 scan remembered"
L.WIN_YOUR_GOLD = "Your gold %s"
L.TAB_SELL = "Sell"

-- Sell tab
L.SELL_BAGS = "Your bags"
L.SELL_BAGS_EMPTY = "Nothing in your bags can be auctioned."
L.SELL_PICK = "Pick something from your bags."
L.SELL_HAVE = "You have %s"
L.SELL_HAVE_STACKS = "You have %s in %d stacks"
L.SELL_SALE = "Sale"
L.SELL_PRICE_EACH = "Price each"
L.SELL_BID_EACH = "Starting bid each"
L.SELL_STARTING_BID = "Starting bid"
L.SELL_EACH = "each"
L.SELL_QUANTITY = "Quantity"
L.SELL_EACH_AUCTION = "Each auction"
L.SELL_AUCTIONS = "Auctions"
L.SELL_DURATION = "Duration"
L.SELL_OF = "of %s"
L.SELL_ALL = "All"
L.SELL_POSTING = "Posting %s of %s"
L.SELL_KEEPING = ", keeping %s"
L.SELL_EACH_AUCTION_PRICE = "each auction %s"
L.SELL_BUYOUT = "Buyout"
L.SELL_ALL_BUYOUTS = "All buyouts"
L.SELL_BID = "Starting bid"
L.SELL_ALL_BIDS = "All starting bids"
L.SELL_RECEIVE = "You receive if all sell, after the %d%% cut"
L.SELL_RECEIVE_BIDS = "You receive at least, after the %d%% cut"
L.SELL_RECEIVE_TIP = "Assumes the auction house keeps this share. The deposit is not included."
L.SELL_BID_TOO_HIGH = "The starting bid has to be under the buy now price."
L.SELL_NO_PRICE = "Nobody is selling this, so there is no price to go by. Type one."
L.SELL_POST = "Post auction"
L.SELL_POST_MANY = "Post %s auctions"
L.SELL_POST_TIP = "Posting is not wired up yet. This screen is read-only for now."
L.SELL_COMPETITION = "The competition"
L.SELL_COMPETITION_KEY = "auctions x units each"
L.SELL_YOU = "You: %s x %s"
L.SELL_YOU_UNITS = "You: %s"
L.SELL_LADDER_ROW = "%s x %s"
L.SELL_CHEAPEST = "You would be the cheapest."
L.SELL_AHEAD = "%s units sell before yours."
L.SELL_MARKET = "%s auctions, usual price %s"
L.SELL_NOT_LISTED = "Nobody else is selling this."

-- Sale types
L.SALE_BUYOUT = "Buy now"
L.SALE_BUYOUT_TIP = "A set price. The first buyer to pay it gets the item at once. What nearly everyone uses."
L.SALE_BOTH = "Buy now + bids"
L.SALE_BOTH_TIP = "A buy now price, and a lower starting bid. If nobody pays the buy now price, the highest bidder wins when the time runs out."
L.SALE_BIDS = "Bids only"
L.SALE_BIDS_TIP = "No buy now price. The highest bidder wins when the time runs out, so it never sells at once."

-- Durations
L.DURATION_SHORT = "Short"
L.DURATION_SHORT_TIP = "The shortest listing. The lowest deposit."
L.DURATION_MEDIUM = "Medium"
L.DURATION_MEDIUM_TIP = "The middle listing length."
L.DURATION_LONG = "Long"
L.DURATION_LONG_TIP = "The longest listing, and the usual choice: the most time to sell."

-- Price rules
L.RULE_MATCH = "Match"
L.RULE_MATCH_TIP = "The same price as the cheapest auction. Yours sells after it does."
L.RULE_UNDERCUT = "Undercut"
L.RULE_UNDERCUT_TIP = "1 copper under the cheapest auction. First in line, for almost nothing."
L.RULE_QUICK = "Quick sale"
L.RULE_QUICK_TIP = "5% under the cheapest auction. Still the cheapest after someone undercuts you by a copper."
L.RULE_SKIP = "Skip lowballs"
L.RULE_SKIP_TIP = "Ignores stray auctions under half the usual price, then goes 1 copper under the first real one."
L.RULE_USUAL = "Usual price"
L.RULE_USUAL_TIP = "The price most units are listed around. Slow, for when you can wait."

-- Price confidence
L.CONFIDENCE = "Price confidence"
L.CONFIDENCE_NONE = "No price"
L.CONFIDENCE_LOW = "Low"
L.CONFIDENCE_FAIR = "Fair"
L.CONFIDENCE_GOOD = "Good"
L.CONFIDENCE_HIGH = "High"
L.CONFIDENCE_FACTS = "auctions: %s | %s usual | scans: %s | sales: %s"
L.CONFIDENCE_NO_SHARE = "0%"
L.REASON_NONE_FOR_SALE = "None for sale, so no price to go by"
L.REASON_ONE_AUCTION = "Only 1 auction"
L.REASON_AUCTIONS = "%s auctions"
L.REASON_SCATTERED = "Prices scattered: %d%% near usual"
L.REASON_NEAR_USUAL = "%d%% priced near usual"
L.REASON_ONE_SCAN = "Seen in 1 scan: more scans raise confidence"
L.REASON_SCANS = "Seen in %s scans over %s days"
L.REASON_NO_SALES = "Listings, not sales"

-- ========= Window, Buy, Resell and Debug ===================================
L.TAB_BUY = "Buy"
L.TAB_RESELL = "Resell"
L.TAB_DEBUG = "Debug"
L.WIN_SCAN_BUSY = "Scanning..."
L.WIN_NEEDS_SCAN = "No scan yet. Open the auction house and press Scan."
L.WIN_ANALYZING = "Reading the scan..."
L.WIN_NO_MARKET = "This needs a full scan. Open the auction house and press Scan."
L.SETTING_DEBUG = "Show the Debug tab"
L.SETTING_DEBUG_TIP = "Adds a tab with the raw scan views and the event log."
L.CMD_HELP_DEBUG = "/an debug  show or hide the Debug tab"
L.CMD_DEBUG_ON = "Debug tab on."
L.CMD_DEBUG_OFF = "Debug tab off."

-- Buy tab
L.BUY_SEARCH = "Search"
L.BUY_CAN_USE = "I can use"
L.BUY_CAN_AFFORD = "I can afford"
L.BUY_DEALS = "Deals"
L.BUY_COL_ITEM = "Item"
L.BUY_COL_LEVEL = "Lvl"
L.BUY_COL_AVAILABLE = "Avail"
L.BUY_COL_PRICE = "Price"
L.BUY_NOTHING = "Nothing matches."
L.BUY_PICK = "Pick an item to see what buying it takes."
L.BUY_AVAILABLE = "%s available"
L.BUY_QUANTITY = "Quantity"
L.BUY_TOTAL = "Total"
L.BUY_AVERAGE = "Average each"
L.BUY_DEAL = "Deal"
L.BUY_SAVE = "You save"
L.BUY_EXTRA = "You pay extra"
L.BUY_GET_MORE = "You get %s: stacks cannot be split."
L.BUY_SHORT = "Only %s are for sale."
L.BUY_OVER_BUDGET = "More than your gold."
L.BUY_LINE_UNITS = "%s units"
L.BUY_LINE_STACKS = "%s x stack of %s"
L.BUY_MORE_LINES = "and %d more price points"
L.BUY_BUTTON = "Buy %s"
L.BUY_BY_UNIT = "Bought by the unit: one purchase, cheapest sellers first."
L.BUY_ONE_AUCTION = "One auction, one purchase."
L.BUY_AUCTIONS = "%s auctions. The game sells one per press, so this is %s purchases."
L.BUY_NOT_WIRED = "Buying is not wired up yet. This screen is read-only for now."
L.CLEAR_ALL = "Clear all"
L.EACH = "%s each"

-- Deal meter
L.DEAL_OVER = "Overpriced"
L.DEAL_FAIR = "Fair"
L.DEAL_GREAT = "Great to buy"
L.DEAL_CONFIDENT = "Confident deal"
L.DEAL_RESELL = "Snag to resell"
L.DEAL_UNKNOWN = "Too few auctions to know what this usually goes for."
L.DEAL_AT_USUAL = "Right at the usual price of %s."
L.DEAL_UNDER = "%d%% under the usual price of %s."
L.DEAL_ABOVE = "%d%% over the usual price of %s."
L.DEAL_CHECK = "Not many auctions behind that usual price, so check it."

-- Categories and filters
L.CAT_WEAPONS = "Weapons"
L.CAT_ARMOR = "Armor"
L.CAT_ACCESSORIES = "Accessories"
L.CAT_CONTAINERS = "Containers"
L.CAT_CONSUMABLES = "Consumables"
L.CAT_TRADE_GOODS = "Trade Goods"
L.CAT_RECIPES = "Recipes"
L.CAT_MISC = "Miscellaneous"
L.CAT_PROJECTILE = "Projectile"
L.CAT_QUEST = "Quest Items"
L.CAT_OTHER = "Other"
L.BOX_SWORDS = "Swords"
L.BOX_AXES = "Axes"
L.BOX_MACES = "Maces"
L.BOX_CLOTH = "Cloth"
L.BOX_LEATHER = "Leather"
L.BOX_MAIL = "Mail"
L.BOX_PLATE = "Plate"
L.BOX_CLOAKS = "Cloaks"
L.BOX_NECK = "Neck"
L.BOX_FINGER = "Finger"
L.BOX_TRINKET = "Trinket"
L.BOX_OFF_HAND = "Off-hand"
L.BOX_SHIELD = "Shield"
L.BOX_SHIRT = "Shirt"
L.BOX_TABARD = "Tabard"
L.BOX_RELICS = "Relics"
L.FACET_QUALITY = "Quality"
L.RAIL_TIP = "%s: %s"
L.HAND_ONE = "One-hand"
L.HAND_TWO = "Two-hand"
L.SLOT_HEAD = "Head"
L.SLOT_SHOULDER = "Shoulder"
L.SLOT_CHEST = "Chest"
L.SLOT_WAIST = "Waist"
L.SLOT_LEGS = "Legs"
L.SLOT_FEET = "Feet"
L.SLOT_WRIST = "Wrist"
L.SLOT_HANDS = "Hands"

-- Resell tab
L.RESELL_DISCOUNT = "Discount"
L.RESELL_DISCOUNT_TIP = "Only buy auctions at least %d%% under the usual price."
L.RESELL_MIN_PROFIT = "Min profit"
L.RESELL_MIN_PROFIT_TIP = "Hide leads that would make less than this."
L.RESELL_AFFORD = "I can afford"
L.RESELL_AFFORD_TIP = "Only loads your gold can buy out in full."
L.RESELL_TOP = "Top deals"
L.RESELL_TOP_TIP = "Only five-pip deals: a big discount on a price many sellers agree on."
L.RESELL_COL_DEAL = "Deal"
L.RESELL_COL_BUY = "Buy"
L.RESELL_COL_COST = "Cost"
L.RESELL_COL_PROFIT = "Profit"
L.RESELL_NOTHING = "Nothing worth flipping with these settings."
L.RESELL_PICK = "Pick an item to see the plan: what to buy, what to relist it at, and what you keep."
L.RESELL_FOR_SALE = "%s for sale in %s auctions"
L.RESELL_STEP_BUY = "Buy"
L.RESELL_STEP_RELIST = "Relist"
L.RESELL_STEP_KEEP = "Keep"
L.RESELL_AUCTIONS = "Auctions"
L.RESELL_UNITS = "Units"
L.RESELL_BUY_ONE = "Buy this auction"
L.RESELL_BUY_NEXT = "Buy auction 1 of %s"
L.RESELL_BUY_UNITS = "Buy %s"
L.RESELL_NEXT = "stack of %s at %s each"
L.RESELL_AVERAGE = "%s units, average each"
L.RESELL_COST = "Cost"
L.RESELL_USUAL = "At the usual price, each"
L.RESELL_RETURN = "If all sell, less the %d%% cut"
L.RESELL_PROFIT = "Profit"
L.RESELL_ROI = "Return on what you spend"
L.RESELL_CLEAR = "Nothing else is listed at or under the usual price once you buy."
L.RESELL_COMPETITION = "%s units stay listed at or under the usual price."
L.RESELL_THE_AUCTIONS = "The auctions"

-- Debug tab
L.DEBUG_FULL_SCAN = "Full scan"
L.DEBUG_BROWSE = "Browse sweep"
L.DEBUG_CLEAR_LOG = "Clear log"
L.DEBUG_CONFIRM = "Press again"
L.CMD_CLEARED_LOG = "The event log was cleared."
L.CMD_CLEAR_HOW = "/an clear log  empties the event log. Scans and the price history are never cleared."
L.DEBUG_FILTER = "Filter"

-- Price history length
L.CMD_HISTORY = "Each item keeps %d days of prices for its graph. /an history <days> changes it (%d to %d)."
L.CMD_HELP_HISTORY = "/an history [days]  how many days of prices each item keeps"

-- Posting
L.SELL_DEPOSIT = "Deposit"
L.SELL_CONFIRM = "Confirm post"
L.SELL_POSTING_NOW = "Posting..."
L.POST_NEEDS_AH = "Open the auction house first."
L.POST_SCANNING = "Wait for the scan to finish."
L.POST_BUSY = "The auction house is busy. Try again in a moment."
L.POST_NOT_IN_BAGS = "That item is not in your bags any more."
L.POST_NOT_SELLABLE = "The auction house will not take that item."
L.POST_SENDING = "Posting..."
L.POST_CONFIRM = "The game wants this confirmed. Check the price, then press Confirm post."
L.POST_DONE = "Posted."
L.POST_DONE_MANY = "Posted %s auctions."
L.POST_PROGRESS = "Posted %s of %s..."
L.POST_STOPPED = "Posting stopped before it finished. Check your auctions."
L.POST_REFUSED = "The auction house refused the post."
L.POST_ERROR = "The auction house refused: %s."
L.POST_NO_ANSWER = "The auction house did not answer, and the item is still in your bags. It was not posted."
L.POST_BLOCKED = "The game blocked the addon from posting (%s)."

-- Auctions tab
L.TAB_AUCTIONS = "Auctions"
L.AUCTIONS_SUMMARY = "%s for sale, %s sold. Buyouts for sale: %s"
L.AUCTIONS_REFRESH = "Refresh"
L.AUCTIONS_REFRESH_TIP = "Ask the auction house for your auctions again."
L.AUCTIONS_NONE = "You have no auctions."
L.AUCTIONS_NEEDS_AH = "Open the auction house to see your auctions."
L.AUCTIONS_COL_QUANTITY = "Qty"
L.AUCTIONS_COL_BID = "Bid"
L.AUCTIONS_COL_TIME = "Time left"
L.AUCTIONS_COL_STATUS = "Status"
L.AUCTIONS_ACTIVE = "For sale"
L.AUCTIONS_SOLD = "Sold"
L.POST_FORBIDDEN = "The game does not let addons post (%s)."
L.CMD_POST_NOTHING = "Open the Sell tab and pick an item with a price first."
L.RESELL_MAX_BUY = "Max items"
L.RESELL_MAX_BUY_TIP = "Only show items with this many or fewer for sale in all. Stackable items count by the stack: 100 that stack to 20 count as 5. Reselling means buying them all, then relisting."

-- History tab
L.TAB_HISTORY = "History"
L.HISTORY_PICK = "Pick an item to see how its price has moved."
L.HISTORY_ONE_DAY = "Seen on one day so far. A second day of scans starts the graph."
L.HISTORY_NOW = "%s for sale now"
L.HISTORY_DAYS = "%dd"
L.HISTORY_USUAL = "Usual now"
L.HISTORY_LOWEST = "Lowest seen"
L.HISTORY_HIGHEST = "Highest usual"
L.HISTORY_CHANGE = "Change"
L.HISTORY_SEEN = "Days seen"
L.HISTORY_SEEN_OF = "%d of %d"
L.HISTORY_PRICE = "Price"
L.HISTORY_FOR_SALE = "For sale"
L.HISTORY_SERIES_USUAL = "Usual price"
L.HISTORY_SERIES_LOW = "Lowest price"
L.HISTORY_HOVER = "Hover a chart to read a day."
L.HISTORY_READOUT = "%s   usual %s   lowest %s   %s for sale"
L.HISTORY_COL_USUAL = "Usual"
L.HISTORY_COL_CHANGE = "Chg"

-- Copying text out of the game
L.COPY_HINT = "Ctrl+C copies the selected text. Escape closes."
L.COPY_SELECT = "Select all"
L.COPY_CLOSE = "Close"
L.DEBUG_COPY_LOG = "Copy log"
L.DEBUG_COPY_LOG_TIP = "Opens the whole event log as text, selected and ready for Ctrl+C."
L.DEBUG_COPY_TITLE = "Event log, %d lines"
L.RESELL_COL_FOR_SALE = "For sale"
L.POST_NOT_READY = "The game is still loading this item. Try again in a moment."
L.POST_NO_DEPOSIT = "You do not have enough gold for the deposit."
L.SELL_TOO_CHEAP = "The auction house does not take single items for less than %s."

-- Display strings only, so data files stay language-free.
local _, ns = ...

ns.L = {
	TITLE = "Auction Hero",

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
	COL_COPIES = "Auctions",
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
	SETTING_OPEN_WITH_AH = "Open with the auction house",
	SETTING_OPEN_WITH_AH_TIP = "Shows this window whenever the auction house opens.",
	SETTING_CLOSE_AH = "Close the auction house with this window",
	SETTING_CLOSE_AH_TIP = "Closing this window closes the auction house too. Not while a scan is running, so the scan is not lost.",
	SETTING_LOG_EVENTS = "Record auction house events",
	SETTING_LOG_EVENTS_TIP = "Keeps a log of the auction house events the client fires, with their payloads.",
	ON = "on",
	OFF = "off",

	-- Commands
	CMD_HELP = "Commands:",
	CMD_HELP_TOGGLE = "/ah  show or hide the window",
	CMD_HELP_SCAN = "/ah scan | browse | cancel  start or stop a download; /ah data  open the scan inspector",
	CMD_HELP_CLEAR = "/ah clear log  empty the event log",
	CMD_HELP_SET = "/ah set [name] [on|off]  list or flip a switch",
	CMD_CLEARED = "Snapshot and log cleared.",
	CMD_SET_LINE = "%s: %s  (%s)",
	CMD_SET_UNKNOWN = "No switch called %s.",
}

-- ========= The trading window ==============================================
local L = ns.L

L.WIN_SCAN = "Scan"
L.WIN_SCAN_TIP = "Download every auction. The server takes one full scan every 15 minutes, so the button waits that long after a scan."
L.WIN_DEBUG = "Data"
L.WIN_DEBUG_TIP = "The raw scan views: summary, row model, items, rows and the event log."
L.WIN_NO_SCAN = "No scan yet. Open the auction house and press Scan."
L.WIN_SCAN_AGE = "Scanned %s, %s auctions, %s scans remembered"
L.WIN_SCAN_AGE_ONE = "Scanned %s, %s auctions, 1 scan remembered"
L.WIN_REFRESHING = "Refreshing..."
L.WIN_YOUR_GOLD = "Your gold %s"
L.TAB_SELL = "Sell"

-- Sell tab
L.SELL_BAGS = "Your bags"
L.SELL_BAGS_OTHER = "Other"
L.SELL_BAGS_ITEM = "Item"
L.SELL_BAGS_COUNT = "Count"
L.SELL_BAGS_NONE_HERE = "Nothing of this kind in your bags."
L.SELL_FILTER_ALL = "All"
L.SELL_FILTER_GEAR = "Gear"
L.SELL_FILTER_GEAR_TIP = "Weapons and armor."
L.SELL_FILTER_TRADE = "Trade"
L.SELL_FILTER_TRADE_TIP = "Trade goods, reagents, gems and recipes."
L.SELL_FILTER_USE = "Take"
L.SELL_FILTER_USE_TIP = "Food, potions and other consumables, and ammunition."
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
L.CHANCE_LIKELY = "Likely to sell"
L.CHANCE_MAYBE = "Might sell"
L.CHANCE_UNLIKELY = "Unlikely to sell"
L.CHANCE_UNKNOWN = "Competition"
L.CHANCE_AHEAD = "%s listed at or under your price"
L.CHANCE_NONE_AHEAD = "nothing listed at or under your price"
L.CHANCE_RATE = "%s, about %s sell a day"
L.CHANCE_TIP_HEAD = "Competition"
L.CHANCE_TIP_AHEAD = "Units listed at or under your price: %s. Buyers take the cheapest first."
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
L.REASON_AUCTIONS = "%s auctions at %s different prices"
L.REASON_ONE_PRICE = "%s auctions, all at one price: likely one seller"
L.REASON_SCATTERED = "Prices scattered: %d%% near usual"
L.REASON_NEAR_USUAL = "%d%% priced near usual"
L.REASON_ONE_SCAN = "Seen in 1 scan: more scans raise confidence"
L.REASON_SCANS = "Seen in %s scans over %s days"
L.REASON_NO_SALES = "Listings, not sales"

-- ========= Window, Buy, Resell and Debug ===================================
L.TAB_BUY = "Buy"
L.TAB_RESELL = "Resell"
L.TAB_DEBUG = "Debug"
L.TAB_PROGRESS = "Progress"
L.WIN_SCAN_BUSY = "Scanning..."
L.WIN_NEEDS_SCAN = "No scan yet. Open the auction house and press Scan."
L.WIN_ANALYZING = "Reading the scan..."
L.WIN_ANALYSIS_FAILED = "Could not read the scan. See the Debug tab's log."
L.WIN_NO_MARKET = "This needs a full scan. Open the auction house and press Scan."
L.SETTING_DEBUG = "Show the Debug tab"
L.SETTING_DEBUG_TIP = "Adds a tab with the raw scan views and the event log."
L.CMD_HELP_DEBUG = "/ah debug  show or hide the Debug tab"
L.CMD_DEBUG_ON = "Debug tab on."
L.CMD_DEBUG_OFF = "Debug tab off."
L.CMD_DEV_ON = "Developer options on. Options now lists the Debug section."
L.CMD_DEV_OFF = "Developer options off."

-- Buy tab
L.BUY_SEARCH = "Search"
L.BUY_CAN_USE = "Use"
L.BUY_BETTER = "Better"
L.BUY_NEAR_LEVEL = "Near level"
L.BUY_SUGGESTED = "Picks"
L.BUY_COL_GAIN = "Gain"
L.BUY_GAIN_SLOTS = "+%d slots"
L.BUY_CAN_AFFORD = "Afford"
L.BUY_DEALS = "Deals"
L.BUY_COL_ITEM = "Item"
L.BUY_COL_LEVEL = "Lvl"
L.BUY_COL_AVAILABLE = "For sale"
L.BUY_COL_PRICE = "Price"
L.BUY_NOTHING = "Nothing matches."
L.BUY_PICK = "Pick an item to see what buying it takes."
L.BUY_INCOMING = "Already bought for this slot, in your mail: %s"
L.BUY_INCOMING_ITEM = "%s (%s, %s)"
L.BUY_INCOMING_TIP = "Gear you bought here that has not reached your bags yet. Weigh an upgrade against it too. It drops off this list once you take it from the mail."
L.BUY_INCOMING_ALL = "In your mail, bought here: %s"
L.BUY_INCOMING_SLOT = "%s (%s, %s)"
L.BUY_COL_INCOMING_TIP = "Marked: you already bought gear for this slot, and it is in your mail."
L.BUY_AVAILABLE = "%s for sale, at all prices"
L.BUY_QUANTITY = "Quantity"
L.BUY_STACKS_ONE = "1 stack"
L.BUY_STACKS_MANY = "%d stacks"
L.BUY_STACKS_TIP = "%s units. A stack of this item is %s, what one bag slot holds."
L.BUY_STACKS_SHORT = "Only %s are for sale."
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
L.BUY_PRESS_AGAIN = "Press again: %s"
L.BUY_BUTTON_ONE = "Buy 1 for %s"
L.BUY_BUTTON_MANY = "Buy %s for %s total"
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
L.DEAL_UNKNOWN = "Too few for sale to know what you would otherwise pay."
L.DEAL_AT_USUAL = "Right at the %s you would otherwise pay."
L.DEAL_UNDER = "%d%% under the %s you would otherwise pay."
L.DEAL_ABOVE = "%d%% over the %s you would otherwise pay."
L.DEAL_BASIS_TODAY = "Measured against today's listings, skipping the cheapest few. Past scans cannot back it yet."
L.DEAL_BASIS_HISTORY = "Measured against today's listings and what past scans show its lowest price usually is."
L.DEAL_ASKING = "These are asking prices, not what it has sold for."

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
L.HAND_RANGED = "Ranged"
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
L.CMD_CLEAR_HOW = "/ah clear log  empties the event log. Scans and the price history are never cleared."
L.DEBUG_FILTER = "Filter"

-- Price history length
L.CMD_HISTORY = "Each item keeps %d days of prices for its graph. /ah history <days> changes it (%d to %d)."
L.CMD_HELP_HISTORY = "/ah history [days]  how many days of prices each item keeps"

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
L.TAB_CRAFT = "Craft"
L.WIN_TAB_ERROR = "The %s tab hit an error and may be blank: %s. The full error is in the debug log."
L.CRAFT_ALL = "All"
L.CRAFT_PROFESSION_TIP = "Skill %d / %d. %d recipes known."
L.CRAFT_READY = "Ready to make"
L.CRAFT_READY_TIP = "Only recipes your bags and bank hold every material for."
L.CRAFT_COL_RECIPE = "Recipe"
L.CRAFT_COL_PROFESSION = "Profession"
L.CRAFT_COL_PROF = "Prof"
L.CRAFT_COL_SALE = "Sells for"
L.CRAFT_COL_COST = "Raw goods"
L.CRAFT_COL_PROFIT = "Profit"
L.CRAFT_COL_VS_MATS = "vs raw goods"
L.CRAFT_COL_VERDICT = "Verdict"
L.CRAFT_V_MAKE = "Make"
L.CRAFT_V_LEVEL = "Level · %s"
L.CRAFT_V_MAYBE = "Maybe level"
L.CRAFT_V_UNKNOWN = "?"
L.CRAFT_V_SELL = "Sell raw goods"
L.CRAFT_POINT_FREE = "free"
L.CRAFT_TIP_VERDICT = "Verdict: %s"
L.CRAFT_F_MAKE = "Worth making"
L.CRAFT_F_MAKE_TIP = "Crafting pays more than selling the raw goods."
L.CRAFT_F_LEVEL = "Levels me"
L.CRAFT_F_LEVEL_TIP = "Recipes that can still raise your skill, cheapest point first."
L.CRAFT_F_SELL = "Sell raw goods"
L.CRAFT_F_SELL_TIP = "Selling the raw goods pays more, and no skill-up is left."
L.CRAFT_TIP_MATH = "Sells for %s. The raw goods are worth %s at auction."
L.CRAFT_TIP_MAKE_WINS = "Making it earns %s more than selling them."
L.CRAFT_TIP_SELL_WINS = "Selling them earns %s more than making it."
L.CRAFT_SKILL_ALWAYS = "Always"
L.CRAFT_SKILL_LIKELY = "Likely"
L.CRAFT_SKILL_MAYBE = "Maybe"
L.CRAFT_SKILL_POINT_COST = "+%d for %s"
L.CRAFT_TIP_POINT_COST = "A sure skill-up: each point costs %s, what you give up by not selling the raw goods."
L.CRAFT_TIP_PROFIT = "Profit: the sale, less the raw goods you still have to buy. What you hold (skinned, gathered) counts as free."
L.CRAFT_TIP_VS_MATS = "vs raw goods: the sale, less what the raw goods cost at auction. Below zero, selling the raw goods pays more than crafting."
L.CRAFT_COL_CAN_MAKE = "Can make"
L.CRAFT_COL_TO_BUY = "To buy"
L.CRAFT_NO_PRICE = "?"
L.CRAFT_HAVE_ALL = "Have all"
L.CRAFT_TIP_REAGENT = "%d x %s: have %d, %s"
L.CRAFT_TIP_EACH = "%s each"
L.CRAFT_TIP_NO_PRICE = "no auction price (a vendor sells it?)"
L.CRAFT_TIP_ESTIMATED = "~ The sale price is from an older scan or a similar item."
L.CRAFT_SUMMARY = "Per craft, at today's lowest asking prices."
L.CRAFT_NO_SCAN = "Scan the auction house for prices."
L.CRAFT_EMPTY_BOOK = "Open each of your profession windows once. Auction Hero keeps the recipes you know."
L.CRAFT_EMPTY_READY = "Your bags and bank do not hold every material for any of these recipes."
L.CRAFT_EMPTY = "None of these recipes makes an item."
L.AUCTIONS_NAME_LOADING = "Loading item..."
L.AUCTIONS_SUMMARY = "%s for sale, %s sold. Buyouts for sale: %s"
L.AUCTIONS_REFRESH = "Refresh"
L.AUCTIONS_REFRESH_TIP = "Ask the auction house for your auctions again."
L.AUCTIONS_CANCEL = "Cancel auction"
L.AUCTIONS_CANCEL_TIP = "Pick one of your auctions in the list, then press this. It shows what cancelling costs; press again to cancel."
L.AUCTIONS_CANCEL_CONFIRM = "Confirm cancel"
L.AUCTIONS_CANCEL_CONFIRM_COST = "Confirm cancel, costs %s"
L.CANCEL_CONFIRM = "Press again to cancel this auction. Its deposit is not given back."
L.CANCEL_CONFIRM_COST = "Press again to cancel this auction. It costs the amount shown, and its deposit is not given back."
L.CANCEL_SENDING = "Cancelling..."
L.CANCEL_CHECKING = "No word from the auction house. Checking your auctions..."
L.CANCEL_DONE = "Auction cancelled. The item comes back by mail."
L.CANCEL_SOLD = "That auction has sold, so it cannot be cancelled."
L.CANCEL_NOT_ALLOWED = "The auction house will not cancel that auction."
L.CANCEL_OVER_GOLD = "You do not have the gold that cancelling costs."
L.CANCEL_NO_ANSWER = "The auction house did not answer. Press Refresh to see your auctions as they are."
L.CANCEL_NOT_DONE = "The auction is still up: it was not cancelled."
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
L.TAB_HISTORY = "Graphs"
L.HISTORY_PICK = "Pick an item to see how its price has moved."
L.HISTORY_NONE = "No scan has priced this item yet."
L.HISTORY_PRIMING = "%d points so far, all on one day. A new point is kept every 8 hours; the picture fills out over the next days."
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
L.HISTORY_HOVER = "Hover a chart to read a scan."
L.HISTORY_READOUT = "%s   usual %s   lowest %s   %s for sale"
L.HISTORY_COL_USUAL = "Usual"
L.HISTORY_COL_CHANGE = "Chg"
L.HISTORY_FILTER_UP = "Rising"
L.HISTORY_FILTER_DOWN = "Falling"

-- Copying text out of the game
L.WIN_EARLY_ACCESS = "Early Access  |  "
L.WIN_FEEDBACK = "feedback welcome"
L.WIN_FEEDBACK_TIP = "Auction Hero is early, and your feedback shapes it. Click for the address of its CurseForge page, to leave a comment or report a problem."
L.WIN_FEEDBACK_COPY = "Auction Hero on CurseForge"
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

-- The footer's list of recent actions
L.ACT_TITLE = "Recent activity"
L.ACT_NONE = "Nothing yet this session."
L.ACT_AN_ITEM = "an item"
L.ACT_SCAN_STARTED = "%s started"
L.ACT_SCAN_DONE = "Scan finished: %s auctions in %s"
L.ACT_SCAN_FAILED = "Scan failed: %s"
L.ACT_HISTORY = "Price history updated, %s scans remembered"
L.ACT_POSTED = "Posted %s"
L.ACT_POST_FAILED = "Could not post %s: %s"
L.ACT_AH_OPENED = "Auction house opened"
L.ACT_AH_CLOSED = "Auction house closed"

-- How long ago
L.AGO_NOW = "just now"
L.AGO_MINUTES = "%dm ago"
L.AGO_HOURS = "%dh %02dm ago"
L.AGO_DAYS = "%dd %dh ago"
L.WIN_SCAN_WAIT = ". Next scan in %dm"
L.BUY_CAN_USE_TIP = "Only items your character can use."
L.BUY_BETTER_TIP = "Only gear better than what you wear in that slot: gear your class can wear, whose stats, weighted for your class, add up to more. An empty slot is beaten by anything with a stat your class values. Rings and trinkets are measured against the weaker of the two you wear. Bags count when they have more slots than your smallest bag of the same kind: herb bags against your herb bags, ordinary bags against your ordinary bags and any empty bag slot. A kind you do not carry shows only when you pick it in the filters."
L.BUY_SUGGESTED_TIP = "Upgrades you can wear today and afford, the biggest improvement first. The Gain column says how much better each is than what you wear, in stat points weighted for your class. Bags follow the gear, the most extra slots first: Gain says how many more slots each holds than the bag it would replace."
L.BUY_NEAR_LEVEL_TIP = "Only items whose required level is near yours. How far under and over is set in the options."
L.BUY_CAN_AFFORD_TIP = "Only items whose cheapest auction your gold covers."
L.BUY_DEALS_TIP = "Only items priced well under what they usually go for."

-- Options
L.CMD_RECIPES_READ = "Recipe book: read %s, %d learned recipes."
L.CMD_RECIPES_NOT_READ = "Recipe book: not read (%s). The game said: %s"
L.CMD_RECIPES_BOOK = "  %s: %d recipes kept."
L.SETTING_SHOW_RESELL = "Show the Resell tab"
L.SETTING_SHOW_RESELL_TIP = "Adds the Resell tab, which finds auctions listed under their usual price to buy and post again."
L.SETTING_BAG_LIST = "List view for your bags"
L.SETTING_BAG_LIST_TIP = "Shows your bags on the Sell tab as a list, one row per item with its count, under a heading for each kind, instead of a grid of icons."
L.SETTING_RAIL_LARGE = "Bigger filter icons"
L.SETTING_RAIL_LARGE_TIP = "Makes the quick filter icons down the left of the Buy tab a quarter bigger."
L.BUY_RAIL_BIGGER = "Bigger filter icons"
L.BUY_RAIL_SMALLER = "Smaller filter icons"
L.OPTIONS = "Options"
L.OPTIONS_TIP = "Auction Hero's settings."
L.OPTIONS_DEBUG = "Debug"
L.OPTIONS_DATA = "Data kept: the last scan (%s auctions) and price history for %s items (%s graph points, up to %d days back)."
L.OPTIONS_JOURNAL = "Scan journal: %s scans back over %s, %s changes."
L.OPTIONS_JOURNAL_OFF = "Scan journal: off."
L.CMD_TIMINGS_NONE = "No tab has been opened yet."
L.CMD_TIMINGS_LINE = "%s %s: last %.0f ms, worst %.0f ms (%d times)"
L.CMD_HELP_OPTIONS = "/ah options  open the options"

-- Buying
L.BUY_QUOTING = "Asking the auction house for the price..."
L.BUY_CONFIRM_PRICE = "This is the price right now. Press again to buy."
L.BUY_WAIT_BUSY = "The auction house is still answering another request. Nothing was spent. Press again in a moment."
L.BUY_CHECKED_SAME = "Checked with the auction house: the price is unchanged. The game needs one press per purchase, so press again to buy."
L.BUY_CONFIRM_CHANGED = "The price changed since the list was read. Press Confirm to buy at the new price."
L.BUY_PRICE_ROSE = "The price just went up by %s. Check the new total, then press again to buy."
L.BUY_CONFIRM_BUTTON = "Confirm: buy %s for %s total"
L.BUY_CONFIRM_STACK = "Confirm: buy a stack of %s for %s total"
L.BUY_CONFIRM_ONE = "Confirm: buy 1 for %s"
L.BUY_CONFIRM_OVER_GOLD = "The live price is %s, more than your %s. Nothing was spent. Lower the quantity to buy fewer."
L.BUY_CONFIRM_STACK_NOTE = "The cheapest auction is a stack of %s, and stacks cannot be split. Press again to buy all %s."
L.BUY_BUYING = "Buying..."
L.BUY_DONE = "Bought. It is in your mail."
L.BUY_FAILED = "The auction house refused the purchase. Nothing was spent."
L.BUY_UNAVAILABLE = "That quantity is not for sale any more. Nothing was spent."
L.BUY_NO_ANSWER = "The auction house did not answer. Nothing was spent."
L.BUY_OVER_GOLD = "The price went above your gold. Nothing was spent."
L.BUY_QUOTE_EXPIRED = "The game only holds a checked price for a short while, and this one lapsed. Nothing was spent. Press Buy to check it again."
L.BUY_BUTTON_AUCTION = "Buy the cheapest"
L.BUY_HOW_AUCTION = "Two presses: the first finds the cheapest auction for sale right now, the second buys it. Press again for the next one."
L.BUY_NO_CONFIRM = "The auction house did not confirm the purchase. Check your gold and your mail before trying again."
L.BUY_UNREADABLE = "Could not tell which auction is this exact item. Nothing was spent. Try again in a moment."
L.BUY_HOW = "Two presses: the first checks the live price, the second buys."
L.ACT_BOUGHT = "Bought %s %s for %s"
L.ACT_BUY_FAILED = "Could not buy %s: %s"

-- Ledger
L.TAB_LEDGER = "Ledger"
L.LEDGER_KIND_BUY = "Bought"
L.LEDGER_KIND_POST = "Deposit"
L.LEDGER_KIND_SALE = "Sold"
L.LEDGER_TILE_STOCK = "Unsold stock"
L.LEDGER_TILE_SOLD = "%s sold"
L.LEDGER_TILE_BOUGHT = "%s bought"
L.LEDGER_TILE_UNITS = "%s items"
L.LEDGER_TILE_PROFIT_TIP = "What your sales made: what they paid out, less what the sold items cost you and every deposit. Items you still hold are not counted as a loss."
L.LEDGER_TILE_EARNED_TIP = "What your sales paid out, after the auction house's cut. Sales come in when you open your mailbox."
L.LEDGER_TILE_SPENT_TIP = "Everything you paid for what you bought."
L.LEDGER_TILE_FEES_TIP = "Deposits paid to post auctions. A deposit comes back when the auction sells."
L.LEDGER_TILE_STOCK_TIP = "What the items you bought and have not sold yet cost you."
L.LEDGER_SHOW_ENTRIES = "Every trade"
L.LEDGER_SHOW_ITEMS = "By item"
L.LEDGER_TIP = "Buys and deposits are written down as you make them. Sales are read from your mail, so open the mailbox to bring them in. Profit counts what you sold against the oldest units you bought."
L.LEDGER_NONE = "Nothing yet. Buy or post at the auction house, and open your mailbox to bring in sales."
L.LEDGER_COL_BOUGHT = "Bought"
L.LEDGER_COL_SPENT = "Spent"
L.LEDGER_COL_SOLD = "Sold"
L.LEDGER_COL_EARNED = "Earned"
L.LEDGER_COL_FEES = "Deposits"
L.LEDGER_COL_PROFIT = "Profit"
L.LEDGER_COL_HELD = "Unsold"
L.LEDGER_COL_WHEN = "When"
L.LEDGER_COL_LAST = "Last trade"
L.LEDGER_COL_SOLD_AT = "Sold at"
L.LEDGER_COL_NOW = "Now"
L.LEDGER_COL_CHANGE = "Change"
L.LEDGER_CHART_TITLE = "Earned per day"
L.LEDGER_CHART_HOVER = "Hover a day for its sales."
L.LEDGER_CHART_READOUT = "%s: %s from %s sales (%s units)"
L.LEDGER_CHART_WEEK = "Last 7 days"
L.LEDGER_CHART_MONTH = "Last 30 days"
L.LEDGER_CHART_BEST = "Best day"
L.LEDGER_DAY = "%b %d"
L.LEDGER_TIME = "%b %d %H:%M"
L.LEDGER_COL_WHAT = "What"
L.LEDGER_COL_GOLD = "Gold"
L.ACT_SOLD = "Sold %s %s for %s"

-- Item tooltips
L.SETTING_ITEM_TOOLTIPS = "Prices in item tooltips"
L.SETTING_ITEM_TOOLTIPS_TIP = "Adds scan and trade prices to item tooltips, plus crafted output prices and estimated material costs to recipe tooltips."
L.TIP_YOURS = "Your %s is worth"
L.TIP_YOURS_VALUE = "~%s"
L.TIP_LOWEST = "Lowest"
L.TIP_NEXT = "Next price up"
L.TIP_COMMON = "Most are at"
L.TIP_PRICE_OF = "%s  (%s of %s)"
L.TIP_LOWEST_THEN = "%s  (%s for sale then)"
L.TIP_RANGE = "Asked between"
L.TIP_RANGE_VALUE = "%s and %s"
L.TIP_SEEN = "Last seen"
L.TIP_PAID = "You paid"
L.TIP_PAID_VALUE = "%s each  (%s unsold)"
L.TIP_SOLD = "You last sold at"
L.RECIPE_HEADING = "Crafted output"
L.RECIPE_MAKES = "Makes"
L.RECIPE_ITEM_UNKNOWN = "Item #%d"
L.RECIPE_RATE = "Going rate (each)"
L.RECIPE_RATE_EST = "Est. going rate (each)"
L.RECIPE_RATE_VARIANTS = "Est. rate (other variants)"
L.RECIPE_UNKNOWN = "Unknown"
L.RECIPE_QUOTE_AGE = "%s  (scan: %s)"
L.RECIPE_YIELD = "%s x%d"
L.RECIPE_YIELD_RANGE = "%s x%d-%d"
L.RECIPE_MATS = "Est. materials / craft"
L.RECIPE_MATS_PARTIAL = "At least %s (%d unpriced)"
L.RECIPE_MARGIN = "Est. margin before fees"
L.RECIPE_MARGIN_RANGE = "%s to %s"
L.RECIPE_PRICE_NOTE = "Asking prices; auction fees and deposits are not included."
L.BUY_COL_DEAL = "$"

-- Number settings
L.SETTING_GEAR_RANGE = "Near level"
L.SETTING_GEAR_RANGE_TIP = "How many levels under and over yours the Buy tab's Near level toggle reaches, up to %d each way. At your level (%d) it shows items for levels %d to %d."
L.SETTING_HISTORY_DAYS = "Days of price history to keep"
L.SETTING_HISTORY_DAYS_TIP = "How far back each item's price graph reaches. More days keep more data."
L.SETTING_DAYS = "%d days"
L.SETTING_JOURNAL_DAYS = "Days of scan changes to keep"
L.SETTING_JOURNAL_DAYS_TIP = "Keeps what changed between scans. Uses the most memory of anything kept; Off turns it off."
L.SETTING_OFF = "Off"
L.SETTING_HISTORY_TRIM = "The oldest %d days of each item's graph go the next time a scan sees it. Pick %d again before then to keep them."

-- Item stats, under the Buy button
L.STAT_HEADING = "What the scans show"
L.STAT_SCANS = "Seen in"
L.STAT_SCANS_ONE = "%s scan"
L.STAT_SCANS_MANY = "%s scans"
L.STAT_DAYS_ONE = "over %s day"
L.STAT_DAYS_MANY = "over %s days"
L.STAT_USUAL_LOW = "Usual lowest"
L.STAT_LOWEST_EVER = "Lowest ever"
L.STAT_LOWEST_EVER_VALUE = "%s  (%s, %s)"
L.STAT_FOR_SALE = "For sale now"
L.STAT_FOR_SALE_COUNT = "%s in all"
L.STAT_MORE_PRICES = "and %s more prices, up to %s"
L.STAT_FROM_SCAN = "from the scan, %s"
L.STAT_CHECKED = "checked live, %s"
L.STAT_CHECKING = "checking the auction house..."
L.BUY_GONE = "%s is no longer for sale. It was in the scan, and the auction house has none now."
L.BUY_COL_FROM = "From"
L.BUY_ROW_PRICE = "-  for sale at"
L.BUY_ROW_MORE = "-  and %s more prices, up to %s"
L.BUY_PRICE_GONE = "None at %s any more. The cheapest now is %s. Nothing was spent."
L.BUY_ITEM_GONE = "The auction house has none of this exact item for sale right now. Nothing was spent."
L.BUY_NOT_AMONG = "The auction house listed %s auctions%s for this item, but none is named \"%s\". The first is \"%s\". Nothing was spent."
L.BUY_AND_MORE = " (and there are more)"
L.STAT_CHECK_TOO_LONG = "too many auctions to check live: the scan's prices stand"
L.STAT_CHECK_UNREAD = "live check could not be read (%s): the scan's prices stand"
L.STAT_CHECK_NOT_FOUND = "could not find this item at the auction house, so the scan's prices stand. Looked up by name: %s"
L.BUY_NOT_FOUND = "Could not find this item at the auction house. Looked up by name: %s. Nothing was spent."
L.BUY_PRICES_UPDATED = "Prices updated"
L.BUY_PRICE_WENT = "The one at %s is gone. %s for sale now, from %s."
L.BUY_PROBLEM = "The auction house reported a problem (code %s). Your gold was %s before and is %s now, so it does not look bought. Check your mail to be sure."

-- The scan shield: covers the tabs while a scan runs
L.SHIELD_TITLE = "Scanning the auction house"
L.SHIELD_DONE_TITLE = "Scan complete"
L.SHIELD_READING_TITLE = "Reading your last scan"
L.SHIELD_CANCELLING = "Cancelling..."
L.SHIELD_CLOSE = "Close"
L.SHIELD_STAGE_ASK = "Ask the server for every auction"
L.SHIELD_STAGE_READ = "Read the auctions"
L.SHIELD_STAGE_DETAILS = "Fill in item details"
L.SHIELD_STAGE_PRICE = "Price it all against your history"
L.SHIELD_ASKING = "The server is packing up every auction..."
L.SHIELD_READING = "%s of %s auctions"
L.SHIELD_RESOLVING = "%s auctions still need item details (pass %d)"
L.SHIELD_PRICING = "Comparing %s auctions with what they usually go for"
L.SHIELD_RATE = "%s a second"
L.SHIELD_ELAPSED = "%s so far"
L.SHIELD_LAST = "Last scan: %s auctions"
L.SHIELD_RESULT = "%s auctions in %s"
L.SHIELD_RESULT_CHANGE = "%s auctions in %s, %s since the last scan"
L.SHIELD_TIP = "The tabs are paused so nothing changes under you while the scan runs. Cancel stops the scan; the last one stays in use."
-- The daily scan, rewards and scan confidence (data\rewards.lua)
L.SCAN_CONF = "Confidence"
L.SCAN_CONF_LINE = "%d%%  %s"
L.SCAN_CONF_FACTS = "Scanned on %d of the last %d days"
L.SCAN_CONF_TIP = "How well your scans cover the market. Deals are measured against what things usually cost, and the more days you scan, the surer that usual price is. Full confidence takes a scan on %d of the last %d days."
L.SCAN_CONF_GUESS = "Mostly guessing"
L.SCAN_CONF_HUNCH = "A hunch"
L.SCAN_CONF_FAIR = "Fairly sure"
L.SCAN_CONF_SURE = "Sure"
L.SCAN_CONF_ORACLE = "Market oracle"
L.GOALS_TITLE = "Today"
L.GOALS_STREAK = "Streak: %d days"
L.GOALS_STREAK_ONE = "Streak: 1 day"
L.GOALS_STREAK_NONE = "No streak yet"
L.GOAL_SCAN = "One full scan"
L.HERO_COINS = "Hero Coins"
L.HERO_COINS_TIP = "Earned by using Auction Hero: a scan a day, buying, posting, selling, looking around, and scanning days in a row. Can you spend them? ...TBD"
L.HERO_COINS_TODAY = "+%s today"
L.HERO_COINS_EARNED = "Earned: +%s Hero Coins"
L.HERO_COINS_PLUS = "+%s"
L.HERO_COINS_RECENT = "Lately"
L.HERO_COINS_NONE = "Nothing yet. Run a scan to earn your first."
L.EARN_TITLE = "Ways to earn"
L.EARN_SCAN = "The day's first full scan"
L.EARN_VISIT = "Open the auction house"
L.EARN_BUY = "Buy through Auction Hero"
L.EARN_POST = "Post through Auction Hero"
L.EARN_SALE = "Something of yours sells"
L.EARN_EXPLORE = "Open a tab for the first time"
L.EARN_STREAK = "Streak bonus"
L.EARN_TODAY = "%d/%d today"
L.EARN_ONCE_EACH = "once each"
L.PROGRESS_BONUS = "%d days in a row"
-- Progress tab (ui\tabs\progress.lua)
L.PROGRESS_DAYS = "The last %d days"
L.PROGRESS_DAYS_NOTE = "Green: a day with a scan. Scan on %d of them for full confidence."
L.PROGRESS_DAY_SCANNED = "Scanned"
L.PROGRESS_DAY_MISSED = "No scan"
L.PROGRESS_BONUSES = "Streak bonuses"
L.PROGRESS_NEXT = "%d more days to the next"
L.PROGRESS_ALL_BONUSES = "Every bonus reached"
L.TRACK_TITLE = "What's tracked"
L.TRACK_COUNTING = "counting..."
L.TRACK_NONE = "none yet"
L.TRACK_SCAN = "Last scan"
L.TRACK_SCAN_TIP = "The full scan the tabs read: its auctions, the different items in it, and how old it is."
L.TRACK_SCAN_VALUE = "%s auctions, %s items, %s"
L.TRACK_HISTORY = "Price history"
L.TRACK_HISTORY_TIP = "One small record per item, with the points its graph is drawn from. Days kept is set in Options."
L.TRACK_HISTORY_VALUE = "%s items, %s points, %d days"
L.TRACK_SCANS = "Scans in history"
L.TRACK_SCANS_TIP = "Full scans folded into the price history, and how many realm and faction markets they cover."
L.TRACK_SCANS_VALUE = "%s, %d markets"
L.TRACK_JOURNAL = "Scan journal"
L.TRACK_JOURNAL_TIP = "What changed between scans, kept so any earlier scan can be rebuilt. Uses the most memory; days kept is set in Options."
L.TRACK_JOURNAL_VALUE = "%s scans over %s"
L.TRACK_JOURNAL_CHANGES = "Journal detail"
L.TRACK_JOURNAL_CHANGES_TIP = "Listings that changed across the kept scans, the item variants they point to, and live checks journaled between scans."
L.TRACK_JOURNAL_CHANGES_VALUE = "%s changes, %s items, %s checks"
L.TRACK_LEDGER = "Your ledger"
L.TRACK_LEDGER_TIP = "Sales, purchases and posts recorded for this character."
L.TRACK_LOG = "Event log"
L.TRACK_LOG_TIP = "Auction house events kept for troubleshooting. Switched off in Options under Debug."
L.SHIELD_QUIPS = {
	"Counting every copper ore in town...",
	"Asking the auctioneer very nicely...",
	"Shaking out the linen cloth...",
	"Weighing gold by the coin...",
	"Peeking under every stack...",
	"Sorting the treasure from the trash...",
	"Looking for swords priced like daggers...",
	"Haggling with nobody in particular...",
	"Reading the fine print on every bid...",
	"Polishing the good stuff...",
	"Checking which bargains are real...",
	"Dusting off forgotten recipes...",
}

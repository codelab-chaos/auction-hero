-- The ledger's rules, as data: what kinds of entry there are, and how auction
-- house mail is read into them.
local _, ns = ...
local L = ns.L

-- Each kind of entry. sign says which way the gold went: -1 out, 1 in.
ns.LedgerKinds = {
	buy = { label = L.LEDGER_KIND_BUY, sign = -1 },
	post = { label = L.LEDGER_KIND_POST, sign = -1 },
	sale = { label = L.LEDGER_KIND_SALE, sign = 1 },
}

ns.LedgerRules = {
	-- How long auction house mail is kept. With the days a mail has left, it
	-- gives the moment the mail arrived, which is when the sale happened.
	mailDays = 30,
	-- Two readings of one mail can differ by a little. Mails alike in every
	-- detail that arrived within this many seconds are the same mail.
	sameMailSeconds = 300,
	-- Invoice types the mailbox reports, and the entry each becomes. Purchases
	-- are recorded at the press, so a buyer's invoice is not read again here.
	invoices = { seller = "sale" },
	-- Where a mail's subject carries the quantity: "Auction successful: Linen Cloth (20)".
	quantityPatterns = { "%((%d+)%)%s*$" },
}

-- The tiles across the top of the Ledger tab, left to right. value is a field
-- of the ledger's totals (ns.Ledger:Summary). count, when given, is the
-- field shown under it with its line. headline makes the tile the big one;
-- signed shows a + or - and colors it by which way it went.
ns.LedgerTiles = {
	{ value = "profit", label = L.LEDGER_COL_PROFIT, tip = L.LEDGER_TILE_PROFIT_TIP, headline = true, signed = true },
	{ value = "earned", label = L.LEDGER_COL_EARNED, tip = L.LEDGER_TILE_EARNED_TIP, count = "sold", line = L.LEDGER_TILE_SOLD },
	{ value = "spent", label = L.LEDGER_COL_SPENT, tip = L.LEDGER_TILE_SPENT_TIP, count = "bought", line = L.LEDGER_TILE_BOUGHT },
	{ value = "fees", label = L.LEDGER_COL_FEES, tip = L.LEDGER_TILE_FEES_TIP },
	{ value = "heldCost", label = L.LEDGER_TILE_STOCK, tip = L.LEDGER_TILE_STOCK_TIP, count = "held", line = L.LEDGER_TILE_UNITS },
}

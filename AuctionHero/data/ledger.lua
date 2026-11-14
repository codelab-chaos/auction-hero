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

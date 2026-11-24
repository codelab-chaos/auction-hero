-- The ledger: buys and deposits written down at the press, sales read from
-- mail, and profit worked out from the two.
local ns = Boot()
OpenAuctionHouse()
Scan()
MONEY = 1000000
local function entries()
	return ns.Ledger:Entries()
end
local function row(name)
	for _, item in ipairs((ns.Ledger:Summary())) do
		if item.name == name then
			return item
		end
	end
end

check("the ledger starts empty", #entries(), 0)

-- A purchase is written down when the game says it went through, at the quote.
ns.Buying:Start({ key = "2001:Copper Ore", itemID = 2001, quantity = 5 })
Tick(2)
check("a quote alone is not a trade", #entries(), 0)
ns.Buying:Confirm()
check("nor is the press, until the game answers", #entries(), 0)
Tick(2)
check("a purchase is one entry", #entries(), 1)
check("of the kind buy", entries()[1].kind, "buy")
check("for the units bought", entries()[1].quantity, 5)
check("at the server's price", entries()[1].amount, 35)
check("under the item's name", entries()[1].name, "item 2001")

-- A refused purchase leaves no trace.
MOCK.buyFails = true
ns.Buying:Start({ key = "2001:Copper Ore", itemID = 2001, quantity = 5 })
Tick(2)
ns.Buying:Confirm()
Tick(2)
check("a refused purchase is not entered", #entries(), 1)
MOCK.buyFails = false

-- A purchase made in the game's own window is seen the same way.
C_AuctionHouse.StartCommoditiesPurchase(2001, 5)
Tick(2)
C_AuctionHouse.ConfirmCommoditiesPurchase(2001, 5)
Tick(2)
check("a purchase outside the addon is entered too", #entries(), 2)

-- Buying a single item out.
local tunic = C_AuctionHouse.MakeItemKey(2006)
C_AuctionHouse.SendSearchQuery(tunic, {}, false)
C_AuctionHouse.PlaceBid(77, 400)
Tick(2)
check("a single item bought out is entered", entries()[3].amount, 400)
check("with its item", entries()[3].itemID, 2006)

-- Posting costs a deposit.
ns.SellSearch:Request("2003:Light Leather")
Tick(3)
ns.Posting:Post({ key = "2003:Light Leather", commodity = true, duration = 3, quantity = 10, unit = 50, buyout = true })
Tick(5)
check("a post is entered", entries()[4].kind, "post")
check("at its deposit", entries()[4].amount, 30)

-- Sales arrive by mail. Two mails alike in every detail are two sales.
MAIL = {
	{ "seller", "item 2001", 60, 60, 2, 3, "Auction successful: item 2001 (4)", 30 },
	{ "seller", "item 2001", 60, 60, 2, 3, "Auction successful: item 2001 (4)", 30 },
	{ "buyer", "item 2001", 35, 35, 0, 0, "Auction won: item 2001 (5)", 29.9 },
	{ "seller_temp_invoice", "item 2001", 60, 60, 0, 0, "Sale pending", 29.9 },
}
FireEvent("MAIL_SHOW")
Tick(15) -- read once the mailbox settles
check("two sales are entered, and nothing else", #entries(), 6)
local sale = entries()[5]
check("a sale", sale.kind, "sale")
check("of the quantity in the subject", sale.quantity, 4)
check("for the price, plus the deposit back, less the cut", sale.amount, 59)
checkTrue("dated when the mail arrived", math.abs(sale.time - GetServerTime()) <= 1)

-- Reading the same mailbox again, a little later, adds nothing.
Tick(100)
FireEvent("MAIL_INBOX_UPDATE")
Tick(15)
check("the same mail is not entered twice", #entries(), 6)
-- Nor after a reload, when only the saved ledger remembers.
table.remove(MAIL, 1)
FireEvent("MAIL_INBOX_UPDATE")
Tick(15)
check("one of the two taken from the box", #entries(), 6)
MAIL[#MAIL + 1] = { "seller", "item 2001", 60, 60, 2, 3, "Auction successful: item 2001 (4)", 30.01 }
FireEvent("MAIL_INBOX_UPDATE")
Tick(15)
check("a new mail alike in detail but arriving later is a new sale", #entries(), 7)

-- Adding it up: 10 ore bought for 70, 12 sold for 177 (10 of them ours).
local ore = row("item 2001")
check("units bought", ore.bought, 10)
check("spent", ore.spent, 70)
check("units sold", ore.sold, 12)
check("earned", ore.earned, 177)
check("the sold units had cost all 70", ore.cost, 70)
check("profit", ore.profit, 107)
check("nothing left unsold", ore.held, 0)
local held = row("item 2006")
check("an unsold purchase is stock, not a loss", held.profit, 0)
check("held at what it cost", held.heldCost, 400)
check("a deposit with no sale yet is a cost", row("item 2003").profit, -30)
local newest = 0
for _, entry in ipairs(ns.Ledger:Entries()) do
	if entry.name == "item 2001" then
		newest = math.max(newest, entry.time)
	end
end
check("an item row says when it was last traded", row("item 2001").last, newest)
local _, totals = ns.Ledger:Summary()

-- Each day's sales, for the chart over the ledger.
local daily = ns.Ledger:Daily(ns.LedgerChart.days)
check("one point a day", #daily, ns.LedgerChart.days)
local paid, units, gross, sold = 0, 0, 0, 0
for _, point in ipairs(daily) do
	paid = paid + point.earned
end
for _, entry in ipairs(ns.Ledger:Entries()) do
	if entry.kind == "sale" and entry.name == "item 2001" then
		gross, sold = gross + (entry.price or entry.amount), sold + entry.quantity
	end
end
check("the days add up to what sales paid", paid, totals.earned)
check("an item's average sale price, before the cut", row("item 2001").soldUnit, math.floor(gross / sold + 0.5))
check("total profit", totals.profit, 77)

-- A sale is announced in the footer.
checkMatch("the footer tells of the sale", ns.Activity:Latest().text, "Sold 4 item 2001")

-- The tab shows it both ways.
ShowTab("ledger")
local function shows(pattern)
	return #Frames(function(frame)
		return type(frame.text) == "string" and strip(frame.text):find(pattern) ~= nil
	end) > 0
end
checkTrue("the totals are tiles, profit first", shows("^PROFIT$") and shows("^EARNED$") and shows("^UNSOLD STOCK$"))
checkTrue("profit says it went up", shows("^%+77c$"))
checkTrue("with counts under the amounts", shows("^%d+ sold$") and shows("^%d+ bought$"))

-- Last trade reads as an age, and hovering it gives the date.
checkTrue("last trade reads as an age", shows("^%d+[mhd]$"))
local heading
for _, frame in ipairs(ALL_FRAMES()) do
	if frame.label and type(frame.label.text) == "string" and frame.label.text:gsub("^[v%^]  ", "") == ns.L.LEDGER_COL_LAST then
		heading = frame
	end
end
local itemRow = Frames(function(frame)
	return frame.data ~= nil and frame.data.last ~= nil and frame.data.soldUnit ~= nil and frame.scripts.OnEnter ~= nil
end)[1]
checkTrue("found the heading and a row", heading ~= nil and itemRow ~= nil)
CURSOR_X = itemRow:GetLeft() + heading.lastPoint[2] + 2
itemRow.scripts.OnEnter(itemRow)
check("hovering it gives the date", TIP and TIP[2], date(ns.L.LEDGER_DATE_LONG, itemRow.data.last))
CURSOR_X = itemRow:GetLeft() + 5
itemRow.scripts.OnUpdate(itemRow)
checkTrue("away from it, not the date", not (TIP and TIP[2] == date(ns.L.LEDGER_DATE_LONG, itemRow.data.last)) or not GameTooltip:IsShown())
itemRow.scripts.OnLeave(itemRow)
CURSOR_X = nil
ButtonNamed("Every trade").scripts.OnClick(ButtonNamed("Every trade"))
checkTrue("and switches to every trade", ButtonNamed("By item") ~= nil)

-- The game's Open All: the mailbox is read once as it starts, so no sale is
-- missed before its mail is emptied, not while it takes the mail, and again
-- when it ends.
local before = #entries()
MAIL[#MAIL + 1] = { "seller", "item 2001", 90, 90, 2, 3, "Auction successful: item 2001 (6)", 29.5 }
C_Mail.SetOpeningAll(true)
check("read as Open All starts", #entries(), before + 1)
local reads = 0
local realInvoice = GetInboxInvoiceInfo
GetInboxInvoiceInfo = function(index)
	reads = reads + 1
	return realInvoice(index)
end
for _ = 1, 2 do
	table.remove(MAIL, 1)
	FireEvent("MAIL_INBOX_UPDATE")
	Tick(15)
end
check("not read while it takes the mail", reads, 0)
C_Mail.SetOpeningAll(false)
Tick(15)
checkTrue("read again once it ends", reads > 0)
check("with nothing entered twice", #entries(), before + 1)
GetInboxInvoiceInfo = realInvoice

-- Too narrow for every column: the least needed step aside, lowest first.
ShowTab("ledger")
ButtonNamed("By item").scripts.OnClick(ButtonNamed("By item"))
local function Heading(label)
	return Frames(function(frame)
		return frame.label and type(frame.label.text) == "string" and frame.label.text:gsub("^[v%^]  ", "") == label and frame:IsShown()
	end)[1]
end
local list = Heading(ns.L.LEDGER_COL_PROFIT):GetParent():GetParent()
local box = Frames(function(frame)
	return frame.rowsDrawn ~= nil and frame:GetParent() == list
end)[1] or SCROLLBOX
box:SetWidth(520)
list.scripts.OnSizeChanged(list, 520)
checkTrue("deposits step aside first", Heading(ns.L.LEDGER_COL_FEES) == nil)
checkTrue("profit always stays", Heading(ns.L.LEDGER_COL_PROFIT) ~= nil)

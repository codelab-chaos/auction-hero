-- Ledger: every auction house trade this character has made, kept for good.
-- It only stores entries and adds them up. What becomes an entry is decided by
-- ledger\trades.lua (buys and posts) and ledger\mail.lua (sales).
--
-- An entry:
--   time      server time of the trade
--   kind      a key of ns.LedgerKinds: "buy", "post" or "sale"
--   name      the item's name. Trades of one item are matched up by it
--   itemID    when known
--   quantity  units
--   amount    copper that moved: paid for a buy, the deposit for a post, what
--             the mail paid out for a sale (the price, less the auction
--             house's cut, plus the deposit handed back)
--   price, cut, deposit   a sale's parts, as the invoice gave them
--   mail      for an entry read from mail, the details that identify the mail
local _, ns = ...
local Bus = ns.Bus

local Ledger = {}
ns.Ledger = Ledger

function Ledger:Entries()
	return ns.charDb.ledger
end

function Ledger:Add(entry)
	entry.time = entry.time or GetServerTime()
	entry.quantity = entry.quantity or 1
	entry.amount = entry.amount or 0
	local entries = self:Entries()
	entries[#entries + 1] = entry
	self.byName = nil
	Bus:Fire("LEDGER_CHANGED", entry)
	return entry
end

local function NewRow(name)
	return { name = name, bought = 0, spent = 0, sold = 0, earned = 0, fees = 0, cost = 0, profit = 0, held = 0, heldCost = 0, lots = {} }
end

-- Takes sold units out of what was bought, oldest purchase first, and returns
-- what those units cost. Units sold that were never bought here cost nothing.
local function Consume(lots, quantity)
	local cost = 0
	while quantity > 0 and lots[1] do
		local lot = lots[1]
		local take = math.min(lot.quantity, quantity)
		cost = cost + take * lot.unit
		lot.quantity = lot.quantity - take
		quantity = quantity - take
		if lot.quantity <= 0 then
			table.remove(lots, 1)
		end
	end
	return cost
end

-- Adds the ledger up. Returns one row per item and a row of totals:
--   bought, spent    units bought and what they cost
--   sold, earned     units sold and what the mail paid out
--   fees             deposits paid to post
--   cost             what the sold units had cost
--   profit           earned, less cost, less fees
--   held, heldCost   units bought and not yet sold, at what they cost
--   lastSale         what each unit of the newest sale paid out
function Ledger:Summary()
	-- Oldest first. Trades in the same second keep the order they were written in.
	local ordered, written = {}, {}
	for index, entry in ipairs(self:Entries()) do
		ordered[index] = entry
		written[entry] = index
	end
	table.sort(ordered, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return written[a] < written[b]
	end)

	local rows, byName = {}, {}
	for _, entry in ipairs(ordered) do
		local row = byName[entry.name]
		if not row then
			row = NewRow(entry.name)
			byName[entry.name] = row
			rows[#rows + 1] = row
		end
		row.itemID = row.itemID or entry.itemID
		if entry.kind == "buy" then
			row.bought = row.bought + entry.quantity
			row.spent = row.spent + entry.amount
			row.lots[#row.lots + 1] = { quantity = entry.quantity, unit = entry.amount / entry.quantity }
		elseif entry.kind == "post" then
			row.fees = row.fees + entry.amount
		elseif entry.kind == "sale" then
			row.sold = row.sold + entry.quantity
			row.earned = row.earned + entry.amount
			row.cost = row.cost + Consume(row.lots, entry.quantity)
			row.lastSale = math.floor(entry.amount / entry.quantity)
		end
	end

	local totals = NewRow()
	for _, row in ipairs(rows) do
		for _, lot in ipairs(row.lots) do
			row.held = row.held + lot.quantity
			row.heldCost = row.heldCost + lot.quantity * lot.unit
		end
		row.cost = math.floor(row.cost + 0.5)
		row.heldCost = math.floor(row.heldCost + 0.5)
		row.profit = row.earned - row.cost - row.fees
		for _, field in ipairs({ "bought", "spent", "sold", "earned", "fees", "cost", "profit", "held", "heldCost" }) do
			totals[field] = totals[field] + row[field]
		end
	end
	return rows, totals
end

-- One item's row of the summary, by name, or nil when it was never traded.
-- Kept until the ledger next changes, so asking often costs nothing.
function Ledger:Item(name)
	if not self.byName then
		self.byName = {}
		for _, row in ipairs((self:Summary())) do
			self.byName[row.name] = row
		end
	end
	return self.byName[name]
end

Bus:On("INIT", function()
	ns.charDb.ledger = ns.charDb.ledger or {}
end)

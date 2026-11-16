-- Mail: reads sales into the ledger from the auction house's mail.
--
-- A sale is only known once its mail arrives, and the mail's invoice is the
-- one place that says what was paid, what the auction house kept and what
-- deposit came back. The mailbox is read whenever it is open; nothing is
-- taken from it or changed.
--
-- The mailbox changes in bursts (each mail taken during Open All is one), so
-- it is read once it settles, not on every change. While the game's Open All
-- runs it is not read at all: it is read once as Open All starts, so no sale
-- is missed before its mail is emptied, and again when it ends.
--
-- Mail has no id, so a mail read twice must not be entered twice. A mail is
-- known by its invoice details and the moment it arrived (worked out from the
-- days it has left). Several mails alike in every detail are counted.
local _, ns = ...
local Bus = ns.Bus

local SECONDS_PER_DAY = 86400

local known -- mail details -> arrival times already in the ledger
local reported = {} -- invoice types noted in the log this session

local function Quantity(subject)
	for _, pattern in ipairs(ns.LedgerRules.quantityPatterns) do
		local count = tonumber((tostring(subject or ""):match(pattern)))
		if count then
			return count
		end
	end
	return 1
end

local function Known()
	if not known then
		known = {}
		for _, entry in ipairs(ns.Ledger:Entries()) do
			if entry.mail then
				known[entry.mail] = known[entry.mail] or {}
				table.insert(known[entry.mail], entry.time)
			end
		end
	end
	return known
end

-- Every auction house invoice in the mailbox, as ledger entries.
local function ReadInbox()
	local rules = ns.LedgerRules
	local now = GetServerTime()
	local found = {}
	for index = 1, GetInboxNumItems() do
		local ok, kind, itemName, _, bid, buyout, deposit, cut = pcall(GetInboxInvoiceInfo, index)
		if ok and kind then
			local _, _, _, subject, _, _, daysLeft = GetInboxHeaderInfo(index)
			if not reported[kind] then
				-- What the mailbox really reports, for the Copy log.
				reported[kind] = true
				ns.EventLog:Note("mail invoice", kind, itemName, bid, buyout, deposit, cut, subject, daysLeft)
			end
			local ledgerKind = rules.invoices[kind]
			if ledgerKind and itemName then
				local price, back, kept = bid or 0, deposit or 0, cut or 0
				local quantity = Quantity(subject)
				found[#found + 1] = {
					kind = ledgerKind,
					name = itemName,
					quantity = quantity,
					amount = price + back - kept,
					price = price,
					deposit = back,
					cut = kept,
					time = math.floor(now + ((daysLeft or rules.mailDays) - rules.mailDays) * SECONDS_PER_DAY),
					mail = table.concat({ kind, itemName, quantity, price, buyout or 0, back, kept }, "|"),
				}
			end
		end
	end
	return found
end

local function Scan()
	if not (GetInboxNumItems and GetInboxInvoiceInfo and GetInboxHeaderInfo and ns.charDb) then
		return
	end
	local tolerance = ns.LedgerRules.sameMailSeconds
	local used = {} -- arrival times matched in this reading, per mail details
	for _, entry in ipairs(ReadInbox()) do
		local times = Known()[entry.mail] or {}
		Known()[entry.mail] = times
		used[entry.mail] = used[entry.mail] or {}
		local match
		for index, time in ipairs(times) do
			if not used[entry.mail][index] and math.abs(time - entry.time) <= tolerance then
				match = index
				break
			end
		end
		if match then
			used[entry.mail][match] = true
		else
			times[#times + 1] = entry.time
			used[entry.mail][#times] = true
			ns.Ledger:Add(entry)
		end
	end
end

local openingAll = false -- the game's Open All is taking the mail
local waiting = false -- a reading is due once the mailbox settles
local changedAt = 0

local function ReadWhenSettled()
	changedAt = GetTime()
	if waiting or openingAll then
		return
	end
	waiting = true
	local function Check()
		if openingAll then
			waiting = false
		elseif GetTime() - changedAt >= ns.LedgerRules.settleSeconds then
			waiting = false
			Scan()
		else
			C_Timer.After(ns.LedgerRules.settleSeconds, Check)
		end
	end
	C_Timer.After(ns.LedgerRules.settleSeconds, Check)
end

-- The game's Open All says when it starts and stops taking the mail.
if C_Mail and C_Mail.SetOpeningAll then
	hooksecurefunc(C_Mail, "SetOpeningAll", function(on)
		if on then
			Scan() -- everything, before any of it is emptied
		end
		openingAll = on and true or false
		if not on then
			ReadWhenSettled()
		end
	end)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event)
	if event == "MAIL_CLOSED" then
		openingAll = false
		return
	end
	ReadWhenSettled()
end)

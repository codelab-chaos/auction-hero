-- Mail: reads sales into the ledger from the auction house's mail.
--
-- A sale is only known once its mail arrives, and the mail's invoice is the
-- one place that says what was paid, what the auction house kept and what
-- deposit came back. The mailbox is read whenever it is open; nothing is
-- taken from it or changed.
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

local frame = CreateFrame("Frame")
for _, event in ipairs({ "MAIL_SHOW", "MAIL_INBOX_UPDATE" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", Scan)

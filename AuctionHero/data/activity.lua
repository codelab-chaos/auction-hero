-- What the footer's activity list records, as data: one rule per message.
-- A rule gets the message's payload and returns the line to show and its
-- tone ("good", "bad" or nil), or nothing when the message is not worth a line.
local _, ns = ...
local L = ns.L

ns.ActivityLimit = 15 -- lines kept, and shown when the footer is hovered

-- The item's name from a key such as "2589:Linen Cloth".
local function NameOf(key)
	return key and key:match("^%d+:(.+)$") or L.ACT_AN_ITEM
end

local scanning = false

ns.ActivityRules = {
	DOWNLOAD_STATE = function(state)
		if state.phase == "done" then
			scanning = false
			return L.ACT_SCAN_DONE:format(ns.Comma(state.count or 0), ns.Duration(state.elapsed or 0)), "good"
		elseif state.phase == "failed" then
			scanning = false
			return L.ACT_SCAN_FAILED:format(L[state.reason] or tostring(state.reason)), "bad"
		elseif not scanning then
			scanning = true
			return L.ACT_SCAN_STARTED:format(state.source and state.source.label or "")
		end
	end,
	HISTORY_CHANGED = function()
		return L.ACT_HISTORY:format(ns.Comma(ns.History:ScanCount()))
	end,
	POSTING_CHANGED = function(state)
		if state.phase == "done" then
			return L.ACT_POSTED:format(NameOf(state.key)), "good"
		elseif state.phase == "failed" then
			return L.ACT_POST_FAILED:format(NameOf(state.key), state.message or ""), "bad"
		end
	end,
	BUYING_CHANGED = function(state)
		if state.phase == "done" then
			return L.ACT_BOUGHT:format(ns.Comma(state.quantity or 0), NameOf(state.key), ns.Money(state.total or 0)), "good"
		elseif state.phase == "failed" then
			return L.ACT_BUY_FAILED:format(NameOf(state.key), state.message or ""), "bad"
		end
	end,
	-- Buys and posts already have a line of their own. A sale is news.
	LEDGER_CHANGED = function(entry)
		if entry.kind == "sale" then
			return L.ACT_SOLD:format(ns.Comma(entry.quantity), entry.name, ns.Money(entry.amount)), "good"
		end
	end,
	AH_OPENED = function()
		return L.ACT_AH_OPENED
	end,
	AH_CLOSED = function()
		return L.ACT_AH_CLOSED
	end,
}

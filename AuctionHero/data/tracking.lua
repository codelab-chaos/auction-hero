-- What the Progress tab lists under "What's tracked", as data: one line per
-- thing kept, read from ns.Footprint:Read() (market\footprint.lua).
--   label  the words on the left
--   value  function(kept) -> the text on the right, or nil to leave the line out
--   tip    what the line counts
local _, ns = ...
local L = ns.L

local function Megabytes(bytes)
	return L.TRACK_MB:format(bytes / (1024 * 1024))
end

ns.TrackingLines = {
	{
		label = L.TRACK_MEMORY,
		tip = L.TRACK_MEMORY_TIP,
		value = function(kept)
			return kept.megabytes and L.TRACK_MB:format(kept.megabytes) or L.TRACK_UNKNOWN
		end,
	},
	{
		label = L.TRACK_SCAN,
		tip = L.TRACK_SCAN_TIP,
		value = function(kept)
			if not kept.scanAge then
				return L.TRACK_NONE
			end
			return L.TRACK_SCAN_VALUE:format(ns.Comma(kept.auctions), ns.Comma(kept.variants), ns.Ago(kept.scanAge))
		end,
	},
	{
		label = L.TRACK_HISTORY,
		tip = L.TRACK_HISTORY_TIP,
		value = function(kept)
			return L.TRACK_HISTORY_VALUE:format(ns.Comma(kept.items), ns.Comma(kept.points), kept.days)
		end,
	},
	{
		label = L.TRACK_SCANS,
		tip = L.TRACK_SCANS_TIP,
		value = function(kept)
			return L.TRACK_SCANS_VALUE:format(ns.Comma(kept.scans), kept.markets)
		end,
	},
	{
		label = L.TRACK_JOURNAL,
		tip = L.TRACK_JOURNAL_TIP,
		value = function(kept)
			local journal = kept.journal
			if not journal then
				return L.SETTING_OFF
			end
			return L.TRACK_JOURNAL_VALUE:format(ns.Comma(journal.scans), ns.Duration(journal.reach), Megabytes(journal.bytes))
		end,
	},
	{
		label = L.TRACK_JOURNAL_CHANGES,
		tip = L.TRACK_JOURNAL_CHANGES_TIP,
		value = function(kept)
			local journal = kept.journal
			return journal and L.TRACK_JOURNAL_CHANGES_VALUE:format(ns.Comma(journal.changes), ns.Comma(journal.variants), ns.Comma(journal.deltas - journal.scans)) or nil
		end,
	},
	{
		label = L.TRACK_SALES,
		tip = L.TRACK_SALES_TIP,
		value = function(kept)
			return L.TRACK_SALES_VALUE:format(ns.Comma(kept.watched), ns.Comma(math.floor(kept.sold + 0.5)), ns.SellChanceRule.days)
		end,
	},
	{
		label = L.TRACK_LEDGER,
		tip = L.TRACK_LEDGER_TIP,
		value = function(kept)
			return ns.Comma(kept.ledger)
		end,
	},
	{
		label = L.TRACK_LOG,
		tip = L.TRACK_LOG_TIP,
		value = function(kept)
			return ns.Comma(kept.logged)
		end,
	},
}

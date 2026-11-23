-- What the Progress tab lists under "What's tracked", as data: one line per
-- thing kept, read from ns.Footprint:Read() (market\footprint.lua).
--   label  the words on the left
--   value  function(kept) -> the text on the right, or nil to leave the line out
--   tip    what the line counts
local _, ns = ...
local L = ns.L

-- No line shows memory or sizes in megabytes: the game's memory figure
-- counts memory used and not yet freed, so right after a scan it reads far
-- above what is kept, and a size of part of the data invites the same misreading.

ns.TrackingLines = {
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
			return L.TRACK_JOURNAL_VALUE:format(ns.Comma(journal.scans), ns.Duration(journal.reach))
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

-- Saved data: what keeps the saved file one the game can read back.
--
-- The game reads an addon's saved file as one Lua function, which holds at
-- most `limit` different strings and numbers. Past that the file does not
-- load and the addon starts with nothing. Two things keep it far under:
-- the large tables are saved packed (pack.lua), each a few strings, and
-- whatever is about to be saved is counted, and cut back when it is over.
local _, ns = ...

ns.SavedRule = {
	-- What one Lua function can hold (Lua 5.1: 2^18 - 1).
	limit = 262143,
	-- The share of it the saved data may use. The rest is room for a
	-- character's own saved file, read the same way, and for being wrong.
	share = 0.8,
	-- The tables saved packed, each a path under the saved data. "*" is every
	-- key at that place. `whole` is how many of the path's keys name the thing
	-- the table is a part of: when the table cannot be read back, all of that
	-- goes, since the rest of it points into the table (a scan's rows without
	-- its items, the journal's changes without the items they are about).
	packed = {
		{ "snapshots", "*", "rows", whole = 2 },
		{ "snapshots", "*", "variants", whole = 2 },
		{ "snapshots", "*", "items", whole = 2 },
		{ "scanJournal", "variants", whole = 1 },
		{ "historyByMarket", "*", "items", whole = 2 },
	},
	-- When the count is still over, what goes, first to last, until it fits.
	-- Each is dropped a part at a time, oldest first, by the module that owns
	-- it (ns.Saved.purgers). The latest scan is never dropped.
	purge = { "log", "journal", "otherMarkets", "history" },
	-- Seconds after login before anything is said in chat: said sooner, the
	-- game has no chat window to show it in.
	tellSeconds = 3,
}

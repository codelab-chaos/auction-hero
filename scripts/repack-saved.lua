-- Rewrites an Auction Hero saved file so the game can load it again.
--
-- Before 0.2.0 a busy auction house could grow the file past what Lua reads
-- as one file ("constant table overflow" in Logs/FrameXML.log), and the
-- addon then started with nothing. This reads such a file, packs its large
-- tables the way 0.2.0 saves them, and writes a file the game loads.
--
--   lua5.1 scripts/repack-saved.lua <saved file> <new file> [--merge <from market> <into market>]
--
-- --merge folds one market's price history into another, for a market that
-- was kept under two names. Close the game before putting the new file in
-- WTF/Account/<account>/SavedVariables/AuctionHero.lua, and keep the old one.
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local root = here .. "/.."
local SavedFile = dofile(here .. "/saved-file.lua")
local ns = SavedFile.Addon(root, { "pack.lua", "data/saved.lua", "saved.lua", "market/history-merge.lua" })

local source, target = arg[1], arg[2]
if not source or not target then
	io.stderr:write("usage: lua5.1 scripts/repack-saved.lua <saved file> <new file> [--merge <from> <into>]\n")
	os.exit(2)
end

local file = assert(io.open(source, "rb"))
local text = file:read("*a")
file:close()
assert(loadstring(SavedFile.Roomy(text), "@" .. source))()
local db = assert(AuctionHeroDB, "no AuctionHeroDB in " .. source)
ns.Saved.Open(db, ns.SavedRule.packed)
print(("read    %s: %.1f MB, %d values counted against a limit of %d"):format(source, #text / 1e6, ns.Saved.Count(db), ns.SavedRule.limit))

local index = 3
while arg[index] do
	if arg[index] == "--merge" then
		local from, into = arg[index + 1], arg[index + 2]
		local stores = db.historyByMarket or {}
		assert(stores[from], "no market named " .. tostring(from))
		assert(stores[into], "no market named " .. tostring(into))
		ns.HistoryMerge.Markets(stores[into], stores[from])
		stores[from] = nil
		print(("merged  %q into %q: %d scans"):format(from, into, stores[into].scans))
		index = index + 3
	else
		error("unknown option " .. arg[index])
	end
end

ns.Saved.Close(db, ns.SavedRule.packed)
local count = ns.Saved.Count(db)
local written = SavedFile.Text("AuctionHeroDB", db)
-- What the game will do with it: read it as one function.
assert(loadstring(written, "@" .. target))
file = assert(io.open(target, "wb"))
file:write(written)
file:close()
print(("wrote   %s: %.1f MB, %d values, loads as the game loads it"):format(target, #written / 1e6, count))

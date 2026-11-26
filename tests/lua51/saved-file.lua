-- Run by tests/saved-file.test.mjs with stock Lua 5.1, the game's Lua, whose
-- limits are the ones that matter: a saved file is read as one function, and
-- a function holds at most 262,143 different values.
--
-- Builds data far past that, shows it does not load saved as plain tables
-- (so the check is real), then that it loads once the addon has packed it,
-- and comes back as it was.
local root = arg[1]
local SavedFile = dofile(root .. "/scripts/saved-file.lua")
local ns = SavedFile.Addon(root, { "pack.lua", "data/saved.lua", "saved.lua" })
local rule = ns.SavedRule

local function check(label, got, want)
	if got ~= want then
		error(("%s: expected %s, got %s"):format(label, tostring(want), tostring(got)), 2)
	end
end

local function build()
	local snapshot = { meta = { time = 1795596733, schema = "listings", place = "Realm / Horde" }, rows = {}, variants = {}, items = {} }
	for index = 1, 200000 do
		snapshot.rows[index] = { index % 60000 + 1, index % 20 + 1, 0, 1000000 + index * 7, 0, index % 4 + 1, 1 }
	end
	for index = 1, 60000 do
		snapshot.variants[index] = { "Item " .. index .. " of the Bear", 134000 + index % 900, 2, false, index % 60, "REQ_LEVEL_ABBR", index,
			"|cnIQ2:|Hitem:" .. index .. "::::::::10:1482|h[Item " .. index .. " of the \"Bear\"]|h|r" }
	end
	for index = 1, 8000 do
		snapshot.items[index] = { type = "Armor", subType = "Leather", equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 2, commodity = false }
	end
	local journal = { place = "Realm / Horde", variants = {}, deltas = { { kind = "scan", time = 1795596733, changes = "1:1:0:100:0:2=1" } } }
	for index = 1, 90000 do
		journal.variants[index] = { "Old item " .. index, 134000, 2, false, 10, "REQ_LEVEL_ABBR", index, "|Hitem:" .. index .. ":old|h[Old item " .. index .. "]|h" }
	end
	local history = { items = {}, folded = { [1795596733] = true }, scans = 1 }
	for index = 1, 60000 do
		history.items[index .. ":Item " .. index .. " of the Bear"] = {
			u = 5000000 + index * 13, m = 5100000 + index * 11, lo = 4000000 + index * 3, hi = 9000000 + index, n = 9, d = 4, f = 20700, l = 20780,
			h = "1795596733:" .. (5100000 + index * 11) .. ":" .. (4000000 + index * 3) .. ":12:1",
		}
	end
	return {
		snapshots = { replicate = snapshot }, scanJournal = journal, historyByMarket = { ["Realm / Horde"] = history },
		switches = { itemTooltips = true }, lastFetch = { replicate = 1795596733 }, active = "replicate",
	}
end

local db = build()
local plain = ns.Saved.Count(db)
check("the data is far over the limit", plain > rule.limit * 1.5, true)

-- As 0.1.8 saved it: the game's reader refuses the file.
local read, problem = loadstring(SavedFile.Text("AuctionHeroDB", db))
check("saved as plain tables it does not load", read, nil)
check("for the reason the game gives", tostring(problem):find("constant table overflow", 1, true) ~= nil, true)

-- As 0.2.0 saves it.
check("every large table is packed", ns.Saved.Close(db, rule.packed), 5)
local count, dropped = ns.Saved.Fit(db, rule, {})
check("packed, it fits the budget", count < rule.limit * rule.share, true)
check("with room to spare", count < rule.limit / 20, true)
check("and nothing dropped", #dropped, 0)
local text = SavedFile.Text("AuctionHeroDB", db)
read, problem = loadstring(text)
check("the game's reader takes the file: " .. tostring(problem), read ~= nil, true)

-- Read back as the game would, and unpacked, it is what was saved.
AuctionHeroDB = nil
read()
local back = AuctionHeroDB
check("everything unpacks", #ns.Saved.Open(back, rule.packed), 0)
local function same(a, b, where)
	if type(a) ~= type(b) then error(where .. ": " .. type(a) .. " became " .. type(b)) end
	if type(a) ~= "table" then
		if a ~= b then error(where .. ": " .. tostring(a) .. " became " .. tostring(b)) end
		return
	end
	for key, value in pairs(a) do same(value, b[key], where .. "." .. tostring(key)) end
	for key in pairs(b) do if a[key] == nil then error(where .. "." .. tostring(key) .. " appeared") end end
end
same(build(), back, "db")
print(("ok: %d values plain, %d packed, %.1f MB written"):format(plain, count, #text / 1e6))

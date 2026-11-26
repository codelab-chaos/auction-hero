-- loads: pack.lua, data/saved.lua, saved.lua
-- Saved: the large tables go out packed and come back plain, and what is
-- about to be saved is counted and cut back until it fits.
local Saved, rule = NS.Saved, NS.SavedRule

local function scan(rows)
	local snapshot = { meta = { time = 1, schema = "listings" }, rows = {}, variants = {}, items = {} }
	for index = 1, rows do
		snapshot.rows[index] = { index, 1, 0, index * 37, 0, 2, 1 }
		snapshot.variants[index] = { "Item " .. index, index, "link " .. index }
		snapshot.items[index] = { type = "Armor", classID = 4 }
	end
	return snapshot
end
local function history(items, day)
	local store = { items = {}, folded = { [day] = true }, scans = 1 }
	for index = 1, items do
		store.items[index .. ":Item " .. index] = { u = index * 11, l = day - index % 10, h = "p" .. index }
	end
	return store
end

-- Counting: what the game would write.
check("a list's places are not counted", Saved.Count({ 5, 5, 5 }), 1)
check("keys are", Saved.Count({ a = 5, b = 5 }), 3)
check("text and a number that print alike are two", Saved.Count({ "1", 1 }), 2)
check("a value seen twice is one", Saved.Count({ { "x", 1 }, { "x", 1 } }), 2)

-- Out packed, back plain.
local db = {
	snapshots = { replicate = scan(2000) },
	scanJournal = { place = "Here", variants = scan(500).variants, deltas = { { changes = "1:1=1" } } },
	historyByMarket = { Here = history(2000, 100) },
	switches = { a = true },
}
local plain = Saved.Count(db)
check("every table named is packed", Saved.Close(db, rule.packed), 5)
checkTrue("rows are packed", NS.Pack.IsPacked(db.snapshots.replicate.rows))
checkTrue("the journal's variants are", NS.Pack.IsPacked(db.scanJournal.variants))
checkTrue("history is", NS.Pack.IsPacked(db.historyByMarket.Here.items))
check("what is not named is left alone", db.snapshots.replicate.meta.schema, "listings")
checkTrue("packed, it counts for a fraction", Saved.Count(db) < plain / 50)
check("closing twice packs nothing twice", Saved.Close(db, rule.packed), 0)

check("everything unpacks", #Saved.Open(db, rule.packed), 0)
check("rows are back", #db.snapshots.replicate.rows, 2000)
check("as they were", db.snapshots.replicate.rows[2000][4], 2000 * 37)
check("history is back", db.historyByMarket.Here.items["7:Item 7"].u, 77)
check("data never packed opens as it is", #Saved.Open(db, rule.packed), 0)

-- A packed table that cannot be read is named, and goes with the whole
-- thing it is a part of: the rest of that points into it.
Saved.Close(db, rule.packed)
db.snapshots.other = scan(10)
db.historyByMarket.There = history(10, 100)
Saved.Close(db, rule.packed)
db.snapshots.replicate.rows[1] = "return {"
local failed = Saved.Open(db, rule.packed)
check("one failure", #failed, 1)
check("named by where it is", failed[1].path, "snapshots.*.rows")
check("the scan it was part of is gone", db.snapshots.replicate, nil)
check("another scan is whole", #db.snapshots.other.rows, 10)
check("the journal still opened", #db.scanJournal.variants, 500)
check("and history", db.historyByMarket.Here.items["7:Item 7"].u, 77)

Saved.Close(db, rule.packed)
db.scanJournal.variants[1] = "return {"
db.historyByMarket.There.items[1] = "return {"
failed = Saved.Open(db, rule.packed)
check("two failures", #failed, 2)
check("the journal goes whole, its changes with its items", db.scanJournal, nil)
check("a market's history goes whole", db.historyByMarket.There, nil)
check("the other market's stays", db.historyByMarket.Here.items["7:Item 7"].u, 77)

-- Nothing is half packed when packing fails.
local bad = { snapshots = { replicate = scan(10) }, scanJournal = { variants = { function() end } } }
check("what cannot be packed is an error", pcall(Saved.Close, bad, rule.packed), false)
check("and nothing was packed", NS.Pack.IsPacked(bad.snapshots.replicate.rows), false)

-- A packed table that reads back as something else is not put in place.
local decode = NS.Pack.Decode
NS.Pack.Decode = function(packed) local value = decode(packed) value[1] = nil return value end
local wrong = { snapshots = { replicate = scan(10) } }
check("a table that reads back wrong is an error", pcall(Saved.Close, wrong, rule.packed), false)
check("and the plain one stays", #wrong.snapshots.replicate.rows, 10)
NS.Pack.Decode = decode

-- Marks: both files carry the number of the save.
local account, character = {}, {}
check("the first save is one", Saved.Stamp(account, character), 1)
check("on both", account.savedStamp, character.savedStamp)
check("another character saves after it", Saved.Stamp(account, {}), 2)
check("marks that agree are no problem", Saved.Problem(account, { savedStamp = 2 }, {}, true, true), nil)
check("an older character is no problem", Saved.Problem(account, character, {}, true, true), nil)
check("no account data after a save is gone", Saved.Problem({}, character, {}, true, false), "gone")
check("an unmarked copy with scans in it is older", Saved.Problem({}, character, {}, false, false), "older")
check("an account behind its character is older", Saved.Problem({ savedStamp = 1 }, { savedStamp = 3 }, {}, false, false), "older")
check("a table that did not unpack comes first", Saved.Problem({}, character, { {} }, true, false), "unpack")
check("no marks, trades and no scans is a lost file", Saved.Problem({}, {}, {}, true, true), "trades")
check("no marks and scans is a first run of this version", Saved.Problem({}, {}, {}, false, true), nil)
check("no marks and no trades is a new player", Saved.Problem({}, {}, {}, true, false), nil)

-- Where packed tables would not read back, nothing is packed.
NS.Pack.works = false
check("no packing where it cannot be undone", pcall(Saved.Close, { snapshots = { replicate = scan(5) } }, rule.packed), false)
NS.Pack.works = nil

-- Fitting: over the budget, things go in the order given, until it fits.
local small = { limit = 1000, share = 0.5, purge = { "log", "journal", "otherMarkets", "history" } }
local function crowded()
	local data = { log = {}, journal = {}, other = {}, mine = {}, scan = {} }
	for index = 1, 200 do
		data.log[index] = "log " .. index
		data.journal[index] = "journal " .. index
		data.other[index] = "other " .. index
		data.mine[index] = "mine " .. index
		data.scan[index] = "scan " .. index
	end
	return data
end
-- Each drops half of its own, as the real ones drop a part at a time.
local function halve(name)
	return function(data)
		local list = data[name]
		if #list == 0 then return false end
		for _ = 1, math.ceil(#list / 2) do table.remove(list, 1) end
		return true
	end
end
local purgers = { log = halve("log"), journal = halve("journal"), otherMarkets = halve("other"), history = halve("mine") }

local data = crowded()
local count, dropped = Saved.Fit(data, small, purgers)
checkTrue("it ends under the budget", count <= 500)
check("the log went first", dropped[1], "log")
check("then the journal", dropped[2], "journal")
check("then other markets", dropped[3], "otherMarkets")
check("and no further than needed", dropped[4], nil)
check("the log is gone", #data.log, 0)
check("the journal is gone", #data.journal, 0)
checkTrue("only part of the other markets went", #data.other > 0 and #data.other < 200)
check("this market's history is whole", #data.mine, 200)
check("the scan is never touched", #data.scan, 200)

local roomy = crowded()
count, dropped = Saved.Fit(roomy, { limit = 100000, share = 0.8, purge = small.purge }, purgers)
check("under the budget, nothing is dropped", #dropped, 0)
check("and nothing is touched", #roomy.log, 200)

-- The real limit and the tables that matter are in the rule.
check("the limit is Lua's", rule.limit, 2 ^ 18 - 1)
checkTrue("the budget leaves room", rule.share < 1)

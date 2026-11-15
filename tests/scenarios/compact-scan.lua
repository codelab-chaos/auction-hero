-- A full scan is kept in a compact shape: one entry per distinct item as it
-- is listed, and one row per distinct listing with how many auctions it
-- stands for. Nothing the tabs read is lost by it.
local ns = Boot()
OpenAuctionHouse()
MOCK.repeats = 140 -- as many again of a few auctions, each an exact copy
Scan()

local snapshot = ns.Store:GetSourceSnapshot("replicate")
local auctions = C_AuctionHouse.GetNumReplicateItems()
check("the scan is kept as listings", snapshot.meta.schema, "listings")
check("it still says how many auctions it saw", snapshot.meta.count, auctions)
check("its rows stand for every one of them", ns.AuctionCount(snapshot), auctions)
check("identical auctions share a row", #snapshot.rows, auctions - 140)
checkTrue("with far fewer item entries than rows", #snapshot.variants < #snapshot.rows)
check("what is saved is the same table", AuctionHeroDB.snapshots.replicate, snapshot)

-- A row holds only what differs between listings.
local schema = ns.Schemas.listings
check("a row holds seven values", schema.count, 7)
for _, row in ipairs(snapshot.rows) do
	checkTrue("every row points at an item entry", snapshot.variants[row[schema.index.variant]] ~= nil)
	checkTrue("and stands for at least one auction", row[schema.index.copies] >= 1)
	checkTrue("and holds nothing past its seven values", row[8] == nil)
end
check("an item entry holds eight values", schema.variants, 8)

-- The same scan, kept the old way: one row of twenty values per auction.
local wire, old = ns.Schemas.replicate, {}
for index = 0, auctions - 1 do
	local row = { C_AuctionHouse.GetReplicateItemInfo(index) }
	row[wire.index.link] = C_AuctionHouse.GetReplicateItemLink(index)
	row[wire.index.timeLeft] = C_AuctionHouse.GetReplicateItemTimeLeft(index)
	old[index + 1] = row
end
local before = ns.Market:Build({ meta = { source = "replicate", schema = "replicate", time = snapshot.meta.time, place = snapshot.meta.place }, rows = old, items = snapshot.items })
local after = ns.Market:Build(snapshot)

-- The market built from each is the same, item for item and price for price.
check("the same number of items", #after.items, #before.items)
check("the same number of auctions", after.listings, before.listings)
for _, was in ipairs(before.items) do
	local now = after.byKey[was.key]
	checkTrue(was.key .. " is still there", now ~= nil)
	for _, field in ipairs({ "name", "itemID", "quality", "icon", "link", "level", "levelType", "usable", "commodity", "listings", "units", "bidOnly", "min", "max", "median", "floor", "priceCount" }) do
		check(was.key .. " " .. field, now[field], was[field])
	end
	check(was.key .. " has the same price ladder", #now.tiers, #was.tiers)
	for place, tier in ipairs(was.tiers) do
		for _, field in ipairs({ "unit", "stack", "buyout", "copies", "units", "timeLeft" }) do
			check(was.key .. " tier " .. place .. " " .. field, now.tiers[place][field], tier[field])
		end
	end
end

-- Reading a field works the same whichever way a scan is kept.
local get = ns.RowReader(snapshot)
local first = snapshot.rows[1]
checkTrue("a row gives its item's name", type(get(first, "name")) == "string")
checkTrue("and its link", get(first, "link"):find("|Hitem:") ~= nil)
check("a field the shape does not keep reads as nothing", get(first, "ownerFullName"), nil)

-- A new row copies an existing one and stands for one auction. A new name
-- makes a new item entry, once.
local entries = #snapshot.variants
local made = ns.MakeRow(snapshot, first, { count = 5, buyoutPrice = 900 })
check("a made row keeps its item", get(made, "name"), get(first, "name"))
check("with the new stack size", get(made, "count"), 5)
check("and stands for one auction", get(made, "copies"), 1)
check("without a new item entry", #snapshot.variants, entries)
local other = ns.MakeRow(snapshot, first, { name = "Tunic of the Whale", count = 1 })
check("a made row can be another variant", get(other, "name"), "Tunic of the Whale")
check("which adds one item entry", #snapshot.variants, entries + 1)
ns.MakeRow(snapshot, first, { name = "Tunic of the Whale", count = 1 })
check("and only one, however often it is made", #snapshot.variants, entries + 1)
check("the row it was copied from is unchanged", get(first, "name") ~= "Tunic of the Whale", true)

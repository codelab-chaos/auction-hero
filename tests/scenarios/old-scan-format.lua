-- A scan saved by an earlier build, one row of twenty values per auction,
-- still loads and still fills the tabs. Nobody has to scan again to keep
-- using the addon after updating.
local function row(name, itemID, count, buyout)
	return { name, 1, count, 2, true, 0, nil, buyout, 0, buyout, 0, nil, nil, nil, nil, 0, itemID, true, "|Hitem:" .. itemID .. "|h[" .. name .. "]|h", 4 }
end
local rows = {}
for _ = 1, 6 do rows[#rows + 1] = row("Old Ore", 9001, 20, 2000) end
rows[#rows + 1] = row("Old Ore", 9001, 5, 400)
rows[#rows + 1] = row("Old Cloth", 9002, 1, 150)
AuctionHeroDB = { snapshots = { replicate = {
	meta = { source = "replicate", schema = "replicate", time = GetServerTime() - 60, place = "Test / Horde", count = #rows },
	rows = rows,
} } }

local ns = Boot()
Tick(60)
local snapshot = ns.Store:GetSourceSnapshot("replicate")
checkTrue("the old scan is loaded", snapshot ~= nil)
check("and left in the shape it was saved in", snapshot.meta.schema, "replicate")
check("its auctions are counted one per row", ns.AuctionCount(snapshot), 8)

local market = ns.Analysis and ns.Analysis.market
checkTrue("the market is built from it", market ~= nil)
local ore = market.byKey["9001:Old Ore"]
check("with every auction", ore.listings, 7)
check("and every unit", ore.units, 125)
check("at the right lowest price", ore.min, 80)
check("and the other item too", market.byKey["9002:Old Cloth"].units, 1)

-- The next scan is kept the new way.
OpenAuctionHouse()
Scan()
check("a new scan replaces it in the compact shape", ns.Store:GetSourceSnapshot("replicate").meta.schema, "listings")

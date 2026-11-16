-- A full scan can end with rows whose details never arrived: an item id, but
-- no name or link. An item that cannot be equipped has only one name, so it is
-- named from its id and stays in the market. Gear could be any of its random
-- suffix variants, so its nameless rows are still left out.
local ns = Boot()
OpenAuctionHouse()
Scan()

local snapshot = ns.Store:GetSourceSnapshot("replicate")
local wire = ns.Schemas.replicate
local BAT_WING, TUNIC = 12223, 6600

-- The bat wing is a trade good; the tunic is gear.
local instant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id)
	if id == BAT_WING then
		return id, "Trade Goods", "Meat", "", 1, 7, 8
	end
	return instant(id)
end
local byId = C_Item.GetItemNameByID
C_Item.GetItemNameByID = function(id)
	return id == BAT_WING and "Meaty Bat Wing" or byId(id)
end

local function Nameless(itemID, unit, count)
	local row = {}
	row[wire.index.itemID] = itemID
	row[wire.index.count] = count
	row[wire.index.buyoutPrice] = unit * count
	row[wire.index.minBid] = unit * count
	row[wire.index.timeLeft] = 2
	row[wire.index.hasAllInfo] = false
	return row
end

local rows = {
	Nameless(BAT_WING, 70, 20),
	Nameless(BAT_WING, 75, 5),
	Nameless(TUNIC, 900, 1),
}
local market = ns.Market:Build({
	meta = { source = "replicate", schema = "replicate", time = snapshot.meta.time, place = snapshot.meta.place },
	rows = rows,
	items = {},
})

local wing
for _, item in ipairs(market.items) do
	if item.itemID == BAT_WING then
		wing = item
	end
	checkTrue("nameless gear is left out", item.itemID ~= TUNIC)
end
checkTrue("a nameless trade good is still in the market", wing ~= nil)
check("named from its item id", wing.name, "Meaty Bat Wing")
check("with every unit for sale", wing.units, 25)

-- A live check of goods copies a scan row of the item for each live auction.
-- When the first such row is a nameless one, the live rows must still carry
-- the item's name, or the item vanishes from the list once it is clicked.
local ore = ns.Analysis.market.byKey["2001:Copper Ore"]
local get = ns.RowReader(snapshot)
local template
for _, row in ipairs(snapshot.rows) do
	if get(row, "itemID") == 2001 then
		template = row
		break
	end
end
table.insert(snapshot.rows, 1, ns.MakeRow(snapshot, template, { name = "" }))
check("the item's first scan row is now nameless", get(snapshot.rows[1], "name"), "")

SkipTime(ns.LiveCheckRule.staleMinutes * 60 + 1)
MOCK.liveGoods = { { 150, 3 }, { 180, 10 } }
check("choosing it asks the auction house", ns.LiveCheck:Request(ore), true)
Tick(20)
ore = ns.Analysis.market.byKey["2001:Copper Ore"]
checkTrue("it is still in the market after the check", ore ~= nil)
check("with the live units", ore and ore.units, 13)
local named = 0
for _, row in ipairs(snapshot.rows) do
	if get(row, "itemID") == 2001 and get(row, "name") == "Copper Ore" then
		named = named + 1
	end
end
check("and the saved scan keeps its name", named, 2)

-- Everything the player carries is offered for sale, the reagent bag included.
-- The game numbers the backpack 0, the four bag slots 1 to 4, and a reagent
-- bag 5, past NUM_BAG_SLOTS.
-- Bags are found from the game's own list of them, by name, so a client that
-- numbers its bags its own way is still read in full. Bank bags are not
-- carried, so nothing in them can be posted.
Enum.BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5, Bank = -1, BankBag_1 = 6 }
MOCK_BAGS[2] = { { id = 2770, name = "Copper Ore Chunk", count = 11 } } -- a mining bag
MOCK_BAGS[5] = { { id = 2589, name = "Linen Cloth", count = 15 } } -- the reagent bag
MOCK_BAGS[6] = { { id = 2592, name = "Wool Cloth", count = 9 } } -- a bank bag
-- The game's own sellability check is not used to hide anything: a post the
-- auction house refuses fails with its error instead.
C_AuctionHouse.IsSellItemValid = function() return false end
local ns = Boot()
OpenAuctionHouse()
Tick(2)

local function Held(name)
	for _, item in ipairs(ns.Bags.items) do
		if item.name == name then
			return item
		end
	end
end

checkTrue("the backpack is read", Held("Light Leather") ~= nil)
check("a bag in a bag slot is read", Held("Copper Ore Chunk") and Held("Copper Ore Chunk").total, 11)
check("the reagent bag is read", Held("Linen Cloth") and Held("Linen Cloth").total, 15)
local slot = Held("Linen Cloth").slots[1]
check("its slot knows its bag", slot.bag, 5)
check("and is in the grid", ns.Bags:Slots()[#ns.Bags:Slots()], slot)
checkTrue("a bank bag is not read", Held("Wool Cloth") == nil)
checkTrue("what the game's check turns down is still offered", Held("Light Leather") ~= nil)
checkTrue("soulbound items are not", Held("Soulbound Thing") == nil)

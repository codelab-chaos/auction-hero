-- A client may number its reagent bag its own way and leave it out of
-- Enum.BagIndex. It is still read: the game says which equipment slot holds
-- each container, and one in the player's own bag slots is carried. A bank
-- bag sits in a bank slot and is not read.
Enum.BagIndex = nil
local SLOT_IDS = { Bag0Slot = 31, Bag1Slot = 32, Bag2Slot = 33, Bag3Slot = 34, ReagentBag0Slot = 35 }
function GetInventorySlotInfo(name)
	return SLOT_IDS[name]
end
local HELD_IN = { [1] = 31, [2] = 32, [3] = 33, [4] = 34, [7] = 35, [8] = 80 }
C_Container.ContainerIDToInventoryID = function(bag)
	return HELD_IN[bag] or error("not a bag")
end
MOCK_BAGS[7] = { { id = 4234, name = "Heavy Leather", count = 11 } } -- the reagent bag
MOCK_BAGS[8] = { { id = 2592, name = "Wool Cloth", count = 9 } } -- a bank bag
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

check("leather in the reagent bag is offered", Held("Heavy Leather") and Held("Heavy Leather").total, 11)
check("from its bag", Held("Heavy Leather") and Held("Heavy Leather").slots[1].bag, 7)
checkTrue("a bank bag is not read", Held("Wool Cloth") == nil)

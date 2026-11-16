-- Right after logging in, an item's data may not have loaded: its link has an
-- empty name. It is not offered under a blank name; its data is asked for, and
-- it appears once the game says it has loaded.
local asked = {}
C_Item.RequestLoadItemDataByID = function(id)
	asked[#asked + 1] = id
end
MOCK_BAGS[1] = { { id = 2318, name = "", count = 11 } }
local ns = Boot()
OpenAuctionHouse()
Tick(2)

local function Held(id)
	for _, item in ipairs(ns.Bags.items) do
		if item.itemID == id then
			return item
		end
	end
end

checkTrue("an item with no data yet is not offered", Held(2318) == nil)
check("its data is asked for", asked[1], 2318)
ns.Bags:Refresh()
check("and asked for once, not on every read", #asked, 1)

MOCK_BAGS[1][1].name = "Light Leather"
FireEvent("ITEM_DATA_LOAD_RESULT", 2318, true)
Tick(2)
local leather = Held(2318)
checkTrue("once loaded, it is offered", leather ~= nil)
check("under its name", leather and leather.name, "Light Leather")
check("with its count", leather and leather.total, 11)

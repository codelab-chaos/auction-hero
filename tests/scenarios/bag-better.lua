-- "Better" counts bags too, kind against kind: a bag is better when it has
-- more slots than the smallest bag of its kind carried. An empty bag slot is
-- beaten by any ordinary bag. A kind not carried counts only when picked in
-- the filters. A bag's size comes from its tooltip.
local ns = Boot()

local GENERAL, HERB = 0, 2
MOCK_TOOLTIPS[804] = { "Large Blue Sack", "Bag", "10 Slot Bag" }
MOCK_TOOLTIPS[4245] = { "Small Silk Pack", "Bag", "8 Slot Bag" }
MOCK_TOOLTIPS[22250] = { "Herb Pouch", "12 Slot Herb Bag" }
MOCK_TOOLTIPS[22251] = { "Cenarion Herb Bag", "24 Slot Herb Bag" }
local function bag(itemID, kind) return { classID = 1, subClassID = kind or GENERAL, itemID = itemID } end

check("a bag's slots are read from its tooltip", ns.BagSize:Slots(804), 10)
check("whatever kind of bag it is", ns.BagSize:Slots(22250), 12)
check("an item not loaded yet has no size", ns.BagSize:Slots(5765), nil)

-- Four ordinary bags carried, the smallest 8 slots.
C_Container.ContainerIDToInventoryID = function(container) return 19 + container end
local function carry(container, link, slots, kind)
	EQUIPPED[19 + container] = link
	MOCK_BAG_SIZES[container] = slots
	MOCK_ITEM_CLASS[link] = { 1, kind }
end
carry(1, "bag:a", 10, GENERAL)
carry(2, "bag:b", 8, GENERAL)
carry(3, "bag:c", 12, GENERAL)
carry(4, "bag:d", 14, GENERAL)
local better = ns.BagSize:Better()
checkTrue("a bigger bag is better", better(bag(804)))
checkTrue("one the same size is not", not better(bag(4245)))
checkTrue("nor one whose size is unknown", not better(bag(5765)))
checkTrue("nor anything that is not a bag", not better({ classID = 4, itemID = 804 }))
checkTrue("a herb bag is not, with no herb bag carried", not better(bag(22250, HERB)))
checkTrue("unless herb bags are picked in the filters", ns.BagSize:Better({ [HERB] = true })(bag(22250, HERB)))

-- A herb bag carried: herb bags are measured against it alone.
carry(3, "bag:herb", 12, HERB)
better = ns.BagSize:Better()
checkTrue("a bigger herb bag than the one carried is better", better(bag(22251, HERB)))
checkTrue("one the same size is not", not better(bag(22250, HERB)))
checkTrue("and ordinary bags still go by ordinary bags", better(bag(804)) and not better(bag(4245)))

-- An empty bag slot: any ordinary bag beats it.
EQUIPPED[20], MOCK_BAG_SIZES[1] = nil, 0
checkTrue("with a bag slot empty, any ordinary bag is better", ns.BagSize:Better()(bag(4245)))

-- Once the item's data arrives, its size can be read.
MOCK_TOOLTIPS[5765] = { "Black Silk Pack", "Bag", "10 Slot Bag" }
check("and an item that loads later is sized then", ns.BagSize:Slots(5765), 10)

-- How much more a bag holds, and what a gold of that costs, for "Picks".
-- Bags carried now: 0 (empty slot), 8, 12 herb, 14. The smallest ordinary is 0.
EQUIPPED[20], MOCK_BAG_SIZES[1] = "bag:a", 10 -- the empty slot filled again: smallest ordinary is 8
local gain = ns.BagSize:Gains()
check("a 10 slot bag over an 8 slot one gains 2 slots", gain(bag(804)), 2)
check("one the same size gains none", gain(bag(4245)), 0)
check("gear gains no slots", gain({ classID = 4, itemID = 804 }), nil)
local value = ns.BagSize:ValuePerGold(function() return 20000 end)
check("2 slots for 2 gold is 1 slot a gold", value(bag(804)), 1)
check("a bag that gains nothing is no pick", value(bag(4245)), nil)
check("nor one known to be unusable", value({ classID = 1, subClassID = GENERAL, itemID = 804, usable = false }), nil)

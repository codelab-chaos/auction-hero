-- Bags in the Buy list: the Gain column says how many more slots a bag holds
-- than the one it would replace, and Picks lists bags after the gear.
MOCK_ITEM_CLASS[2007] = { 1, 0 } -- the test auction house's sword, made a bag
MOCK_TOOLTIPS[2007] = { "Big Sack", "Bag", "20 Slot Bag" }
local ns = Boot()
OpenAuctionHouse()
Scan()
MONEY = 10000000
-- Four ordinary bags carried, the smallest 8 slots.
C_Container.ContainerIDToInventoryID = function(container) return 19 + container end
for container, slots in pairs({ 10, 8, 12, 14 }) do
	EQUIPPED[19 + container] = "bag:" .. container
	MOCK_BAG_SIZES[container] = slots
	MOCK_ITEM_CLASS["bag:" .. container] = { 1, 0 }
end
-- A level 20 rogue for whom the tunic is an upgrade.
PLAYER.level, PLAYER.class = 20, "ROGUE"
for _, item in pairs(ns.Analysis.market.byKey) do
	if item.itemID == 2006 and item.link then ITEM_STATS[item.link] = { ITEM_MOD_AGILITY_SHORT = 5 } end
end
ShowTab("buy")

local function rows()
	return Frames(function(frame)
		return frame.data ~= nil and frame.data.key ~= nil and frame.data.tiers ~= nil and frame.scripts.OnMouseUp ~= nil
	end)
end
local function bagRow()
	for _, row in ipairs(rows()) do
		if row.data.itemID == 2007 then return row end
	end
end
local function gainText(row)
	for _, cell in ipairs(row.cells) do
		local text = cell.text and cell.text:IsShown() and cell.text.text
		if text and tostring(text):match("slots$") then return text end
	end
end

checkTrue("the bag is listed", bagRow() ~= nil)
check("its gain is the slots it adds over the smallest bag", gainText(bagRow()), "+12 slots")

local picks = ButtonNamed("Picks")
picks.scripts.OnClick(picks)
Tick(5)
local shown = rows()
checkTrue("Picks lists the bag", bagRow() ~= nil)
checkTrue("with gear above it", #shown > 1)
check("after the gear", shown[#shown].data.itemID, 2007)

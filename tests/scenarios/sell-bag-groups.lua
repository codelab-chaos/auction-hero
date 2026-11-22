-- The Sell tab lists your bags one item to a row, its stacks added up, with
-- items of the same kind together under a heading: trade goods first.
MOCK_ITEM_CLASS[3001] = { 6, 2 } -- arrows
MOCK_ITEM_CLASS[3002] = { 7, 5 } -- cloth
MOCK_ITEM_CLASS[3003] = { 0, 5 } -- bread
MOCK_ITEM_CLASS[3004] = { 7, 5 } -- more cloth
MOCK_ITEM_CLASS[3005] = { 99, 0 } -- a class with no name
MOCK_BAGS[1] = {
	{ id = 3001, name = "Rough Arrow", count = 200 },
	{ id = 3002, name = "Wool Cloth", count = 20 },
	{ id = 3003, name = "Fresh Bread", count = 7 },
	{ id = 3001, name = "Rough Arrow", count = 190 },
	{ id = 3004, name = "Linen Cloth", count = 15 },
	{ id = 3005, name = "Odd Thing", count = 1 },
}
local ns = Boot()
OpenAuctionHouse()
Tick(2)
ShowTab("sell")

-- The grid of icons is the default: one tile per bag slot, same kinds together.
local function tiles()
	local names = {}
	for _, frame in ipairs(Frames(function(frame)
		return frame.slot ~= nil and frame.scripts.OnClick ~= nil
	end)) do
		names[#names + 1] = frame.slot.item.name .. " " .. frame.slot.count
	end
	return table.concat(names, " | ")
end
checkMatch("a tile per slot, grouped by kind", tiles(), "^Linen Cloth 15 | Wool Cloth 20 | Fresh Bread 7 | Rough Arrow 200 | Rough Arrow 190 | ")
checkMatch("a kind the game cannot name comes last", tiles(), " | Odd Thing 1$")
local tradeButton = ButtonNamed("Trade")
tradeButton.scripts.OnClick(tradeButton)
check("the filters work on the grid too", tiles(), "Linen Cloth 15 | Wool Cloth 20")
local allButton = ButtonNamed("All")
allButton.scripts.OnClick(allButton)

-- The list is an option.
ns.SetEnabled("sellBagList", true)
check("with the list on, the grid is put away", tiles(), "")

local labels = {}
for _, row in ipairs(ns.Bags:Grouped()) do
	labels[#labels + 1] = row.heading and ("[" .. row.heading .. "]") or row.name
end
local order = table.concat(labels, " | ")
checkMatch("trade goods lead, cloth together and by name", order, "^%[Trade Goods%] | Linen Cloth | Wool Cloth | %[Consumable%] | Fresh Bread | ")
checkMatch("arrows under projectiles", order, "%[Projectile%] | Rough Arrow")
checkMatch("a kind the game cannot name goes last, as Other", order, "%[Other%] | Odd Thing$")

local arrows
for _, row in ipairs(ns.Bags:Grouped()) do
	if row.name == "Rough Arrow" then
		arrows = row
	end
end
check("one row per item, its stacks added up", arrows.total, 390)

local function rowFor(match)
	return Frames(function(frame)
		return frame.data ~= nil and frame.scripts.OnMouseUp ~= nil and match(frame.data)
	end)[1]
end
local arrowRow = rowFor(function(data) return data.name == "Rough Arrow" end)
checkTrue("the list shows it", arrowRow ~= nil)
arrowRow.scripts.OnMouseUp(arrowRow)
check("clicking it picks it to sell", ns.Bags:Find("3001:Rough Arrow") ~= nil and arrowRow.selected:IsShown(), true)
local heading = rowFor(function(data) return data.heading == "Consumable" end)
heading.scripts.OnMouseUp(heading)
check("a heading cannot be picked", arrowRow.selected:IsShown(), true)

-- Filters: only one kind at a time.
local function shownOrder()
	local list = {}
	for _, frame in ipairs(Frames(function(frame)
		local data = frame.data
		return data ~= nil and frame.scripts.OnMouseUp ~= nil and (data.heading ~= nil or data.slots ~= nil)
	end)) do
		list[#list + 1] = frame.data.heading and ("[" .. frame.data.heading .. "]") or frame.data.name
	end
	return table.concat(list, " | ")
end
local trade = ButtonNamed("Trade")
trade.scripts.OnClick(trade)
check("Trade shows trade goods only", shownOrder(), "[Trade Goods] | Linen Cloth | Wool Cloth")
local use = ButtonNamed("Take")
use.scripts.OnClick(use)
check("Take shows consumables and ammunition", shownOrder(), "[Consumable] | Fresh Bread | [Projectile] | Rough Arrow")
check("the filter is kept for the character", ns.charDb.sellBags.filter, "use")
local all = ButtonNamed("All")
all.scripts.OnClick(all)

-- Sorting by count puts the biggest first, within each group.
ns.charDb.sellBags.sort = { field = "total", descending = true }
ns.Window:RefreshActive()
checkMatch("cloth by count, most first", shownOrder(), "^%[Trade Goods%] | Wool Cloth | Linen Cloth")


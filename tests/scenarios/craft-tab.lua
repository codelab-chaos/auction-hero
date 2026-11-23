-- The Craft tab: each recipe you know, what it sells for, what its materials
-- cost, the profit, how many you hold the materials for, and what to buy.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("buy")

-- Two items from the scan: one to make, one as its material.
local made, material
for _, item in pairs(ns.Analysis.market.byKey) do
	if item.units > 0 and item.min then
		if not made or item.min > made.min then
			made = item
		end
		if not material or item.min < material.min then
			material = item
		end
	end
end
checkTrue("the scan has items to price with", made ~= nil and material ~= nil and made ~= material)
C_Item.GetItemNameByID = function(id)
	if id == made.itemID then return made.name end
	if id == material.itemID then return material.name end
	return "item " .. id
end

ns.charDb.recipeBook = {
	Leatherworking = { skill = 50, maxSkill = 75, icon = 133611, recipes = {
		[1] = { name = "Make It", icon = 1, itemID = made.itemID, quantityMin = 1, quantityMax = 1,
			reagents = { { itemID = material.itemID, count = 3 } } },
		[3] = { name = "Skill Thing", icon = 1, itemID = material.itemID, quantityMin = 1, quantityMax = 1,
			difficulty = 0, skillUps = 1, reagents = { { itemID = made.itemID, count = 1 } } },
		[2] = { name = "Vendor Thing", icon = 1, itemID = made.itemID, quantityMin = 1, quantityMax = 1,
			reagents = { { itemID = 77777, count = 1 } } },
	} },
	Fishing = { skill = 1, recipes = {} },
}
MOCK.bagCounts = { [material.itemID] = 7 }

local rows = ns.CraftPlan:Rows()
local byName = {}
for _, row in ipairs(rows) do
	byName[row.name] = row
end
local row = byName["Make It"]
check("it sells for the lowest asking price", row.sale, made.min)
check("its materials cost three of the material", row.cost, material.min * 3)
check("held materials are free: the profit is the whole sale", row.profit, made.min)
check("against selling the materials, it is the difference", row.vsMats, made.min - material.min * 3)
check("seven held makes two", row.canMake, 2)
check("nothing is left to buy", row.toBuy, 0)
local skill = byName["Skill Thing"]
check("a sure skill-up that loses against its raw goods prices its point", skill.pointCost, made.min - material.min)
check("a recipe without a sure skill-up has no point price", row.pointCost, nil)
check("making beats selling the raw goods: Make", row.verdict.id, "make")
check("a sure skill-up at a loss: Level up, at the point's price", skill.verdict.id, "level")
local vendor = byName["Vendor Thing"]
check("a material with no auction price leaves the cost open", vendor.unpriced, 1)
check("and no comparison with selling them is claimed", vendor.vsMats, nil)
check("nor a profit, since it is not held and has no price", vendor.profit, nil)
check("with a price missing, the verdict is open", vendor.verdict.id, "unknown")
MOCK.bagCounts[77777] = 1
check("held, a material with no price is free all the same", ns.CraftPlan:Rows()[1] and (function()
	for _, r in ipairs(ns.CraftPlan:Rows()) do
		if r.name == "Vendor Thing" then return r.profit end
	end
end)(), made.min)
MOCK.bagCounts[77777] = nil
check("a profession that makes nothing is not a filter", table.concat(ns.CraftPlan:Professions(), ","), "Leatherworking")

ShowTab("craft")
checkTrue("the tab lists the recipes", #Frames(function(frame)
	return frame.data ~= nil and frame.data.recipeID ~= nil
end) == 3)
local ready = ButtonNamed("Ready to make")
MOCK.bagCounts = {}
ready.scripts.OnClick(ready)
check("ready to make hides what the bags cannot make", #Frames(function(frame)
	return frame.data ~= nil and frame.data.recipeID ~= nil
end), 0)

ready.scripts.OnClick(ready)
local function shown()
	local names = {}
	for _, frame in ipairs(Frames(function(frame)
		return frame.data ~= nil and frame.data.recipeID ~= nil
	end)) do
		names[#names + 1] = frame.data.name
	end
	table.sort(names)
	return table.concat(names, ",")
end
local levels = ButtonNamed("Levels me")
levels.scripts.OnClick(levels)
check("Levels me shows the recipes that still raise the skill", shown(), "Skill Thing")
local make = ButtonNamed("Worth making")
make.scripts.OnClick(make)
check("Worth making shows the ones that beat selling the raw goods", shown(), "Make It")
make.scripts.OnClick(make)
check("pressed again, the filter clears", shown(), "Make It,Skill Thing,Vendor Thing")

-- A profession is an icon, named in its tooltip; All stays a word.
local icons = Frames(function(frame)
	return frame.icon ~= nil and frame.scripts.OnClick ~= nil and frame.label and frame.label.text == ""
end)
checkTrue("a profession shows as its icon", #icons >= 1)
checkTrue("All is still a word", ButtonNamed("All") ~= nil)
checkTrue("no profession name is a button any more", ButtonNamed("Leatherworking") == nil)

-- Make is a green check, Sell raw goods a no-sign.
check("Make shows as a check", ns.CraftVerdicts[1].mark:find("ReadyCheck%-Ready") ~= nil, true)
check("Sell raw goods shows as a no-sign", ns.CraftVerdicts[#ns.CraftVerdicts].mark, "\195\152")

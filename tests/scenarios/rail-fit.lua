-- The Buy tab's rail of quick filters keeps its tiles at the size chosen and
-- scrolls with the mouse wheel when they run taller than the window.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("buy")

local function tiles()
	return Frames(function(frame)
		-- The rail's tiles sit down its middle; the quality squares sit in a row.
		local point = rawget(frame, "lastPoint")
		return frame.__kind == "Button" and frame.onClick ~= nil and frame.tip ~= nil and point ~= nil and point[1] == "TOP"
	end)
end
local all = tiles()
checkTrue("the rail has tiles", #all >= 1)
local content = all[1]:GetParent()
local view = content:GetParent()
local function offset()
	return rawget(content, "lastPoint")[5]
end
local tall = content:GetHeight()

rawset(view, "h", tall + 100)
view.scripts.OnSizeChanged(view)
view.scripts.OnMouseWheel(view, -1)
check("in a tall window there is nothing to scroll", offset(), 0)

rawset(view, "h", tall - 20)
view.scripts.OnSizeChanged(view)
check("in a short one the tiles keep their size", all[#all]:GetWidth(), ns.Theme.tile)
view.scripts.OnMouseWheel(view, -1)
checkTrue("and the wheel moves them up", offset() > 0)
for _ = 1, 20 do
	view.scripts.OnMouseWheel(view, -1)
end
check("no further than the last tile", offset(), 20)
for _ = 1, 20 do
	view.scripts.OnMouseWheel(view, 1)
end
check("and back to the top", offset(), 0)

-- A taller window takes back scrolling it no longer needs.
view.scripts.OnMouseWheel(view, -1)
rawset(view, "h", tall + 100)
view.scripts.OnSizeChanged(view)
check("a taller window puts the tiles back at the top", offset(), 0)

-- The quality swatches: six squares in a row at the top of the category column.
local squares = Frames(function(frame)
	local point = rawget(frame, "lastPoint")
	return frame.__kind == "Button" and frame.onClick ~= nil and frame.tip ~= nil and point ~= nil and point[1] == "TOPLEFT" and frame.fill ~= nil
end)
check("six quality squares", #squares, 6)
for _, square in ipairs(squares) do
	check("each one square", square:GetWidth(), square:GetHeight())
end
check("all in one row", rawget(squares[6], "lastPoint")[5], rawget(squares[1], "lastPoint")[5])
squares[5].scripts.OnClick(squares[5])
Tick(2)
checkTrue("a square ticks its quality", squares[5].mark.shown ~= false)

-- Ranged: a tile for bows, guns, crossbows, wands and thrown weapons, pictured by a bow.
local function weapon(equipLoc, subClassID, icon)
	return { key = icon, name = icon, classID = 2, subClassID = subClassID, equipLoc = equipLoc, icon = icon, listings = 1, units = 1, quality = 2 }
end
local items = {
	weapon("INVTYPE_WEAPON", 7, "sword"),
	weapon("INVTYPE_RANGEDRIGHT", 19, "wand"),
	weapon("INVTYPE_RANGED", 2, "bow"),
	weapon("INVTYPE_THROWN", 16, "knife"),
}
local ranged
for _, facet in ipairs(ns.Facets:Build(items)) do
	for _, option in ipairs(facet.refineOptions or {}) do
		if option.label == "Ranged" then
			ranged = option
		end
	end
end
checkTrue("weapons have a Ranged tile", ranged ~= nil)
check("pictured by a bow", ranged.icon, "bow")
local weapons
for _, facet in ipairs(ns.Facets:Build(items)) do
	if facet.id == "weapons" then
		weapons = facet
	end
end
for _, item in ipairs(items) do
	check(item.icon .. " is " .. (item.icon == "sword" and "not " or "") .. "ranged", weapons.refineRead(item) == "Ranged", item.icon ~= "sword")
end

-- The boxes in an expanded category are alphabetical, however many of each.
local function trinket(equipLoc, subClassID, name, listings)
	return { key = name, name = name, classID = 4, subClassID = subClassID, equipLoc = equipLoc, icon = name, listings = listings, units = listings, quality = 2 }
end
local accessories
for _, facet in ipairs(ns.Facets:Build({
	trinket("INVTYPE_TRINKET", 0, "t", 9),
	trinket("INVTYPE_NECK", 0, "n", 5),
	trinket("INVTYPE_CLOAK", 1, "c", 1),
	trinket("INVTYPE_FINGER", 0, "f", 3),
})) do
	if facet.id == "accessories" then
		accessories = facet
	end
end
local labels = {}
for _, option in ipairs(accessories.options) do
	labels[#labels + 1] = option.label
end
local sorted = { unpack(labels) }
table.sort(sorted)
check("accessories are alphabetical", table.concat(labels, ","), table.concat(sorted, ","))

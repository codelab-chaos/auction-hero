-- The rail's item tiles are in gray until ticked, then in their own colors.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("buy")

local function itemTiles()
	return Frames(function(frame)
		local point = rawget(frame, "lastPoint")
		return frame.__kind == "Button" and frame.onClick ~= nil and frame.tip ~= nil and point ~= nil and point[1] == "TOP"
			and frame.art ~= nil and frame.art:IsShown() and frame.mark ~= nil
	end)
end
local tiles = itemTiles()
checkTrue("the rail has item tiles", #tiles >= 1)
local tile = tiles[1]
local tip = tile.tip
checkTrue("an item tile not ticked is gray", tile.art:IsDesaturated())
tile.scripts.OnClick(tile)
Tick(5)
for _, again in ipairs(itemTiles()) do
	if again.tip == tip then tile = again end
end
checkTrue("ticked, it is in color", not tile.art:IsDesaturated())
check("and shown in full", rawget(tile.art, "alpha") or 1, 1)

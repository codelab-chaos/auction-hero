-- The Quantity and Auctions sliders have a box to type the number into.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("sell")

local tile = Frames(function(frame)
	return frame.slot ~= nil and frame.scripts.OnClick ~= nil and frame.slot.item and frame.slot.item.name == "Light Leather"
end)[1]
checkTrue("the leather is in the bags", tile ~= nil)
tile.scripts.OnClick(tile)
Tick(5)

local box = Frames(function(frame)
	return frame.__kind == "EditBox" and frame:GetText() == "53"
end)[1]
checkTrue("the quantity box shows all 53", box ~= nil)
local function type(text)
	box:SetText(text)
	box.scripts.OnTextChanged(box, true)
end
box:SetFocus()
type("2")
type("25")
checkTrue("the box keeps its focus between keys", box:HasFocus())
check("both digits count", box:GetText(), "25")
type("5000")
box:ClearFocus()
box.scripts.OnEditFocusLost(box)
check("more than there are posts what there is", box:GetText(), "53")

-- Typing a quantity of more than one digit: each key redraws the order, and
-- the redraw must not hide the box, which in the game takes its focus and
-- sends the next key to the game instead.
local ns = Boot()
OpenAuctionHouse()
Scan()
MONEY = 10000000
ShowTab("buy")
local market = ns.Analysis.market

local goods
for _, item in pairs(market.byKey) do
	if ns.Orders.IsCommodity(item) and item.units >= 20 and (not goods or item.units > goods.units) then
		goods = item
	end
end
checkTrue("some goods are for sale by the unit, 20 or more", goods ~= nil)

local row = Frames(function(frame)
	return frame.data ~= nil and frame.scripts.OnMouseUp ~= nil and frame.data.key == goods.key
end)[1]
checkTrue("they are in the list", row ~= nil)
row.scripts.OnMouseUp(row)
Tick(20)

local box = Frames(function(frame)
	return frame.__kind == "EditBox" and frame:GetText() == "1"
end)[1]
checkTrue("the quantity box shows 1", box ~= nil)
local function type(text)
	box:SetText(text)
	box.scripts.OnTextChanged(box, true)
end

box:SetFocus()
type("1")
type("15")
checkTrue("the box keeps its focus between keys", box:HasFocus())
check("so both digits count", box:GetText(), "15")
checkTrue("and the order is for 15", #Frames(function(frame)
	return frame.label and tostring(frame.label.text):find("^Buy 15 for") and frame.scripts.OnClick
end) > 0)

type("")
checkTrue("emptying the box to retype keeps its focus", box:HasFocus())
check("and is not read as 1", box:GetText(), "")
type("2")
check("then the new number counts", box:GetText(), "2")

-- Whole stacks in one press: a stack is what one bag slot holds (200 here).
local one = ButtonNamed("1 stack")
checkTrue("goods offer a whole stack", one ~= nil)
checkTrue("and several", ButtonNamed("2 stacks") ~= nil and ButtonNamed("5 stacks") ~= nil)
local five = ButtonNamed("5 stacks")
check("more stacks than are for sale cannot be pressed", five.disabled, goods.units < 1000)
if goods.units >= 200 then
	one.scripts.OnClick(one)
	check("a stack sets the quantity to 200", box:GetText(), "200")
else
	check("a stack more than is for sale cannot be pressed", one.disabled, true)
end

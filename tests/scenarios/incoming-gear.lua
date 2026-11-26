-- Gear bought at the auction house is named beside gear for the same slot, as
-- a reminder of what is on its way in the mail, until it reaches the bags.
local ns = Boot()
OpenAuctionHouse()
Scan()
MONEY = 100000
ShowTab("buy")
local market = ns.Analysis.market

local function itemRow(key)
	return Frames(function(frame)
		return frame.data ~= nil and frame.scripts.OnMouseUp ~= nil and frame.data.key == key
	end)[1]
end
local function select(key)
	local row = itemRow(key)
	row.scripts.OnMouseUp(row)
	Tick(20)
end
local function incomingNote()
	return Frames(function(frame)
		return type(frame.text) == "table" and tostring(frame.text.text):match("^Already bought for this slot, in your mail: ")
	end)[1]
end

local tunic = market.byKey["2006:Tunic of the Bear"]
checkTrue("the tunic is gear", tunic.equipLoc ~= nil)
select(tunic.key)
check("before buying, nothing is incoming", incomingNote(), nil)

-- Buy the tunic.
MOCK.liveNames = { "Tunic of the Bear" }
ns.Buying:Start({ key = tunic.key, itemID = tunic.itemID, name = tunic.name, single = true })
Tick(20)
ns.Buying:Confirm()
Tick(20)
check("bought", ns.Buying.state.phase, "done")
MOCK.liveNames = nil

local bought = ns.Incoming:ForSlot(tunic.equipLoc)
check("it is incoming for its slot", #bought, 1)
check("by name", bought[1].name, "Tunic of the Bear")
checkTrue("nothing is incoming for another slot", #ns.Incoming:ForSlot("INVTYPE_FEET") == 0)
checkTrue("a robe fills the same slot as a chest", #ns.Incoming:ForSlot("INVTYPE_ROBE") == 1)

-- Gear for that slot names it in the order panel.
local other
for key, item in pairs(market.byKey) do
	if key ~= tunic.key and item.equipLoc == tunic.equipLoc then other = item end
end
checkTrue("another item for the same slot is for sale", other ~= nil)
if other then
	select(other.key)
	local note = incomingNote()
	checkTrue("gear for the same slot names what is incoming", note ~= nil)
	checkMatch("with what it cost", note and note.text.text or "", "Tunic of the Bear %(")
end

-- Goods are not gear, and are not incoming.
MOCK_ITEM_CLASS[2003] = { 7, 0 }
check("a trade good is not gear", ns.Incoming:Add({ name = "Not gear", itemID = 2003, amount = 5 }), nil)

-- The list shows what was bought beside gear for that slot, grayed, and
-- hovering it compares the two.
local function incomingCell(key)
	local row = itemRow(key)
	for index, cell in pairs(row.cells) do
		if cell.icon and cell.icon.art.desaturated then
			return row, cell.icon
		end
	end
	return row
end
local BESIDE
ShoppingTooltip1 = CreateFrame("GameTooltip")
rawset(ShoppingTooltip1, "SetHyperlink", function(_, link) BESIDE = { "LINK " .. link } end)
rawset(ShoppingTooltip1, "AddLine", function(_, text) BESIDE[#BESIDE + 1] = text end)
rawset(ShoppingTooltip1, "Hide", function() BESIDE = nil end)
if other then
	local row, icon = incomingCell(other.key)
	checkTrue("gear for the slot shows what was bought, grayed", icon ~= nil and icon.art.shown ~= false)
	local seen
	for x = 100, 900, 4 do
		CURSOR_X = x
		row.scripts.OnEnter(row)
		if BESIDE then
			seen = { tip = TIP, beside = BESIDE }
			break
		end
		row.scripts.OnLeave(row)
	end
	CURSOR_X = nil
	checkTrue("hovering it compares the two", seen ~= nil)
	if seen then
		check("the gear in the row", seen.tip[1], "LINK " .. (other.link or ("item:" .. other.itemID)))
		check("beside what was bought", seen.beside[1], "LINK " .. (tunic.link or ("item:" .. tunic.itemID)))
		checkMatch("with what it cost", seen.beside[2] or "", "^In your mail. Paid ")
		row.scripts.OnLeave(row)
		check("leaving puts both away", BESIDE, nil)
	end
end
local _, own = incomingCell(tunic.key)
checkTrue("the bought gear's own row shows it too", own ~= nil)
ShoppingTooltip1 = nil
ns.Window:RefreshActive()
checkTrue("it is kept with the character, through a reload", ns.charDb.incoming[1] and ns.charDb.incoming[1].name == "Tunic of the Bear")

-- Taken from the mail: it is in the bags, and no longer incoming.
MOCK.bagCounts = { [tunic.itemID] = 1 }
FireEvent("BAG_UPDATE_DELAYED")
check("taken from the mail, it is not incoming", #ns.Incoming:ForSlot(tunic.equipLoc), 0)
check("and is dropped from the saved list", #ns.charDb.incoming, 0)
MOCK.bagCounts = nil

-- Mail is returned after 30 days, so nothing is incoming for longer.
ns.Incoming:Add({ name = "Tunic of the Bear", itemID = tunic.itemID, amount = 200, time = GetServerTime() - 31 * 86400 })
FireEvent("BAG_UPDATE_DELAYED")
check("an old purchase is dropped", #ns.Incoming:All(), 0)

-- Only gear this character can wear: leather bought on a mage is not a
-- reminder for anything.
local class = PLAYER.class
PLAYER.class = "MAGE"
check("gear the class cannot wear is not incoming", ns.Incoming:Add({ name = "Tunic of the Bear", itemID = tunic.itemID, amount = 200 }), nil)
PLAYER.class = class

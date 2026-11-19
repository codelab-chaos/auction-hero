-- Gear bought this session is named beside gear for the same slot, as a
-- reminder of what is on its way in the mail. It is not kept past the session.
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
		return type(frame.text) == "table" and tostring(frame.text.text):match("^Bought this session for this slot: ")
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

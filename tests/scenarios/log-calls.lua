-- The log names every request sent to the auction house or the mailbox, and
-- who sent it, so two windows asking at once can be told apart.
local stack = "Interface/AddOns/Blizzard_AuctionHouseUI/Blizzard_AuctionHouseFrame.lua:10: in function <...>"
debugstack = function() return "[C]: in function 'PlaceBid'\n" .. stack end
local ns = Boot()
OpenAuctionHouse()

local function last(event)
	for index = #ns.db.log, 1, -1 do
		if ns.db.log[index].event == event then return ns.db.log[index] end
	end
end

C_AuctionHouse.PlaceBid(42, 500)
local entry = last("call PlaceBid")
checkTrue("a purchase is logged", entry ~= nil)
checkMatch("with the game window that made it", entry and entry.detail or "", '^"Blizzard_AuctionHouseUI", 42, 500')

stack = "Interface/AddOns/AuctionHero/trade/buying.lua:239: in function <...>"
C_AuctionHouse.PlaceBid(43, 600)
checkMatch("and this addon's own", last("call PlaceBid").detail, '^"AuctionHero", 43')

FireEvent("MAIL_FAILED", 7)
checkTrue("mail failures are logged", last("MAIL_FAILED") ~= nil)

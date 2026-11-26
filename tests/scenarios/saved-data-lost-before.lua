-- A version before this one left no mark when its saved file stopped
-- loading: the scans are gone, the character's trades are not. That is told.
AuctionHeroCharDB = { ledger = { { kind = "buy", itemID = 2589, name = "Linen Cloth", quantity = 20, amount = 460, time = 1 } } }
local said = {}
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or {}
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, text)
	said[#said + 1] = strip(text)
	if add then return add(self, text) end
end
local ns = Boot()
Tick(80) -- chat waits a few seconds after login
check("trades and no scans is taken for a lost file", ns.savedProblem, "trades")
local told = false
for _, line in ipairs(said) do
	told = told or line:find("too large for the game to load", 1, true) ~= nil
end
checkTrue("the player is told at login", told)
ShowTab("buy")
local function shown(text)
	return Frames(function(frame)
		local value = type(frame.text) == "table" and frame.text.text or frame.text
		return type(value) == "string" and value:find(text, 1, true) ~= nil
	end)[1]
end
checkTrue("the window says to scan again", shown("press Scan to carry on") ~= nil)
check("and names no copy to keep, there is none", shown("AuctionHero.lua.bak"), nil)

-- It stays so through reloads, until there is a scan again.
FireEvent("PLAYER_LOGOUT")
check("the save is marked", AuctionHeroDB.savedStamp, AuctionHeroCharDB.savedStamp)
said = {}
ns = Boot()
Tick(80)
check("after a reload it is still known", ns.savedProblem, "trades")
check("and the window still says so", ns.savedLost, true)
told = false
for _, line in ipairs(said) do
	told = told or line:find("too large for the game to load", 1, true) ~= nil
end
checkTrue("and it is said again", told)
OpenAuctionHouse()
Scan()
check("a scan ends it", AuctionHeroDB.savedLost, nil)
FireEvent("PLAYER_LOGOUT")
ns = Boot()
check("and it is not said after that", ns.savedProblem, nil)

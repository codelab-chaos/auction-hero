-- A saved file the game could not read arrives as nothing. A character that
-- saved with it is told so, instead of "No scan yet".
AuctionHeroCharDB = { savedStamp = 4 }
local said = {}
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or {}
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, text)
	said[#said + 1] = strip(text)
	if add then return add(self, text) end
end
local ns = Boot()
Tick(80) -- chat waits a few seconds after login
check("the data is known to be lost", ns.savedLost, true)
check("and how", ns.savedProblem, "gone")
local told = false
for _, line in ipairs(said) do
	told = told or line:find("did not load", 1, true) ~= nil
end
checkTrue("the player is told at login", told)
checkTrue("after the line that says which version loaded", said[1]:find("loaded", 1, true) ~= nil)
ShowTab("buy")
local function shown(text)
	return Frames(function(frame)
		local value = type(frame.text) == "table" and frame.text.text or frame.text
		return type(value) == "string" and value:find(text, 1, true) ~= nil
	end)[1]
end
checkTrue("the window says so too", shown("Your saved scans did not load") ~= nil)
check("in place of no scan yet", shown("No scan yet"), nil)

-- A new scan is new data: nothing is lost any more.
OpenAuctionHouse()
Scan()
check("after a scan, nothing is lost", ns.savedLost, false)

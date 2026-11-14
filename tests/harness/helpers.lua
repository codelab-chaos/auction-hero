-- What every scenario uses: checks that fail loudly, and the few steps most
-- scenarios start with.

-- Text as a player reads it, without the game's color codes.
function strip(text)
	return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function check(label, got, want)
	if got ~= want then
		error(("%s: expected %s, got %s"):format(label, tostring(want), tostring(got)), 2)
	end
end

function checkTrue(label, value)
	if not value then
		error(label .. ": expected it to hold, got " .. tostring(value), 2)
	end
end

function checkMatch(label, text, pattern)
	if not tostring(text):find(pattern) then
		error(("%s: expected text matching %q, got %q"):format(label, pattern, tostring(text)), 2)
	end
end

-- Logs in. Returns the addon's shared table.
function Boot()
	FireEvent("ADDON_LOADED", "AuctionHero")
	FireEvent("PLAYER_LOGIN")
	Tick(5)
	return NS
end

function OpenAuctionHouse()
	FireEvent("AUCTION_HOUSE_SHOW")
	Tick(5)
end

-- Runs a full scan to the end: the download, then the work that follows it.
-- It stops stepping as soon as that is done, and gives up after 500 steps.
function Scan()
	SlashCmdList.AUCTIONHERO("scan")
	Tick(5)
	for _ = 1, 100 do
		if not NS.Downloader:IsRunning() and NS.Jobs:IsIdle() then
			break
		end
		Tick(5)
	end
	Tick(5)
end

-- Shows the window on a tab.
function ShowTab(id)
	NS.charDb.tab = id
	SlashCmdList.AUCTIONHERO("")
	if not AuctionHeroCharDB.windowShown then
		SlashCmdList.AUCTIONHERO("")
	end
	Tick(5)
end

-- A frame is on screen only when it and every frame it sits in are shown.
local function OnScreen(frame)
	while frame do
		if frame.shown == false then
			return false
		end
		frame = rawget(frame, "parentFrame")
	end
	return true
end

-- Every frame the addon made that passes the test, ones on screen only.
function Frames(passes)
	local found = {}
	for _, frame in ipairs(ALL_FRAMES()) do
		if OnScreen(frame) and passes(frame) then
			found[#found + 1] = frame
		end
	end
	return found
end

-- The first shown button with this label.
function ButtonNamed(label)
	return Frames(function(frame)
		return frame.label and frame.label.text == label and frame.scripts.OnClick
	end)[1]
end

-- Lets a scenario move the clock by whole days.
do
	local realTime = GetServerTime
	local shift = 0
	function GetServerTime()
		return realTime() + shift
	end
	function SkipTime(seconds)
		shift = shift + seconds
	end
end

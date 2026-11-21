-- While a scan runs, only the tab on screen and Debug can be opened: opening
-- another builds it and reads the market mid-scan. They unlock when it ends.
local ns = Boot()
OpenAuctionHouse()
ns.SetEnabled("debug", true)
ShowTab("buy")

local function tabButton(id)
	return Frames(function(frame)
		return frame.tabId == id
	end)[1]
end
local function press(id)
	local button = tabButton(id)
	button.scripts.OnClick(button)
end

SlashCmdList.AUCTIONHERO("scan")
Tick(1)
checkTrue("a scan is running", ns.Downloader:IsRunning())
check("other tabs are locked", tabButton("sell").disabled, true)
check("the tab on screen is not", tabButton("buy").disabled, false)
check("nor is Debug", tabButton("debug").disabled, false)
press("sell")
check("a locked tab does not open", ns.charDb.tab, "buy")
press("debug")
check("Debug opens mid-scan", ns.charDb.tab, "debug")
check("and Buy, left behind, is locked now", tabButton("buy").disabled, true)

for _ = 1, 400 do
	if not ns.Downloader:IsRunning() then
		break
	end
	Tick(1)
end
checkTrue("the scan ends", not ns.Downloader:IsRunning())
check("and the tabs unlock", tabButton("sell").disabled, false)
press("sell")
check("so they open again", ns.charDb.tab, "sell")

-- The Log view, open while thousands of events arrive, redraws a few times a
-- second, not once per event (that froze the game mid-scan).
press("debug")
ns.charDb.view = "log"
local builds = 0
local build = ns.ViewModel.Build
ns.ViewModel.Build = function(...)
	builds = builds + 1
	return build(...)
end
for index = 1, 2000 do
	ns.EventLog:Note("burst", index)
end
check("a burst of events draws nothing at once", builds, 0)
Tick(20)
checkTrue("then it is drawn a few times, not once per event", builds >= 1 and builds <= 5)
ns.ViewModel.Build = build

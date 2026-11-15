-- The scan shield: while a scan runs it covers the tabs, shows how the scan
-- is going and offers Cancel. It lifts once the new scan is priced.
local ns = Boot()
OpenAuctionHouse()
ShowTab("buy")

local function stage()
	return (ns.ScanShieldState())
end
local function up()
	return select(2, ns.ScanShieldState())
end
local function shows(pattern)
	return #Frames(function(frame)
		return type(frame.text) == "string" and strip(frame.text):find(pattern) ~= nil
	end) > 0
end

check("no shield before a scan", up(), false)

-- A first scan, followed to the end.
SlashCmdList.AUCTIONHERO("scan")
Tick(1)
check("the shield goes up when the scan starts", up(), true)
checkTrue("and says what it is doing", shows("^Scanning the auction house$"))
checkTrue("with each stage listed", shows("^Read the auctions$") and shows("^Fill in item details$"))
checkTrue("and a way out", ButtonNamed("Cancel") ~= nil)
-- The stages go by too fast in a test to catch between ticks, so each is
-- noted as the downloader reports it (after the shield has taken it in).
local seen = {}
ns.Bus:On("DOWNLOAD_STATE", function()
	seen[stage() or "down"] = true
end)
for _ = 1, 400 do
	seen[stage() or "down"] = true
	if not up() then
		break
	end
	Tick(1)
end
checkTrue("it showed the reading", seen.reading)
checkTrue("and the pricing after it", seen.pricing or seen.finished)
checkTrue("then the result", seen.finished)
check("and lifted by itself", up(), false)

-- A second scan, cancelled while it runs: the shield lifts and the last scan stays.
local before = ns.Store:GetSourceSnapshot("replicate").meta.time
SkipTime(16 * 60)
SlashCmdList.AUCTIONHERO("scan")
Tick(1)
check("up again for the next scan", up(), true)
checkTrue("which knows the last scan's size", shows("Last scan: [%d,]+ auctions"))
ButtonNamed("Cancel").scripts.OnClick(ButtonNamed("Cancel"))
for _ = 1, 100 do
	if not ns.Downloader:IsRunning() then
		break
	end
	Tick(1)
end
Tick(2)
check("cancel lifts the shield", up(), false)
check("and keeps the last scan", ns.Store:GetSourceSnapshot("replicate").meta.time, before)

-- Reading the last scan into a market (after a reload or login) shows the
-- same card, titled for reading, and lifts it once the prices are in.
Tick(100)
check("nothing showing before", (ns.ScanShieldState()), nil)
ns.Bus:Fire("SNAPSHOT_CHANGED")
check("reading the scan raises the card", (ns.ScanShieldState()), "pricing")
checkTrue("titled for reading", #Frames(function(frame)
	return frame.text == ns.L.SHIELD_READING_TITLE
end) > 0)
for _ = 1, 100 do
	if ns.Jobs:IsIdle() then break end
	Tick(5)
end
Tick(2)
check("and lifts it once read", (ns.ScanShieldState()), nil)

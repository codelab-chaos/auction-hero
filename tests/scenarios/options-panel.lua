-- The addon's own options panel, and the strip that resizes the filter icons.
Settings = nil -- the game's central options are not used
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("buy")

local function rows()
	return Frames(function(frame)
		return frame.setting ~= nil and frame.box ~= nil
	end)
end
local function ids()
	local list = {}
	for index, row in ipairs(rows()) do
		list[index] = row.setting.id
	end
	table.sort(list)
	return table.concat(list, ",")
end
local function debugHeading()
	return #Frames(function(frame)
		return frame.section ~= nil and frame.setting == nil and frame.numberSetting == nil
	end)
end
local function ids()
	local list = {}
	for index, row in ipairs(rows()) do
		list[index] = row.setting.id
	end
	table.sort(list)
	return table.concat(list, ",")
end
local function debugHeading()
	return #Frames(function(frame)
		return frame.section ~= nil and frame.setting == nil and frame.numberSetting == nil
	end)
end
local options = ButtonNamed("Options")
options.scripts.OnClick(options)
Tick(2)
check("a player sees the everyday switches only", ids(), "buyOnePress,closeAuctionHouse,itemTooltips,openWithAuctionHouse,railLarge,sellBagList,showResell")
-- The settings sit in a scroll, as tall as the rows showing, with a bar
-- saying where the view is when they do not all fit.
local scroll = Frames(function(frame)
	return frame.content ~= nil and frame.contentHeight ~= nil and frame.bar ~= nil
end)[1]
checkTrue("the settings scroll", scroll ~= nil)
checkTrue("as tall as the rows", scroll.contentHeight > 4 * 40)
checkTrue("with a bar when they do not all fit", scroll.bar.shown)
check("and no Debug section", debugHeading(), 0)
checkTrue("the foot of the panel says how much data is kept", #Frames(function(frame)
	return type(frame.text) == "string" and frame.text:find("^Data kept: the last scan %(300 auctions%) and price history for ") ~= nil
end) == 1)
checkTrue("and shows no memory figure", #Frames(function(frame)
	return type(frame.text) == "string" and frame.text:find("MB") ~= nil
end) == 0)
local order = {}
for index, setting in ipairs(ns.Settings) do
	order[index] = setting.id
end
check("in the agreed order", table.concat(order, ","), "openWithAuctionHouse,closeAuctionHouse,itemTooltips,railLarge,showResell,sellBagList,buyOnePress,logEvents,debug")

-- The days of history kept is one of a few lengths.
local function numberRow(id)
	return Frames(function(frame)
		return frame.numberSetting ~= nil and frame.numberSetting.id == id
	end)[1]
end
local daysRow = numberRow("historyDays")
check("the lengths offered", #ns.HistoryRule.dayChoices, 3)
AuctionHeroDB.graphDays = 180
check("a longer length saved before the cap reads as the cap", ns.History:GraphDays(), 30)
AuctionHeroDB.graphDays = nil
local seven = ButtonNamed("7 days")
seven.scripts.OnClick(seven)
check("picking one sets it", ns.History:GraphDays(), 7)
checkTrue("a shorter length warns what goes at the next scan", daysRow.warning.shown and daysRow.warning.text:find("oldest 23 days") ~= nil)
local fourteen = ButtonNamed("14 days")
fourteen.scripts.OnClick(fourteen)
checkTrue("counted from the longest since the last scan", daysRow.warning.text:find("oldest 16 days") ~= nil and daysRow.warning.text:find("Pick 30 again") ~= nil)
local thirty = ButtonNamed("30 days")
thirty.scripts.OnClick(thirty)
checkTrue("going back to it before a scan loses nothing", not daysRow.warning.shown)
ButtonNamed("14 days").scripts.OnClick(ButtonNamed("14 days"))
FireEvent("AUCTION_HOUSE_CLOSED")
OpenAuctionHouse()
SkipTime(16 * 60)
Scan()
check("a scan trims, and the warning goes", ns.History:PendingTrim(), nil)

-- Near level is two numbers on one row, each with arrows.
local range = numberRow("gearRange")
check("under shows the setting", range.low.box.text, tostring(ns.Gear:Offset("below")))
range.low.up.scripts.OnClick(range.low.up)
check("the up arrow adds one", ns.Gear:Offset("below"), 2)
range.high.down.scripts.OnClick(range.high.down)
check("the down arrow takes one", ns.Gear:Offset("above"), 0)
range.high.down.scripts.OnClick(range.high.down)
check("never under nothing", ns.Gear:Offset("above"), 0)
range.high.scripts.OnMouseWheel(range.high, 1)
check("the wheel steps it too", ns.Gear:Offset("above"), 1)
range.low.box.text = "99"
range.low.box.scripts.OnTextChanged(range.low.box, true)
check("typing is held to the most allowed", ns.Gear:Offset("below"), ns.GearLevelRule.max)

-- A row flips its switch.
local tips
for _, row in ipairs(rows()) do
	if row.setting.id == "itemTooltips" then
		tips = row
	end
end
tips.scripts.OnClick(tips)
check("a row flips its switch", ns.IsEnabled("itemTooltips"), false)
check("and shows it", tips.box.mark.shown, false)
tips.scripts.OnClick(tips)
check("and back", ns.IsEnabled("itemTooltips"), true)

-- Turning debug on brings the Debug section in, under its own heading.
SlashCmdList.AUCTIONHERO("debug")
Tick(2)
check("debug on lists the debug switches too", ids(), "buyOnePress,closeAuctionHouse,debug,itemTooltips,logEvents,openWithAuctionHouse,railLarge,sellBagList,showResell")
check("under a Debug heading", debugHeading(), 1)
local debugRow
for _, row in ipairs(rows()) do
	if row.setting.id == "debug" then
		debugRow = row
	end
end
debugRow.scripts.OnClick(debugRow)
check("switching debug off from there", ns.IsEnabled("debug"), false)
check("puts the section away again", debugHeading(), 0)
check("with its switches", ids(), "buyOnePress,closeAuctionHouse,itemTooltips,openWithAuctionHouse,railLarge,sellBagList,showResell")

-- A developer's account keeps the section, whether the Debug tab is on or off.
SlashCmdList.AUCTIONHERO("dev")
Tick(2)
check("dev lists the Debug section with the tab off", debugHeading(), 1)
check("and remembers it in the saved variables", AuctionHeroDB.dev, true)
SlashCmdList.AUCTIONHERO("dev")
Tick(2)
check("dev off puts it away", debugHeading(), 0)
options.scripts.OnClick(options)
check("the button puts the panel away", #rows(), 0)

-- The strip beside the filter rail.
local function tileWidths()
	local widths = {}
	for _, frame in ipairs(Frames(function(frame)
		return frame.onClick ~= nil and frame.tip ~= nil and frame.w ~= nil
	end)) do
		widths[frame.w] = true
	end
	return widths
end
local big = math.floor(ns.Theme.tile * ns.Theme.tileLargeScale + 0.5)
checkTrue("tiles start at the normal size", tileWidths()[ns.Theme.tile])
local strip = Frames(function(frame)
	return frame.arrow ~= nil and frame.scripts.OnClick
end)[1]
strip.scripts.OnClick(strip)
Tick(2)
checkTrue("one click makes them bigger", tileWidths()[big] and not tileWidths()[ns.Theme.tile])
check("the choice is a setting", ns.IsEnabled("railLarge"), true)
strip.scripts.OnClick(strip)
Tick(2)
checkTrue("another click puts them back", tileWidths()[ns.Theme.tile])

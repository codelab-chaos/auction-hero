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
check("a player sees the everyday switches only", ids(), "itemTooltips,openWithAuctionHouse,railLarge")
check("and no Debug section", debugHeading(), 0)
checkTrue("the foot of the panel says how much data is kept", #Frames(function(frame)
	return type(frame.text) == "string" and frame.text:find("^Data kept: .* The last scan %(300 auctions%) and price history for ") ~= nil
end) == 1)
local order = {}
for index, setting in ipairs(ns.Settings) do
	order[index] = setting.id
end
check("in the agreed order", table.concat(order, ","), "openWithAuctionHouse,itemTooltips,railLarge,logEvents,debug")

-- The days of history kept is a number typed into the panel.
local daysRow = Frames(function(frame)
	return frame.numberSetting ~= nil
end)[1]
check("the box shows the days kept", daysRow.input.text, tostring(ns.HistoryRule.graphPoints))
daysRow.Commit("20")
check("typing a number sets it", ns.History:GraphDays(), 20)
daysRow.Commit("9999")
check("held to the most allowed", ns.History:GraphDays(), ns.HistoryRule.graphPointsMax)
daysRow.Commit("15")

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
SlashCmdList.AUCTIONITRO("debug")
Tick(2)
check("debug on lists the debug switches too", ids(), "debug,itemTooltips,logEvents,openWithAuctionHouse,railLarge")
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
check("with its switches", ids(), "itemTooltips,openWithAuctionHouse,railLarge")

-- A developer's account keeps the section, whether the Debug tab is on or off.
SlashCmdList.AUCTIONITRO("dev")
Tick(2)
check("dev lists the Debug section with the tab off", debugHeading(), 1)
check("and remembers it in the saved variables", AuctioNitroDB.dev, true)
SlashCmdList.AUCTIONITRO("dev")
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

-- Numeric columns fit their rendered values, leaving the spare room for names.
local ns = Boot()
OpenAuctionHouse()
Scan()
local market = ns.Analysis.market
local ore = market.byKey["2001:Copper Ore"]
local tunic = market.byKey["2006:Tunic of the Bear"]
ore.units, ore.min, ore.deal = 242087, 3, 99
tunic.min = 12345678 -- a gold price must fit alongside the cheap copper rows
ns.Gear.Gains = function()
	return function(item) return item.displayGain end
end
ShowTab("buy")

local function header(label)
	for _, frame in ipairs(ALL_FRAMES()) do
		if frame.label and type(frame.label.text) == "string"
			and frame.label.text:gsub("^[v%^]  ", "") == label then
			return frame
		end
	end
	error("missing header: " .. label)
end
local name, level, units, price, gain, deal = header("Item"), header("Lvl"), header("For sale"), header("From"), header("Gain"), header("$")
local scrollBox = SCROLLBOX
local panel = scrollBox:GetParent()
scrollBox:SetWidth(420)
ns.charDb.columnWidths.buy.units = 400
ns.charDb.columnWidths.buy.min = 400
ns.charDb.columnWidths.buy.deal = 400
ns.Window:RefreshActive()

check("an empty Gain column disappears", gain:IsShown(), false)
check("without leaving a gap before deals", deal.lastPoint[2], price.lastPoint[2] + price.w + 6)
checkTrue("old dragged widths do not squeeze out item names", name.w >= 100)
local nameWidth = name.w

local function readable()
	for _, heading in ipairs({ level, units, price, gain, deal }) do
		if heading:IsShown() then
			checkTrue("heading fits: " .. heading.label.text, heading.label:GetStringWidth() <= heading.w)
			checkTrue("column stays inside the list", heading.lastPoint[2] + heading.w <= scrollBox:GetWidth())
		end
	end
	for _, row in ipairs(scrollBox.rowsDrawn) do
		for index = 2, #row.cells do
			local cell = row.cells[index]
			if cell.text:IsShown() then
				checkTrue("numeric value fits: " .. strip(cell.text.text), cell.text:GetStringWidth() <= cell.text.w)
			end
			if cell.badge and cell.badge:IsShown() then
				checkTrue("deal badge has room around its label", cell.badge.w >= cell.badgeText:GetStringWidth() + 4)
			end
		end
	end
end
readable()

-- Sorting changes the marker without shifting numeric columns or their values.
local before = { level.lastPoint[2], units.lastPoint[2], price.lastPoint[2], deal.lastPoint[2] }
units:Click()
check("sort marker precedes its heading", units.label.text, "^  For sale")
for index, heading in ipairs({ level, units, price, deal }) do
	check("sorting keeps a column in place", heading.lastPoint[2], before[index])
end
readable()

-- Gain returns when there is an upgrade, then gives its space back afterward.
tunic.displayGain = 123.4
ns.Window:RefreshActive()
check("Gain returns for an upgrade", gain:IsShown(), true)
check("it takes only the space it needs", name.w, nameWidth - gain.w - 6)
readable()
tunic.displayGain = nil
ns.Window:RefreshActive()
check("Gain hides again", gain:IsShown(), false)
check("names get their room back", name.w, nameWidth)
for _, row in ipairs(scrollBox.rowsDrawn) do
	check("reused rows hide the old gain text", row.cells[5].text:IsShown(), false)
end

-- Resizing keeps headers and live row cells aligned.
scrollBox:SetWidth(580)
panel.scripts.OnSizeChanged(panel, 580)
check("only the name grows with the window", name.w - nameWidth, 160)
for _, row in ipairs(scrollBox.rowsDrawn) do
	check("row prices follow their heading", row.cells[4].text.lastPoint[2], price.lastPoint[2])
end
readable()

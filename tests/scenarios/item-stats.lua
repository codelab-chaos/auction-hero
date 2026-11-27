-- Under the Buy button: what the scans show about the chosen item, then
-- every price it is listed at now with how many are at each.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("buy")

local function texts()
	local found = {}
	for _, frame in ipairs(Frames(function(frame)
		return type(frame.text) == "string" and frame.text ~= ""
	end)) do
		found[#found + 1] = strip(frame.text)
	end
	return found
end
local function has(pattern)
	for _, text in ipairs(texts()) do
		if text:find(pattern) then
			return true
		end
	end
	return false
end

checkTrue("nothing is shown until an item is chosen", not has("^For sale now$"))

-- Choose the first row of the list.
local row = Frames(function(frame)
	return frame.data ~= nil and frame.data.key ~= nil and frame.data.tiers ~= nil and frame.scripts.OnMouseUp ~= nil
end)[1]
checkTrue("the list has rows", row ~= nil)
local item = row.data
row.scripts.OnMouseUp(row)
Tick(2)

checkTrue("the scan facts are headed", has("^What the scans show$"))
checkTrue("the tooltip's lines are there", has("^Lowest$") and has("^Last seen$"))
checkTrue("with how much scanning is behind them", has("^Seen in$") and has("^1 scan over 1 day$"))
checkTrue("and the lowest ever, with how many and when", has("^Lowest ever$"))
checkTrue("no ledger lines here", not has("^You paid$"))
checkTrue("the prices for sale now come last", has("^For sale now$"))
checkTrue("with the total", has("^" .. ns.Comma(item.units) .. " in all$"))

-- Every listed price is in the ladder with its count, or summed up as more.
local points = ns.Market.PricePoints(item)
checkTrue("the cheapest price is listed", has("^" .. strip(ns.Money(points[1].unit)):gsub("%p", "%%%0") .. "$"))
local units = 0
for _, point in ipairs(points) do
	units = units + point.units
end
check("price points add up to everything for sale", units, item.units)

-- History now keeps how many were at the lowest price.
local history = ns.History:Points(item.key)
check("a point records the units at the lowest price", history[#history].lowUnits, points[1].units)
local record = ns.History:Get(item.key)
check("and the record keeps it for the lowest ever", record.lou, points[1].units)
checkTrue("with when", record.lot ~= nil)

-- Points saved before that was kept still read.
record.h = "1794500000:150:120:9"
check("an older point has no count", ns.History:Points(item.key)[1].lowUnits, nil)
check("and keeps its numbers", ns.History:Points(item.key)[1].low, 120)

-- The order panel scrolls: in a short window its lines stay inside it.
local view = Frames(function(frame)
	return frame.content ~= nil and frame.contentHeight ~= nil and frame.bar ~= nil
end)[1]
checkTrue("the order panel is a scroll", view ~= nil)
checkTrue("as tall as everything stacked in it", view.contentHeight > 200)

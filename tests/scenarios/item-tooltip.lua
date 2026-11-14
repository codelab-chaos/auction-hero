-- Item tooltips: what the scans and the ledger know, added to any item's tooltip.
local ns = Boot()
OpenAuctionHouse()
Scan()

-- A tooltip that records what is written to it.
local function tooltip(name, link)
	local tip = { lines = {} }
	function tip:GetItem()
		return name, link
	end
	function tip:AddLine(text)
		self.lines[#self.lines + 1] = strip(text)
	end
	function tip:AddDoubleLine(left, right)
		self.lines[#self.lines + 1] = strip(left) .. ": " .. strip(right)
	end
	return tip
end
local function line(tip, label)
	for _, text in ipairs(tip.lines) do
		if text:find("^" .. label .. ": ") then
			return text
		end
	end
end

-- Find an item the scan priced.
local key
for candidate, record in pairs(ns.db.historyByMarket["TestRealm / Alliance"].items) do
	if record.lo < record.hi or not key then
		key = candidate
	end
end
local itemID, name = key:match("^(%d+):(.+)$")
local link = "|cffffffff|Hitem:" .. itemID .. "::::::::1:::::|h[" .. name .. "]|h|r"
local record = ns.History:Get(key)

local tip = tooltip(name, link)
ns.ItemTooltip.OnItem(tip)
check("the block is headed with the addon's name", tip.lines[2], "AuctioNitro")
check("no blended price is quoted", line(tip, "Going rate"), nil)
local live = ns.Analysis.market.byKey[key]
local atLowest, nextUp, atNext = 0, nil, 0
for _, tier in ipairs(live.tiers) do
	if tier.unit == live.min then
		atLowest = atLowest + tier.units
	elseif not nextUp or tier.unit == nextUp then
		nextUp, atNext = tier.unit, atNext + tier.units
	end
end
local function quote(unit, units)
	return strip(ns.Money(unit)) .. "  (" .. ns.Comma(units) .. " of " .. ns.Comma(live.units) .. ")"
end
check("the lowest price, and how many of all for sale are at it", line(tip, "Lowest"), "Lowest: " .. quote(live.min, atLowest))
checkTrue("which is not everything for sale", atLowest < live.units)
check("the next price up, with its count", line(tip, "Next price up"), "Next price up: " .. quote(nextUp, atNext))
check("the last scan to see it, by the clock", line(tip, "Last seen"), "Last seen: just now")

-- Every price quoted is one an auction is listed at.
local listed = {}
for _, tier in ipairs(live.tiers) do
	listed[strip(ns.Money(tier.unit))] = true
end
for _, label in ipairs({ "Lowest", "Next price up", "Most are at" }) do
	local text = line(tip, label)
	if text then
		checkTrue(label .. " quotes a listed price", listed[text:match("^" .. label .. ": (.-)  %(")])
	end
end
check("no trades, no trade lines", line(tip, "You paid"), nil)

-- A recipe's tooltip holds the item it makes, and can name that one as "its
-- item". The prices shown must be the recipe's own, or none.
local function recipeTip(productName, productLink)
	local tip = tooltip(productName, productLink)
	function tip:GetName()
		return "RecipeTip"
	end
	RecipeTipTextLeft1 = { GetText = function()
		return "Blueprint: " .. name
	end }
	return tip
end
local blueprint = "7777:Blueprint: " .. name
ns.db.historyByMarket["TestRealm / Alliance"].items[blueprint] = { u = 5950, m = 6000, lo = 1200, hi = 6000, n = 5, d = 1, f = 1, l = 1, h = "1794500000:6000:1200:7" }
tip = recipeTip(name, link)
ns.ItemTooltip.OnItem(tip)
check("a recipe that cannot be told from its product shows nothing", #tip.lines, 0)
tip = recipeTip(name, link)
ns.ItemTooltip.OnItem(tip, { id = 7777 })
check("told which item it is, it shows the recipe's own prices", line(tip, "Lowest"), "Lowest: " .. strip(ns.Money(1200)) .. "  (7 for sale then)")
local count = #tip.lines
ns.ItemTooltip.OnItem(tip, { id = 7777 })
check("a tooltip filled twice gets one block", #tip.lines, count)

-- An item nothing is known about is left alone.
local unknown = tooltip("Thing Nobody Sells", "|Hitem:9999::::|h[Thing Nobody Sells]|h")
ns.ItemTooltip.OnItem(unknown)
check("nothing is added for an unknown item", #unknown.lines, 0)
local notItem = tooltip(nil, nil)
ns.ItemTooltip.OnItem(notItem)
check("nor for a tooltip with no item", #notItem.lines, 0)

-- The ledger adds what you paid and what you last sold at.
ns.Ledger:Add({ kind = "buy", name = name, itemID = tonumber(itemID), quantity = 4, amount = 400 })
ns.Ledger:Add({ kind = "sale", name = name, quantity = 1, amount = 150 })
tip = tooltip(name, link)
ns.ItemTooltip.OnItem(tip)
checkMatch("what the unsold units cost", line(tip, "You paid"), "1s 0c each  %(3 unsold%)")
checkMatch("what the last sale paid", line(tip, "You last sold at"), "1s 50c")

-- It can be switched off.
ns.db.switches.itemTooltips = false
tip = tooltip(name, link)
ns.ItemTooltip.OnItem(tip)
check("switched off, nothing is added", #tip.lines, 0)

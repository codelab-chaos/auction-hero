-- Item tooltips: adds what Auction Hero knows about an item to its tooltip,
-- anywhere in the game. Which lines, and in what order, is ns.TooltipLines in
-- data\tooltip.lua. This file only finds the item and writes the lines.
local _, ns = ...
local L = ns.L
local C = ns.Theme.color

local ItemTooltip = {}
ns.ItemTooltip = ItemTooltip

-- The lines for an item, as { label, text } pairs. Empty when nothing is known.
-- rules is the list to work through (ns.TooltipLines when left out). With
-- scansOnly, lines that come from the ledger are left out.
function ItemTooltip:Lines(itemID, name, rules, scansOnly)
	local key = itemID .. ":" .. name
	local points = ns.History:Points(key)
	local info = {
		record = ns.History:Get(key),
		last = points[#points],
		now = GetServerTime(),
		typicalLow = ns.History:TypicalLow(key),
		trades = ns.Ledger:Item(name),
		live = ns.Analysis and ns.Analysis.market and ns.Analysis.market.byKey[key],
	}
	local lines = {}
	for _, rule in ipairs(rules or ns.TooltipLines) do
		local text = not (scansOnly and rule.trades) and rule.text(info)
		if text then
			lines[#lines + 1] = { rule.label, text }
		end
	end
	return lines
end

-- The name at the top of the tooltip: the item the player is looking at.
local function Title(tooltip)
	local frameName = tooltip.GetName and tooltip:GetName()
	local line = frameName and _G[frameName .. "TextLeft1"]
	local text = line and line:GetText()
	return text ~= "" and text or nil
end

-- The item a tooltip is showing. Older and newer clients ask differently.
--
-- A recipe's tooltip holds a second item inside it, the thing the recipe
-- makes, and asking the tooltip for "its item" can answer with that one. So
-- the name is always taken from the top line, and the id from what the game
-- handed over (data) when it did. When the two sources name different items
-- and the id cannot be told, nothing is shown: no prices beat another item's.
local function Shown(tooltip, data)
	local name, link
	if tooltip.GetItem then
		name, link = tooltip:GetItem()
	end
	if not link and TooltipUtil and TooltipUtil.GetDisplayedItem then
		name, link = TooltipUtil.GetDisplayedItem(tooltip)
	end
	local itemID = link and tonumber(link:match("item:(%d+)"))
	local title = Title(tooltip)
	local given = data and data.id
	if title and name and title ~= name then
		if not given then
			return nil
		end
		name = title
	end
	itemID = given or itemID
	if itemID and name and name ~= "" then
		return itemID, name
	end
end

-- data is what newer clients pass along with the tooltip: { id = item id }.
function ItemTooltip.OnItem(tooltip, data)
	if not (ns.db and ns.IsEnabled("itemTooltips")) then
		return
	end
	-- A recipe's tooltip is filled twice. One block is enough.
	if tooltip.auctionHeroAdded then
		return
	end
	local itemID, name = Shown(tooltip, data)
	if not itemID then
		return
	end
	local lines = ItemTooltip:Lines(itemID, name)
	if #lines == 0 then
		return
	end
	tooltip.auctionHeroAdded = true
	local label, value = C.muted, C.text
	tooltip:AddLine(" ")
	tooltip:AddLine(L.TITLE, C.accent[1], C.accent[2], C.accent[3])
	for _, line in ipairs(lines) do
		tooltip:AddDoubleLine(line[1], line[2], label[1], label[2], label[3], value[1], value[2], value[3])
	end
end

local function Ours(tooltip)
	return tooltip == GameTooltip or tooltip == ItemRefTooltip
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if Ours(tooltip) then
			ItemTooltip.OnItem(tooltip, data)
		end
	end)
else
	for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
		if tooltip and tooltip.HookScript then
			pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", ItemTooltip.OnItem)
		end
	end
end

-- A tooltip is reused for the next thing hovered, so the mark comes off when
-- it is emptied.
for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
	if tooltip and tooltip.HookScript then
		pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(self)
			self.auctionHeroAdded = nil
		end)
	end
end

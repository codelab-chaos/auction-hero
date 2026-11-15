-- Ledger tab: what this character has bought and sold, and what it made.
-- Two views of the same ledger: added up by item, or every entry as it happened.
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local state = { view = "items", sort = { items = { id = "profit", descending = true }, entries = { id = "time", descending = true } } }
local lists, tiles, toggle = {}, {}, nil

local function Coins(copper)
	return copper ~= 0 and ns.Money(copper) or ""
end

local function Count(units)
	return units ~= 0 and ns.Comma(units) or ""
end

-- A column for one number of a row, sorted by that number.
local function Number(id, label, width, text, color)
	return { id = id, label = label, width = width, align = "RIGHT", color = color, text = function(row)
		return text(row[id])
	end }
end

local function Signed(copper)
	if copper == 0 then
		return ""
	end
	return (copper < 0 and "-" or "") .. ns.Money(math.abs(copper))
end

local function ProfitColor(row)
	return row.profit < 0 and C.bad or C.good
end

local VIEWS = {
	items = {
		id = "ledger-items",
		rows = function()
			return (ns.Ledger:Summary())
		end,
		value = function(row, id)
			return row[id]
		end,
		columns = {
			{ id = "name", label = L.BUY_COL_ITEM, flex = true, text = function(row)
				return row.name
			end },
			Number("bought", L.LEDGER_COL_BOUGHT, 60, Count),
			Number("spent", L.LEDGER_COL_SPENT, 110, Coins),
			Number("sold", L.LEDGER_COL_SOLD, 60, Count),
			Number("earned", L.LEDGER_COL_EARNED, 110, Coins),
			Number("fees", L.LEDGER_COL_FEES, 90, Coins),
			Number("profit", L.LEDGER_COL_PROFIT, 110, Signed, ProfitColor),
			Number("held", L.LEDGER_COL_HELD, 60, Count),
		},
	},
	entries = {
		id = "ledger-entries",
		rows = function()
			local rows = {}
			for index, entry in ipairs(ns.Ledger:Entries()) do
				rows[index] = entry
			end
			return rows
		end,
		value = function(entry, id)
			if id == "amount" then
				return entry.amount * ns.LedgerKinds[entry.kind].sign
			end
			return entry[id]
		end,
		columns = {
			{ id = "time", label = L.LEDGER_COL_WHEN, width = 110, text = function(entry)
				return date("%b %d %H:%M", entry.time)
			end },
			{ id = "kind", label = L.LEDGER_COL_WHAT, width = 80, text = function(entry)
				return ns.LedgerKinds[entry.kind].label
			end },
			{ id = "name", label = L.BUY_COL_ITEM, flex = true, text = function(entry)
				return entry.name
			end },
			Number("quantity", L.AUCTIONS_COL_QUANTITY, 60, Count),
			{
				id = "amount",
				label = L.LEDGER_COL_GOLD,
				width = 120,
				align = "RIGHT",
				text = function(entry)
					return Signed(entry.amount * ns.LedgerKinds[entry.kind].sign)
				end,
				color = function(entry)
					return ns.LedgerKinds[entry.kind].sign < 0 and C.bad or C.good
				end,
			},
		},
	},
}

local function Refresh()
	local view = VIEWS[state.view]
	local sort = state.sort[state.view]
	local rows = view.rows()
	Kit.SortRows(rows, function(row)
		return view.value(row, sort.id)
	end, sort.descending)
	for id, list in pairs(lists) do
		list:SetShown(id == state.view)
	end
	local list = lists[state.view]
	list:SetSort(sort.id, sort.descending)
	list:SetRows(rows, true)
	toggle:SetLabel(state.view == "items" and L.LEDGER_SHOW_ENTRIES or L.LEDGER_SHOW_ITEMS)

	local _, totals = ns.Ledger:Summary()
	for index, spec in ipairs(ns.LedgerTiles) do
		local tile, amount = tiles[index], totals[spec.value] or 0
		if spec.signed then
			tile.value:SetText((amount > 0 and "+" or "") .. (amount ~= 0 and Signed(amount) or ns.Money(0)))
			tile.value:SetTextColor(unpack(amount < 0 and C.bad or amount > 0 and C.good or C.text))
		else
			tile.value:SetText(ns.Money(amount))
		end
		if spec.count then
			tile.line:SetText(spec.line:format(ns.Comma(totals[spec.count] or 0)))
		end
	end
end

-- One tile of the totals: a small label, the amount under it, and a line
-- under that when the tile has a count. Hover for what it means.
local function Tile(parent, spec)
	local tile = CreateFrame("Frame", nil, parent)
	tile:SetSize(spec.headline and Theme.ledgerTile.headline or Theme.ledgerTile.width, Theme.ledgerTile.height)
	tile.label = Kit.Text(tile, "small", C.muted)
	tile.label:SetPoint("TOPLEFT", 0, -2)
	tile.label:SetText(spec.label:upper())
	tile.value = Kit.Text(tile, spec.headline and "total" or "large", C.text)
	tile.value:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -4)
	tile.line = Kit.Text(tile, "small", C.muted)
	tile.line:SetPoint("TOPLEFT", tile.value, "BOTTOMLEFT", 0, -3)
	tile:EnableMouse(true)
	Kit.Tip(tile, { spec.label, spec.tip })
	return tile
end

local function Create(parent)
	-- The totals sit under the list, as its footing.
	local bar = Kit.Panel(parent)
	bar:SetPoint("BOTTOMLEFT")
	bar:SetPoint("BOTTOMRIGHT")
	bar:SetHeight(Theme.ledgerTile.height + 16)
	-- The totals, as tiles with a thin rule between them.
	local x = 14
	for index, spec in ipairs(ns.LedgerTiles) do
		local tile = Tile(bar, spec)
		tile:SetPoint("TOPLEFT", x, -8)
		tiles[index] = tile
		x = x + tile:GetWidth()
		if index < #ns.LedgerTiles then
			local rule = bar:CreateTexture(nil, "ARTWORK")
			rule:SetColorTexture(unpack(C.line))
			rule:SetSize(1, Theme.ledgerTile.height - 6)
			rule:SetPoint("TOPLEFT", x, -11)
			x = x + Theme.ledgerTile.gap
		end
	end
	toggle = Kit.Button(bar, { text = L.LEDGER_SHOW_ENTRIES, padding = 16, tip = { L.TAB_LEDGER, L.LEDGER_TIP }, onClick = function()
		state.view = state.view == "items" and "entries" or "items"
		Refresh()
	end })
	toggle:SetPoint("RIGHT", -6, 0)

	for id, view in pairs(VIEWS) do
		local list = Kit.List(parent, {
			id = view.id,
			columns = view.columns,
			empty = L.LEDGER_NONE,
			onSort = function(column)
				local sort = state.sort[id]
				if sort.id == column then
					sort.descending = not sort.descending
				else
					state.sort[id] = { id = column, descending = column ~= "name" and column ~= "kind" }
				end
				Refresh()
			end,
		})
		list:SetPoint("TOPLEFT")
		list:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 6)
		lists[id] = list
	end
	return { Refresh = Refresh }
end

ns.Window:RegisterTab({ id = "ledger", label = L.TAB_LEDGER, order = 5, Create = Create })

ns.Bus:On("LEDGER_CHANGED", function()
	if #tiles > 0 and ns.charDb.tab == "ledger" then
		ns.Window:RefreshActive()
	end
end)

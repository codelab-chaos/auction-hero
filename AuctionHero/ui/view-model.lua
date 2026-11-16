-- View model: turns the snapshot, the analysis and the log into what the panel
-- draws. The panel never reads the store itself.
--
-- ViewModel:Build(viewId, state) returns a model:
--   columns    the column list to draw (from data\views.lua)
--   elements   one entry per row to draw
--   Cell(element, column)  the text for one cell
--   Tip(element)           nil, or { title, link, lines = {...} } for the tooltip
--   Sort(element, field)   the value a column sorts by
--   info       text for the line next to the filter box
--   empty      text to show when there are no elements
-- state is { search = "text", itemKey = "key" | nil }.
local _, ns = ...
local L = ns.L

local ViewModel = {}
ns.ViewModel = ViewModel

-- ========= Formats ==========================================================
-- Format[name](value, element, context) -> text. context is the snapshot's
-- { meta, totals } so a format can relate a value to the whole.
local function QualityName(quality)
	return quality and _G["ITEM_QUALITY" .. quality .. "_DESC"] or L.UNKNOWN
end

local function QualityColor(quality, text)
	local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color and color.hex then
		return color.hex .. text .. "|r"
	end
	return text
end

local Format = {}
ns.Format = Format

function Format.text(value)
	if value == nil then
		return ""
	end
	return tostring(value)
end

Format.plain = Format.text

function Format.number(value)
	return value and ns.Comma(value) or ""
end

function Format.money(value)
	return ns.Money(value)
end

function Format.moneyOrBlank(value)
	if not value or value == 0 then
		return ""
	end
	return ns.Money(value)
end

function Format.percent(value)
	return value and ("%d%%"):format(value) or ""
end

function Format.date(value)
	return value and date("%Y-%m-%d %H:%M", value) or ""
end

function Format.duration(value)
	return value and ns.Duration(value) or ""
end

-- A count with its share of all rows: "1,234 (12%)"
function Format.share(value, _, context)
	if not value then
		return ""
	end
	local rows = context.totals.rows
	if rows == 0 then
		return ns.Comma(value)
	end
	return ("%s (%d%%)"):format(ns.Comma(value), math.floor(value / rows * 100 + 0.5))
end

function Format.returns(value, _, context)
	if not value then
		return ""
	end
	local expected = ns.Schemas[context.meta.schema].native
	if expected and value ~= expected then
		return "|cffff4040" .. L.SUM_RETURNS_MISMATCH:format(value, expected) .. "|r"
	end
	return tostring(value)
end

function Format.priceNote(value)
	return value and L.SUM_PRICE_PER_STACK or L.SUM_PRICE_PER_UNIT
end

function Format.itemName(value, element)
	return QualityColor(element.quality, value or ("item:" .. tostring(element.key)))
end

-- ========= Group labels =====================================================
-- How to name the keys of each breakdown from the derive step.
local KIND_LABELS = {
	commodity = L.KIND_COMMODITY,
	equipment = L.KIND_EQUIPMENT,
	pet = L.KIND_PET,
	other = L.KIND_OTHER,
}

local GroupLabel = {
	quality = function(key)
		return QualityColor(key, QualityName(key))
	end,
	timeLeft = function(key)
		return L.TIME_BAND:format(tostring(key))
	end,
	stack = function(key)
		local buckets = ns.StackBuckets
		if key > #buckets then
			return ("%d+"):format(buckets[#buckets] + 1)
		end
		local low = key == 1 and 1 or buckets[key - 1] + 1
		if low == buckets[key] then
			return tostring(low)
		end
		return ("%d to %d"):format(low, buckets[key])
	end,
	kind = function(key)
		return KIND_LABELS[key] or tostring(key)
	end,
}

local function LabelFor(definition, key)
	if key == false then
		return L.UNKNOWN
	end
	local labeler = GroupLabel[definition.by]
	return labeler and labeler(key) or tostring(key)
end

-- ========= Shared helpers ===================================================
local function Matches(text, search)
	if search == "" then
		return true
	end
	return text ~= nil and tostring(text):lower():find(search, 1, true) ~= nil
end

local function Compare(a, b, descending)
	if a == nil or b == nil then
		return b == nil and a ~= nil -- empty values always go last
	end
	if type(a) ~= type(b) then
		a, b = tostring(a), tostring(b)
	end
	if type(a) == "boolean" then
		a, b = a and 1 or 0, b and 1 or 0
	end
	if descending then
		return a > b
	end
	return a < b
end

local function SortElements(elements, sort, read)
	if not sort then
		return
	end
	local field, descending = sort.field, sort.descending
	table.sort(elements, function(a, b)
		return Compare(read(a, field), read(b, field), descending)
	end)
end

local function Cap(elements, limit)
	local total = #elements
	if limit and total > limit then
		for position = total, limit + 1, -1 do
			elements[position] = nil
		end
		return L.INFO_ROWS_CAPPED:format(ns.Comma(limit), ns.Comma(total))
	end
	return L.INFO_ROWS:format(ns.Comma(total))
end

local function ReadField(element, field)
	return element[field]
end

-- The usual cell: the column's format applied to the element's field.
local function CellWith(read, context)
	return function(element, column)
		local format = Format[column.format or "text"] or Format.text
		return format(read(element, column.field), element, context)
	end
end

function ViewModel:SortFor(view)
	return ns.charDb.sort[view.id] or view.defaultSort
end

-- ========= Builders =========================================================
local Builders = {}

function Builders.summary(view, _, snapshot, analysis)
	local context = { meta = snapshot.meta, totals = analysis.derived.totals }
	local source = ns.SourceById[snapshot.meta.source]
	local values = { meta = snapshot.meta, totals = analysis.derived.totals }
	local elements = {}

	for _, section in ipairs(ns.SummarySections) do
		elements[#elements + 1] = { label = section.label, header = true }
		for _, line in ipairs(section.lines) do
			if ns.Derive.Applies(line, source) then
				local value = values[line.from][line.field]
				if not (line.hideZero and value == 0) then
					elements[#elements + 1] = {
						label = line.label,
						value = (Format[line.format] or Format.text)(value, nil, context),
					}
				end
			end
		end
	end

	for _, definition in ipairs(ns.SummaryGroups) do
		local group = analysis.derived.groups[definition.id]
		if group then
			elements[#elements + 1] = { label = definition.label, header = true }
			for _, entry in ipairs(group.entries) do
				elements[#elements + 1] = {
					label = LabelFor(definition, entry.key),
					value = Format.share(entry.count, nil, context),
				}
			end
		end
	end

	return {
		columns = view.columns,
		elements = elements,
		Cell = function(element, column)
			local text = element[column.field] or ""
			if element.header then
				return column.field == "label" and ("|cffffd100" .. text .. "|r") or ""
			end
			return text
		end,
	}
end

-- "string 98%, nil 2%" style list of the types a field held.
local function TypesText(stats)
	local parts = {}
	for kind, count in pairs(stats.types) do
		parts[#parts + 1] = { kind = kind, count = count }
	end
	table.sort(parts, function(a, b)
		return a.count > b.count
	end)
	local texts = {}
	for position, part in ipairs(parts) do
		if #parts == 1 then
			texts[position] = part.kind
		else
			texts[position] = ("%s %d%%"):format(part.kind, math.floor(part.count / stats.total * 100 + 0.5))
		end
	end
	return table.concat(texts, ", ")
end

local function DistinctList(stats, limit)
	local entries = {}
	for value, count in pairs(stats.distinct) do
		entries[#entries + 1] = { value = value, count = count }
	end
	table.sort(entries, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return tostring(a.value) < tostring(b.value)
	end)
	local texts = {}
	for position = 1, math.min(limit, #entries) do
		local entry = entries[position]
		local text = tostring(entry.value)
		if #text > 40 then
			text = text:sub(1, 40) .. "..."
		end
		text = text:gsub("|", "||") -- show links as text instead of rendering them
		texts[position] = ("%s (%s)"):format(text, ns.Comma(entry.count))
	end
	return texts
end

-- One line that says what a field's values look like.
local function ValuesText(stats)
	if stats.filled == 0 then
		return "|cff808080" .. L.NONE .. "|r"
	end
	local few = not stats.overflow and stats.distinctCount <= 6
	if few then
		return table.concat(DistinctList(stats, 6), ", ")
	end
	local count = stats.overflow and L.MANY:format(stats.distinctCount) or L.DISTINCT:format(stats.distinctCount)
	if stats.min then
		return ("%s, %s"):format(L.RANGE:format(ns.Comma(stats.min), ns.Comma(stats.max)), count)
	end
	return ("%s, %s"):format(count, L.EXAMPLES:format(table.concat(DistinctList(stats, 2), ", ")))
end

function Builders.model(view, state, _, analysis)
	local elements = {}
	for _, stats in ipairs(analysis.profile) do
		if Matches(stats.id, state.search) then
			elements[#elements + 1] = {
				position = (not stats.virtual) and stats.position or nil,
				field = stats.virtual and ("|cff80c0ff" .. stats.id .. "|r") or stats.id,
				sortField = stats.id,
				types = TypesText(stats),
				filled = stats.total > 0 and math.floor(stats.filled / stats.total * 100 + 0.5) or 0,
				values = ValuesText(stats),
				stats = stats,
			}
		end
	end
	SortElements(elements, ViewModel:SortFor(view), function(element, field)
		return element[field == "field" and "sortField" or field]
	end)

	return {
		columns = view.columns,
		elements = elements,
		Cell = CellWith(ReadField),
		Tip = function(element)
			local lines = { element.stats.note }
			for _, text in ipairs(DistinctList(element.stats, 12)) do
				lines[#lines + 1] = text
			end
			return { title = element.stats.id, lines = lines }
		end,
		info = L.INFO_ROWS:format(#elements),
	}
end

function Builders.items(view, state, snapshot, analysis)
	local elements = {}
	for _, item in ipairs(analysis.derived.items) do
		if Matches(item.name, state.search) then
			elements[#elements + 1] = item
		end
	end
	SortElements(elements, ViewModel:SortFor(view), ReadField)
	local info = Cap(elements, view.limit)
	local context = { meta = snapshot.meta, totals = analysis.derived.totals }

	return {
		columns = view.columnsBySource[snapshot.meta.source],
		elements = elements,
		Cell = function(element, column)
			if column.field == "kind" then
				return KIND_LABELS[element.kind] or ""
			end
			local format = Format[column.format or "text"] or Format.text
			return format(element[column.field], element, context)
		end,
		Tip = function(element)
			return { title = element.name, link = element.link, itemID = element.itemID, lines = { L.TIP_ITEM_CLICK } }
		end,
		itemKeyOf = function(element)
			return element.key
		end,
		info = info,
	}
end

function Builders.rows(view, state, snapshot, analysis)
	local schema = ns.Schemas[snapshot.meta.schema]
	local source = ns.SourceById[snapshot.meta.source]
	local nameField, qualityField = source.listing.name, source.listing.quality
	local rows = snapshot.rows
	-- Reads one field of a row, wherever the snapshot keeps it.
	local Read = ns.RowReader(snapshot)

	local elements = {}
	local item = state.itemKey and analysis.derived.byKey[state.itemKey]
	if item then
		for _, position in ipairs(item.rows) do
			elements[#elements + 1] = rows[position]
		end
	else
		for position = 1, #rows do
			local row = rows[position]
			if Matches(Read(row, nameField), state.search) then
				elements[#elements + 1] = row
			end
		end
	end
	SortElements(elements, ViewModel:SortFor(view), Read)
	local info = Cap(elements, view.limit)
	if item then
		info = L.INFO_ROWS_FOR:format(ns.Comma(#item.rows), item.name or item.key)
	end

	local itemIdField = source.listing.itemID
	local usual = CellWith(Read)
	local function Cell(row, column)
		if column.format == "rowName" then
			return QualityColor(Read(row, qualityField), Read(row, nameField) or ("item:" .. tostring(Read(row, itemIdField))))
		end
		return usual(row, column)
	end

	return {
		columns = view.columnsBySource[snapshot.meta.source],
		elements = elements,
		Cell = Cell,
		-- The tooltip lists every field kept for the row: the object model, as it is held.
		Tip = function(row)
			local lines = {}
			for _, field in ipairs(schema.fields) do
				if not field.virtual then
					local text = ns.EventLog.Describe(Read(row, field.id), 0)
					lines[#lines + 1] = ("|cffffd100%s|r = %s"):format(field.id, text)
				end
			end
			return { title = Read(row, nameField) or L.UNKNOWN, lines = lines }
		end,
		info = info,
		filteredToItem = item ~= nil,
	}
end

function Builders.log(view, state)
	local elements = {}
	local log = ns.db.log or {}
	for position = #log, 1, -1 do -- newest first
		local entry = log[position]
		if Matches(entry.event, state.search) then
			elements[#elements + 1] = entry
		end
	end
	return {
		columns = view.columns,
		elements = elements,
		Cell = function(element, column)
			if column.field == "event" and element.count then
				return ("%s |cff808080x%d|r"):format(element.event, element.count)
			end
			return element[column.field] or ""
		end,
		Tip = function(element)
			return { title = element.event, lines = { element.detail ~= "" and element.detail or L.NONE } }
		end,
		info = L.INFO_ROWS:format(#elements),
		empty = L.EMPTY_LOG,
	}
end

-- Views that work without a snapshot.
local STANDALONE = { log = true }

function ViewModel:Build(viewId, state)
	local view = ns.ViewById[viewId] or ns.Views[1]
	local snapshot = ns.Store:GetSnapshot()
	local analysis = ns.Analysis

	if not STANDALONE[view.id] and not (snapshot and analysis) then
		return {
			columns = view.columns or view.columnsBySource[snapshot and snapshot.meta.source or ns.Sources[1].id],
			elements = {},
			Cell = function()
				return ""
			end,
			empty = snapshot and L.EMPTY_ANALYZING or L.EMPTY_NO_SNAPSHOT,
		}
	end

	local model = Builders[view.id](view, state, snapshot, analysis)
	model.view = view
	model.empty = model.empty or L.EMPTY_NO_MATCH
	return model
end

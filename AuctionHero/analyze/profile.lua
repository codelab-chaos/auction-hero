-- Profile: measures what each field of a snapshot really holds. For every
-- schema field it counts the Lua types seen, how often it is filled, the range
-- of numbers, and the distinct values while there are few of them.
-- Pure data in, plain tables out. Formatting happens in the view model.
local _, ns = ...

local Profile = {}
ns.Profile = Profile

local MAX_DISTINCT = 40 -- stop tracking distinct values past this many

local function NewStats(position, field)
	return {
		position = position,
		id = field.id,
		note = field.note,
		virtual = field.virtual ~= nil,
		total = 0,
		filled = 0,
		types = {}, -- type name -> count
		distinct = {}, -- value -> count, while there are few
		distinctCount = 0,
		overflow = false, -- true once there were too many distinct values to track
	}
end

local function Observe(stats, value)
	stats.total = stats.total + 1
	local kind = type(value)
	stats.types[kind] = (stats.types[kind] or 0) + 1
	if value == nil then
		return
	end
	stats.filled = stats.filled + 1

	if kind == "number" then
		if not stats.min or value < stats.min then
			stats.min = value
		end
		if not stats.max or value > stats.max then
			stats.max = value
		end
	elseif kind == "string" then
		local length = #value
		if not stats.minLength or length < stats.minLength then
			stats.minLength = length
		end
		if not stats.maxLength or length > stats.maxLength then
			stats.maxLength = length
		end
	elseif kind ~= "boolean" then
		return -- tables and the like are not worth counting by value
	end

	local seen = stats.distinct[value]
	if seen then
		stats.distinct[value] = seen + 1
	elseif stats.distinctCount < MAX_DISTINCT then
		stats.distinct[value] = 1
		stats.distinctCount = stats.distinctCount + 1
	else
		stats.overflow = true
	end
end

-- Returns one stats table per schema field, in schema order.
function Profile:Run(snapshot)
	local schema = ns.Schemas[snapshot.meta.schema]
	local fields = schema.fields
	local get = ns.RowReader(snapshot)
	local all = {}
	for position, field in ipairs(fields) do
		all[position] = NewStats(position, field)
	end

	-- Every field is read the same way, wherever it is kept. A row that stands
	-- for several identical auctions is still looked at once: this measures
	-- what the fields hold, not how many auctions there are.
	for count, row in ipairs(snapshot.rows) do
		for position, field in ipairs(fields) do
			Observe(all[position], get(row, field.id))
		end
		if count % 100 == 0 then
			ns.Breathe()
		end
	end
	return all
end

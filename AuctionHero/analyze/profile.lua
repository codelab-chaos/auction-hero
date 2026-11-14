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
	local index = schema.index
	local fields = schema.fields
	local all = {}
	for position, field in ipairs(fields) do
		all[position] = NewStats(position, field)
	end

	local parse = ns.Links.Parse
	for count, row in ipairs(snapshot.rows) do
		for position, field in ipairs(fields) do
			local value
			if field.virtual then
				value = parse(row[index[field.virtual.from]])[field.virtual.part]
			else
				value = row[position]
			end
			Observe(all[position], value)
		end
		if count % 100 == 0 then
			ns.Breathe()
		end
	end
	return all
end

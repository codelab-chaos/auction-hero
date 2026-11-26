-- Pack: a large table as a few long strings, and back.
--
-- The game saves an addon's data as one Lua file and reads it back as one
-- function, and a Lua function can hold only so many different values
-- (262,143 strings and numbers). A table of a hundred thousand rows passes
-- that, and then nothing in the file loads at all. A string is one value
-- however long it is, so a packed table costs the file a handful.
--
-- A packed table is { packed = 1, array = bool, count = entries, "...", ... }:
-- each string is Lua that returns a part of the table, small enough to be a
-- function of its own. Reading one back is the game's own parser at work.
--
-- Holds no game state and calls nothing of the game's, so it can be tested
-- on its own (tests/unit/pack.lua).
local _, ns = ...

local Pack = {}
ns.Pack = Pack

-- The format written. Another number is not ours to read.
Pack.format = 1
-- Values in one part, at most. Far under what a function can hold, so a part
-- loads whatever its values are, and small enough that a part is a string of
-- a few hundred thousand characters, not millions.
Pack.partValues = 5000

local compile = loadstring or load
local HUGE = math.huge

local Write -- (value, out, at) -> at, values written

local function WriteNumber(value, out, at)
	local text
	if value ~= value then
		text = "(0/0)"
	elseif value == HUGE then
		text = "(1/0)"
	elseif value == -HUGE then
		text = "(-1/0)"
	elseif value % 1 == 0 and value > -1e14 and value < 1e14 then
		text = ("%.0f"):format(value)
	else
		text = ("%.17g"):format(value)
	end
	out[at + 1] = text
	return at + 1
end

local function WriteTable(value, out, at)
	local count = 0
	at = at + 1
	out[at] = "{"
	-- The run from 1 goes without keys, the rest with them.
	local length = #value
	for index = 1, length do
		local used
		at, used = Write(value[index], out, at)
		count = count + used
		at = at + 1
		out[at] = ","
	end
	for key, item in pairs(value) do
		if not (type(key) == "number" and key >= 1 and key <= length and key % 1 == 0) then
			local used
			at = at + 1
			out[at] = "["
			at, used = Write(key, out, at)
			count = count + used
			at = at + 1
			out[at] = "]="
			at, used = Write(item, out, at)
			count = count + used
			at = at + 1
			out[at] = ","
		end
	end
	at = at + 1
	out[at] = "}"
	return at, count
end

function Write(value, out, at)
	local kind = type(value)
	if kind == "number" then
		return WriteNumber(value, out, at), 1
	elseif kind == "string" then
		out[at + 1] = ("%q"):format(value)
		return at + 1, 1
	elseif kind == "boolean" then
		out[at + 1] = value and "true" or "false"
		return at + 1, 0
	elseif kind == "table" then
		return WriteTable(value, out, at)
	elseif value == nil then
		out[at + 1] = "nil"
		return at + 1, 0
	end
	error("cannot pack a " .. kind)
end

-- True for a table whose keys are 1..n and nothing else.
local function IsArray(value)
	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end
	return count == #value, count
end

-- Whether a table packed here reads back here. Asked before anything is
-- packed: where it does not (a game without loadstring), nothing must be.
function Pack.Works()
	if Pack.works == nil then
		local ok, back = pcall(function()
			return Pack.Decode(Pack.Encode({ "a", 2, { b = false } }))
		end)
		Pack.works = ok and back[1] == "a" and back[2] == 2 and back[3].b == false
	end
	return Pack.works
end

-- breathe, when given, is called between parts: packing can be long work.
function Pack.Encode(value, breathe)
	local array, count = IsArray(value)
	local packed = { packed = Pack.format, array = array, count = count }
	local out, at, held = { "return{" }, 1, 0
	local function Close()
		at = at + 1
		out[at] = "}"
		packed[#packed + 1] = table.concat(out, "", 1, at)
		out, at, held = { "return{" }, 1, 0
		if breathe then
			breathe()
		end
	end
	local function Add(key, item)
		local used
		if key ~= nil then
			at = at + 1
			out[at] = "["
			at, used = Write(key, out, at)
			held = held + used
			at = at + 1
			out[at] = "]="
		end
		at, used = Write(item, out, at)
		held = held + used
		at = at + 1
		out[at] = ","
		if held >= Pack.partValues then
			Close()
		end
	end
	if array then
		for index = 1, count do
			Add(nil, value[index])
		end
	else
		for key, item in pairs(value) do
			Add(key, item)
		end
	end
	if held > 0 or at > 1 then
		Close()
	end
	return packed
end

-- Whether two values hold the same thing, all the way down.
function Pack.Same(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		-- Not-a-number is not equal to itself, and is still the same value.
		return a ~= a and b ~= b
	end
	local keys = 0
	for key, item in pairs(a) do
		if not Pack.Same(item, b[key]) then
			return false
		end
		keys = keys + 1
	end
	for _ in pairs(b) do
		keys = keys - 1
	end
	return keys == 0
end

function Pack.IsPacked(value)
	return type(value) == "table" and type(value.packed) == "number" and value.array ~= nil
end

-- The table a packed one holds. An error when it is not ours to read, or a
-- part of it is damaged: half a table is worse than none.
function Pack.Decode(packed, breathe)
	if packed.packed ~= Pack.format then
		error("packed in a format this build does not read: " .. tostring(packed.packed))
	end
	local value, filled = {}, 0
	for index = 1, #packed do
		local read, problem = compile(packed[index])
		if not read then
			error("part " .. index .. " does not read: " .. tostring(problem))
		end
		local part = read()
		if packed.array then
			for at = 1, #part do
				filled = filled + 1
				value[filled] = part[at]
			end
		else
			for key, item in pairs(part) do
				value[key] = item
				filled = filled + 1
			end
		end
		if breathe then
			breathe()
		end
	end
	if filled ~= packed.count then
		error(("%d entries packed, %d read back"):format(packed.count or -1, filled))
	end
	return value
end

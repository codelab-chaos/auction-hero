-- loads: pack.lua
-- Pack: a table as a few strings, and back exactly as it was.
local Pack = NS.Pack

local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b or (a ~= a and b ~= b) end
	for key, value in pairs(a) do
		if not same(value, b[key]) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end
local function round(value)
	return Pack.Decode(Pack.Encode(value))
end

-- Rows of numbers, as a scan keeps them.
local rows = {}
for index = 1, 8000 do
	rows[index] = { index, index % 7, 0, index * 100, 0, 2, 1 }
end
local packed = Pack.Encode(rows)
checkTrue("it says it is packed", Pack.IsPacked(packed))
check("a list is packed as a list", packed.array, true)
check("with how many it holds", packed.count, 8000)
checkTrue("in more than one part once it is long", #packed > 1)
checkTrue("rows come back as they were", same(round(rows), rows))
for index = 1, #packed do
	check("every part is one string", type(packed[index]), "string")
end

-- Text the game's files could trip on, and entries with gaps.
local variants = {
	{ "Tunic of the Bear", 134587, 2, false, 29, "REQ", 7414, "|cnIQ2:|Hitem:7414::::::::10:1482|h[Tunic \"of\" the Bear]|h|r" },
	{ "Back\\slash\nand a new line", 1, nil, nil, 5 },
	{ [1] = "gap", [4] = "after it", name = "named" },
}
checkTrue("text and gaps come back as they were", same(round(variants), variants))

-- A table by key, as price history is kept.
local items = {}
for index = 1, 3000 do
	items[index .. ":Item " .. index] = { u = index, lo = index - 1, h = "1795000000:" .. index .. ":1:2:3" }
end
local byKey = Pack.Encode(items)
check("a table by key is not a list", byKey.array, false)
checkTrue("it comes back as it was", same(round(items), items))

-- Numbers of every sort.
local numbers = { 0, -1, 1795596733, 99999999999, 120.181, 1 / 3, -0.5, math.huge, -math.huge, 2 ^ 53, 1e15 }
local back = round(numbers)
for index, number in ipairs(numbers) do
	check("number " .. index .. " is exact", back[index], number)
end
check("nothing packs to nothing", next(round({})), nil)
check("true and false are kept", round({ a = true, b = false }).b, false)

-- Damage is an error, not half a table.
local broken = Pack.Encode(rows)
broken[2] = broken[2]:sub(1, 40)
check("a damaged part is an error", pcall(Pack.Decode, broken), false)
local short = Pack.Encode(rows)
table.remove(short)
check("a missing part is an error", pcall(Pack.Decode, short), false)
local other = Pack.Encode(rows)
other.packed = 99
check("another format is an error", pcall(Pack.Decode, other), false)
checkTrue("a plain table is not packed", not Pack.IsPacked(rows))
check("packing works here", Pack.Works(), true)

-- Same: what a packed table is checked against before it replaces the plain one.
checkTrue("a table is the same as its copy", Pack.Same({ 1, "a", { b = false } }, { 1, "a", { b = false } }))
check("a changed value is not", Pack.Same({ 1, 2 }, { 1, 3 }), false)
check("a missing entry is not", Pack.Same({ a = 1, b = 2 }, { a = 1 }), false)
check("an added entry is not", Pack.Same({ a = 1 }, { a = 1, b = 2 }), false)
checkTrue("not-a-number is the same as itself", Pack.Same({ 0 / 0 }, { 0 / 0 }))

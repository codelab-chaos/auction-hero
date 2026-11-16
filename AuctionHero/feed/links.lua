-- Links: pulls the parts we care about out of an item link.
-- A link looks like |cff...|Hitem:19019:0:0:0:0:0:0:...|h[Name]|h|r
-- For item links the values after the type are, in order:
--   itemID, enchantID, gem1, gem2, gem3, gem4, suffixID, uniqueID, ...
local _, ns = ...

local Links = {}
ns.Links = Links

local EMPTY = {}

-- Downloads parse the same link several times in a row, so remember the last one.
local lastLink, lastParsed

function Links.Parse(link)
	if type(link) ~= "string" then
		return EMPTY
	end
	if link == lastLink then
		return lastParsed
	end

	local parsed = {}
	local kind, payload = link:match("|H([^:|]+):?([^|]*)|h")
	if kind then
		parsed.type = kind
		local values = {}
		for value in (payload .. ":"):gmatch("([^:]*):") do
			values[#values + 1] = value
		end
		parsed.parts = #values
		parsed.id = tonumber(values[1])
		if kind == "item" then
			parsed.enchant = tonumber(values[2]) or 0
			parsed.suffix = tonumber(values[7]) or 0
		end
	end

	lastLink, lastParsed = link, parsed
	return parsed
end

-- Saved files: reads and writes the game's saved variables files outside the
-- game, with stock Lua 5.1 (the game's Lua). Used by scripts/repack-saved.lua
-- and by the test that checks a saved file against Lua's real limits
-- (tests/lua51/saved-file.lua).
local SavedFile = {}

local function Text(value)
	return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
end

local function Number(value)
	if value % 1 == 0 and value > -1e14 and value < 1e14 then
		return ("%.0f"):format(value)
	end
	return ("%.17g"):format(value)
end

local function Write(value, out)
	local kind = type(value)
	if kind == "table" then
		out[#out + 1] = "{\n"
		local length = #value
		for index = 1, length do
			Write(value[index], out)
			out[#out + 1] = ", -- [" .. index .. "]\n"
		end
		for key, item in pairs(value) do
			if not (type(key) == "number" and key >= 1 and key <= length and key % 1 == 0) then
				out[#out + 1] = "[" .. (type(key) == "string" and Text(key) or Number(key)) .. "] = "
				Write(item, out)
				out[#out + 1] = ",\n"
			end
		end
		out[#out + 1] = "}"
	elseif kind == "string" then
		out[#out + 1] = Text(value)
	elseif kind == "number" then
		out[#out + 1] = Number(value)
	elseif kind == "boolean" then
		out[#out + 1] = value and "true" or "false"
	else
		out[#out + 1] = "nil"
	end
end

-- A variable as the game writes it: lists by place, the rest by key.
function SavedFile.Text(name, value)
	local out = { "\n", name, " = " }
	Write(value, out)
	out[#out + 1] = "\n"
	return table.concat(out)
end

-- A saved file's text with its large tables each made a function of their
-- own, so stock Lua reads it however much it holds. The game cannot do this;
-- it is how a file too large for the game is still read here.
function SavedFile.Roomy(text)
	local out, depth = {}, 0
	for line in text:gmatch("[^\n]*\n?") do
		local bare = line:gsub("%s+$", "")
		if bare:sub(-1) == "{" then
			if depth == 2 or depth == 3 then
				line = bare:sub(1, -2) .. "(function() return {\n"
			end
			depth = depth + 1
		elseif bare:sub(1, 1) == "}" then
			depth = depth - 1
			if depth == 2 or depth == 3 then
				line = "} end)()" .. bare:sub(2) .. "\n"
			end
		end
		out[#out + 1] = line
	end
	return table.concat(out)
end

-- Loads the addon's own modules that need nothing of the game, by path
-- under AuctionHero/. Returns the shared table they fill.
function SavedFile.Addon(root, files)
	local ns = { Bus = { On = function() end } }
	for _, file in ipairs(files) do
		assert(loadfile(root .. "/AuctionHero/" .. file))("AuctionHero", ns)
	end
	return ns
end

return SavedFile

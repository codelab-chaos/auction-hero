-- Saved: gets the saved data ready to be written, and ready to use again.
--
-- Closing packs the large tables (ns.SavedRule.packed) and counts what is
-- left; opening unpacks them. Between the two the rest of the addon sees
-- plain tables and knows nothing of this.
--
-- Holds no game state and calls nothing of the game's, so it can be tested
-- on its own (tests/unit/saved.lua). core.lua calls it when the saved data
-- arrives and before it is written.
local _, ns = ...

local Saved = {}
ns.Saved = Saved

-- id (of ns.SavedRule.purge) -> function(db) that drops some of what it
-- owns, oldest first, and returns whether anything went. Set by the owners.
Saved.purgers = {}

-- Calls visit(parent, key, chain) for every table a path leads to. chain[n]
-- is { parent, key } of the path's nth key, on the way to this table.
local function Each(node, path, at, visit, chain)
	chain = chain or {}
	local key = path[at]
	if type(node) ~= "table" then
		return
	end
	local function Step(name)
		chain[at] = { parent = node, key = name }
		if at == #path then
			if type(node[name]) == "table" then
				visit(node, name, chain)
			end
		else
			Each(node[name], path, at + 1, visit, chain)
		end
	end
	if key == "*" then
		-- The keys first: what is visited may be taken out of the table.
		local names = {}
		for name in pairs(node) do
			names[#names + 1] = name
		end
		for _, name in ipairs(names) do
			if node[name] ~= nil then
				Step(name)
			end
		end
	else
		Step(key)
	end
end

-- Packs every table the paths name, and reads each one back to see that it
-- holds what went in. All of them or none: the packed ones are only put in
-- place once every one is made and checked, so an error leaves the data as
-- it was.
function Saved.Close(db, paths)
	if not ns.Pack.Works() then
		error("packed tables do not read back here")
	end
	local found = {}
	for _, path in ipairs(paths) do
		Each(db, path, 1, function(parent, key)
			if not ns.Pack.IsPacked(parent[key]) then
				found[#found + 1] = { parent = parent, key = key }
			end
		end)
	end
	for _, target in ipairs(found) do
		local plain = target.parent[target.key]
		target.packed = ns.Pack.Encode(plain)
		if not ns.Pack.Same(ns.Pack.Decode(target.packed), plain) then
			error("a packed table did not read back as it went in: " .. tostring(target.key))
		end
	end
	for _, target in ipairs(found) do
		target.parent[target.key] = target.packed
	end
	return #found
end

-- Unpacks every packed table the paths name. One that cannot be read goes,
-- with the whole thing it is a part of (path.whole), and is named in the list
-- returned: { path = "a.b.c", problem = text }.
function Saved.Open(db, paths)
	local failed = {}
	for _, path in ipairs(paths) do
		Each(db, path, 1, function(parent, key, chain)
			if ns.Pack.IsPacked(parent[key]) then
				local ok, value = pcall(ns.Pack.Decode, parent[key])
				if ok then
					parent[key] = value
				else
					local whole = chain[path.whole or #path]
					whole.parent[whole.key] = nil
					failed[#failed + 1] = { path = table.concat(path, "."), problem = tostring(value) }
				end
			end
		end)
	end
	return failed
end

-- Marks a save on both files, the account's and the character's. They are
-- written together, so the marks agree unless one of the files was lost.
function Saved.Stamp(db, charDb)
	local stamp = math.max(db.savedStamp or 0, charDb.savedStamp or 0) + 1
	db.savedStamp = stamp
	charDb.savedStamp = stamp
	return stamp
end

-- What is wrong with the saved data as it arrived, or nil:
--   "unpack"  a packed table could not be read
--   "gone"    this character saved with the account's data, and none came back
--   "older"   what came back is from before this character's last save
--   "trades"  saved before there were marks: trades on record and no scans,
--             which is how a file too large to load leaves things
-- failed is what Saved.Open returned; empty, whether there are no scans and
-- no history; trades, whether this character has trades on record.
function Saved.Problem(db, charDb, failed, empty, trades)
	if #failed > 0 then
		return "unpack"
	end
	if charDb.savedStamp then
		if not db.savedStamp and empty then
			return "gone"
		elseif (db.savedStamp or 0) < charDb.savedStamp then
			return "older"
		end
	elseif not db.savedStamp and empty and trades then
		return "trades"
	end
	return nil
end

-- How many different strings and numbers the game would write for a value:
-- what counts toward the limit. The places of a list (1, 2, 3...) are not
-- written, so they are not counted.
function Saved.Count(value)
	local seen, tables, count = {}, {}, 0
	local function See(item)
		local kind = type(item)
		if kind == "string" or kind == "number" then
			-- A string and a number that print alike are two values.
			local set = seen[kind]
			if not set then
				set = {}
				seen[kind] = set
			end
			if not set[item] then
				set[item] = true
				count = count + 1
			end
		elseif kind == "table" and not tables[item] then
			tables[item] = true
			local length = #item
			for key, inner in pairs(item) do
				if not (type(key) == "number" and key >= 1 and key <= length and key % 1 == 0) then
					See(key)
				end
				See(inner)
			end
		end
	end
	See(value)
	return count
end

-- Cuts the data back until it fits the rule's share of the limit, going
-- through rule.purge in order. Returns the count it ends at and what was
-- dropped from, in order, each id once.
function Saved.Fit(db, rule, purgers)
	purgers = purgers or Saved.purgers
	local budget = rule.limit * rule.share
	local count = Saved.Count(db)
	local dropped = {}
	for _, id in ipairs(rule.purge) do
		local purge = purgers[id]
		local named = false
		while count > budget and purge and purge(db) do
			if not named then
				dropped[#dropped + 1] = id
				named = true
			end
			count = Saved.Count(db)
		end
	end
	return count, dropped
end

-- Data versions: numbers that move whenever data a view shows changes. It
-- holds no game state and calls nothing of the game's, so it can be tested
-- on its own (tests/unit/versions.lua).
--
-- A message in ns.DataEvents (data\events.lua) moves the version of its kind
-- of data and ns.DataVersion, the version of any data (core.lua's Bus:Fire
-- does it). Views read data and never write it, so a view may keep work it
-- did for as long as the versions of what it reads have not moved, and must
-- redo it once they have. ns.DataChanged() moves them by hand, for data
-- changed without a message.
local _, ns = ...

ns.DataVersion = 0
ns.DataVersions = {} -- kind of data -> its version

function ns.DataChanged(kind)
	ns.DataVersion = ns.DataVersion + 1
	if kind then
		ns.DataVersions[kind] = (ns.DataVersions[kind] or 0) + 1
	else
		-- Changed by hand without saying what: every kind moves, and so do
		-- kinds not seen yet (through "*", part of every reading).
		for known in pairs(ns.DataVersions) do
			ns.DataVersions[known] = ns.DataVersions[known] + 1
		end
		ns.DataVersions["*"] = (ns.DataVersions["*"] or 0) + 1
	end
end

-- The versions of the kinds of data a view reads, as one value to compare:
-- it changes when any of them does. Without kinds, every kind counts.
function ns.VersionOf(kinds)
	if not kinds then
		return ns.DataVersion
	end
	local parts = { ns.DataVersions["*"] or 0 }
	for index, kind in ipairs(kinds) do
		parts[index + 1] = ns.DataVersions[kind] or 0
	end
	return table.concat(parts, ":")
end

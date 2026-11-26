-- Place: the market a character trades in, named by realm and faction. Scans
-- and price history are kept by it.
--
-- The game does not always say the realm's name (this client stopped for a
-- while and gave ""). A name once seen is kept with the character, so a
-- blank answer does not start a second market beside the first. A character
-- that only ever saw a blank name trades in the nameless market, and once
-- the name is seen, what was kept there moves under it (PLACE_RENAMED).
local _, ns = ...
local Bus = ns.Bus

local Place = {}
ns.Place = Place

-- The market's name. A blank realm gives " / Horde".
function Place.Name(realm, faction)
	return (realm or "") .. " / " .. (faction or "?")
end

-- The realm name to go by: what the game says, else what it said before.
-- Calls nothing of the game's.
function Place.Realm(given, remembered)
	if given and given ~= "" then
		return given
	end
	return remembered or ""
end

local function Faction()
	return UnitFactionGroup("player") or "?"
end

-- The market this character is in.
function Place:Current()
	local given = GetRealmName()
	local kept = ns.charDb
	if kept then
		if given and given ~= "" then
			kept.realm = given
		elseif not kept.realm then
			kept.blankRealm = true -- it has traded under no name
		end
	end
	return Place.Name(Place.Realm(given, kept and kept.realm), Faction())
end

-- The name is known now, and this character has traded under none: what
-- was kept under the blank name is this market's.
Bus:On("READY", function()
	local kept = ns.charDb
	local current = Place:Current()
	local blank = Place.Name("", Faction())
	if kept.blankRealm and kept.realm and current ~= blank then
		kept.blankRealm = nil
		Bus:Fire("PLACE_RENAMED", blank, current)
	end
end)

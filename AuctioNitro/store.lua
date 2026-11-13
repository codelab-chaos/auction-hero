-- Store: the cache of downloads. It keeps the latest snapshot of each source,
-- so a browse sweep never replaces a full scan, and saves them across reloads.
-- A snapshot is { meta = {...}, rows = { row, row, ... }, items = {...} }.
-- Rows follow the schema named in meta.schema (see data\schemas.lua). items is
-- optional: item id -> { type, subType, equipLoc, classID, subClassID }.
--
-- One snapshot is "active": the one the views show.
--
-- The game only writes saved variables to disk on /reload, logout or exit.
-- Until then a fresh download lives in memory, which IsOnDisk reports.
local _, ns = ...
local Bus = ns.Bus

local Store = {}
ns.Store = Store

local snapshots = {} -- source id -> snapshot
local activeId
local inMemoryOnly = {} -- source id -> true for downloads made this session

function Store:GetSnapshot()
	return snapshots[activeId]
end

-- The sources that have a cached snapshot, in the order of data\sources.lua.
function Store:GetCachedSources()
	local cached = {}
	for _, source in ipairs(ns.Sources) do
		if snapshots[source.id] then
			cached[#cached + 1] = source
		end
	end
	return cached
end

-- "disk" when the active snapshot is in the saved variables file,
-- "memory" when it will be written on the next reload or logout,
-- "never" when the rows are not being saved at all.
function Store:GetSaveState()
	if not snapshots[activeId] then
		return nil
	elseif not inMemoryOnly[activeId] then
		return "disk"
	elseif ns.IsEnabled("persistRows") then
		return "memory"
	end
	return "never"
end

local function Persist()
	local saved = {}
	for id, snapshot in pairs(snapshots) do
		-- A snapshot already on disk stays whole even if the switch was turned off since.
		if ns.IsEnabled("persistRows") or not inMemoryOnly[id] then
			saved[id] = snapshot
		else
			saved[id] = { meta = snapshot.meta }
		end
	end
	ns.db.snapshots = saved
	ns.db.active = activeId
end

local function Newest()
	local best
	for id, snapshot in pairs(snapshots) do
		if not best or (snapshot.meta.time or 0) > (snapshots[best].meta.time or 0) then
			best = id
		end
	end
	return best
end

function Store:SetActive(sourceId)
	if snapshots[sourceId] and sourceId ~= activeId then
		activeId = sourceId
		Persist()
		Bus:Fire("SNAPSHOT_CHANGED")
	end
end

-- Drops the active snapshot and falls back to another cached one, if any.
function Store:Clear()
	if not activeId then
		return
	end
	snapshots[activeId] = nil
	inMemoryOnly[activeId] = nil
	activeId = Newest()
	Persist()
	Bus:Fire("SNAPSHOT_CHANGED")
end

local function IsUsable(saved)
	return type(saved) == "table" and saved.meta and saved.rows and ns.Schemas[saved.meta.schema] ~= nil
end

Bus:On("INIT", function()
	local db = ns.db
	db.snapshots = db.snapshots or {}
	-- Earlier builds kept a single snapshot.
	if db.snapshot then
		if IsUsable(db.snapshot) and not db.snapshots[db.snapshot.meta.source] then
			db.snapshots[db.snapshot.meta.source] = db.snapshot
		end
		db.snapshot = nil
	end

	-- A snapshot saved without its rows has nothing to show.
	for id, saved in pairs(db.snapshots) do
		if IsUsable(saved) and ns.SourceById[id] then
			snapshots[id] = saved
		end
	end
	activeId = snapshots[db.active] and db.active or Newest()
end)

Bus:On("READY", function()
	if activeId then
		Bus:Fire("SNAPSHOT_CHANGED")
	end
end)

Bus:On("DOWNLOAD_FINISHED", function(meta, rows, items)
	snapshots[meta.source] = { meta = meta, rows = rows, items = items }
	inMemoryOnly[meta.source] = true
	activeId = meta.source
	ns.db.lastFetch[meta.source] = meta.time
	Persist()
	Bus:Fire("SNAPSHOT_CHANGED")
end)

Bus:On("SETTING_CHANGED", function(id)
	if id == "persistRows" then
		Persist()
		Bus:Fire("SAVE_STATE_CHANGED")
	end
end)

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

function Store:GetSourceSnapshot(id)
	return snapshots[id]
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
-- "memory" when it will be written on the next reload or logout.
function Store:GetSaveState()
	if not snapshots[activeId] then
		return nil
	end
	return inMemoryOnly[activeId] and "memory" or "disk"
end

-- Saved snapshots this build could not load (an unknown source or schema).
-- They are written back untouched, so a build that does not understand a
-- snapshot can never be the reason it disappears.
local unreadable = {}

local function Persist()
	local saved = {}
	for id, snapshot in pairs(unreadable) do
		saved[id] = snapshot
	end
	-- Snapshots are saved whole. The Buy, Sell and Resell tabs are built from
	-- the rows, so without them a login would start with nothing to show.
	for id, snapshot in pairs(snapshots) do
		saved[id] = snapshot
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

-- Replaces a snapshot's rows for one item id with fresher ones, from a live
-- check of that item. The snapshot is then no longer one moment in time, so
-- it says which items were patched and when: meta.patched is a list of
-- { id, time }, one entry per item, for whoever reads the scan afterwards.
function Store:PatchItem(sourceId, itemID, rows, time, name)
	local snapshot = snapshots[sourceId]
	local schema = snapshot and ns.Schemas[snapshot.meta.schema]
	if not schema or not schema.index.itemID then
		return false
	end
	-- With a name, only that variant of the item is replaced.
	local at, nameAt = schema.index.itemID, schema.index.name
	local kept = {}
	for _, row in ipairs(snapshot.rows) do
		if row[at] ~= itemID or (name and row[nameAt] ~= name) then
			kept[#kept + 1] = row
		end
	end
	for _, row in ipairs(rows) do
		kept[#kept + 1] = row
	end
	snapshot.rows = kept
	local patched = snapshot.meta.patched or {}
	local entry
	for _, known in ipairs(patched) do
		if known.id == itemID then
			entry = known
		end
	end
	if entry then
		entry.time = time
	else
		patched[#patched + 1] = { id = itemID, time = time }
	end
	snapshot.meta.patched = patched
	Persist()
	return true
end

-- There is deliberately no way to clear a snapshot. A new scan replaces the
-- last one of its kind, and that is the only way one goes away.

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
		else
			unreadable[id] = saved
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

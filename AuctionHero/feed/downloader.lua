-- Downloader: runs one fetcher at a time and reports how it goes.
-- It knows nothing about any source beyond the data in data\sources.lua.
--
-- DOWNLOAD_STATE carries a table:
--   phase    "waiting", "reading", "resolving", "done" or "failed"
--   source   the entry from ns.Sources
--   done, total, pass   progress numbers, when the phase has them
--   reason   a locale key, for "failed"
--   count, elapsed      for "done"
local _, ns = ...
local Bus = ns.Bus
local Jobs = ns.Jobs

local Downloader = {}
ns.Downloader = Downloader

local running -- the context of the download in flight

function Downloader:IsRunning()
	return running ~= nil
end

local function Report(source, phase, fields)
	local state = fields or {}
	state.phase = phase
	state.source = source
	Bus:Fire("DOWNLOAD_STATE", state)
end

local function BuildInfoText()
	local version, build, _, interface = GetBuildInfo()
	return ("%s (%s), interface %s"):format(tostring(version), tostring(build), tostring(interface))
end

function Downloader:Start(sourceId)
	local source = ns.SourceById[sourceId]
	local fetch = source and ns.Fetchers[source.id]
	if not fetch then
		return false
	end
	if running then
		Report(source, "failed", { reason = "FAIL_BUSY", keepRunning = true })
		return false
	end
	if not ns.auctionHouseOpen then
		Report(source, "failed", { reason = "SOURCE_NEEDS_AH" })
		return false
	end

	local ctx = { cancelled = false, reason = "FAIL_CANCELLED" }
	function ctx:Progress(phase, done, total, pass)
		Report(source, phase, { done = done, total = total, pass = pass })
	end
	running = ctx
	local startedAt = GetTime()

	local function Fail(reason, detail)
		running = nil
		Report(source, "failed", { reason = reason, detail = detail })
	end

	Jobs:Run(function()
		return fetch(source, ctx)
	end, function(rows, info)
		if not rows then
			Fail(info or "FAIL_CANCELLED")
			return
		end
		running = nil
		info = info or {}
		local meta = {
			source = source.id,
			sourceLabel = source.label,
			schema = source.schema,
			time = GetServerTime(),
			elapsed = GetTime() - startedAt,
			count = #rows,
			place = ("%s / %s"):format(GetRealmName() or "?", UnitFactionGroup("player") or "?"),
			build = BuildInfoText(),
			returns = info.returns,
			incomplete = info.incomplete or 0,
			stale = info.stale,
			timeLeftBands = info.timeLeftBands,
		}
		Bus:Fire("DOWNLOAD_FINISHED", meta, rows, info.items)
		Report(source, "done", { count = meta.count, elapsed = meta.elapsed })
	end, function(message)
		Fail("FAIL_ERROR", message)
	end)
	return true
end

function Downloader:Cancel(reason)
	if running then
		running.cancelled = true
		running.reason = reason or "FAIL_CANCELLED"
	end
end

Bus:On("AH_CLOSED", function()
	Downloader:Cancel("FAIL_CLOSED")
end)

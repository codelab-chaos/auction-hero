-- Event log: records the auction house events the client fires, with a short
-- description of each payload. It is how we learn what the events really carry.
local _, ns = ...
local Bus = ns.Bus

local EventLog = {}
ns.EventLog = EventLog

local MAX_TEXT = 160
local MAX_KEYS = 8

-- A short, readable description of any value.
local function Describe(value, depth)
	local kind = type(value)
	if kind == "string" then
		local text = value
		if #text > MAX_TEXT then
			text = text:sub(1, MAX_TEXT) .. "..."
		end
		-- Doubling the bars shows links as text instead of rendering them.
		return '"' .. text:gsub("|", "||") .. '"'
	elseif kind == "number" or kind == "boolean" or kind == "nil" then
		return tostring(value)
	elseif kind ~= "table" then
		return "<" .. kind .. ">"
	end
	if depth >= 2 then
		return "{...}"
	end

	local length = #value
	if length > 0 then
		return ("[%d] %s"):format(length, Describe(value[1], depth + 1))
	end
	local parts = {}
	for key, inner in pairs(value) do
		if #parts >= MAX_KEYS then
			parts[#parts + 1] = "..."
			break
		end
		parts[#parts + 1] = tostring(key) .. "=" .. Describe(inner, depth + 1)
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end
EventLog.Describe = Describe

local function DescribeArgs(...)
	local count = select("#", ...)
	if count == 0 then
		return ""
	end
	local parts = {}
	for index = 1, count do
		parts[index] = Describe((select(index, ...)), 0)
	end
	return table.concat(parts, ", ")
end

local function Record(event, ...)
	if not ns.IsEnabled("logEvents") then
		return
	end
	local log = ns.db.log
	local last = log[#log]
	local detail = DescribeArgs(...)
	if last and last.event == event and ns.LoggedEventsCollapsed[event] then
		last.count = (last.count or 1) + 1
		last.clock = date("%H:%M:%S")
		last.detail = detail
	else
		log[#log + 1] = { clock = date("%H:%M:%S"), event = event, detail = detail }
		while #log > ns.LogLimit do
			table.remove(log, 1)
		end
	end
	Bus:Fire("LOG_ADDED")
end

-- Adds a line of our own to the log, beside the game's events. Used to record
-- what we asked the game to do, so its answer (or silence) can be read in order.
function EventLog:Note(what, ...)
	Record("> " .. what, ...)
end

-- The whole log as plain text, newest first like the Log view, one line per
-- entry, so the latest lines are at the top and easy to pick out.
function EventLog:Text()
	local lines = {}
	local log = ns.db.log
	for index = #log, 1, -1 do
		local entry = log[index]
		local count = entry.count and (" x" .. entry.count) or ""
		lines[#lines + 1] = ("%s  %s%s  %s"):format(entry.clock, entry.event, count, entry.detail)
	end
	return table.concat(lines, "\n")
end

function EventLog:Clear()
	ns.db.log = {}
	Bus:Fire("LOG_ADDED")
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	Record(event, ...)
end)

Bus:On("INIT", function()
	ns.db.log = ns.db.log or {}
	for _, event in ipairs(ns.LoggedEvents) do
		-- Registering an event the client does not have raises an error.
		pcall(frame.RegisterEvent, frame, event)
	end
end)

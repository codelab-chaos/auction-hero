-- Jobs: runs long work a little each frame so the game never freezes.
-- A job is a plain function. Inside it, call ns.Breathe() in loops and
-- ns.Jobs.Sleep(seconds) to wait. Both are safe to call outside a job too.
local _, ns = ...

local Jobs = {}
ns.Jobs = Jobs

local BUDGET_MS = 8 -- work time allowed per frame

local active = {} -- running job records
local current -- the record being resumed right now
local sliceStart = 0

local driver = CreateFrame("Frame")
driver:Hide()

local function InJob()
	return current ~= nil
end

-- Gives the frame back to the game when this frame's budget is used up.
function ns.Breathe()
	if InJob() and debugprofilestop() - sliceStart > BUDGET_MS then
		coroutine.yield()
	end
end

-- Pauses the job for a number of seconds.
function Jobs.Sleep(seconds)
	if not InJob() then
		return
	end
	current.wakeAt = GetTime() + seconds
	coroutine.yield()
end

local function Finish(record, ok, ...)
	for index = #active, 1, -1 do
		if active[index] == record then
			table.remove(active, index)
		end
	end
	if #active == 0 then
		driver:Hide()
	end
	if ok then
		if record.onDone then
			record.onDone(...)
		end
	elseif record.onError then
		record.onError(...)
	end
end

local function Step(record)
	if record.wakeAt and GetTime() < record.wakeAt then
		return
	end
	record.wakeAt = nil
	current = record
	sliceStart = debugprofilestop()
	local results = { coroutine.resume(record.thread) }
	current = nil
	if not results[1] then
		Finish(record, false, tostring(results[2]))
	elseif coroutine.status(record.thread) == "dead" then
		Finish(record, true, unpack(results, 2, 10))
	end
end

driver:SetScript("OnUpdate", function()
	-- Walk a copy: a job may finish and remove itself while we iterate.
	local snapshot = {}
	for index = 1, #active do
		snapshot[index] = active[index]
	end
	for index = 1, #snapshot do
		Step(snapshot[index])
	end
end)

-- Starts a job. onDone gets the job's return values, onError gets the error text.
function Jobs:Run(work, onDone, onError)
	local record = {
		thread = coroutine.create(work),
		onDone = onDone,
		onError = onError,
	}
	active[#active + 1] = record
	driver:Show()
	return record
end

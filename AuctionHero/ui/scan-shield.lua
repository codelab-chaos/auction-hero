-- The scan shield: while a scan runs it covers the tabs, so nothing can be
-- bought, posted or cancelled against a market that is about to change. It
-- shows how the scan is going (each stage, a bar, the counts, the time) and
-- a Cancel button. It lifts once the new scan has been priced, or at once
-- when the scan fails or is cancelled. The stages are data\scan-shield.lua.
local _, ns = ...
local L, Bus, Kit = ns.L, ns.Bus, ns.Kit
local Theme = ns.Theme
local C = Theme.color
local Rule = ns.ScanShield

local shield, parts
local run -- the scan being shown, nil when the shield is down
local analyzing = false

local stageIndex = {}
for index, stage in ipairs(Rule.stages) do
	stageIndex[stage.id] = index
end

-- ========= Progress =========================================================
-- How far along a stage with no count to go by is: it creeps toward the end
-- and never quite gets there.
local function Creep(seconds)
	return 1 - 0.5 ^ (seconds / Rule.creepHalfSeconds)
end

local function StageShare(now)
	if run.stage == "reading" and run.total and run.total > 0 then
		return (run.done or 0) / run.total
	elseif run.stage == "resolving" and (run.pass or 0) > 0 and run.pendingStart and run.pendingStart > 0 then
		return 1 - (run.done or 0) / run.pendingStart
	end
	return Creep(now - run.stageAt)
end

local function Share(now)
	if run.finishedAt then
		return 1
	end
	local stage = Rule.stages[stageIndex[run.stage]]
	local share = stage.from + (stage.to - stage.from) * math.max(0, math.min(1, StageShare(now)))
	run.shown = math.max(run.shown or 0, share) -- the bar never goes backwards
	return run.shown
end

local function Detail(now)
	if run.finishedAt then
		local result = L.SHIELD_RESULT:format(ns.Comma(run.count or 0), ns.Duration(run.elapsed or 0))
		if run.previous and run.count then
			local change = run.count - run.previous
			local signed = (change < 0 and "-" or "+") .. ns.Comma(math.abs(change))
			result = L.SHIELD_RESULT_CHANGE:format(ns.Comma(run.count), ns.Duration(run.elapsed or 0), signed)
		end
		return result
	elseif run.cancelling then
		return L.SHIELD_CANCELLING
	elseif run.stage == "reading" and run.total then
		local text = L.SHIELD_READING:format(ns.Comma(run.done or 0), ns.Comma(run.total))
		local seconds = now - run.stageAt
		if seconds >= 1 then
			text = text .. "   " .. L.SHIELD_RATE:format(ns.Comma(math.floor((run.done or 0) / seconds)))
		end
		return text
	elseif run.stage == "resolving" then
		return L.SHIELD_RESOLVING:format(ns.Comma(run.done or 0), run.pass or 0)
	elseif run.stage == "pricing" then
		return L.SHIELD_PRICING:format(ns.Comma(run.count or run.total or 0))
	end
	return L.SHIELD_ASKING
end

-- ========= Coin rain ========================================================
-- Where a drop is in its fall (0 at the top, 1 landed): how far down the
-- slot it is, speeding up like a real fall, and how faded it is by then.
local function Drop(share)
	local rain = Rule.coinRain
	local depth = -rain.size + (rain.slot + rain.size) * share * share
	local fadeFrom = 1 - rain.fadeShare
	local alpha = share < fadeFrom and 1 or (1 - share) / rain.fadeShare
	return depth, alpha
end

local function RainCoins(now)
	local rain = Rule.coinRain
	local count = #parts.drops
	for index, drop in ipairs(parts.drops) do
		local share = (now / rain.fallSeconds + (index - 1) / count) % 1
		local depth, alpha = Drop(share)
		drop:ClearAllPoints()
		drop:SetPoint("TOP", parts.chute, "TOP", rain.drops[index].x, -depth)
		drop:SetAlpha(alpha)
	end
end

local function StopRain()
	parts.chute:Hide()
end

-- ========= Painting =========================================================
local function Paint()
	if not shield or not run then
		return
	end
	local now = GetTime()
	local finished = run.finishedAt ~= nil
	parts.title:SetText(finished and L.SHIELD_DONE_TITLE or L.SHIELD_TITLE)
	parts.title:SetTextColor(unpack(finished and C.good or C.accent))

	local current = stageIndex[run.stage] or 1
	for index, row in ipairs(parts.stages) do
		local done = finished or index < current
		local here = not finished and index == current
		row.icon:SetShown(done or here)
		row.icon:SetTexture(done and Rule.stageIcons.done or Rule.stageIcons.current)
		row.text:SetTextColor(unpack(here and C.text or done and C.muted or C.line))
	end

	local share = Share(now)
	parts.fill:SetWidth(math.max(1, math.floor(parts.barWidth * share + 0.5)))
	parts.percent:SetText(("%d%%"):format(math.floor(share * 100)))

	local counted = run.stage == "reading" and run.done or run.count or run.total
	parts.count:SetText(counted and ns.Comma(counted) or "")
	parts.detail:SetText(Detail(now))

	local footer = L.SHIELD_ELAPSED:format(ns.Duration(now - run.startedAt))
	if run.previous then
		footer = footer .. "   " .. L.SHIELD_LAST:format(ns.Comma(run.previous))
	end
	parts.footer:SetText(finished and "" or footer)

	-- Pricing cannot be stopped, and a finished scan has nothing to stop.
	parts.cancel:SetLabel((finished or run.stage == "pricing") and L.SHIELD_CLOSE or L.CANCEL)
	parts.cancel:SetDisabled(run.cancelling == true)
end

local function NextQuip()
	local quips = L.SHIELD_QUIPS
	if #quips == 0 then
		return ""
	end
	run.quip = (run.quip or math.random(#quips) - 1) % #quips + 1
	return quips[run.quip]
end

-- ========= Construction =====================================================
local function Build()
	local body = ns.Window:Body()
	if not body then
		return nil
	end
	shield = CreateFrame("Frame", nil, body)
	shield:SetAllPoints(body)
	shield:SetFrameLevel(body:GetFrameLevel() + 100)
	-- It takes every click and scroll meant for the tab under it.
	shield:EnableMouse(true)
	shield:EnableMouseWheel(true)
	shield:SetScript("OnMouseWheel", function() end)
	local dim = Kit.Fill(shield, C.window)
	dim:SetAlpha(Rule.dim)

	local card = Kit.Panel(shield)
	card:SetSize(Rule.card.width, Rule.card.height)
	card:SetPoint("CENTER")
	Kit.Border(card, C.border)
	card:EnableMouse(true)
	Kit.Tip(card, { L.SHIELD_TITLE, L.SHIELD_TIP })
	parts = {}

	local pad = 16
	parts.coin = card:CreateTexture(nil, "ARTWORK")
	parts.coin:SetSize(32, 32)
	parts.coin:SetPoint("TOPLEFT", pad, -pad)
	parts.coin:SetTexture(Rule.coinIcon)

	-- The coins raining onto the brand coin, clipped to its slot.
	local rain = Rule.coinRain
	parts.chute = CreateFrame("Frame", nil, card)
	parts.chute:SetSize(rain.slot, rain.slot)
	parts.chute:SetPoint("CENTER", parts.coin, "CENTER")
	parts.chute:SetClipsChildren(true)
	parts.drops = {}
	for index, spec in ipairs(rain.drops) do
		local drop = parts.chute:CreateTexture(nil, "OVERLAY")
		drop:SetSize(rain.size, rain.size)
		drop:SetTexture(spec.icon)
		parts.drops[index] = drop
	end

	parts.title = Kit.Text(card, "large", C.accent)
	parts.title:SetPoint("TOPLEFT", parts.coin, "TOPRIGHT", 10, -1)
	parts.quip = Kit.Text(card, "small", C.muted)
	parts.quip:SetPoint("TOPLEFT", parts.title, "BOTTOMLEFT", 0, -4)
	parts.quip:SetPoint("RIGHT", card, "RIGHT", -pad, 0)

	parts.stages = {}
	for index, stage in ipairs(Rule.stages) do
		local y = -(pad + 44 + (index - 1) * 20)
		local icon = card:CreateTexture(nil, "ARTWORK")
		icon:SetSize(14, 14)
		icon:SetPoint("TOPLEFT", pad + 4, y)
		local text = Kit.Text(card, "normal", C.line)
		text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
		text:SetText(stage.label)
		parts.stages[index] = { icon = icon, text = text }
	end

	parts.barWidth = Rule.card.width - pad * 2 - 40
	local barY = -(pad + 44 + #Rule.stages * 20 + 10)
	local track = card:CreateTexture(nil, "ARTWORK")
	track:SetColorTexture(unpack(C.input))
	track:SetSize(parts.barWidth, 12)
	track:SetPoint("TOPLEFT", pad, barY)
	parts.fill = card:CreateTexture(nil, "OVERLAY")
	parts.fill:SetColorTexture(unpack(C.gold))
	parts.fill:SetSize(1, 12)
	parts.fill:SetPoint("TOPLEFT", track, "TOPLEFT")
	parts.percent = Kit.Text(card, "small", C.text, "RIGHT")
	parts.percent:SetPoint("LEFT", track, "RIGHT", 6, 0)
	parts.percent:SetPoint("RIGHT", card, "RIGHT", -pad, 0)

	parts.count = Kit.Text(card, "total", C.text)
	parts.count:SetPoint("TOPLEFT", pad, barY - 22)
	parts.detail = Kit.Text(card, "small", C.muted)
	parts.detail:SetPoint("LEFT", parts.count, "RIGHT", 10, 0)
	parts.detail:SetPoint("RIGHT", card, "RIGHT", -pad, 0)
	parts.footer = Kit.Text(card, "small", C.muted)
	parts.footer:SetPoint("TOPLEFT", pad, barY - 46)

	parts.cancel = Kit.Button(card, {
		text = L.CANCEL,
		width = 120,
		onClick = function()
			if not run then
				return
			end
			if run.finishedAt or run.stage == "pricing" then
				run = nil
				shield:Hide()
				return
			end
			run.cancelling = true
			ns.Downloader:Cancel()
			Paint()
		end,
	})
	parts.cancel:SetPoint("BOTTOM", 0, 14)

	-- The clock, the creeping bar, the coin rain and the quips move here.
	local since, quipAt = 0, 0
	shield:SetScript("OnUpdate", function(_, elapsed)
		if not run then
			return
		end
		local now = GetTime()
		if not run.finishedAt then
			RainCoins(now)
		end
		if now - quipAt >= Rule.quipSeconds then
			quipAt = now
			parts.quip:SetText(run.finishedAt and "" or NextQuip())
		end
		since = since + elapsed
		if since >= 0.1 then
			since = 0
			Paint()
		end
	end)
	shield:Hide()
	return shield
end

-- ========= The scan's life ==================================================
local function Raise(state)
	if not shield and not Build() then
		return
	end
	local snapshot = ns.Store:GetSourceSnapshot(state.source.id)
	local now = GetTime()
	run = {
		source = state.source.id,
		startedAt = now,
		stageAt = now,
		previous = snapshot and snapshot.meta and snapshot.meta.count,
	}
	-- A search box being typed in would keep the keyboard behind the shield.
	local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focus and focus.ClearFocus then
		focus:ClearFocus()
	end
	parts.quip:SetText(NextQuip())
	parts.chute:Show()
	shield:Show()
end

local function Lift()
	run = nil
	if shield then
		shield:Hide()
	end
end

local function Finish()
	run.finishedAt = GetTime()
	parts.quip:SetText("")
	StopRain()
	Paint()
	local mine = run
	C_Timer.After(Rule.doneSeconds, function()
		if run == mine then
			Lift()
		end
	end)
end

local function Enter(stage)
	if run.stage ~= stage then
		run.stage, run.stageAt = stage, GetTime()
	end
end

local ON_STATE = {
	waiting = function()
		Enter("waiting")
	end,
	reading = function(state)
		Enter("reading")
		run.done, run.total = state.done, state.total
	end,
	resolving = function(state)
		Enter("resolving")
		run.done, run.pass = state.done, state.pass
		if (state.pass or 0) > 0 and not run.pendingStart then
			run.pendingStart = state.done
		end
	end,
	done = function(state)
		run.count, run.elapsed = state.count, state.elapsed
		Enter("pricing")
		if not analyzing then
			Finish()
		end
	end,
}

Bus:On("DOWNLOAD_STATE", function(state)
	if state.phase == "failed" then
		-- A second start while one runs is turned away; the first carries on.
		if not state.keepRunning then
			Lift()
		end
		return
	end
	local handle = ON_STATE[state.phase]
	if not handle then
		return
	end
	if not run then
		if state.phase == "done" then
			return
		end
		Raise(state)
		if not run then
			return
		end
	end
	handle(state)
	Paint()
end)

Bus:On("ANALYSIS_STATE", function(running)
	analyzing = running
	if not running and run and run.stage == "pricing" and not run.finishedAt then
		Finish()
	end
end)

-- For tests and the debug tab: whether the shield is up, and its stage.
function ns.ScanShieldState()
	return run and (run.finishedAt and "finished" or run.stage) or nil, shield and shield:IsShown() or false
end

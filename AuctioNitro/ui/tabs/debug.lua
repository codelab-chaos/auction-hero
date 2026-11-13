-- Debug tab: the raw scan views (summary, row model, items, rows) and the
-- event log, for looking at what the game actually sent. It only shows while
-- the debug switch is on: /an debug.
--
-- What each view contains is decided by ui\view-model.lua and data\views.lua.
-- This file only draws the table it is handed.
local _, ns = ...
local L = ns.L
local Kit = ns.Kit
local Theme = ns.Theme
local C = Theme.color

local CONFIRM_SECONDS = 4 -- how long a "press again" stays armed

local state = { search = "", itemKey = nil }
local holder, views, infoText, allRowsButton
local lists = {} -- column list -> the table drawn for it
local model
local Refresh

-- A view model column, as a Kit.List column.
local function ListColumns(columns)
	local out = {}
	for index, column in ipairs(columns) do
		out[index] = {
			id = column.field,
			label = column.label,
			width = column.width,
			flex = column.flex,
			align = column.align,
			sortable = column.sort ~= false,
			text = function(element)
				return model.Cell(element, column)
			end,
		}
	end
	return out
end

local function ListFor(columns)
	local list = lists[columns]
	if not list then
		list = Kit.List(holder, {
			columns = ListColumns(columns),
			rowHeight = 20,
			onClick = function(element)
				-- Clicking an item jumps to its raw rows.
				if model.itemKeyOf then
					state.itemKey = model.itemKeyOf(element)
					ns.charDb.view = "rows"
					Refresh()
				end
			end,
			tip = function(element)
				local tip = model.Tip and model.Tip(element)
				if not tip then
					return nil
				end
				local lines = { tip.title or "" }
				for _, line in ipairs(tip.lines or {}) do
					lines[#lines + 1] = line
				end
				return lines
			end,
			onSort = function(field)
				local view = model.view
				if not view then
					return
				end
				local current = ns.ViewModel:SortFor(view)
				local descending = true
				if current and current.field == field then
					descending = not current.descending
				end
				ns.charDb.sort[view.id] = { field = field, descending = descending }
				Refresh()
			end,
		})
		list:SetPoint("TOPLEFT", 0, -62)
		list:SetPoint("BOTTOMRIGHT")
		lists[columns] = list
	end
	return list
end

Refresh = function()
	views:Refresh()
	model = ns.ViewModel:Build(ns.charDb.view, state)
	for _, list in pairs(lists) do
		list:Hide()
	end
	local list = ListFor(model.columns)
	local sort = model.view and ns.ViewModel:SortFor(model.view)
	list:SetSort(sort and sort.field, sort and sort.descending)
	list:SetEmptyText(model.empty or "")
	list:SetRows(model.elements, true)
	list:Show()
	infoText:SetText(model.info or "")
	allRowsButton:SetShown(model.filteredToItem == true)
end

local function Create(parent)
	holder = parent

	views = Kit.Choices(parent, {
		items = ns.Views,
		padding = 18,
		isActive = function(view)
			return view.id == ns.charDb.view
		end,
		onPick = function(view)
			ns.charDb.view = view.id
			state.itemKey = nil
			Refresh()
		end,
	})
	views:SetPoint("TOPLEFT")

	-- Only the event log can be emptied, and that takes two presses: the first
	-- asks, the second (within a few seconds) does it. Nothing clears a scan
	-- or the price history.
	local function ConfirmButton(label, action)
		local button
		button = Kit.Button(parent, { text = label, onClick = function()
			if button.armed then
				button.armed = false
				button:SetLabel(label)
				button:SetActive(false)
				action()
				return
			end
			button.armed = true
			button:SetLabel(L.DEBUG_CONFIRM)
			button:SetActive(true)
			C_Timer.After(CONFIRM_SECONDS, function()
				if button.armed then
					button.armed = false
					button:SetLabel(label)
					button:SetActive(false)
				end
			end)
		end })
		return button
	end
	local clearLog = ConfirmButton(L.DEBUG_CLEAR_LOG, function()
		ns.EventLog:Clear()
	end)
	clearLog:SetPoint("TOPRIGHT")
	local copyBox = Kit.CopyBox(parent)
	local copyLog = Kit.Button(parent, { text = L.DEBUG_COPY_LOG, tip = { L.DEBUG_COPY_LOG, L.DEBUG_COPY_LOG_TIP }, onClick = function()
		copyBox:Open(L.DEBUG_COPY_TITLE:format(#ns.db.log), ns.EventLog:Text())
	end })
	copyLog:SetPoint("RIGHT", clearLog, "LEFT", -5, 0)
	local previous = copyLog
	for index = #ns.Sources, 1, -1 do
		local source = ns.Sources[index]
		local button = Kit.Button(parent, { text = source.label, tip = { source.label, source.tip }, onClick = function()
			ns.Downloader:Start(source.id)
		end })
		button:SetPoint("RIGHT", previous, "LEFT", -5, 0)
		previous = button
	end

	local filter = Kit.Input(parent, { width = 200, placeholder = L.DEBUG_FILTER, onChange = function(text)
		state.search = text:lower()
		state.itemKey = nil
		Refresh()
	end })
	filter:SetPoint("TOPLEFT", 0, -31)
	allRowsButton = Kit.Button(parent, { text = L.SHOW_ALL, onClick = function()
		state.itemKey = nil
		Refresh()
	end })
	allRowsButton:SetPoint("LEFT", filter, "RIGHT", 6, 0)
	infoText = Kit.Text(parent, "small", C.muted, "RIGHT")
	infoText:SetPoint("TOPRIGHT", 0, -37)

	return { Refresh = Refresh }
end

ns.Window:RegisterTab({ id = "debug", label = L.TAB_DEBUG, order = 9, debug = true, Create = Create })

-- The log view fills in as events arrive.
ns.Bus:On("LOG_ADDED", function()
	if ns.charDb.tab == "debug" and ns.charDb.view == "log" then
		ns.Window:RefreshActive()
	end
end)

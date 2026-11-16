-- Views: the tabs of the window and their columns, as data.
-- The view model fills them (ui\view-model.lua) and the panel draws them.
--
-- Column keys:
--   field    which value of an element the column shows
--   width    fixed width in pixels. Exactly one column per view has flex = true
--            and takes whatever width is left
--   align    "LEFT" (default) or "RIGHT"
--   format   a key of ns.Format in ui\view-model.lua
--   sort     false to make the header unclickable
--
-- View keys:
--   search   the field the filter box matches against
--   limit    most rows drawn at once
--   columnsBySource  for views whose columns depend on the snapshot's source
local _, ns = ...
local L = ns.L

ns.Views = {
	{
		id = "summary",
		label = L.VIEW_SUMMARY,
		columns = {
			{ field = "label", label = L.COL_LABEL, width = 330, sort = false },
			{ field = "value", label = L.COL_VALUE, flex = true, sort = false },
		},
	},
	{
		id = "model",
		label = L.VIEW_MODEL,
		search = "field",
		columns = {
			{ field = "position", label = L.COL_INDEX, width = 26, align = "RIGHT", format = "plain" },
			{ field = "field", label = L.COL_FIELD, width = 150 },
			{ field = "types", label = L.COL_TYPES, width = 130 },
			{ field = "filled", label = L.COL_FILLED, width = 54, align = "RIGHT", format = "percent" },
			{ field = "values", label = L.COL_VALUES, flex = true, sort = false },
		},
	},
	{
		id = "items",
		label = L.VIEW_ITEMS,
		search = "name",
		limit = 3000,
		defaultSort = { field = "quantity", descending = true },
		columnsBySource = {
			replicate = {
				{ field = "name", label = L.COL_ITEM, flex = true, format = "itemName" },
				{ field = "listings", label = L.COL_LISTINGS, width = 58, align = "RIGHT", format = "number" },
				{ field = "quantity", label = L.COL_UNITS, width = 62, align = "RIGHT", format = "number" },
				{ field = "minUnit", label = L.COL_MIN, width = 104, align = "RIGHT", format = "money" },
				{ field = "medianUnit", label = L.COL_MEDIAN, width = 104, align = "RIGHT", format = "money" },
				{ field = "maxUnit", label = L.COL_MAX, width = 104, align = "RIGHT", format = "money" },
				{ field = "deal", label = L.COL_DEAL, width = 86, align = "RIGHT", format = "percent" },
			},
			browse = {
				{ field = "name", label = L.COL_ITEM, flex = true, format = "itemName" },
				{ field = "kind", label = L.COL_KIND, width = 90 },
				{ field = "quantity", label = L.COL_UNITS, width = 70, align = "RIGHT", format = "number" },
				{ field = "minUnit", label = L.COL_MIN, width = 110, align = "RIGHT", format = "money" },
			},
		},
	},
	{
		id = "rows",
		label = L.VIEW_ROWS,
		search = "name",
		limit = 2000,
		rawRows = true, -- elements are raw rows, read through the snapshot's schema
		columnsBySource = {
			replicate = {
				{ field = "name", label = L.COL_ITEM, flex = true, format = "rowName" },
				{ field = "itemID", label = L.COL_ID, width = 54, align = "RIGHT", format = "plain" },
				{ field = "count", label = L.COL_COUNT, width = 46, align = "RIGHT", format = "number" },
				{ field = "copies", label = L.COL_COPIES, width = 60, align = "RIGHT", format = "number" },
				{ field = "buyoutPrice", label = L.COL_BUYOUT, width = 104, align = "RIGHT", format = "moneyOrBlank" },
				{ field = "minBid", label = L.COL_MIN_BID, width = 104, align = "RIGHT", format = "money" },
				{ field = "bidAmount", label = L.COL_BID, width = 96, align = "RIGHT", format = "moneyOrBlank" },
				{ field = "timeLeft", label = L.COL_TIME_LEFT, width = 40, align = "RIGHT", format = "plain" },
			},
			browse = {
				{ field = "name", label = L.COL_ITEM, flex = true, format = "rowName" },
				{ field = "itemID", label = L.COL_ID, width = 54, align = "RIGHT", format = "plain" },
				{ field = "itemSuffix", label = "Suffix", width = 50, align = "RIGHT", format = "plain" },
				{ field = "requiredLevel", label = L.COL_LEVEL_REQ, width = 36, align = "RIGHT", format = "plain" },
				{ field = "totalQuantity", label = L.COL_UNITS, width = 70, align = "RIGHT", format = "number" },
				{ field = "minPrice", label = L.COL_MIN, width = 110, align = "RIGHT", format = "money" },
			},
		},
	},
	{
		id = "log",
		label = L.VIEW_LOG,
		search = "event",
		columns = {
			{ field = "clock", label = L.COL_TIME, width = 60, sort = false },
			{ field = "event", label = L.COL_EVENT, width = 290, sort = false },
			{ field = "detail", label = L.COL_DETAIL, flex = true, sort = false },
		},
	},
}

ns.ViewById = {}
for _, view in ipairs(ns.Views) do
	ns.ViewById[view.id] = view
end

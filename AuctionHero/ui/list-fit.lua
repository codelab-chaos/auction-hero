-- List fit: decides how much of a list must be measured again to fit its
-- columns to their text. Only the decision: it reads rows as opaque values
-- and calls nothing of the game's, so it can be tested on its own
-- (tests/unit/list-fit.lua). Kit.List does the measuring.
--
-- A fit is kept with the version of the data its rows' text comes from. While
-- that version holds, a row's text cannot have changed, so:
--   "keep"   the same rows as last time: nothing to measure
--   "some"   a few rows not seen before (rows replaced in place, such as an
--            item a live search patched): only they are measured, and widen
--            the fit when wider. A few is ns.ListFitRule's fewRows, or its
--            fewShare of the list, whichever is more
--   "all"    the data changed, or too many rows are new: measure every row
-- A fit that is only ever widened by "some" may end a little wider than its
-- rows need, never narrower; the next "all" sets it right.
local _, ns = ...

local ListFit = {}
ns.ListFit = ListFit

-- The plan for a list's rows: "keep", "some" with the rows to measure, or
-- "all". state is what Remember returned last time, or nil.
function ListFit.Plan(state, rows, version, rule)
	if not state or state.version ~= version then
		return "all"
	end
	if rows == state.list then
		return "keep"
	end
	local unseen = {}
	for _, row in ipairs(rows) do
		if not state.rows[row] then
			unseen[#unseen + 1] = row
		end
	end
	if #unseen == 0 then
		return "keep"
	end
	if #unseen > math.max(rule.fewRows, #rows * rule.fewShare) then
		return "all"
	end
	return "some", unseen
end

-- What to keep after measuring by a plan: the rows measured (all of them for
-- "all"), the list as handed, and the version.
function ListFit.Remember(state, plan, rows, version, measured)
	if plan == "all" or not state then
		state = { rows = {} }
		measured = rows
	end
	for _, row in ipairs(measured or {}) do
		state.rows[row] = true
	end
	state.list, state.version = rows, version
	return state
end

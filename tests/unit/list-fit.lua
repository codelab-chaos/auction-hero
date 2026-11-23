-- loads: data/theme.lua, ui/list-fit.lua
-- The list fit plan, with rows as plain tables: no game, no list.
local F = NS.ListFit
local RULE = NS.ListFitRule

local function Rows(count)
	local rows = {}
	for index = 1, count do
		rows[index] = { index = index }
	end
	return rows
end

local function Copy(rows)
	local copy = {}
	for index, row in ipairs(rows) do
		copy[index] = row
	end
	return copy
end

do -- Nothing kept: measure everything.
	check("a first fit measures all", F.Plan(nil, Rows(3), 1, RULE), "all")
end

do -- The same rows, the same data: keep.
	local rows = Rows(500)
	local state = F.Remember(nil, "all", rows, 7)
	check("the same list handed back", F.Plan(state, rows, 7, RULE), "keep")
	check("the same rows in a new list (sorted again)", F.Plan(state, Copy(rows), 7, RULE), "keep")
	local reversed = {}
	for index = #rows, 1, -1 do
		reversed[#reversed + 1] = rows[index]
	end
	check("in any order", F.Plan(state, reversed, 7, RULE), "keep")
	local fewer = Copy(rows)
	table.remove(fewer)
	check("some rows filtered away", F.Plan(state, fewer, 7, RULE), "keep")
end

do -- The data changed: measure everything, whatever the rows.
	local rows = Rows(10)
	local state = F.Remember(nil, "all", rows, "1:4")
	check("a new version", F.Plan(state, rows, "1:5", RULE), "all")
end

do -- A few rows replaced in place: only they are measured.
	local rows = Rows(1000)
	local state = F.Remember(nil, "all", rows, 1)
	local patched = Copy(rows)
	patched[10], patched[20] = { replaced = 10 }, { replaced = 20 }
	local plan, unseen = F.Plan(state, patched, 1, RULE)
	check("a patch measures some", plan, "some")
	check("just the two new rows", #unseen, 2)
	checkTrue("the ones replaced", (unseen[1] == patched[10] and unseen[2] == patched[20]))
	state = F.Remember(state, plan, patched, 1, unseen)
	check("then they are known", F.Plan(state, patched, 1, RULE), "keep")
	check("and the rows they replaced are still known", F.Plan(state, rows, 1, RULE), "keep")
end

do -- Too many new rows: measure everything.
	local small = Rows(100)
	local state = F.Remember(nil, "all", small, 1)
	local grown = Copy(small)
	for index = 1, RULE.fewRows + 1 do
		grown[#grown + 1] = { new = index }
	end
	check("more than fewRows new", F.Plan(state, grown, 1, RULE), "all")

	local big = Rows(RULE.fewRows * 20)
	state = F.Remember(nil, "all", big, 1)
	local share = Copy(big)
	local allowed = math.floor(#big * RULE.fewShare)
	for index = 1, allowed do
		share[index] = { new = index }
	end
	check("up to fewShare of a long list is still some", (F.Plan(state, share, 1, RULE)), "some")
	share[allowed + 1] = { new = allowed + 1 }
	check("past it, all", F.Plan(state, share, 1, RULE), "all")
end

do -- Measuring everything forgets the rows from before.
	local old = Rows(5)
	local state = F.Remember(nil, "all", old, 1)
	local new = Rows(5)
	state = F.Remember(state, "all", new, 2)
	local plan, unseen = F.Plan(state, old, 2, RULE)
	check("old rows are not taken as measured", plan, "some")
	check("all five of them", #unseen, 5)
end

do -- Whatever happens, every row shown has been measured since the data last changed.
	local seed = 12345
	local function Random(n)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n + 1
	end
	local pool = Rows(400)
	local state, version, ok = nil, 1, true
	for _ = 1, 500 do
		local roll = Random(10)
		if roll == 1 then
			version = version + 1 -- the data changed
		end
		local rows = {}
		for index = 1, Random(400) do
			rows[index] = pool[index]
		end
		if roll == 2 then
			pool[Random(#pool)] = { patched = true } -- a row replaced in place
		end
		local plan, unseen = F.Plan(state, rows, version, RULE)
		state = F.Remember(state, plan, rows, version, unseen)
		for _, row in ipairs(rows) do
			ok = ok and state.rows[row] == true
		end
		ok = ok and state.version == version
	end
	checkTrue("no row is ever shown unmeasured", ok)
end

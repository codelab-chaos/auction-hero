-- loads: market/history-merge.lua
-- History merge: one market kept under two names, put back together.
local Merge = NS.HistoryMerge

-- Points: every point of both, oldest first, none twice.
check("points of both, in order", Merge.Points("100000000:5:4:3:1;300000000:6:4:3:1", "200000000:7:4:3:1"), "100000000:5:4:3:1;200000000:7:4:3:1;300000000:6:4:3:1")
check("a point both have is kept once", Merge.Points("100000000:5:4:3:1", "100000000:5:4:3:1"), "100000000:5:4:3:1")
check("the one saying more is kept", Merge.Points("100000000:5:4:3:1", "100000000:5:4:3:1:2:0:0:30:9"), "100000000:5:4:3:1:2:0:0:30:9")
check("nothing and something", Merge.Points(nil, "100000000:5:4:3:1"), "100000000:5:4:3:1")

-- A record: the newer says the price, the counts are of both.
local old = { u = 100, m = 90, lo = 40, lou = 2, lot = 111, hi = 300, n = 5, d = 3, f = 10, l = 12, h = "100000000:90:40:8:2" }
local new = { u = 150, m = 160, lo = 60, lou = 1, lot = 222, hi = 200, n = 4, d = 2, f = 13, l = 14, h = "200000000:160:60:5:1" }
for _, merged in ipairs({ Merge.Record(old, new), Merge.Record(new, old) }) do
	check("the usual price is the newer one's", merged.u, 150)
	check("so is the last median", merged.m, 160)
	check("the lowest is the lowest of both", merged.lo, 40)
	check("with how many were at it", merged.lou, 2)
	check("and when", merged.lot, 111)
	check("the highest of both", merged.hi, 300)
	check("scans add up", merged.n, 9)
	check("days add up", merged.d, 5)
	check("first seen is the earlier", merged.f, 10)
	check("last seen is the later", merged.l, 14)
	check("the graph has both", merged.h, "100000000:90:40:8:2;200000000:160:60:5:1")
end
check("a day both saw is one day", Merge.Record({ n = 1, d = 2, f = 10, l = 13, hi = 1, lo = 1 }, { n = 1, d = 2, f = 13, l = 14, hi = 1, lo = 1 }).d, 3)
check("one record alone is itself", Merge.Record(nil, new), new)
check("neither record was changed", old.n + new.n, 9)

-- Markets: items of both, and a scan both remember counts once.
local into = { items = { a = new, c = { u = 1, n = 1, d = 1, f = 1, l = 1, hi = 1, lo = 1 } }, folded = { [200] = true, [300] = true }, scans = 2 }
local from = { items = { a = old, b = { u = 7, n = 1, d = 1, f = 1, l = 1, hi = 7, lo = 7 } }, folded = { [100] = true, [200] = true }, scans = 2 }
local calls = 0
Merge.Markets(into, from, function() calls = calls + 1 end)
check("an item of both is merged", into.items.a.n, 9)
check("an item of one comes over", into.items.b.u, 7)
check("an item of the other stays", into.items.c.u, 1)
check("three scans in all, not four", into.scans, 3)
checkTrue("every scan is remembered", into.folded[100] and into.folded[200] and into.folded[300])

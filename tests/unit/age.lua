-- loads: data/theme.lua, age.lua
-- Short ages: minutes under an hour, hours under two days, then days.
local A = NS.ShortAge
check("just now reads as a minute", A(0), "1m")
check("59 seconds", A(59), "1m")
check("one minute", A(60), "1m")
check("59 minutes", A(59 * 60 + 59), "59m")
check("an hour", A(3600), "1h")
check("47 hours 59 minutes", A(48 * 3600 - 1), "47h")
check("48 hours is two days", A(48 * 3600), "2d")
check("ten days", A(10 * 86400 + 5000), "10d")
check("a time in the future reads as now", A(-30), "1m")
-- Steps only ever count up: a later time never reads as a smaller age.
local last, ok = 0, true
local function Size(text)
	local number, suffix = text:match("^(%d+)(%a)$")
	return tonumber(number) * ({ m = 60, h = 3600, d = 86400 })[suffix]
end
for seconds = 0, 30 * 86400, 1800 do
	local size = Size(A(seconds))
	ok = ok and size >= last
	last = size
end
checkTrue("never reads younger as time goes on", ok)

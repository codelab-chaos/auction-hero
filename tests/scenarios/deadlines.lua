-- The wait every trade flow puts on the game: a phase that waits always has a
-- deadline, any new phase ends the old wait, and a late timer never acts on a
-- newer request.
local ns = Boot()
local expired = {}
local flow = ns.Deadlines({ asking = 1, slow = function() return 2 end }, function(phase)
	expired[#expired + 1] = phase
end)

flow:Enter("asking")
Tick(25) -- 1.25 seconds
check("a waiting phase runs out", expired[1], "asking")

flow:Enter("asking")
Tick(10)
flow:Enter("done")
Tick(30)
check("a new phase ends the wait before it", #expired, 1)

flow:Enter("slow")
Tick(30)
check("a wait can be worked out when it starts", #expired, 1)
Tick(20)
check("and runs out then", expired[2], "slow")

local ran = false
flow:Enter("asking")
flow:Later(0.5, function() ran = true end)
flow:Drop()
Tick(30)
checkTrue("a late timer from an older turn does nothing", not ran)
check("nor does a dropped wait", #expired, 2)

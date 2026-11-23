-- loads: data/theme.lua, data/trading.lua, market/sale-odds.lua
-- The sale odds: first that they are sound probabilities, then that they
-- recover the truth from an auction house where the truth is known.
local O = NS.SaleOdds
local BANDS = NS.Assumptions.timeLeftBands
local HOUR = 3600
local EPSILON = 1e-9

-- ========= Sound probabilities =============================================
local function Range(fromHours, toHours)
	return { min = fromHours * HOUR, max = toHours * HOUR }
end

do
	local ok, why = true, nil
	local ranges = { Range(0, 0.5), Range(0.5, 2), Range(2, 12), Range(12, 24), Range(1, 1) }
	for _, range in ipairs(ranges) do
		for _, gapHours in ipairs({ 0.25, 1, 2.5, 6, 14, 30 }) do
			for _, rate in ipairs({ 0, 0.001, 0.05, 0.3, 0.9, 1 }) do
				for _, pull in ipairs({ 0, 0.05, 0.5 }) do
					for _, hasBid in ipairs({ false, true }) do
						for _, buyout in ipairs({ false, true }) do
							local sold, expired, pulled = O.Split(range, gapHours * HOUR, rate, pull, hasBid, buyout)
							local sum = sold + expired + pulled
							if math.abs(sum - 1) > EPSILON or sold < -EPSILON or expired < -EPSILON or pulled < -EPSILON or sold ~= sold then
								ok, why = false, ("band %s-%s gap %s rate %s pull %s: %s %s %s"):format(range.min, range.max, gapHours, rate, pull, sold, expired, pulled)
							end
						end
					end
				end
			end
		end
	end
	checkTrue("sold, ran out and taken down always add to 1 and never go negative" .. (why and (": " .. why) or ""), ok)
end

do -- Moving the evidence moves the answer the right way.
	local ok = true
	for _, rate in ipairs({ 0.01, 0.1, 0.5 }) do
		local last = 2
		for step = 0, 20 do
			-- The band slides later: less of it runs out in a 3 hour gap.
			local sold = O.Split(Range(step * 0.25, step * 0.25 + 2), 3 * HOUR, rate, 0, false, true)
			ok = ok and sold >= (last == 2 and 0 or last) - EPSILON
			last = sold
		end
	end
	checkTrue("further from its end: likelier it sold", ok)
	ok = true
	for _, range in ipairs({ Range(0.5, 2), Range(2, 12) }) do
		local last = -1
		for step = 0, 20 do
			local sold = O.Split(range, 2.5 * HOUR, step / 20, 0, false, true)
			ok = ok and sold >= last - EPSILON
			last = sold
		end
	end
	checkTrue("a faster selling item: likelier it sold", ok)
end

do -- No evidence, no sale; certainty where there is certainty.
	check("an item that sells nothing: what could run out ran out", (O.Split(Range(2, 12), 3 * HOUR, 0, 0, false, true)), 0)
	check("one that could not have run out was taken", (O.Split(Range(12, 24), 3 * HOUR, 0, 0, false, true)), 1)
	check("one with no buyout only ever runs out", select(2, O.Split(Range(12, 24), HOUR, 0.9, 0, false, false)), 1)
	check("one that ran out with a bid on it sold", (O.Split(Range(0, 0.5), HOUR, 0, 0, true, true)), 1)
	local rule = { minEvidence = 10, maxRanOutForRate = 0.5 }
	check("too few auctions to measure a rate from: unknown", O.SaleRate({ { ranOut = 0, start = 9, gone = 3 } }, rule), nil)
	check("only bands likely to run out: unknown", O.SaleRate({ { ranOut = 0.8, start = 500, gone = 450 } }, rule), nil)
	check("from a band that cannot run out, the share gone", O.SaleRate({ { ranOut = 0, start = 20, gone = 5 } }, rule), 0.25)
	check("the least likely band to run out is used", O.SaleRate({ { ranOut = 0.4, start = 100, gone = 70 }, { ranOut = 0.2, start = 50, gone = 20 } }, rule), (20 / 50 - 0.2) / 0.8)
	check("what running out explains is not taken as sales", O.SaleRate({ { ranOut = 0.2, start = 100, gone = 15 } }, rule), 0)
	check("never over 1", O.SaleRate({ { ranOut = 0, start = 20, gone = 30 } }, rule), 1)
end

do -- The chance of running out is the band's share the gap reaches past.
	check("a band starting after the gap: none", O.RanOut(BANDS, 4, HOUR), 0)
	check("a band ending before the gap: all", O.RanOut(BANDS, 1, HOUR), 1)
	local range = BANDS["2"]
	check("partway into a band: that share", O.RanOut(BANDS, 2, HOUR), (HOUR - range.min) / (range.max - range.min))
	check("a band not known could have", O.RanOut(BANDS, 9, HOUR), 1)
end

-- ========= Recovering a known truth ========================================
-- An auction house where every auction's time left and fate are drawn, so
-- the real number sold is known. Time left is spread evenly over a day (as
-- the odds assume within a band); each auction is bought at a random time
-- (an even chance per hour) or runs out first.
local seed = 20261123
local function Random()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function BandOf(left)
	for band, range in pairs(BANDS) do
		if left >= range.min and left < range.max then
			return tonumber(band)
		end
	end
	return 4
end

-- Simulates `count` auctions over a gap, with a chance `perHour` that one is
-- bought in any hour. Returns what really sold, what the odds say sold (nil
-- when they say the rate cannot be known), and what the first way of
-- counting (the band's share alone) said.
local function Simulate(count, perHour, gap)
	local hazard = -math.log(1 - perHour) / HOUR
	local auctions = {}
	local byBand = {}
	for index = 1, count do
		local left = Random() * BANDS["4"].max
		local boughtAt = -math.log(1 - Random()) / hazard
		local auction = { band = BandOf(left), gone = math.min(left, boughtAt) < gap, sold = boughtAt < left and boughtAt < gap }
		auctions[index] = auction
		local seen = byBand[auction.band] or { ranOut = O.RanOut(BANDS, auction.band, gap), start = 0, gone = 0 }
		byBand[auction.band] = seen
		seen.start = seen.start + 1
		if auction.gone then
			seen.gone = seen.gone + 1
		end
	end
	local observed = {}
	for _, seen in pairs(byBand) do
		observed[#observed + 1] = seen
	end
	local rate = O.SaleRate(observed, NS.TurnoverRule)
	local truth, estimate, firstWay = 0, 0, 0
	for _, auction in ipairs(auctions) do
		if auction.sold then
			truth = truth + 1
		end
		if auction.gone then
			local ranOut = O.RanOut(BANDS, auction.band, gap)
			estimate = estimate + O.Split(BANDS[tostring(auction.band)], gap, rate or 0, 0, false, true)
			firstWay = firstWay + (1 - ranOut)
		end
	end
	return truth, rate and estimate or nil, firstWay
end

-- Validated so far: scans up to 2.5 hours apart, within 10%. Further apart
-- the odds overcount (by about 7% at 6 hours and 23% at 14 hours for slow
-- sellers, over 30 runs), which is why showing sales is shelved
-- (ns.TurnoverRule.shown). Widen the gaps here when that is fixed.
do -- Across sale rates and the validated gaps: within 10% of the truth.
	local unknowns = 0
	for _, perHour in ipairs({ 0.002, 0.01, 0.05, 0.2 }) do
		for _, hours in ipairs({ 0.5, 2.5 }) do
			local truth, estimate = Simulate(20000, perHour, hours * HOUR)
			if estimate == nil then
				unknowns = unknowns + 1
			else
				local miss = math.abs(estimate - truth) / math.max(truth, 50)
				checkTrue(("within 10%% of what really sold at %.3f an hour, %.1fh apart (sold %d, estimated %.0f)"):format(perHour, hours, truth, estimate), miss <= 0.10)
			end
		end
	end
	check("never unknown at these gaps", unknowns, 0)
end

do -- The first way of counting failed this test, which is why it was replaced.
	local truth, estimate, firstWay = Simulate(20000, 0.01, 2.5 * HOUR)
	checkTrue(("the first way overcounted a slow seller (sold %d, it said %.0f)"):format(truth, firstWay), firstWay > truth * 1.5)
	checkTrue(("the odds do not (estimated %s)"):format(tostring(estimate)), estimate ~= nil and estimate <= truth * 1.15)
end

do -- Too few auctions to measure a rate from: unknown, not a guess.
	local unknown = 0
	for _ = 1, 50 do
		local _, estimate = Simulate(8, 0.01, 2.5 * HOUR)
		if estimate == nil then
			unknown = unknown + 1
		end
	end
	check("a handful of auctions is always unknown", unknown, 50)
end

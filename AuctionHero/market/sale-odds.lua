-- Sale odds: the arithmetic of what happened to an auction that vanished
-- between two scans. Only numbers in and out, nothing of the game's, so it
-- can be tested on its own (tests/unit/sale-odds.lua). market\turnover.lua
-- reads the scans and uses it.
--
-- An auction that vanished was bought, taken down by its seller, or ran out
-- of time. Nothing says which. What is known:
--   * the time left band it was in, so the chance it could have run out in
--     the time between the scans (RanOut)
--   * how often the item's auctions vanished in that time, in the band least
--     likely to run out: from it, its sale rate over the gap (SaleRate)
-- An auction that vanished is far likelier to be one that ran out than its
-- band alone suggests, since running out is certain for it and being bought
-- is not. So the chance it ran out, given that it vanished, weighs the two
-- (Split). An item whose rate cannot be measured (too few auctions, or scans
-- so far apart that nearly everything could have run out) gets no counts for
-- that gap at all, rather than a guess (market\turnover.lua).
local _, ns = ...

local SaleOdds = {}
ns.SaleOdds = SaleOdds

-- The chance an auction in a band ran out within `elapsed` seconds, taking
-- its time left as even across the band. A band not known could have.
function SaleOdds.RanOut(bands, band, elapsed)
	local range = bands[tostring(band)]
	if not range then
		return 1
	end
	if range.max <= range.min then
		return elapsed >= range.min and 1 or 0
	end
	return math.max(0, math.min(1, (elapsed - range.min) / (range.max - range.min)))
end

-- An item's sale rate over the gap: the chance one of its auctions that
-- does not run out is bought (or taken down) in it. Measured from one time
-- left band: in a band, the share that vanished is the chance of running
-- out, plus the rest times the rate, so the rate is
--   (vanished share - ran out chance) / (1 - ran out chance)
-- The band used is the least likely to run out that has at least
-- rule.minEvidence buyable auctions and a ran out chance of at most
-- rule.maxRanOutForRate. Nil when no band will do: the rate is not known.
--   byBand  { { ranOut, start, gone }, ... }, one per band, buyable auctions
--           in the scan before and how many of them vanished
function SaleOdds.SaleRate(byBand, rule)
	local best
	for _, band in ipairs(byBand) do
		if band.start >= rule.minEvidence and band.ranOut <= rule.maxRanOutForRate and (not best or band.ranOut < best.ranOut) then
			best = band
		end
	end
	if not best then
		return nil
	end
	local rate = (best.gone / best.start - best.ranOut) / (1 - best.ranOut)
	return math.max(0, math.min(1, rate))
end

-- The chance per second of being bought that gives `rate` over `gap`.
local function Hazard(rate, gap)
	if rate <= 0 or gap <= 0 then
		return 0
	end
	return -math.log(math.max(1e-12, 1 - math.min(rate, 1 - 1e-12))) / gap
end

-- The average over time left spread evenly from a to c of the chance of
-- being bought before that time: 1 - e^(-hazard * left).
local function BoughtWithin(hazard, a, c)
	if c <= a then
		return 0
	end
	if hazard <= 0 then
		return 0
	end
	return 1 - (math.exp(-hazard * a) - math.exp(-hazard * c)) / (hazard * (c - a))
end

-- For one auction that vanished: the shares (adding to 1) that it was sold,
-- ran out unsold and was taken down.
--   range   its time left band, { min, max } in seconds, its time left taken
--           as even across it
--   gap     the seconds between the scans
--   rate    its item's sale rate over the gap (SaleRate), taken as an even
--           chance of being bought every moment
--   pull    the share of auctions taken, not run out, that were taken down
--   hasBid  it had a bid: if it ran out, the bidder won it, a sale too
--   buyout  it could be bought out; one that could not only ever ran out
-- Worked out exactly under those two takes: the chance it was bought before
-- it ran out and before the second scan, over the chance it vanished at all.
-- One bought before running out counts as taken even when it would have run
-- out within the gap anyway.
function SaleOdds.Split(range, gap, rate, pull, hasBid, buyout)
	local taken = 0
	if buyout and range and range.max > range.min then
		local hazard = Hazard(rate, gap)
		local width = range.max - range.min
		local early = math.max(0, math.min(range.max, gap) - range.min) / width -- shares that run out in the gap
		local late = 1 - early
		local inGap = 1 - math.exp(-hazard * gap)
		-- Bought: before running out (those that run out in the gap), or
		-- within the gap (the rest).
		if early <= 0 then
			taken = 1 -- could not have run out: it was taken
		else
			local bought = early * BoughtWithin(hazard, range.min, math.min(range.max, gap)) + late * inGap
			taken = bought / (early + late * inGap)
		end
	elseif buyout and range and range.max <= range.min then
		taken = gap < range.min and 1 or 0
	end
	taken = math.max(0, math.min(1, taken))
	local out = 1 - taken
	local sold, expired = taken * (1 - pull), out
	if hasBid then
		sold, expired = sold + out, 0
	end
	return sold, expired, taken * pull
end

-- Signals: works out how far to trust an item's price, from the rules in
-- data\trading.lua. A reading comes with the numbers behind it and plain
-- reasons, so a meter can always say why it reads the way it does.
local _, ns = ...
local L = ns.L

local Signals = {}
ns.Signals = Signals

local function LevelFor(levels, score)
	local best = levels[1]
	for _, level in ipairs(levels) do
		if score >= level.min and level.min >= best.min then
			best = level
		end
	end
	return best
end

-- The largest step of a ladder that a count has reached.
local function StepFor(steps, field, count)
	local found
	for _, step in ipairs(steps) do
		if count >= step[field] then
			found = step
		end
	end
	return found
end

-- Returns { score, level, pips, reasons = {...},
--           facts = { auctions, nearUsual, scans, days, sales } }
-- item may be nil, for something nobody is selling.
function Signals:Confidence(item)
	local rule = ns.ConfidenceRule
	local record = item and ns.History:Get(item.key)
	local scans = record and record.n or (item and 1 or 0)
	local days = record and record.d or (item and 1 or 0)
	local usual = item and ns.History:Usual(item)
	local auctions = item and (item.listings - item.bidOnly) or 0

	if not item or auctions <= 0 or not usual then
		return {
			score = 0,
			level = LevelFor(ns.ConfidenceLevels, 0),
			pips = ns.ConfidencePips,
			reasons = { L.REASON_NONE_FOR_SALE },
			facts = { auctions = 0, scans = scans, days = days, sales = 0 },
		}
	end

	local depth = StepFor(rule.depth, "auctions", auctions)
	local low, high = usual * (1 - rule.agreementBand), usual * (1 + rule.agreementBand)
	local agreeing = 0
	for _, tier in ipairs(item.tiers) do
		if tier.unit >= low and tier.unit <= high then
			agreeing = agreeing + tier.units
		end
	end
	local agreement = item.units > 0 and agreeing / item.units or 0
	local keep = rule.agreementFloor + (1 - rule.agreementFloor) * agreement
	local seen = StepFor(rule.scans, "scans", scans)
	local score = (depth and depth.score or 0) * keep * (seen and seen.share or 0)
	score = math.max(1, math.floor(score + 0.5))

	local share = math.floor(agreement * 100 + 0.5)
	local reasons = {
		auctions == 1 and L.REASON_ONE_AUCTION or L.REASON_AUCTIONS:format(ns.Comma(auctions)),
		(agreement < rule.agreementWarning and L.REASON_SCATTERED or L.REASON_NEAR_USUAL):format(share),
		scans <= 1 and L.REASON_ONE_SCAN or L.REASON_SCANS:format(ns.Comma(scans), ns.Comma(days)),
		L.REASON_NO_SALES,
	}

	return {
		score = score,
		level = LevelFor(ns.ConfidenceLevels, score),
		pips = ns.ConfidencePips,
		reasons = reasons,
		facts = { auctions = auctions, nearUsual = share, scans = scans, days = days, sales = 0 },
	}
end

-- The facts on one line, for under the meter.
function Signals:ConfidenceLine(confidence)
	local facts = confidence.facts
	return L.CONFIDENCE_FACTS:format(
		ns.Comma(facts.auctions),
		facts.nearUsual and (facts.nearUsual .. "%") or L.CONFIDENCE_NO_SHARE,
		ns.Comma(facts.scans),
		ns.Comma(facts.sales)
	)
end

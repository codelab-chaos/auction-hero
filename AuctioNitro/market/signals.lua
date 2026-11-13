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

-- How good it is to buy an order of this item. units and cost describe the
-- whole order. Returns a reading like Confidence, plus:
--   known    false when there is too little to judge by. No meter is shown then
--   saving   what the order saves against the usual price (negative when over)
function Signals:Deal(item, units, cost)
	local rule = ns.DealRule
	local function ConfidenceAt(id)
		for _, level in ipairs(ns.ConfidenceLevels) do
			if level.id == id then
				return level.min
			end
		end
		return 0
	end
	local confidence = self:Confidence(item)
	local usual = ns.History:Usual(item)
	if units <= 0 or not usual or confidence.score < ConfidenceAt(rule.needsConfidence) then
		return { known = false, pips = ns.DealPips, level = { pips = 0, tone = "warn", label = "" }, reasons = { L.DEAL_UNKNOWN } }
	end

	local unitPrice = cost / units
	local under = (usual - unitPrice) / usual * 100
	local level = ns.DealLevels.fair
	if under < -rule.fairBand then
		level = ns.DealLevels.over
	elseif under >= rule.resellFrom and confidence.score >= ConfidenceAt(rule.resellNeeds) then
		level = ns.DealLevels.resell
	elseif under >= rule.greatFrom then
		level = confidence.score >= ConfidenceAt(rule.confidentNeeds) and ns.DealLevels.confident or ns.DealLevels.great
	end

	local percent = math.floor(math.abs(under) + 0.5)
	local reasons = {}
	if percent == 0 then
		reasons[1] = L.DEAL_AT_USUAL:format(ns.PlainMoney(usual))
	else
		reasons[1] = (under > 0 and L.DEAL_UNDER or L.DEAL_ABOVE):format(percent, ns.PlainMoney(usual))
	end
	if level == ns.DealLevels.great then
		reasons[2] = L.DEAL_CHECK
	end

	return {
		known = true,
		saving = math.floor(usual * units - cost + 0.5),
		level = level,
		pips = ns.DealPips,
		reasons = reasons,
	}
end

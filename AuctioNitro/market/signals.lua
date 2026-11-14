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

	-- Judged by how many different prices there are, not how many auctions.
	local prices = item.priceCount or 0
	local depth = StepFor(rule.depth, "prices", prices)
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
		auctions == 1 and L.REASON_ONE_AUCTION or (prices == 1 and L.REASON_ONE_PRICE or L.REASON_AUCTIONS):format(ns.Comma(auctions), ns.Comma(prices)),
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

-- The price a buyer would otherwise pay for an item, which a deal is measured
-- against: today's floor, held down to the item's usual lowest price once
-- past scans can say what that is. Returns nil when there is neither, else
--   { price, floor, typicalLow, backed }   backed: past scans had a say
-- Worked out once per item per scan and kept on the item.
function Signals:Baseline(item)
	if item.baseline == nil then
		local typicalLow = ns.History:TypicalLow(item.key)
		local price = item.floor
		if typicalLow and (not price or typicalLow < price) then
			price = typicalLow
		end
		item.baseline = price and { price = price, floor = item.floor, typicalLow = typicalLow, backed = typicalLow ~= nil } or false
	end
	return item.baseline or nil
end

-- Sets what a list shows for an item: item.deal, how far its cheapest price
-- sits under the baseline in percent (nil when there is no baseline or it is
-- not under), and item.dealUnits, how many units are at that price.
function Signals:Rate(item)
	item.deal, item.dealUnits = nil, nil
	local baseline = self:Baseline(item)
	if not baseline or not item.min or item.min >= baseline.price then
		return
	end
	-- A row is only flagged when there is something behind the baseline: past
	-- scans, or several different prices today. Two listings far apart say
	-- nothing about which of them is the odd one.
	if not baseline.backed and (item.priceCount or 0) < ns.DealBadgeRule.minPrices then
		return
	end
	item.deal = math.floor((baseline.price - item.min) / baseline.price * 100)
	item.dealUnits = 0
	for _, tier in ipairs(item.tiers) do
		if tier.unit == item.min then
			item.dealUnits = item.dealUnits + tier.units
		end
	end
end

-- How good it is to buy an order of this item. units and cost describe the
-- whole order. Returns a reading like Confidence, plus:
--   known    false when there is nothing to measure against. No meter is shown then
--   saving   what the order saves against the baseline (negative when over)
function Signals:Deal(item, units, cost)
	local rule = ns.DealRule
	local baseline = self:Baseline(item)
	if units <= 0 or not baseline then
		return { known = false, pips = ns.DealPips, level = { pips = 0, tone = "warn", label = "" }, reasons = { L.DEAL_UNKNOWN } }
	end

	local unitPrice = cost / units
	local under = (baseline.price - unitPrice) / baseline.price * 100
	local level = ns.DealLevels.fair
	if under < -rule.fairBand then
		level = ns.DealLevels.over
	elseif under >= rule.greatFrom then
		local needs = 0
		for _, entry in ipairs(ns.ConfidenceLevels) do
			if entry.id == rule.confidentNeeds then
				needs = entry.min
			end
		end
		local sure = baseline.backed or self:Confidence(item).score >= needs
		if not sure then
			level = ns.DealLevels.great
		elseif under >= rule.resellFrom then
			level = ns.DealLevels.resell
		else
			level = ns.DealLevels.confident
		end
	end

	local percent = math.floor(math.abs(under) + 0.5)
	local reasons = {}
	if percent == 0 then
		reasons[1] = L.DEAL_AT_USUAL:format(ns.PlainMoney(baseline.price))
	else
		reasons[1] = (under > 0 and L.DEAL_UNDER or L.DEAL_ABOVE):format(percent, ns.PlainMoney(baseline.price))
	end
	reasons[2] = baseline.backed and L.DEAL_BASIS_HISTORY or L.DEAL_BASIS_TODAY
	reasons[3] = L.DEAL_ASKING

	return {
		known = true,
		saving = math.floor(baseline.price * units - cost + 0.5),
		level = level,
		pips = ns.DealPips,
		reasons = reasons,
	}
end

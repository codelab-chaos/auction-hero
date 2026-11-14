// Signals: works out an item's price confidence from the rules in
// config/signals.ts. It comes with plain-language reasons, so the meter can
// always say why it reads the way it does.
import {
  CONFIDENCE_LEVELS,
  CONFIDENCE_PIPS,
  CONFIDENCE_RULE,
  DEAL_LEVELS,
  DEAL_PIPS,
  DEAL_RULE,
  DEAL_UNKNOWN,
  type SignalLevel,
} from "../config/signals.ts";
import type { MarketItem } from "./market";

export interface Signal {
  score: number; // 0 to 100
  level: SignalLevel;
  pips: number; // how many pips the meter has in total
  reasons: string[];
}

function levelFor(levels: SignalLevel[], score: number): SignalLevel {
  let best = levels[0] as SignalLevel;
  for (const level of levels) {
    if (score >= level.min && level.min >= best.min) best = level;
  }
  return best;
}

function plural(count: number, word: string): string {
  return `${count.toLocaleString("en-US")} ${word}${count === 1 ? "" : "s"}`;
}

// A price confidence reading, with the numbers it was worked out from.
export interface Confidence extends Signal {
  facts: {
    auctions: number;
    nearUsual: number | null; // percent of units priced near the usual price
    scans: number;
    sales: number | null; // null until there is history to estimate sales from
  };
}

// The facts on one line, for under the meter.
export function confidenceLine(confidence: Confidence): string {
  const { auctions, nearUsual, scans, sales } = confidence.facts;
  return [
    `auctions: ${auctions.toLocaleString("en-US")}`,
    `${nearUsual === null ? "-" : `${nearUsual}%`} usual`,
    `scans: ${scans.toLocaleString("en-US")}`,
    // No sales seen reads as 0. A dash looked like "does not apply".
    `sales: ${(sales ?? 0).toLocaleString("en-US")}`,
  ].join(" | ");
}

// How far to trust a price read off this item's ladder.
// scansSeen is how many scans the item has appeared in, once history exists.
export function priceConfidence(item: MarketItem, scansSeen = item.scansSeen ?? 1): Confidence {
  const auctions = item.listings - item.bidOnly;
  if (auctions <= 0 || item.median === null) {
    return {
      score: 0,
      level: levelFor(CONFIDENCE_LEVELS, 0),
      pips: CONFIDENCE_PIPS,
      reasons: ["None for sale, so no price to go by"],
      facts: { auctions: 0, nearUsual: null, scans: scansSeen, sales: null },
    };
  }

  let depth = 0;
  for (const step of CONFIDENCE_RULE.depth) {
    if (auctions >= step.auctions) depth = step.score;
  }

  const usual = item.usual ?? item.median;
  const low = usual * (1 - CONFIDENCE_RULE.agreementBand);
  const high = usual * (1 + CONFIDENCE_RULE.agreementBand);
  let agreeing = 0;
  for (const tier of item.tiers) {
    if (tier.unit >= low && tier.unit <= high) agreeing += tier.units;
  }
  const agreement = item.units > 0 ? agreeing / item.units : 0;
  const keep = CONFIDENCE_RULE.agreementFloor + (1 - CONFIDENCE_RULE.agreementFloor) * agreement;
  const score = Math.max(1, Math.round(depth * keep));

  const reasons: string[] = [];
  reasons.push(
    auctions === 1 ? "Only 1 auction" : plural(auctions, "auction"),
  );
  const share = Math.round(agreement * 100);
  reasons.push(
    agreement < CONFIDENCE_RULE.agreementWarning ? `Prices scattered: ${share}% near usual` : `${share}% priced near usual`,
  );
  reasons.push(
    scansSeen <= 1 ? "One scan: listings, not sales" : `Seen in ${plural(scansSeen, "scan")}`,
  );

  return {
    score,
    level: levelFor(CONFIDENCE_LEVELS, score),
    pips: CONFIDENCE_PIPS,
    reasons,
    facts: { auctions, nearUsual: share, scans: scansSeen, sales: null },
  };
}

function money(copper: number): string {
  const gold = Math.floor(copper / 10000);
  const silver = Math.floor(copper / 100) % 100;
  const rest = Math.floor(copper) % 100;
  return [gold ? `${gold}g` : "", gold || silver ? `${silver}s` : "", `${rest}c`].filter(Boolean).join(" ");
}

// A deal reading: the meter, whether there is anything to measure against,
// and what the order saves against the baseline (negative when it costs more).
export interface Deal extends Signal {
  known: boolean;
  saving: number | null; // copper
}

// How good it is to buy an order of this item, against the price you would
// otherwise pay (item.baseline, see model/market.ts). units and cost describe
// the whole order, so buying deeper into the ladder weakens the deal.
export function deal(item: MarketItem, units: number, cost: number): Deal {
  const baseline = item.baseline;
  const unitPrice = units > 0 ? cost / units : null;
  if (unitPrice === null || baseline === null) {
    return {
      known: false,
      saving: null,
      score: 0,
      level: DEAL_UNKNOWN,
      pips: DEAL_PIPS,
      reasons: ["Too few for sale to know what you would otherwise pay."],
    };
  }

  // Past scans had a say in the baseline, so it is more than today's asking prices.
  const backed = (item.typicalLow ?? null) !== null;
  const under = ((baseline - unitPrice) / baseline) * 100;
  let level: SignalLevel = DEAL_LEVELS.fair;
  if (under < -DEAL_RULE.fairBand) level = DEAL_LEVELS.over;
  else if (under >= DEAL_RULE.greatFrom) {
    const needs = CONFIDENCE_LEVELS.find((entry) => entry.id === DEAL_RULE.confidentNeeds)?.min ?? 0;
    const sure = backed || priceConfidence(item).score >= needs;
    level = !sure ? DEAL_LEVELS.great : under >= DEAL_RULE.resellFrom ? DEAL_LEVELS.resell : DEAL_LEVELS.confident;
  }
  const percent = Math.round(Math.abs(under));
  return {
    known: true,
    saving: Math.round(baseline * units - cost),
    score: Math.max(0, Math.min(100, Math.round(under))),
    level,
    pips: DEAL_PIPS,
    reasons: [
      percent === 0
        ? `Right at the ${money(baseline)} you would otherwise pay.`
        : `${percent}% ${under > 0 ? "under" : "over"} the ${money(baseline)} you would otherwise pay.`,
      backed
        ? "Measured against today's listings and what past scans show its lowest price usually is."
        : "Measured against today's listings, skipping the cheapest few. Past scans cannot back it yet.",
      "These are asking prices, not what it has sold for.",
    ],
  };
}

// Deal confidence: how far to trust that an item's low price is a real deal,
// worked out from the rules in config/signals.ts. It says nothing about how
// big the discount is. Each reading carries its reasons.
import { DEAL_CONFIDENCE_LEVELS, DEAL_CONFIDENCE_PIPS, DEAL_CONFIDENCE_RULE as RULE, type SignalLevel } from "../config/signals.ts";
import type { Flows } from "./flow.ts";
import type { MarketItem } from "./market";
import type { Signal } from "./signals.ts";

export interface DealConfidence extends Signal {
  facts: {
    days: number;
    sold: number | null; // null when sales cannot be read for this item
    prices: number;
    nearVendor: boolean;
  };
}

// The share earned on a ladder: that of the largest step the count has reached.
function shareOf(steps: { from: number; share: number }[], count: number): number {
  let share = 0;
  for (const step of steps) {
    if (count >= step.from) share = step.share;
  }
  return share;
}

function levelFor(score: number): SignalLevel {
  let best = DEAL_CONFIDENCE_LEVELS[0] as SignalLevel;
  for (const level of DEAL_CONFIDENCE_LEVELS) {
    if (score >= level.min && level.min >= best.min) best = level;
  }
  return best;
}

const plural = (count: number, word: string): string => `${Math.floor(count).toLocaleString("en-US")} ${word}${Math.floor(count) === 1 ? "" : "s"}`;

export function dealConfidence(item: MarketItem, flows: Flows): DealConfidence {
  const days = item.daysSeen ?? 1;
  const prices = new Set(item.tiers.map((tier) => tier.unit)).size;
  const flow = flows.byKey.get(item.key);
  // Sales can be read when scans were compared and the item's rows had names.
  const sold = flows.intervals > 0 && !flow?.shaky ? (flow?.sold ?? 0) : null;

  let score =
    RULE.days.weight * shareOf(RULE.days.steps, days) +
    RULE.sold.weight * shareOf(RULE.sold.steps, sold ?? 0) +
    RULE.prices.weight * shareOf(RULE.prices.steps, prices);

  // A cheap price near what a vendor pays, under listings asking many times
  // more: the cheap one is the realistic price and the others are hopeful.
  const vendor = item.vendorPrice ?? null;
  const nearVendor =
    vendor !== null && vendor > 0 && item.min !== null && item.baseline !== null &&
    item.min <= vendor * RULE.vendorNear && item.baseline >= vendor * RULE.vendorFar;
  if (nearVendor) score = Math.min(score, RULE.vendorCap);
  if (item.baseline === null) score = 0;
  score = Math.round(score);

  const reasons = [
    days <= 1 ? "Seen on one day only: a snapshot, not a pattern" : `Seen on ${plural(days, "day")}`,
    sold === null ? "Sales cannot be read for this item" : sold < 1 ? "Not seen selling between scans" : `About ${plural(sold, "unit")} seen selling between scans`,
    prices <= 1 ? "Listed at one price: likely one seller" : `Listed at ${plural(prices, "different price")}`,
  ];
  if (nearVendor) reasons.push("The low price is near what a vendor pays, and the rest ask many times more: they are likely the odd ones out");
  if (item.baseline === null) reasons.push("Too few for sale to measure a price against");

  return { score, level: levelFor(score), pips: DEAL_CONFIDENCE_PIPS, reasons, facts: { days, sold, prices, nearVendor } };
}

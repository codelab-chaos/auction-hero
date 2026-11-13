// What happens if you post at a given price: who is ahead of you, and what
// you would receive.
import { ASSUMPTIONS } from "../config/catalog";
import type { PriceRule } from "../config/price-rules";
import type { MarketItem } from "./market";

export interface Quote {
  rule: PriceRule;
  unit: number | null; // price per unit
  total: number | null; // price for the whole stack
  unitsAhead: number; // units priced under yours
  auctionsAhead: number;
  proceeds: number | null; // after the auction house's cut
}

export function quote(item: MarketItem, rule: PriceRule, quantity: number): Quote {
  const unit = rule.price(item);
  if (unit === null) {
    return { rule, unit, total: null, unitsAhead: 0, auctionsAhead: 0, proceeds: null };
  }
  let unitsAhead = 0;
  let auctionsAhead = 0;
  for (const tier of item.tiers) {
    if (tier.unit >= unit) break;
    unitsAhead += tier.units;
    auctionsAhead += tier.copies;
  }
  const total = unit * quantity;
  return { rule, unit, total, unitsAhead, auctionsAhead, proceeds: Math.floor(total * (1 - ASSUMPTIONS.auctionCut)) };
}

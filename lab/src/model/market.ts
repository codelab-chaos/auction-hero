// Market: turns a scan file into items with a price ladder and summary numbers.
// Pure data in, plain objects out. No DOM, no formatting.
import { DEAL_RULE } from "../config/catalog";
import type { ItemRecord, ScanFile, ScanMeta } from "../data/types";

// One rung of an item's price ladder: every auction with the same stack size,
// price and time left.
export interface Tier {
  unit: number; // price per unit, copper
  stack: number; // units per auction
  buyout: number; // price per auction
  copies: number; // identical auctions
  units: number; // stack * copies
  timeLeft: number;
}

export interface MarketItem extends ItemRecord {
  tiers: Tier[]; // cheapest per unit first, buyout auctions only
  listings: number; // auctions, counting copies
  units: number; // units for sale with a buyout
  bidOnly: number; // auctions without a buyout
  min: number | null;
  median: number | null; // weighted by units
  max: number | null;
  value: number; // total buyout of everything listed
  deal: number | null; // how far the lowest sits under the median, in percent
}

export interface Market {
  meta: ScanMeta;
  items: MarketItem[];
  byKey: Map<string, MarketItem>;
}

function weightedMedian(tiers: Tier[], totalUnits: number): number | null {
  let running = 0;
  for (const tier of tiers) {
    running += tier.units;
    if (running >= totalUnits / 2) return tier.unit;
  }
  return null;
}

function finish(item: MarketItem): void {
  item.tiers.sort((a, b) => a.unit - b.unit || a.stack - b.stack);
  const first = item.tiers[0];
  const last = item.tiers[item.tiers.length - 1];
  if (!first || !last) return;
  item.min = first.unit;
  item.max = last.unit;
  item.median = weightedMedian(item.tiers, item.units);
  const buyoutListings = item.listings - item.bidOnly;
  if (item.median && buyoutListings >= DEAL_RULE.minListings) {
    item.deal = Math.floor(((item.median - item.min) / item.median) * 100);
  }
}

export function buildMarket(scan: ScanFile): Market {
  const items: MarketItem[] = scan.items.map((record) => ({
    ...record,
    tiers: [],
    listings: 0,
    units: 0,
    bidOnly: 0,
    min: null,
    median: null,
    max: null,
    value: 0,
    deal: null,
  }));

  for (const [itemIndex, count, buyout, , , timeLeft, copies] of scan.listings) {
    const item = items[itemIndex];
    if (!item) continue;
    const stack = Math.max(1, count);
    item.listings += copies;
    if (buyout > 0) {
      item.tiers.push({ unit: Math.floor(buyout / stack), stack, buyout, copies, units: stack * copies, timeLeft });
      item.units += stack * copies;
      item.value += buyout * copies;
    } else {
      item.bidOnly += copies;
    }
  }

  items.forEach(finish);
  return { meta: scan.meta, items, byKey: new Map(items.map((item) => [item.key, item])) };
}

// How many units a budget buys, cheapest first, and what they cost.
// Auctions are bought whole: a stack cannot be split.
export function affordable(item: MarketItem, budget: number): { units: number; cost: number } {
  let units = 0;
  let cost = 0;
  for (const tier of item.tiers) {
    const copies = Math.min(tier.copies, Math.floor((budget - cost) / tier.buyout));
    if (copies <= 0) {
      if (tier.buyout > budget - cost) continue; // a smaller stack further up may still fit
      break;
    }
    units += copies * tier.stack;
    cost += copies * tier.buyout;
  }
  return { units, cost };
}

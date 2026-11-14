// Market: turns a scan file into items with a price ladder and summary numbers.
// Pure data in, plain objects out. No DOM, no formatting.
import { BASELINE_RULE, DEAL_RULE } from "../config/catalog.ts";
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
  scansSeen?: number;
  daysSeen?: number; // different days the scans saw it on
  lowestSeen?: number | null; // the lowest price any scan saw it at
  usual?: number | null; // price history across imported scans
  expiryUncertainUnits?: number;
  expiryUnknownUnits?: number;
  tiers: Tier[]; // cheapest per unit first, buyout auctions only
  listings: number; // auctions, counting copies
  units: number; // units for sale with a buyout
  bidOnly: number; // auctions without a buyout
  min: number | null;
  median: number | null; // weighted by units
  max: number | null;
  value: number; // total buyout of everything listed
  // The price once the cheapest few units are skipped. null with too few for sale.
  floor: number | null;
  // What the item's lowest price usually is across scans. Missing or null until enough scans have seen it.
  typicalLow?: number | null;
  // The price you would otherwise pay: the floor, held down to the typical low.
  baseline: number | null;
  deal: number | null; // how far the lowest sits under the baseline, in percent. null when it does not
  dealUnits: number | null; // units at that lowest price
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

export function finishMarketItem(item: MarketItem): void {
  item.min = item.median = item.max = item.floor = item.baseline = item.deal = item.dealUnits = null;
  item.tiers.sort((a, b) => a.unit - b.unit || a.stack - b.stack);
  const first = item.tiers[0];
  const last = item.tiers[item.tiers.length - 1];
  if (!first || !last) return;
  item.min = first.unit;
  item.max = last.unit;
  item.median = weightedMedian(item.tiers, item.units);

  const skip = Math.max(BASELINE_RULE.floorMinUnits, Math.ceil(item.units * BASELINE_RULE.floorShare));
  let running = 0;
  for (const tier of item.tiers) {
    running += tier.units;
    if (running >= skip) {
      item.floor = tier.unit;
      break;
    }
  }
  const typicalLow = item.typicalLow ?? null;
  item.baseline = item.floor === null ? typicalLow : typicalLow === null ? item.floor : Math.min(item.floor, typicalLow);
  // A row is only flagged when there is something behind the baseline: past
  // scans, or several different prices today. Two listings far apart say
  // nothing about which of them is the odd one.
  const prices = new Set(item.tiers.map((tier) => tier.unit)).size;
  const founded = typicalLow !== null || prices >= DEAL_RULE.minPrices;
  if (founded && item.baseline !== null && item.min < item.baseline) {
    item.deal = Math.floor(((item.baseline - item.min) / item.baseline) * 100);
    item.dealUnits = item.tiers.reduce((units, tier) => units + (tier.unit === item.min ? tier.units : 0), 0);
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
    floor: null,
    baseline: null,
    deal: null,
    dealUnits: null,
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

  items.forEach(finishMarketItem);
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

// Units for sale at each different price, cheapest first. An item is never
// one price: this is what a list shows when the item is opened.
export interface PricePoint {
  unit: number;
  units: number;
}

export function pricePoints(item: MarketItem): PricePoint[] {
  const points: PricePoint[] = [];
  for (const tier of item.tiers) {
    const last = points[points.length - 1];
    if (last && last.unit === tier.unit) last.units += tier.units;
    else points.push({ unit: tier.unit, units: tier.units });
  }
  return points;
}

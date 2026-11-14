// Flow: what moved between consecutive scans, per item. It is the lab's read
// on demand and supply, which one scan cannot show.
//
// Three grades of knowing, kept apart:
//   observed   what a scan saw listed (the market itself)
//   probable   what this file works out happened between scans
//   confirmed  what the character's own ledger records (not in the lab yet)
//
//   left     units that were listed and are gone
//   relisted the part of `left` that went early while as many units appeared
//            at a lower price: most likely a seller undercutting, not a sale
//   sold     the part of `left` that neither expiry nor a relist explains,
//            from the cheaper half of the ladder. Each listing's time band says how likely it
//            was to run out in the gap between scans; what is missing beyond
//            that went early. Cheap stock that goes early was most likely
//            bought. Dear stock that goes early was most likely cancelled, so
//            it is not counted.
//   arrived  units newly listed
//
// Everything is counted in units at a unit price, not in auctions.
//
// A scan does not name sellers, so a relist is told only by units moving down
// in price. A new seller undercutting while the old stock really sells looks
// the same and is read as a relist, so `sold` leans low. A relist at a higher
// price is still read as a sale. These are estimates, never confirmed sales.
import type { Market, MarketItem } from "./market";
import { ASSUMED_EXPIRY_BANDS } from "../config/sale-detection.ts";
import { uniqueMarkets } from "./history.ts";

const HOURS_PER_DAY = 24;

export interface ItemFlow {
  key: string;
  left: number;
  sold: number;
  soldValue: number; // copper, at the asking prices of what sold
  soldPrice: number | null; // unit price half the sold units went at or under, over every scan
  lastSoldPrice: number | null; // the same, for the newest gap between scans that saw a sale
  lastSoldTime: number | null; // the time of the scan that closed that gap
  relisted: number; // early departures read as moved to a lower price, not sold
  arrived: number;
  shaky: boolean; // some of this item's rows never got a name, so counts may be off
}

export interface Flows {
  hours: number; // how long the compared scans span
  intervals: number;
  byKey: Map<string, ItemFlow>;
}

export function perDay(units: number, flows: Flows): number {
  return flows.hours > 0 ? (units / flows.hours) * HOURS_PER_DAY : 0;
}

type Band = { min: number; max: number | null };

interface Pool {
  unit: number; // price per unit
  units: number;
  bands: Map<number, number>; // time band -> units
}

// An item's units for sale pooled by unit price, whatever the stack size or
// time left. Goods sold by the unit are bought a few at a time, which shrinks
// a seller's stack without removing it: counted by auction that would read as
// one whole stack sold and a smaller one newly listed. Counted by units at a
// price, it reads as what it is.
function pooled(item: MarketItem | undefined): Map<number, Pool> {
  const result = new Map<number, Pool>();
  for (const tier of item?.tiers ?? []) {
    const unit = tier.buyout / tier.stack;
    let pool = result.get(unit);
    if (!pool) {
      pool = { unit, units: 0, bands: new Map() };
      result.set(unit, pool);
    }
    pool.units += tier.units;
    pool.bands.set(tier.timeLeft, (pool.bands.get(tier.timeLeft) ?? 0) + tier.units);
  }
  return result;
}

// The share of listings in a time band expected to run out within `gap`
// seconds, taking their time left as spread evenly across the band. A band
// with no known bounds counts as certain to expire, so it never invents a sale.
export function expiryShare(band: Band | undefined, gap: number): number {
  if (!band || !Number.isFinite(band.min) || band.min < 0) return 1;
  if (gap <= band.min) return 0;
  if (band.max === null || !Number.isFinite(band.max) || band.max <= band.min) return 1;
  return Math.min(1, (gap - band.min) / (band.max - band.min));
}

// Takes probable relists out of the units that left early. A seller who is
// undercut cancels and lists again lower, so units that left a price while
// units appeared at a lower one are read as moved, not sold. The dearest
// departures are matched first, each against the nearest lower arrival.
export function withoutRelists(
  early: { unit: number; units: number }[],
  arrivals: { unit: number; units: number }[],
): { unit: number; units: number }[] {
  const lower = arrivals.map((arrival) => ({ ...arrival })).sort((a, b) => b.unit - a.unit);
  const sold: { unit: number; units: number }[] = [];
  for (const departure of [...early].sort((a, b) => b.unit - a.unit)) {
    let units = departure.units;
    for (const arrival of lower) {
      if (units <= 0) break;
      if (arrival.unit >= departure.unit || arrival.units <= 0) continue;
      const moved = Math.min(units, arrival.units);
      arrival.units -= moved;
      units -= moved;
    }
    if (units > 0) sold.push({ unit: departure.unit, units });
  }
  return sold;
}

function weightedMedian(prices: { unit: number; units: number }[]): number | null {
  const total = prices.reduce((sum, price) => sum + price.units, 0);
  if (total <= 0) return null;
  let running = 0;
  for (const price of [...prices].sort((a, b) => a.unit - b.unit)) {
    running += price.units;
    if (running >= total / 2) return Math.floor(price.unit);
  }
  return null;
}

// Flows across every adjacent pair of scans from the newest scan's market.
export function buildFlows(archive: Market[], useAssumedBands = true): Flows {
  const all = uniqueMarkets(archive);
  const latest = all[all.length - 1];
  const scans = latest ? all.filter((scan) => scan.meta.place === latest.meta.place) : [];
  const byKey = new Map<string, ItemFlow>();
  const soldPrices = new Map<string, { unit: number; units: number }[]>();
  const flow = (key: string): ItemFlow => {
    let entry = byKey.get(key);
    if (!entry) {
      entry = { key, left: 0, sold: 0, soldValue: 0, soldPrice: null, lastSoldPrice: null, lastSoldTime: null, relisted: 0, arrived: 0, shaky: false };
      byKey.set(key, entry);
    }
    return entry;
  };

  let seconds = 0;
  let intervals = 0;
  for (let index = 1; index < scans.length; index++) {
    const before = scans[index - 1] as Market;
    const after = scans[index] as Market;
    seconds += after.meta.time - before.meta.time;
    intervals++;

    const gap = after.meta.time - before.meta.time;
    const band = (id: number): Band | undefined =>
      before.meta.timeLeftBands?.[id] ?? (useAssumedBands ? ASSUMED_EXPIRY_BANDS[id] : undefined);
    const unnamed = new Set<number>();
    for (const item of before.items) if (item.name === null) unnamed.add(item.id);
    for (const item of after.items) if (item.name === null) unnamed.add(item.id);
    // An item patched by a live check holds rows from a later moment than its
    // scan, so what left and what arrived cannot be timed. It is left out,
    // the same way an item with nameless rows is.
    for (const scan of [before, after]) {
      for (const patch of Array.isArray(scan.meta.patched) ? scan.meta.patched : []) unnamed.add(patch.id);
    }

    for (const item of before.items) {
      if (item.name === null) continue;
      if (unnamed.has(item.id)) {
        // A named variant can seem to vanish when its name simply did not arrive.
        flow(item.key).shaky = true;
        continue;
      }
      const earlier = pooled(item);
      const later = pooled(after.byKey.get(item.key));
      const early: { unit: number; units: number }[] = [];
      for (const [unit, pool] of earlier) {
        const remaining = later.get(unit)?.units ?? 0;
        const missing = pool.units - remaining;
        if (missing <= 0) continue;
        flow(item.key).left += missing;
        let expiring = 0;
        for (const [id, units] of pool.bands) expiring += units * expiryShare(band(id), gap);
        const units = Math.max(0, pool.units - expiring - remaining);
        if (units > 0 && item.median !== null && unit <= item.median) early.push({ unit, units });
      }
      if (early.length === 0) continue;

      const arrivals: { unit: number; units: number }[] = [];
      for (const [unit, pool] of later) {
        const units = pool.units - (earlier.get(unit)?.units ?? 0);
        if (units > 0) arrivals.push({ unit, units });
      }
      const entry = flow(item.key);
      const sold = withoutRelists(early, arrivals);
      const soldUnits = sold.reduce((sum, price) => sum + price.units, 0);
      entry.relisted += early.reduce((sum, price) => sum + price.units, 0) - soldUnits;
      if (soldUnits <= 0) continue;
      entry.sold += soldUnits;
      entry.soldValue += sold.reduce((sum, price) => sum + price.units * price.unit, 0);
      soldPrices.set(entry.key, [...(soldPrices.get(entry.key) ?? []), ...sold]);
      // Scans run oldest first, so the last interval with a sale wins.
      entry.lastSoldPrice = weightedMedian(sold);
      entry.lastSoldTime = after.meta.time;
    }

    for (const item of after.items) {
      if (item.name === null || unnamed.has(item.id)) continue;
      const earlier = pooled(before.byKey.get(item.key));
      let arrived = 0;
      for (const [unit, pool] of pooled(item)) {
        arrived += Math.max(0, pool.units - (earlier.get(unit)?.units ?? 0));
      }
      if (arrived > 0) flow(item.key).arrived += arrived;
    }
  }

  for (const [key, prices] of soldPrices) {
    const entry = byKey.get(key);
    if (entry) entry.soldPrice = weightedMedian(prices);
  }
  return { hours: seconds / 3600, intervals, byKey };
}

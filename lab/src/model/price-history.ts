// Price history: one point per day per item, built from the scans. This is
// the same record the addon keeps (AuctioNitro/market/history.lua): several
// scans on one day leave one point, the latest.
import { SAMPLE_BELOW_DAYS, SAMPLE_DAYS } from "../config/history-view";
import type { Market, MarketItem } from "./market";

const SECONDS_PER_DAY = 86400;

export interface PricePoint {
  day: number; // days since 1970
  median: number;
  low: number;
  units: number;
}

export interface ItemHistory {
  item: MarketItem; // the item as last seen
  points: PricePoint[]; // oldest first
  sample: boolean; // true when the points were made up for the lab
}

export function dayOf(time: number): number {
  return Math.floor(time / SECONDS_PER_DAY);
}

// Real history: fold every scan in, oldest first.
export function buildHistory(markets: Market[]): Map<string, ItemHistory> {
  const histories = new Map<string, ItemHistory>();
  const ordered = [...markets].sort((a, b) => a.meta.time - b.meta.time);
  for (const market of ordered) {
    const day = dayOf(market.meta.time);
    for (const item of market.items) {
      if (item.name === null || item.median === null || item.min === null) continue;
      const point: PricePoint = { day, median: item.median, low: item.min, units: item.units };
      const history = histories.get(item.key);
      if (!history) {
        histories.set(item.key, { item, points: [point], sample: false });
        continue;
      }
      history.item = item;
      const last = history.points[history.points.length - 1];
      if (last && last.day === day) history.points[history.points.length - 1] = point;
      else history.points.push(point);
    }
  }
  return histories;
}

// A small repeatable random number generator, seeded from the item's key, so
// an item's sample history looks the same every time.
function seeded(key: string): () => number {
  let state = 2166136261;
  for (let index = 0; index < key.length; index++) {
    state = Math.imul(state ^ key.charCodeAt(index), 16777619);
  }
  return () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let mixed = Math.imul(state ^ (state >>> 15), 1 | state);
    mixed = (mixed + Math.imul(mixed ^ (mixed >>> 7), 61 | mixed)) ^ mixed;
    return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296;
  };
}

// Sample history, for the lab only: when an item has too few real days to
// draw, walk backwards from its real latest point with small random steps.
// Some days are skipped, as they would be for an item not always listed.
export function withSample(history: ItemHistory): ItemHistory {
  if (history.points.length >= SAMPLE_BELOW_DAYS) return history;
  const latest = history.points[history.points.length - 1];
  if (!latest) return history;
  const random = seeded(history.item.key);
  const points: PricePoint[] = [latest];
  let median = latest.median;
  let units = latest.units;
  for (let back = 1; back < SAMPLE_DAYS; back++) {
    median = Math.max(1, median * (1 + (random() - 0.5) * 0.12));
    units = Math.max(1, units * (1 + (random() - 0.5) * 0.3));
    if (random() < 0.12) continue; // not seen that day
    const low = Math.max(1, median * (0.7 + random() * 0.28));
    points.unshift({ day: latest.day - back, median: Math.round(median), low: Math.round(low), units: Math.round(units) });
  }
  return { item: history.item, points, sample: true };
}

// The points inside the last `days` days, counted back from the newest point.
export function inRange(points: PricePoint[], days: number): PricePoint[] {
  const newest = points[points.length - 1];
  if (!newest) return [];
  return points.filter((point) => point.day > newest.day - days);
}

export interface HistorySummary {
  usual: number; // the newest median
  lowest: number; // lowest price in the range
  highest: number; // highest median in the range
  change: number | null; // percent the usual price moved across the range
  days: number; // days seen in the range
}

export function summarize(points: PricePoint[]): HistorySummary | null {
  const first = points[0];
  const last = points[points.length - 1];
  if (!first || !last) return null;
  return {
    usual: last.median,
    lowest: Math.min(...points.map((point) => point.low)),
    highest: Math.max(...points.map((point) => point.median)),
    change: points.length > 1 && first.median > 0 ? Math.round(((last.median - first.median) / first.median) * 100) : null,
    days: points.length,
  };
}

import type { Market } from "./market";
import { finishMarketItem } from "./market.ts";
import { aggregateMarket, uniqueMarkets } from "./history.ts";
import { ASSUMED_EXPIRY_BANDS } from "../config/sale-detection.ts";

export interface TimelineView {
  asOf: number;
  markets: Market[];
  market: Market | null;
  expiredUnits: number;
  uncertainUnits: number;
  unknownUnits: number;
  assumed: boolean;
}

// Only knowledge available at the chosen instant enters history or sale
// evidence. Between scans this projects expiry, never future sales/arrivals.
export function marketAtTime(archive: Market[], asOf: number, useAssumedBands = true): TimelineView {
  if (!Number.isFinite(asOf)) throw new Error("Choose a valid viewing date.");
  const markets = uniqueMarkets(archive).filter((scan) => scan.meta.time <= asOf);
  const result: TimelineView = { asOf, markets, market: null, expiredUnits: 0, uncertainUnits: 0, unknownUnits: 0, assumed: false };
  if (!markets.length) return result;
  const market = aggregateMarket(markets);
  const age = asOf - market.meta.time;
  const readTime = Math.max(0, market.meta.elapsed || 0);
  const items = market.items.map((source) => {
    let uncertain = 0, unknown = 0;
    const tiers = source.tiers.filter((tier) => {
      let band = market.meta.timeLeftBands?.[tier.timeLeft];
      const valid = (entry: typeof band): boolean => !!entry && Number.isFinite(entry.min) && entry.min >= 0
        && (entry.max === null || (Number.isFinite(entry.max) && entry.max >= entry.min));
      if (!valid(band)) {
        band = useAssumedBands ? ASSUMED_EXPIRY_BANDS[tier.timeLeft] : undefined;
        if (valid(band)) result.assumed = true;
      }
      if (!valid(band) || !band) { unknown += tier.units; return true; }
      // Using completion time for the upper bound avoids prematurely dropping
      // a row that was read near the end of a long scan.
      if (band.max !== null && age >= band.max) { result.expiredUnits += tier.units; return false; }
      if (age + readTime >= band.min) uncertain += tier.units;
      return true;
    });
    const units = tiers.reduce((sum, tier) => sum + tier.units, 0);
    const buyoutListings = tiers.reduce((sum, tier) => sum + tier.copies, 0);
    const item = { ...source, tiers, units, listings: buyoutListings + source.bidOnly,
      value: tiers.reduce((sum, tier) => sum + tier.buyout * tier.copies, 0),
      expiryUncertainUnits: uncertain, expiryUnknownUnits: unknown };
    finishMarketItem(item);
    result.uncertainUnits += uncertain;
    result.unknownUnits += unknown;
    return item;
  }).filter((item) => item.listings > 0);
  result.market = { meta: market.meta, items, byKey: new Map(items.map((item) => [item.key, item])) };
  return result;
}

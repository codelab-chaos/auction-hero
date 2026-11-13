// One archive for the SPA. Stock is the latest full snapshot; history is
// folded once per unique scan. Repeated observations never multiply stock.
import type { Market, MarketItem } from "./market";
import { compareMarkets, type PossibleSale, type DetectionConfidence } from "./possible-sales.ts";
import { HISTORY_SMOOTHING } from "../config/history.ts";

export function uniqueMarkets(markets: Market[]): Market[] {
  const unique = new Map<string, Market>();
  for (const market of markets) {
    if (market.meta.stale || market.meta.source !== "replicate") continue;
    unique.set(JSON.stringify([market.meta.place, market.meta.source, market.meta.time]), market);
  }
  return [...unique.values()].sort((a, b) => a.meta.time - b.meta.time);
}

export function aggregateMarket(markets: Market[]): Market {
  const scans = uniqueMarkets(markets);
  const latest = scans[scans.length - 1];
  if (!latest) throw new Error("No fresh full scans available.");
  const history = new Map<string, { scans: number; usual: number | null }>();
  for (const scan of scans) {
    if (scan.meta.place !== latest.meta.place || scan.meta.source !== latest.meta.source) continue;
    for (const item of scan.items) {
      if (!item.name) continue;
      const old = history.get(item.key);
      const usual = item.median === null ? old?.usual ?? null
        : old?.usual == null ? item.median : Math.round(old.usual + (item.median - old.usual) * HISTORY_SMOOTHING);
      history.set(item.key, { scans: (old?.scans ?? 0) + 1, usual });
    }
  }
  const items: MarketItem[] = latest.items.map((item) => ({
    ...item, scansSeen: history.get(item.key)?.scans ?? 1, usual: history.get(item.key)?.usual ?? item.median,
  }));
  return { meta: latest.meta, items, byKey: new Map(items.map((item) => [item.key, item])) };
}

export interface SaleInterval {
  from: number;
  to: number;
  units: number;
  saleScore: number | null;
  expiryScore: number | null;
}

export interface HistoricalSale extends PossibleSale {
  marketPlace: string;
  intervals: SaleInterval[];
}

export function aggregateSales(markets: Market[], useAssumedBands = true): { rows: HistoricalSale[]; comparisons: number } {
  const previous = new Map<string, Market>();
  const totals = new Map<string, HistoricalSale>();
  let comparisons = 0;
  const average = (old: DetectionConfidence, next: DetectionConfidence, oldUnits: number, newUnits: number): DetectionConfidence => ({
    // Missing timing contributes no positive evidence, rather than silently
    // inheriting the score of the intervals whose timing is known.
    score: old.score === null && next.score === null ? null
      : ((old.score ?? 0) * oldUnits + (next.score ?? 0) * newUnits) / (oldUnits + newUnits),
    reasons: [...new Set([...old.reasons, ...next.reasons])],
  });
  for (const after of uniqueMarkets(markets)) {
    const scope = JSON.stringify([after.meta.place, after.meta.source]);
    const before = previous.get(scope);
    previous.set(scope, after);
    if (!before) continue;
    comparisons++;
    for (const row of compareMarkets(before, after, useAssumedBands)) {
      const key = JSON.stringify([scope, row.item.key, row.stack, row.buyout]);
      const interval = { from: before.meta.time, to: after.meta.time, units: row.units, saleScore: row.saleConfidence.score, expiryScore: row.expiryConfidence.score };
      const old = totals.get(key);
      if (!old) { totals.set(key, { ...row, marketPlace: after.meta.place, intervals: [interval] }); continue; }
      old.saleConfidence = average(old.saleConfidence, row.saleConfidence, old.units, row.units);
      old.expiryConfidence = average(old.expiryConfidence, row.expiryConfidence, old.units, row.units);
      old.after = row.after;
      old.supplyAfter = row.supplyAfter;
      old.missing += row.missing;
      old.units += row.units;
      old.askingValue += row.askingValue;
      old.couldExpireUnits += row.couldExpireUnits;
      old.beyondExpiryUnits += row.beyondExpiryUnits;
      old.deadlinePassedUnits += row.deadlinePassedUnits;
      old.unknownTimingUnits += row.unknownTimingUnits;
      old.higherRetainedUnits += row.higherRetainedUnits;
      old.unresolved ||= row.unresolved;
      if (row.timingSource === "assumed" || old.timingSource === "assumed") old.timingSource = "assumed";
      else if (row.timingSource === "unknown") old.timingSource = "unknown";
      old.intervals.push(interval);
    }
  }
  for (const row of totals.values()) {
    const cap = row.unresolved ? 25 : row.timingSource === "assumed" ? 65 : 95;
    if (row.saleConfidence.score !== null) row.saleConfidence.score = Math.min(cap, Math.round(row.saleConfidence.score));
    if (row.expiryConfidence.score !== null) row.expiryConfidence.score = Math.min(cap, Math.round(row.expiryConfidence.score));
    if (row.intervals.length > 1) {
      const explanation = `Aggregated over ${row.intervals.length} intervals. Scores are weighted by missing units, not added. Reasons below describe contributing intervals.`;
      row.saleConfidence.reasons.unshift(explanation);
      row.expiryConfidence.reasons.unshift(explanation);
    }
  }
  return { rows: [...totals.values()], comparisons };
}

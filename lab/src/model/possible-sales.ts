// A decrease in matching listings is a possible sale, cancellation or expiry.
// Match variant + stack + exact buyout, pooling time bands and bid changes.
// New identical listings can mask departures; these are net tier decreases.
import type { Market, MarketItem } from "./market";
import { ASSUMED_EXPIRY_BANDS, SALE_DETECTION as RULE } from "../config/sale-detection.ts";

export interface DetectionConfidence {
  score: number | null;
  reasons: string[];
}

interface CountedTier {
  stack: number;
  buyout: number;
  copies: number;
  bands: { band: number; copies: number }[];
}

export interface PossibleSale {
  item: MarketItem;
  stack: number;
  buyout: number;
  before: number;
  after: number;
  missing: number;
  units: number;
  askingValue: number;
  supplyBefore: number;
  supplyAfter: number;
  unresolved: boolean;
  couldExpireUnits: number;
  beyondExpiryUnits: number;
  deadlinePassedUnits: number;
  unknownTimingUnits: number;
  higherRetainedUnits: number;
  timingSource: "recorded" | "assumed" | "unknown";
  saleConfidence: DetectionConfidence;
  expiryConfidence: DetectionConfidence;
}

export function compareMarkets(before: Market, after: Market, useAssumedBands = true): PossibleSale[] {
  if (before.meta.place !== after.meta.place || before.meta.source !== after.meta.source) {
    throw new Error("Choose two scans from the same market and source.");
  }
  if (before.meta.source !== "replicate") throw new Error("This comparison needs full scans.");
  if (before.meta.time >= after.meta.time) throw new Error("The comparison scan must be older than the selected scan.");
  if (before.meta.stale || after.meta.stale) throw new Error("A scan contains a cached server list. Choose fresh scans to compare.");

  const unresolved = new Set<number>();
  for (const item of [...before.items, ...after.items]) {
    if (!item.name) unresolved.add(item.id);
  }
  const counts = (item: MarketItem | undefined): Map<string, CountedTier> => {
    const result = new Map<string, CountedTier>();
    for (const tier of item?.tiers ?? []) {
      const key = `${tier.stack}:${tier.buyout}`;
      const existing = result.get(key);
      const band = { band: tier.timeLeft, copies: tier.copies };
      if (existing) {
        existing.copies += tier.copies;
        existing.bands.push(band);
      } else result.set(key, { stack: tier.stack, buyout: tier.buyout, copies: tier.copies, bands: [band] });
    }
    return result;
  };

  // A scan is stamped at completion; rows were observed during its download.
  // Use the widest possible interval when ruling expiry out, and the shortest
  // when saying a deadline has passed.
  const gap = after.meta.time - before.meta.time;
  const gapMax = gap + Math.max(0, before.meta.elapsed || 0);
  const gapMin = Math.max(0, gap - Math.max(0, after.meta.elapsed || 0));
  const gapStrength = Math.min(1, Math.sqrt(RULE.fullStrengthGapSeconds / gapMax));
  const validBand = (band: { min: number; max: number | null } | undefined): boolean =>
    !!band && Number.isFinite(band.min) && band.min >= 0 && (band.max === null || (Number.isFinite(band.max) && band.max >= band.min));

  const rows: PossibleSale[] = [];
  for (const item of before.items) {
    if (!item.name) continue;
    const current = after.byKey.get(item.key);
    const later = counts(current);
    const earlier = [...counts(item)].sort(([, a], [, b]) => a.buyout / a.stack - b.buyout / b.stack);
    const higher = new Map<string, { units: number; retained: number }>();
    let higherUnits = 0, retainedUnits = 0;
    // Strictly higher prices only; exclude ties across different stack sizes.
    for (let end = earlier.length; end > 0;) {
      let start = end - 1;
      const last = earlier[start]![1];
      while (start > 0 && earlier[start - 1]![1].buyout / earlier[start - 1]![1].stack === last.buyout / last.stack) start--;
      for (let i = start; i < end; i++) higher.set(earlier[i]![0], { units: higherUnits, retained: retainedUnits });
      for (let i = start; i < end; i++) {
        const [key, tier] = earlier[i]!;
        higherUnits += tier.copies * tier.stack;
        retainedUnits += Math.min(tier.copies, later.get(key)?.copies ?? 0) * tier.stack;
      }
      end = start;
    }
    let runningUnits = 0;
    let usual = 0;
    for (const [, tier] of earlier) {
      runningUnits += tier.copies * tier.stack;
      if (runningUnits >= item.units / 2) { usual = tier.buyout / tier.stack; break; }
    }
    for (const [key, tier] of earlier) {
      const remaining = later.get(key)?.copies ?? 0;
      const missing = Math.max(0, tier.copies - remaining);
      if (!missing) continue;
      let eligible = 0, deadline = 0, unknown = 0, assumed = false;
      for (const entry of tier.bands) {
        let band = before.meta.timeLeftBands?.[entry.band];
        if (!validBand(band)) {
          band = useAssumedBands ? ASSUMED_EXPIRY_BANDS[entry.band] : undefined;
          if (validBand(band)) assumed = true;
        }
        if (!validBand(band) || !band) { unknown += entry.copies; continue; }
        if (band.min <= gapMax) eligible += entry.copies;
        if (band.max !== null && band.max <= gapMin) deadline += entry.copies;
      }
      const couldExpire = Math.min(missing, eligible + unknown);
      const beyondExpiry = missing - couldExpire;
      const deadlinePassed = Math.min(missing, deadline);
      const unknownTiming = Math.min(missing, unknown);
      const timingSource = unknown === tier.copies ? "unknown" : assumed ? "assumed" : "recorded";
      const higherStock = higher.get(key)!;
      const cheap = tier.buyout / tier.stack <= usual;
      const priceOrder = cheap && higherStock.units > 0
        ? (higherStock.retained / higherStock.units) * Math.min(1, higherStock.retained / (missing * tier.stack)) * (missing / tier.copies)
        : 0;
      const hasGaps = unresolved.has(item.id);
      const qualityCap = hasGaps ? RULE.unresolvedCap : assumed ? RULE.assumedCap : RULE.maxScore;
      // Scale into the quality cap rather than just clipping: selective cheap
      // depletion must still outrank timing-only evidence on assumed bands.
      const cap = (value: number, limit = qualityCap): number => Math.max(0, Math.min(limit, Math.round(value * gapStrength * limit / RULE.maxScore)));
      const timingReasons = [
        `Up to ${couldExpire * tier.stack} missing units could be explained by expiry; ${beyondExpiry * tier.stack} are beyond that allowance.`,
        `${deadlinePassed * tier.stack} missing units could match earlier listings whose deadline has passed; this does not prove they expired.`,
      ];
      const caveats = [
        ...(assumed ? ["Uses assumed time bands, not recorded Forever boundaries; scores are capped at 65."] : []),
        ...(unknownTiming ? [`Expiry timing is unknown for up to ${unknownTiming * tier.stack} missing units.`] : []),
        ...(hasGaps ? ["Unnamed variants can distort this delta; scores are capped at 25."] : []),
        ...(gapStrength < 1 ? ["A gap over two hours weakens the evidence because arrivals and departures can be hidden."] : []),
        "Evidence score, not a sale or expiry probability. Cancellations and replacement listings remain possible.",
      ];
      const saleConfidence: DetectionConfidence = {
        score: cap(RULE.saleBase + RULE.beforeExpiryPoints * beyondExpiry / missing + RULE.priceOrderPoints * priceOrder,
          Math.min(qualityCap, timingSource === "unknown" ? RULE.priceOnlyCap : RULE.maxScore)),
        reasons: [...timingReasons,
          priceOrder > 0 ? `${higherStock.retained} units remain at matching higher-priced tiers while this cheaper tier shrank.`
            : "No clear pattern of cheaper stock disappearing while higher-priced stock remains.",
          ...caveats],
      };
      const expiryConfidence: DetectionConfidence = {
        score: timingSource === "unknown" ? null : cap(
          (RULE.expiryPossiblePoints * Math.min(missing, eligible) / missing + RULE.expiryDeadlinePoints * deadlinePassed / missing)
          * (1 - RULE.priceOrderExpiryDiscount * priceOrder)),
        reasons: [...timingReasons, ...(priceOrder > 0 ? ["Selective depletion of cheaper stock also supports a sale explanation."] : []), ...caveats],
      };
      rows.push({
        item, stack: tier.stack, buyout: tier.buyout,
        before: tier.copies, after: remaining, missing,
        units: missing * tier.stack, askingValue: missing * tier.buyout,
        supplyBefore: item.units, supplyAfter: current?.units ?? 0,
        unresolved: hasGaps,
        couldExpireUnits: couldExpire * tier.stack, beyondExpiryUnits: beyondExpiry * tier.stack,
        deadlinePassedUnits: deadlinePassed * tier.stack, unknownTimingUnits: unknownTiming * tier.stack,
        higherRetainedUnits: higherStock.retained, timingSource, saleConfidence, expiryConfidence,
      });
    }
  }
  return rows;
}

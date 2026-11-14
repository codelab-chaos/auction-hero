// A full scan leaves some rows without a name: the game had not loaded the
// item's data when the row was read. The row still has its item id, stack and
// price. When an id has only ever been seen under one name, in any scan, the
// unnamed rows are that item, and they are folded into it. An id seen under
// several names (gear with random suffixes) stays unresolved: there is no
// telling which one a nameless row is.
import { finishMarketItem, type Market, type MarketItem } from "./market.ts";

export function nameUnresolved(markets: Market[]): Market[] {
  const known = new Map<number, Map<string, MarketItem>>();
  for (const market of markets) {
    for (const item of market.items) {
      if (item.name === null) continue;
      const names = known.get(item.id) ?? new Map<string, MarketItem>();
      names.set(item.key, item);
      known.set(item.id, names);
    }
  }

  return markets.map((market) => {
    const byKey = new Map(market.byKey);
    const touched = new Set<MarketItem>();
    for (const item of market.items) {
      const names = item.name === null ? known.get(item.id) : undefined;
      if (!names || names.size !== 1) continue;
      const record = names.values().next().value as MarketItem;
      let target = byKey.get(record.key);
      if (!target || !touched.has(target)) {
        // Never change an item another market may share: work on a copy.
        const source = target ?? { ...record, listings: 0, units: 0, bidOnly: 0, value: 0 };
        target = { ...source, tiers: target ? [...target.tiers] : [] };
        byKey.set(target.key, target);
        touched.add(target);
      }
      target.tiers.push(...item.tiers);
      target.listings += item.listings;
      target.units += item.units;
      target.bidOnly += item.bidOnly;
      target.value += item.value;
      byKey.delete(item.key);
    }
    if (touched.size === 0) return market;
    touched.forEach(finishMarketItem);
    return { meta: market.meta, items: [...byKey.values()], byKey };
  });
}

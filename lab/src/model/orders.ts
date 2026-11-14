// Orders: what buying a quantity of an item would actually involve.
//
// The game has two ways to buy, and an item only ever uses one of them:
//   Commodities (stackable goods) are bought by the unit. You ask for a
//     quantity and get exactly that, cheapest sellers first, in one purchase.
//   Everything else is bought one whole auction at a time. A stack cannot be
//     split, and every auction is its own purchase.
import { isCommodity } from "../config/catalog";
import type { MarketItem, Tier } from "./market";

export interface OrderLine {
  tier: Tier;
  units: number; // units taken at this price
  auctions: number; // whole auctions bought here. 0 for commodities, which have none
}

export interface Order {
  byUnit: boolean; // true for a commodity
  lines: OrderLine[];
  units: number; // units received. For whole auctions this can exceed what was asked
  cost: number;
  purchases: number; // how many times you buy: 1 for a commodity, one per auction otherwise
  averageUnit: number | null;
  short: number; // units asked for that the market could not supply
}

// Fills a quantity from the cheapest unit price up.
export function fillOrder(item: MarketItem, wanted: number): Order {
  const byUnit = isCommodity(item);
  const lines: OrderLine[] = [];
  let units = 0;
  let cost = 0;
  let auctions = 0;
  for (const tier of item.tiers) {
    if (units >= wanted) break;
    if (byUnit) {
      const take = Math.min(tier.units, wanted - units);
      lines.push({ tier, units: take, auctions: 0 });
      units += take;
      cost += take * tier.unit;
    } else {
      const take = Math.min(tier.copies, Math.ceil((wanted - units) / tier.stack));
      lines.push({ tier, units: take * tier.stack, auctions: take });
      units += take * tier.stack;
      cost += take * tier.buyout;
      auctions += take;
    }
  }
  return {
    byUnit,
    lines,
    units,
    cost,
    purchases: units === 0 ? 0 : byUnit ? 1 : auctions,
    averageUnit: units > 0 ? Math.floor(cost / units) : null,
    short: Math.max(0, wanted - units),
  };
}

// One auction at a chosen unit price, in the shape fillOrder returns: the
// player picked that price in the list and wants that one, not the cheapest.
export function fillAt(item: MarketItem, unit: number): Order | null {
  const tier = item.tiers.find((candidate) => candidate.unit === unit);
  if (!tier) return null;
  return { byUnit: false, lines: [{ tier, units: tier.stack, auctions: 1 }], units: tier.stack, cost: tier.buyout, purchases: 1, averageUnit: tier.unit, short: 0 };
}

// Corner: items where the whole cheap end of the market can be bought and
// relisted just under the next price up. After the purchase nobody is listed
// under you, so the price is yours until other sellers restock.
//
// It only pays when the item is sought after (units keep selling) and slow to
// restock (few new units are listed per unit sold). Both are read off the
// flow between scans.
import { ASSUMPTIONS } from "../config/catalog.ts";
import type { CornerParams } from "../config/banker.ts";
import { perDay, type Flows, type ItemFlow } from "./flow.ts";
import type { MarketItem } from "./market";
import type { ResellLine } from "./resell.ts";

export interface CornerLead {
  item: MarketItem;
  flow: ItemFlow;
  lines: ResellLine[]; // what to buy, cheapest first
  buyAuctions: number;
  buyUnits: number;
  cost: number;
  averageUnit: number;
  wall: number | null; // the next unit price up. null when you buy the whole market
  relist: number; // unit price to relist at
  share: number; // percent of the units for sale that you would hold
  overUsual: number; // the relist price as a percent of the usual price
  revenue: number; // after the auction house's cut
  profit: number;
  roi: number;
  soldPerDay: number;
  restock: number; // units newly listed per unit sold
  daysToSell: number; // at the pace seen at the old prices
  profitPerDay: number;
}

// The best corner on one item, or null when none passes the rules.
export function planCorner(item: MarketItem, flow: ItemFlow, flows: Flows, params: CornerParams): CornerLead | null {
  const usual = item.usual ?? item.median;
  const first = item.tiers[0];
  if (usual === null || !first || item.units <= 0) return null;
  const soldPerDay = perDay(flow.sold, flows);
  if (soldPerDay <= 0 || soldPerDay < params.minSoldPerDay) return null;
  const restock = flow.sold > 0 ? flow.arrived / flow.sold : Infinity;
  if (restock > params.maxRestock) return null;
  const ceiling = Math.floor((usual * params.maxOverUsualPercent) / 100);

  let best: CornerLead | null = null;
  const lines: ResellLine[] = [];
  let buyAuctions = 0;
  let buyUnits = 0;
  let cost = 0;
  for (let index = 0; index < item.tiers.length; index++) {
    const tier = item.tiers[index]!;
    lines.push({ tier, auctions: tier.copies });
    buyAuctions += tier.copies;
    buyUnits += tier.units;
    cost += tier.buyout * tier.copies;
    if (params.budget > 0 && cost > params.budget) break;

    // Only cut where the price steps up: leaving a listing at the price you
    // just paid would leave it under you.
    const next = item.tiers[index + 1];
    if (next && next.unit === tier.unit) continue;
    const wall = next ? next.unit : null;
    const relist = Math.min(wall === null ? ceiling : wall - 1, ceiling);
    const averageUnit = cost / buyUnits;
    if (relist <= first.unit || relist < averageUnit * (1 + params.minMarkupPercent / 100)) continue;

    const revenue = Math.floor(buyUnits * relist * (1 - ASSUMPTIONS.auctionCut));
    const profit = revenue - cost;
    const daysToSell = buyUnits / soldPerDay;
    if (profit < params.minProfit || daysToSell > params.maxDays) continue;
    const profitPerDay = Math.floor(profit / Math.max(1, daysToSell));
    if (best && best.profitPerDay >= profitPerDay) continue;
    best = {
      item, flow, lines: [...lines], buyAuctions, buyUnits, cost,
      averageUnit: Math.floor(averageUnit), wall, relist,
      share: Math.round((buyUnits / item.units) * 100),
      overUsual: Math.round((relist / usual) * 100),
      revenue, profit, roi: Math.floor((profit / cost) * 100),
      soldPerDay, restock, daysToSell, profitPerDay,
    };
  }
  return best;
}

export function findCorners(items: MarketItem[], flows: Flows, params: CornerParams): CornerLead[] {
  const leads: CornerLead[] = [];
  for (const item of items) {
    if (item.name === null) continue;
    const flow = flows.byKey.get(item.key);
    if (!flow || flow.shaky) continue;
    const lead = planCorner(item, flow, flows, params);
    if (lead) leads.push(lead);
  }
  return leads;
}

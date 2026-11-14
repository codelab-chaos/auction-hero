// Flips: listings priced under the going rate that can be bought and relisted
// at it, ranked by how fast the money comes back. A flip never needs the
// price to move: it relists at a price the item has been leaving the auction
// house at.
import type { FlipParams } from "../config/banker.ts";
import { FLOW_RULE } from "../config/banker.ts";
import { perDay, type Flows, type ItemFlow } from "./flow.ts";
import type { MarketItem } from "./market";
import { planResell, type ResellLead } from "./resell.ts";

export interface FlipLead extends ResellLead {
  flow: ItemFlow;
  proven: boolean; // the relist price is one units were seen selling at
  soldPerDay: number;
  daysToSell: number; // your load plus what is listed ahead of it, at the seen pace
  profitPerDay: number;
}

// The price to relist at: the usual price, held down to what units actually
// sold at when enough were seen selling.
export function relistPrice(item: MarketItem, flow: ItemFlow | undefined): { price: number | null; proven: boolean } {
  const usual = item.usual ?? item.median;
  if (usual === null) return { price: null, proven: false };
  if (flow && flow.soldPrice !== null && flow.sold >= FLOW_RULE.minSoldForPrice) {
    return { price: Math.min(usual, flow.soldPrice), proven: true };
  }
  return { price: usual, proven: false };
}

export function findFlips(items: MarketItem[], flows: Flows, params: FlipParams): FlipLead[] {
  const leads: FlipLead[] = [];
  for (const item of items) {
    if (item.name === null) continue;
    const flow = flows.byKey.get(item.key);
    if (!flow || flow.sold < params.minSold) continue;
    const { price, proven } = relistPrice(item, flow);
    if (price === null) continue;
    const plan = planResell(item, { marginPercent: params.marginPercent, minListings: 1 }, Infinity, price);
    if (!plan || plan.profit < params.minProfit) continue;
    if (params.budget > 0 && plan.cost > params.budget) continue;
    const soldPerDay = perDay(flow.sold, flows);
    if (soldPerDay <= 0) continue;
    const daysToSell = (plan.buyUnits + plan.competition) / soldPerDay;
    if (daysToSell > params.maxDays) continue;
    leads.push({ ...plan, flow, proven, soldPerDay, daysToSell, profitPerDay: Math.floor(plan.profit / Math.max(1, daysToSell)) });
  }
  return leads;
}

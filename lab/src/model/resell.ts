// Resell: finds items where buying the cheap end of the ladder and relisting
// at the usual price would turn a profit, and plans the purchase.
//
// A purchase is always a list of whole auctions, cheapest first. The game sells
// one auction per click and a stack cannot be split, so a plan never asks for
// "some units": it asks for these auctions, at these prices.
//
// Stock comes from the latest snapshot; the usual price comes from history.
// Listing prices can be propped up by auctions that never sell.
import { ASSUMPTIONS } from "../config/catalog";
import type { MarketItem, Tier } from "./market";

export interface ResellParams {
  marginPercent: number; // buy auctions at least this far under the usual price
  budget: number; // copper you have, 0 for no limit. Hides loads you cannot buy out in full
  minProfit: number; // copper
  minListings: number; // ignore thin markets
  // The most units of an item that may be for sale, in all, for it to be a
  // lead. Reselling means buying the market out and relisting it, so only
  // small markets are worth showing. This never trims a plan.
  maxItems: number;
}

export const DEFAULT_RESELL_PARAMS: ResellParams = {
  marginPercent: 30,
  budget: 0,
  minProfit: 5000,
  minListings: 5,
  maxItems: 10,
};

// Auctions to buy at one price point.
export interface ResellLine {
  tier: Tier;
  auctions: number;
}

export interface ResellLead {
  item: MarketItem;
  target: number; // unit price to relist at (the usual price)
  lines: ResellLine[]; // what to buy, cheapest first
  available: number; // auctions cheap enough to be worth buying, before any limit
  buyAuctions: number;
  buyUnits: number;
  cost: number;
  averageUnit: number; // what each unit costs across the purchase
  revenue: number; // after the auction house's cut
  profit: number;
  roi: number; // profit as a percent of cost
  competition: number; // units still listed at or under the target after buying
}

// How many of an item fit in one bag slot. The import records it from the
// game's item tables. For an item those do not know, the biggest stack anyone
// has listed stands in for it.
function maxStack(item: MarketItem): number {
  return item.maxStack ?? item.tiers.reduce((biggest, tier) => Math.max(biggest, tier.stack), 1);
}

// How much of an item is for sale, counted the way it fills bags: a stackable
// item counts by full stacks (100 that stack to 20 is 5), anything else by
// the piece.
export function marketSize(item: MarketItem): number {
  return Math.ceil(item.units / maxStack(item));
}

// Plans a purchase of up to auctionLimit auctions, cheapest first. Returns
// null when the item has no usual price to resell at, or nothing cheap enough.
export function planResell(item: MarketItem, params: ResellParams, auctionLimit = Infinity): ResellLead | null {
  const target = item.usual ?? item.median;
  if (target === null || item.listings - item.bidOnly < params.minListings) return null;
  const ceiling = target * (1 - params.marginPercent / 100);

  const lines: ResellLine[] = [];
  let available = 0;
  let buyAuctions = 0;
  let buyUnits = 0;
  let cost = 0;
  let competition = 0;
  for (const tier of item.tiers) {
    if (tier.unit > target) break;
    const worthBuying = tier.unit <= ceiling ? tier.copies : 0;
    available += worthBuying;
    let take = Math.min(worthBuying, auctionLimit - buyAuctions);
    take = Math.max(0, take);
    if (take > 0) lines.push({ tier, auctions: take });
    buyAuctions += take;
    buyUnits += take * tier.stack;
    cost += take * tier.buyout;
    competition += (tier.copies - take) * tier.stack;
  }
  if (buyUnits === 0) return null;

  const revenue = Math.floor(buyUnits * target * (1 - ASSUMPTIONS.auctionCut));
  const profit = revenue - cost;
  return {
    item,
    target,
    lines,
    available,
    buyAuctions,
    buyUnits,
    cost,
    averageUnit: Math.floor(cost / buyUnits),
    revenue,
    profit,
    roi: Math.floor((profit / cost) * 100),
    competition,
  };
}

// Every item worth flipping, each planned as "buy everything cheap enough".
export function findResellLeads(items: MarketItem[], params: ResellParams): ResellLead[] {
  const leads: ResellLead[] = [];
  for (const item of items) {
    if (item.name === null) continue;
    const lead = planResell(item, params);
    if (!lead || marketSize(item) > params.maxItems) continue;
    // A load you cannot buy out in full is not a lead.
    if (params.budget > 0 && lead.cost > params.budget) continue;
    if (lead.profit >= params.minProfit) leads.push(lead);
  }
  return leads;
}

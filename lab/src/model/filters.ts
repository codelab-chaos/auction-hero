// The Find screen's filter: a plain description of what to keep, and the
// function that applies it.
import { CHARACTER_LEVEL_TYPE, levelOf } from "../config/catalog";
import type { MarketItem } from "./market";

export interface FindFilter {
  text: string;
  qualities: number[]; // empty means any
  levelType: string; // "" means any
  levelMin: number | null;
  levelMax: number | null;
  usableOnly: boolean;
  affordableOnly: boolean; // lowest auction fits the budget
  dealsOnly: boolean;
  type: string; // "" means any. Only scans with item types can use these three
  subType: string;
  slot: string;
  hideUnknown: boolean; // hide items whose data never arrived
}

export const DEFAULT_FIND_FILTER: FindFilter = {
  text: "",
  qualities: [],
  levelType: "",
  levelMin: null,
  levelMax: null,
  usableOnly: false,
  affordableOnly: false,
  dealsOnly: false,
  type: "",
  subType: "",
  slot: "",
  hideUnknown: true,
};

export function applyFindFilter(items: MarketItem[], filter: FindFilter, budget: number, dealPercent: number): MarketItem[] {
  const text = filter.text.trim().toLowerCase();
  return items.filter((item) => {
    if (filter.hideUnknown && item.name === null) return false;
    if (text && !(item.name ?? "").toLowerCase().includes(text)) return false;
    if (filter.qualities.length && (item.quality === null || !filter.qualities.includes(item.quality))) return false;
    if (filter.levelType && item.levelType !== filter.levelType) return false;
    // The level range means required character level. Recipes and bags have
    // a skill or a slot count instead, so a range leaves them out.
    const level = levelOf(item, CHARACTER_LEVEL_TYPE);
    if (filter.levelMin !== null && (level === null || level < filter.levelMin)) return false;
    if (filter.levelMax !== null && (level === null || level > filter.levelMax)) return false;
    if (filter.usableOnly && !item.usable) return false;
    if (filter.dealsOnly && (item.deal === null || item.deal < dealPercent)) return false;
    if (filter.type && item.type !== filter.type) return false;
    if (filter.subType && item.subType !== filter.subType) return false;
    if (filter.slot && item.equipLoc !== filter.slot) return false;
    if (filter.affordableOnly) {
      const cheapest = item.tiers.reduce((low, tier) => Math.min(low, tier.buyout), Infinity);
      if (cheapest > budget) return false;
    }
    return true;
  });
}

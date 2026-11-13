// Posting price rules, as data. Each one looks at an item's ladder and says
// what unit price it would post at. Add a rule here and the Sell tab shows it.
//
//   label  the word on the button. Keep it to a word or two
//   note   the tooltip: what the rule does and when you would pick it
import type { MarketItem } from "../model/market";

export interface PriceRule {
  id: string;
  label: string;
  note: string;
  price: (item: MarketItem) => number | null;
}

// A listing this far under the median is treated as a stray low price that
// will sell out, not as the going rate.
const OUTLIER_SHARE_OF_MEDIAN = 0.5;

export const PRICE_RULES: PriceRule[] = [
  {
    id: "match",
    label: "Match",
    note: "The same price as the cheapest auction. Yours sells after it does.",
    price: (item) => item.min,
  },
  {
    id: "undercut-copper",
    label: "Undercut",
    note: "1 copper under the cheapest auction. First in line, for almost nothing.",
    price: (item) => (item.min === null ? null : Math.max(1, item.min - 1)),
  },
  {
    id: "undercut-percent",
    label: "Quick sale",
    note: "5% under the cheapest auction. Still the cheapest after someone undercuts you by a copper.",
    price: (item) => (item.min === null ? null : Math.max(1, Math.floor(item.min * 0.95))),
  },
  {
    id: "skip-outliers",
    label: "Skip lowballs",
    note: "Ignores stray auctions under half the usual price, then goes 1 copper under the first real one. For when a few cheap listings will sell out before yours matters.",
    price: (item) => {
      const usual = item.usual ?? item.median;
      if (usual === null) return null;
      const floor = usual * OUTLIER_SHARE_OF_MEDIAN;
      const real = item.tiers.find((tier) => tier.unit >= floor);
      return real ? Math.max(1, real.unit - 1) : null;
    },
  },
  {
    id: "median",
    label: "Usual price",
    note: "The usual price across imported scans, with newer scans carrying more weight. Slow, for when you can wait.",
    price: (item) => item.usual ?? item.median,
  },
];

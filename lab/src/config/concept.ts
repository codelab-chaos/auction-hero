// Settings for the in-game concept window, as data.
// The size of Blizzard's auction house window, so the concept is judged at
// the room it will really have in game.
export const WINDOW = { width: 900, height: 600 };

export interface ConceptTab {
  id: string;
  label: string;
}

export const CONCEPT_TABS: ConceptTab[] = [
  { id: "buy", label: "Buy" },
  { id: "sell", label: "Sell" },
  { id: "resell", label: "Resell" },
  { id: "history", label: "History" },
];

// Quick toggles above the Buy list.
export interface BuyToggle {
  id: "usableOnly" | "affordableOnly" | "dealsOnly";
  label: string;
}

export const BUY_TOGGLES: BuyToggle[] = [
  { id: "usableOnly", label: "I can use" },
  { id: "affordableOnly", label: "I can afford" },
  { id: "dealsOnly", label: "Deals" },
];

export const BUY_LIST_LIMIT = 80;

// The game offers three durations by index. What each means in hours is not
// confirmed on Forever yet, so they are named by position.
export const DURATIONS = [
  { index: 1, label: "Short", note: "The shortest listing. The lowest deposit." },
  { index: 2, label: "Medium", note: "The middle listing length." },
  { index: 3, label: "Long", note: "The longest listing, and the usual choice: the most time to sell." },
];

// Most auctions are a buyout left up as long as possible, so start there.
export const DEFAULT_DURATION = 3;

// The lab has no view of your real bags yet, so the Sell tab starts with a
// pretend bag: the most-listed items in the scan.
// One stackable item is spread over several slots, to cover the common case
// of holding a few stacks of the same thing.
export const PRETEND_BAG = {
  slots: 16,
  stackSize: 20,
  splitItemNamed: "Leather",
  splitStacks: [20, 20, 13],
};

// The price rule the Sell tab starts on (an id from config/price-rules.ts).
export const DEFAULT_PRICE_RULE = "skip-outliers";

// ========= Resell tab ======================================================
// How far under the usual price an auction must be to count as worth buying
// to sell again. The middle one is the starting choice.
export const RESELL_MARGINS = [15, 30, 50];

// A lead is only listed when its deal meter reads at least this many pips,
// so nothing is suggested on a price too few sellers back up.
export const RESELL_MIN_PIPS = 4;

export const RESELL_LIST_LIMIT = 80;

// ========= Sale types ======================================================
// The three ways the game lets an item be listed.
//   buyout  whether buyers can take it at once for a set price
//   bids    whether buyers can bid, with the highest bidder winning when the
//           time runs out
export const SALE_TYPES = [
  { id: "buyout", label: "Buy now", buyout: true, bids: false, note: "A set price. The first buyer to pay it gets the item at once. What nearly everyone uses." },
  { id: "both", label: "Buy now + bids", buyout: true, bids: true, note: "A buy now price, and a lower starting bid. If nobody pays the buy now price, the highest bidder wins when the time runs out." },
  { id: "bids", label: "Bids only", buyout: false, bids: true, note: "No buy now price. The highest bidder wins when the time runs out, so it never sells at once." },
] as const;

export type SaleTypeId = (typeof SALE_TYPES)[number]["id"];

// When bids are on, the starting bid begins at this share of the price.
export const STARTING_BID_SHARE = 0.8;

// The most units of an item that may be for sale, in all, for it to be shown
// as a resell lead. Reselling means buying the market out and relisting it.
export const RESELL_MAX_ITEMS = 10;

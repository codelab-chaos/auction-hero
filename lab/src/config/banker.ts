// The banker's rules, as data: how the lab reads demand off a run of scans,
// and what makes an item worth flipping or cornering. Tune here; the models
// in model/flow.ts, model/flips.ts and model/corner.ts only apply them.

// ========= Flow: what moved between scans ===================================
export const FLOW_RULE = {
  // Below this many hours of scans, rates per day are too thin to rank by.
  minHours: 6,
  // An item needs this many units seen selling before its sold price counts.
  minSoldForPrice: 2,
};

// ========= Flips: buy under the going rate, relist at it ====================
export interface FlipParams {
  marginPercent: number; // buy auctions at least this far under the relist price
  minProfit: number; // copper
  budget: number; // copper you have, 0 for no limit
  maxDays: number; // longest you will wait for the load to sell
  minSold: number; // units that must have been seen selling
}

export const DEFAULT_FLIP_PARAMS: FlipParams = {
  marginPercent: 25,
  minProfit: 2500,
  budget: 0,
  maxDays: 2,
  minSold: 2,
};

// ========= Corner: own the cheap supply, relist under the next price ========
export interface CornerParams {
  budget: number; // copper you have, 0 for no limit
  minProfit: number; // copper
  minSoldPerDay: number; // how sought after the item must be
  minMarkupPercent: number; // the relist price over what each unit cost you
  maxDays: number; // longest you will hold the stock
  // Units newly listed per unit sold. Above this, other sellers refill the
  // market under you faster than it drains, and the corner does not hold.
  maxRestock: number;
  // The most buyers are taken to pay, as a percent of the usual price. A wall
  // above this is someone's wishful listing, not a price to sit under, and a
  // whole market bought out is relisted at this.
  maxOverUsualPercent: number;
}

export const DEFAULT_CORNER_PARAMS: CornerParams = {
  budget: 0,
  minProfit: 5000,
  minSoldPerDay: 2,
  minMarkupPercent: 40,
  maxDays: 3,
  maxRestock: 1.5,
  maxOverUsualPercent: 150,
};

// ========= Market type: supply beside turnover ==============================
// Supply alone cannot say whether an item is wanted: plenty for sale can be a
// staple or a glut, and few for sale can be hot or simply unwanted. Turnover
// is what tells them apart. See docs/ah-player-economy.md.
export const MARKET_RULE = {
  // Few for sale: at most this much, counted the way it fills bags (stacks of
  // a stackable item, pieces of anything else).
  scarceSize: 5,
  // Sells fast: at least this share of what is for sale leaves by sale each day.
  fastTurnover: 0.5,
  // Units that must have been seen selling before "fast" can be claimed.
  minSold: 2,
};

export interface MarketType {
  id: string;
  label: string;
  note: string; // what it means for a trader
}

export const MARKET_TYPES: MarketType[] = [
  { id: "hot", label: "Hot", note: "Few for sale and they keep selling. Demand outruns supply." },
  { id: "staple", label: "Staple", note: "Plenty for sale and it keeps selling. Reliable prices, thin margins." },
  { id: "glut", label: "Glut", note: "Plenty for sale and it barely moves. A low price here is not a deal." },
  { id: "quiet", label: "Quiet", note: "Few for sale and little sign of buyers. Rare, or simply unwanted: a scan cannot tell which." },
  { id: "unknown", label: "Unknown", note: "Not enough scans, or rows without names, to say how it moves." },
];

// ========= News =============================================================
export const NEWS_RULE = {
  // Item names shorter than this are too likely to be ordinary words.
  minNameLength: 6,
  // An article is "recent" for this many days: its items get a News mark.
  recentDays: 7,
};

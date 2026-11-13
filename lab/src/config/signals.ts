// Signals: the meters shown beside prices, as data.
//
//   Price confidence   how far to trust the price we suggest for an item
//
// It is read off what a scan can see. It does not know what actually sold.

export interface SignalLevel {
  id: string;
  label: string;
  min: number; // lowest score (0 to 100) that earns this level
  pips: number; // filled pips on the meter
  tone: "bad" | "warn" | "ok" | "good";
}

// ========= Price confidence ================================================
export const CONFIDENCE_LEVELS: SignalLevel[] = [
  { id: "none", label: "No price", min: 0, pips: 0, tone: "bad" },
  { id: "low", label: "Low", min: 1, pips: 1, tone: "bad" },
  { id: "fair", label: "Fair", min: 30, pips: 2, tone: "warn" },
  { id: "good", label: "Good", min: 55, pips: 3, tone: "ok" },
  { id: "high", label: "High", min: 80, pips: 4, tone: "good" },
];
export const CONFIDENCE_PIPS = 4;

export const CONFIDENCE_RULE = {
  // More auctions to compare with means a steadier price. Score by auction count.
  depth: [
    { auctions: 1, score: 15 },
    { auctions: 2, score: 30 },
    { auctions: 5, score: 60 },
    { auctions: 15, score: 85 },
    { auctions: 40, score: 100 },
  ],
  // Units priced within this share of the median count as "agreeing" on the price.
  agreementBand: 0.25,
  // How much of the depth score survives when nothing agrees. Full agreement keeps all of it.
  agreementFloor: 0.5,
  // Below this share of agreeing units, say so.
  agreementWarning: 0.5,
};

// ========= Deal ============================================================
// How good a buy is: how far the price you would pay sits under the item's
// usual price across scans. It is judged on the whole order, so buying deeper
// into the ladder makes the deal worse.
//
// Five steps, one pip each:
//   1 Overpriced       more than DEAL_RULE.fairBand percent over the usual price
//   2 Fair             within that band either way, or only a little under
//   3 Great to buy     at least DEAL_RULE.greatFrom percent under
//   4 Confident deal   great to buy, and the usual price itself is well
//                      founded: price confidence reaches DEAL_RULE.confidentNeeds
//   5 Snag to resell   a solid, known deal with room to relist at the usual
//                      price and still profit after the auction house's cut:
//                      at least DEAL_RULE.resellFrom percent under, with price
//                      confidence at DEAL_RULE.resellNeeds
export const DEAL_LEVELS = {
  over: { id: "over", label: "Overpriced", min: 0, pips: 1, tone: "bad" },
  fair: { id: "fair", label: "Fair", min: 0, pips: 2, tone: "warn" },
  great: { id: "great", label: "Great to buy", min: 0, pips: 3, tone: "good" },
  confident: { id: "confident", label: "Confident deal", min: 0, pips: 4, tone: "good" },
  resell: { id: "resell", label: "Snag to resell", min: 0, pips: 5, tone: "good" },
} satisfies Record<string, SignalLevel>;
export const DEAL_PIPS = 5;

export const DEAL_RULE = {
  fairBand: 10, // percent over the usual price that still counts as fair
  greatFrom: 15, // percent under the usual price that makes it great to buy
  confidentNeeds: "good", // an id from CONFIDENCE_LEVELS
  resellFrom: 30, // percent under the usual price that leaves room to resell
  resellNeeds: "high", // an id from CONFIDENCE_LEVELS
  // Below this price confidence there is no deal reading at all: a "usual
  // price" built from one or two auctions means nothing.
  needsConfidence: "fair",
};

// What a deal reports when there is too little to judge by. The Buy panel
// shows no meter in that case, only a short note.
export const DEAL_UNKNOWN: SignalLevel = { id: "unknown", label: "Can't tell", min: 0, pips: 0, tone: "warn" };

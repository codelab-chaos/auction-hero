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
// How good a buy is: how far the price you would pay sits under the price you
// would otherwise pay, the baseline (today's floor, held down to the item's
// usual lowest price once past scans can say what that is). It is judged on
// the whole order, so buying deeper into the ladder makes the deal worse.
//
// Five steps, one pip each:
//   1 Overpriced       more than DEAL_RULE.fairBand percent over the baseline
//   2 Fair             within that band either way, or only a little under
//   3 Great to buy     at least DEAL_RULE.greatFrom percent under, on today's
//                      listings alone
//   4 Confident deal   great to buy, and the baseline is well founded: past
//                      scans back it, or price confidence reaches
//                      DEAL_RULE.confidentNeeds
//   5 Snag to resell   a confident deal at least DEAL_RULE.resellFrom percent
//                      under, which leaves room to relist and still profit
export const DEAL_LEVELS = {
  over: { id: "over", label: "Overpriced", min: 0, pips: 1, tone: "bad" },
  fair: { id: "fair", label: "Fair", min: 0, pips: 2, tone: "warn" },
  great: { id: "great", label: "Great to buy", min: 0, pips: 3, tone: "good" },
  confident: { id: "confident", label: "Confident deal", min: 0, pips: 4, tone: "good" },
  resell: { id: "resell", label: "Snag to resell", min: 0, pips: 5, tone: "good" },
} satisfies Record<string, SignalLevel>;
export const DEAL_PIPS = 5;

export const DEAL_RULE = {
  fairBand: 10, // percent over the baseline that still counts as fair
  greatFrom: 15, // percent under the baseline that makes it great to buy
  confidentNeeds: "good", // an id from CONFIDENCE_LEVELS, for when past scans cannot back the baseline
  resellFrom: 30, // percent under that leaves room to resell
};

// What a deal reports when there is too little to judge by. The Buy panel
// shows no meter in that case, only a short note.
export const DEAL_UNKNOWN: SignalLevel = { id: "unknown", label: "Can't tell", min: 0, pips: 0, tone: "warn" };

// ========= Deal confidence ==================================================
// How far to trust that a low price is a real deal. It is separate from how
// big the discount is: a 90% discount against prices nobody pays is worth
// nothing. Scored 0 to 100 from three kinds of evidence, each a ladder of
// steps (the largest step reached counts) worth its weight when full:
//   days     different days the scans saw the item on. One scan is a snapshot
//   sold     units seen selling between scans. Without sales, asking prices
//            are only hopes
//   prices   different prices it is listed at today. Identical auctions are
//            one seller's opinion
// And one check that holds the score down:
//   vendor   when the cheap price sits near what a vendor pays while the rest
//            ask many times more, the rest are the odd ones out
// See docs/ah-player-economy.md.
export const DEAL_CONFIDENCE_RULE = {
  days: { weight: 35, steps: [{ from: 1, share: 0.2 }, { from: 2, share: 0.6 }, { from: 3, share: 0.8 }, { from: 5, share: 1 }] },
  sold: { weight: 40, steps: [{ from: 1, share: 0.4 }, { from: 3, share: 0.8 }, { from: 10, share: 1 }] },
  prices: { weight: 25, steps: [{ from: 1, share: 0.1 }, { from: 2, share: 0.4 }, { from: 3, share: 0.7 }, { from: 5, share: 1 }] },
  // The cheap price is "near vendor" at up to this multiple of the vendor
  // price, and the rest "ask many times more" from this multiple of it.
  vendorNear: 2,
  vendorFar: 5,
  vendorCap: 25, // the most the score can be when that check trips
  // The least confidence for a deal to be shown: to buy for yourself, and the
  // stricter bar to buy for resale.
  showFrom: 40,
  resellFrom: 65,
};

export const DEAL_CONFIDENCE_LEVELS: SignalLevel[] = [
  { id: "none", label: "No basis", min: 0, pips: 0, tone: "bad" },
  { id: "low", label: "Low", min: 1, pips: 1, tone: "bad" },
  { id: "fair", label: "Fair", min: 40, pips: 2, tone: "warn" },
  { id: "good", label: "Good", min: 65, pips: 3, tone: "ok" },
  { id: "high", label: "High", min: 85, pips: 4, tone: "good" },
];
export const DEAL_CONFIDENCE_PIPS = 4;

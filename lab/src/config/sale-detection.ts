// An explicit fallback for old imports, not verified Forever boundaries.
// Replicate returns bands 1–4; GetTimeLeftBandInfo takes enum values 0–3.
export const ASSUMED_EXPIRY_BANDS: Record<string, { min: number; max: number | null }> = {
  1: { min: 0, max: 30 * 60 },
  2: { min: 30 * 60, max: 2 * 3600 },
  3: { min: 2 * 3600, max: 12 * 3600 },
  4: { min: 12 * 3600, max: null },
};

// Evidence points, not calibrated probabilities. Neither score proves a sale
// or expiry; cancellation remains possible. Keep tuning separate from UI.
export const SALE_DETECTION = {
  saleBase: 10,
  beforeExpiryPoints: 55,
  priceOrderPoints: 30,
  expiryPossiblePoints: 55,
  expiryDeadlinePoints: 40,
  priceOrderExpiryDiscount: 0.3,
  assumedCap: 65,
  unresolvedCap: 25,
  priceOnlyCap: 35,
  maxScore: 95,
  // Long gaps allow more hidden arrivals, departures and cancellations.
  fullStrengthGapSeconds: 2 * 3600,
};

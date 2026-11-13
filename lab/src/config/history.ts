// Same smoothing used by the addon's price memory: each newer scan carries
// 30% of the usual price, previous history 70%. Each scan is folded once.
export const HISTORY_SMOOTHING = 0.3;

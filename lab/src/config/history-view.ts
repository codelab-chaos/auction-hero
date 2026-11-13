// Settings for the concept's History tab, as data.
//
// The charts use only what the game can draw: straight lines, rectangles and
// text. No curves, gradients or filled areas.

// How far back a chart can look. The middle one is the starting choice.
export const HISTORY_RANGES = [
  { days: 7, label: "7d" },
  { days: 14, label: "14d" },
  { days: 30, label: "30d" },
];
export const DEFAULT_HISTORY_RANGE = 30;

// The two price lines. The colors were checked as a pair on the window's dark
// panel for color-blind separation and contrast (dataviz validate_palette).
export const PRICE_SERIES = [
  { id: "median", label: "Usual price", color: "#bf8a2a" },
  { id: "low", label: "Lowest price", color: "#4a8fd6" },
] as const;

// One muted color for the units bars: they show an amount, not an identity.
export const UNITS_COLOR = "#8f7f63";

export const HISTORY_LIST_LIMIT = 200;

// With fewer real days than this, the lab fills the chart with sample points
// so the design can be judged. The addon never does this.
export const SAMPLE_BELOW_DAYS = 5;
export const SAMPLE_DAYS = 30;

export const CHART = {
  width: 572,
  priceHeight: 190,
  unitsHeight: 84,
  left: 62, // room for the price labels
  right: 14,
  top: 10,
  bottom: 20, // room for the dates
  gridLines: 4,
};

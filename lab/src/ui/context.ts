// What every screen is handed: the market, the shared settings, and ways to
// move around the lab. Screens never reach for each other directly.
import type { Flows } from "../model/flow";
import type { Market } from "../model/market";
import type { NewsIndex } from "../model/news";

export interface Settings {
  gold: number | null; // the player's budget, in gold
}

export interface LabContext {
  market: Market;
  markets: Market[]; // unique fresh full scans available by the viewing date
  asOf: number;
  useAssumedExpiryBands: boolean;
  settings: Settings;
  budget: () => number; // the budget in copper, 0 when not set
  flows: () => Flows; // what moved between the scans available by the viewing date
  news: () => NewsIndex; // fetched articles, matched to the items for sale
  openItem: (key: string) => void; // show an item in the detail panel
}

export interface Screen {
  element: HTMLElement;
  update: () => void; // redraw results after the market or settings changed
}

// Small persistent state, per browser. The lab works without it.
export function remember<T>(key: string, fallback: T): T {
  try {
    const text = localStorage.getItem(`nitro-lab:${key}`);
    return text === null ? fallback : { ...fallback, ...(JSON.parse(text) as T) };
  } catch {
    return fallback;
  }
}

export function store(key: string, value: unknown): void {
  try {
    localStorage.setItem(`nitro-lab:${key}`, JSON.stringify(value));
  } catch {
    // Storage is a convenience only.
  }
}

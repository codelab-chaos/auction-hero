// What every screen is handed: the market, the shared settings, and ways to
// move around the lab. Screens never reach for each other directly.
import type { Market } from "../model/market";

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
  openItem: (key: string) => void; // show an item in the detail panel
  postItem: (key: string) => void; // jump to the Post screen with an item chosen
}

export interface Screen {
  element: HTMLElement;
  update: () => void; // redraw results after the market or settings changed
  select?: (key: string) => void; // for screens that work on one chosen item
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

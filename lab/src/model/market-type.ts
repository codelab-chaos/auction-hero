// Market type: what kind of market an item is, from how much is for sale and
// how fast it leaves by sale. The rules are MARKET_RULE in config/banker.ts.
//
//                 sells fast     sells slowly
//   plenty        staple         glut
//   few           hot            quiet
//
// Turnover is the lab's estimate of sales (model/flow.ts), never a count of
// confirmed sales, so a type is a reading, not a fact.
import { FLOW_RULE, MARKET_RULE } from "../config/banker.ts";
import { perDay, type Flows } from "./flow.ts";
import type { MarketItem } from "./market";
import { marketSize } from "./resell.ts";

export interface MarketReading {
  type: string; // an id from MARKET_TYPES
  size: number; // how much is for sale, as stacks or pieces
  scarce: boolean;
  soldPerDay: number | null; // null when turnover cannot be read
  turnover: number | null; // share of the units for sale that sells per day
}

export function marketType(item: MarketItem, flows: Flows): MarketReading {
  const size = marketSize(item);
  const scarce = size <= MARKET_RULE.scarceSize;
  const flow = flows.byKey.get(item.key);
  // No flow recorded for an item that was scanned means nothing left: zero sales.
  const readable = flows.hours >= FLOW_RULE.minHours && !flow?.shaky && item.units > 0;
  if (!readable) return { type: "unknown", size, scarce, soldPerDay: null, turnover: null };

  const sold = flow?.sold ?? 0;
  const soldPerDay = perDay(sold, flows);
  const turnover = soldPerDay / item.units;
  const fast = sold >= MARKET_RULE.minSold && turnover >= MARKET_RULE.fastTurnover;
  const type = scarce ? (fast ? "hot" : "quiet") : fast ? "staple" : "glut";
  return { type, size, scarce, soldPerDay, turnover };
}

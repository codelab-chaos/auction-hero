// Table cells and notes shared by the banker's screens (Flips and Corner).
import { FLOW_RULE } from "../config/banker";
import type { Flows, ItemFlow } from "../model/flow";
import type { MarketItem } from "../model/market";
import { recentNews } from "../model/news";
import type { ResellLine } from "../model/resell";
import type { LabContext } from "./context";
import { h, icon, itemName, money, number } from "./dom";

// An item's icon and name, with a mark when recent news names it.
export function leadName(item: MarketItem, ctx: LabContext): HTMLElement {
  const articles = recentNews(ctx.news(), item.key, ctx.asOf);
  return h(
    "span",
    { class: "item-cell" },
    icon(item.icon),
    itemName(item.name, item.quality, ""),
    articles.length > 0 && h("span", { class: "badge badge-news", title: articles.map((article) => article.title).join("\n") }, "News"),
  );
}

function coins(copper: number): string {
  const value = Math.floor(copper);
  const gold = Math.floor(value / 10000);
  const silver = Math.floor(value / 100) % 100;
  return [gold ? `${gold.toLocaleString("en-US")}g` : "", gold || silver ? `${silver}s` : "", `${value % 100}c`].filter(Boolean).join(" ");
}

// What to buy, one line per price, for a tooltip.
export function planTip(lines: ResellLine[]): string {
  return lines
    .map((line) => `${line.auctions} x ${line.tier.stack > 1 ? `stack of ${line.tier.stack}` : "1"} at ${coins(line.tier.buyout)} each`)
    .join("\n");
}

// A rate or a span of days, to one decimal while it is small.
export function decimal(value: number): string {
  return value >= 100 ? number(value) : value.toFixed(1);
}

// How much scan history the rates stand on, and a warning while it is thin.
export function flowNote(flows: Flows): string {
  const span = `${decimal(flows.hours)} hours of scans (${flows.intervals} ${flows.intervals === 1 ? "gap" : "gaps"} compared)`;
  if (flows.intervals === 0) return "Sales pace needs at least two scans. Scan again later and these lists will fill in.";
  if (flows.hours < FLOW_RULE.minHours) return `Sales pace is read off only ${span}. Treat it as a rough guide until more scans are in.`;
  return `Sales pace is read off ${span}.`;
}

// The price an item was last seen selling at, with when in a tooltip.
export function lastSold(flow: ItemFlow): HTMLElement {
  if (flow.lastSoldPrice === null || flow.lastSoldTime === null) return h("span", { class: "muted" }, "not seen");
  const cell = money(flow.lastSoldPrice);
  cell.title = `Seen in the scan of ${new Date(flow.lastSoldTime * 1000).toLocaleString()}`;
  return cell;
}

export const LAST_SOLD_TIP = "The unit price units most recently left at, before they could expire. Read off the newest pair of scans that saw a sale. An estimate, not a confirmed sale.";

// The detail panel: everything the scan knows about one item, and its full
// price ladder.
import { EQUIP_SLOTS, LEVEL_TYPE_BY_ID, QUALITY_BY_ID, TIME_BANDS } from "../config/catalog";
import { affordable, type MarketItem, type Tier } from "../model/market";
import type { LabContext } from "./context";
import { clear, h, icon, itemName, money, number } from "./dom";
import { priceConfidence } from "../model/signals";
import { meterBlock } from "./meter";
import { renderTable, type Column } from "./table";

const LADDER_LIMIT = 250;

interface LadderRow extends Tier {
  runningUnits: number;
  runningCost: number;
}

const LADDER_COLUMNS: Column<LadderRow>[] = [
  { id: "unit", label: "Per unit", align: "right", render: (row) => money(row.unit) },
  { id: "stack", label: "Stack", align: "right", render: (row) => number(row.stack) },
  { id: "copies", label: "Auctions", align: "right", render: (row) => number(row.copies) },
  { id: "running", label: "Units so far", align: "right", tip: "Units you would hold after buying down to this row.", render: (row) => number(row.runningUnits) },
  { id: "cost", label: "Cost so far", align: "right", render: (row) => money(row.runningCost) },
  { id: "time", label: "Time left at scan", render: (row) => TIME_BANDS[row.timeLeft] ?? String(row.timeLeft) },
];

function ladder(item: MarketItem): LadderRow[] {
  let runningUnits = 0;
  let runningCost = 0;
  return item.tiers.map((tier) => {
    runningUnits += tier.units;
    runningCost += tier.buyout * tier.copies;
    return { ...tier, runningUnits, runningCost };
  });
}

function fact(label: string, value: Node | string): HTMLElement {
  return h("div", { class: "fact" }, h("span", { class: "fact-label" }, label), h("span", null, value));
}

export function renderItemDetail(panel: HTMLElement, item: MarketItem | null, ctx: LabContext, close: () => void): void {
  clear(panel);
  panel.classList.toggle("open", item !== null);
  if (!item) return;

  const levelType = LEVEL_TYPE_BY_ID.get(item.levelType ?? "");
  const budget = ctx.budget();
  const facts = h(
    "div",
    { class: "facts" },
    fact("Item id", String(item.id)),
    fact("Quality", item.quality === null ? "unknown" : (QUALITY_BY_ID.get(item.quality)?.label ?? String(item.quality))),
    fact(levelType?.name ?? "Level", item.level === null ? "unknown" : String(item.level)),
    fact("Usable by my character", item.usable ? "yes" : "no"),
    fact("Auctions", number(item.listings)),
    fact("Units", number(item.units)),
    fact("Lowest", money(item.min)),
    fact("Median", money(item.median)),
    fact("Usual across scans", money(item.usual ?? item.median)),
    fact("Scans seen", number(item.scansSeen ?? 1)),
    fact("Units with uncertain expiry", number(item.expiryUncertainUnits ?? 0)),
    fact("Units with unknown expiry", number(item.expiryUnknownUnits ?? 0)),
    fact("Highest", money(item.max)),
    fact("All buyouts", money(item.value)),
  );
  if (item.type) facts.append(fact("Type", [item.type, item.subType].filter(Boolean).join(", ")));
  if (item.equipLoc) facts.append(fact("Slot", EQUIP_SLOTS[item.equipLoc] ?? item.equipLoc));
  if (item.bidOnly > 0) facts.append(fact("Bid-only auctions", number(item.bidOnly)));
  if (item.deal !== null) facts.append(fact("Lowest is under median by", `${item.deal}%`));
  if (budget > 0) {
    const can = affordable(item, budget);
    facts.append(fact("Your gold buys", h("span", null, `${number(can.units)} units for `, money(can.cost))));
  }

  panel.append(
    h(
      "div",
      { class: "detail-head" },
      icon(item.icon, 40),
      h("div", { class: "title" }, itemName(item.name, item.quality, `item ${item.id} (data never arrived)`)),
      h("button", { class: "button", onclick: () => ctx.postItem(item.key) }, "Post this"),
      h("button", { class: "button button-quiet", onclick: close }, "Close"),
    ),
    facts,
    h("div", { class: "muted small link" }, item.link ? `link: item:${item.link}` : ""),
    meterBlock("Price confidence", priceConfidence(item)),
    h("h3", null, "Price ladder"),
    renderTable({
      columns: LADDER_COLUMNS,
      rows: ladder(item),
      sort: null,
      onSort: () => {},
      limit: LADDER_LIMIT,
      empty: "No auctions with a buyout.",
    }),
  );
}

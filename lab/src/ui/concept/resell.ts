// Concept, Resell tab: a short list of things worth buying to sell again, and
// for the one you pick, the whole plan: what to buy, what to relist it at, and
// what is left after the auction house's cut.
import { ASSUMPTIONS } from "../../config/catalog";
import { RESELL_LIST_LIMIT, RESELL_MARGINS, RESELL_MIN_PIPS } from "../../config/concept";
import type { MarketItem } from "../../model/market";
import { findResellLeads, planResell, type ResellLead, type ResellParams } from "../../model/resell";
import { confidenceLine, deal, priceConfidence, type Deal } from "../../model/signals";
import type { LabContext } from "../context";
import { clear, h, icon, itemName, money, moneyInput, number } from "../dom";
import { meter, meterRow } from "../meter";
import { renderTable, type Column, type Sort } from "../table";


interface Row {
  lead: ResellLead;
  deal: Deal;
}

const COLUMNS: Column<Row>[] = [
  {
    id: "name",
    label: "Item",
    sort: (row) => row.lead.item.name,
    render: (row) => h("span", { class: "item-cell" }, icon(row.lead.item.icon, 18), itemName(row.lead.item.name, row.lead.item.quality, "")),
  },
  { id: "deal", label: "Deal", width: "66px", sort: (row) => row.deal.level.pips, render: (row) => meter(row.deal, { compact: true }) },
  { id: "units", label: "Buy", align: "right", width: "52px", sort: (row) => row.lead.buyUnits, render: (row) => number(row.lead.buyUnits) },
  { id: "cost", label: "Cost", align: "right", width: "96px", sort: (row) => row.lead.cost, render: (row) => money(row.lead.cost) },
  { id: "profit", label: "Profit", align: "right", width: "96px", sort: (row) => row.lead.profit, render: (row) => money(row.lead.profit) },
];

function confidenceRow(item: MarketItem): HTMLElement {
  const confidence = priceConfidence(item);
  return meterRow("Price confidence", confidence, confidenceLine(confidence));
}

export function createResellTab(ctx: LabContext): { element: HTMLElement; update: () => void } {
  let margin = RESELL_MARGINS[1] ?? 30;
  let minProfit = 5000; // copper
  let withinGold = false;
  let solidOnly = false;
  let sort: Sort | null = { column: "profit", descending: true };
  let selectedKey: string | null = null;
  let auctionsWanted: number | null = null; // null means every auction worth buying

  const toolbar = h("div", { class: "cw-toolbar" });
  const list = h("div", { class: "cw-list" });
  const plan = h("div", { class: "cw-order" });
  const element = h("div", { class: "cw-resell" }, h("div", { class: "cw-center" }, toolbar, list), plan);

  function params(): ResellParams {
    return {
      marginPercent: margin,
      budget: withinGold ? ctx.budget() : 0,
      minProfit,
      minListings: 5,
    };
  }

  function rows(): Row[] {
    return findResellLeads(ctx.market.items, params())
      .map((lead) => ({ lead, deal: deal(lead.item, lead.buyUnits, lead.cost) }))
      .filter((row) => row.deal.known && row.deal.level.pips >= (solidOnly ? 5 : RESELL_MIN_PIPS));
  }

  function toggle(label: string, on: boolean, tip: string, pick: () => void): HTMLElement {
    return h("button", { class: `cw-toggle ${on ? "active" : ""}`, title: tip, onclick: pick }, label);
  }

  // The settings bar: two labelled controls on the left (how big a discount,
  // how much profit), then the two on/off filters on the right.
  function renderToolbar(): void {
    clear(toolbar);

    const discount = h("div", { class: "cw-segments" });
    for (const option of RESELL_MARGINS) {
      discount.append(
        h(
          "button",
          {
            class: `cw-segment ${option === margin ? "active" : ""}`,
            title: `Only buy auctions at least ${option}% under the usual price.`,
            onclick: () => {
              margin = option;
              render();
            },
          },
          `${option}%`,
        ),
      );
    }

    const profit = moneyInput(
      minProfit,
      (copper) => {
        minProfit = copper;
        renderList();
      },
      { compact: true },
    );
    profit.title = "Hide leads that would make less than this.";

    toolbar.append(
      h("label", { class: "cw-group" }, h("span", { class: "cw-group-label" }, "Discount"), discount),
      h("label", { class: "cw-group" }, h("span", { class: "cw-group-label" }, "Min profit"), profit),
      h(
        "div",
        { class: "cw-group cw-group-end" },
        toggle("I can afford", withinGold, "Only what your gold covers. Set your gold in the lab's header.", () => {
          withinGold = !withinGold;
          render();
        }),
        toggle("Top deals", solidOnly, "Only five-pip deals: a big discount on a price many sellers agree on.", () => {
          solidOnly = !solidOnly;
          render();
        }),
      ),
    );
  }

  function renderList(): void {
    const data = rows();
    clear(list);
    list.append(
      renderTable({
        columns: COLUMNS,
        rows: data,
        sort,
        onSort: (next) => {
          sort = next;
          renderList();
        },
        onRowClick: (row) => {
          selectedKey = row.lead.item.key;
          auctionsWanted = null;
          renderList();
        },
        rowClass: (row) => (row.lead.item.key === selectedKey ? "selected" : ""),
        limit: RESELL_LIST_LIMIT,
        empty: "Nothing worth flipping with these settings.",
      }),
    );
    const selected = data.find((row) => row.lead.item.key === selectedKey);
    renderPlan(selected ?? null);
  }

  function step(numberText: string, title: string, ...body: (HTMLElement | string)[]): HTMLElement {
    return h("div", { class: "cw-step-block" }, h("div", { class: "cw-step-title" }, h("span", { class: "cw-step-number" }, numberText), title), ...body);
  }

  function setAuctions(value: number, available: number, row: Row): void {
    const wanted = Math.max(1, Math.min(available, Math.floor(value)));
    auctionsWanted = wanted >= available ? null : wanted;
    renderPlan(row);
  }

  function renderPlan(row: Row | null): void {
    clear(plan);
    if (!row) {
      plan.append(h("div", { class: "cw-hint" }, "Pick an item to see the plan: what to buy, what to relist it at, and what you keep."));
      return;
    }
    const item = row.lead.item;
    // The list plans "everything worth buying". Here the player picks how many
    // of those auctions to take, and the rest of the plan follows from that.
    const lead = planResell(item, params(), auctionsWanted ?? Infinity) ?? row.lead;
    const available = row.lead.buyAuctions;
    const next = lead.lines[0];

    const lines = h("div", { class: "cw-lines" });
    for (const line of lead.lines.slice(0, 5)) {
      lines.append(
        h(
          "div",
          { class: "cw-line" },
          h("span", null, `${number(line.auctions)} x stack of ${number(line.tier.stack)}`),
          h("span", null, money(line.tier.unit), " each"),
        ),
      );
    }
    if (lead.lines.length > 5) lines.append(h("div", { class: "muted small" }, `and ${lead.lines.length - 5} more price points`));

    plan.append(
      h("div", { class: "cw-order-head" }, icon(item.icon, 32), h("div", null, itemName(item.name, item.quality, ""), h("div", { class: "muted small" }, `${number(item.units)} for sale in ${number(item.listings)} auctions`))),
      step(
        "1",
        "Buy",
        h(
          "div",
          { class: "cw-quantity" },
          h("span", { class: "muted" }, "Auctions"),
          h("button", { class: "cw-step", onclick: () => setAuctions(lead.buyAuctions - 1, available, row) }, "-"),
          h("input", {
            type: "number",
            class: "input cw-quantity-input",
            value: String(lead.buyAuctions),
            onchange: (event: Event) => setAuctions(Number((event.target as HTMLInputElement).value) || 1, available, row),
          }),
          h("button", { class: "cw-step", onclick: () => setAuctions(lead.buyAuctions + 1, available, row) }, "+"),
          h("button", { class: "cw-step cw-step-wide", onclick: () => setAuctions(available, available, row) }, "All"),
          h("span", { class: "muted small" }, `of ${number(available)}`),
        ),
        // The game sells one auction per press, so the button buys the next one
        // on the list and says exactly what that is.
        h(
          "button",
          { class: "cw-action cw-action-detail" },
          h("span", null, lead.buyAuctions > 1 ? `Buy auction 1 of ${number(lead.buyAuctions)}` : "Buy this auction"),
          next ? h("span", { class: "cw-action-sub" }, `stack of ${number(next.tier.stack)} at `, money(next.tier.unit), " each") : "",
        ),
        confidenceRow(item),
        h("div", { class: "cw-row" }, h("span", { class: "muted" }, `${number(lead.buyUnits)} units, average each`), money(lead.averageUnit)),
        h("div", { class: "cw-row" }, h("span", { class: "muted" }, "Cost"), money(lead.cost)),
      ),
      step(
        "2",
        "Relist",
        h("div", { class: "cw-row" }, h("span", { class: "muted" }, "At the usual price, each"), money(lead.target)),
        h("div", { class: "cw-row" }, h("span", { class: "muted" }, `If all sell, less the ${ASSUMPTIONS.auctionCut * 100}% cut`), money(lead.revenue)),
      ),
      step(
        "3",
        "Keep",
        h("div", { class: "cw-total" }, h("span", null, "Profit"), money(lead.profit)),
        h("div", { class: "cw-row" }, h("span", { class: "muted" }, "Return on what you spend"), `${number(lead.roi)}%`),
      ),
      h(
        "div",
        { class: lead.competition > lead.buyUnits * 3 ? "cw-note bad" : "cw-note" },
        lead.competition === 0
          ? "Nothing else is listed at or under the usual price once you buy."
          : `${number(lead.competition)} units stay listed at or under the usual price.`,
      ),
      // The auction-by-auction detail is the least interesting part, so it goes last.
      h("div", { class: "cw-step-block" }, h("div", { class: "cw-label" }, "The auctions"), lines),
    );
  }

  function render(): void {
    renderToolbar();
    renderList();
  }

  render();
  return { element, update: render };
}

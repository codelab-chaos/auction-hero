// Resell: items where buying the cheap end and relisting at the median pays.
import { ASSUMPTIONS } from "../../config/catalog";
import { DEFAULT_RESELL_PARAMS, findResellLeads, type ResellLead, type ResellParams } from "../../model/resell";
import { remember, store, type LabContext, type Screen } from "../context";
import { checkbox, clear, field, h, icon, itemName, money, moneyInput, number, numberInput } from "../dom";
import { renderTable, type Column, type Sort } from "../table";

const ROW_LIMIT = 300;

const COLUMNS: Column<ResellLead>[] = [
  {
    id: "name",
    label: "Item",
    sort: (lead) => lead.item.name,
    render: (lead) => h("span", { class: "item-cell" }, icon(lead.item.icon), itemName(lead.item.name, lead.item.quality, "")),
  },
  { id: "buy", label: "Buy units", align: "right", width: "90px", sort: (lead) => lead.buyUnits, render: (lead) => number(lead.buyUnits) },
  { id: "cost", label: "Cost", align: "right", width: "120px", sort: (lead) => lead.cost, render: (lead) => money(lead.cost) },
  { id: "target", label: "Relist at", align: "right", width: "120px", tip: "The median unit price.", sort: (lead) => lead.target, render: (lead) => money(lead.target) },
  { id: "profit", label: "Profit", align: "right", width: "120px", sort: (lead) => lead.profit, render: (lead) => money(lead.profit) },
  { id: "roi", label: "Return", align: "right", width: "80px", sort: (lead) => lead.roi, render: (lead) => `${number(lead.roi)}%` },
  {
    id: "competition",
    label: "Units in your way",
    align: "right",
    width: "130px",
    tip: "Units still listed at or under the relist price after you buy. More means a slower sale.",
    sort: (lead) => lead.competition,
    render: (lead) => number(lead.competition),
  },
];

export function createResellScreen(ctx: LabContext): Screen {
  const params: ResellParams = remember("resell-params", DEFAULT_RESELL_PARAMS);
  let useBudget = remember("resell-budget", { on: false }).on;
  let sort: Sort | null = { column: "profit", descending: true };

  const controls = h("div", { class: "controls" });
  const results = h("div");
  const element = h("section", { class: "screen" }, controls, results);

  function update(): void {
    store("resell-params", params);
    store("resell-budget", { on: useBudget });
    const leads = findResellLeads(ctx.market.items, { ...params, budget: useBudget ? ctx.budget() : 0 });
    clear(results);
    results.append(
      renderTable({
        columns: COLUMNS,
        rows: leads,
        sort,
        onSort: (next) => {
          sort = next;
          update();
        },
        onRowClick: (lead) => ctx.openItem(lead.item.key),
        limit: ROW_LIMIT,
        empty: "No leads with these settings.",
      }),
    );
  }

  controls.append(
    field(
      "Buy at least this % under median",
      numberInput(params.marginPercent, (value) => {
        params.marginPercent = Math.min(95, Math.max(1, value ?? DEFAULT_RESELL_PARAMS.marginPercent));
        update();
      }),
    ),
    field(
      "Minimum profit",
      moneyInput(params.minProfit, (copper) => {
        params.minProfit = copper;
        update();
      }),
    ),
    field(
      "Minimum listings",
      numberInput(params.minListings, (value) => {
        params.minListings = Math.max(1, value ?? 1);
        update();
      }),
    ),
    h(
      "div",
      { class: "checks" },
      checkbox("Limit each buy to my gold", useBudget, (value) => {
        useBudget = value;
        update();
      }),
    ),
    h(
      "div",
      { class: "hint" },
      `Leads, not promises. This is one snapshot, a median can be held up by auctions that never sell, and profit assumes a ${ASSUMPTIONS.auctionCut * 100}% cut with no deposit.`,
    ),
  );

  update();
  return { element, update };
}

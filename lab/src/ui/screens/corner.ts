// Corner: sought-after items whose cheap supply is small enough to buy out
// and relist just under the next price up.
import { DEFAULT_CORNER_PARAMS, type CornerParams } from "../../config/banker";
import { ASSUMPTIONS } from "../../config/catalog";
import { findCorners, type CornerLead } from "../../model/corner";
import { remember, store, type LabContext, type Screen } from "../context";
import { checkbox, clear, field, h, money, moneyInput, number, numberInput } from "../dom";
import { decimal, flowNote, LAST_SOLD_TIP, lastSold, leadName, planTip } from "../lead-cells";
import { renderTable, type Column, type Sort } from "../table";

const ROW_LIMIT = 300;

function columns(ctx: LabContext): Column<CornerLead>[] {
  return [
    { id: "name", label: "Item", sort: (lead) => lead.item.name, render: (lead) => leadName(lead.item, ctx) },
    {
      id: "buy", label: "Buy out", align: "right", width: "90px", tip: "Units to buy: everything under the relist price. Hover a number for the list.",
      sort: (lead) => lead.buyUnits,
      render: (lead) => h("span", { title: planTip(lead.lines) }, `${number(lead.buyUnits)} units`),
    },
    {
      id: "share", label: "Of market", align: "right", width: "80px", tip: "The share of all units for sale that you would hold.",
      sort: (lead) => lead.share, render: (lead) => `${number(lead.share)}%`,
    },
    { id: "cost", label: "Cost", align: "right", width: "120px", sort: (lead) => lead.cost, render: (lead) => money(lead.cost) },
    { id: "average", label: "You pay / unit", align: "right", width: "120px", sort: (lead) => lead.averageUnit, render: (lead) => money(lead.averageUnit) },
    { id: "relist", label: "Relist at", align: "right", width: "120px", sort: (lead) => lead.relist, render: (lead) => money(lead.relist) },
    {
      id: "over", label: "Of usual", align: "right", width: "80px",
      tip: "The relist price against the usual price. Capped by the setting above: past it, buyers are taken to walk away.",
      sort: (lead) => lead.overUsual, render: (lead) => `${number(lead.overUsual)}%`,
    },
    {
      id: "wall", label: "Next price up", align: "right", width: "120px",
      tip: "The cheapest listing you leave standing. Empty when you buy the whole market and the price is yours to set.",
      sort: (lead) => lead.wall, render: (lead) => (lead.wall === null ? h("span", { class: "muted" }, "none left") : money(lead.wall)),
    },
    { id: "lastSold", label: "Last sold", align: "right", width: "120px", tip: LAST_SOLD_TIP, sort: (lead) => lead.flow.lastSoldPrice, render: (lead) => lastSold(lead.flow) },
    { id: "profit", label: "Profit", align: "right", width: "120px", sort: (lead) => lead.profit, render: (lead) => money(lead.profit) },
    {
      id: "pace", label: "Sells / day", align: "right", width: "90px",
      tip: "Units a day that left before they could expire, at the old prices. Fewer will sell at a higher price.",
      sort: (lead) => lead.soldPerDay, render: (lead) => decimal(lead.soldPerDay),
    },
    {
      id: "restock", label: "Restock", align: "right", width: "80px",
      tip: "Units newly listed for each unit sold. Under 1, the market drains and your corner holds. Over 1, other sellers refill it under you.",
      sort: (lead) => lead.restock, render: (lead) => `${lead.restock.toFixed(2)}x`,
    },
    { id: "days", label: "Days to sell", align: "right", width: "100px", sort: (lead) => lead.daysToSell, render: (lead) => decimal(lead.daysToSell) },
    {
      id: "perDay", label: "Profit / day", align: "right", width: "120px",
      tip: "Profit spread over the days it takes to sell. A load that sells within a day counts as one day.",
      sort: (lead) => lead.profitPerDay, render: (lead) => money(lead.profitPerDay),
    },
  ];
}

export function createCornerScreen(ctx: LabContext): Screen {
  const params: CornerParams = remember("corner-params", DEFAULT_CORNER_PARAMS);
  let useBudget = remember("corner-budget", { on: true }).on;
  let sort: Sort | null = { column: "perDay", descending: true };
  const table = columns(ctx);

  const controls = h("div", { class: "controls" });
  const results = h("div");
  const element = h("section", { class: "screen" }, controls, results);

  function update(): void {
    store("corner-params", params);
    store("corner-budget", { on: useBudget });
    const leads = findCorners(ctx.market.items, ctx.flows(), { ...params, budget: useBudget ? ctx.budget() : 0 });
    clear(results);
    results.append(
      renderTable({
        columns: table, rows: leads, sort,
        onSort: (next) => { sort = next; update(); },
        onRowClick: (lead) => ctx.openItem(lead.item.key),
        limit: ROW_LIMIT,
        empty: "No markets to corner with these settings.",
      }),
    );
  }

  controls.append(
    field("Sells per day, at least", numberInput(params.minSoldPerDay, (value) => {
      params.minSoldPerDay = Math.max(0, value ?? DEFAULT_CORNER_PARAMS.minSoldPerDay);
      update();
    })),
    field("Relist at least this % over cost", numberInput(params.minMarkupPercent, (value) => {
      params.minMarkupPercent = Math.max(1, value ?? DEFAULT_CORNER_PARAMS.minMarkupPercent);
      update();
    })),
    field("Relist at most this % of usual", numberInput(params.maxOverUsualPercent, (value) => {
      params.maxOverUsualPercent = Math.max(100, value ?? DEFAULT_CORNER_PARAMS.maxOverUsualPercent);
      update();
    })),
    field("Restock per sale, at most", numberInput(params.maxRestock, (value) => {
      params.maxRestock = Math.max(0, value ?? DEFAULT_CORNER_PARAMS.maxRestock);
      update();
    })),
    field("Sells within days", numberInput(params.maxDays, (value) => {
      params.maxDays = Math.max(0.1, value ?? DEFAULT_CORNER_PARAMS.maxDays);
      update();
    })),
    field("Minimum profit", moneyInput(params.minProfit, (copper) => { params.minProfit = copper; update(); })),
    h("div", { class: "checks" }, checkbox("Only buyouts I can afford in full", useBudget, (value) => { useBudget = value; update(); })),
    h("div", { class: "hint" },
      `Buy every unit under a price step and relist just under it, so nothing is listed below you. Worth it when the item keeps selling and restocks slowly. ${flowNote(ctx.flows())} Days to sell uses the pace at the old prices, so expect slower. Profit assumes a ${ASSUMPTIONS.auctionCut * 100}% cut and no deposit.`),
  );

  update();
  return { element, update };
}

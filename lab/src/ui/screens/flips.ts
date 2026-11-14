// Flips: listings under the going rate that can be bought and relisted at it,
// ranked by how fast the money comes back.
import { DEFAULT_FLIP_PARAMS, type FlipParams } from "../../config/banker";
import { ASSUMPTIONS } from "../../config/catalog";
import { findFlips, type FlipLead } from "../../model/flips";
import { remember, store, type LabContext, type Screen } from "../context";
import { checkbox, clear, field, h, money, moneyInput, number, numberInput } from "../dom";
import { decimal, flowNote, LAST_SOLD_TIP, lastSold, leadName, planTip } from "../lead-cells";
import { renderTable, type Column, type Sort } from "../table";

const ROW_LIMIT = 300;

function columns(ctx: LabContext): Column<FlipLead>[] {
  return [
    { id: "name", label: "Item", sort: (lead) => lead.item.name, render: (lead) => leadName(lead.item, ctx) },
    {
      id: "buy", label: "Buy", align: "right", width: "80px", tip: "Auctions to buy, cheapest first. Hover a number for the list.",
      sort: (lead) => lead.buyAuctions,
      render: (lead) => h("span", { title: planTip(lead.lines) }, `${number(lead.buyAuctions)} (${number(lead.buyUnits)} units)`),
    },
    { id: "cost", label: "Cost", align: "right", width: "120px", sort: (lead) => lead.cost, render: (lead) => money(lead.cost) },
    { id: "average", label: "You pay / unit", align: "right", width: "120px", sort: (lead) => lead.averageUnit, render: (lead) => money(lead.averageUnit) },
    {
      id: "target", label: "Relist at", align: "right", width: "120px",
      tip: "The usual unit price, held down to the price units were seen selling at.",
      sort: (lead) => lead.target, render: (lead) => money(lead.target),
    },
    { id: "lastSold", label: "Last sold", align: "right", width: "120px", tip: LAST_SOLD_TIP, sort: (lead) => lead.flow.lastSoldPrice, render: (lead) => lastSold(lead.flow) },
    { id: "profit", label: "Profit", align: "right", width: "120px", sort: (lead) => lead.profit, render: (lead) => money(lead.profit) },
    { id: "roi", label: "Return", align: "right", width: "70px", sort: (lead) => lead.roi, render: (lead) => `${number(lead.roi)}%` },
    {
      id: "pace", label: "Sells / day", align: "right", width: "90px",
      tip: "Units a day that left before they could expire, from the cheaper half of the ladder. An estimate, not confirmed sales.",
      sort: (lead) => lead.soldPerDay, render: (lead) => decimal(lead.soldPerDay),
    },
    {
      id: "days", label: "Days to sell", align: "right", width: "100px",
      tip: "Your load plus the units still listed under your price, at the pace seen.",
      sort: (lead) => lead.daysToSell, render: (lead) => decimal(lead.daysToSell),
    },
    {
      id: "perDay", label: "Profit / day", align: "right", width: "120px",
      tip: "Profit spread over the days it takes to sell. A load that sells within a day counts as one day.",
      sort: (lead) => lead.profitPerDay, render: (lead) => money(lead.profitPerDay),
    },
  ];
}

export function createFlipsScreen(ctx: LabContext): Screen {
  const params: FlipParams = remember("flip-params", DEFAULT_FLIP_PARAMS);
  let useBudget = remember("flip-budget", { on: true }).on;
  let sort: Sort | null = { column: "perDay", descending: true };
  const table = columns(ctx);

  const controls = h("div", { class: "controls" });
  const results = h("div");
  const element = h("section", { class: "screen" }, controls, results);

  function update(): void {
    store("flip-params", params);
    store("flip-budget", { on: useBudget });
    const leads = findFlips(ctx.market.items, ctx.flows(), { ...params, budget: useBudget ? ctx.budget() : 0 });
    clear(results);
    results.append(
      renderTable({
        columns: table, rows: leads, sort,
        onSort: (next) => { sort = next; update(); },
        onRowClick: (lead) => ctx.openItem(lead.item.key),
        limit: ROW_LIMIT,
        empty: "No flips with these settings.",
      }),
    );
  }

  controls.append(
    field("Buy at least this % under relist", numberInput(params.marginPercent, (value) => {
      params.marginPercent = Math.min(95, Math.max(1, value ?? DEFAULT_FLIP_PARAMS.marginPercent));
      update();
    })),
    field("Minimum profit", moneyInput(params.minProfit, (copper) => { params.minProfit = copper; update(); })),
    field("Sells within days", numberInput(params.maxDays, (value) => {
      params.maxDays = Math.max(0.1, value ?? DEFAULT_FLIP_PARAMS.maxDays);
      update();
    })),
    field("Units seen selling, at least", numberInput(params.minSold, (value) => {
      params.minSold = Math.max(1, value ?? DEFAULT_FLIP_PARAMS.minSold);
      update();
    })),
    h("div", { class: "checks" }, checkbox("Only loads I can afford in full", useBudget, (value) => { useBudget = value; update(); })),
    h("div", { class: "hint" },
      `Buy what is listed well under the going rate and relist at it. ${flowNote(ctx.flows())} Profit assumes a ${ASSUMPTIONS.auctionCut * 100}% cut and no deposit. Click a row for the item's ladder.`),
  );

  update();
  return { element, update };
}

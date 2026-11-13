// Concept, History tab: pick an item and see how its price and supply have
// moved. Two charts, never sharing an axis: prices as lines, units as bars.
import {
  DEFAULT_HISTORY_RANGE,
  HISTORY_LIST_LIMIT,
  HISTORY_RANGES,
  PRICE_SERIES,
  UNITS_COLOR,
} from "../../config/history-view";
import { buildHistory, inRange, summarize, withSample, type ItemHistory, type PricePoint } from "../../model/price-history";
import { dayLabel, priceChart, unitsChart, type Series } from "../chart";
import type { LabContext } from "../context";
import { clear, h, icon, itemName, money, number } from "../dom";
import { renderTable, type Column, type Sort } from "../table";

const SERIES: Series[] = PRICE_SERIES.map((entry) => ({
  label: entry.label,
  color: entry.color,
  value: (point: PricePoint) => point[entry.id],
}));

interface Row {
  history: ItemHistory;
  usual: number;
  change: number | null;
}

export function createHistoryTab(ctx: LabContext): { element: HTMLElement; update: () => void } {
  let range = DEFAULT_HISTORY_RANGE;
  let search = "";
  let selectedKey: string | null = null;
  let sort: Sort | null = { column: "units", descending: true };
  let histories = new Map<string, ItemHistory>();

  const listPanel = h("div", { class: "cw-history-list" });
  const detail = h("div", { class: "cw-history-detail" });
  const element = h("div", { class: "cw-history" }, listPanel, detail);

  const columns: Column<Row>[] = [
    {
      id: "name",
      label: "Item",
      sort: (row) => row.history.item.name,
      render: (row) => h("span", { class: "item-cell" }, icon(row.history.item.icon, 18), itemName(row.history.item.name, row.history.item.quality, "")),
    },
    { id: "usual", label: "Usual", align: "right", width: "78px", sort: (row) => row.usual, render: (row) => money(row.usual) },
    {
      id: "change",
      label: "Change",
      align: "right",
      width: "54px",
      tip: "How far the usual price moved across the chosen days.",
      sort: (row) => row.change,
      render: (row) =>
        row.change === null ? "" : h("span", { class: row.change > 0 ? "good" : row.change < 0 ? "bad" : "muted" }, `${row.change > 0 ? "+" : ""}${row.change}%`),
    },
    // Not shown, only sorted by: the busiest items first.
    { id: "units", label: "", width: "0px", sort: (row) => row.history.item.units, render: () => "" },
  ];

  function rows(): Row[] {
    const text = search.trim().toLowerCase();
    const out: Row[] = [];
    for (const history of histories.values()) {
      if (text && !(history.item.name ?? "").toLowerCase().includes(text)) continue;
      const points = inRange(history.points, range);
      const summary = summarize(points);
      if (summary) out.push({ history, usual: summary.usual, change: summary.change });
    }
    return out;
  }

  function renderList(): void {
    const table = renderTable({
      columns,
      rows: rows(),
      sort,
      onSort: (next) => {
        sort = next;
        renderList();
      },
      onRowClick: (row) => {
        selectedKey = row.history.item.key;
        renderList();
        renderDetail();
      },
      rowClass: (row) => (row.history.item.key === selectedKey ? "selected" : ""),
      limit: HISTORY_LIST_LIMIT,
      empty: "Nothing matches.",
    });
    listPanel.querySelector(".table-wrap")?.remove();
    listPanel.append(table);
  }

  function tile(label: string, value: Node | string, tone = ""): HTMLElement {
    return h("div", { class: "cw-tile-stat" }, h("div", { class: "cw-tile-label" }, label), h("div", { class: `cw-tile-value ${tone}` }, value));
  }

  function renderDetail(): void {
    clear(detail);
    const history = selectedKey ? histories.get(selectedKey) : undefined;
    if (!history) {
      detail.append(h("div", { class: "cw-hint" }, "Pick an item to see how its price has moved."));
      return;
    }
    const item = history.item;
    const points = inRange(history.points, range);
    const summary = summarize(points);

    const ranges = h("div", { class: "cw-segments" });
    for (const option of HISTORY_RANGES) {
      ranges.append(
        h(
          "button",
          {
            class: `cw-segment ${option.days === range ? "active" : ""}`,
            onclick: () => {
              range = option.days;
              renderList();
              renderDetail();
            },
          },
          option.label,
        ),
      );
    }

    detail.append(
      h(
        "div",
        { class: "cw-order-head" },
        icon(item.icon, 32),
        h("div", { class: "cw-grow" }, itemName(item.name, item.quality, ""), h("div", { class: "muted small" }, `${number(item.units)} for sale now`)),
        ranges,
      ),
    );
    if (history.sample) {
      detail.append(
        h("div", { class: "cw-note cw-sample" }, "Sample history. Only the newest point is real: the lab has one day of scans so far."),
      );
    }
    if (!summary || points.length < 2) {
      detail.append(h("div", { class: "cw-hint" }, "Seen on one day so far. A second day of scans starts the graph."));
      return;
    }

    const change = summary.change;
    detail.append(
      h(
        "div",
        { class: "cw-tiles" },
        tile("Usual now", money(summary.usual)),
        tile("Lowest seen", money(summary.lowest)),
        tile("Highest usual", money(summary.highest)),
        tile("Change", change === null ? "" : `${change > 0 ? "+" : ""}${change}%`, change === null || change === 0 ? "" : change > 0 ? "good" : "bad"),
        tile("Days seen", `${summary.days} of ${range}`),
      ),
    );

    // One readout serves both charts: hovering either shows that day's numbers.
    const readout = h("div", { class: "cw-readout muted small" }, "Hover a chart to read a day.");
    const show = (point: PricePoint | null): void => {
      clear(readout);
      if (!point) {
        readout.append("Hover a chart to read a day.");
        return;
      }
      readout.append(
        h("span", { class: "cw-readout-day" }, dayLabel(point.day)),
        swatch(PRICE_SERIES[0].color),
        "usual ",
        money(point.median),
        swatch(PRICE_SERIES[1].color),
        "lowest ",
        money(point.low),
        swatch(UNITS_COLOR),
        `${number(point.units)} for sale`,
      );
    };

    const legend = h("div", { class: "cw-legend" });
    for (const entry of PRICE_SERIES) {
      legend.append(h("span", { class: "cw-legend-item" }, swatch(entry.color), entry.label));
    }

    detail.append(
      h("div", { class: "cw-chart-head" }, h("span", { class: "cw-label" }, "Price"), legend),
      priceChart(points, SERIES, show),
      h("div", { class: "cw-chart-head" }, h("span", { class: "cw-label" }, "For sale")),
      unitsChart(points, UNITS_COLOR, show),
      readout,
    );
  }

  function swatch(color: string): HTMLElement {
    return h("span", { class: "cw-swatch", style: `background:${color}` });
  }

  function rebuild(): void {
    const real = buildHistory(ctx.markets);
    histories = new Map([...real.entries()].map(([key, history]) => [key, withSample(history)]));
    if (selectedKey && !histories.has(selectedKey)) selectedKey = null;
    if (!selectedKey) {
      // Start on the busiest item, so the tab opens with a graph in it.
      let busiest: ItemHistory | null = null;
      for (const history of histories.values()) {
        if (!busiest || history.item.units > busiest.item.units) busiest = history;
      }
      selectedKey = busiest?.item.key ?? null;
    }
    renderList();
    renderDetail();
  }

  listPanel.append(
    h("input", {
      type: "search",
      class: "input cw-search",
      placeholder: "Search",
      oninput: (event: Event) => {
        search = (event.target as HTMLInputElement).value;
        renderList();
      },
    }),
  );
  rebuild();
  return { element, update: rebuild };
}

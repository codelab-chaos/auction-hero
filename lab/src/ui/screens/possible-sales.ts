import type { DetectionConfidence } from "../../model/possible-sales";
import { aggregateSales, type HistoricalSale as PossibleSale } from "../../model/history";
import type { Signal } from "../../model/signals";
import type { LabContext, Screen } from "../context";
import { checkbox, clear, field, h, icon, itemName, money, number } from "../dom";
import { renderTable, type Column, type Sort } from "../table";
import { meter, meterBlock } from "../meter";

function reading(confidence: DetectionConfidence): Signal {
  const score = confidence.score;
  const level = score === null ? { label: "Unknown", pips: 0, tone: "warn" as const }
    : score >= 70 ? { label: "High", pips: 4, tone: "good" as const }
    : score >= 30 ? { label: "Moderate", pips: 2, tone: "warn" as const }
    : score > 0 ? { label: "Low", pips: 1, tone: "warn" as const }
    : { label: "None", pips: 0, tone: "bad" as const };
  return { score: score ?? 0, pips: 4, reasons: confidence.reasons,
    level: { ...level, id: level.label, min: 0, label: `${level.label}${score === null ? "" : ` · ${score}/100`}` } };
}

const COLUMNS: Column<PossibleSale>[] = [
  { id: "name", label: "Item", sort: (row) => row.item.name, render: (row) => h("span", { class: "item-cell" }, icon(row.item.icon), itemName(row.item.name, row.item.quality, "")) },
  { id: "sale", label: "Sale confidence", tip: "Evidence points, not a probability. Click a row for the reasons.", sort: (row) => row.saleConfidence.score, render: (row) => meter(reading(row.saleConfidence)) },
  { id: "expiry", label: "Expiry confidence", tip: "Independent expiry evidence; the two scores do not add to 100. Click a row for the reasons.", sort: (row) => row.expiryConfidence.score, render: (row) => meter(reading(row.expiryConfidence)) },
  { id: "intervals", label: "Intervals", align: "right", sort: (row) => row.intervals.length, render: (row) => number(row.intervals.length) },
  { id: "market", label: "Market", sort: (row) => row.marketPlace, render: (row) => row.marketPlace },
  { id: "stack", label: "Stack", align: "right", sort: (row) => row.stack, render: (row) => number(row.stack) },
  { id: "unit", label: "Asking / unit", align: "right", sort: (row) => row.buyout / row.stack, render: (row) => money(row.buyout / row.stack) },
  { id: "price", label: "Asking / stack", align: "right", sort: (row) => row.buyout, render: (row) => money(row.buyout) },
  { id: "before", label: "First before", align: "right", tip: "Auctions at this exact stack size and buyout, across all time bands.", sort: (row) => row.before, render: (row) => number(row.before) },
  { id: "after", label: "Last after", align: "right", sort: (row) => row.after, render: (row) => number(row.after) },
  { id: "missing", label: "Missing auctions", align: "right", sort: (row) => row.missing, render: (row) => number(row.missing) },
  { id: "units", label: "Missing units", align: "right", sort: (row) => row.units, render: (row) => number(row.units) },
  { id: "could-expire", label: "Could expire (up to)", align: "right", tip: "Maximum missing units expiry could explain, including units with unknown timing. Not confirmed expirations.", sort: (row) => row.couldExpireUnits, render: (row) => number(row.couldExpireUnits) },
  { id: "beyond-expiry", label: "Beyond expiry allowance", align: "right", tip: "Missing units left after allowing every eligible earlier auction to expire. Still could be cancellations or incomplete data.", sort: (row) => row.beyondExpiryUnits, render: (row) => number(row.beyondExpiryUnits) },
  { id: "value", label: "At asking prices", align: "right", tip: "Missing auctions × their earlier stack buyout. This is not confirmed sale revenue.", sort: (row) => row.askingValue, render: (row) => money(row.askingValue) },
  { id: "supply", label: "First → last stock", tip: "Total buyout units for this variant, across every price. Supply can rise while a particular price tier shrinks.", sort: (row) => row.supplyBefore - row.supplyAfter, render: (row) => `${number(row.supplyBefore)} → ${number(row.supplyAfter)}` },
  { id: "data", label: "Data", sort: (row) => Number(row.unresolved), render: (row) => row.unresolved ? "Unresolved variants" : "Named rows" },
];

export function createPossibleSalesScreen(ctx: LabContext): Screen {
  let rows: PossibleSale[] = [];
  let chosen: PossibleSale | null = null;
  let includeUnresolved = false;
  let search = "";
  let sort: Sort | null = { column: "sale", descending: true };
  const results = h("div");
  const status = h("p", { class: "hint", role: "status", "aria-live": "polite" });
  const controls = h("div", { class: "controls" });
  const element = h("section", { class: "screen possible-sales" },
    h("h3", null, "Possible sales"),
    h("p", { class: "hint" }, "Missing listings accumulated across consecutive scans, valued at their earlier asking prices. Repeated observations are counted once per interval; stock that is replenished and disappears again can contribute another departure. Sale confidence grows when cheap stock disappears before expiry while higher-priced stock remains. Expiry confidence grows when the missing quantity fits earlier expiry windows. These are independent evidence scores, not probabilities; cancellations and replacement listings remain possible. Click a row for its reasons."),
    controls, status, results);

  function update(): void {
    const text = search.trim().toLowerCase();
    const filtered = rows.filter((row) => (includeUnresolved || !row.unresolved) && (row.item.name ?? "").toLowerCase().includes(text));
    const hidden = rows.filter((row) => row.unresolved).length;
    const auctions = filtered.reduce((sum, row) => sum + row.missing, 0);
    const units = filtered.reduce((sum, row) => sum + row.units, 0);
    const value = filtered.reduce((sum, row) => sum + row.askingValue, 0);
    const expiryUnits = filtered.reduce((sum, row) => sum + row.couldExpireUnits, 0);
    const beyondUnits = filtered.reduce((sum, row) => sum + row.beyondExpiryUnits, 0);
    const sources = new Set(rows.map((row) => row.timingSource));
    clear(results);
    results.append(
      h("div", { class: "sales-totals" },
        h("div", null, h("span", { class: "muted" }, "Missing units"), h("strong", null, number(units)), `${number(auctions)} auctions`),
        h("div", null, h("span", { class: "muted" }, "Expiry could explain"), h("strong", null, `Up to ${number(expiryUnits)}`), "units, including unknown timing"),
        h("div", null, h("span", { class: "muted" }, "Beyond expiry allowance"), h("strong", null, number(beyondUnits)), "units; sales or cancellations")),
      h("p", null, money(value), " at earlier asking prices (filtered totals)."),
      h("p", { class: "hint" }, rows.length === 0 ? "No missing named price tiers in these scans."
        : sources.has("assumed")
        ? "Assumed expiry bands are in use: Short 0–30 min, Medium 30 min–2 h, Long 2–12 h, Very long over 12 h. These boundaries are unverified on Forever. Scores using them are capped at 65/100; disable the assumption to leave expiry unknown where boundaries were not recorded."
        : sources.has("unknown") ? "Some expiry timing is unknown. Those units remain in the possible-expiry allowance; no expiry score is assigned when all timing is unknown."
        : "Expiry windows use boundaries recorded from the game in the earlier scan. Neither confidence score confirms a transaction."),
      !includeUnresolved && hidden > 0 ? h("p", { class: "muted" }, `${number(hidden)} price tiers hidden because an item ID has unnamed rows in either scan. Those rows could belong to a named variant.`) : "",
    );
    if (chosen && filtered.includes(chosen)) {
      results.append(h("div", { class: "sales-evidence-detail" },
        h("h3", null, `${chosen.item.name} · stack of ${number(chosen.stack)}`),
        h("button", { class: "button", onclick: () => { chosen = null; update(); } }, "Close reasons"),
        meterBlock("Sale confidence", reading(chosen.saleConfidence)),
        meterBlock("Expiry confidence", reading(chosen.expiryConfidence)),
        h("div", { class: "sales-intervals" }, h("strong", null, "Contributing intervals"),
          ...chosen.intervals.map((interval) => h("p", { class: "muted small" },
            `${new Date(interval.from * 1000).toLocaleString()} → ${new Date(interval.to * 1000).toLocaleString()}: ${number(interval.units)} missing units · sale ${interval.saleScore ?? "unknown"} · expiry ${interval.expiryScore ?? "unknown"}`)))));
    }
    results.append(renderTable({ columns: [...COLUMNS, { id: "reasons", label: "", render: (row) => h("button", { class: "button", onclick: (event: Event) => { event.stopPropagation(); chosen = row; update(); } }, "Reasons") }], rows: filtered, sort, onSort: (next) => { sort = next; update(); },
      onRowClick: (row) => { chosen = row; update(); }, rowClass: (row) => row === chosen ? "selected" : "",
      limit: 300, empty: "No missing listings match these filters." }));
  }

  function recalculate(): void {
    const aggregate = aggregateSales(ctx.markets, ctx.useAssumedExpiryBands);
    rows = aggregate.rows;
    chosen = null;
    const first = ctx.markets[0];
    const last = ctx.markets[ctx.markets.length - 1];
    status.textContent = aggregate.comparisons === 0
      ? "Import another full scan from the same market to detect possible sales. New scans are included automatically."
      : `${number(ctx.markets.length)} scans · ${number(aggregate.comparisons)} consecutive comparisons · ${new Date(first!.meta.time * 1000).toLocaleString()} → ${new Date(last!.meta.time * 1000).toLocaleString()}. Markets are compared separately. Scores are weighted by missing units across intervals. Bid-only auctions are excluded; time bands are pooled so aging alone is not a disappearance.`;
    update();
  }

  controls.append(
    field("Item name", h("input", { type: "search", class: "input input-text", placeholder: "Search items", oninput: (event: Event) => { search = (event.target as HTMLInputElement).value; update(); } })),
    checkbox("Include items with unresolved variants", includeUnresolved, (value) => { includeUnresolved = value; update(); }),
  );
  recalculate();
  return { element, update };
}

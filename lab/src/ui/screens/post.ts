// Post: pick an item as if from your bags and compare posting price rules
// against its current price ladder.
import { ASSUMPTIONS } from "../../config/catalog";
import { PRICE_RULES } from "../../config/price-rules";
import type { MarketItem, Tier } from "../../model/market";
import { quote, type Quote } from "../../model/pricing";
import type { LabContext, Screen } from "../context";
import { clear, field, h, icon, itemName, money, number, numberInput } from "../dom";
import { renderTable, type Column } from "../table";

const SEARCH_RESULTS = 12;
const LADDER_ROWS = 14;

type LadderRow = { you: true; unit: number } | { you: false; tier: Tier };

export function createPostScreen(ctx: LabContext): Screen {
  let selected: MarketItem | null = null;
  let quantity = 1;
  let ruleId = PRICE_RULES[1]?.id ?? "";
  let search = "";

  const picker = h("div", { class: "picker" });
  const body = h("div", { class: "post-body" });
  const element = h("section", { class: "screen" }, picker, body);

  function matches(): MarketItem[] {
    const text = search.trim().toLowerCase();
    if (text.length < 2) return [];
    return ctx.market.items
      .filter((item) => item.name?.toLowerCase().includes(text))
      .sort((a, b) => b.listings - a.listings)
      .slice(0, SEARCH_RESULTS);
  }

  function renderMatches(): HTMLElement {
    const list = h("div", { class: "picker-results" });
    for (const item of matches()) {
      list.append(
        h(
          "button",
          { class: "picker-item", onclick: () => choose(item) },
          icon(item.icon),
          itemName(item.name, item.quality, ""),
          h("span", { class: "muted" }, `${number(item.listings)} listed`),
        ),
      );
    }
    return list;
  }

  function renderPicker(): void {
    clear(picker);
    picker.append(
      field(
        "Item to post",
        h("input", {
          type: "search",
          class: "input input-text",
          placeholder: "Type at least 2 letters",
          value: search,
          oninput: (event: Event) => {
            search = (event.target as HTMLInputElement).value;
            // Redraw only the list so the box keeps its focus.
            picker.querySelector(".picker-results")?.replaceWith(renderMatches());
          },
        }),
      ),
      renderMatches(),
    );
  }

  function choose(item: MarketItem): void {
    selected = item;
    quantity = 1;
    renderBody();
  }

  const quoteColumns: Column<Quote>[] = [
    { id: "rule", label: "Rule", render: (row) => h("div", null, h("div", null, row.rule.label), h("div", { class: "muted small" }, row.rule.note)) },
    { id: "unit", label: "Per unit", align: "right", width: "120px", render: (row) => money(row.unit) },
    { id: "total", label: "Stack price", align: "right", width: "120px", render: (row) => money(row.total) },
    { id: "ahead", label: "Units ahead of you", align: "right", width: "140px", render: (row) => number(row.unitsAhead) },
    { id: "auctions", label: "Auctions ahead", align: "right", width: "120px", render: (row) => number(row.auctionsAhead) },
    { id: "proceeds", label: "You receive", align: "right", width: "120px", render: (row) => money(row.proceeds) },
  ];

  // The cheapest rungs of the ladder with "you" slotted in at the chosen price.
  function ladderRows(item: MarketItem, unit: number | null): LadderRow[] {
    const rows: LadderRow[] = [];
    let placed = unit === null;
    for (const tier of item.tiers) {
      if (!placed && unit !== null && tier.unit >= unit) {
        rows.push({ you: true, unit });
        placed = true;
      }
      rows.push({ you: false, tier });
      if (rows.length >= LADDER_ROWS && placed) break;
    }
    if (!placed && unit !== null) rows.push({ you: true, unit });
    return rows;
  }

  const ladderColumns: Column<LadderRow>[] = [
    {
      id: "unit",
      label: "Per unit",
      align: "right",
      width: "120px",
      render: (row) => money(row.you ? row.unit : row.tier.unit),
    },
    { id: "stack", label: "Stack of", align: "right", width: "90px", render: (row) => (row.you ? number(quantity) : number(row.tier.stack)) },
    { id: "copies", label: "Auctions", align: "right", width: "90px", render: (row) => (row.you ? "yours" : number(row.tier.copies)) },
    { id: "units", label: "Units", align: "right", width: "90px", render: (row) => (row.you ? number(quantity) : number(row.tier.units)) },
  ];

  function renderBody(): void {
    clear(body);
    const item = selected;
    if (!item) {
      body.append(h("div", { class: "empty" }, "Search for an item above, or click Post on any item's detail panel."));
      return;
    }
    body.append(
      h(
        "div",
        { class: "post-head" },
        icon(item.icon, 36),
        h(
          "div",
          null,
          h("div", { class: "title" }, itemName(item.name, item.quality, "")),
          h("div", { class: "muted" }, `${number(item.listings)} auctions, ${number(item.units)} units listed. Lowest `, money(item.min), ", median ", money(item.median)),
        ),
        field(
          "Units in your stack",
          numberInput(quantity, (value) => {
            quantity = Math.max(1, Math.floor(value ?? 1));
            renderResults();
          }),
        ),
      ),
    );

    const results = h("div", { class: "post-results" });
    body.append(results);

    const renderResults = (): void => {
      const fresh = PRICE_RULES.map((rule) => quote(item, rule, quantity));
      const pick = fresh.find((candidate) => candidate.rule.id === ruleId) ?? fresh[0];
      clear(results);
      results.append(
        h("h3", null, "Price rules"),
        renderTable({
          columns: quoteColumns,
          rows: fresh,
          sort: null,
          onSort: () => {},
          onRowClick: (row) => {
            ruleId = row.rule.id;
            renderResults();
          },
          rowClass: (row) => (row.rule.id === ruleId ? "selected" : ""),
          limit: 50,
          empty: "",
        }),
        h(
          "div",
          { class: "hint" },
          `"You receive" assumes the auction house keeps ${ASSUMPTIONS.auctionCut * 100}% (the Classic rule, not yet confirmed on Forever). The deposit is not included: the scan cannot tell us what it is.`,
        ),
        h("h3", null, `Where "${pick?.rule.label ?? ""}" puts you`),
        renderTable({
          columns: ladderColumns,
          rows: ladderRows(item, pick?.unit ?? null),
          sort: null,
          onSort: () => {},
          rowClass: (row) => (row.you ? "you" : ""),
          limit: 50,
          empty: "No auctions with a buyout.",
        }),
      );
    };
    renderResults();
  }

  renderPicker();
  renderBody();

  return {
    element,
    update: () => {
      if (selected) selected = ctx.market.byKey.get(selected.key) ?? null;
      renderPicker();
      renderBody();
    },
    select: (key) => {
      const item = ctx.market.byKey.get(key);
      if (item) choose(item);
    },
  };
}

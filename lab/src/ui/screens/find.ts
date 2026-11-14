// Find: filter the whole market down to items you can use and afford.
import { MARKET_TYPES } from "../../config/banker";
import { DEAL_CONFIDENCE_RULE } from "../../config/signals";
import { DEAL_RULE, EQUIP_SLOTS, LEVEL_TYPES, levelOf, QUALITIES } from "../../config/catalog";
import { dealConfidence, type DealConfidence } from "../../model/deal-confidence";
import { applyFindFilter, DEFAULT_FIND_FILTER, type FindFilter } from "../../model/filters";
import { affordable, type MarketItem } from "../../model/market";
import { marketType, type MarketReading } from "../../model/market-type";
import { priceConfidence } from "../../model/signals";
import { remember, store, type LabContext, type Screen } from "../context";
import { checkbox, clear, field, h, icon, itemName, money, number, numberInput, select } from "../dom";
import { meter } from "../meter";
import { renderTable, type Column, type Sort } from "../table";

const ROW_LIMIT = 300;

const MARKET_TYPE_BY_ID = new Map(MARKET_TYPES.map((type) => [type.id, type]));

// How sure a deal must be to be listed: any, sure enough to buy for yourself,
// or sure enough to buy for resale.
const CONFIDENCE_CHOICES = [
  { value: "0", label: "Any" },
  { value: String(DEAL_CONFIDENCE_RULE.showFrom), label: `To use (${DEAL_CONFIDENCE_RULE.showFrom}+)` },
  { value: String(DEAL_CONFIDENCE_RULE.resellFrom), label: `To resell (${DEAL_CONFIDENCE_RULE.resellFrom}+)` },
];

function columns(
  ctx: LabContext,
  reading: (item: MarketItem) => MarketReading,
  confidence: (item: MarketItem) => DealConfidence,
): Column<MarketItem>[] {
  return [
    {
      id: "name",
      label: "Item",
      sort: (item) => item.name,
      render: (item) => h("span", { class: "item-cell" }, icon(item.icon), itemName(item.name, item.quality, `item ${item.id}`)),
    },
    // One numeric column per meaning of "level": Level, Skill, Slots.
    ...LEVEL_TYPES.map(
      (type): Column<MarketItem> => ({
        id: `level:${type.id}`,
        label: type.column,
        align: "right",
        width: "64px",
        tip: type.name,
        sort: (item) => levelOf(item, type.id),
        render: (item) => number(levelOf(item, type.id)),
      }),
    ),
    {
      id: "slot",
      label: "Slot",
      width: "110px",
      sort: (item) => item.equipLoc,
      render: (item) => (item.equipLoc ? (EQUIP_SLOTS[item.equipLoc] ?? item.equipLoc) : (item.subType ?? "")),
    },
    { id: "listings", label: "Listings", align: "right", width: "80px", sort: (item) => item.listings, render: (item) => number(item.listings) },
    { id: "units", label: "Units", align: "right", width: "80px", sort: (item) => item.units, render: (item) => number(item.units) },
    {
      id: "dealConfidence", label: "Deal confidence", width: "130px",
      tip: "How far to trust that the low price is a real deal: days of scans, units seen selling, different prices, and whether it sits near vendor price. Hover a meter for its reasons.",
      sort: (item) => (item.deal === null ? null : confidence(item).score),
      render: (item) => (item.deal === null ? "" : meter(confidence(item))),
    },
    {
      id: "pace", label: "Sells / day", align: "right", width: "90px",
      tip: "Units a day that left before they could expire and were not relisted lower. An estimate from comparing scans, not confirmed sales.",
      sort: (item) => reading(item).soldPerDay,
      render: (item) => { const pace = reading(item).soldPerDay; return pace === null ? "" : pace >= 100 ? number(pace) : pace.toFixed(1); },
    },
    {
      id: "market", label: "Market", width: "80px",
      tip: MARKET_TYPES.map((type) => `${type.label}: ${type.note}`).join("\n"),
      sort: (item) => reading(item).type,
      render: (item) => {
        const type = MARKET_TYPE_BY_ID.get(reading(item).type);
        return h("span", { class: `market-type market-${type?.id ?? "unknown"}`, title: type?.note ?? "" }, type?.label ?? "");
      },
    },
    { id: "min", label: "Lowest", align: "right", width: "120px", sort: (item) => item.min, render: (item) => money(item.min) },
    { id: "median", label: "Median", align: "right", width: "120px", sort: (item) => item.median, render: (item) => money(item.median) },
    {
      id: "deal",
      label: "Deal",
      align: "right",
      width: "110px",
      tip: "How far the lowest price sits under what you would otherwise pay: the price once the cheapest few units are skipped, held down to its usual low across scans.",
      sort: (item) => item.deal,
      render: (item) => (item.deal === null ? "" : `${item.deal}%`),
    },
    {
      id: "confidence",
      label: "Price confidence",
      width: "120px",
      tip: "How far to trust a price read off this item's auctions. Hover a meter for the reasons.",
      sort: (item) => priceConfidence(item).score,
      render: (item) => meter(priceConfidence(item)),
    },
    {
      id: "afford",
      label: "You can buy",
      align: "right",
      width: "110px",
      tip: "Units your gold buys, cheapest auctions first. Set your gold in the header.",
      sort: (item) => (ctx.budget() > 0 ? affordable(item, ctx.budget()).units : null),
      render: (item) => (ctx.budget() > 0 ? number(affordable(item, ctx.budget()).units) : ""),
    },
  ];
}

export function createFindScreen(ctx: LabContext): Screen {
  const filter: FindFilter = remember("find-filter", DEFAULT_FIND_FILTER);
  let sort: Sort | null = remember<{ sort: Sort | null }>("find-sort", { sort: { column: "units", descending: true } }).sort;
  let market = remember("find-market", { type: "" }).type; // "" means any market type
  let minConfidence = remember("find-confidence", { score: 0 }).score; // the least deal confidence a deal needs
  const confidences = new Map<string, DealConfidence>();
  const confidence = (item: MarketItem): DealConfidence => {
    let known = confidences.get(item.key);
    if (!known) {
      known = dealConfidence(item, ctx.flows());
      confidences.set(item.key, known);
    }
    return known;
  };
  // Worked out once per item and kept: the list asks for it on every sort.
  const readings = new Map<string, MarketReading>();
  const reading = (item: MarketItem): MarketReading => {
    let known = readings.get(item.key);
    if (!known) {
      known = marketType(item, ctx.flows());
      readings.set(item.key, known);
    }
    return known;
  };

  const results = h("div");
  const controls = h("div", { class: "controls" });
  const element = h("section", { class: "screen" }, controls, results);

  function update(): void {
    store("find-filter", filter);
    store("find-market", { type: market });
    store("find-confidence", { score: minConfidence });
    const rows = applyFindFilter(ctx.market.items, filter, ctx.budget(), DEAL_RULE.percent).filter(
      (item) =>
        (market === "" || reading(item).type === market) &&
        // The confidence bar applies to deals: with it set, only deals that clear it are listed.
        (minConfidence === 0 || (item.deal !== null && item.deal >= DEAL_RULE.percent && confidence(item).score >= minConfidence)),
    );
    clear(results);
    results.append(
      renderTable({
        columns: columns(ctx, reading, confidence).filter((column) => column.id !== "slot" || ctx.market.meta.hasItemTypes),
        rows,
        sort,
        onSort: (next) => {
          sort = next;
          store("find-sort", { sort });
          update();
        },
        onRowClick: (item) => ctx.openItem(item.key),
        limit: ROW_LIMIT,
        empty: "Nothing matches these filters.",
      }),
    );
  }

  function set<K extends keyof FindFilter>(key: K, value: FindFilter[K]): void {
    filter[key] = value;
    update();
  }

  // Distinct values of an item field, for the type filters.
  function distinct(read: (item: MarketItem) => string | null): { value: string; label: string }[] {
    const values = new Set<string>();
    for (const item of ctx.market.items) {
      const value = read(item);
      if (value) values.add(value);
    }
    return [{ value: "", label: "Any" }, ...[...values].sort().map((value) => ({ value, label: EQUIP_SLOTS[value] ?? value }))];
  }

  function buildControls(): void {
    clear(controls);
    const qualityChecks = h("div", { class: "chips" });
    for (const quality of QUALITIES) {
      qualityChecks.append(
        h(
          "label",
          { class: "chip", style: `color:${quality.color}` },
          h("input", {
            type: "checkbox",
            checked: filter.qualities.includes(quality.id),
            onchange: (event: Event) => {
              const on = (event.target as HTMLInputElement).checked;
              set("qualities", on ? [...filter.qualities, quality.id] : filter.qualities.filter((id) => id !== quality.id));
            },
          }),
          quality.label,
        ),
      );
    }

    controls.append(
      field(
        "Name",
        h("input", {
          type: "search",
          class: "input input-text",
          placeholder: "Filter by name",
          value: filter.text,
          oninput: (event: Event) => set("text", (event.target as HTMLInputElement).value),
        }),
      ),
      field(
        "Kind",
        select(
          [{ value: "", label: "Any" }, ...LEVEL_TYPES.map((type) => ({ value: type.id, label: type.label }))],
          filter.levelType,
          (value) => set("levelType", value),
        ),
      ),
      field("Required level from", numberInput(filter.levelMin, (value) => set("levelMin", value), "min")),
      field("to", numberInput(filter.levelMax, (value) => set("levelMax", value), "max")),
      field("Quality", qualityChecks),
      field(
        "Deals, sure enough",
        select(CONFIDENCE_CHOICES, String(minConfidence), (value) => { minConfidence = Number(value); update(); }),
      ),
      field(
        "Market",
        select(
          [{ value: "", label: "Any" }, ...MARKET_TYPES.map((type) => ({ value: type.id, label: type.label }))],
          market,
          (value) => { market = value; update(); },
        ),
      ),
    );

    if (ctx.market.meta.hasItemTypes) {
      controls.append(
        field("Type", select(distinct((item) => item.type), filter.type, (value) => set("type", value))),
        field("Subtype", select(distinct((item) => item.subType), filter.subType, (value) => set("subType", value))),
        field("Slot", select(distinct((item) => item.equipLoc), filter.slot, (value) => set("slot", value))),
      );
    } else {
      controls.append(
        h("div", { class: "hint" }, "This scan has no item types or slots. Run npm run refresh to add them."),
      );
    }

    controls.append(
      h(
        "div",
        { class: "checks" },
        checkbox("Usable by my character", filter.usableOnly, (value) => set("usableOnly", value)),
        checkbox("I can afford one", filter.affordableOnly, (value) => set("affordableOnly", value)),
        checkbox(`Deals (${DEAL_RULE.percent}%+ under what you would otherwise pay)`, filter.dealsOnly, (value) => set("dealsOnly", value)),
        checkbox("Hide rows the scan never filled in", filter.hideUnknown, (value) => set("hideUnknown", value)),
      ),
    );
  }

  buildControls();
  update();
  return { element, update };
}

// Find: filter the whole market down to items you can use and afford.
import { DEAL_RULE, EQUIP_SLOTS, LEVEL_TYPES, levelOf, QUALITIES } from "../../config/catalog";
import { applyFindFilter, DEFAULT_FIND_FILTER, type FindFilter } from "../../model/filters";
import { affordable, type MarketItem } from "../../model/market";
import { priceConfidence } from "../../model/signals";
import { remember, store, type LabContext, type Screen } from "../context";
import { checkbox, clear, field, h, icon, itemName, money, number, numberInput, select } from "../dom";
import { meter } from "../meter";
import { renderTable, type Column, type Sort } from "../table";

const ROW_LIMIT = 300;

function columns(ctx: LabContext): Column<MarketItem>[] {
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
    { id: "min", label: "Lowest", align: "right", width: "120px", sort: (item) => item.min, render: (item) => money(item.min) },
    { id: "median", label: "Median", align: "right", width: "120px", sort: (item) => item.median, render: (item) => money(item.median) },
    {
      id: "deal",
      label: "Below median",
      align: "right",
      width: "110px",
      tip: "How far the lowest price sits under the median. Needs 3 or more listings.",
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

  const results = h("div");
  const controls = h("div", { class: "controls" });
  const element = h("section", { class: "screen" }, controls, results);

  function update(): void {
    store("find-filter", filter);
    const rows = applyFindFilter(ctx.market.items, filter, ctx.budget(), DEAL_RULE.percent);
    clear(results);
    results.append(
      renderTable({
        columns: columns(ctx).filter((column) => column.id !== "slot" || ctx.market.meta.hasItemTypes),
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
    for (const quality of QUALITIES.filter((candidate) => candidate.id <= 4)) {
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
        checkbox(`Deals (${DEAL_RULE.percent}%+ under median)`, filter.dealsOnly, (value) => set("dealsOnly", value)),
        checkbox("Hide rows the scan never filled in", filter.hideUnknown, (value) => set("hideUnknown", value)),
      ),
    );
  }

  buildControls();
  update();
  return { element, update };
}

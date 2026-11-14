// Concept, Buy tab: categories on the left, a short list in the middle, and
// an order panel that says what buying a quantity really costs and involves.
import { DEAL_RULE, levelOf, CHARACTER_LEVEL_TYPE } from "../../config/catalog";
import { BUY_LADDER_ROWS, BUY_LIST_LIMIT, BUY_PRICE_ROWS, BUY_TOGGLES } from "../../config/concept";
import { BUY_FACETS, BUY_RAIL, type RailEntry } from "../../config/facets";
import { applyFacets, optionsOf, refineKey, toggleFacetValue, type FacetSelection } from "../../model/facets";
import { applyFindFilter, DEFAULT_FIND_FILTER, type FindFilter } from "../../model/filters";
import { pricePoints, type MarketItem, type PricePoint } from "../../model/market";
import { fillAt, fillOrder } from "../../model/orders";
import type { LabContext } from "../context";
import { deal } from "../../model/signals";
import { clear, h, icon, itemName, money, moneyText, number } from "../dom";
import { meter } from "../meter";
import { renderTable, type Column, type Sort } from "../table";

const LIST_COLUMNS: Column<MarketItem>[] = [
  {
    id: "name",
    label: "Item",
    sort: (item) => item.name,
    render: (item) => h("span", { class: "item-cell" }, icon(item.icon, 18), itemName(item.name, item.quality, "")),
  },
  {
    id: "level",
    label: "Lvl",
    align: "right",
    width: "44px",
    sort: (item) => levelOf(item, CHARACTER_LEVEL_TYPE),
    render: (item) => number(levelOf(item, CHARACTER_LEVEL_TYPE)),
  },
  // An item's row gives the total and the lowest price. Opened, its price rows
  // give how many are at each price.
  { id: "units", label: "For sale", align: "right", width: "64px", tip: "How many are for sale, at all prices.", sort: (item) => item.units, render: (item) => number(item.units) },
  { id: "min", label: "From", align: "right", width: "100px", tip: "The lowest price. Click the item to see every price.", sort: (item) => item.min, render: (item) => money(item.min) },
  {
    id: "deal",
    label: "$",
    align: "right",
    width: "54px",
    tip: "How far the lowest price is under what you would otherwise pay.",
    sort: (item) => item.deal,
    render: (item) => (item.deal !== null && item.deal >= DEAL_RULE.percent ? h("span", { class: "badge badge-deal" }, `-${item.deal}%`) : ""),
  },
];

export function createBuyTab(ctx: LabContext): { element: HTMLElement; update: () => void } {
  const filter: FindFilter = { ...DEFAULT_FIND_FILTER };
  const selection: FacetSelection = new Map();
  const open = new Map(BUY_FACETS.map((facet) => [facet.id, facet.open]));
  let sort: Sort | null = { column: "units", descending: true };
  let selected: MarketItem | null = null;
  let wanted = 1;
  let openKey: string | null = null; // the item whose prices are listed under it
  let pickedUnit: number | null = null; // the price picked under it, if one was

  const rail = h("div", { class: "cw-rail" });
  const sidebar = h("div", { class: "cw-sidebar" });
  const toolbar = h("div", { class: "cw-toolbar" });
  const list = h("div", { class: "cw-list" });
  const order = h("div", { class: "cw-order" });
  const element = h("div", { class: "cw-buy" }, rail, sidebar, h("div", { class: "cw-center" }, toolbar, list), order);

  // Boxes are offered only for items the list can show: a row the scan never
  // filled in has no name, so it should not conjure a box that leads nowhere.
  function buildFacetOptions(): Map<string, ReturnType<typeof optionsOf>> {
    const listable = ctx.market.items.filter((item) => item.name !== null && item.units > 0);
    return new Map(BUY_FACETS.map((facet) => [facet.id, optionsOf(facet, listable)]));
  }

  // One collapsible group of checkboxes per facet. A group whose facet allows
  // it has a checkbox of its own in the header that ticks everything inside.
  // The options are worked out once: they only change with the scan.
  let facetOptions = buildFacetOptions();

  function setAll(facetId: string, values: string[], on: boolean): void {
    for (const value of values) toggleFacetValue(selection, facetId, value, on);
    renderSidebar();
    renderList();
  }

  // The rail: a stack of square tiles down the far left. Each tile is a
  // checkbox over a color or an icon, and says what it is in a tooltip.
  // It holds the facets placed there, then any group's toggles placed there.
  function tile(
    tip: string,
    on: boolean,
    look: { color?: string; icon?: number | null; shape?: "swatch" },
    onToggle: () => void,
  ): HTMLElement {
    return h(
      "button",
      {
        class: `cw-tile ${on ? "on" : ""} ${look.icon ? "cw-tile-icon" : ""} ${look.shape === "swatch" ? "cw-tile-swatch" : ""}`,
        style: look.color ? `--tile:${look.color}` : "",
        "data-tip": tip,
        "aria-label": tip,
        "aria-pressed": String(on),
        onclick: onToggle,
      },
      look.icon ? icon(look.icon, 24) : "",
      h("span", { class: "cw-tile-check" }, on ? "✓" : ""),
    );
  }

  // The most-listed item a toggle would show, to picture it.
  function pictureFor(facet: (typeof BUY_FACETS)[number], value: string): number | null {
    let best: MarketItem | null = null;
    let bestPreferred = false;
    for (const item of ctx.market.items) {
      if (item.icon === null || item.name === null || facet.read(item) === null) continue;
      if (facet.refine?.read(item) !== value) continue;
      const preferred = facet.refine.pictures?.(item, value) ?? false;
      const better = preferred === bestPreferred ? !best || item.listings > best.listings : preferred;
      if (better) {
        best = item;
        bestPreferred = preferred;
      }
    }
    return best?.icon ?? null;
  }

  function renderRail(): void {
    clear(rail);
    const facetById = new Map(BUY_FACETS.map((facet) => [facet.id, facet]));

    function tilesFor(entry: RailEntry): HTMLElement[] {
      if ("facet" in entry || "box" in entry) {
        const facet = facetById.get("facet" in entry ? entry.facet : entry.of);
        if (!facet) return [];
        const ticked = selection.get(facet.id) ?? new Set<string>();
        return (facetOptions.get(facet.id) ?? [])
          .filter((option) => ("box" in entry ? option.label === entry.box : true))
          .map((option) => {
            const on = ticked.has(option.value);
            // A single box names itself. A whole facet's boxes say which facet they are.
            const tip = "box" in entry ? option.label : `${facet.label}: ${option.label}`;
            return tile(tip, on, { color: option.color, icon: option.icon, shape: facet.tileShape }, () => {
              toggleFacetValue(selection, facet.id, option.value, !on);
              refresh();
            });
          });
      }
      const facet = facetById.get(entry.refine);
      const refine = facet?.refine;
      if (!facet || !refine) return [];
      const key = refineKey(facet.id);
      const ticked = selection.get(key) ?? new Set<string>();
      return refine.options.map((option) => {
        const on = ticked.has(option.value);
        return tile(`${refine.label}: ${option.label}`, on, { icon: pictureFor(facet, option.value) }, () => {
          toggleFacetValue(selection, key, option.value, !on);
          refresh();
        });
      });
    }

    BUY_RAIL.map((section) => section.flatMap(tilesFor))
      .filter((tiles) => tiles.length > 0)
      .forEach((tiles, index) => {
        if (index > 0) rail.append(h("div", { class: "cw-rail-gap" }));
        rail.append(...tiles);
      });
  }

  // Redraws everything a filter change touches.
  function refresh(): void {
    renderRail();
    renderSidebar();
    renderList();
  }

  function renderSidebar(): void {
    clear(sidebar);
    for (const facet of BUY_FACETS) {
      if (facet.placement === "rail") continue;
      const options = facetOptions.get(facet.id) ?? [];
      if (options.length === 0) continue;
      const ticked = selection.get(facet.id) ?? new Set<string>();
      const isOpen = open.get(facet.id) === true;
      const all = ticked.size === options.length;
      const refined = selection.get(refineKey(facet.id)) ?? new Set<string>();
      // What the badge counts: boxes ticked short of "all", plus toggles on.
      const filtering = (all ? 0 : ticked.size) + refined.size;

      // A flat group has no header and no expander: its boxes sit straight
      // in the column. A group with one box takes the group's name.
      if (facet.flat) {
        for (const option of options) {
          sidebar.append(
            h(
              "label",
              { class: "cw-facet cw-facet-head cw-facet-flat" },
              h("input", {
                type: "checkbox",
                class: "cw-facet-all",
                checked: ticked.has(option.value),
                onchange: (event: Event) => {
                  toggleFacetValue(selection, facet.id, option.value, (event.target as HTMLInputElement).checked);
                  refresh();
                },
              }),
              option.icon !== undefined ? icon(option.icon, 16) : "",
              h("span", { class: "cw-facet-name" }, options.length === 1 ? facet.label : option.label),
            ),
          );
        }
        continue;
      }

      const head = h("div", { class: "cw-facet-head" });
      if (facet.selectAll) {
        head.append(
          h("input", {
            type: "checkbox",
            class: "cw-facet-all",
            checked: all,
            indeterminate: ticked.size > 0 && !all,
            title: `All ${facet.label}`,
            onchange: (event: Event) =>
              setAll(
                facet.id,
                options.map((option) => option.value),
                (event.target as HTMLInputElement).checked,
              ),
          }),
        );
      }
      head.append(
        h(
          "button",
          {
            class: "cw-facet-toggle",
            onclick: () => {
              open.set(facet.id, !isOpen);
              renderSidebar();
            },
          },
          h("span", { class: "cw-facet-name" }, facet.label),
          filtering > 0 ? h("span", { class: "cw-facet-count" }, String(filtering)) : "",
          h("span", { class: "cw-caret" }, isOpen ? "▾" : "▸"),
        ),
      );

      const group = h("div", { class: "cw-facet" }, head);
      if (isOpen) {
        for (const option of options) {
          if (option.inRail) continue; // it is a tile in the left strip
          group.append(
            h(
              "label",
              { class: "cw-facet-option", style: option.color ? `color:${option.color}` : "" },
              h("input", {
                type: "checkbox",
                checked: ticked.has(option.value),
                onchange: (event: Event) => {
                  toggleFacetValue(selection, facet.id, option.value, (event.target as HTMLInputElement).checked);
                  renderSidebar();
                  renderList();
                },
              }),
              option.icon !== undefined ? icon(option.icon, 16) : "",
              h("span", { class: "cw-facet-label" }, option.label),
            ),
          );
        }
        // The group's toggles, such as armor slots. They narrow this group only.
        if (facet.refine && facet.refine.placement !== "rail") {
          const refine = facet.refine;
          const toggles = h("div", { class: "cw-refine" });
          for (const option of refine.options) {
            const on = refined.has(option.value);
            toggles.append(
              h(
                "button",
                {
                  class: `cw-toggle cw-refine-toggle ${on ? "active" : ""}`,
                  onclick: () => {
                    toggleFacetValue(selection, refineKey(facet.id), option.value, !on);
                    renderSidebar();
                    renderList();
                  },
                },
                option.label,
              ),
            );
          }
          group.append(h("div", { class: "cw-refine-label" }, refine.label), toggles);
        }
      }
      sidebar.append(group);
    }
    const anyTicked = [...selection.values()].some((values) => values.size > 0);
    if (anyTicked) {
      sidebar.append(
        h(
          "button",
          {
            class: "cw-facet-clear",
            onclick: () => {
              selection.clear();
              renderRail();
              renderSidebar();
              renderList();
            },
          },
          "Clear all",
        ),
      );
    }
  }

  function renderToolbar(): void {
    clear(toolbar);
    toolbar.append(
      h("input", {
        type: "search",
        class: "input cw-search",
        placeholder: "Search",
        value: filter.text,
        oninput: (event: Event) => {
          filter.text = (event.target as HTMLInputElement).value;
          renderList();
        },
      }),
    );
    for (const toggle of BUY_TOGGLES) {
      toolbar.append(
        h(
          "button",
          {
            class: `cw-toggle ${filter[toggle.id] ? "active" : ""}`,
            onclick: () => {
              filter[toggle.id] = !filter[toggle.id];
              renderToolbar();
              renderList();
            },
          },
          toggle.label,
        ),
      );
    }
  }

  function renderList(): void {
    clear(list);
    list.append(
      renderTable({
        columns: LIST_COLUMNS,
        rows: applyFacets(applyFindFilter(ctx.market.items, filter, ctx.budget(), DEAL_RULE.percent), BUY_FACETS, selection).filter(
          (item) => item.units > 0,
        ),
        sort,
        onSort: (next) => {
          sort = next;
          renderList();
        },
        // An item opens to show every price, or closes again.
        onRowClick: (item) => {
          openKey = openKey === item.key ? null : item.key;
          selected = item;
          pickedUnit = null;
          wanted = 1;
          renderList();
          renderOrder();
        },
        rowClass: (item) => (item === selected && pickedUnit === null ? "selected" : ""),
        after: (item) => (item.key === openKey ? priceRows(item) : []),
        limit: BUY_LIST_LIMIT,
        empty: "Nothing matches.",
      }),
    );
  }

  // How far a unit price sits under what the item would otherwise cost, in
  // percent, or null when it does not.
  function dealAt(item: MarketItem, unit: number): number | null {
    if (item.deal === null || item.baseline === null || unit >= item.baseline) return null;
    return Math.floor(((item.baseline - unit) / item.baseline) * 100);
  }

  // The rows under an opened item: one for each price it is listed at, with
  // how many are at that price. Nothing about what is for sale is left to guess.
  function priceRows(item: MarketItem): HTMLElement[] {
    const points = pricePoints(item);
    const rows = points.slice(0, BUY_PRICE_ROWS).map((point) => {
      const under = dealAt(item, point.unit);
      return h(
        "tr",
        {
          class: `clickable cw-price-row ${item === selected && pickedUnit === point.unit ? "selected" : ""}`,
          onclick: () => pick(item, point),
        },
        h("td", null, h("span", { class: "cw-price-label" }, "-  for sale at")),
        h("td", null, ""),
        h("td", { class: "right" }, number(point.units)),
        h("td", { class: "right" }, money(point.unit)),
        h("td", { class: "right" }, under !== null && under >= DEAL_RULE.percent ? h("span", { class: "badge badge-deal" }, `-${under}%`) : ""),
      );
    });
    const last = points[points.length - 1];
    if (points.length > BUY_PRICE_ROWS && last) {
      rows.push(h("tr", { class: "cw-price-row" }, h("td", { colSpan: 5 }, h("span", { class: "cw-price-label" }, `-  and ${number(points.length - BUY_PRICE_ROWS)} more prices, up to `, money(last.unit)))));
    }
    return rows;
  }

  // A price under an opened item: this is the one to buy.
  function pick(item: MarketItem, point: PricePoint): void {
    selected = item;
    pickedUnit = point.unit;
    if (fillOrder(item, 1).byUnit) {
      // Goods are filled from the cheapest up, so picking a price means
      // everything up to and including it.
      wanted = pricePoints(item).reduce((units, other) => units + (other.unit <= point.unit ? other.units : 0), 0);
    }
    renderList();
    renderOrder();
  }

  // What the scans show about an item (the addon's tooltip lines and more),
  // then every price it is listed at now with how many are at each.
  function statsRows(item: MarketItem): HTMLElement[] {
    const points = pricePoints(item);
    const quote = (point: PricePoint): HTMLElement => h("span", null, money(point.unit), `  (${number(point.units)} of ${number(item.units)})`);
    const row = (label: string, value: HTMLElement | string): HTMLElement => h("div", { class: "cw-stat" }, h("span", { class: "muted" }, label), h("span", null, value));
    let common: PricePoint | null = null;
    points.forEach((point, index) => {
      if (index >= 2 && point.units > (common?.units ?? 1)) common = point;
    });
    const scans = item.scansSeen ?? 1;
    const days = item.daysSeen ?? 1;
    const facts = [
      points[0] ? row("Lowest", quote(points[0])) : null,
      points[1] ? row("Next price up", quote(points[1])) : null,
      common ? row("Most are at", quote(common)) : null,
      row("Seen in", `${number(scans)} ${scans === 1 ? "scan" : "scans"} over ${number(days)} ${days === 1 ? "day" : "days"}`),
      (item.typicalLow ?? null) !== null ? row("Usual lowest", money(item.typicalLow ?? null)) : null,
      (item.lowestSeen ?? null) !== null ? row("Lowest ever", money(item.lowestSeen ?? null)) : null,
    ].filter((entry): entry is HTMLElement => entry !== null);

    const shown = points.slice(0, points.length > BUY_LADDER_ROWS ? BUY_LADDER_ROWS - 1 : BUY_LADDER_ROWS);
    const most = Math.max(1, ...shown.map((point) => point.units));
    const ladder = shown.map((point) =>
      h(
        "div",
        { class: "cw-ladder-row" },
        money(point.unit),
        h("span", { class: "cw-ladder-bar", style: `width:${Math.max(2, Math.round((110 * point.units) / most))}px` }),
        h("span", null, number(point.units)),
      ),
    );
    const last = points[points.length - 1];
    if (points.length > shown.length && last) {
      ladder.push(h("div", { class: "cw-stat muted" }, h("span", null, `and ${number(points.length - shown.length)} more prices, up to `, money(last.unit))));
    }
    const age = Math.max(0, Math.round((ctx.asOf - ctx.market.meta.time) / 60));
    return [
      h("div", { class: "cw-stat-head" }, "What the scans show"),
      ...facts,
      h("div", { class: "cw-stat-head cw-stat-split" }, h("span", null, "For sale now"), h("span", { class: "cw-stat-count" }, `${number(item.units)} in all`)),
      h("div", { class: "cw-stat muted" }, `from the scan, ${age < 60 ? `${age}m` : `${Math.floor(age / 60)}h ${age % 60}m`} ago`),
      ...ladder,
    ];
  }

  function renderOrder(): void {
    clear(order);
    const item = selected;
    if (!item) {
      order.append(h("div", { class: "cw-hint" }, "Pick an item to see what buying it takes."));
      return;
    }
    // For a single item, the auction at the price picked in the list when one
    // was picked, else from the cheapest up.
    const byPrice = pickedUnit !== null && !fillOrder(item, 1).byUnit ? fillAt(item, pickedUnit) : null;
    const filled = byPrice ?? fillOrder(item, wanted);
    const budget = ctx.budget();
    const overBudget = budget > 0 && filled.cost > budget;
    const dealSignal = deal(item, filled.units, filled.cost);

    const lines = h("div", { class: "cw-lines" });
    for (const line of filled.lines.slice(0, 8)) {
      lines.append(
        h(
          "div",
          { class: "cw-line" },
          h("span", null, filled.byUnit ? `${number(line.units)} units` : `${number(line.auctions)} x stack of ${number(line.tier.stack)}`),
          h("span", null, money(line.tier.unit), " each"),
        ),
      );
    }
    if (filled.lines.length > 8) lines.append(h("div", { class: "muted small" }, `and ${filled.lines.length - 8} more price points`));

    order.append(
      h("div", { class: "cw-order-head" }, icon(item.icon, 32), h("div", null, itemName(item.name, item.quality, ""), h("div", { class: "muted small" }, `${number(item.units)} for sale, at all prices`))),
      h(
        "div",
        { class: "cw-quantity" },
        h("span", { class: "muted" }, "Quantity"),
        h("button", { class: "cw-step", onclick: () => setWanted(wanted - 1) }, "-"),
        h("input", {
          type: "number",
          class: "input cw-quantity-input",
          value: String(wanted),
          oninput: (event: Event) => setWanted(Number((event.target as HTMLInputElement).value) || 1, false),
        }),
        h("button", { class: "cw-step", onclick: () => setWanted(wanted + 1) }, "+"),
        h("button", { class: "cw-step cw-step-wide", onclick: () => setWanted(item.units) }, "All"),
      ),
      h("div", { class: "cw-total" }, h("span", null, "Total"), money(filled.cost)),
      h("div", { class: "cw-row" }, h("span", { class: "muted" }, "Average each"), money(filled.averageUnit)),
      ...dealRows(dealSignal),
      filled.units !== wanted && filled.short === 0
        ? h("div", { class: "cw-note" }, `You get ${number(filled.units)}: stacks cannot be split.`)
        : "",
      filled.short > 0 ? h("div", { class: "cw-note bad" }, `Only ${number(filled.units)} are for sale.`) : "",
      overBudget ? h("div", { class: "cw-note bad" }, "More than your gold.") : "",
      lines,
      h(
        "button",
        { class: "cw-action", disabled: overBudget || filled.units === 0 },
        filled.byUnit || !filled.lines[0] ? `Buy ${number(filled.units)}` : `Buy at ${moneyText(filled.lines[0].tier.unit)}`,
      ),
      h(
        "div",
        { class: "cw-note" },
        filled.byUnit
          ? "Bought by the unit: one purchase, cheapest sellers first."
          : filled.purchases === 1
            ? "One auction, one purchase."
            : `${number(filled.purchases)} auctions. The game sells one per press, so this is ${number(filled.purchases)} purchases.`,
      ),
      ...statsRows(item),
    );
  }

  // The deal: a meter and what the order saves. With too few auctions to know
  // the usual price there is no meter to show, only a note saying so.
  function dealRows(reading: ReturnType<typeof deal>): (HTMLElement | string)[] {
    if (!reading.known || reading.saving === null) {
      return [h("div", { class: "cw-note" }, reading.reasons[0] ?? "")];
    }
    const saving = reading.saving;
    return [
      h("div", { class: "cw-row" }, h("span", { class: "muted" }, "Deal"), meter(reading, { compact: true })),
      h(
        "div",
        { class: "cw-row" },
        h("span", { class: "muted" }, saving >= 0 ? "You save" : "You pay extra"),
        h("span", { class: saving >= 0 ? "good" : "bad" }, money(Math.abs(saving))),
      ),
      h("div", { class: "cw-note" }, reading.reasons[0] ?? ""),
    ];
  }

  function setWanted(value: number, redrawInput = true): void {
    wanted = Math.max(1, Math.floor(value));
    pickedUnit = null; // a typed quantity is no longer "up to this price"
    if (redrawInput) {
      renderOrder();
      return;
    }
    // Typing in the box: redraw everything but keep the caret where it is.
    const active = document.activeElement;
    renderOrder();
    if (active instanceof HTMLInputElement) {
      const input = order.querySelector<HTMLInputElement>(".cw-quantity-input");
      input?.focus();
    }
  }

  renderRail();
  renderSidebar();
  renderToolbar();
  renderList();
  renderOrder();

  return {
    element,
    update: () => {
      facetOptions = buildFacetOptions();
      renderRail();
      renderSidebar();
      renderList();
      renderOrder();
    },
  };
}

// Concept, Sell tab: your bags on the left, a price already filled in from a
// rule, and the competition on the right with your auctions slotted in.
//
// An item can sit in several bag slots (three stacks of leather). Picking any
// of them picks the item, and the form works from the total across all of
// them: how big each auction is, and how many auctions to post.
import { ASSUMPTIONS } from "../../config/catalog";
import {
  DEFAULT_DURATION,
  DEFAULT_PRICE_RULE,
  DURATIONS,
  PRETEND_BAG,
  SALE_TYPES,
  STARTING_BID_SHARE,
  type SaleTypeId,
} from "../../config/concept";
import { PRICE_RULES } from "../../config/price-rules";
import type { MarketItem } from "../../model/market";
import { confidenceLine, priceConfidence } from "../../model/signals";
import type { LabContext } from "../context";
import { clear, h, icon, itemName, money, moneyInput, number } from "../dom";
import { meterRow } from "../meter";

const LADDER_ROWS = 9;

interface BagSlot {
  item: MarketItem;
  count: number;
}

function isStackable(item: MarketItem): boolean {
  return item.units > item.listings; // someone is selling it more than one at a time
}

// The lab cannot see real bags, so fill a pretend one with the scan's
// most-listed items. One stackable item is spread over several slots, the way
// a few stacks of leather would be.
function pretendBag(items: MarketItem[]): BagSlot[] {
  const candidates = items.filter((item) => item.name !== null && item.min !== null);
  const byListings = [...candidates].sort((a, b) => b.listings - a.listings);
  const split = byListings.find((item) => isStackable(item) && item.name?.includes(PRETEND_BAG.splitItemNamed));

  const slots: BagSlot[] = [];
  if (split) {
    for (const count of PRETEND_BAG.splitStacks) slots.push({ item: split, count });
  }
  for (const item of byListings) {
    if (slots.length >= PRETEND_BAG.slots) break;
    if (item === split) continue;
    slots.push({ item, count: isStackable(item) ? PRETEND_BAG.stackSize : 1 });
  }
  return slots;
}

function confidenceRow(item: MarketItem): HTMLElement {
  const confidence = priceConfidence(item);
  return meterRow("Price confidence", confidence, confidenceLine(confidence));
}

export function createSellTab(ctx: LabContext): { element: HTMLElement; update: () => void } {
  let bag = pretendBag(ctx.market.items);
  let item: MarketItem | null = null;
  let ruleId = DEFAULT_PRICE_RULE;
  let perAuction = 1; // units in each auction
  let auctions = 1; // how many auctions to post
  let duration = DEFAULT_DURATION;
  let customUnit: number | null = null; // set when the player types a price
  let saleType: SaleTypeId = "buyout";
  let customBid: number | null = null; // starting bid each, when the player types one

  const bags = h("div", { class: "cw-bags" });
  const form = h("div", { class: "cw-form" });
  const ladder = h("div", { class: "cw-competition" });
  const element = h("div", { class: "cw-sell" }, bags, form, ladder);

  // Everything the bag holds of the chosen item, across all its slots.
  function owned(): { total: number; stacks: number } {
    const slots = bag.filter((slot) => slot.item === item);
    return { total: slots.reduce((sum, slot) => sum + slot.count, 0), stacks: slots.length };
  }

  function choose(next: MarketItem): void {
    item = next;
    customUnit = null;
    customBid = null;
    // Start by offering everything, in auctions the size of a bag stack.
    const { total } = owned();
    perAuction = Math.max(1, Math.min(total, PRETEND_BAG.stackSize));
    auctions = Math.max(1, Math.floor(total / perAuction));
    render();
  }

  function renderBags(): void {
    clear(bags);
    bags.append(h("div", { class: "cw-label" }, "Your bags (pretend)"));
    const grid = h("div", { class: "cw-bag-grid" });
    for (const slot of bag) {
      grid.append(
        h(
          "button",
          {
            class: `cw-bag-slot ${slot.item === item ? "active" : ""}`,
            title: slot.item.name ?? "",
            onclick: () => choose(slot.item),
          },
          icon(slot.item.icon, 36),
          slot.count > 1 ? h("span", { class: "cw-bag-count" }, String(slot.count)) : "",
        ),
      );
    }
    bags.append(grid);
  }

  function unitPrice(): number | null {
    if (!item) return null;
    if (customUnit !== null) return customUnit;
    const rule = PRICE_RULES.find((candidate) => candidate.id === ruleId) ?? PRICE_RULES[0];
    return rule ? rule.price(item) : null;
  }

  function sale(): (typeof SALE_TYPES)[number] {
    return SALE_TYPES.find((type) => type.id === saleType) ?? SALE_TYPES[0];
  }

  // The starting bid per unit, for the sale type that has both prices.
  function startingBid(): number | null {
    if (customBid !== null) return customBid;
    const unit = unitPrice();
    return unit === null ? null : Math.max(1, Math.floor(unit * STARTING_BID_SHARE));
  }

  function chips<T>(
    options: T[],
    label: (option: T) => string,
    isActive: (option: T) => boolean,
    pick: (option: T) => void,
    tip?: (option: T) => string,
  ): HTMLElement {
    const row = h("div", { class: "cw-chips" });
    for (const option of options) {
      row.append(
        h(
          "button",
          {
            class: `cw-toggle ${isActive(option) ? "active" : ""} ${tip ? "cw-tipped" : ""}`,
            "data-tip": tip?.(option),
            onclick: () => pick(option),
          },
          label(option),
        ),
      );
    }
    return row;
  }

  function slider(value: number, max: number, onInput: (value: number) => void): HTMLElement {
    return h("input", {
      type: "range",
      class: "cw-slider",
      min: "1",
      max: String(Math.max(1, max)),
      value: String(value),
      disabled: max <= 1,
      oninput: (event: Event) => onInput(Number((event.target as HTMLInputElement).value)),
    });
  }

  function renderForm(): void {
    clear(form);
    if (!item) {
      form.append(h("div", { class: "cw-hint" }, "Pick something from your bags."));
      return;
    }
    const chosen = item;
    const { total, stacks } = owned();
    const unit = unitPrice();

    form.append(
      h(
        "div",
        { class: "cw-order-head" },
        icon(chosen.icon, 40),
        h(
          "div",
          { class: "cw-grow" },
          itemName(chosen.name, chosen.quality, ""),
          h("div", { class: "muted small" }, stacks > 1 ? `You have ${number(total)} in ${stacks} stacks` : `You have ${number(total)}`),
        ),
      ),
      h(
        "div",
        { class: "cw-slider-row" },
        h("span", { class: "cw-slider-name" }, "Sale"),
        chips(
          [...SALE_TYPES],
          (type) => type.label,
          (type) => type.id === saleType,
          (type) => {
            saleType = type.id;
            render();
          },
          (type) => type.note,
        ),
      ),
      h("div", { class: "cw-label" }, sale().buyout ? "Price each" : "Starting bid each"),
      // Three boxes, like the game: gold, silver, copper. They start on the
      // rule's price, and typing in any of them makes the price your own.
      moneyInput(unit, (copper) => {
        customUnit = Math.max(1, copper);
        render();
      }),
      chips(
        PRICE_RULES,
        (rule) => rule.label,
        (rule) => customUnit === null && rule.id === ruleId,
        (rule) => {
          ruleId = rule.id;
          customUnit = null;
          render();
        },
        (rule) => rule.note,
      ),
      // With both a buy now price and bids, the starting bid gets its own entry.
      sale().buyout && sale().bids
        ? h(
            "div",
            { class: "cw-slider-row" },
            h("span", { class: "cw-slider-name" }, "Starting bid"),
            moneyInput(
              startingBid(),
              (copper) => {
                customBid = Math.max(1, copper);
                render();
              },
              { compact: true },
            ),
            h("span", { class: "muted small" }, "each"),
          )
        : "",
      confidenceRow(chosen),
    );

    // How many: the size of each auction, then how many of them.
    if (total > 1) {
      form.append(
        h(
          "div",
          { class: "cw-slider-row" },
          h("span", { class: "cw-slider-name" }, "Each auction"),
          slider(perAuction, total, (value) => {
            perAuction = value;
            auctions = Math.min(auctions, Math.max(1, Math.floor(total / perAuction)));
            renderForm();
            renderLadder();
          }),
          h("span", { class: "cw-slider-value" }, `${number(perAuction)} units`),
        ),
        h(
          "div",
          { class: "cw-slider-row" },
          h("span", { class: "cw-slider-name" }, "Auctions"),
          slider(auctions, Math.floor(total / perAuction), (value) => {
            auctions = value;
            renderSummary();
            renderLadder();
          }),
          h("span", { class: "cw-slider-value cw-auction-count" }, ""),
        ),
      );
    }

    form.append(
      h(
        "div",
        { class: "cw-slider-row" },
        h("span", { class: "cw-slider-name" }, "Duration"),
        chips(
          DURATIONS,
          (option) => option.label,
          (option) => option.index === duration,
          (option) => {
            duration = option.index;
            renderForm();
          },
          (option) => option.note,
        ),
      ),
      h("div", { class: "cw-summary" }),
      h("button", { class: "cw-action", disabled: unit === null }, "Post"),
    );
    renderSummary();
  }

  // The numbers under the form. Redrawn alone while a slider moves.
  function renderSummary(): void {
    const summary = form.querySelector(".cw-summary");
    if (!summary || !item) return;
    const { total } = owned();
    const posting = perAuction * auctions;
    const count = form.querySelector(".cw-auction-count");
    if (count) count.textContent = `${number(auctions)} of ${number(Math.floor(total / perAuction))}`;
    const button = form.querySelector(".cw-action");
    if (button) button.textContent = auctions > 1 ? `Post ${number(auctions)} auctions` : "Post auction";
    const type = sale();
    const bid = startingBid();

    const unit = unitPrice();
    clear(summary);
    if (unit === null) {
      summary.append(h("div", { class: "cw-note" }, "Nobody is selling this, so there is no price to go by. Type one."));
      return;
    }
    const each = unit * perAuction;
    const all = each * auctions;
    summary.append(
      h(
        "div",
        { class: "cw-row" },
        h("span", { class: "muted" }, `Posting ${number(posting)} of ${number(total)}${posting < total ? `, keeping ${number(total - posting)}` : ""}`),
        auctions > 1 ? h("span", { class: "muted" }, "each auction ", money(each)) : "",
      ),
      h(
        "div",
        { class: "cw-total" },
        h("span", null, type.buyout ? (auctions > 1 ? "All buyouts" : "Buyout") : auctions > 1 ? "All starting bids" : "Starting bid"),
        money(all),
      ),
      type.buyout && type.bids && bid !== null && bid >= unit
        ? h("div", { class: "cw-note bad" }, "The starting bid has to be under the buy now price.")
        : "",
      h(
        "div",
        { class: "cw-row" },
        // The cut is named in the label, so no separate footnote is needed.
        h(
          "span",
          { class: "muted", title: "Assumes the auction house keeps this share. The deposit is not included." },
          `${type.buyout ? "You receive if all sell" : "You receive at least"}, after the ${ASSUMPTIONS.auctionCut * 100}% cut`,
        ),
        money(Math.floor(all * (1 - ASSUMPTIONS.auctionCut))),
      ),
    );
  }

  function renderLadder(): void {
    clear(ladder);
    ladder.append(h("div", { class: "cw-label" }, "The competition"));
    if (!item) return;
    const unit = unitPrice();
    const rows = h("div", { class: "cw-ladder" });
    let placed = unit === null;
    let shown = 0;
    let unitsAhead = 0;
    const you = (): HTMLElement =>
      h("div", { class: "cw-ladder-row you" }, h("span", null, `You: ${number(auctions)} x ${number(perAuction)}`), money(unit));

    for (const tier of item.tiers) {
      if (!placed && unit !== null && tier.unit >= unit) {
        rows.append(you());
        placed = true;
      }
      if (!placed) unitsAhead += tier.units;
      if (shown < LADDER_ROWS) {
        rows.append(h("div", { class: "cw-ladder-row" }, h("span", null, `${number(tier.copies)} x ${number(tier.stack)}`), money(tier.unit)));
        shown++;
      }
    }
    if (!placed) rows.append(you());
    ladder.append(
      h("div", { class: "muted small" }, "auctions x units each"),
      rows,
      h("div", { class: "cw-note" }, unitsAhead === 0 ? "You would be the cheapest." : `${number(unitsAhead)} units sell before yours.`),
      h("div", { class: "muted small" }, `${number(item.listings)} auctions, usual price `, money(item.median)),
    );
  }

  function render(): void {
    renderBags();
    renderForm();
    renderLadder();
  }

  function start(): void {
    const first = bag[0]?.item;
    if (first) choose(first);
    else {
      item = null;
      render();
    }
  }

  start();
  return {
    element,
    update: () => {
      bag = pretendBag(ctx.market.items);
      start();
    },
  };
}

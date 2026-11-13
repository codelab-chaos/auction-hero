// Concept: a mock of the in-game window at its real size, with Buy and Sell
// tabs running on the scan. Nothing here uses data the addon could not get in game.
import { CONCEPT_TABS, WINDOW } from "../../config/concept";
import { createBuyTab } from "../concept/buy";
import { createHistoryTab } from "../concept/history";
import { createResellTab } from "../concept/resell";
import { createSellTab } from "../concept/sell";
import { remember, store, type LabContext, type Screen } from "../context";
import { clear, h, money } from "../dom";

type Tab = { element: HTMLElement; update: () => void };

const TAB_BUILDERS: Record<string, (ctx: LabContext) => Tab> = {
  buy: createBuyTab,
  sell: createSellTab,
  resell: createResellTab,
  history: createHistoryTab,
};

export function createConceptScreen(ctx: LabContext): Screen {
  let active = remember("concept-tab", { id: CONCEPT_TABS[0]?.id ?? "" }).id;
  const built = new Map<string, Tab>();

  const tabs = h("div", { class: "cw-tabs" });
  const body = h("div", { class: "cw-body" });
  const gold = h("span", { class: "cw-gold" });
  const frame = h(
    "div",
    { class: "cw-window", style: `width:${WINDOW.width}px;height:${WINDOW.height}px` },
    h("div", { class: "cw-title" }, h("span", null, "AuctioNitro"), gold),
    tabs,
    body,
  );
  const element = h(
    "section",
    { class: "screen" },
    h(
      "div",
      { class: "hint concept-hint" },
      `A mock of the in-game window at ${WINDOW.width} by ${WINDOW.height}, the room the real auction house gives us. Buttons do nothing; the numbers are real.`,
    ),
    frame,
  );

  function tab(id: string): Tab | undefined {
    let existing = built.get(id);
    const builder = TAB_BUILDERS[id];
    if (!existing && builder) {
      existing = builder(ctx);
      built.set(id, existing);
    }
    return existing;
  }

  function renderGold(): void {
    clear(gold);
    if (ctx.budget() > 0) gold.append("Your gold ", money(ctx.budget()));
  }

  function show(id: string): void {
    const next = tab(id) ?? tab(CONCEPT_TABS[0]?.id ?? "");
    if (!next) return;
    active = id;
    store("concept-tab", { id });
    clear(tabs);
    for (const entry of CONCEPT_TABS) {
      tabs.append(h("button", { class: `cw-tab ${entry.id === active ? "active" : ""}`, onclick: () => show(entry.id) }, entry.label));
    }
    clear(body);
    body.append(next.element);
  }

  renderGold();
  show(active);

  return {
    element,
    update: () => {
      renderGold();
      built.get(active)?.update();
    },
  };
}

// The shell: header, scan picker, tabs, the active screen and the detail panel.
import { POST_SCREEN_ID, SCREENS } from "../config/screens";
import { loadScan } from "../data/load";
import type { ScanSummary } from "../data/types";
import { buildMarket, type Market } from "../model/market";
import { remember, store, type LabContext, type Screen, type Settings } from "./context";
import { clear, field, h, moneyInput, number, select } from "./dom";
import { renderItemDetail } from "./item-detail";

const COPPER_PER_GOLD = 10000;

function scanLabel(scan: ScanSummary): string {
  const when = new Date(scan.time * 1000).toLocaleString();
  return `${when}  (${scan.rows.toLocaleString("en-US")} auctions)`;
}

export async function mountApp(root: HTMLElement, scans: ScanSummary[]): Promise<void> {
  const settings: Settings = remember("settings", { gold: null });
  let activeScreen = remember("screen", { id: SCREENS[0]?.id ?? "" }).id;
  let openKey: string | null = null;
  let market: Market;
  const built = new Map<string, Screen>();

  const tabs = h("nav", { class: "tabs" });
  const main = h("main", { class: "main" });
  const detail = h("aside", { class: "detail" });
  const summary = h("div", { class: "summary muted" });

  const ctx: LabContext = {
    get market() {
      return market;
    },
    settings,
    budget: () => Math.max(0, (settings.gold ?? 0) * COPPER_PER_GOLD),
    openItem: (key) => {
      openKey = key;
      renderDetail();
    },
    postItem: (key) => {
      openKey = null; // the Post screen needs the room
      renderDetail();
      showScreen(POST_SCREEN_ID);
      screen(POST_SCREEN_ID)?.select?.(key);
    },
  };

  function renderDetail(): void {
    const item = openKey ? (market.byKey.get(openKey) ?? null) : null;
    renderItemDetail(detail, item, ctx, () => {
      openKey = null;
      renderDetail();
    });
  }

  // Screens are built the first time they are shown, then kept.
  function screen(id: string): Screen | undefined {
    let existing = built.get(id);
    if (!existing) {
      const definition = SCREENS.find((candidate) => candidate.id === id);
      if (!definition) return undefined;
      existing = definition.create(ctx);
      built.set(id, existing);
    }
    return existing;
  }

  function renderTabs(): void {
    clear(tabs);
    for (const definition of SCREENS) {
      tabs.append(
        h(
          "button",
          {
            class: `tab ${definition.id === activeScreen ? "active" : ""}`,
            title: definition.blurb,
            onclick: () => showScreen(definition.id),
          },
          definition.label,
        ),
      );
    }
  }

  function showScreen(id: string): void {
    const next = screen(id) ?? screen(SCREENS[0]?.id ?? "");
    if (!next) return;
    activeScreen = id;
    store("screen", { id });
    renderTabs();
    clear(main);
    main.append(next.element);
  }

  async function useScan(file: string): Promise<void> {
    summary.textContent = "Loading scan...";
    market = buildMarket(await loadScan(file));
    const meta = market.meta;
    const named = market.items.filter((item) => item.name !== null).length;
    summary.textContent =
      `${meta.place}. ${number(named)} items, ${number(meta.rows)} auctions` +
      (meta.incompleteRows > 0 ? `, ${number(meta.incompleteRows)} of them never got their item data.` : ".");
    // A new market invalidates every screen.
    built.clear();
    openKey = null;
    renderDetail();
    showScreen(activeScreen);
  }

  const first = scans[0];
  if (!first) return;

  root.append(
    h(
      "header",
      { class: "header" },
      h("div", { class: "brand" }, h("span", { class: "brand-name" }, "Nitro Lab"), summary),
      h(
        "div",
        { class: "header-controls" },
        field(
          "Scan",
          select(
            scans.map((scan) => ({ value: scan.file, label: scanLabel(scan) })),
            first.file,
            (file) => void useScan(file),
          ),
        ),
        field(
          "My gold",
          moneyInput(ctx.budget(), (copper) => {
            settings.gold = copper / COPPER_PER_GOLD;
            store("settings", settings);
            built.get(activeScreen)?.update();
            renderDetail();
          }),
        ),
      ),
    ),
    tabs,
    h("div", { class: "layout" }, main, detail),
  );

  await useScan(first.file);
}

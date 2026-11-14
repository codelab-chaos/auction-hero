// The shell: aggregate archive, header, tabs and the detail panel.
import { SCREENS } from "../config/screens";
import { loadNews, loadScan } from "../data/load";
import type { NewsFile, ScanSummary } from "../data/types";
import { buildMarket, type Market } from "../model/market";
import { aggregateMarket, uniqueMarkets } from "../model/history";
import { buildFlows, type Flows } from "../model/flow";
import { matchNews, type NewsIndex } from "../model/news";
import { nameUnresolved } from "../model/resolve";
import { marketAtTime } from "../model/timeline";
import { remember, store, type LabContext, type Screen, type Settings } from "./context";
import { checkbox, clear, h, moneyInput, number, select } from "./dom";
import { renderItemDetail } from "./item-detail";

const COPPER_PER_GOLD = 10000;

function localDateTime(seconds: number): string {
  const date = new Date(seconds * 1000);
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}

export async function mountApp(root: HTMLElement, scans: ScanSummary[]): Promise<void> {
  const loading = h("div", { class: "welcome", role: "status" }, "Loading all imported scans…");
  root.append(loading);
  let markets: Market[];
  let market: Market;
  let newsFile: NewsFile;
  try {
    const files = [...new Set(scans.map((scan) => scan.file))];
    const [loaded, news] = await Promise.all([
      Promise.all(files.map(async (file) => buildMarket(await loadScan(file)))),
      loadNews(),
    ]);
    markets = nameUnresolved(uniqueMarkets(loaded));
    newsFile = news;
    market = aggregateMarket(markets);
  } catch (error) {
    loading.replaceChildren(h("p", null, `Could not load the scan archive: ${error instanceof Error ? error.message : String(error)}`),
      h("button", { class: "button", onclick: () => { loading.remove(); void mountApp(root, scans); } }, "Retry"));
    return;
  }
  loading.remove();
  const settings: Settings = remember("settings", { gold: null });
  let activeScreen = remember("screen", { id: SCREENS[0]?.id ?? "" }).id;
  let openKey: string | null = null;
  const built = new Map<string, Screen>();

  const tabs = h("nav", { class: "tabs" });
  const main = h("main", { class: "main" });
  const detail = h("aside", { class: "detail" });
  const summary = h("div", { class: "summary muted" });
  const timeNote = h("div", { class: "timeline-note", role: "status", "aria-live": "polite" });
  const menuToggle = h("summary", { class: "context-toggle" }, "Data");
  const contextMenu = h("details", { class: "context-menu" }, menuToggle);
  let followingNow = true;
  let selectedDate = "now";
  let asOf = Math.floor(Date.now() / 1000);
  let useAssumedBands = true;
  let view = marketAtTime(markets, asOf, useAssumedBands);
  // Worked out when first asked for, and again after the view changes.
  let flows: Flows | null = null;
  let news: NewsIndex | null = null;
  const viewingDate = h("input", { type: "datetime-local", class: "input", value: localDateTime(asOf),
    onchange: () => {
      const value = new Date(viewingDate.value).getTime() / 1000;
      if (!Number.isFinite(value)) { viewingDate.value = localDateTime(asOf); return; }
      followingNow = false;
      asOf = value;
      refreshTime();
    } });
  const scanDates = [...new Set(markets.map((scan) => scan.meta.time))].sort((a, b) => b - a);
  const dateSelect = select([
    { value: "now", label: "Now" },
    ...scanDates.map((time) => ({ value: String(time), label: new Date(time * 1000).toLocaleString() })),
    { value: "custom", label: "Custom date…" },
  ], selectedDate, (value) => {
    selectedDate = value;
    followingNow = value === "now";
    if (followingNow) asOf = Math.floor(Date.now() / 1000);
    else if (value !== "custom") asOf = Number(value);
    refreshTime();
    if (value === "custom") viewingDate.focus();
  });
  dateSelect.setAttribute("aria-label", "Viewing date: now, scan date or custom date");

  const ctx: LabContext = {
    get markets() { return view.markets; },
    get asOf() { return asOf; },
    get useAssumedExpiryBands() { return useAssumedBands; },
    get market() {
      return market;
    },
    settings,
    budget: () => Math.max(0, (settings.gold ?? 0) * COPPER_PER_GOLD),
    flows: () => (flows ??= buildFlows(view.markets, useAssumedBands)),
    news: () => (news ??= matchNews(newsFile.articles.filter((article) => article.time <= asOf), market.items)),
    openItem: (key) => {
      openKey = key;
      renderDetail();
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
            onclick: () => { contextMenu.open = false; showScreen(definition.id); },
          },
          definition.label,
        ),
      );
    }
  }

  function showScreen(id: string): void {
    activeScreen = SCREENS.some((screen) => screen.id === id) ? id : SCREENS[0]?.id ?? "";
    store("screen", { id });
    renderTabs();
    clear(main);
    if (!view.market) {
      main.append(h("div", { class: "empty" }, "No scan was available by this date. Choose a later date or Now."));
      return;
    }
    const next = screen(activeScreen);
    if (!next) return;
    main.append(next.element);
  }

  function refreshTime(forceRebuild = true): void {
    const previous = view;
    view = marketAtTime(markets, asOf, useAssumedBands);
    const changed = forceRebuild || previous.market?.meta.time !== view.market?.meta.time
      || previous.expiredUnits !== view.expiredUnits || previous.uncertainUnits !== view.uncertainUnits
      || previous.unknownUnits !== view.unknownUnits;
    viewingDate.value = localDateTime(asOf);
    dateSelect.value = selectedDate;
    viewingDate.style.display = selectedDate === "custom" ? "" : "none";
    if (changed) {
      flows = null;
      news = null;
      built.clear();
      openKey = null;
      clear(detail);
      detail.classList.remove("open");
    }
    if (view.market) {
      market = view.market;
      const named = market.items.filter((item) => item.name !== null).length;
      const listings = market.items.reduce((sum, item) => sum + item.listings, 0);
      summary.replaceChildren(h("div", null, market.meta.place),
        h("div", null, `${number(named)} items · ${number(listings)} listings · ${number(view.markets.length)} scans`));
      timeNote.replaceChildren(
        h("span", { title: "Availability is estimated from this scan. Later sales and new listings are unknown." },
          `Last scan: ${new Date(market.meta.time * 1000).toLocaleString()} · Estimated availability`));
    } else {
      summary.textContent = "No observations available at the viewing date.";
      timeNote.replaceChildren(h("span", null, "No scan available for this date."));
    }
    if (changed) showScreen(activeScreen);
  }

  contextMenu.append(h("div", { class: "context-panel" },
    h("details", { class: "context-advanced" }, h("summary", null, "Availability"),
      checkbox("Estimate expiry when exact timing is unavailable", useAssumedBands, (enabled) => { useAssumedBands = enabled; refreshTime(); })),
    h("div", { class: "context-data" }, summary, timeNote)));

  root.append(
    h("header", { class: "header" }, h("span", { class: "brand-name" }, "Nitro Lab"),
      h("div", { class: "titlebar-controls" },
        h("div", { class: "titlebar-field" }, dateSelect,
          h("label", null, h("span", { class: "sr-only" }, "Custom date and time"), viewingDate)),
        h("label", { class: "titlebar-field" }, h("span", { class: "sr-only" }, "My gold"),
          moneyInput(ctx.budget(), (copper) => {
            settings.gold = copper / COPPER_PER_GOLD;
            store("settings", settings);
            built.get(activeScreen)?.update();
            renderDetail();
          }, { compact: true })),
        contextMenu)),
    tabs,
    h("div", { class: "layout" }, main, detail),
  );

  refreshTime();
  const closeOutside = (event: Event): void => {
    if (event.target instanceof Node && !contextMenu.contains(event.target)) contextMenu.open = false;
  };
  const closeOnEscape = (event: KeyboardEvent): void => {
    if (event.key === "Escape" && contextMenu.open) {
      contextMenu.open = false;
      menuToggle.focus();
    }
  };
  document.addEventListener("pointerdown", closeOutside);
  document.addEventListener("keydown", closeOnEscape);
  // Keep Now current without moving a simulated viewing date.
  const clock = window.setInterval(() => {
    if (!summary.isConnected) {
      window.clearInterval(clock);
      document.removeEventListener("pointerdown", closeOutside);
      document.removeEventListener("keydown", closeOnEscape);
      return;
    }
    if (followingNow) { asOf = Math.floor(Date.now() / 1000); refreshTime(false); }
  }, 60000);
}

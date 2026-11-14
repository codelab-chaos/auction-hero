// News: fetched headlines, each with the items for sale that it names. A
// change to how an item is made, dropped or used shows up here before it
// shows up in the price.
import { remember, store, type LabContext, type Screen } from "../context";
import { checkbox, clear, h, icon, itemName, money } from "../dom";
import type { NewsMatch } from "../../model/news";

const EXCERPT_LENGTH = 260;
const ITEM_LIMIT = 24;

function excerpt(text: string): string {
  return text.length > EXCERPT_LENGTH ? `${text.slice(0, EXCERPT_LENGTH).trimEnd()}...` : text;
}

function card(match: NewsMatch, ctx: LabContext): HTMLElement {
  const { article, items } = match;
  const shown = [...items].sort((a, b) => b.value - a.value).slice(0, ITEM_LIMIT);
  return h(
    "article",
    { class: "news-card" },
    h("div", { class: "news-meta" }, `${new Date(article.time * 1000).toLocaleString()} · ${article.source}`),
    h("a", { class: "news-title", href: article.link, target: "_blank", rel: "noreferrer" }, article.title),
    h("p", { class: "news-text" }, excerpt(article.text)),
    shown.length > 0 &&
      h(
        "div",
        { class: "news-items" },
        ...shown.map((item) =>
          h(
            "button",
            { class: "news-item", title: "Open this item", onclick: () => ctx.openItem(item.key) },
            icon(item.icon, 16),
            itemName(item.name, item.quality, ""),
            item.min !== null && money(item.min),
          ),
        ),
        items.length > shown.length && h("span", { class: "muted" }, `and ${items.length - shown.length} more`),
      ),
  );
}

export function createNewsScreen(ctx: LabContext): Screen {
  let onlyItems = remember("news-filter", { on: false }).on;
  const controls = h("div", { class: "controls" });
  const results = h("div", { class: "news-list" });
  const element = h("section", { class: "screen" }, controls, results);

  function update(): void {
    store("news-filter", { on: onlyItems });
    const matches = ctx.news().matches.filter((match) => !onlyItems || match.items.length > 0);
    clear(results);
    if (matches.length === 0) {
      results.append(h("div", { class: "empty" }, ctx.news().matches.length === 0
        ? "No news fetched yet. In the lab folder, run: npm run news"
        : "No article names an item that is for sale."));
      return;
    }
    for (const match of matches) results.append(card(match, ctx));
  }

  controls.append(
    h("div", { class: "checks" }, checkbox("Only articles that name an item for sale", onlyItems, (value) => { onlyItems = value; update(); })),
    h("div", { class: "hint" },
      "Headlines from the feeds in scripts/lib/feeds.mjs, fetched by npm run news (also part of npm run refresh). Under each one are the items for sale that it names, with their lowest price. Items named in the last week carry a News mark on Flips and Corner."),
  );

  update();
  return { element, update };
}

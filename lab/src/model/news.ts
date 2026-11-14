// News: finds the items an article names. A patch note about an item is often
// the first sign its price is about to move.
import { NEWS_RULE } from "../config/banker.ts";
import type { NewsArticle } from "../data/types";
import type { MarketItem } from "./market";

export interface NewsMatch {
  article: NewsArticle;
  items: MarketItem[]; // items for sale that the article names
}

export interface NewsIndex {
  matches: NewsMatch[]; // newest first, every article
  byKey: Map<string, NewsArticle[]>; // item key -> articles naming it
}

const LETTER = /[a-z0-9]/;

// True when `name` appears in `text` as whole words. Both are lower case.
function names(text: string, name: string): boolean {
  for (let at = text.indexOf(name); at !== -1; at = text.indexOf(name, at + 1)) {
    const before = text[at - 1] ?? " ";
    const after = text[at + name.length] ?? " ";
    if (!LETTER.test(before) && !LETTER.test(after)) return true;
  }
  return false;
}

export function matchNews(articles: NewsArticle[], items: MarketItem[]): NewsIndex {
  const candidates = items
    .filter((item) => item.name !== null && item.name.length >= NEWS_RULE.minNameLength)
    .map((item) => ({ item, name: (item.name as string).toLowerCase() }));
  const byKey = new Map<string, NewsArticle[]>();
  const matches = [...articles]
    .sort((a, b) => b.time - a.time)
    .map((article) => {
      const text = `${article.title} ${article.text}`.toLowerCase();
      const found = candidates.filter((candidate) => names(text, candidate.name)).map((candidate) => candidate.item);
      for (const item of found) byKey.set(item.key, [...(byKey.get(item.key) ?? []), article]);
      return { article, items: found };
    });
  return { matches, byKey };
}

// The articles naming an item that are recent enough to matter, as of a time.
export function recentNews(index: NewsIndex, key: string, asOf: number): NewsArticle[] {
  const since = asOf - NEWS_RULE.recentDays * 86400;
  return (index.byKey.get(key) ?? []).filter((article) => article.time >= since && article.time <= asOf);
}

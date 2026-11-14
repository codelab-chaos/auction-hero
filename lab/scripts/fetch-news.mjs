// Fetches the news feeds in scripts/lib/feeds.mjs into public/data/news.json,
// as plain text the lab can search for item names. Articles already saved are
// kept, so the file builds up a history. A feed that fails is skipped: news is
// a nice-to-have and never blocks a refresh.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { FEEDS, KEEP_DAYS } from "./lib/feeds.mjs";
import { DATA_DIR } from "./lib/paths.mjs";

const NEWS_FILE = join(DATA_DIR, "news.json");
const HEADERS = { "User-Agent": "Mozilla/5.0 (compatible; feed-reader)" };
const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };

function decode(text) {
  return text
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&(\w+);/g, (whole, name) => ENTITIES[name] ?? whole);
}

// Markup to readable text: tags become spaces, entities become characters.
export function plain(markup) {
  const unwrapped = markup.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
  return decode(decode(unwrapped).replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ").trim();
}

function tag(block, name) {
  const match = block.match(new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`));
  return match ? match[1] : "";
}

export function parseFeed(xml, feed) {
  const articles = [];
  for (const [, block] of xml.matchAll(/<item>([\s\S]*?)<\/item>/g)) {
    const link = plain(tag(block, "link"));
    const title = plain(tag(block, "title"));
    if (!link || !title) continue;
    const time = Math.floor(Date.parse(plain(tag(block, "pubDate"))) / 1000);
    const text = plain(tag(block, "content:encoded") || tag(block, "description")).replace(/Continue reading »\s*$/, "").trim();
    articles.push({ source: feed.label, title, link, time: Number.isFinite(time) ? time : 0, text });
  }
  return articles;
}

async function main() {
  const saved = existsSync(NEWS_FILE) ? JSON.parse(readFileSync(NEWS_FILE, "utf8")).articles ?? [] : [];
  const byLink = new Map(saved.map((article) => [article.link, article]));
  for (const feed of FEEDS) {
    try {
      const response = await fetch(feed.url, { headers: HEADERS });
      if (!response.ok) throw new Error(`status ${response.status}`);
      const articles = parseFeed(await response.text(), feed);
      for (const article of articles) byLink.set(article.link, article);
      console.log(`${feed.label}: ${articles.length} articles`);
    } catch (error) {
      console.warn(`${feed.label}: skipped (${error instanceof Error ? error.message : error})`);
    }
  }
  const now = Math.floor(Date.now() / 1000);
  const articles = [...byLink.values()]
    .filter((article) => article.time >= now - KEEP_DAYS * 86400)
    .sort((a, b) => b.time - a.time);
  mkdirSync(DATA_DIR, { recursive: true });
  writeFileSync(NEWS_FILE, JSON.stringify({ fetched: now, articles }));
  console.log(`News: ${articles.length} articles saved`);
}

if (import.meta.url === `file://${process.argv[1]}`) await main();

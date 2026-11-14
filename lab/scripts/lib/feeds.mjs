// News feeds the lab reads, as data. Add an RSS feed here and `npm run news`
// picks it up. Each fetch sends only the feed's address, nothing about you.
export const FEEDS = [
  { id: "wowhead-forever", label: "Wowhead", url: "https://www.wowhead.com/news/rss/forever" },
];

// Articles older than this are dropped from the saved file.
export const KEEP_DAYS = 60;

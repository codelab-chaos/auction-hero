import assert from "node:assert/strict";
import { test } from "node:test";
import { DEFAULT_CORNER_PARAMS, DEFAULT_FLIP_PARAMS } from "../src/config/banker.ts";
import { findCorners } from "../src/model/corner.ts";
import { findFlips } from "../src/model/flips.ts";
import { buildFlows, expiryShare, perDay } from "../src/model/flow.ts";
import { finishMarketItem } from "../src/model/market.ts";
import { marketType } from "../src/model/market-type.ts";
import { matchNews, recentNews } from "../src/model/news.ts";
import { nameUnresolved } from "../src/model/resolve.ts";

const HOUR = 3600;
const BANDS = { 1: { min: 0, max: 1800 }, 2: { min: 1800, max: 7200 }, 3: { min: 7200, max: 43200 }, 4: { min: 43200, max: 86400 } };

// tiers: [stack, buyout per auction, copies, time band]
function item(id, name, tiers, extra = {}) {
  const built = {
    key: `${id}:${name ?? "?"}`, id, name, quality: 1, icon: null,
    tiers: tiers.map(([stack, buyout, copies, timeLeft = 4]) => ({ unit: Math.floor(buyout / stack), stack, buyout, copies, units: stack * copies, timeLeft })),
    listings: 0, units: 0, bidOnly: 0, value: 0, min: null, median: null, max: null, deal: null, ...extra,
  };
  for (const tier of built.tiers) {
    built.listings += tier.copies;
    built.units += tier.units;
    built.value += tier.buyout * tier.copies;
  }
  finishMarketItem(built);
  return built;
}
function market(time, items) {
  return { meta: { time, place: "Horde", source: "replicate", elapsed: 0, timeLeftBands: BANDS }, items, byKey: new Map(items.map((entry) => [entry.key, entry])) };
}

test("expiry share spreads a band's time left evenly", () => {
  assert.equal(expiryShare(BANDS[4], 6 * HOUR), 0);
  assert.equal(expiryShare(BANDS[2], 2 * HOUR), 1);
  assert.equal(expiryShare(BANDS[3], 7 * HOUR), 0.5);
  assert.equal(expiryShare(undefined, 60), 1);
});

test("cheap long listings that vanish count as sold, dear ones do not", () => {
  const before = market(0, [item(1, "Ore", [[1, 100, 4], [1, 200, 4], [1, 900, 2]])]);
  const after = market(6 * HOUR, [item(1, "Ore", [[1, 100, 1], [1, 200, 4], [1, 500, 3]])]);
  const flows = buildFlows([before, after]);
  const flow = flows.byKey.get("1:Ore");
  assert.equal(flows.hours, 6);
  assert.equal(flow.left, 5); // three at 100 and two at 900
  assert.equal(flow.sold, 3); // the two at 900 were over the median: cancelled, not sold
  assert.equal(flow.soldPrice, 100);
  assert.equal(flow.arrived, 3);
  assert.equal(perDay(flow.sold, flows), 12);
});

test("a stack bought from a few units at a time is a sale of those units only", () => {
  const before = market(0, [item(1, "Dust", [[200, 20000, 1], [50, 5000, 1], [10, 9000, 1]])]);
  const after = market(HOUR, [item(1, "Dust", [[170, 17000, 1], [50, 5000, 1], [10, 9000, 1]])]);
  const flow = buildFlows([before, after]).byKey.get("1:Dust");
  assert.equal(flow.sold, 30);
  assert.equal(flow.arrived, 0);
  assert.equal(flow.lastSoldPrice, 100);
  assert.equal(flow.lastSoldTime, HOUR);
});

test("units that move down in price are a relist, not a sale", () => {
  const before = market(0, [item(1, "Dust", [[1, 400, 10], [1, 900, 10]])]);
  const after = market(HOUR, [item(1, "Dust", [[1, 380, 6], [1, 400, 2], [1, 900, 10]])]);
  const flow = buildFlows([before, after]).byKey.get("1:Dust");
  assert.equal(flow.left, 8);
  assert.equal(flow.relisted, 6); // six reappeared at 380
  assert.equal(flow.sold, 2);
  assert.equal(flow.arrived, 6);
});

test("listings that could have expired are not counted as sold", () => {
  const before = market(0, [item(1, "Ore", [[1, 100, 4, 2]])]);
  const after = market(3 * HOUR, [item(1, "Ore", [])]);
  const flow = buildFlows([before, after]).byKey.get("1:Ore");
  assert.equal(flow.left, 4);
  assert.equal(flow.sold, 0);
});

test("an item with nameless rows it cannot place is marked shaky and not counted", () => {
  const before = market(0, [item(1, "Blade of the Bear", [[1, 100, 2]]), item(1, null, [[1, 100, 1]])]);
  const after = market(HOUR, [item(1, "Blade of the Bear", [])]);
  const flow = buildFlows([before, after]).byKey.get("1:Blade of the Bear");
  assert.equal(flow.shaky, true);
  assert.equal(flow.sold, 0);
});

test("an item patched by a live check after the scan is left out of sales pace", () => {
  const before = market(0, [item(1, "Ore", [[1, 100, 4]])]);
  const after = market(HOUR, [item(1, "Ore", [[1, 100, 1]])]);
  after.meta.patched = [{ id: 1, time: HOUR + 600 }];
  const flow = buildFlows([before, after]).byKey.get("1:Ore");
  assert.equal(flow.shaky, true);
  assert.equal(flow.sold, 0);
});

test("nameless rows fold into the only name their id has been seen under", () => {
  const first = market(0, [item(1, "Ore", [[1, 100, 2]]), item(2, "Blade of the Bear", [[1, 500, 1]]), item(2, "Blade of the Owl", [[1, 600, 1]])]);
  const second = market(HOUR, [item(1, null, [[1, 90, 3]]), item(2, null, [[1, 700, 1]])]);
  const [same, resolved] = nameUnresolved([first, second]);
  assert.equal(same, first);
  const ore = resolved.byKey.get("1:Ore");
  assert.equal(ore.units, 3);
  assert.equal(ore.min, 90);
  assert.equal(resolved.byKey.has("1:?"), false);
  assert.equal(resolved.byKey.has("2:?"), true); // two names known: cannot tell which
  assert.equal(first.byKey.get("1:Ore").units, 2); // the other scan's record is untouched
});

function flowsFor(key, flow, hours = 24) {
  return { hours, intervals: 1, byKey: new Map([[key, { key, left: 0, sold: 0, soldValue: 0, soldPrice: null, lastSoldPrice: null, lastSoldTime: null, relisted: 0, arrived: 0, shaky: false, ...flow }]]) };
}

test("a flip buys what is under the proven price and is ranked by pace", () => {
  const ore = item(1, "Ore", [[1, 500, 2], [1, 1000, 5], [1, 1100, 5]], { usual: 1100 });
  const flows = flowsFor(ore.key, { sold: 10, soldPrice: 1000 });
  const [lead] = findFlips([ore], flows, { ...DEFAULT_FLIP_PARAMS, minProfit: 1 });
  assert.equal(lead.target, 1000); // held down from the usual 1100 to what sold
  assert.equal(lead.proven, true);
  assert.equal(lead.buyUnits, 2);
  assert.equal(lead.cost, 1000);
  assert.equal(lead.profit, 900); // 2 x 1000 less 5%, less 1000
  assert.equal(lead.daysToSell, 0.7); // 2 bought + 5 still listed at the price, 10 a day
  assert.equal(lead.profitPerDay, 900);
});

test("a flip that would take too long, or with no sales seen, is not a lead", () => {
  const ore = item(1, "Ore", [[1, 500, 2], [1, 1000, 50]], { usual: 1000 });
  assert.equal(findFlips([ore], flowsFor(ore.key, { sold: 2, soldPrice: 1000 }), { ...DEFAULT_FLIP_PARAMS, minProfit: 1 }).length, 0);
  assert.equal(findFlips([ore], flowsFor(ore.key, { sold: 0 }), { ...DEFAULT_FLIP_PARAMS, minProfit: 1 }).length, 0);
});

test("a corner buys everything under a price step and relists just under it", () => {
  const gem = item(1, "Gem", [[1, 1000, 3], [1, 1100, 2], [1, 1900, 4]], { usual: 1000 });
  const flows = flowsFor(gem.key, { sold: 10, arrived: 5 });
  // Buying all nine would cost 14s 22c each: not 50% under the 20s ceiling.
  const [lead] = findCorners([gem], flows, { ...DEFAULT_CORNER_PARAMS, minProfit: 1, minMarkupPercent: 50, maxOverUsualPercent: 200 });
  assert.equal(lead.buyUnits, 5);
  assert.equal(lead.cost, 5200);
  assert.equal(lead.wall, 1900);
  assert.equal(lead.relist, 1899);
  assert.equal(lead.share, 56);
  assert.equal(lead.profit, Math.floor(5 * 1899 * 0.95) - 5200);
  assert.equal(lead.restock, 0.5);
  assert.equal(lead.daysToSell, 0.5);
});

test("a corner never relists over the ceiling, and needs demand and slow restock", () => {
  const gem = item(1, "Gem", [[1, 1000, 3], [1, 90000, 1]], { usual: 1000 });
  const params = { ...DEFAULT_CORNER_PARAMS, minProfit: 1, maxOverUsualPercent: 200 };
  const [lead] = findCorners([gem], flowsFor(gem.key, { sold: 10, arrived: 0 }), params);
  assert.equal(lead.relist, 2000); // twice the usual price, not 1 copper under 9g
  assert.equal(findCorners([gem], flowsFor(gem.key, { sold: 10, arrived: 40 }), params).length, 0); // refills faster than it sells
  assert.equal(findCorners([gem], flowsFor(gem.key, { sold: 1, arrived: 0 }), params).length, 0); // not sought after
  assert.equal(findCorners([gem], flowsFor(gem.key, { sold: 10, arrived: 0 }), { ...params, budget: 2000 }).length, 0); // cannot afford the buyout
});

test("news matches item names as whole words and knows what is recent", () => {
  const items = [item(1, "Iron Grenade", []), item(2, "Iron", []), item(3, "Linen Bag", [])];
  const day = 86400;
  const articles = [
    { source: "Feed", title: "Vendor Price Changes: Iron Grenade Shuffle Dead", link: "a", time: 10 * day, text: "Ironforge traders note linen bags cost more." },
    { source: "Feed", title: "Old news", link: "b", time: 1 * day, text: "The Linen Bag is bigger now." },
  ];
  const index = matchNews(articles, items);
  assert.deepEqual(index.matches[0].items.map((entry) => entry.name), ["Iron Grenade"]); // "Iron" is too short, "linen bags" is not "linen bag"
  assert.deepEqual(index.matches[1].items.map((entry) => entry.name), ["Linen Bag"]);
  assert.equal(recentNews(index, "1:Iron Grenade", 11 * day).length, 1);
  assert.equal(recentNews(index, "3:Linen Bag", 11 * day).length, 0);
});

test("supply and turnover together say what kind of market an item is", () => {
  const few = item(1, "Few", [[1, 100, 3]]);
  const plenty = item(2, "Plenty", [[20, 2000, 30]], { maxStack: 20 }); // 600 units, 30 stacks
  const read = (entry, flow) => marketType(entry, flowsFor(entry.key, flow)).type;
  assert.equal(read(few, { sold: 6 }), "hot"); // 3 for sale, 6 a day
  assert.equal(read(few, { sold: 0 }), "quiet");
  assert.equal(read(few, { sold: 1 }), "quiet"); // one sale is not a pattern
  assert.equal(read(plenty, { sold: 400 }), "staple");
  assert.equal(read(plenty, { sold: 20 }), "glut");
  assert.equal(read(few, { sold: 6, shaky: true }), "unknown");
  assert.equal(marketType(few, { hours: 2, intervals: 1, byKey: new Map() }).type, "unknown"); // too little scanning to say
  assert.equal(marketType(few, { hours: 24, intervals: 2, byKey: new Map() }).type, "quiet"); // scanned, and nothing left
});

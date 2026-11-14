import assert from "node:assert/strict";
import { test } from "node:test";
import { dealConfidence } from "../src/model/deal-confidence.ts";
import { aggregateMarket } from "../src/model/history.ts";
import { buildMarket } from "../src/model/market.ts";
import { deal } from "../src/model/signals.ts";

// items: { name: [[units each auction, price each, copies], ...] }
function scan(time, items) {
  const records = Object.keys(items).map((name, index) => ({ key: `${index + 1}:${name}`, id: index + 1, name }));
  const listings = [];
  Object.values(items).forEach((rows, index) => {
    for (const [stack, unit, copies] of rows) listings.push([index, stack, unit * stack, 0, 0, 4, copies]);
  });
  return buildMarket({ meta: { time, place: "Horde", source: "replicate" }, items: records, listings });
}

// The two cases from the game on Nov 13.
const guideToday = [[1, 697, 1], [1, 896, 5], [1, 897, 13], [1, 997, 15], [1, 998, 17]];
const blueprintToday = [[1, 1200, 1], [1, 6000, 7]];

test("one stray cheap unit is measured against what the rest cost", () => {
  const market = aggregateMarket([scan(1, { "Field Guide": guideToday })]);
  const guide = market.byKey.get("1:Field Guide");
  assert.equal(guide.floor, 897);
  assert.equal(guide.baseline, 897);
  assert.equal(guide.deal, 22); // under the 30% bar for a badge
  assert.equal(guide.dealUnits, 1);
  const reading = deal(guide, 1, 697);
  assert.equal(reading.known, true);
  assert.match(reading.reasons[0], /^22% under the 8s 97c you would otherwise pay/);
  assert.match(reading.reasons[1], /Past scans cannot back it yet/);
  assert.equal(deal(guide, 6, 697 + 5 * 896).level.id, "fair"); // buying into the floor is no deal
});

test("past scans hold the baseline to the usual low, and back a real deal", () => {
  const past = [4900, 5840, 5940, 4900, 5000, 5955].map((low, index) => scan(index + 1, { Blueprint: [[1, low, 2], [1, 6000, 5]] }));
  const market = aggregateMarket([...past, scan(7, { Blueprint: blueprintToday })]);
  const blueprint = market.byKey.get("1:Blueprint");
  assert.equal(blueprint.floor, 6000);
  assert.equal(blueprint.typicalLow, 5000);
  assert.equal(blueprint.baseline, 5000);
  assert.equal(blueprint.deal, 76);
  const reading = deal(blueprint, 1, 1200);
  assert.equal(reading.level.id, "resell");
  assert.match(reading.reasons[1], /what past scans show/);
  assert.match(reading.reasons[2], /asking prices/);
});

test("asking prices that crept up do not make the old normal price a deal", () => {
  const past = [950, 1000, 1050, 1000].map((low, index) => scan(index + 1, { Crept: [[1, low, 5]] }));
  const market = aggregateMarket([...past, scan(5, { Crept: [[1, 1000, 3], [1, 2000, 9]] })]);
  const crept = market.byKey.get("1:Crept");
  assert.equal(crept.baseline, 1000);
  assert.equal(crept.deal, null);
});

test("one of a kind has nothing to be measured against", () => {
  const lone = aggregateMarket([scan(1, { Lone: [[1, 500, 1]] })]).byKey.get("1:Lone");
  assert.equal(lone.floor, null);
  assert.equal(lone.deal, null);
  assert.equal(deal(lone, 1, 500).known, false);
});

test("two listings far apart, with no past scans, earn no badge", () => {
  const pair = aggregateMarket([scan(1, { Pair: [[1, 1000, 1], [1, 9000, 1]] })]).byKey.get("1:Pair");
  assert.equal(pair.baseline, 9000);
  assert.equal(pair.deal, null);
  assert.equal(deal(pair, 1, 1000).level.id, "great"); // the meter still reads the order
});

test("when most of what is for sale is at the low price, that is the normal price", () => {
  // Forty at 6s and a few stragglers at 59s: the 59s is the odd one out.
  const item = aggregateMarket([scan(1, { Guide: [[1, 600, 40], [1, 5900, 5]] })]).byKey.get("1:Guide");
  assert.equal(item.baseline, 600);
  assert.equal(item.deal, null);
  assert.equal(deal(item, 1, 600).level.id, "fair");
  // And past scans at 59s do not change that: the baseline takes the lower of the two.
  const past = [5900, 5900, 5900].map((low, index) => scan(index + 1, { Guide: [[1, low, 5]] }));
  const now = aggregateMarket([...past, scan(4, { Guide: [[1, 600, 40], [1, 5900, 5]] })]).byKey.get("1:Guide");
  assert.equal(now.baseline, 600);
  assert.equal(now.deal, null);
});

// Deal confidence is separate from the size of the discount.
const DAY = 86400;
function flowsWith(key, sold, shaky = false) {
  return { hours: 24, intervals: 2, byKey: new Map([[key, { key, sold, shaky }]]) };
}

test("a deal on something that sells, seen over days at several prices, is trusted", () => {
  const days = [0, 1, 2, 3, 4].map((day) => scan(day * DAY + 1, { Potion: [[1, 200, 1], [1, 290, 9], [1, 300, 9], [1, 310, 9], [1, 320, 9]] }));
  const potion = aggregateMarket(days).byKey.get("1:Potion");
  const reading = dealConfidence(potion, flowsWith("1:Potion", 40));
  assert.equal(reading.score, 100);
  assert.equal(reading.level.id, "high");
});

test("a huge discount against one hopeful price, never seen selling, is not", () => {
  const item = aggregateMarket([scan(1, { Cape: [[1, 5000, 1], [1, 150000, 3]] })]).byKey.get("1:Cape");
  assert.equal(item.baseline, 150000); // a 96% "discount"
  const reading = dealConfidence(item, flowsWith("1:Cape", 0));
  assert.equal(reading.level.id, "low"); // one day, no sales, two prices
  assert.ok(reading.score < 40);
  assert.match(reading.reasons.join(" "), /one day only/);
});

test("a low price near vendor price, under listings asking many times more, is held down", () => {
  // Four days of sellers asking about 2g 90s, then one listed at 23s.
  const days = [0, 1, 2, 3].map((day) => scan(day * DAY + 1, { Belt: [[1, 28800, 3], [1, 29000, 3], [1, 30000, 3]] }));
  days.push(scan(4 * DAY + 1, { Belt: [[1, 2300, 1], [1, 28800, 3], [1, 29000, 3], [1, 30000, 3]] }));
  const belt = aggregateMarket(days).byKey.get("1:Belt");
  const withoutVendor = dealConfidence(belt, flowsWith("1:Belt", 12)).score;
  belt.vendorPrice = 1560;
  const reading = dealConfidence(belt, flowsWith("1:Belt", 12));
  assert.ok(withoutVendor >= 65);
  assert.equal(reading.score, 25);
  assert.equal(reading.facts.nearVendor, true);
});

test("an item whose sales cannot be read gets no credit for selling", () => {
  const item = aggregateMarket([0, 1, 2].map((day) => scan(day * DAY + 1, { Gear: [[1, 100, 1], [1, 900, 2], [1, 950, 2]] }))).byKey.get("1:Gear");
  const reading = dealConfidence(item, flowsWith("1:Gear", 50, true));
  assert.equal(reading.facts.sold, null);
  assert.match(reading.reasons.join(" "), /Sales cannot be read/);
  assert.ok(reading.score < 65);
});

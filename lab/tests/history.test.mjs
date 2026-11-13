import assert from "node:assert/strict";
import { test } from "node:test";
import { aggregateMarket, aggregateSales, uniqueMarkets } from "../src/model/history.ts";

function item(key, copies, price = 100, extra = {}) {
  return { id: 1, key, name: key, median: price, units: copies, listings: copies, bidOnly: 0,
    tiers: copies ? [{ stack: 1, buyout: price, copies, units: copies, unit: price, timeLeft: 4 }] : [], ...extra };
}
function market(time, items, extra = {}) {
  return { meta: { time, place: "Horde", source: "replicate", elapsed: 0, ...extra },
    items, byKey: new Map(items.map((item) => [item.key, item])) };
}

test("all scans inform price history while repeated stock is counted only in the newest snapshot", () => {
  const before = market(1, [item("Ore", 10, 100), item("Gone", 5, 20)]);
  const after = market(3601, [item("Ore", 10, 200)]);
  const result = aggregateMarket([after, before, before]);
  assert.equal(result.items.length, 1); // vanished stock never reappears via aggregation
  assert.equal(result.items[0].units, 10);
  assert.equal(result.items[0].scansSeen, 2);
  assert.equal(result.items[0].usual, 130);
  assert.equal(result.items[0].median, 200);
  assert.equal(before.items[0].scansSeen, undefined); // raw scans remain unchanged for deltas
});

test("market histories remain separate and stale snapshots do not enter the aggregate", () => {
  const horde = market(1, [item("Ore", 10, 100)]);
  const alliance = market(2, [item("Ore", 7, 900)], { place: "Alliance" });
  const stale = market(3, [item("Ore", 999, 999)], { stale: true });
  const result = aggregateMarket([horde, alliance, stale]);
  assert.equal(result.meta.place, "Alliance");
  assert.equal(result.items[0].usual, 900);
  assert.equal(result.items[0].scansSeen, 1);
  assert.equal(result.items[0].units, 7);
  assert.equal(uniqueMarkets([horde, alliance, stale, alliance]).length, 2);
});

test("sales sum adjacent intervals, never overlapping pairs or duplicate scans", () => {
  const a = market(1, [item("Ore", 10)]);
  const b = market(3601, [item("Ore", 7)]);
  const c = market(7201, [item("Ore", 4)]);
  const { rows, comparisons } = aggregateSales([c, a, b, b]);
  assert.equal(comparisons, 2);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].units, 6); // 3 + 3, not also the 6 from a→c
  assert.equal(rows[0].before, 10);
  assert.equal(rows[0].after, 4);
  assert.equal(rows[0].intervals.length, 2);
  assert.equal(rows[0].askingValue, 600);
  assert.ok(rows[0].saleConfidence.score <= 65);
});

test("replenishment is observed between departures and scores are unit-weighted rather than added", () => {
  const a = market(1, [item("Ore", 10)]);
  const b = market(3601, [item("Ore", 7)]);
  const c = market(7201, [item("Ore", 12)]);
  const d = market(18001, [item("Ore", 6)]);
  const { rows, comparisons } = aggregateSales([a, b, c, d]);
  const row = rows[0];
  assert.equal(comparisons, 3);
  assert.equal(row.units, 9);
  assert.equal(row.intervals.length, 2);
  const expected = Math.round(row.intervals.reduce((sum, i) => sum + i.saleScore * i.units, 0) / row.units);
  assert.equal(row.saleConfidence.score, expected);
  assert.equal(row.before, 10);
  assert.equal(row.after, 6);
});

test("sales from different markets are never compared or merged", () => {
  const a = market(1, [item("Ore", 10)]);
  const b = market(3601, [item("Ore", 9)]);
  const c = market(2, [item("Ore", 10)], { place: "Alliance" });
  const d = market(3602, [item("Ore", 8)], { place: "Alliance" });
  const { rows, comparisons } = aggregateSales([d, a, b, c]);
  assert.equal(comparisons, 2);
  assert.equal(rows.length, 2);
  assert.deepEqual(rows.map((row) => row.units).sort(), [1, 2]);
  assert.equal(new Set(rows.map((row) => row.marketPlace)).size, 2);
});

test("one scan has current stock and history, but no made-up departures", () => {
  const only = market(1, [item("Ore", 10)]);
  assert.equal(aggregateMarket([only]).items[0].scansSeen, 1);
  assert.deepEqual(aggregateSales([only]), { rows: [], comparisons: 0 });
  assert.throws(() => aggregateMarket([]));
});

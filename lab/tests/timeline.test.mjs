import assert from "node:assert/strict";
import { test } from "node:test";
import { buildMarket } from "../src/model/market.ts";
import { aggregateSales } from "../src/model/history.ts";
import { marketAtTime } from "../src/model/timeline.ts";

function scan(time, { band = 1, bounds = { 1: { min: 10, max: 20 } }, copies = 2, price = 100, elapsed = 0 } = {}) {
  return buildMarket({ meta: { source: "replicate", time, elapsed, place: "Horde", timeLeftBands: bounds },
    items: [{ key: "1:Ore", id: 1, name: "Ore" }], listings: [[0, 10, price, 0, 0, band, copies]] });
}

test("a date before the first scan exposes no listings, history or sale evidence", () => {
  const view = marketAtTime([scan(100)], 99);
  assert.equal(view.market, null);
  assert.deepEqual(view.markets, []);
  assert.deepEqual(aggregateSales(view.markets), { rows: [], comparisons: 0 });
});

test("historical views exclude future prices, stock and sale evidence", () => {
  const archive = [scan(100), scan(200, { copies: 1, price: 10000 })];
  const view = marketAtTime(archive, 105);
  assert.equal(view.market.items[0].units, 20);
  assert.equal(view.market.items[0].usual, 10);
  assert.equal(view.market.items[0].scansSeen, 1);
  assert.equal(view.markets.length, 1);
  assert.equal(aggregateSales(view.markets).comparisons, 0);
});

test("expiry windows retain uncertain stock until its upper boundary then remove it", () => {
  const archive = [scan(100)];
  const before = marketAtTime(archive, 109);
  assert.equal(before.market.items[0].expiryUncertainUnits, 0);
  const uncertain = marketAtTime(archive, 115);
  assert.equal(uncertain.market.items[0].units, 20);
  assert.equal(uncertain.uncertainUnits, 20);
  const expired = marketAtTime(archive, 120);
  assert.equal(expired.expiredUnits, 20);
  assert.equal(expired.market.items.length, 0);
  assert.equal(expired.market.byKey.size, 0);
  assert.equal(archive[0].items[0].units, 20); // simulation never mutates a scan
});

test("moving to a later recorded scan refreshes stock and history", () => {
  const archive = [scan(100), scan(200, { price: 200, copies: 3 })];
  const view = marketAtTime(archive, 200);
  assert.equal(view.market.meta.time, 200);
  assert.equal(view.market.items[0].units, 30);
  assert.equal(view.market.items[0].usual, 13);
  assert.equal(view.market.items[0].scansSeen, 2);
});

test("future projections do not invent future scans, sales, or new stock", () => {
  const view = marketAtTime([scan(100)], 10000);
  assert.equal(view.market.items.length, 0);
  assert.equal(view.markets.length, 1);
  assert.equal(aggregateSales(view.markets).comparisons, 0);
});

test("unknown expiry is retained and marked unknown; fallback assumptions can be disabled", () => {
  const archive = [scan(100, { bounds: undefined })];
  // Explicitly remove the fixture's default recorded boundaries.
  delete archive[0].meta.timeLeftBands;
  const unknown = marketAtTime(archive, 4000, false);
  assert.equal(unknown.market.items[0].units, 20);
  assert.equal(unknown.unknownUnits, 20);
  assert.equal(unknown.assumed, false);
  const assumed = marketAtTime(archive, 4000, true);
  assert.equal(assumed.expiredUnits, 20);
  assert.equal(assumed.assumed, true);
});

test("partial expiry rebuilds ladder statistics and leaves a correct buyout", () => {
  const market = scan(100);
  market.items[0].tiers.push({ unit: 20, stack: 10, buyout: 200, copies: 1, units: 10, timeLeft: 2 });
  market.meta.timeLeftBands[2] = { min: 30, max: 40 };
  const view = marketAtTime([market], 125);
  const item = view.market.items[0];
  assert.equal(item.listings, 1);
  assert.equal(item.units, 10);
  assert.equal(item.min, 20);
  assert.equal(item.max, 20);
  assert.equal(item.median, 20);
  assert.equal(item.value, 200);
});

test("scan duration widens uncertainty without prematurely deleting stock", () => {
  const view = marketAtTime([scan(100, { elapsed: 10 })], 105);
  assert.equal(view.uncertainUnits, 20);
  assert.equal(view.expiredUnits, 0);
  assert.throws(() => marketAtTime([], NaN));
});

import assert from "node:assert/strict";
import { test } from "node:test";
import { compareMarkets } from "../src/model/possible-sales.ts";

function item(key, tiers, extra = {}) {
  return { key, id: 1, name: key, tiers, units: tiers.reduce((sum, tier) => sum + tier.stack * tier.copies, 0), ...extra };
}
function tier(stack, buyout, copies, timeLeft = 4) {
  return { stack, buyout, copies, timeLeft };
}
function market(time, items, meta = {}) {
  return { meta: { time, place: "Horde", source: "replicate", ...meta }, items, byKey: new Map(items.map((item) => [item.key, item])) };
}

test("pools time bands so aging does not create departures", () => {
  const before = market(1, [item("1:Ore", [tier(20, 200, 2, 4), tier(20, 200, 3, 3)])]);
  const after = market(2, [item("1:Ore", [tier(20, 200, 5, 2)])]);
  assert.deepEqual(compareMarkets(before, after), []);
});

test("preserves a fully disappeared variant without requiring a later item record", () => {
  const rows = compareMarkets(market(1, [item("1:Ore", [tier(20, 200, 3)])]), market(2, []));
  assert.equal(rows.length, 1);
  assert.equal(rows[0].missing, 3);
  assert.equal(rows[0].supplyAfter, 0);
  assert.equal(rows[0].unresolved, false);
});

test("growing tiers and bid-only counts do not produce negative or invented sales", () => {
  const before = market(1, [item("1:Ore", [tier(20, 200, 3)]), item("Bids", [], { bidOnly: 5 })]);
  const after = market(2, [item("1:Ore", [tier(20, 200, 8)]), item("Bids", [], { bidOnly: 0 })]);
  assert.deepEqual(compareMarkets(before, after), []);
});

test("counts copy decreases at exact asking prices while keeping variants separate", () => {
  const before = market(1, [item("1:Bear", [tier(2, 201, 5)]), item("1:Owl", [tier(2, 201, 2)])]);
  const after = market(2, [item("1:Bear", [tier(2, 201, 3), tier(2, 300, 10)]), item("1:Owl", [tier(2, 201, 2)])]);
  const [row] = compareMarkets(before, after);
  assert.equal(row.missing, 2);
  assert.equal(row.units, 4);
  assert.equal(row.askingValue, 402);
  assert.equal(row.supplyBefore, 10);
  assert.equal(row.supplyAfter, 26); // replenishment is not mistaken for zero departures
  assert.equal(row.item.key, "1:Bear");
});

test("keeps disappeared items and flags unresolved variants on either side", () => {
  const before = market(1, [item("1:Bear", [tier(1, 100, 2)]), item("2:Other", [tier(1, 50, 1)], { id: 2 }), item("2:?", [], { id: 2, name: null })]);
  const after = market(2, [item("1:?", [tier(1, 100, 2)], { name: null })]);
  const rows = compareMarkets(before, after);
  assert.equal(rows.length, 2);
  assert.ok(rows.every((row) => row.unresolved));
  assert.ok(rows.every((row) => row.after === 0));
});

test("different stack sizes and buyouts do not match; new items are not sales", () => {
  const before = market(1, [item("Ore", [tier(20, 200, 2)])]);
  const after = market(2, [item("Ore", [tier(10, 100, 4), tier(20, 201, 2)]), item("New", [tier(1, 1, 5)])]);
  assert.equal(compareMarkets(before, after)[0].missing, 2);
});

test("rejects incompatible, stale, and out-of-order comparisons", () => {
  const before = market(1, []);
  for (const after of [market(0, []), market(1, []), market(2, [], { place: "Alliance" }), market(2, [], { source: "browse" }), market(2, [], { stale: true })]) {
    assert.throws(() => compareMarkets(before, after));
  }
  assert.throws(() => compareMarkets(market(1, [], { stale: true }), market(2, [])));
});

const recordedBands = {
  1: { min: 0, max: 1800 }, 2: { min: 1800, max: 7200 },
  3: { min: 7200, max: 43200 }, 4: { min: 43200, max: null },
};
const timedMarket = (time, items, extra = {}) => market(time, items, { elapsed: 0, timeLeftBands: recordedBands, ...extra });

test("cheaper stock disappearing before expiry with matching expensive stock retained boosts sale evidence", () => {
  const before = timedMarket(1, [item("Ore", [tier(1, 100, 10), tier(1, 200, 20)])]);
  const retained = timedMarket(3601, [item("Ore", [tier(1, 200, 20)])]);
  const allGone = timedMarket(3601, []);
  const row = compareMarkets(before, retained)[0];
  const noPattern = compareMarkets(before, allGone)[0];
  assert.equal(row.higherRetainedUnits, 20);
  assert.equal(row.beyondExpiryUnits, 10);
  assert.equal(row.expiryConfidence.score, 0);
  assert.ok(row.saleConfidence.score > noPattern.saleConfidence.score);
  assert.equal(row.timingSource, "recorded");
});

test("new expensive tiers and equal unit prices do not pretend to be retained higher stock", () => {
  const before = timedMarket(1, [item("Ore", [tier(1, 100, 10), tier(1, 200, 20)])]);
  const after = timedMarket(3601, [item("Ore", [tier(1, 300, 20), tier(2, 200, 10)])]);
  const row = compareMarkets(before, after)[0];
  assert.equal(row.higherRetainedUnits, 0);
  assert.equal(row.saleConfidence.score, 65);
});

test("only earlier prices count: expensive missing stock does not get a cheap-depletion bonus", () => {
  const before = timedMarket(1, [item("Ore", [tier(1, 100, 100), tier(1, 200, 10), tier(1, 300, 10)])]);
  const after = timedMarket(3601, [item("Ore", [tier(1, 100, 100), tier(1, 300, 10)])]);
  assert.equal(compareMarkets(before, after)[0].saleConfidence.score, 65);
});

test("expiry allowance is bounded by eligible stock rather than all missing units", () => {
  const before = timedMarket(1, [item("Ore", [tier(10, 100, 20, 1), tier(10, 100, 20, 4)])]);
  const after = timedMarket(7201, [item("Ore", [tier(10, 100, 10, 3)])]);
  const row = compareMarkets(before, after)[0];
  assert.equal(row.units, 300);
  assert.equal(row.couldExpireUnits, 200);
  assert.equal(row.beyondExpiryUnits, 100);
  assert.equal(row.deadlinePassedUnits, 200);
});

test("passed deadlines support expiry, without claiming certainty or complementary scores", () => {
  const before = timedMarket(1, [item("Ore", [tier(1, 100, 10, 1), tier(1, 200, 20, 4)])]);
  const row = compareMarkets(before, timedMarket(3601, [item("Ore", [tier(1, 200, 20)])]))[0];
  assert.equal(row.couldExpireUnits, 10);
  assert.equal(row.beyondExpiryUnits, 0);
  assert.ok(row.expiryConfidence.score > row.saleConfidence.score);
  assert.notEqual(row.saleConfidence.score + row.expiryConfidence.score, 100);
  assert.ok(row.expiryConfidence.score < 100);
});

test("unknown bands cannot falsely rule out expiry; assumptions are optional and capped", () => {
  const before = market(1, [item("Ore", [tier(1, 100, 10), tier(1, 200, 20)])]);
  const after = market(3601, [item("Ore", [tier(1, 200, 20)])]);
  const unknown = compareMarkets(before, after, false)[0];
  assert.equal(unknown.expiryConfidence.score, null);
  assert.equal(unknown.beyondExpiryUnits, 0);
  assert.equal(unknown.unknownTimingUnits, 10);
  assert.equal(unknown.timingSource, "unknown");
  assert.ok(unknown.saleConfidence.score <= 35);
  const assumed = compareMarkets(before, after)[0];
  assert.equal(assumed.timingSource, "assumed");
  assert.ok(assumed.saleConfidence.score <= 65);
  assert.equal(assumed.beyondExpiryUnits, 10);
  const noPattern = compareMarkets(before, market(3601, []))[0];
  assert.ok(assumed.saleConfidence.score > noPattern.saleConfidence.score);
});

test("scan read time widens expiry eligibility conservatively near a band boundary", () => {
  const before = timedMarket(1, [item("Ore", [tier(1, 100, 10, 3)])], { elapsed: 300 });
  const row = compareMarkets(before, timedMarket(7001, []))[0];
  assert.equal(row.couldExpireUnits, 10); // gap alone is below 2h, but observation may be older
  assert.equal(row.beyondExpiryUnits, 0);
});

test("unresolved variants and long scan gaps weaken both confidence scores", () => {
  const before = timedMarket(1, [item("Ore", [tier(1, 100, 10, 1)])]);
  const short = compareMarkets(before, timedMarket(3601, []))[0];
  const long = compareMarkets(before, timedMarket(86401, []))[0];
  assert.ok(long.expiryConfidence.score < short.expiryConfidence.score);
  const incomplete = compareMarkets(before, timedMarket(3601, [item("?", [], { name: null })]))[0];
  assert.ok(incomplete.saleConfidence.score <= 25);
  assert.ok(incomplete.expiryConfidence.score <= 25);
});

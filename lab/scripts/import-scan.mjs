// Converts the addon's saved full scan into a compact JSON file the lab loads.
//
//   npm run import                 newest AuctioNitro.lua in the game's WTF folder
//   npm run import -- <file.lua>   a specific saved variables file
//
// The game keeps the previous version of the file beside it as .bak. That is
// read too, so a scan that was overwritten by the next one before it was
// imported can still be picked up.
//
// Each scan becomes public/data/scans/scan-<time>.json and is listed in
// public/data/index.json. Importing the same scan again rewrites the same file.
//
// Output shape (see src/data/types.ts):
//   items     one entry per distinct item (item id + name)
//   listings  [itemIndex, count, buyout, minBid, bid, timeLeft, copies]
//             identical auctions are collapsed into one entry with a copy count
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { loadItemTypes } from "./lib/item-types.mjs";
import { parseSavedVariables } from "./lib/lua-table.mjs";
import { findSavedVariables, INDEX_FILE, SCANS_DIR } from "./lib/paths.mjs";

// The addon's row layout for a full scan (AuctioNitro/data/schemas.lua).
// Position in this list is position in the row.
const ROW_FIELDS = [
  "name", "texture", "count", "qualityID", "usable", "level", "levelType",
  "minBid", "minIncrement", "buyoutPrice", "bidAmount", "highBidder",
  "bidderFullName", "owner", "ownerFullName", "saleStatus", "itemID",
  "hasAllInfo", "link", "timeLeft",
];
const AT = Object.fromEntries(ROW_FIELDS.map((field, index) => [field, index]));

// Saved rows are arrays, or objects keyed "1".."20" when the row has gaps.
function cell(row, index) {
  const value = Array.isArray(row) ? row[index] : row[index + 1];
  return value === undefined ? null : value;
}

// The part of an item link that tells variants apart: everything after the
// item id, without the name.
function linkPayload(link) {
  const match = /\|Hitem:([^|]*)\|h/.exec(link ?? "");
  return match ? match[1] : null;
}

function convert(snapshot, typeOf) {
  const rows = Array.isArray(snapshot.rows) ? snapshot.rows : Object.values(snapshot.rows);
  const catalog = snapshot.items ?? {};
  const items = [];
  const itemIndexByKey = new Map();
  const listingByKey = new Map();
  let incomplete = 0;

  for (const row of rows) {
    const itemId = cell(row, AT.itemID);
    const name = cell(row, AT.name) || null; // "" means the row's data never arrived
    if (!name) incomplete++;
    const key = name ? `${itemId}:${name}` : `${itemId}:?`;

    let itemIndex = itemIndexByKey.get(key);
    if (itemIndex === undefined) {
      // The scan's own catalog wins. Older scans have none, so fall back to the game tables.
      const known = { ...(typeOf(itemId) ?? {}), ...(catalog[itemId] ?? {}) };
      itemIndex = items.length;
      itemIndexByKey.set(key, itemIndex);
      items.push({
        key,
        id: itemId,
        name,
        quality: name ? cell(row, AT.qualityID) : null,
        level: name ? cell(row, AT.level) : null,
        levelType: cell(row, AT.levelType),
        icon: cell(row, AT.texture),
        usable: cell(row, AT.usable) === true,
        link: linkPayload(cell(row, AT.link)),
        type: known.type ?? null,
        subType: known.subType ?? null,
        equipLoc: known.equipLoc || null,
        classId: known.classID ?? null,
        subClassId: known.subClassID ?? null,
        commodity: known.commodity ?? null, // true when it is bought by the unit
      });
    }

    const listing = [
      itemIndex,
      cell(row, AT.count),
      cell(row, AT.buyoutPrice),
      cell(row, AT.minBid),
      cell(row, AT.bidAmount),
      cell(row, AT.timeLeft),
    ];
    const listingKey = listing.join(",");
    const existing = listingByKey.get(listingKey);
    if (existing) existing[6]++;
    else listingByKey.set(listingKey, [...listing, 1]);
  }

  return {
    meta: {
      ...snapshot.meta,
      rows: rows.length,
      incompleteRows: incomplete,
      hasItemTypes: items.some((item) => item.type !== null),
    },
    items,
    listings: [...listingByKey.values()],
  };
}

function readIndex() {
  return existsSync(INDEX_FILE) ? JSON.parse(readFileSync(INDEX_FILE, "utf8")) : { scans: [] };
}

// The full scan held in one saved variables file, or null.
function readSnapshot(file) {
  const db = parseSavedVariables(readFileSync(file, "utf8")).AuctioNitroDB;
  const snapshot = db?.snapshots?.replicate ?? (db?.snapshot?.meta?.source === "replicate" ? db.snapshot : null);
  return snapshot?.rows ? snapshot : null;
}

function describe(fileName, scan, megabytes) {
  return (
    `${fileName}: ${scan.meta.rows} rows -> ${scan.listings.length} distinct listings, ` +
    `${scan.items.length} items, ${megabytes} MB` +
    (scan.meta.hasItemTypes ? "" : " (no item types could be found for this scan)")
  );
}

async function main() {
  const file = process.argv[2] ?? findSavedVariables()[0];
  if (!file) throw new Error("No AuctioNitro.lua found. Run a full scan in game, then /reload.");

  const index = readIndex();
  const known = new Set(index.scans.map((entry) => entry.time));
  const typeOf = await loadItemTypes();
  mkdirSync(SCANS_DIR, { recursive: true });

  // The current file first, then the game's backup of the one before it.
  const sources = [
    { path: file, isBackup: false },
    { path: `${file}.bak`, isBackup: true },
  ].filter((source) => existsSync(source.path));

  let found = false;
  for (const source of sources) {
    let snapshot;
    try {
      snapshot = readSnapshot(source.path);
    } catch (error) {
      if (!source.isBackup) throw error;
      continue; // a backup that cannot be read is no loss
    }
    if (!snapshot) continue;
    found = true;
    // A backup only matters when it holds a scan we never imported.
    if (source.isBackup && known.has(snapshot.meta.time)) continue;

    console.log(`reading ${source.path}`);
    const scan = convert(snapshot, typeOf);
    const fileName = `scan-${scan.meta.time}.json`;
    const text = JSON.stringify(scan);
    writeFileSync(join(SCANS_DIR, fileName), text);
    index.scans = index.scans.filter((entry) => entry.file !== fileName);
    index.scans.push({ file: fileName, ...scan.meta, items: scan.items.length, listings: scan.listings.length });
    known.add(scan.meta.time);
    console.log((source.isBackup ? "recovered from backup: " : "") + describe(fileName, scan, (text.length / 1024 / 1024).toFixed(1)));
  }
  if (!found) throw new Error("That file holds no full scan with its rows. Run a full scan in game, then /reload.");

  index.scans.sort((a, b) => b.time - a.time);
  writeFileSync(INDEX_FILE, JSON.stringify(index, null, 2));
  console.log(`${index.scans.length} scan${index.scans.length === 1 ? "" : "s"} in the lab`);
}

await main();

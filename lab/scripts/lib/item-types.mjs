// What kind of thing each item id is: class (Armor, Weapon...), subclass
// (Leather, One-Handed Swords...) and equip slot.
//
// This comes from the game's own item tables for the Forever build, published
// by wago.tools. It is the same information the addon gets in game from
// GetItemInfoInstant, so the lab is not learning anything the addon cannot.
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { CACHE_DIR } from "./paths.mjs";

const PRODUCT = "wowf"; // wago.tools' name for the Forever client
const TABLES = ["Item", "ItemSubClass", "ItemClass"];
const MAX_AGE_DAYS = 30;
const HEADERS = { "User-Agent": "item-data-script" };

// The Item table stores the slot as a number. These are the names the game's
// API uses for them, which config/catalog.ts turns into labels.
const EQUIP_LOCATIONS = {
  1: "INVTYPE_HEAD", 2: "INVTYPE_NECK", 3: "INVTYPE_SHOULDER", 4: "INVTYPE_BODY",
  5: "INVTYPE_CHEST", 6: "INVTYPE_WAIST", 7: "INVTYPE_LEGS", 8: "INVTYPE_FEET",
  9: "INVTYPE_WRIST", 10: "INVTYPE_HAND", 11: "INVTYPE_FINGER", 12: "INVTYPE_TRINKET",
  13: "INVTYPE_WEAPON", 14: "INVTYPE_SHIELD", 15: "INVTYPE_RANGED", 16: "INVTYPE_CLOAK",
  17: "INVTYPE_2HWEAPON", 18: "INVTYPE_BAG", 19: "INVTYPE_TABARD", 20: "INVTYPE_ROBE",
  21: "INVTYPE_WEAPONMAINHAND", 22: "INVTYPE_WEAPONOFFHAND", 23: "INVTYPE_HOLDABLE",
  24: "INVTYPE_AMMO", 25: "INVTYPE_THROWN", 26: "INVTYPE_RANGEDRIGHT",
  27: "INVTYPE_QUIVER", 28: "INVTYPE_RELIC",
};

// Splits one CSV line, honoring quoted fields.
function splitLine(line) {
  const cells = [];
  let cell = "";
  let quoted = false;
  for (let index = 0; index < line.length; index++) {
    const char = line[index];
    if (quoted) {
      if (char === '"' && line[index + 1] === '"') {
        cell += '"';
        index++;
      } else if (char === '"') quoted = false;
      else cell += char;
    } else if (char === '"') quoted = true;
    else if (char === ",") {
      cells.push(cell);
      cell = "";
    } else cell += char;
  }
  cells.push(cell);
  return cells;
}

function readTable(file) {
  const lines = readFileSync(file, "utf8").split(/\r?\n/).filter(Boolean);
  const header = splitLine(lines[0]);
  return lines.slice(1).map((line) => {
    const cells = splitLine(line);
    return Object.fromEntries(header.map((name, index) => [name, cells[index]]));
  });
}

async function tableFile(table) {
  mkdirSync(CACHE_DIR, { recursive: true });
  const file = join(CACHE_DIR, `${PRODUCT}-${table}.csv`);
  const fresh = existsSync(file) && Date.now() - statSync(file).mtimeMs < MAX_AGE_DAYS * 86400_000;
  if (!fresh) {
    const response = await fetch(`https://wago.tools/db2/${table}/csv?product=${PRODUCT}`, { headers: HEADERS });
    if (!response.ok) {
      if (existsSync(file)) return file; // an old copy beats none
      throw new Error(`could not download the ${table} table: ${response.status}`);
    }
    writeFileSync(file, await response.text());
  }
  return file;
}

// Returns a function: item id -> { type, subType, equipLoc, classID, subClassID } or null.
export async function loadItemTypes() {
  const [itemFile, subClassFile, classFile] = await Promise.all(TABLES.map(tableFile));

  const classNames = new Map(readTable(classFile).map((row) => [Number(row.ClassID), row.ClassName_lang]));
  const subClassNames = new Map(
    readTable(subClassFile).map((row) => [
      `${row.ClassID}:${row.SubClassID}`,
      // The verbose name tells one-handed from two-handed ("Sword" is both).
      row.VerboseName_lang || row.DisplayName_lang,
    ]),
  );
  const items = new Map(
    readTable(itemFile).map((row) => [
      Number(row.ID),
      { classID: Number(row.ClassID), subClassID: Number(row.SubclassID), slot: Number(row.InventoryType) },
    ]),
  );

  return (itemId) => {
    const item = items.get(itemId);
    if (!item) return null;
    return {
      type: classNames.get(item.classID) ?? null,
      subType: subClassNames.get(`${item.classID}:${item.subClassID}`) ?? null,
      equipLoc: EQUIP_LOCATIONS[item.slot] ?? null,
      classID: item.classID,
      subClassID: item.subClassID,
    };
  };
}

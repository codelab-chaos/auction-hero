// Downloads the icon of every item in the imported scans into public/icons,
// one file per icon id, skipping the ones already there.
//
//   npm run icons
//
// A scan only knows an icon's numeric id. The game's file manifest (published
// by wago.tools) turns that into a file name, and Blizzard's own render host
// serves the image by name.
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { CACHE_DIR, ICONS_DIR, SCANS_DIR } from "./lib/paths.mjs";

const MANIFEST_URL = "https://wago.tools/db2/ManifestInterfaceData/csv";
const MANIFEST_FILE = join(CACHE_DIR, "interface-manifest.csv");
const MANIFEST_MAX_AGE_DAYS = 30;

// Tried in order for each icon. {name} is the lowercase file name without extension.
const IMAGE_SOURCES = [
  "https://render.worldofwarcraft.com/us/icons/56/{name}.jpg",
  "https://wow.zamimg.com/images/wow/icons/large/{name}.jpg",
];

const PARALLEL = 8;
const HEADERS = { "User-Agent": "icon-fetch-script" };

async function loadManifest() {
  mkdirSync(CACHE_DIR, { recursive: true });
  const { statSync } = await import("node:fs");
  const fresh =
    existsSync(MANIFEST_FILE) &&
    Date.now() - statSync(MANIFEST_FILE).mtimeMs < MANIFEST_MAX_AGE_DAYS * 86400_000;
  if (!fresh) {
    console.log("downloading the game's file manifest...");
    const response = await fetch(MANIFEST_URL, { headers: HEADERS });
    if (!response.ok) throw new Error(`manifest download failed: ${response.status}`);
    writeFileSync(MANIFEST_FILE, await response.text());
  }

  // Lines look like: 132537,Interface\ICONS\,INV_Boots_03.blp
  const names = new Map();
  for (const line of readFileSync(MANIFEST_FILE, "utf8").split(/\r?\n/)) {
    const [id, folder, file] = line.split(",");
    if (file && /icons/i.test(folder)) {
      names.set(Number(id), file.replace(/\.blp$/i, "").toLowerCase());
    }
  }
  return names;
}

function iconIdsInScans() {
  const ids = new Set();
  if (!existsSync(SCANS_DIR)) return ids;
  for (const file of readdirSync(SCANS_DIR)) {
    const scan = JSON.parse(readFileSync(join(SCANS_DIR, file), "utf8"));
    for (const item of scan.items) if (item.icon) ids.add(item.icon);
  }
  return ids;
}

async function download(name) {
  for (const template of IMAGE_SOURCES) {
    const response = await fetch(template.replace("{name}", name), { headers: HEADERS });
    if (response.ok && (response.headers.get("content-type") ?? "").startsWith("image/")) {
      return Buffer.from(await response.arrayBuffer());
    }
  }
  return null;
}

async function main() {
  const wanted = [...iconIdsInScans()].filter((id) => !existsSync(join(ICONS_DIR, `${id}.jpg`)));
  if (wanted.length === 0) {
    console.log("icons are up to date");
    return;
  }
  mkdirSync(ICONS_DIR, { recursive: true });
  const names = await loadManifest();

  const unnamed = [];
  const failed = [];
  let saved = 0;
  const queue = [...wanted];
  async function worker() {
    for (let id = queue.shift(); id !== undefined; id = queue.shift()) {
      const name = names.get(id);
      if (!name) {
        unnamed.push(id);
        continue;
      }
      const image = await download(name).catch(() => null);
      if (image) {
        writeFileSync(join(ICONS_DIR, `${id}.jpg`), image);
        saved++;
      } else {
        failed.push(id);
      }
    }
  }
  await Promise.all(Array.from({ length: PARALLEL }, worker));

  console.log(`icons: ${saved} downloaded`);
  if (unnamed.length) {
    console.log(`  ${unnamed.length} have no name in the manifest (new on Forever): ${unnamed.slice(0, 8).join(", ")}...`);
  }
  if (failed.length) console.log(`  ${failed.length} could not be downloaded: ${failed.slice(0, 8).join(", ")}...`);
  // The lab shows a placeholder for any icon it cannot find.
  writeFileSync(join(ICONS_DIR, "missing.json"), JSON.stringify([...unnamed, ...failed]));
}

main();

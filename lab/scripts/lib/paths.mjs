// Where things live, for the lab's scripts.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

export const LAB_ROOT = resolve(here, "../..");
export const REPO_ROOT = resolve(LAB_ROOT, "..");
export const DATA_DIR = join(LAB_ROOT, "public/data");
export const SCANS_DIR = join(DATA_DIR, "scans");
export const INDEX_FILE = join(DATA_DIR, "index.json");
export const ICONS_DIR = join(LAB_ROOT, "public/icons");
export const CACHE_DIR = join(LAB_ROOT, ".cache");

const SAVED_FILE = "AuctioNitro.lua";

// The AddOns folder the addon deploys to: WOW_ADDONS_DIR, or the first line
// of .deploy-target in the repo root. Same rule as scripts/deploy.sh.
function addonsDir() {
  if (process.env.WOW_ADDONS_DIR) return process.env.WOW_ADDONS_DIR;
  const target = join(REPO_ROOT, ".deploy-target");
  if (existsSync(target)) return readFileSync(target, "utf8").split(/\r?\n/)[0].trim();
  return null;
}

// Every account's saved variables file for the addon, newest first.
export function findSavedVariables() {
  const addons = addonsDir();
  if (!addons) {
    throw new Error("No game folder. Set WOW_ADDONS_DIR or put the AddOns path in .deploy-target.");
  }
  const accounts = resolve(addons, "../../WTF/Account");
  if (!existsSync(accounts)) throw new Error(`No WTF folder at ${accounts}`);
  return readdirSync(accounts)
    .map((account) => join(accounts, account, "SavedVariables", SAVED_FILE))
    .filter((file) => existsSync(file))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
}

// Adds what the game's item tables know about each item (stack size, vendor
// price) to the scans already imported, so older scans do not need importing
// again. New imports record these themselves.
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { loadStackSizes, loadVendorPrices } from "./lib/item-types.mjs";
import { SCANS_DIR } from "./lib/paths.mjs";

const stackOf = await loadStackSizes();
const vendorOf = await loadVendorPrices();
for (const name of readdirSync(SCANS_DIR).filter((file) => file.endsWith(".json"))) {
  const file = join(SCANS_DIR, name);
  const scan = JSON.parse(readFileSync(file, "utf8"));
  let known = 0;
  for (const item of scan.items) {
    item.maxStack = stackOf(item.id);
    item.vendorPrice = vendorOf(item.id);
    if (item.vendorPrice !== null) known++;
  }
  writeFileSync(file, JSON.stringify(scan));
  console.log(`${name}: vendor price known for ${known} of ${scan.items.length} items`);
}

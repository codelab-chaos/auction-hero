// One test per file in tests/unit: a module tested on its own, by calling it
// (see runUnit in harness/run.mjs). Fails by raising a Lua error.
import { readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { runUnit } from "./harness/run.mjs";

const units = join(dirname(fileURLToPath(import.meta.url)), "unit");

for (const file of readdirSync(units).filter((name) => name.endsWith(".lua")).sort()) {
  test("unit: " + file.replace(/\.lua$/, "").replaceAll("-", " "), () => {
    runUnit(join(units, file));
  });
}

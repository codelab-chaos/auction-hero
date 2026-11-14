// One test per scenario in tests/scenarios. A scenario drives the addon the
// way a player would and fails by raising a Lua error (see harness/helpers.lua).
import { readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { runScenario } from "./harness/run.mjs";

const scenarios = join(dirname(fileURLToPath(import.meta.url)), "scenarios");

for (const file of readdirSync(scenarios).filter((name) => name.endsWith(".lua")).sort()) {
  test(file.replace(/\.lua$/, "").replaceAll("-", " "), () => {
    runScenario(join(scenarios, file));
  });
}

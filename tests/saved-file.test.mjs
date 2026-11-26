// The saved file against the game's real limits. The other tests run on Lua
// 5.3 (fengari), whose limits are not the game's, so this one runs stock Lua
// 5.1 (tests/lua51/saved-file.lua). Skipped where lua5.1 is not installed;
// the build installs it.
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const lua = ["lua5.1", "lua51"].find((name) => spawnSync(name, ["-v"]).status === 0);

test("saved file: loads in the game's Lua however much is saved", { skip: lua ? false : "lua5.1 is not installed" }, () => {
  const run = spawnSync(lua, [join(here, "lua51/saved-file.lua"), join(here, "..")], { encoding: "utf8" });
  if (run.status !== 0) throw new Error((run.stderr || run.stdout).trim());
});

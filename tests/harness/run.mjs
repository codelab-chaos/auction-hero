// Runs the addon inside a Lua interpreter with a mocked game client, then a
// scenario against it. Each call gets a fresh Lua state, so scenarios cannot
// affect each other.
//
// The interpreter is Lua 5.3 (fengari); the game runs Lua 5.1. The addon avoids
// anything the two disagree on, and the build's syntax check uses Lua 5.1.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const here = dirname(fileURLToPath(import.meta.url));
export const ADDON_DIR = join(here, "../../AuctionHero");

// Throws with the Lua error (and its traceback) when the scenario fails.
export function runScenario(scenarioFile, addonDir = ADDON_DIR) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  function run(source, name, addonArgs = false) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(source), null, to_luastring("@" + name)) !== 0) {
      throw new Error("syntax: " + to_jsstring(lua.lua_tostring(L, -1)));
    }
    if (addonArgs) {
      // Every addon file is called with the addon's name and its shared table.
      lua.lua_pushstring(L, to_luastring("AuctionHero"));
      lua.lua_getglobal(L, to_luastring("NS"));
    }
    if (lua.lua_pcall(L, addonArgs ? 2 : 0, 0, 0) !== 0) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
  }

  run(readFileSync(join(here, "mock.lua"), "utf8"), "mock.lua");
  run(readFileSync(join(here, "helpers.lua"), "utf8"), "helpers.lua");
  run("NS = {}", "namespace");

  // Load the addon's files in the order its TOC lists them, as the game does.
  const toc = readFileSync(join(addonDir, "AuctionHero.toc"), "utf8").split(/\r?\n/);
  for (const line of toc) {
    const file = line.trim().replace(/\\/g, "/");
    if (file && !file.startsWith("#")) run(readFileSync(join(addonDir, file), "utf8"), file, true);
  }

  lua.lua_pushstring(L, to_luastring(readFileSync(scenarioFile, "utf8")));
  lua.lua_setglobal(L, to_luastring("SCENARIO_SOURCE"));
  run(
    `local scenario = assert(load(SCENARIO_SOURCE, "@scenario"))
     local ok, problem = xpcall(scenario, debug.traceback)
     if not ok then error(problem, 0) end`,
    "runner",
  );
}

// Runs a unit test: one module (or a few) on its own, with no mocked game and
// none of the rest of the addon. The test's first line names what it loads:
//   -- loads: ui/redraw-scheduler.lua, data/theme.lua
// Each is called as the game would, with the addon's name and NS. The test
// then calls the module directly, so it tests the logic, not a running addon.
export function runUnit(unitFile, addonDir = ADDON_DIR) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  function run(source, name, addonArgs = false) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(source), null, to_luastring("@" + name)) !== 0) {
      throw new Error("syntax: " + to_jsstring(lua.lua_tostring(L, -1)));
    }
    if (addonArgs) {
      lua.lua_pushstring(L, to_luastring("AuctionHero"));
      lua.lua_getglobal(L, to_luastring("NS"));
    }
    if (lua.lua_pcall(L, addonArgs ? 2 : 0, 0, 0) !== 0) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
  }
  const source = readFileSync(unitFile, "utf8");
  const loads = (source.match(/^-- loads: (.*)$/m) || [null, ""])[1].split(",").map((name) => name.trim()).filter(Boolean);
  run(readFileSync(join(here, "helpers.lua"), "utf8"), "helpers.lua");
  run("NS = { L = setmetatable({}, { __index = function(_, key) return key end }) }", "namespace");
  for (const file of loads) run(readFileSync(join(addonDir, file), "utf8"), file, true);
  lua.lua_pushstring(L, to_luastring(source));
  lua.lua_setglobal(L, to_luastring("UNIT_SOURCE"));
  run(
    `local unit = assert(load(UNIT_SOURCE, "@unit"))
     local ok, problem = xpcall(unit, debug.traceback)
     if not ok then error(problem, 0) end`,
    "runner",
  );
}

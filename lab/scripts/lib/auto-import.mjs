// A dev server add-on: while the lab is running, it watches the game's saved
// variables file and imports a new scan the moment the game writes one, then
// reloads the page. So after a scan the only step in game is "Save to disk".
//
// The game folder is on the Windows side, where file change notices do not
// reach WSL, so this checks the file's timestamp on a timer instead.
import { spawn } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { findSavedVariables, LAB_ROOT } from "./paths.mjs";

const CHECK_EVERY_MS = 3000;
const SCRIPTS = ["scripts/import-scan.mjs", "scripts/fetch-icons.mjs"];

function run(script, log) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [join(LAB_ROOT, script)], { cwd: LAB_ROOT });
    const say = (data) => {
      for (const line of String(data).split(/\r?\n/)) if (line.trim()) log(line.trim());
    };
    child.stdout.on("data", say);
    child.stderr.on("data", say);
    child.on("close", (code) => resolve(code === 0));
  });
}

// The newest saved variables file and when it was last written, or null.
function newest() {
  try {
    const file = findSavedVariables()[0];
    return file && existsSync(file) ? { file, stamp: statSync(file).mtimeMs, size: statSync(file).size } : null;
  } catch {
    return null; // no game folder configured: nothing to watch
  }
}

export function autoImport() {
  return {
    name: "nitro-lab-auto-import",
    apply: "serve",
    configureServer(server) {
      const log = (text) => server.config.logger.info(`[scan import] ${text}`, { timestamp: true });
      let seen = newest();
      let pending = null; // a change waiting to settle
      let busy = false;

      if (!seen) {
        log("no saved scan file found, so new scans will not be imported automatically");
        return;
      }
      log(`watching ${seen.file}`);

      const timer = setInterval(async () => {
        if (busy) return;
        const now = newest();
        if (!now || (seen && now.stamp === seen.stamp)) return;

        // The game writes a large file over a moment. Wait until two checks in
        // a row see the same size before reading it.
        if (!pending || pending.size !== now.size || pending.stamp !== now.stamp) {
          pending = now;
          return;
        }
        pending = null;
        seen = now;
        busy = true;
        log("the game saved new data, importing...");
        let ok = true;
        for (const script of SCRIPTS) ok = (await run(script, log)) && ok;
        busy = false;
        if (ok) {
          log("done, reloading the lab");
          server.ws.send({ type: "full-reload" });
        } else {
          log("the import failed, see above. Run `npm run refresh` to try again");
        }
      }, CHECK_EVERY_MS);

      server.httpServer?.once("close", () => clearInterval(timer));
    },
  };
}

import { defineConfig } from "vite";
import { autoImport } from "./scripts/lib/auto-import.mjs";

// Nitro Lab owns port 5210 (claimed in Chaos Atlas). strictPort makes the
// server fail loudly instead of drifting to another port.
const PORT = 5210;

export default defineConfig({
  publicDir: "public",
  // While the dev server runs, a new scan saved by the game is imported by itself.
  plugins: [autoImport()],
  server: { port: PORT, strictPort: true },
  preview: { port: PORT, strictPort: true },
});

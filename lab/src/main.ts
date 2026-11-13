// Entry point: load what was imported, then hand over to the shell.
import { loadIndex, loadMissingIcons } from "./data/load";
import { mountApp } from "./ui/app";
import { h, setMissingIcons } from "./ui/dom";
import "./styles.css";

async function main(): Promise<void> {
  const root = document.getElementById("app");
  if (!root) return;

  const [index, missing] = await Promise.all([loadIndex(), loadMissingIcons()]);
  setMissingIcons(missing);

  if (index.scans.length === 0) {
    root.append(
      h(
        "div",
        { class: "welcome" },
        h("h1", null, "Nitro Lab"),
        h("p", null, "No scan has been imported yet."),
        h("ol", null, h("li", null, "In game, run a Full scan in AuctioNitro, then click Save to disk."), h("li", null, "In the lab folder, run: npm run refresh"), h("li", null, "Reload this page.")),
      ),
    );
    return;
  }
  await mountApp(root, index.scans);
}

void main();

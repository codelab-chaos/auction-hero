// Meter: a row of pips with a word beside it. The word carries the meaning,
// so the meter never depends on color alone. Hovering lists the reasons.
import type { Signal } from "../model/signals";
import { h } from "./dom";

export function meter(signal: Signal, options: { compact?: boolean } = {}): HTMLElement {
  const pips = h("span", { class: "meter-pips" });
  for (let position = 1; position <= signal.pips; position++) {
    pips.append(h("span", { class: `meter-pip ${position <= signal.level.pips ? "on" : ""}` }));
  }
  return h(
    "span",
    // The hover always names the level, so a meter shown without its word
    // still says what it means.
    { class: `meter tone-${signal.level.tone}`, title: [signal.level.label, ...signal.reasons].join("\n") },
    pips,
    options.compact ? "" : h("span", { class: "meter-label" }, signal.level.label),
  );
}

// A meter with its name above and its reasons spelled out below. For places
// where the meter is a disclaimer and should not hide behind a hover.
export function meterBlock(name: string, signal: Signal): HTMLElement {
  const block = h("div", { class: "meter-block" }, h("div", { class: "meter-head" }, h("span", { class: "meter-name" }, name), meter(signal)));
  for (const reason of signal.reasons) {
    block.append(h("div", { class: "meter-reason" }, reason));
  }
  return block;
}

// A meter on one line with its name, and optionally one line of facts under
// it. The reasons are in a tooltip, one per line.
export function meterRow(name: string, signal: Signal, facts?: string): HTMLElement {
  return h(
    "div",
    { class: "meter-row cw-tipped", "data-tip": signal.reasons.join("\n"), tabindex: "0" },
    h("div", { class: "meter-head" }, h("span", { class: "meter-name" }, name), meter(signal)),
    facts ? h("div", { class: "meter-facts" }, facts) : "",
  );
}

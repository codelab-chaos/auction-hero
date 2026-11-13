// Small DOM helpers shared by every screen.
import { QUALITY_BY_ID } from "../config/catalog";

type Child = Node | string | number | null | undefined | false;
type Props = Record<string, unknown>;

// h("div", { class: "x", onclick: fn }, child, child)
export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: Props | null = null,
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const element = document.createElement(tag);
  for (const [key, value] of Object.entries(props ?? {})) {
    if (value === null || value === undefined || value === false) continue;
    if (key.startsWith("on") && typeof value === "function") {
      element.addEventListener(key.slice(2), value as EventListener);
    } else if (key === "class") {
      element.className = String(value);
    } else if (key in element && key !== "list") {
      (element as unknown as Props)[key] = value;
    } else {
      element.setAttribute(key, String(value));
    }
  }
  for (const child of children) {
    if (child === null || child === undefined || child === false) continue;
    element.append(child instanceof Node ? child : String(child));
  }
  return element;
}

export function clear(element: Element): void {
  element.replaceChildren();
}

export function number(value: number | null): string {
  return value === null ? "" : Math.floor(value).toLocaleString("en-US");
}

// Copper as gold, silver and copper: 123456 -> 12g 34s 56c
export function money(copper: number | null): HTMLElement {
  const span = h("span", { class: "money" });
  if (copper === null) return span;
  const value = Math.floor(copper);
  const gold = Math.floor(value / 10000);
  const silver = Math.floor(value / 100) % 100;
  const rest = value % 100;
  if (gold > 0) span.append(h("span", { class: "gold" }, `${gold.toLocaleString("en-US")}g`), " ");
  if (gold > 0 || silver > 0) span.append(h("span", { class: "silver" }, `${silver}s`), " ");
  span.append(h("span", { class: "copper" }, `${rest}c`));
  return span;
}

let missingIcons = new Set<number>();

export function setMissingIcons(ids: Set<number>): void {
  missingIcons = ids;
}

export function icon(id: number | null, size = 20): HTMLElement {
  if (id === null || missingIcons.has(id)) {
    return h("span", { class: "icon icon-missing", style: `width:${size}px;height:${size}px` });
  }
  return h("img", {
    class: "icon",
    src: `/icons/${id}.jpg`,
    width: size,
    height: size,
    loading: "lazy",
    alt: "",
  });
}

export function itemName(name: string | null, quality: number | null, fallback: string): HTMLElement {
  const color = quality === null ? undefined : QUALITY_BY_ID.get(quality)?.color;
  return h("span", { class: "item-name", style: color ? `color:${color}` : "" }, name ?? fallback);
}

// A labelled form control: <label>Text <control/></label>
export function field(label: string, control: HTMLElement): HTMLElement {
  return h("label", { class: "field" }, h("span", { class: "field-label" }, label), control);
}

export function numberInput(value: number | null, onChange: (value: number | null) => void, placeholder = ""): HTMLInputElement {
  return h("input", {
    type: "number",
    class: "input input-number",
    value: value === null ? "" : String(value),
    placeholder,
    oninput: (event: Event) => {
      const text = (event.target as HTMLInputElement).value;
      onChange(text === "" ? null : Number(text));
    },
  });
}

export function checkbox(label: string, checked: boolean, onChange: (checked: boolean) => void): HTMLElement {
  return h(
    "label",
    { class: "check" },
    h("input", {
      type: "checkbox",
      checked,
      onchange: (event: Event) => onChange((event.target as HTMLInputElement).checked),
    }),
    label,
  );
}

export function select(
  options: { value: string; label: string }[],
  value: string,
  onChange: (value: string) => void,
): HTMLSelectElement {
  const element = h("select", {
    class: "input",
    onchange: (event: Event) => onChange((event.target as HTMLSelectElement).value),
  });
  for (const option of options) {
    element.append(h("option", { value: option.value, selected: option.value === value }, option.label));
  }
  return element;
}

// A price entry as three boxes, gold, silver and copper, the way the game's
// own auction house takes a price. onChange gets the total in copper.
// compact makes it small enough for a toolbar.
export function moneyInput(
  copper: number | null,
  onChange: (copper: number) => void,
  options: { compact?: boolean } = {},
): HTMLElement {
  const value = Math.max(0, Math.floor(copper ?? 0));
  const parts = { gold: Math.floor(value / 10000), silver: Math.floor(value / 100) % 100, copper: value % 100 };
  const row = h("span", { class: `money-input ${options.compact ? "money-input-compact" : ""}` });

  const commit = (): void => {
    const read = (name: string): number =>
      Math.max(0, Math.floor(Number(row.querySelector<HTMLInputElement>(`[data-coin="${name}"]`)?.value) || 0));
    onChange(read("gold") * 10000 + read("silver") * 100 + read("copper"));
  };

  for (const [name, letter] of [
    ["gold", "g"],
    ["silver", "s"],
    ["copper", "c"],
  ] as const) {
    row.append(
      h(
        "span",
        { class: `money-box money-box-${name}` },
        h("input", {
          type: "number",
          min: "0",
          max: name === "gold" ? null : "99",
          "data-coin": name,
          "aria-label": name,
          value: String(parts[name]),
          onchange: commit,
        }),
        h("span", { class: name }, letter),
      ),
    );
  }
  return row;
}

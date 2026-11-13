// A sortable table drawn from a list of column definitions.
import { h } from "./dom";

export interface Column<T> {
  id: string;
  label: string;
  align?: "left" | "right";
  width?: string;
  tip?: string;
  // What the column sorts by. Leave out to make the header unclickable.
  sort?: (row: T) => number | string | null;
  render: (row: T) => Node | string;
}

export interface Sort {
  column: string;
  descending: boolean;
}

export interface TableOptions<T> {
  columns: Column<T>[];
  rows: T[];
  sort: Sort | null;
  onSort: (sort: Sort) => void;
  onRowClick?: (row: T) => void;
  limit: number;
  empty: string;
  rowClass?: (row: T) => string;
}

// Empty values always sort last, whichever direction.
function compare(a: number | string | null, b: number | string | null, descending: boolean): number {
  if (a === null || b === null) return a === null ? (b === null ? 0 : 1) : -1;
  const order = typeof a === "number" && typeof b === "number" ? a - b : String(a).localeCompare(String(b));
  return descending ? -order : order;
}

export function sortRows<T>(rows: T[], columns: Column<T>[], sort: Sort | null): T[] {
  const column = sort && columns.find((candidate) => candidate.id === sort.column);
  if (!sort || !column?.sort) return rows;
  const read = column.sort;
  return [...rows].sort((a, b) => compare(read(a), read(b), sort.descending));
}

export function renderTable<T>(options: TableOptions<T>): HTMLElement {
  const { columns, sort } = options;
  const sorted = sortRows(options.rows, columns, sort);
  const shown = sorted.slice(0, options.limit);

  const head = h("tr");
  for (const column of columns) {
    const active = sort?.column === column.id;
    const arrow = active ? (sort.descending ? " ▾" : " ▴") : "";
    head.append(
      h(
        "th",
        {
          class: `${column.align === "right" ? "right" : ""} ${column.sort ? "sortable" : ""} ${active ? "active" : ""}`,
          style: column.width ? `width:${column.width}` : "",
          title: column.tip ?? "",
          onclick: column.sort
            ? () =>
                options.onSort({
                  column: column.id,
                  // Numbers start largest first, text starts at A.
                  descending: active ? !sort.descending : column.align === "right",
                })
            : null,
        },
        column.label + arrow,
      ),
    );
  }

  const body = h("tbody");
  for (const row of shown) {
    const line = h("tr", {
      class: `${options.onRowClick ? "clickable" : ""} ${options.rowClass?.(row) ?? ""}`,
      onclick: options.onRowClick ? () => options.onRowClick?.(row) : null,
    });
    for (const column of columns) {
      line.append(h("td", { class: column.align === "right" ? "right" : "" }, column.render(row)));
    }
    body.append(line);
  }

  const count =
    sorted.length > shown.length
      ? `${shown.length.toLocaleString("en-US")} of ${sorted.length.toLocaleString("en-US")} shown. Filter or sort to see others.`
      : `${sorted.length.toLocaleString("en-US")} shown`;

  return h(
    "div",
    { class: "table-wrap" },
    h("div", { class: "table-count" }, count),
    sorted.length === 0
      ? h("div", { class: "empty" }, options.empty)
      : h("table", { class: "table" }, h("thead", null, head), body),
  );
}

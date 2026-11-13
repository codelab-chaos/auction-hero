// Charts for the History tab, drawn as SVG from straight lines, rectangles
// and text only: the same primitives the game's UI has (lines, textures and
// font strings), so what is designed here can be rebuilt there.
import { CHART } from "../config/history-view";
import type { PricePoint } from "../model/price-history";

const SVG = "http://www.w3.org/2000/svg";

function el(tag: string, attributes: Record<string, string | number>, text?: string): SVGElement {
  const node = document.createElementNS(SVG, tag);
  for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, String(value));
  if (text !== undefined) node.textContent = text;
  return node;
}

// Copper as short plain text for an axis: 12g, 3s 40c, 85c.
export function axisMoney(copper: number): string {
  const value = Math.round(copper);
  const gold = Math.floor(value / 10000);
  const silver = Math.floor(value / 100) % 100;
  const rest = value % 100;
  if (gold >= 10) return `${gold.toLocaleString("en-US")}g`;
  if (gold > 0) return silver ? `${gold}g ${silver}s` : `${gold}g`;
  if (silver > 0) return rest ? `${silver}s ${rest}c` : `${silver}s`;
  return `${rest}c`;
}

export function dayLabel(day: number): string {
  return new Date(day * 86400 * 1000).toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" });
}

// A round number at or above a value, so the top grid line is a tidy figure.
function niceCeiling(value: number): number {
  if (value <= 0) return 1;
  const power = Math.pow(10, Math.floor(Math.log10(value)));
  for (const step of [1, 2, 2.5, 5, 10]) {
    if (step * power >= value) return step * power;
  }
  return 10 * power;
}

export interface Series {
  label: string;
  color: string;
  value: (point: PricePoint) => number;
}

interface Frame {
  svg: SVGElement;
  x: (day: number) => number;
  y: (value: number) => number;
  plotBottom: number;
  plotRight: number;
}

// The shared scaffold: quiet grid lines with their labels, and the dates.
function frame(
  points: PricePoint[],
  height: number,
  top: number,
  format: (value: number) => string,
  showDates: boolean,
  gridLines = CHART.gridLines,
): Frame {
  const { width, left, right } = CHART;
  const bottom = showDates ? CHART.bottom : 6;
  const svg = el("svg", { class: "chart", width, height, viewBox: `0 0 ${width} ${height}` });
  const plotBottom = height - bottom;
  const plotRight = width - right;
  const firstDay = points[0]?.day ?? 0;
  const lastDay = points[points.length - 1]?.day ?? 0;
  const span = Math.max(1, lastDay - firstDay);
  const x = (day: number): number => left + ((day - firstDay) / span) * (plotRight - left);
  const y = (value: number): number => plotBottom - (value / top) * (plotBottom - CHART.top);

  for (let index = 0; index <= gridLines; index++) {
    const value = (top / gridLines) * index;
    const lineY = Math.round(y(value)) + 0.5;
    svg.append(
      el("line", { class: index === 0 ? "chart-axis" : "chart-grid", x1: left, x2: plotRight, y1: lineY, y2: lineY }),
      el("text", { class: "chart-label", x: left - 6, y: lineY + 3, "text-anchor": "end" }, format(value)),
    );
  }
  if (showDates) {
    const middle = Math.round((firstDay + lastDay) / 2);
    const marks = points.length > 2 ? [firstDay, middle, lastDay] : [firstDay, lastDay];
    [...new Set(marks)].forEach((day, index, all) => {
      const anchor = index === 0 ? "start" : index === all.length - 1 ? "end" : "middle";
      svg.append(el("text", { class: "chart-label", x: x(day), y: height - 5, "text-anchor": anchor }, dayLabel(day)));
    });
  }
  return { svg, x, y, plotBottom, plotRight };
}

// Hover: a vertical guide and a callback saying which point is nearest.
function hover(svg: SVGElement, points: PricePoint[], scale: Frame, onHover: (point: PricePoint | null, x: number) => void): void {
  const guide = el("line", { class: "chart-guide", y1: CHART.top, y2: scale.plotBottom, x1: 0, x2: 0, visibility: "hidden" });
  svg.append(guide);
  svg.addEventListener("mousemove", (event) => {
    const box = (svg as unknown as SVGSVGElement).getBoundingClientRect();
    const mouseX = (event as MouseEvent).clientX - box.left;
    let nearest = points[0];
    for (const point of points) {
      if (nearest && Math.abs(scale.x(point.day) - mouseX) < Math.abs(scale.x(nearest.day) - mouseX)) nearest = point;
    }
    if (!nearest) return;
    const guideX = Math.round(scale.x(nearest.day)) + 0.5;
    guide.setAttribute("x1", String(guideX));
    guide.setAttribute("x2", String(guideX));
    guide.setAttribute("visibility", "visible");
    onHover(nearest, guideX);
  });
  svg.addEventListener("mouseleave", () => {
    guide.setAttribute("visibility", "hidden");
    onHover(null, 0);
  });
}

// Lines of price over time. Each series is straight segments between its
// points, a small square at each point, and its name at its right-hand end.
export function priceChart(points: PricePoint[], series: Series[], onHover: (point: PricePoint | null, x: number) => void): SVGElement {
  const highest = Math.max(1, ...points.flatMap((point) => series.map((entry) => entry.value(point))));
  const scale = frame(points, CHART.priceHeight, niceCeiling(highest * 1.05), axisMoney, true);
  for (const entry of series) {
    for (let index = 1; index < points.length; index++) {
      const from = points[index - 1] as PricePoint;
      const to = points[index] as PricePoint;
      scale.svg.append(
        el("line", {
          class: "chart-line",
          stroke: entry.color,
          x1: scale.x(from.day),
          y1: scale.y(entry.value(from)),
          x2: scale.x(to.day),
          y2: scale.y(entry.value(to)),
        }),
      );
    }
    for (const point of points) {
      scale.svg.append(
        el("rect", { class: "chart-marker", fill: entry.color, x: scale.x(point.day) - 2, y: scale.y(entry.value(point)) - 2, width: 4, height: 4 }),
      );
    }
  }
  hover(scale.svg, points, scale, onHover);
  return scale.svg;
}

// Bars of units for sale each day. A separate chart, so prices and amounts
// never share an axis.
export function unitsChart(points: PricePoint[], color: string, onHover: (point: PricePoint | null, x: number) => void): SVGElement {
  const highest = Math.max(1, ...points.map((point) => point.units));
  const scale = frame(points, CHART.unitsHeight, niceCeiling(highest), (value) => Math.round(value).toLocaleString("en-US"), false, 2);
  const span = Math.max(1, (points[points.length - 1]?.day ?? 0) - (points[0]?.day ?? 0));
  const barWidth = Math.max(2, Math.min(14, (scale.plotRight - CHART.left) / (span + 1) - 2));
  for (const point of points) {
    const top = scale.y(point.units);
    scale.svg.append(
      el("rect", { class: "chart-bar", fill: color, x: scale.x(point.day) - barWidth / 2, y: top, width: barWidth, height: Math.max(1, scale.plotBottom - top) }),
    );
  }
  hover(scale.svg, points, scale, onHover);
  return scale.svg;
}

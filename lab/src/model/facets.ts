// Applies ticked facet boxes to a list of items.
import type { Facet, FacetOption } from "../config/facets";
import type { MarketItem } from "./market";

// facet id -> the values ticked in it. A facet with nothing ticked filters nothing.
export type FacetSelection = Map<string, Set<string>>;

export function optionsOf(facet: Facet, items: MarketItem[]): FacetOption[] {
  return typeof facet.options === "function" ? facet.options(items) : facet.options;
}

// Where a facet's refine toggles are kept in the selection.
export function refineKey(facetId: string): string {
  return `${facetId}/refine`;
}

export function applyFacets(items: MarketItem[], facets: Facet[], selection: FacetSelection): MarketItem[] {
  const ticked = (key: string): Set<string> => selection.get(key) ?? new Set<string>();
  const refining = (facet: Facet): boolean => facet.refine !== undefined && ticked(refineKey(facet.id)).size > 0;

  // Group the facets that are in play by dimension. An item must satisfy every
  // dimension, and satisfies one by matching any facet in it. A facet whose
  // refine toggles are on is in play even with no boxes ticked: it then means
  // the whole group.
  const dimensions = new Map<string, Facet[]>();
  for (const facet of facets) {
    if (ticked(facet.id).size === 0 && !refining(facet)) continue;
    const key = facet.dimension ?? facet.id;
    dimensions.set(key, [...(dimensions.get(key) ?? []), facet]);
  }
  if (dimensions.size === 0) return items;

  const matches = (facet: Facet, item: MarketItem): boolean => {
    const value = facet.read(item);
    if (value === null) return false;
    const boxes = ticked(facet.id);
    if (boxes.size > 0 && !boxes.has(value)) return false;
    if (facet.refine && refining(facet)) {
      const refined = facet.refine.read(item);
      // The toggles have nothing to say about this item (a ring has no body
      // slot). Keep it only when its box was ticked on purpose.
      if (refined === null) return boxes.size > 0;
      return ticked(refineKey(facet.id)).has(refined);
    }
    return true;
  };

  const groups = [...dimensions.values()];
  return items.filter((item) => groups.every((group) => group.some((facet) => matches(facet, item))));
}

export function toggleFacetValue(selection: FacetSelection, facetId: string, value: string, on: boolean): void {
  const values = selection.get(facetId) ?? new Set<string>();
  if (on) values.add(value);
  else values.delete(value);
  selection.set(facetId, values);
}

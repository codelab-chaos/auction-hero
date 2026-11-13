// Facets: the collapsible checkbox groups down the side of the Buy tab, as data.
//
// Ticking boxes in one group means "any of these". Groups normally combine as
// "and", except groups that share a dimension: those are one question asked in
// several places, so they combine as "any of these" too. Armor and Weapons
// share the "type" dimension, so ticking Leather and Swords shows both.
//
//   read       the value of an item for this facet, or null when it has none
//   options    the boxes to offer. A function builds them from the scan, for
//              facets whose values depend on the data. A facet with no
//              options is not shown.
//   open       whether the group starts expanded
//   dimension  see above. Defaults to the facet's own id
//   selectAll  gives the group's header its own checkbox that ticks every box
//              in it, so "all Recipes" is one click
//   flat       no header and no expander: the group's boxes sit straight in
//              the column. For categories too small to hide behind a click
//   placement  "rail" puts the facet in the narrow strip at the far left as a
//              stack of square tiles: a checkbox drawn over a color or an
//              icon, named by its tooltip. Anything else goes in the sidebar
//   refine     on/off toggles that narrow only the group's own items. Armor
//              uses them for body slots: Feet, Chest and so on. Turning one on
//              with nothing ticked means the whole group. Items a toggle has
//              nothing to say about (a ring has no body slot) are left alone
//              when their box is ticked, and left out otherwise.
import type { MarketItem } from "../model/market";
import { QUALITIES } from "./catalog";

export interface FacetOption {
  value: string;
  label: string;
  color?: string;
  icon?: number | null; // an icon file id to show beside the label
  inRail?: boolean; // drawn as a tile in the left strip, so left out of the group's list
}

export interface Facet {
  id: string;
  label: string;
  open: boolean;
  dimension?: string;
  selectAll?: boolean;
  flat?: boolean;
  placement?: "rail";
  // For rail facets: "swatch" draws half-height color bars instead of square
  // tiles. Good for a plain color key, where there is no icon to show.
  tileShape?: "swatch";
  refine?: FacetRefine;
  read: (item: MarketItem) => string | null;
  options: FacetOption[] | ((items: MarketItem[]) => FacetOption[]);
}

export interface FacetRefine {
  label: string;
  // "rail" draws the toggles as tiles in the left strip instead of inside the
  // group. They behave the same either way: they narrow only this group.
  placement?: "rail";
  read: (item: MarketItem) => string | null;
  options: FacetOption[];
  // For toggles drawn as icon tiles: true for the items that picture a toggle
  // best. The tile uses the most-listed of those, or of anything if none match.
  pictures?: (item: MarketItem, value: string) => boolean;
}

// The auction house's own top-level categories, mostly in its order. classIds are
// the game's item class ids (Enum.ItemClass).
//
//   slots      only items worn in these equip slots belong to the category
//   notSlots   items worn in these equip slots do not
//   boxes      the checkboxes to offer instead of the game's raw subtypes. An
//              item goes in the first box it fits. Items that fit none keep
//              their own subtype as a box
//   keepOrder  list the boxes in the order written, not most common first
//   iconSlots  which equip slot best pictures a box: a chest piece shows
//              "Leather" better than a belt
export interface ItemCategory {
  id: string;
  label: string;
  classIds: number[];
  flat?: boolean; // its boxes sit straight in the column, no expander
  slots?: string[];
  notSlots?: string[];
  boxes?: SubtypeBox[];
  keepOrder?: boolean;
  iconSlots?: string[];
  refine?: FacetRefine;
}

// One checkbox that gathers items by subtype, by equip slot, or by both.
export interface SubtypeBox {
  label: string;
  inRail?: boolean; // shown as a tile in the left strip instead of in the group
  subClassIds?: number[];
  slots?: string[];
}

function fitsBox(box: SubtypeBox, item: MarketItem): boolean {
  if (box.subClassIds && !box.subClassIds.includes(item.subClassId ?? -1)) return false;
  if (box.slots && !box.slots.includes(item.equipLoc ?? "")) return false;
  return true;
}

// ========= Armor ============================================================
// The eight body slots. Only these have a material (cloth, leather, mail, plate).
const BODY_SLOTS: { label: string; slots: string[] }[] = [
  { label: "Head", slots: ["INVTYPE_HEAD"] },
  { label: "Shoulder", slots: ["INVTYPE_SHOULDER"] },
  { label: "Chest", slots: ["INVTYPE_CHEST", "INVTYPE_ROBE"] }, // a robe is a chest piece
  { label: "Waist", slots: ["INVTYPE_WAIST"] },
  { label: "Legs", slots: ["INVTYPE_LEGS"] },
  { label: "Feet", slots: ["INVTYPE_FEET"] },
  { label: "Wrist", slots: ["INVTYPE_WRIST"] },
  { label: "Hands", slots: ["INVTYPE_HAND"] },
];
const BODY_SLOT_NAMES = BODY_SLOTS.flatMap((entry) => entry.slots);

// The game has one Armor class. We show it as two categories:
//   Armor        what you wear on the eight body slots, where material applies
//   Accessories  everything else the game calls armor: cloaks, jewelry,
//                off-hand items, shields, shirts, tabards and relics
// The game files every cloak as Cloth, which is why the split is by slot and
// not by the game's own subtypes.
const ARMOR_BOXES: SubtypeBox[] = [
  { label: "Cloth", subClassIds: [1] },
  { label: "Leather", subClassIds: [2] },
  { label: "Mail", subClassIds: [3] },
  { label: "Plate", subClassIds: [4] },
];

const ACCESSORY_BOXES: SubtypeBox[] = [
  { label: "Cloaks", slots: ["INVTYPE_CLOAK"] },
  { label: "Neck", slots: ["INVTYPE_NECK"] },
  { label: "Finger", slots: ["INVTYPE_FINGER"] },
  { label: "Trinket", slots: ["INVTYPE_TRINKET"] },
  { label: "Off-hand", slots: ["INVTYPE_HOLDABLE"] },
  { label: "Shield", slots: ["INVTYPE_SHIELD"], inRail: true },
  { label: "Shirt", slots: ["INVTYPE_BODY"] },
  { label: "Tabard", slots: ["INVTYPE_TABARD"] },
  { label: "Relics", subClassIds: [7, 8, 9] }, // libram, idol, totem
];

const BODY_SLOT_OF = new Map(BODY_SLOTS.flatMap((entry) => entry.slots.map((slot) => [slot, entry.label] as const)));

// Slot toggles for the Armor category, as icon tiles in the left strip.
const ARMOR_SLOT_REFINE: FacetRefine = {
  label: "Armor",
  placement: "rail",
  read: (item) => BODY_SLOT_OF.get(item.equipLoc ?? "") ?? null,
  options: BODY_SLOTS.map((entry) => ({ value: entry.label, label: entry.label })),
};

// ========= Weapons ==========================================================
// The game splits swords, axes and maces into one-handed and two-handed
// subtypes. The Weapons group shows each as one kind of weapon, and the
// hand toggles do the splitting.
const WEAPON_BOXES: SubtypeBox[] = [
  { label: "Swords", subClassIds: [7, 8] },
  { label: "Axes", subClassIds: [0, 1] },
  { label: "Maces", subClassIds: [4, 5] },
];

// How a weapon is held, read from its equip slot. Ranged weapons are neither,
// so the hand toggles leave them alone.
// pictureSubClass is the weapon subtype whose icon stands for the toggle: a
// one-handed sword for One-hand, a two-handed axe for Two-hand, so the two
// tiles look different at a glance.
const WEAPON_HANDS: { label: string; slots: string[]; pictureSubClass: number }[] = [
  { label: "One-hand", slots: ["INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND"], pictureSubClass: 7 },
  { label: "Two-hand", slots: ["INVTYPE_2HWEAPON"], pictureSubClass: 1 },
];

const WEAPON_HAND_OF = new Map(WEAPON_HANDS.flatMap((entry) => entry.slots.map((slot) => [slot, entry.label] as const)));

const WEAPON_HAND_REFINE: FacetRefine = {
  label: "Weapons",
  placement: "rail",
  read: (item) => WEAPON_HAND_OF.get(item.equipLoc ?? "") ?? null,
  options: WEAPON_HANDS.map((entry) => ({ value: entry.label, label: entry.label })),
  pictures: (item, value) => WEAPON_HANDS.some((entry) => entry.label === value && entry.pictureSubClass === item.subClassId),
};

export const ITEM_CATEGORIES: ItemCategory[] = [
  { id: "weapons", label: "Weapons", classIds: [2], boxes: WEAPON_BOXES, refine: WEAPON_HAND_REFINE },
  {
    id: "armor",
    label: "Armor",
    classIds: [4],
    slots: BODY_SLOT_NAMES,
    boxes: ARMOR_BOXES,
    keepOrder: true,
    iconSlots: ["INVTYPE_CHEST", "INVTYPE_ROBE"],
    refine: ARMOR_SLOT_REFINE,
  },
  { id: "accessories", label: "Accessories", classIds: [4], notSlots: BODY_SLOT_NAMES, boxes: ACCESSORY_BOXES, keepOrder: true },
  { id: "containers", label: "Containers", classIds: [1, 11] }, // bags, and quivers and ammo pouches
  { id: "consumables", label: "Consumables", classIds: [0] },
  { id: "trade-goods", label: "Trade Goods", classIds: [7, 5] }, // and reagents
  { id: "recipes", label: "Recipes", classIds: [9] },
  { id: "misc", label: "Miscellaneous", classIds: [15, 13] }, // and keys
  // The categories whose boxes sit straight in the column go last, under the ones that expand.
  { id: "projectile", label: "Projectile", classIds: [6], flat: true },
  { id: "quest", label: "Quest Items", classIds: [12], flat: true },
];

// Which box of its category an item belongs in: its value, label and place in
// the written order. Null when the item is not in the category at all.
function boxOf(
  category: ItemCategory,
  item: MarketItem,
): { value: string; label: string; order: number; inRail?: boolean } | null {
  if (item.classId === null || !category.classIds.includes(item.classId)) return null;
  if (category.slots && !category.slots.includes(item.equipLoc ?? "")) return null;
  if (category.notSlots && category.notSlots.includes(item.equipLoc ?? "")) return null;
  const boxes = category.boxes ?? [];
  const index = boxes.findIndex((box) => fitsBox(box, item));
  const box = boxes[index];
  if (box) return { value: `${category.id}:${box.label}`, label: box.label, order: index, inRail: box.inRail };
  return { value: `${item.classId}:${item.subClassId ?? 0}`, label: item.subType ?? "Other", order: boxes.length };
}

// One box per group of a category, each pictured by its most-listed item
// (from a preferred slot when there is one).
function boxOptions(category: ItemCategory) {
  return (items: MarketItem[]): FacetOption[] => {
    const groups = new Map<
      string,
      { count: number; label: string; order: number; inRail?: boolean; best: MarketItem; preferred: boolean }
    >();
    for (const item of items) {
      const box = boxOf(category, item);
      if (!box) continue;
      const preferred = category.iconSlots?.includes(item.equipLoc ?? "") ?? false;
      const group = groups.get(box.value);
      if (!group) {
        groups.set(box.value, { count: 1, label: box.label, order: box.order, inRail: box.inRail, best: item, preferred });
        continue;
      }
      group.count++;
      const better = preferred === group.preferred ? item.listings > group.best.listings : preferred;
      if (better && item.icon !== null) {
        group.best = item;
        group.preferred = preferred;
      }
    }
    return [...groups.entries()]
      .sort((a, b) => (category.keepOrder && a[1].order !== b[1].order ? a[1].order - b[1].order : b[1].count - a[1].count))
      .map(([value, group]) => ({ value, label: group.label, icon: group.best.icon, inRail: group.inRail }));
  };
}

// The group for one auction house category. They all share the "type"
// dimension, so ticking boxes in several categories shows all of them.
function categoryFacet(category: ItemCategory): Facet {
  return {
    id: category.id,
    label: category.label,
    open: false,
    dimension: "type",
    selectAll: true,
    flat: category.flat,
    refine: category.refine,
    read: (item) => boxOf(category, item)?.value ?? null,
    options: boxOptions(category),
  };
}

export const BUY_FACETS: Facet[] = [
  ...ITEM_CATEGORIES.map(categoryFacet),
  {
    id: "quality",
    label: "Quality",
    open: false,
    placement: "rail",
    tileShape: "swatch",
    read: (item) => (item.quality === null ? null : String(item.quality)),
    options: QUALITIES.filter((quality) => quality.id <= 4).map((quality) => ({
      value: String(quality.id),
      label: quality.label,
      color: quality.color,
    })),
  },
];

// The left strip, top to bottom, as sections with a divider between them.
// An entry is one of:
//   { facet }       every box of a facet placed in the rail
//   { refine }      the toggles of that facet's refine
//   { box, of }     one box of a facet, by its label
export type RailEntry = { facet: string } | { refine: string } | { box: string; of: string };

export const BUY_RAIL: RailEntry[][] = [
  [{ facet: "quality" }],
  // What goes in your hands: the two weapon holds, then shields.
  [{ refine: "weapons" }, { box: "Shield", of: "accessories" }],
  [{ refine: "armor" }],
];

// Names and rules of thumb for the values a scan holds, as data.

export interface Quality {
  id: number;
  label: string;
  color: string;
}

export const QUALITIES: Quality[] = [
  { id: 0, label: "Poor", color: "#9d9d9d" },
  { id: 1, label: "Common", color: "#e8e8e8" },
  { id: 2, label: "Uncommon", color: "#1eff00" },
  { id: 3, label: "Rare", color: "#3b9dff" },
  { id: 4, label: "Epic", color: "#b65cff" },
  { id: 5, label: "Legendary", color: "#ff8000" },
];

export const QUALITY_BY_ID = new Map(QUALITIES.map((quality) => [quality.id, quality]));

// The scan has one "level" number per item, but it means a different thing
// depending on levelType: a required character level, a profession skill, or
// a bag's slot count. Each meaning gets its own column so they never mix.
export interface LevelType {
  id: string;
  label: string; // the group of items it marks
  column: string; // header of its column
  name: string; // what the number is, in full
}

export const LEVEL_TYPES: LevelType[] = [
  { id: "REQ_LEVEL_ABBR", label: "Gear and goods", column: "Level", name: "Required level" },
  { id: "SKILL_ABBR", label: "Recipes", column: "Skill", name: "Required skill" },
  { id: "SLOT_ABBR", label: "Bags", column: "Slots", name: "Bag slots" },
];

export const LEVEL_TYPE_BY_ID = new Map(LEVEL_TYPES.map((type) => [type.id, type]));

// The level type the Find screen's level range filters on.
export const CHARACTER_LEVEL_TYPE = "REQ_LEVEL_ABBR";

// The item's number for one meaning of "level", or null when it has another.
export function levelOf(item: { level: number | null; levelType: string | null }, typeId: string): number | null {
  return item.levelType === typeId ? item.level : null;
}

export const TIME_BANDS: Record<number, string> = {
  1: "Short",
  2: "Medium",
  3: "Long",
  4: "Very long",
};

export const EQUIP_SLOTS: Record<string, string> = {
  INVTYPE_HEAD: "Head",
  INVTYPE_NECK: "Neck",
  INVTYPE_SHOULDER: "Shoulder",
  INVTYPE_BODY: "Shirt",
  INVTYPE_CHEST: "Chest",
  INVTYPE_ROBE: "Chest",
  INVTYPE_WAIST: "Waist",
  INVTYPE_LEGS: "Legs",
  INVTYPE_FEET: "Feet",
  INVTYPE_WRIST: "Wrist",
  INVTYPE_HAND: "Hands",
  INVTYPE_FINGER: "Finger",
  INVTYPE_TRINKET: "Trinket",
  INVTYPE_CLOAK: "Back",
  INVTYPE_WEAPON: "One-hand",
  INVTYPE_SHIELD: "Shield",
  INVTYPE_2HWEAPON: "Two-hand",
  INVTYPE_WEAPONMAINHAND: "Main hand",
  INVTYPE_WEAPONOFFHAND: "Off hand",
  INVTYPE_HOLDABLE: "Held in off-hand",
  INVTYPE_RANGED: "Ranged",
  INVTYPE_RANGEDRIGHT: "Ranged",
  INVTYPE_THROWN: "Thrown",
  INVTYPE_AMMO: "Ammo",
  INVTYPE_RELIC: "Relic",
  INVTYPE_BAG: "Bag",
  INVTYPE_QUIVER: "Quiver",
  INVTYPE_TABARD: "Tabard",
};

// Commodities are bought by the unit: ask for 40 and you get exactly 40, from
// the cheapest sellers up, in one purchase. Everything else is bought one
// whole auction at a time.
//
// The scan says which items are commodities when the game had the answer
// ready. For the rest we go by item class, which matched the known answers on
// a real scan (trade goods 118 to 2, weapons and armor none).
export const COMMODITY_CLASS_IDS = new Set([0, 5, 6, 7, 12, 15]); // consumable, reagent, projectile, trade goods, quest, miscellaneous

export function isCommodity(item: { commodity: boolean | null; classId: number | null }): boolean {
  return item.commodity ?? (item.classId !== null && COMMODITY_CLASS_IDS.has(item.classId));
}

// Things we assume because the scan cannot tell us. Shown in the lab wherever
// a number depends on them.
export const ASSUMPTIONS = {
  // Share of a sale the auction house keeps. 5% is the Classic rule; not yet
  // confirmed on Forever.
  auctionCut: 0.05,
};

// An item is flagged as a deal when its lowest price sits this far under its
// median and it has at least this many listings (the addon uses the same rule).
export const DEAL_RULE = { percent: 30, minListings: 3 };

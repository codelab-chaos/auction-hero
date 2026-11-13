// The shape of the files scripts/import-scan.mjs writes.

export interface ScanMeta {
  source: string;
  sourceLabel: string;
  time: number; // server time, seconds
  elapsed: number;
  place: string; // realm / faction
  build: string;
  rows: number; // auctions in the scan, before collapsing copies
  incompleteRows: number; // rows whose name never arrived
  hasItemTypes: boolean; // false for scans made before the addon exported types
  stale?: boolean; // the server did not return a fresh list
  timeLeftBands?: Record<string, { min: number; max: number | null }>;
}

export interface ItemRecord {
  key: string; // item id + name, the identity of a variant
  id: number;
  name: string | null; // null when the row's data never arrived
  quality: number | null;
  level: number | null;
  levelType: string | null; // what "level" means, see config/catalog.ts
  icon: number | null; // icon file id, also the file name in public/icons
  usable: boolean; // usable by the character that ran the scan
  link: string | null; // the item link's payload, which carries bonus ids
  type: string | null;
  subType: string | null;
  equipLoc: string | null;
  classId: number | null;
  subClassId: number | null;
  commodity: boolean | null; // bought by the unit rather than by the auction. null when unknown
}

// [itemIndex, count, buyout, minBid, bid, timeLeft, copies]
// buyout is for the whole stack. copies is how many identical auctions there were.
export type ListingTuple = [number, number, number, number, number, number, number];

export interface ScanFile {
  meta: ScanMeta;
  items: ItemRecord[];
  listings: ListingTuple[];
}

export interface ScanSummary extends ScanMeta {
  file: string;
  items: number;
  listings: number;
}

export interface ScanIndex {
  scans: ScanSummary[];
}

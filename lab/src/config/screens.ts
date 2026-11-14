// The lab's screens, as data. Add an entry and it appears as a tab.
import type { LabContext, Screen } from "../ui/context";
import { createCornerScreen } from "../ui/screens/corner";
import { createFlipsScreen } from "../ui/screens/flips";
import { createNewsScreen } from "../ui/screens/news";
import { createConceptScreen } from "../ui/screens/concept";
import { createFindScreen } from "../ui/screens/find";
import { createResellScreen } from "../ui/screens/resell";
import { createPossibleSalesScreen } from "../ui/screens/possible-sales";

export interface ScreenDefinition {
  id: string;
  label: string;
  blurb: string;
  create: (ctx: LabContext) => Screen;
}

export const SCREENS: ScreenDefinition[] = [
  { id: "concept", label: "Concept", blurb: "The in-game window, mocked up", create: createConceptScreen },
  { id: "flips", label: "Flips", blurb: "Cheap listings that resell fast at the going rate", create: createFlipsScreen },
  { id: "corner", label: "Corner", blurb: "Sought-after items whose cheap supply you can buy out", create: createCornerScreen },
  { id: "news", label: "News", blurb: "Headlines, and the items for sale they name", create: createNewsScreen },
  { id: "find", label: "Find", blurb: "Items you can use and afford", create: createFindScreen },
  { id: "resell", label: "Resell", blurb: "Cheap listings worth flipping", create: createResellScreen },
  { id: "possible-sales", label: "Possible sales", blurb: "Listings missing between scans, at their last asking price", create: createPossibleSalesScreen },
];

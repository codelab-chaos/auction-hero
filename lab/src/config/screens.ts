// The lab's screens, as data. Add an entry and it appears as a tab.
import type { LabContext, Screen } from "../ui/context";
import { createConceptScreen } from "../ui/screens/concept";
import { createFindScreen } from "../ui/screens/find";
import { createPostScreen } from "../ui/screens/post";
import { createResellScreen } from "../ui/screens/resell";

export interface ScreenDefinition {
  id: string;
  label: string;
  blurb: string;
  create: (ctx: LabContext) => Screen;
}

export const SCREENS: ScreenDefinition[] = [
  { id: "concept", label: "Concept", blurb: "The in-game window, mocked up", create: createConceptScreen },
  { id: "find", label: "Find", blurb: "Items you can use and afford", create: createFindScreen },
  { id: "post", label: "Post", blurb: "Try pricing rules against the ladder", create: createPostScreen },
  { id: "resell", label: "Resell", blurb: "Cheap listings worth flipping", create: createResellScreen },
];

// The screen that works on one chosen item, for "Post this" buttons.
export const POST_SCREEN_ID = "post";

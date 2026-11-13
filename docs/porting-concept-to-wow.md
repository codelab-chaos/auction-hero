# Porting the concept UI to WoW

## Objective and current status

Reproduce the existing **Concept** window in Nitro Lab as closely as WoW's UI renderer permits, with working auction-house functionality. The lab is the specification for the arrangement of controls, selection behavior, filtering, colors, spacing, and information shown to the player.

This document is the implementation plan. Writing it does not change the lab, the addon, or the deployed game files. The checkpoint before this plan is `f65e573`.

The current native UI is a functional first pass with substantial visual and behavioral differences. In particular, its stock red buttons, single-selection categories, missing filter rail, different column widths, and relocated controls do not reproduce the concept. Those choices will be corrected using the existing prototype code.

The visual reference is [ui-good.png](docs/img-barn/ui-good.png). [ui-bad.png](docs/img-barn/ui-bad.png) records the native implementation that needs correction.

## 1. Use the lab code as the specification

The port will follow these files directly:

| Lab source | What must carry into the addon |
| --- | --- |
| `lab/src/config/concept.ts` | 900 × 600 window, tabs, quick toggles, sale types, durations, defaults, resell margins and limits |
| `lab/src/ui/screens/concept.ts` | Title bar, gold display, tab selection, page lifecycle |
| `lab/src/ui/concept/buy.ts` | Four-column Buy layout, rail tiles, expanding categories, search row, item list and order panel |
| `lab/src/config/facets.ts` | Category order, category boxes, equipment refinements, representative icons and rail sections |
| `lab/src/model/facets.ts` | Exact combination rules for checkbox selections and refinements |
| `lab/src/ui/concept/sell.ts` | Bag grid, sale buttons, price entry, price-rule buttons, sliders, summary and competition ladder |
| `lab/src/ui/concept/resell.ts` | Discount segments, profit filter, deal filters, table and Buy → Relist → Keep plan |
| `lab/src/model/orders.ts`, `pricing.ts`, `resell.ts`, `signals.ts` | Order costs, stack handling, price suggestions, resell calculations and meters |
| `lab/src/config/catalog.ts`, `price-rules.ts`, `signals.ts` | Item labels, pricing rules, thresholds, assumptions and signal levels |
| `lab/src/ui/dom.ts`, `table.ts`, `meter.ts` | Money formatting, icons, sorting, selection, tooltips and meter presentation |
| `lab/src/styles.css` | Effective geometry, colors, borders, gradients, typography and interaction states |

CSS must be read in cascade order. Later declarations change earlier layouts: the final Buy layout has **four columns**, and the final concept palette is brown and gold. Copying an earlier three-column rule would reproduce the same mistake.

The outer Nitro Lab shell is separate from the Concept window. The SPA's scan-date selector, simulated dates, historical analysis screens and header configuration are not additional rows to insert into the in-game window.

### How the source becomes Lua

WoW runs Lua and native UI objects; it does not execute the lab's TypeScript and CSS. I will translate the existing component tree and model functions into those native objects while retaining their structure and behavior.

Plain configuration will be carried over systematically. A build-time export can read the lab's existing TypeScript configuration and produce checked-in Lua tables for labels, categories, class IDs, box definitions, defaults and thresholds. Function-based rules will be translated explicitly and checked against the TypeScript implementation using shared fixtures. The addon will run independently of Node and Nitro Lab.

The lab files will remain unchanged during this port. Native API differences will be handled in the addon adapters rather than by changing the prototype to match the current addon.

## 2. Establish geometry and a shared visual theme first

Before rebuilding the tabs, create one native theme and component layer corresponding to the concept's CSS. All three tabs will use it.

### Geometry

Use a 900 × 600 logical-unit window at a controlled scale. Compare it with the browser concept at the same displayed size; an in-game UI scale can make 900 logical units occupy a different number of screenshot pixels.

| Area | Prototype geometry to preserve |
| --- | --- |
| Window | 900 × 600; compact title bar; tabs immediately below |
| Body | 8px padding and 8px column gaps |
| Buy | 34px rail, 176px category panel, flexible item list, 250px order panel |
| Sell | 200px bags, flexible form, 230px competition panel |
| Resell | Flexible list and toolbar, 290px plan panel |
| Bag slots | Four columns of 40px slots, with 4px gaps |
| Rail tiles | 26px icon tiles; 12px-high quality swatches |
| Buy toolbar | Search and all three quick toggles share one row |

For a 900px outer width with 2px borders, the Buy grid has approximately 880px after its horizontal padding. The specified columns and gaps leave approximately 396px for the center. These relationships will be preserved instead of assigning unrelated widths to the native panels.

Exact title height, tab height, text baselines, row heights and padding will be measured from the rendered lab. A large permanent footer will not consume space that belongs to the prototype's body. Scan details can remain in Data, with concise progress or error feedback when needed.

### Palette and materials

Use the final concept colors from `styles.css`:

| Role | Value |
| --- | --- |
| Window background | `#120e0a` |
| Panel background | `#1c1611` |
| Secondary background / table header | `#2a2018` |
| Panel divider | `#4a3a26` |
| Primary text | `#f2e8d5` |
| Muted text | `#a8977a` |
| Accent | `#ffd100` |
| Outer border | `#8a6a2f` |
| Input background / border | `#0d0a07` / `#5c4526` |
| Title gradient | `#3a2a16` → `#1f160c` |
| Ordinary control gradient | `#3a2c1c` → `#241a10` |
| Active tab gradient | `#5a431c` → `#33260f` |

Custom frame textures and font strings will reproduce the panels, gradients, thin borders, tabs and controls. Rounded corners and subtle edges can use a small bundled texture atlas where native primitives are insufficient. Texture/font availability and rendering will be checked in the Forever client.

The default `UIPanelButtonTemplate` will not define the appearance of category controls or tabs. Red is reserved for the primary trading actions, matching `.cw-action` in the prototype. The selected tab will be gold and remain an enabled control; it will not look disabled.

Typography will follow the concept's readable sans-serif appearance, sizes, hierarchy and alignment. A suitable client font will be selected and checked in-game, rather than assuming the default button font looks equivalent. Exact font rasterization may differ between browser and game; geometry and hierarchy should still match.

### Shared native components

The component layer will provide themed panels, tabs, toggle buttons, checkbox headers, expandable groups, icon tiles, inputs, segmented choices, sliders, money inputs, tables, tooltips and meters. Each needs normal, hover, selected, focused and disabled states where applicable.

Tables will preserve column alignment, sort arrows, truncated long names, item icons, quality colors, selected rows and deal badges. Scrollable lists will reuse visible row frames so large scans do not create a frame for every listing. Long sidebars and order panels must scroll without moving the window's navigation.

## 3. Port Buy directly

### Left rail and category panel

Reproduce the rail sections in `BUY_RAIL`: quality swatches; weapon-hand and shield tiles; then armor-slot tiles. Representative item icons will follow the prototype's preference and popularity rules.

Reproduce category headers with a checkbox, category name, selection count when applicable, and a separate expand/collapse control. Expanded groups show the actual configured subtype boxes. Projectile and quest groups retain their flat presentation. Shield stays in the rail where configured. Clear all appears when selections exist.

Preserve the logic in `applyFacets`:

- Choices inside one group combine as OR.
- Categories sharing the `type` dimension also combine as OR; selecting Leather and Swords shows both.
- Different dimensions, such as type and quality, combine as AND.
- A refinement narrows its own category and can activate that category without selecting a subtype.
- A refinement with no meaning for an item follows the prototype's explicit-selection behavior.

The previous category buttons and generic subtype/slot dropdowns will be replaced by this actual interaction model.

### Search, list and order panel

Keep Search, I can use, I can afford and Deals on one compact row. Preserve the prototype's table columns: Item, Lvl, Avail, Price and the deal badge. Required level applies only to the appropriate level type. Selecting an item highlights its row and starts an order of one unit.

The right panel owns quantity, minus/plus/All controls, total, average price, deal reading, saving or extra cost, order lines and the purchase action. Quantity will not sit underneath the center table. The unselected state will match the prototype's quiet centered prompt; purchase controls stay hidden until an item is selected.

`fillOrder` is the reference for whole-auction versus commodity quantities, stack rounding, shortages and total cost. Its outputs will be matched before connecting live purchases.

## 4. Port Sell directly

Preserve the bag grid on the left, the form in the center and the competition ladder on the right. Replace only the prototype's pretend bag provider with real player inventory. Multiple slots holding the same variant contribute to the same owned total while retaining their individual bag icons and counts.

The form will follow the prototype's order:

1. Selected item's icon, name and owned quantity.
2. Sale-type choices: Buy now, Buy now + bids, Bids only.
3. Gold/silver/copper price entry.
4. The five price-rule buttons, with the prototype's labels and tooltips.
5. Starting-bid entry when the selected sale type needs it.
6. Price-confidence meter and facts.
7. Each-auction and auction-count sliders with bounded values.
8. Duration choices.
9. Posting/keeping quantities, proceeds and the Post action.

Changing a rule resets the custom price; entering a custom price overrides the rule. Sliders update each other's valid ranges and the summary. The competition ladder inserts the green “You” row at the chosen price and reports the units ahead, as `renderLadder` does.

Real commodity posting has different capabilities from a pretend bag of stack auctions. The UI will use the client's commodity classification, present a combined quantity/unit price where required, and avoid offering unsupported bid modes. Any necessary difference will be confined to those controls and explained concisely beside them. Item auctions retain the prototype's stack and auction-count controls; each submitted auction requires its own user action.

Deposits will come from the client API. Duration labels will remain Short/Medium/Long until Forever's actual durations are verified. The assumed auction cut will remain identified in the proceeds label.

## 5. Port Resell directly

Reproduce the prototype's single toolbar: Discount with joined 15%/30%/50% buttons, compact Min profit input, I can afford, and Top deals. Preserve its defaults, rather than starting with a different budget or auction-count limit.

Use the same table columns and filtering: Item, Deal meter, Buy units, Cost and Profit. The minimum deal reading and stronger Top deals threshold come from the lab configuration.

The right panel will reproduce the numbered plan:

1. **Buy:** auction-count controls, next-auction action, price confidence, average unit cost and purchase cost.
2. **Relist:** target unit price and projected revenue after the assumed cut.
3. **Keep:** profit and return on spending.

Competition and auction details follow the plan. Choosing fewer auctions recalculates the plan without moving the settings into a different part of the layout. Clicking a lead resets its requested count in the same way as the lab.

## 6. Connect game data and working actions

The native views will consume a stable model corresponding to `LabContext` and the lab market objects. The adapter supplies the current market, actual player gold, inventory, history, selection and action state. It will translate field names such as `id`/`itemID` and `classId`/`classID` consistently.

Existing `store.lua`, scan fetchers, price history and `trade.lua` are candidates for reuse after verification. Their current behavior is not assumed correct simply because it already exists. Model parity tests will check item identity, collapsed copy counts, unit prices, weighted medians, order costs, resell calculations, confidence levels and threshold behavior against the TypeScript source.

### Resolve the empty market separately

The “No scan yet” state in `ui-bad` has not been diagnosed. Before changing or clearing saved data, trace:

- Which saved snapshot exists and whether it has rows and a supported schema.
- Whether the full replicate snapshot remains accessible when browse data is active.
- When initialization, analysis jobs and `ANALYSIS_READY` occur.
- Whether a failed analysis or early realm/faction check hides an otherwise valid market.
- Whether the market belongs to the player's current realm/faction.

The UI must distinguish loading, no scan, wrong market, no filter matches and analysis failure. Valid cached data should appear without requiring an unnecessary new scan. A different market's stock must not silently appear as the current market. No fixture data will be presented as a live market, and no existing saved variables will be deleted as a workaround.

### Live purchases and posting

Cached scans provide browsing and planning. Executable actions use the live auction APIs:

| Action | Native behavior |
| --- | --- |
| Check availability | Search the selected item and match the actual variant; handle asynchronous and paged results |
| Buy an item auction | Show current quantity and buyout, revalidate the auction, and buy one whole auction on a user press |
| Buy commodities | Request a quote for the desired quantity, show its current total, and require explicit confirmation before quote expiry |
| Post | Resolve the current bag location, validate quantity and sale type, calculate deposit, then post from a user press |
| Confirm a post | Retain the reviewed parameters and require another explicit press if the client requests confirmation |
| Complete or fail | Respond to client events, refresh affected views, and show concise outcome or recovery text |

The visible action should make the next press clear: check, request quote, buy or confirm. Price changes update the reviewed total rather than silently executing at a different price. No purchase or post is initiated merely because a search, bag or quote event fired.

Closing the auction house, changing the selected item or quantity, quote expiry, insufficient funds, locked/moved bag items, throttling and client errors must leave the action state recoverable. Scan and trade requests must coordinate rather than overwrite each other's context.

## 7. Implementation order and proposed file boundaries

Keep the project in its current folder and branch. The lab remains the reference throughout.

1. Establish the source mapping, rendered measurements and repeatable comparison data.
2. Replace native widget styling with the concept theme; verify the window shell and tab states.
3. Port Buy's exact geometry, facets, rail and order panel.
4. Diagnose the missing scan and verify model parity with real cached data.
5. Port Sell's bag grid, form, sliders and competition ladder.
6. Port Resell's toolbar, table and numbered plan.
7. Connect and verify live actions through the adapter/controller.
8. Compare actual in-game screenshots and correct differences before reporting visual completion.

Proposed native responsibilities:

| File / area | Responsibility |
| --- | --- |
| `ui/theme.lua` | Colors, metrics, fonts, textures and state styling derived from the effective concept CSS |
| `ui/widgets.lua` | Reusable themed controls, tables, scrolling, money inputs and meters |
| `ui/trading-window.lua` | Window shell, selected tab, position and page lifecycle |
| `ui/tabs/buy.lua`, `sell.lua`, `resell.lua` | Direct counterparts of the three concept components |
| `data/` concept configuration | Exported/transcribed category, rail, pricing and signal definitions with source references |
| `market/` and a facet model | Pure data calculations and the translated facet selection logic |
| `inventory.lua`, `trade.lua` | Game inventory and asynchronous trading adapters |

The scan inspector stays available behind Data or `/an data`. Its controls do not dictate the appearance of the trading window.

## 8. Verification and completion criteria

### Visual checks

Use the same item data, filters, selection and window scale for the reference and native screenshots. Compare the window crop at equal size. Review overlay/difference images for geometry, while allowing for font rasterization differences.

Capture Buy unselected and selected, expanded categories, mixed category/refinement selections, Sell with its price and sliders, Resell with its selected plan, and empty/loading/error states. Inspect hover, focus, active and disabled states as well as the default appearance.

The native window is visually ready when:

- The four Buy columns have the reference proportions and spacing.
- The rail and category checkboxes behave and appear like the prototype.
- Search and quick filters remain on one row at the reference size.
- Selected tabs are visually selected rather than disabled gray buttons.
- Panel colors, title gradient, borders, text hierarchy and row density follow the final CSS.
- Item names truncate without hiding prices; icons, quality colors, sort arrows and deal badges are present.
- Sell and Resell retain their actual prototype controls and information order.
- Content scrolls within its intended panel and the navigation remains visible.
- Headers, diagnostics and explanations do not displace the working area.

### Functional checks

Run Lua syntax/startup checks and shared-fixture comparisons against the lab models. Exercise facet combinations, mixed stack sizes, low funds, missing item metadata, bag changes, quantity bounds, asynchronous responses and trading recovery.

In the actual Forever client, verify scan loading, filters, selection, tooltips, scrolling and all three tabs. Use a small item purchase, commodity purchase and post to verify the real API paths and confirmation behavior. Check that `/reload` restores saved state appropriately.

Mock tests can establish logic and construction behavior. They cannot establish in-game visual fidelity or prove that a protected trading action works in the client. Those results will be reported separately. If actual client screenshots or trading verification are unavailable, the affected parts remain explicitly unverified rather than being described as finished.

Implementation, validation and deployment will be reported as distinct states. This planning task ends with this document; it does not start the corrective port or deploy any changes.

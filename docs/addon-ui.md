# Native trading interface

The addon's default window ports the lab's 900 × 600 Buy, Sell and Resell concept to native WoW frames. Open it with `/an`, the auction-house AuctioNitro button, or the addon compartment. The window remembers its position and tab. Scan and Data stay in the compact title bar; Data (also `/an data`) opens the existing scan inspector.

- Buy: name search, category, quality, subtype, slot, required-level range, usability, affordability and deals; sortable listings, quantity, price ladder and confidence. Check current price before purchasing. Items buy one whole auction per press. Commodities request a current quote and then require a separate Buy press.
- Sell: real bag contents grouped by variant, price rules, editable gold/silver/copper prices, buyout or bid modes for items, duration, quantity, deposit and competition. Post next submits one auction per press; confirmations require another explicit press. Commodity posting uses one combined quantity and a unit buyout.
- Resell: margin, confidence, gold budget, profit and auction-count controls; projected profits and remaining competition, with the same live purchase checks as Buy. Estimates use listed prices and an assumed 5% cut, excluding deposits.

The addon reads its own in-game scans and keeps compact price history separately for each realm/faction market. It does not depend on Nitro Lab or import the SPA's simulated dates. Browse sweeps remain available for inspection; trading ladders continue to use the full scan. Raw snapshots, events and existing settings are preserved.

Native widget helpers are in `ui/widgets.lua`, the window in `ui/trading-window.lua`, live actions in `trade.lua`, bag discovery in `inventory.lua`, categories in `data/catalog.lua`, and order/resell calculations in `market/trading.lua`.

## Verification

Run `python3 tests/run-addon.py` from the project folder. It parses every addon Lua file and executes mocked-client checks for variant grouping, history isolation/deduplication, item price revalidation, quote expiry, explicit confirmations, quantity/bid/deposit validation, order calculations and native window/tab construction. No trading occurs as a result of search or quote events alone.

These checks do not replace in-game testing. After deploying, restart the client because the TOC and file list changed. Open the auction house, run `/an`, check the three tabs, and test a small purchase/post before larger trades. The precise Forever duration hours and auction cut remain unverified; deposits come from the live client API.

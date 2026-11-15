# The in-game window

The addon's window is the ahero-lab concept (`src/ui/concept` in the lab's own repository, `../ahero-lab`) rebuilt for the game: same 900 by 600 size, same tabs, same layout, colors and wording. Open it with `/ah`, the AuctionHero button on the auction house, or the minimap addon menu. It also opens with the auction house.

It is drawn from plain textures and text, not the game's stock button art, so it takes its whole look from one theme table.

## The scan is the core

Everything Auction Hero does runs off scan data. A scan is what the Buy, Sell and Resell tabs list, what the going rates, deals, price history and item tooltips are worked out from, and so what makes the auction house easier to use and easier to profit from. Keeping and loading that data is fundamental operation, never an optional extra: a scan is saved whole, and there is no switch to turn that off.

## How a scan is kept

The game answers a full scan with one row of twenty values per auction. Most of that repeats: more than half of all auctions are exact copies of another, and everything about an item is said again on every one of its auctions. So the addon keeps a scan as two lists (`listings` in `data/schemas.lua`):

- **Variants:** one entry per distinct item as it is listed, holding its name, icon, quality, level, id and link.
- **Rows:** one per distinct listing of a variant, holding the stack size, starting bid, buyout, current bid and time left, and how many identical auctions it stands for.

Left out are the seller and bidder names a full scan never fills, the sale status that is always the same, and the bid increment nothing reads. On a real scan of 223,564 auctions this is 31,568 variants and 107,015 rows, about a fifth of the size on disk.

The market the tabs read is the same whichever way the scan is kept, auction for auction and price for price. A scan saved by an earlier build still loads as it is, and the next scan is kept the new way. Code reads a row through `ns.RowReader`, which knows where each field is.

## What is there

- **Title bar:** a Scan button with how long ago the last scan was beside it (the button waits 15 minutes after a scan, the server's limit), and your gold.
- **Scan shield:** while a scan runs, a cover over the tabs stops buying, posting and cancelling against a market that is about to change. It lists the stages (ask the server, read, fill in item details, price against history) with a bar, the auctions counted, how fast, the time so far, the last scan's size and a rotating quip, and has a Cancel button (Close once pricing has started). It shows the result for a moment, then lifts. Stages and timings are in `data/scan-shield.lua`.
- **Footer:** the last thing the addon did (a scan, a post, a refusal). Hover it for the last 15.
- **Buy:** a left rail of quick toggles (one-hand, two-hand, ranged, shield, the eight armor slots, cloaks; it scrolls with the mouse wheel when the window is short), collapsible category checkboxes under a row of six square quality swatches, search with "Picks", "Use", "Afford", "Better", "Near level" and "Deals" ("Picks" also turns on "Use" and "Afford") ("Better" is gear that beats what you wear, by stats weighted for your class; "Picks" is the upgrades you can wear today, sorted by gain, biggest first, and the "Gain" column says how much better each is; "Near level" is a required level within a few levels of yours, set in Options on one row as under and over, each with arrows; both run on `data/gear.lua`), a sortable item list, and an order panel with quantity, total, the five-pip deal meter and what you save. Under the Buy button the panel shows what the scans know about the chosen item: the tooltip's lines, how many scans over how many days have seen it, its usual lowest price, its lowest ever (with how many were at that price and when), and last of all every price it is listed at now with how many are at each.
- **Sell:** your real bags as a grid (an item spread over several stacks is one choice), sale type, price in gold, silver and copper, the five price rules, price confidence with its facts line, how many to post, duration, and the competition ladder with your auctions slotted in.
- **Resell:** discount and minimum profit settings, "I can afford" and "Top deals", the list of leads, and the Buy, Relist, Keep plan.
- **Graphs:** pick an item and see its usual and lowest price as lines and the units for sale as bars, over 3, 7, 14 or 30 days, with a hover readout. It draws from the first scan, and a note says it is early until two days are in.
- **Debug:** the raw scan views and the event log. Hidden unless the debug switch is on: `/ah debug`.

## Posting

Post on the Sell tab puts the chosen item up for auction, one press per post. Picking an item asks the game for its live listings first, the same request the game's own sell form makes. The Auctions tab lists what you have up.

The server does not take a single item (gear and the like) for less than 1 silver. It does not refuse such a post, it never answers, and the auction house stops responding until you log out. The game's own form does the same. The addon will not send a price under that floor (`ns.MinItemPrice` in `data/trading.lua`). Goods sold by the unit have no floor.

## Buying

Buy on the Buy tab takes two presses, like the game's own window: the first asks the server for the live price, the second buys at it. Scan prices are never spent on. Changing the quantity or the item drops the price check.

- **Goods sold by the unit** (cloth, ore, potions): the server quotes a price for the quantity, and one purchase fills it from the cheapest sellers up.
- **Single items** (gear, recipes): the first press searches the live auctions and offers one of that exact item at the price you picked in the list (the cheapest when you picked none). If nothing is at that price any more it says so, names the cheapest now, and buys nothing. An item id covers every variant of a piece of gear, so the auction's name must match; an auction whose name cannot be read is never bought. The second press buys that one auction. Press again for the next one.

If the game sends no word after a single item is bought, the addon goes by the gold: gone means bought. If neither happens it says so and tells you to check your gold and mail, and does not claim nothing was spent.

## Finding a single item

A scan gives an item's id and name. The auction house only finds a single item by its full key: the id, and for gear the level and variant that tell "of the Elder" from "of the Owl". A key made from the id alone finds nothing on Forever, even for an item the game's own window lists. So before buying or checking a single item, the addon asks for its key the way the game's window does: it browses for the name and takes the key of the result with that id and that name (`trade/item-key.lua`). Keys are kept for the session. If the browse lists none under that name, the item is gone. Goods sold by the unit are known by their id alone and skip this step.

## Every price is shown

The Buy list never sums an item up as one price. An item's row gives how many are for sale in all ("For sale") and the lowest price ("From"). Clicking the row opens it: under it comes one row for each price the item is listed at, cheapest first, with how many are at that price and that price's own deal reading. Clicking a price picks it, and the Buy button then reads "Buy at" that price. For goods sold by the unit, which are always filled from the cheapest up, picking a price sets the quantity to everything up to and including it. Clicking the item again closes it. One item is open at a time.

## Live checks

A scan ages. Choosing an item on the Buy tab when the scan is more than 5 minutes old asks the auction house for that one item as it is now, and patches the answer in. An item checked in the last 5 minutes is not asked about again, and neither is anything while a scan is fresh. Buying an item checks it again straight away.

- **What is patched:** the item's listings in the market every tab reads (the list row, the prices under the Buy button, the tooltip, the deal reading), and its rows in the saved scan.
- **Single items:** the item is looked up by name first (see "Finding a single item"), then only that variant is brought up to date. If its search comes back complete and empty, it is taken out of the list and the saved scan, and the panel says it is no longer for sale; its price history is kept. If the item cannot be found by name at all, nothing is removed: that is not proof it is gone, so the scan's rows stand and the panel says what the lookup found.
- **The saved scan says it was patched:** `meta.patched` lists each patched item and when, because those rows are from a later moment than the rest. The lab leaves patched items out of sales pace for that reason.
- **Price history is not touched,** with one exception: a price lower than any scan has seen is recorded as the lowest ever.
- **Buy uses it:** pressing Buy on a single item within 30 seconds of its check goes straight to the confirm, with no second search. It is the same query, and a purchase names one auction at its exact buyout, so an auction that has since sold is refused by the server and nothing is spent.
- **Never guessed:** if an auction cannot be named, or only part of a long list came back, nothing is patched and the scan's own rows stand.

The panel under the Buy button says how fresh its prices are: from the scan, being checked, or checked live. Rules: `ns.LiveCheckRule` in `data/trading.lua`.

## Ledger

The Ledger tab keeps every auction house trade the character makes, for good, in the character's saved variables (`AuctionHeroCharDB.ledger`). Under the list, the totals sit as tiles: profit first and largest (green when up, red when down), then earned, spent, deposits and unsold stock, with how many sold, bought and held under them; hover a tile for what it means. Above them, the trades added up by item, or one line per trade. The tiles are data in `data/ledger.lua` (`ns.LedgerTiles`).

- **Buys and deposits** are written down when the game confirms them. The addon watches the game's own buy and post calls, so a trade made in the game's window is recorded too.
- **Sales** are read from auction house mail, the only place that states the price, the auction house's cut and the deposit handed back. Open the mailbox to bring them in. Nothing in the mailbox is touched. A mail read twice is entered once.
- **Profit** counts what was sold against the oldest units bought (first in, first out), less deposits. Units bought and not yet sold are stock at cost, not a loss. Units sold that were never bought here (farmed, crafted) cost nothing.

Not covered yet: auctions won by a bid placed earlier (only buyouts are recorded), and trades made while the addon was not loaded. The mail reading and the single-item buyout event are written from the game's documented interface and are not yet confirmed on Forever: the first invoice of each type the mailbox reports is noted in the Debug log (Copy log) to check against. Rules live in `data/ledger.lua`.

## When a price is called a deal

A deal is a price under what you would otherwise pay for the item, the baseline.

- **Today's floor:** the price reached once the cheapest fifth of the units for sale (at least two) is skipped. One stray low listing is not the price of all the others.
- **Held down by history:** once an item has three graph points, the baseline is also held to its usual lowest price, so asking prices that have crept up cannot turn an ordinary price into a deal.
- **Badge:** a list row is flagged when its cheapest price is 30% or more under the baseline, and the baseline has something behind it: past scans, or at least three different prices today.
- **Deal meter:** reads the whole order against the same baseline, so buying deeper into the ladder weakens the reading. Its tooltip says what it was measured against.

Nothing here knows what actually sold: these are asking prices, and the meter says so. Rules: `ns.BaselineRule`, `ns.DealBadgeRule` and `ns.DealRule` in `data/trading.lua`. The lab uses the same rules (`src/config/catalog.ts` in `../ahero-lab`).

## Item tooltips

Hovering an item anywhere in the game (bags, chat links, the auction house) adds a short Auction Hero block to its tooltip.

- **Lowest:** the cheapest price it is listed at, and how many of everything for sale are at that price.
- **Next price up:** what you pay if the cheapest is gone, with its count.
- **Most are at:** the price the largest number share, when that is neither of the two above.
- **Asked between:** the lowest and highest asking prices the scans have seen.
- **Last seen:** how long ago a scan last saw it.
- **You paid, You last sold at:** from the ledger, when you have traded it.

Every price quoted is one an auction is actually listed at, with its count. There is no blended "going rate" here: an average of asking prices can land on a figure nobody lists and nobody pays. The block never claims what an item sells for; the only confirmed sale price is your own. An item nothing is known about gets no block. The lines are data (`data/tooltip.lua`); "Prices in item tooltips" in Options turns it off.

## What is not there yet

The Resell tab's Buy button does nothing yet; buy the item from the Buy tab. Buying several single auctions in one go is not built: it is one auction per pair of presses.

## Price history

Each full scan is folded into one small record per item (usual price, lowest and highest seen, how many scans and days have seen it), kept per realm and faction. Scans also leave graph points (usual price, lowest price, units for sale, and how many were at the lowest price). Points are kept at least 8 hours apart and reach back 30 days; a scan made sooner than that updates the newest point, so the latest scan always shows. "Days of price history to keep" in Options picks the reach from 7, 14, 30, 60, 90 or 180 days (a shorter pick says how many days go, and nothing goes until the next scan, so picking the longer one again before then keeps them), and the foot of the Options panel says how much data is kept (`ns.HistoryRule` in `data/trading.lua`). The scan itself is not kept beyond the latest one. Price confidence rises as more scans see an item: one scan caps it below High.

## Where things are

| Path | What it holds |
| --- | --- |
| `data/theme.lua` | Sizes, colors and fonts |
| `data/facets.lua` | Categories, their checkboxes, the rail |
| `data/trading.lua` | Price rules, sale types, confidence, deal and resell rules, history settings |
| `market/market.lua` | Price ladders built from a scan |
| `market/history.lua` | The price memory |
| `market/signals.lua` | Price confidence and the deal meter |
| `market/facets.lua`, `orders.lua`, `resell.lua` | Filtering, order costs, resell plans |
| `inventory/bags.lua` | What in your bags can be auctioned |
| `ui/kit.lua` | The building blocks every tab is drawn from |
| `ui/window.lua` | The window and its tabs |
| `ui/chart.lua` | Line and bar charts for the History tab |
| `ui/tabs/*.lua` | One file per tab |
| `trade/*.lua` | Posting, the sell search, your own auctions |
| `ledger/*.lua` | The trade ledger: the store, the buy and post recorder, the mail reader |

The scan engine (`feed/`, `store.lua`, `jobs.lua`) is unchanged.

## Checking it

There is no automated test in the repo for the window. It was run against a mocked game client (every tab built, every button and row clicked), which catches Lua errors but cannot check how it looks or how the real client behaves. After deploying, restart the client, since the file list changed.

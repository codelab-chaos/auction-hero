# The in-game window

The addon's window is the Nitro Lab concept (`lab/src/ui/concept`) rebuilt for the game: same 900 by 600 size, same tabs, same layout, colors and wording. Open it with `/an`, the AuctioNitro button on the auction house, or the minimap addon menu. It also opens with the auction house.

It is drawn from plain textures and text, not the game's stock button art, so it takes its whole look from one theme table.

## What is there

- **Title bar:** a Scan button with the scan's status beside it, and your gold.
- **Buy:** a left rail of quick toggles (quality swatches, one-hand, two-hand, shield, the eight armor slots), collapsible category checkboxes, search with "I can use", "I can afford" and "Deals", a sortable item list, and an order panel with quantity, total, the five-pip deal meter and what you save.
- **Sell:** your real bags as a grid (an item spread over several stacks is one choice), sale type, price in gold, silver and copper, the five price rules, price confidence with its facts line, how many to post, duration, and the competition ladder with your auctions slotted in.
- **Resell:** discount and minimum profit settings, "I can afford" and "Top deals", the list of leads, and the Buy, Relist, Keep plan.
- **History:** pick an item and see its usual and lowest price as lines and the units for sale as bars, over 7, 14 or 30 days, with a hover readout. It needs two days of scans before it draws.
- **Debug:** the raw scan views and the event log. Hidden unless the debug switch is on: `/an debug`.

## Posting

Post on the Sell tab puts the chosen item up for auction, one press per post. Picking an item asks the game for its live listings first, the same request the game's own sell form makes. The Auctions tab lists what you have up.

The server does not take a single item (gear and the like) for less than 1 silver. It does not refuse such a post, it never answers, and the auction house stops responding until you log out. The game's own form does the same. The addon will not send a price under that floor (`ns.MinItemPrice` in `data/trading.lua`). Goods sold by the unit have no floor.

## What is not there yet

**Buying is not wired up.** The Buy buttons on the Buy and Resell tabs are drawn but do nothing, and say so in their tooltips. Every number on screen is real, from your own scans and bags.

## Price history

Each full scan is folded into one small record per item (usual price, lowest and highest seen, how many scans and days have seen it), kept per realm and faction. The scan itself is not kept beyond the latest one. Price confidence rises as more scans see an item: one scan caps it below High.

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

The scan engine (`feed/`, `store.lua`, `jobs.lua`) is unchanged.

## Checking it

There is no automated test in the repo for the window. It was run against a mocked game client (every tab built, every button and row clicked), which catches Lua errors but cannot check how it looks or how the real client behaves. After deploying, restart the client, since the file list changed.

# Auction House Research (WoW: Forever)

Researched 2026-11-12. Covers the in-game auction object model and API, what is specific to Forever, the external web API, and what still needs an in-game check.

## Sources and how much to trust them

| Source | What it is | Trust |
| --- | --- | --- |
| `/home/chadneff/git/hub/wow-ui-source`, branch `origin/forever` | Blizzard's own UI code and generated API docs, client 1.60.1 build 70888 | Primary. Everything in "Object model" and "API" below comes from here |
| `../quest-party/QuestParty/QuestParty.toc` | Our own working Forever addon | Primary for TOC settings |
| Community repos, guides, CurseForge pages | Other addon authors' notes | Self-reported. None had an in-game test behind the claims we care about |
| Blizzard forum post on the web API | One developer probing endpoints | Unofficial, "nothing is official and documented yet" |

Note: the local `wow-ui-source` checkout sits on `live` (retail 12.1.5). Read the Forever files without switching branches:

```sh
cd /home/chadneff/git/hub/wow-ui-source
git show origin/forever:Interface/AddOns/Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua
git ls-tree -r --name-only origin/forever Interface/AddOns/Blizzard_AuctionHouseUI
```

Key files on that branch:

- `Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua` (functions, events, structures)
- `Blizzard_APIDocumentationGenerated/AuctionHouseEnumsDocumentation.lua` (enums)
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.lua` (search and browse flow)
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua`, `...ItemSellFrame.lua`, `...CommoditiesSellFrame.lua` (posting flow)
- `Blizzard_AuctionHouseUI/Camelot/Blizzard_AuctionData.lua` (Forever-only categories)

## The headline

Forever (client 1.60.1, build 70888, internal game type `camelot`) uses the modern retail `C_AuctionHouse` API, not the Classic `QueryAuctionItems` one. Compared with retail 12.1.5, the Forever API docs differ by exactly one added function (`GetItemKeySampleLink`). Retail addon knowledge transfers almost completely.

## Object model

Everything hangs off the **ItemKey**:

```lua
{ itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
```

Build one with `C_AuctionHouse.MakeItemKey(itemID, itemLevel, itemSuffix, battlePetSpeciesID)` or from a bag item with `GetItemKeyFromItem(itemLocation)`. `GetItemKeyInfo(itemKey)` returns `ItemKeyInfo`: `itemName`, `quality`, `iconFileID`, `isCommodity`, `isEquipment`, `isPet`. It can return nil until `ITEM_KEY_ITEM_INFO_RECEIVED` fires.

There are two kinds of listing, and almost every call comes in a pair:

| | Items (gear and other non-stackables) | Commodities (stackables) |
| --- | --- | --- |
| Keyed by | `ItemKey` | `itemID` |
| Result row | `ItemSearchResultInfo` | `CommoditySearchResultInfo` |
| Price fields | `minBid`, `bidAmount`, `buyoutAmount` | `unitPrice` |
| Other fields | `auctionID`, `quantity`, `timeLeft` (band), `timeLeftSeconds`, `owners`, `itemLink`, `containsOwnerItem`, `containsAccountItem`, `containsSocketedItem`, `bidder` | `auctionID`, `quantity`, `timeLeftSeconds`, `owners`, `numOwnerItems`, `containsOwnerItem`, `containsAccountItem` |
| Post | `PostItem(itemLocation, duration, quantity, bid, buyout)` | `PostCommodity(itemLocation, duration, quantity, unitPrice)` |
| Buy | `PlaceBid(auctionID, amount)` (bid the buyout to buy) | `StartCommoditiesPurchase(itemID, qty)`, then `ConfirmCommoditiesPurchase(itemID, qty)` |

`GetItemCommodityStatus(itemLocation)` tells you which kind a bag item is: `Unknown = 0`, `Item = 1`, `Commodity = 2`.

Other structures:

- `BrowseResultInfo`: `itemKey`, `totalQuantity`, `minPrice`, `containsOwnerItem`, `appearanceLink`. One row per ItemKey.
- `OwnedAuctionInfo`: `auctionID`, `itemKey`, `itemLink`, `status` (`Active = 0`, `Sold = 1`), `quantity`, `timeLeftSeconds`, `bidAmount`, `buyoutAmount`, `bidder`.
- `BidInfo`: `auctionID`, `itemKey`, `itemLink`, `timeLeft`, `minBid`, `bidAmount`, `buyoutAmount`, `bidder`.
- `AuctionHouseSortType`: `{ sortOrder, reverseSort }`.
- `AuctionHouseBrowseQuery`: `{ searchString, sorts, minLevel, maxLevel, filters, itemClassFilters }`.
- `AuctionHouseItemClassFilter`: `{ classID, subClassID, inventoryType }`.

### Enums

- `Enum.AuctionHouseSortOrder`: `Price 0`, `Name 1`, `Level 2`, `Bid 3`, `Buyout 4`, `TimeRemaining 5`
- `Enum.AuctionHouseCommoditySortOrder`: `UnitPrice 0`, `Quantity 1`
- `Enum.AuctionHouseItemSortOrder`: `Bid 0`, `Buyout 1`
- `Enum.AuctionHouseTimeLeftBand`: `Short 0`, `Medium 1`, `Long 2`, `VeryLong 3`. `GetTimeLeftBandInfo(band)` returns min and max seconds.
- `Enum.AuctionHouseFilter`: `UncollectedOnly 1`, `UsableOnly 2`, `CurrentExpansionOnly 3`, `UpgradesOnly 4`, `ExactMatch 5`, `PoorQuality 6` through `ArtifactQuality 12`, `LegendaryCraftedItemOnly 13`
- `Enum.AuctionHouseNotification`: `BidPlaced 0`, `AuctionRemoved 1`, `AuctionWon 2`, `AuctionOutbid 3`, `AuctionSold 4`, `AuctionExpired 5`
- `Enum.AuctionHouseError`: 27 values, including `NotEnoughMoney 0`, `HigherBid 1`, `ItemNotFound 4`, `IsBusy 7`, `Unavailable 8`, `DatabaseError 10`, `NotEnoughItems 12`
- Constant: `DEFAULT_AUCTION_PRICE_MULTIPLIER = 1.5`

## Reading auctions

There are three ways to read, each with a different cost.

### 1. Browse (many items, one price each)

```
SendBrowseQuery(query)
  -> AUCTION_HOUSE_BROWSE_RESULTS_UPDATED   (first page)
  -> GetBrowseResults()                     (table of BrowseResultInfo)
RequestMoreBrowseResults()
  -> AUCTION_HOUSE_BROWSE_RESULTS_ADDED     (payload: the added rows)
HasFullBrowseResults()                      (true when there are no more pages)
```

Gives the minimum price and total quantity per ItemKey. Cheap. Failure fires `AUCTION_HOUSE_BROWSE_FAILURE`. Related: `SearchForItemKeys(itemKeys, sorts)` and `SearchForFavorites(sorts)` return browse results for a known list.

### 2. Search (every listing of one item)

```
SendSearchQuery(itemKey, sorts, separateOwnerItems, minLevel, maxLevel)
  items:       -> ITEM_SEARCH_RESULTS_UPDATED (itemKey)
               -> GetNumItemSearchResults(itemKey), GetItemSearchResultInfo(itemKey, i)
  commodities: -> COMMODITY_SEARCH_RESULTS_UPDATED (itemID)
               -> GetNumCommoditySearchResults(itemID), GetCommoditySearchResultInfo(itemID, i)
RequestMoreItemSearchResults(itemKey) / RequestMoreCommoditySearchResults(itemID)
  -> ITEM_SEARCH_RESULTS_ADDED / COMMODITY_SEARCH_RESULTS_ADDED
HasFullItemSearchResults(itemKey) / HasFullCommoditySearchResults(itemID)
```

The docs state: "Search queries are restricted to 100 calls per minute. These should not be used to query the entire auction house. See ReplicateItems."

`SendSellSearchQuery(itemKey, sorts, separateOwnerItems)` is the variant the sell tab uses to show competing listings. The docs say to clear the item level and suffix on the ItemKey first.

`AUCTION_HOUSE_NEW_RESULTS_RECEIVED` (payload: itemKey, or nil for browse) is documented as "not used in the base UI but is included for AddOn ease-of-use".

### 3. Full scan (the whole house)

```
ReplicateItems()
  -> REPLICATE_ITEM_LIST_UPDATE
  -> GetNumReplicateItems()
  -> GetReplicateItemInfo(i), GetReplicateItemLink(i), GetReplicateItemTimeLeft(i)
```

`GetReplicateItemInfo(i)` returns positional values, not a table: `name, texture, count, qualityID, usable, level, levelType, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo`.

Notes:

- `buyoutPrice` is for the whole stack, so the unit price is `buyoutPrice / count`.
- `hasAllInfo` can be false, meaning the item data has not loaded yet. Retail addons handle that row later.
- Community sources report one scan per 15 minutes. None had tested it in-game on Forever.

### My own auctions and bids

- `QueryOwnedAuctions(sorts)` -> `OWNED_AUCTIONS_UPDATED` -> `GetNumOwnedAuctions()`, `GetOwnedAuctionInfo(i)`, `GetOwnedAuctions()`
- `QueryBids(sorts, auctionIDs)` -> `BIDS_UPDATED` -> `GetNumBids()`, `GetBidInfo(i)`, `GetBids()`
- `CanCancelAuction(id)`, `GetCancelCost(id)`, `CancelAuction(id)` -> `AUCTION_CANCELED`
- Lifecycle events: `AUCTION_HOUSE_AUCTION_CREATED` (auctionID, documented as included for addons), `AUCTION_HOUSE_AUCTIONS_EXPIRED`, `AUCTION_HOUSE_PURCHASE_COMPLETED`, `AUCTION_HOUSE_NEW_BID_RECEIVED`, `AUCTION_HOUSE_SHOW_NOTIFICATION`, `AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION`
- Open and close: `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`

## Posting auctions

The flow Blizzard's own sell frame uses:

1. `IsSellItemValid(itemLocation, displayError)` to check the item can be sold.
2. `GetItemCommodityStatus(itemLocation)` to pick the item or commodity path.
3. `GetAvailablePostCount(itemLocation)` for the maximum quantity.
4. `CalculateItemDeposit(itemLocation, duration, quantity)` or `CalculateCommodityDeposit(itemID, duration, quantity)`.
5. Check `IsThrottledMessageSystemReady()`. Blizzard's UI disables the post button when this is false.
6. `PostItem(...)` or `PostCommodity(...)`. Both return `needsConfirmation`.
7. If `needsConfirmation` is true, follow with `ConfirmPostItem(...)` or `ConfirmPostCommodity(...)` using the same arguments.
8. Success fires `AUCTION_HOUSE_AUCTION_CREATED`. Problems fire `AUCTION_HOUSE_POST_ERROR` or `AUCTION_HOUSE_POST_WARNING`.

Things to know:

- **Duration is an index 1 to 3, not hours.** It is stored in the CVar `auctionHouseDurationDropdown`. The hours behind the three indexes are unconfirmed for Forever (sources say 12/24/48 or 2/8/24).
- **Restrictions.** `PostItem`, `PostCommodity`, `ConfirmPostItem`, `ConfirmPostCommodity`, `PlaceBid`, `CancelAuction` and `StartCommoditiesPurchase` are flagged `HasRestrictions` in the docs. On retail that means one hardware click per action: an addon can fill in the form but cannot act unattended. Unconfirmed on Forever.
- **Throttle.** Listen for `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, `..._MESSAGE_QUEUED`, `..._MESSAGE_SENT`, `..._MESSAGE_RESPONSE_RECEIVED`, `..._MESSAGE_DROPPED`.
- **Copper.** `SupportsCopperValues()` says whether prices may include copper. When false, Blizzard rounds deposits up to whole silver.
- **Price suggestion.** `ShouldAutoPopulatePrice()` and the constant multiplier 1.5 are what the default UI uses.
- **Multisell.** Posting several stacks fires `AUCTION_MULTISELL_START`, `AUCTION_MULTISELL_UPDATE`, `AUCTION_MULTISELL_FAILURE`. `CancelSell()` stops it.

## Buying

- **Items:** `PlaceBid(auctionID, bidAmount)`. Bidding the buyout amount buys it. Result events: `AUCTION_HOUSE_PURCHASE_COMPLETED`, `ITEM_PURCHASED`, or `AUCTION_HOUSE_SHOW_ERROR`.
- **Commodities:** `StartCommoditiesPurchase(itemID, quantity)` -> `COMMODITY_PRICE_UPDATED (unitPrice, totalPrice)` or `COMMODITY_PRICE_UNAVAILABLE` -> `ConfirmCommoditiesPurchase(itemID, quantity)` -> `COMMODITY_PURCHASE_SUCCEEDED` or `COMMODITY_PURCHASE_FAILED`. The quote expires, see `GetQuoteDurationRemaining()`. `CancelCommoditiesPurchase()` backs out.

## Price history

**There is no price history API.** The client only knows what is listed right now. Every auction addon builds history itself by recording what it sees into SavedVariables.

This is the core design decision for AuctioNitro:

- What we snapshot (browse min prices, full search results, or full scans).
- How often, given the search limit and the scan cooldown.
- How we compact it so SavedVariables stays small (for example daily min and median per item rather than raw rows).

## Forever-specific differences

Verified from the `forever` branch:

- **New function:** `GetItemKeySampleLink(itemKey)` returns "a link for an item in this key's results with player-applied enchants, gems and reforges stripped". Blizzard's UI prefers it for tooltips.
- **Required level, not item level.** `AuctionHouse_ShouldUseRequiredLevel()` returns true on Forever, so the UI shows `GetItemKeyRequiredLevel(itemKey)` and drops the item level column.
- **Categories are Classic-style.** Added: relics (idol, libram, totem), quivers and ammo pouches, projectiles, soul bags, profession bags. Removed: battle pets, housing, glyphs, gems, profession equipment, warglaives.
- **WoW Token category** is hidden unless `C_WowTokenUI.ShouldDisplayInAuctionHouse()`.

From our own working addon (`../quest-party`):

- `## Interface: 16001`
- `## AllowLoadGameType: forever` with a plain `QuestParty.toc`. Blizzard's own files use `camelot` as the game type tag, and community guides mention a `_Camelot.toc` suffix, so both names appear to be in play. Follow what quest-party does since it is known to load.

Self-reported by community sources, not confirmed:

- **Market scope:** one house per ruleset and faction, region-wide rather than per realm. The web API also lists a "Blackwater Auction House" (likely the neutral one).
- **Cut:** 5% at faction houses and 15% at neutral, assumed from Classic.
- **Deposit:** based on vendor value and duration. Minimum is 1 silver at the time of writing, with a drop to 1 copper postponed to the Nov 17 maintenance. Use `Calculate*Deposit` and `SupportsCopperValues()` at runtime instead of hardcoding.
- **Secret values:** auction data is reported to carry no secret-value marks. Nearly every function is flagged `SecretArguments = "AllowedWhenUntainted"`.

## External web API

From one developer's forum post, working since Nov 6, not official:

- Namespaces: `static-forever-{region}`, `dynamic-forever-{region}`, `profile-forever-{region}`
- Rulesets replace realms: `/data/wow/ruleset/index`, `/data/wow/ruleset/{id}`. US and EU ids: 1 (PvP), 2 (Normal), 3 (Roleplay), 15 (Roleplay PvP).
- `/data/wow/ruleset/{id}/auctions/` (trailing slash required) returns the list of houses.
- `/data/wow/ruleset/{id}/auctions/{houseId}` returns item auctions: `id`, `item`, `buyout`, optional `bid`, `quantity`, `time_left`.
- `/data/wow/ruleset/{id}/auctions/{houseId}/commodities` returns `id`, `item`, `quantity`, `unit_price`, `time_left`.
- House ids 110 to 121 and 123 to 125. Every ruleset currently returns the same houses with identical auctions.
- Busy houses hold 50k to 68k auctions, about 9 MB per response.
- Update frequency and auth details were not stated. Client credentials are likely enough for game data.

An addon cannot call this from in-game. It is a possible later source for history and graphs through a companion tool.

## Verified from a real full scan

One scan on 2026-11-12, US Horde, build 70888, read back from the saved variables file. These are facts, not reports.

**The scan itself**

- `ReplicateItems` works. 180,863 auctions came back, read in 38 seconds.
- `GetReplicateItemInfo` returns 18 values, matching the docs.
- `REPLICATE_ITEM_LIST_UPDATE` fires thousands of times, not once. The first one means the list is ready, the rest deliver row details.
- 14,366 rows (8%) were still incomplete when we stopped waiting after about 6 seconds: `hasAllInfo` false, name `""`, quality `-1`, level 1, no texture, no link. Count, prices and item id were already there. The addon now keeps re-reading until the server goes quiet.
- The saved file was 38 MB. Fine for a probe, too big to keep as the cache format.

**Prices**

- `buyoutPrice` is for the whole stack. Raptor Egg medians by stack size: 1 for 118, 2 for 234, 5 for 590, 10 for 1,200.
- The market is buyout-only in practice. 99.85% of rows have `minBid` 0, only 7 rows have no buyout, and 35 have a bid.
- `minIncrement` is 0 except on the handful of rows with bids.

**What is missing**

- `owner`, `ownerFullName`, `highBidder` and `bidderFullName` are nil on every row. A full scan cannot tell us who is selling, so undercut-by-seller logic needs the search API.
- `saleStatus` is always 0.

**Item identity**

- 5,413 item ids, but 12,679 distinct items once variants count. 971 item ids have more than one name ("of the Bear", "of the Owl" and so on).
- The link's suffix position is empty on Forever. Variants are told apart by bonus ids near the end of the link. The link looks like `|cnIQ2:|Hitem:6601::::::::9:1486::1:1:12751:1:28:5242:::::|h[Dervish Boots of the Bandit]|h|r`.
- Within an item id, the name and the link's bonus part always agree, so item id plus name is a safe key. The addon groups by that.
- Every link is type `item`, with 19 to 22 values. The color code is `nIQ<quality>:`, not a hex color.

**Shape of the market**

- 72% of rows are single units, 28% are stacks, up to 10,000 (ammo).
- 1.3 million units, about 157,000 gold of buyouts.
- 65% of rows are identical to at least one other row (same item, count and price), up to 993 copies. Deduplicating would cut a snapshot by more than half.
- `levelType` is `REQ_LEVEL_ABBR` (required level 1 to 60), `SKILL_ABBR` (recipes, skill 1 to 300) or `SLOT_ABBR` (bags, 6 to 26 slots).
- `timeLeft` is a band 1 to 4. Band 3 holds 67% of rows.
- Quality: 48% common, 37% uncommon, 4% rare, 2% poor, 83 epics.

**Still open**

- The real cooldown between scans (only one has been run).
- What the three duration indexes mean, whether posting needs a click, and the actual cut.

## Existing addons worth reading

- **Auctionator** (Forever build): simple selling, shopping lists, price history. Closest to our priorities.
- **auxForever**: fast search, posting, scanning. Confirms commodity buying re-checks price before purchase.
- **Auctioneer** (community port): the full suite.

## To verify in-game first

1. `/dump select(4, GetBuildInfo())` to confirm the interface number.
2. Whether `ReplicateItems` works, and its real cooldown.
3. What the three duration indexes mean in hours.
4. Whether post and buy need a hardware click.
5. The actual cut, by selling one item.
6. Whether `GetReplicateItemInfo` rows come back with `hasAllInfo` false and how long they take to fill.

Suggested next step: a tiny probe addon that answers these and dumps one scan to SavedVariables, so the price store is designed against real data.

## Correction to discuss.md

`docs/discuss.md` lists `GetItemSearchResults` and `GetCommoditySearchResults`. Those do not exist. The real calls are the indexed `GetItemSearchResultInfo(itemKey, i)` and `GetCommoditySearchResultInfo(itemID, i)`.

## The addon and deployment

The addon lives in `AuctioNitro/` and deploys the same way `../quest-party` does:

```sh
scripts/deploy.sh            # copy the addon into the game
scripts/deploy.sh --dry-run  # show what would change, copy nothing
```

- The target comes from the `WOW_ADDONS_DIR` environment variable, or the first line of `.deploy-target` in the repo root (gitignored).
- `--delete` only removes stale files inside the addon's own folder. Saved variables live in the WTF folder and are never touched.
- After deploy: `/reload` in game, or restart the client if files were added or the TOC changed.

What the first version does (a probe, not yet a trading tool):

- **Download:** "Full scan" (`ReplicateItems`, one row per auction) or "Browse sweep" (paged empty browse, one row per item). Buttons are in the window, which opens with the auction house. `/an` toggles it.
- **Summary:** snapshot facts and market totals, with breakdowns by quality, time left, stack size and seller.
- **Model:** every field of the raw rows with the Lua types seen, how often it is filled, and its values or range.
- **Items:** per-item listings, units, sellers, lowest, median and highest unit price, and how far the lowest sits under the median. Click a row to see its raw rows.
- **Rows:** the raw rows. The tooltip lists every field as it arrived.
- **Log:** the auction house events the client fired, with their payloads.

The snapshot is saved in `AuctioNitroDB` (`WTF/Account/<account>/SavedVariables/AuctioNitro.lua`), so it can also be read from outside the game after a `/reload` or logout.

Where things are, one responsibility per file:

| File | Responsibility |
| --- | --- |
| `data/schemas.lua` | Field lists of the raw rows, per source |
| `data/sources.lua` | The download sources and how their fields map to a listing |
| `data/summary.lua` | What the Summary shows, the deal rule, the stack buckets |
| `data/views.lua` | Tabs and columns |
| `data/events.lua` | Which events the log records |
| `feed/replicate.lua`, `feed/browse.lua` | Talk to the server, return rows |
| `feed/downloader.lua` | Runs one fetcher and reports progress |
| `analyze/profile.lua` | Measures the object model |
| `analyze/derive.lua` | Per-item numbers and market totals |
| `ui/view-model.lua`, `ui/panel.lua` | Turn data into table rows, draw them |
| `jobs.lua` | Spreads long work over frames so the game does not freeze |

## Links

- [Atomtomate/wow-forever-addons](https://github.com/Atomtomate/wow-forever-addons)
- [Atraeau/WoW-Addons](https://github.com/Atraeau/WoW-Addons)
- [WoW: Forever API forum post](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- [auxForever on CurseForge](https://www.curseforge.com/wow/addons/auxforever)
- [Forever addon developer guide](https://wowforeverguides.com/addons/developers)
- [Hearthproof auction house guide](https://hearthproof.com/economy/auction-house/)
- [Icy Veins on the deposit change](https://www.icy-veins.com/wow-forever/news/wow-forever-players-are-getting-a-99-cheaper-auction-house-deposit/)
- [IGGM on the delayed AH changes](https://www.iggm.com/news/wow-forever-auction-house-changes-delayed)
- [AHledger auction house overview](https://ahledger.com/wow-forever/auction-house)
- [auctionhouse.fyi API docs](https://auctionhouse.fyi/docs/api)

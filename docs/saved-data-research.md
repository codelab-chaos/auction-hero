# Saved data: what broke, how other addons store theirs, and a direction for the data model

Written 2026-11-25, after a saved file stopped loading. Findings and a proposal, nothing here is decided.

Update, same day: the stop-gap described below ships as 0.2.0, since it changes the saved format and older versions cannot read it. The proposal is for the release after it.

## What happened

- The game reads an addon's saved file as one Lua function. A Lua 5.1 function holds at most 262,143 different strings and numbers. Past that the file is refused whole: `constant table overflow` in `Logs/FrameXML.log`, and the addon starts with nothing.
- The limit is on distinct values, not on megabytes or rows.
- The account file reached 311,314 distinct values (77 MB). The copy from three hours earlier had 258,786 and still loaded.
- The failure is silent in game ("No scan yet"), and the next reload overwrites the last loadable copy.

Where the values were (77 MB file):

| Section | Distinct values | Size saved packed |
|---|---|---|
| Scan journal, item variants (93,230 entries) | 129,855 | 14.4 MB |
| Scan journal, changes (25 changes over about 34 hours) | under 200 | 13.6 MB |
| Latest scan (153,669 rows, 44,686 variants) | 115,734 | 10.8 MB |
| Price history, named realm (42,831 items, 32 scans) | 109,591 | 16.3 MB |
| Price history, blank realm (42,673 items, 9 scans) | 109,562 | 12.2 MB |

Two causes:

1. Nothing measured the real limit. Retention was by days only (journal 7 days, history by graph days).
2. The realm name went blank on this client on 2026-11-20, so one market was stored under two names.

## How other addons store auction data

Read from source, not from descriptions.

### Auctioneer

- **Raw scan in its own addon.** `Auc-ScanData` is a separate load-on-demand addon with its own saved file (`AucScanData`). Its notes say why: to delay loading "the, probably, large auction scan dataset until it is needed". A broken scan file cannot take settings or statistics with it.
- **Packed on unload.** `ScanData.lua` turns the scan image into "ropes": strings of Lua source (`return {...}`), each cut at 2^20 characters, read back with `loadstring`. If any rope fails, the whole image is treated as corrupt and dropped.
- **Aged out.** A scan image older than 14 days is deleted at unload.
- **Statistics are fixed size per item**, one packed string per item, each module in its own saved variable with its own `DATABASE_VERSION` and upgrade step:
  - Stat-Simple: today's totals plus moving averages over 3, 7 and 14 days. No time series at all.
  - Stat-StdDev: the last 100 price points per item (`MAX_DATAPOINTS = 100`). A cap by count, not by time.
  - Stat-Histogram: a histogram of at most 300 buckets, rescaled when prices move, "we don't want prices too high: they'll bloat the data".

### Auctionator

- Hit this exact error. Its code comment: serialize other realms "so their data doesn't contribute to a constant overflow when the client parses the saved variables".
- The current realm stays a plain table. Every other realm is one serialized string (LibSerialize).
- Per item: `m` (last minimum price), and per-day maps `h`, `l`, `a` (high, low, available). One entry per day, not per scan.
- Pruned at load by age: `price_history_days`, 21 by default.
- Posting history is capped by count: 10 entries per item.
- A `__dbversion` on each saved variable. A version it does not know is replaced with an empty database.

### TradeSkillMaster

- The scan is saved as one CSV string, written when the addon is disabled (logout), with a hash of the string beside it.
- Only a summary per item is kept: min buyout, market value, auction count, quantity, last scan time. No raw listings.
- Data from its desktop app arrives as Lua source and is read with `loadstring`, in chunks of about 3.4 MB when larger than 3.5 MB.
- Users still report `constant table overflow` on `TradeSkillMaster.lua` (r/woweconomy, December 2024), so even it is not immune where data is kept as plain tables.

### What they have in common

| Practice | Auctioneer | Auctionator | TSM | Auction Hero 0.1.8 |
|---|---|---|---|---|
| Big data saved as strings | yes | other realms only | yes | no |
| Raw scan kept apart from the rest | own addon and file | not kept | summary only | same file |
| Per-item data fixed or capped in size | yes | by days | yes | by days |
| Cap by count somewhere | 100 points | 10 posts | n/a | no |
| Each store versioned | yes | yes | yes | no |
| Integrity check | drop on any bad part | drop on bad version | hash | no |

Nobody caps by megabytes. They bound size by structure: a fixed amount per item, a count of points, or an age, and they keep the raw scan away from everything else.

## What is already built on this branch (uncommitted)

Built on 2026-11-25 as the smallest fix, before this research. It matches what Auctioneer does for its scan image.

- `pack.lua`: a table as strings of Lua source, each part at most 5,000 values, read back with `loadstring`.
- `saved.lua` and `data/saved.lua`: which tables are packed (as data), a count of what is about to be saved, and a purge order when over 80% of the limit (debug log, oldest journal changes, other markets' history, oldest history).
- `market/place.lua`: a realm name once seen is remembered per character.
- `market/history-merge.lua`: two histories of one market as one.
- A notice when saved data fails to load.
- `scripts/repack-saved.lua`: converts an oversized file offline.
- Tests: 66 pass, one on stock Lua 5.1 with about 946,000 values.

Measured on the real file: 311,314 values become 1,492. Unpack 0.6s, pack 1.3s on the development machine.

What it does not do: make the data smaller. The file is still 63 MB.

The recovered file is at `~/auction-hero-saved-backup-2026-11-25/AuctionHero.recovered.lua`, with both originals. Nothing has been deployed or installed for this change.

## Proposal for the release after 0.2.0

### Principles

1. **A store per kind of data, each declared as data.** Id, format version, how it is packed, how it is bounded, how it is purged, how it migrates. One manager opens, closes, migrates and budgets them all. Adding a kind of data is adding a declaration.
2. **Bound by structure first.** Each store has a hard cap that does not depend on how often someone scans: entries, points per item, or bytes.
3. **Size is the trigger, age is the preference.** Keep "last N days" as the setting players see, but enforce a size cap under it. When the cap is hit, the oldest goes regardless of age, and the player is told.
4. **A failure in one store stays in that store.** Bad scan data must not cost settings or price history.
5. **Every store has a version and a migration.** An unknown newer version is left untouched, not wiped.

### Stores

| Store | Today | Proposed bound | Notes |
|---|---|---|---|
| Settings and small state | plain | plain, tiny | Never packed, always loads. |
| Latest scan | all rows, packed | one scan, packed | Needed to draw the tabs at login. |
| Price history | per item, points by days | points per item capped by count as well as days | One market per realm. A leaner record (see below). |
| Scan journal | changes by days, own copy of variants | capped in MB, oldest dropped | 28 MB for 34 hours today. Seven days would be near 100 MB. |
| Debug log | 600 lines | as is | Already capped by count. |
| Ledger (per character) | plain, never trimmed | cap or pack | Separate file, small today, grows forever. |

### Decisions that are the owner's

1. **The scan journal.** It exists to count sales, and sales estimates are paused in 0.1.8. It is the largest and fastest growing store. Options: keep it with a size cap, turn it off by default until estimates return, or keep only what a future estimate needs. The data cannot say whether it is worth its size; the roadmap can.
2. **A second addon for bulk data.** Auctioneer's way: `AuctionHero_Data`, load on demand, with its own saved file. Isolates failure and halves what one file holds. Costs a second folder in the package and in deploys.
3. **How much history per item.** Per scan (today), per day (Auctionator), or a fixed summary (Auctioneer, TSM). Per day with a count cap would cut history several times over and still draw the graph.
4. **Key markets by realm id** if this client has one, so a blank realm name cannot split a market again. Needs `/run print(GetRealmName(), GetRealmID and GetRealmID())` in game.

### Leaner structures worth measuring

- **Journal variants.** The journal copies every variant the scan already holds (93,230 entries, 14.4 MB). A shared variant table, or an identity string in place of the copy, removes most of it.
- **History records.** Eleven named fields per item. A packed string per item, as Auctioneer does, is one value per item and parses only when asked for.
- **Scan rows.** Already compact (seven numbers per row).

### Upgrade for existing users

- First login on that release: each store migrates once, in a job so the game does not freeze, and chat says what was done ("Auction Hero changed how it saves data. Your scans and history were converted.").
- A file that already failed to load cannot be migrated in game. The addon says so; `scripts/repack-saved.lua` recovers it if the player still has the file.
- Users emptied by 0.1.7 or 0.1.8 before updating have no marker saying so. Infer it from data they do have (a ledger with purchases and no scans) so they get the notice too.
- Downgrading to 0.1.8 will not read the new format. The 0.2.0 changelog says so.

### Suggested order

1. Ship what is built as the stop-gap, after one test in game, so current users stop being exposed.
2. Decide the four questions above.
3. Build the store registry and move each store onto it, one at a time, each with its migration and its size cap.
4. Then the leaner structures, measured against the real file.

## Sources

- Auctioneer source (mirror): [gnummers/auctioneer](https://github.com/gnummers/auctioneer), files `Auc-ScanData/ScanData.lua`, `Auc-Stat-Simple/StatSimple.lua`, `Auc-Stat-StdDev/StatStdDev.lua`, `Auc-Stat-Histogram/StatHistogram.lua`
- Auctionator source (copy of 10.2.33): [Evolvee/EvolvePWPUI-ClassicVanilla](https://github.com/Evolvee/EvolvePWPUI-ClassicVanilla), files `Source/Variables/Main.lua`, `Source/Database/Mixin.lua`, `Source/Config/Main.lua`
- TradeSkillMaster source (copy): [notquin69/Quins-Classic-Addons](https://github.com/notquin69/Quins-Classic-Addons), file `TradeSkillMaster/Core/Service/AuctionDB/Core.lua`
- [TSM overflow report, r/woweconomy weekly thread, December 2024](https://lr.in.psf.lt/r/woweconomy/comments/1hpgl8x/weekly_tradeskillmaster_thread)
- [Saving variables between game sessions, Warcraft Wiki](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions)
- [Option to Compress SavedVariables, Blizzard forums](https://us.forums.blizzard.com/en/wow/t/option-to-compress-savedvariables/1752911)
- [Saved variable size limits observed by ESO addon authors, ESOUI](https://cdn.esoui.com/forums/showthread.php?p=33190)

The copies are mirrors and forks, so versions may trail the current releases. The practices described are in the code read, with the file named.

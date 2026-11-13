# Nitro Lab

A local workbench for exploring AuctioNitro scans and trying out UI ideas for posting, finding and reselling. The addon never depends on it.

```sh
npm install
npm run refresh   # import the newest full scan from the game and fetch its icons
npm run dev       # http://localhost:5210 (this project's pinned port)
```

- **Getting a scan:** in game, run a Full scan in AuctioNitro, then click Save to disk. `npm run refresh` reads the saved variables file from the game folder named in `../.deploy-target`.
- **Generated files:** `public/data` (scans as JSON) and `public/icons` (Blizzard's icon art) are gitignored. `npm run refresh` rebuilds them.
- **Where to change things:** screens are listed in `src/config/screens.ts`, posting price rules in `src/config/price-rules.ts`, names and assumptions in `src/config/catalog.ts`.
- **Aggregate view:** all imported fresh full scans are loaded automatically, with no scan selectors. Repeated scans are deduplicated. Stock comes from the newest scan; usual prices fold the same market's scan medians into history (30% new / 70% previous), and confidence shows each item's scan count. Old stock is never added to current quantities. Different markets keep separate histories.
- **Viewing date:** defaults to Now, updating each minute. The date/time and gold budget sit in the title bar; Data contains scan information and availability options. Choose a local date and time to emulate the past or future. Only scans available by that time inform listings, history and sale evidence. Between scans, expired tiers are removed using their maximum remaining-time bound; uncertain/unknown expiry remains explicitly estimated, without inventing sales or new listings. Now returns to the live clock. The timing fallback is optional under Data → Availability and applies to both availability and sale evidence.
- **Date dropdown:** lists Now and every imported scan's exact date/time, newest first. Choose Custom date… for a past/future time between scans. Selecting a scan date aggregates all history up to that instant.
- **Possible sales:** automatically accumulates decreases across consecutive scans within each market. Matching variant/stack/buyout tiers are grouped across intervals, and confidence scores are weighted by missing units rather than added. Only adjacent pairs are compared so overlapping intervals do not double-count departures. Click Reasons for the contributing intervals. Values use earlier asking prices; departures can also be cancellations or expirations, and replacement listings can mask them. Items with unnamed variants in any contributing interval are hidden by default. This is a lab screen, separate from the Concept window.
- **Sale / expiry confidence:** independent evidence scores (not probabilities) with click-through reasons. Sale evidence grows when cheap tiers disappear before possible expiry while matching higher-priced tiers remain. Expiry evidence uses earlier time bands and the gap between scans, allowing for scan read times. Future full scans record the client's actual band boundaries; older imports use an explicitly labelled, optional assumption (0–30 min / 30 min–2 h / 2–12 h / over 12 h). Assumed timing caps scores at 65; unresolved variants cap them at 25, and long scan gaps weaken scores. Unknown timing is allowed for as possible expiry, never counted as proof of a sale. Rules live in `src/config/sale-detection.ts`.
- **Checks:** `npm run build` checks TypeScript and builds the SPA; `npm test` checks scan comparison logic (Node 22.18+).

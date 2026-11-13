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

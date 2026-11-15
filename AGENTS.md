# Auction Hero development

## Deploy after every change (the game does not read this repo)

WoW loads Auction Hero from a copy in the game's AddOns folder, not from
`AuctionHero/` here. A change is not in game until it is deployed:

```sh
scripts/deploy.sh            # copy the addon into the game
scripts/deploy.sh --dry-run  # see what is out of date, copy nothing
```

The target folder is the first line of `.deploy-target` (or `WOW_ADDONS_DIR`).

- After changing anything under `AuctionHero/`: run the tests, then deploy, then
  ask the owner to test.
- Tell the owner which one is needed: `/reload` for edits to existing files, a
  full client restart when a file was added or the `.toc` changed.
- If what the owner sees in game does not match the code, run
  `scripts/deploy.sh --dry-run` first. Undeployed changes are the likeliest cause.

## Tests

```sh
cd tests && npm test
```

One scenario per file in `tests/scenarios`; the game is mocked in
`tests/harness/mock.lua`.

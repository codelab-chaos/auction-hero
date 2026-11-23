# Auction Hero development

## Versions and release status

Use plain `major.minor.patch` versions, such as `0.1.0`, in tags, ZIP names
and TOC metadata. Do not add alpha, beta or rc suffixes. The `0.x` series
communicates early development; GitHub's prerelease flag carries release status.

A public release means ready for general use and can still be `0.x`; it does
not mean the project is finished or requires `1.0.0`. Promote a tested beta by
editing the existing GitHub release's status, keeping its version, tag and ZIP.
Tag pushes publish prereleases by default; manual releases have an explicit
`public_release` choice. See docs/releasing.md for publication and promotion commands.

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

Unit tests live in `tests/unit`, one module per file. A unit test loads only
the files its first line names (`-- loads: ui/list-fit.lua, data/theme.lua`),
with no mocked game, and calls the module directly. Logic that decides
something (when to redraw, what to re-measure, which version moved) belongs
in a module that calls nothing of the game's, so it can be tested this way.

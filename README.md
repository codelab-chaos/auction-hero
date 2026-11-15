# Auction Hero

An auction house addon for World of Warcraft: Forever. It replaces the stock
window with one built for buying, selling and reselling: better filters, going
rates from your own scans, posting in a couple of clicks, and price graphs.

Your scans are the core of it. Everything the addon shows is worked out from
scan data, to make the auction house easier to use and easier to profit from.
It works from what it sees in game. There is no outside price feed.

## What it does

- **Buy:** quick filters down the side (quality, weapon hand, armor slot),
  category checkboxes, search, toggles for gear you can use, gear better than
  what you wear (stats weighted for your class) and gear near your level, and
  a deal meter that says how a price compares with what the item usually goes
  for. Goods sold by the unit can be bought
  from here in two presses.
- **Sell:** your bags as a grid, price rules (match, undercut, quick sale and
  so on), how confident the price is, and the competition you would be listed
  against.
- **Resell:** small markets you could buy out and relist at a profit.
- **Auctions:** what you have up for sale.
- **Ledger:** every auction house trade your character makes, and what each
  item has made you. Buys and deposits are recorded as you make them; sales
  come in from your mail.
- **Graphs:** price and supply graphs for an item over 3, 7, 14 or 30 days.
- **Item tooltips:** hover an item anywhere in the game for its going rate,
  lowest price, quantity for sale and when it was last seen.

Open it with `/ah`, or it opens with the auction house. `/ah help` lists the
commands.

## Status

Early and under active development, on the Forever client (1.60.1).

- Scanning, price history, posting, and buying goods sold by the unit work.
- Buying single items (gear) and buying from the Resell tab are not built yet.
- The server does not accept a single item posted for less than 1 silver, and
  hangs the auction house instead of refusing it. The addon will not send one.

More detail is in [docs/addon-ui.md](docs/addon-ui.md).

## Install

Copy the `AuctionHero` folder into
`World of Warcraft/_forever_/Interface/AddOns`, then start the game.

## What is in this repository

| Folder | What it is |
| --- | --- |
| `AuctionHero/` | The addon |
| `tests/` | The addon's tests, run against a mocked game client |
| `docs/` | Research notes and how the window is put together |
| `scripts/deploy.sh` | Copies the addon into a local game install |

## Development

```sh
# Addon tests
cd tests && npm install && npm test

# Copy the addon into your game (set WOW_ADDONS_DIR, or put the AddOns path
# on the first line of a .deploy-target file in the repository root)
scripts/deploy.sh
```

The tests load the addon's real files into a Lua interpreter with a fake game
client and drive it the way a player would. They catch broken behavior and Lua
errors. They cannot show how the window looks or prove what the real server
does, so anything that talks to the server is also checked in game.

## ahero-lab

ahero-lab is a local web workbench used to study scans, design the window, and
try out price evaluations before they are built in game. It has its own
repository, kept beside this one in `../ahero-lab`. The addon does not depend
on it.

## License

MIT. See [LICENSE](LICENSE).

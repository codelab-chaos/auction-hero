# Changelog

Features and fixes shipped in each release. Copy a version's section into
CurseForge's changelog field using Markdown formatting, and into the GitHub
release notes.

## 0.1.6 - 2026-11-21

### Fixed

- **Quantity box:** you can type more than one digit again.
- Clearing a quantity or Resell limit to retype no longer snaps it back to 1.

### New

- **Buy in stacks:** 1, 2 and 5 stack buttons for goods like arrows and cloth.
- **Bags grouped by kind** on the Sell tab, with All, Gear, Trade and Take filters and rarity-colored borders.
- **List view for your bags:** an option that shows one row per item with its count, sortable by name or count.

## 0.1.5 - 2026-11-21

### Fixed

- **Buying twice in a row:** after a purchase, the next auction of the same item is ready at once, so the next press buys it instead of only checking the price.
- **A press that only checks says so:** when a press can only check the price, the button reads "Press again: buy 1 for ..." instead of looking unchanged.
- **Debug tab froze during a scan:** the Log view redraws at most twice a second instead of once per event.
- **Tabs during a scan:** every tab except Debug and the one on screen is locked until the scan ends, so nothing loads mid-scan.

### Improved

- **Gear already bought:** equippable gear your class can wear, bought here and still in your mail, is shown while you shop: a mail icon on rows for the same slot, and a list in the pick prompt. It clears once you take it from the mail.
- **Confidence label:** the lowest scan confidence now reads "Mostly guessing".
- **Early Access | feedback welcome** in the title, with a link to the CurseForge page.

## 0.1.4 - 2026-11-19

### Fixed

- **Buy buttons say what you pay:** every Buy and Confirm button names how many and the total ("Buy 1 for 27c", "Buy 2 for 54c total"). A count beside a price of each no longer reads like that many at that price.
- **Picking a price starts at one:** for goods sold by the unit, clicking a price sets the quantity to 1 instead of everything listed up to that price.
- **A greyed-out Confirm says why:** when the live price comes back above your gold, the note under the button says so, with both amounts.
- **A lapsed price check is not a failure:** the game only holds a checked price briefly. When it lapses, the Buy button comes back with a note to check again, instead of a red error.

## 0.1.3 - 2026-11-19

### New

- **Hero Coins:** earned by using Auction Hero: the day's first scan, opening the auction house, buying, posting, sales, a first look at each tab, and scan streaks of 3, 7, 14 and 30 days. Each way is capped per day, so nothing pays for scanning more than once a day. Can you spend them? ...TBD
- **Progress tab** (the pouch icon at the right end of the tabs): today's scan and streak, scan confidence, your Hero Coin balance and recent earnings, a 30-day scan calendar, streak bonuses and every way to earn.
- **Scan confidence:** how well your scans cover the market, from how many of the last 30 days you scanned.
- **Recipe tooltips:** hover a profession recipe for the crafted item's price, the material cost and the margin.
- **Requests and incoming gear tracking**, and bag-aware Better and Picks filters on the Buy tab.

### Improved

- The window can be dragged shorter, down to 420 tall.
- The scan card's coins spill out of the progress bar.
- A rallying-cry badge after the title.
- Debug always sits at the far right of the tabs.

### Fixed

- Buying, live price checks, item matching and the sell search were reworked for reliability.

## 0.1.0 - 2026-11-16

First release: the native Auction Hero window with Buy, Sell, Resell, Auctions, Ledger and Graphs tabs, full scans with price history, posting, cancelling, buying goods sold by the unit, item tooltips and the scan shield.

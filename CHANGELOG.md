# Changelog

Features and fixes shipped in each release. Copy a version's section into
CurseForge's changelog field using Markdown formatting, and into the GitHub
release notes.

## 0.2.0 - 2026-11-25

Your scans and price history are converted the first time you log out. Versions before 0.2.0 cannot read them afterwards, so going back starts with none.

### Fixed

- **Sell tab:** an item nobody is selling right now gets its price from past scans, and says so, instead of "no price to go by".
- **Saved data:** a busy auction house could grow the saved file past what the game can load, and Auction Hero then started with no scans or price history. Scans and history are now saved packed, so the file loads however much it holds.
- **Price history:** a market is no longer kept twice when the game gives no realm name.

### Improved

- **Sell tab:** the right panel shows the item's price history and your past sales under the listings, like the Buy tab.
- **Saved data:** if saved scans ever fail to load, the window says so and how to keep the copy from before, instead of "No scan yet".
- **Chat:** says which version loaded when you log in.
- **Buy tab:** gear for a slot you already bought for shows the item you bought, grayed, in place of the letter. Hover it to compare the two. The column heading says what it is.

## 0.1.8 - 2026-11-23

### Fixed

- **Auctions tab:** gear you have listed shows its name again. Until the game has the item loaded, it says "Loading item...".
- **Sales estimates are paused:** they counted too many sales when scans were hours apart, so they no longer show. Counts already saved are cleared. The Sell tab still shows how many are listed at or under your price.
- **Ledger:** Last trade shows how long ago, such as 45m, 5h or 3d, so it is easy to compare and sort. Hover it for the date.
- **No memory figure:** the Progress tab and Options no longer show memory used. The game's number counts memory not yet freed and read far too high right after a scan.

### Improved

- **Buying asks you to confirm** every purchase. To buy gear in one press when the price has not changed, turn it on in Options. A changed price always asks.
- **Coins drop** on a Buy row while its price is being checked live.
- **The version** shows in the title bar, beside your gold.
- **Craft tab:** shorter names (Worth it, Level Up, Sell raw and Can Make), and a word of caution from gnome science.
- **Column widths, redone:** drag the line between any two columns and only that line moves; it snaps to fit the text as you pass. Double-click a line to fit the column to its text. Right-click a heading to reset. Widths you set before are reset once.
- **Narrow windows:** the Ledger's least needed columns step aside instead of squashing every number.

## 0.1.7 - 2026-11-23

### Fixed

- **Gear in the mail:** the reminder clears once you collect it.
- **Name columns:** drag a list's name column wider; columns no longer run off the right edge. Double-click its edge to reset.
- **Live prices after a reload:** prices checked live still say so after a /reload, and the check mark fades once they are 5 minutes old.

### New

- **Craft tab:** what your recipes are worth making, with a verdict per recipe (worth making, sell raw goods, levels you), profit counting raw goods you hold, and filters by profession.
- **Chance to sell** on the Sell tab, under the price buttons: likely, might or unlikely, from how many are listed at or under your price and how fast the item sells. Hover for the details.
- **Sales between scans:** each scan is compared with the one before to see what likely sold, ran out or was taken down. Scanning a few hours apart says the most. Choose how many days to keep in Options, or turn it off.
- **Ledger:** a chart of what you earned each day, a Last trade date per item, and Sold at, Now and Change columns to spot what is worth more than you sold it for.
- **Progress tab:** what Auction Hero keeps, and the memory it uses.
- **Your stack's worth** in item tooltips: "Your 20 is worth ~3s 40c".
- **Live price mark** on Buy rows: being checked, checked live, or the check failed.
- **Type the count** beside the Auctions and Quantity sliders on the Sell tab.
- **Rising and Falling filters** on the Graphs tab.

### Improved

- **Much faster tabs:** switching tabs and live price checks no longer stall the game. "Refreshing..." shows beside your gold when a big redraw is coming.
- **Graphs:** open on 7 days. The price axis fits the prices instead of starting at zero, and Change ignores scans with only a few for sale.
- **Resell tab** is hidden by default; turn it on in Options.
- Sortable column headings light up under the mouse.

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

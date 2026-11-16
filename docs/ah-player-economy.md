# The auction house as a player economy

A working paper for AuctionHero. It sets down how the auction house behaves as a market, what a player trading on it is really asking, and which of those questions our data can answer. It is the reference for every evaluation the addon or the lab makes: a deal, a going rate, scarcity, a lead worth flipping.

Status: draft for review. Nothing here is settled until the open questions at the end are answered.

## How we work on evaluations

1. An evaluation is written down here first: the question it answers, the data it uses, and what would prove it wrong.
2. It is built and tried in ahero-lab (its own repository, `../ahero-lab`) against real scans.
3. Only when it reads right there is it ported to the addon.

The addon and the lab must then use the same rule. The deal rule of 13 November 2026 was built in both at once, before this process existed, and is the one exception.

## What we can and cannot see

Everything the addon knows comes from three sources, and they are not equally trustworthy.

| Grade | Source | What it tells us | What it cannot tell us |
|---|---|---|---|
| Observed | A full scan | What is listed right now: item, stack, asking price, time left | Who is selling. Whether anything sold |
| Probable | Two scans compared | What left between scans, and whether it could have expired | Sold, cancelled and relisted look alike |
| Confirmed | The character's own ledger | What you paid, what a sale paid out, the cut, the deposit | Anything you did not trade yourself |

Three facts about the Forever auction house shape all of this:

- **A scan shows asking prices, never sale prices.** A price nobody pays can sit there for a day and look like the going rate.
- **A full scan names no sellers.** Six identical auctions are probably one seller, but that is an inference.
- **Listings last 24 hours at most**, and time left comes as four bands (under 30 minutes, to 2 hours, to 12 hours, to 24 hours). Scans less than 2 hours apart can rule expiry out for most listings. Scans 9 hours apart cannot.

Costs we assume, not yet confirmed on Forever: the auction house keeps 5% of a sale, and a deposit is paid to post and returned on a sale. The ledger will confirm both from mail invoices.

## The market in plain terms

| Term | On the auction house | How we measure it |
|---|---|---|
| Asking price | What a seller listed an item for | The scan |
| Lowest price | The cheapest unit for sale now | The scan |
| Floor | The price once the cheapest few units are skipped. What you pay if the stray bargain is gone | The price a fifth of the way up the units |
| Median | The price of the middle unit for sale, not the average. 50 at 6s and 10 at 59s has a median of 6s | The scan, weighted by units |
| Going rate | The median, blended across scans so one odd scan does not swing it | 30% toward each new scan's median |
| Usual low | What the lowest price normally is | The middle of the lows across scans |
| Spread | The gap between what you can buy at and what you could relist at, after the cut | Lowest against floor or going rate |
| Depth | How many units sit at each price | The price ladder |
| Supply | How many units are for sale in all | The scan |
| Turnover | How fast units leave the house by being bought | Probable only: scan to scan flow |
| Demand | Buyers wanting the item. Never seen directly | Inferred from turnover |

## Abundance and scarcity

The starting idea: abundance means not in demand, scarcity means high demand or rarely for sale.

That is often true, and supply alone cannot tell us when it is not. The same supply number can mean opposite things:

- **Linen Cloth** is among the most abundant items in the scans (thousands of units listed) and among the fastest moving. Abundant and in heavy demand.
- **A rare pattern with one listing** may be scarce because everyone wants it, or because nobody bothers to list something nobody buys.

So supply needs a second number beside it: turnover. Together they give four kinds of market.

| | Sells fast | Sells slowly or never |
|---|---|---|
| **Plenty for sale** | **Staple.** Cloth, ore, food. Reliable prices, thin margins, safe to trade in volume | **Glut.** More than buyers want. Prices drift down. A low price here is not a deal |
| **Few for sale** | **Hot.** Demand outruns supply. Prices rise. Where cornering and sniping pay | **Dead or rare.** Nobody lists it and nobody asks. A price here means little |

What this means for the addon:

- **Scarcity is its own signal, not part of the deal number.** A row can be a deal, scarce, both or neither.
- **"Few for sale" is easy** and can be shown today from one scan.
- **"Sells fast" is the hard half.** It needs flow between scans (in the lab now, as an estimate) or the ledger (confirmed, but only for what you trade).
- Until the addon has turnover, it can say "scarce" but not "in demand", and should not pretend otherwise.

## What is a good deal?

There is no single answer. A trader means at least four different things by it, and each needs different data.

| Question | Meaning | Data needed | Status |
|---|---|---|---|
| A. Is it cheaper than I would otherwise pay? | The price sits under the floor and the usual low | One scan, better with history | Built, addon and lab |
| B. Is it cheap for what it is? | Under the going rate over days or weeks | Price history | Partly: the going rate exists, a trend does not |
| C. Can I resell it for more, soon? | Spread after the cut, and it actually sells | Turnover, the cut, the deposit | Lab only (Flips), as an estimate |
| D. Is it worth having? | Useful to this character | The character | Only "Can use" and "Afford" filters |

Rule A is what the deal badge and deal meter mean today:

- **Baseline:** today's floor, held down to the usual low once three points of history exist. The baseline is whichever is lower.
- **Deal:** how far a price sits under the baseline, and for how many units.
- **Badge:** 30% or more under, with something behind the baseline (history, or three different prices today).

Worked examples from the scans of 12 and 13 November 2026:

| Item | For sale | Reading under rule A |
|---|---|---|
| Field Guide | 1 at 6s 97c, 50 more from 8s 96c to 9s 98c | Baseline 8s 97c. The cheap unit is 22% under. No badge |
| Blueprint: Field Guide | 1 at 12s, 7 at 60s. Listed between 49s and 1g 99s in every earlier scan | Baseline 50s. 76% under. Badge |
| 50 at 6s and 10 at 59s (made up) | The bulk is at 6s | Baseline 6s. 6s is the normal price. The 59s listings are the odd ones |

Rule A's known blind spots:

- It is built on asking prices. A whole market of wishful prices still produces a baseline.
- It does not know whether the item sells, so it cannot answer question C.
- In a falling market the usual low lags, and waiting may beat buying.

## How players make money

The ways a trader profits, and what each one depends on.

| Method | What you do | Depends on | Our support |
|---|---|---|---|
| Sniping | Buy a single mispriced listing the moment it appears | Speed, and knowing the real price | The deal badge. Scans are too slow to be first |
| Flipping | Buy what is listed under the going rate, relist at it | A real spread after the cut, and steady turnover | Resell tab. Lab Flips adds turnover |
| Resetting or cornering | Buy all the cheap supply, relist higher | Low supply, real demand, slow restock | Lab Corner only |
| Undercut selling | Post just under the cheapest to sell first | Knowing the competition | Sell tab price rules |
| Riding the cycle | Buy when supply peaks, sell when it thins | A repeating pattern by time of day or week | Not built. Needs weeks of history |
| News trading | Stock up before a patch changes a recipe or drop | Reading patch notes early | Lab News tab |
| Vendor floor | Buy anything listed under its vendor price | The vendor price | Not built. The tooltip already shows the game's sell price |

Community guides (TradeSkillMaster and others) add rules of thumb worth testing against our own data before trusting them:

- Buy flips at no more than about 70% of market value, and list a little above it.
- An item that sells rarely is not worth buying in bulk, however cheap.
- Rare items such as recipes sell slowly but have far less competition.
- The cut is commonly given as 5%, with a deposit that is lost when an auction expires.

## Signals: what we have and what we could add

| Signal | Answers | Source | Addon | Lab |
|---|---|---|---|---|
| Lowest price, and units at it | What does it cost now? | Scan | Yes | Yes |
| Floor | What do I pay once the bargain is gone? | Scan | Yes | Yes |
| Median and going rate | What is it listed for, typically? | Scan, history | Yes | Yes |
| Usual low | What is its lowest price normally? | History | Yes | Yes |
| Deal percent and units | Question A | Scan, history | Yes | Yes |
| Price confidence | How many independent prices back this? | Scan | Yes | Older rule |
| Supply (for sale, all prices) | Abundant or scarce? | Scan | Shown, not judged | Shown |
| Turnover (sells per day) | Does it move? | Flow | No | Estimate |
| Restock (new units per unit sold) | Does supply refill? | Flow | No | Estimate |
| Relists | Are sellers undercutting each other? | Flow | No | Estimate |
| Trend | Rising or falling? | History | No | No |
| Spread after the cut | Question C | Scan, costs | Resell tab | Flips |
| What I paid, what I sold for | My real results | Ledger | Yes | No |
| My sale rate | Does it sell for me? | Ledger | No | No |

## Evaluations to try in the lab next

Each is a proposal. Market type (1) is built in the lab's Find tab as a first pass; the rest are not built.

First results for market type, from the seven scans of 12 and 13 November 2026: 378 hot, 659 staple, 2,221 glut, 2,238 quiet, 9,091 unknown (mostly random-suffix gear the scan cannot follow). The hot list reads right to a trader (Arcanite Bar, Fiery War Axe, Pattern: Robe of the Archmage). The thresholds are first guesses: Field Guide reads quiet with 51 for sale because stackable goods are counted by the stack.

1. **Market type.** Label every item staple, glut, hot or dead from supply and turnover. Show it as a column and a filter. Check: do the labels match what a trader would say about items they know?
2. **Scarcity mark.** A plain "few for sale" mark from one scan, with the count, and no claim about demand. Check: does it flag useful things, or mostly junk nobody lists?
3. **Trend.** Is the going rate rising, flat or falling over the kept history? Check: does "falling" on Field Guide (12s 80c to 9s in a day) read correctly?
4. **Resale deal (question C).** A deal only counts if the spread survives the cut and the item's turnover would sell the load within a set number of days. This is Flips, expressed as a deal reading.
5. **Outlier listings.** Mark asking prices far above the bulk as out of line, so a ladder shows which prices to ignore.
6. **Ledger feedback.** Once sales come in from mail, compare what the lab predicted with what actually sold, and at what price. This is the only way to check any of the above against the truth.

7. **Deal confidence.** Raised in review on 13 November 2026: a deal should not be shown at all unless we are confident enough in it, and for resale that bar is higher. Confidence would be its own reading, separate from how big the discount is, built from:
   - **Days of data.** One scan is a snapshot. A baseline seen holding over several days is worth far more.
   - **Evidence it sells.** Turnover from scan to scan, and in time the ledger.
   - **Independent prices.** Several different prices, not one seller's wall.
   - **A sanity floor.** The vendor's sell price, which the game gives us. A "deal" sitting just over vendor price while the others ask ten times more (Twilight Belt of the Elder: 1 at 23s, vendor 15s 60c, three more near 2g 88s) says the others are hopeful, not that 23s is a steal.

   The badge would then need both a discount and a confidence over a set threshold, with a stricter threshold for the Resell tab. Check: random-suffix green gear, which fills the deals list today at 85% to 92% under, should mostly drop out.

   **First pass, built in the lab's Find tab on 13 November 2026** (`src/model/deal-confidence.ts`, rules in `src/config/signals.ts`, in `../ahero-lab`). Scored 0 to 100: days seen up to 35, units seen selling up to 40, different prices up to 25, capped at 25 when the vendor check trips. A deal is shown from 40 to buy for yourself and from 65 to buy for resale. On eight scans over two days:

   | | Deals |
   |---|---|
   | Badges with no confidence bar | 717 |
   | Confidence 40 or more | 38 |
   | Confidence 65 or more | 13 |

   The random-suffix greens at 90% and more under all read Low: one or two days, sales unreadable, one or two prices. What clears the bar is goods that visibly sell: Swiftness Potion, Coarse Thread, Solid Stone, Swiftthistle, Lesser Bloodstone Ore, at 30% to 50% under.

   Known gaps: two days of scans cannot score above the second step for days. The lab only knows the vendor price for about a third of items (the game's tables leave out most random-suffix gear), though the addon can ask the game for any item. Sales cannot be read for random-suffix gear at all, so it can never reach the resale bar.

## Options the player could be given

The addon should not decide alone what a deal means. Possible choices to offer, each a setting or a filter:

- **What "deal" compares against:** what I would otherwise pay (A), the going rate over time (B), or resale after costs (C).
- **How strict:** the percent under the baseline that earns a badge (30% now).
- **How much evidence:** today's listings only, or only when history backs it.
- **Minimum units:** ignore a deal on a single stray unit.
- **Market types to show:** hide gluts and dead markets.

## Open questions for review

1. Is the four-way split (staple, glut, hot, dead) the right model, or should abundance and scarcity stay as you first stated them?
2. For a banker character, should the deal badge mean question A (cheaper than otherwise) or question C (will resell for more)?
3. Should a deal on one single unit earn a badge at all?
4. Which of the six lab evaluations should be tried first?
5. Which of the player options are worth exposing, and which should stay fixed rules?
6. Until turnover exists in the addon, should it show a scarcity mark at all, given that it cannot tell hot from dead?
7. What should the deal confidence threshold be for buying to use, and what stricter one for reselling? And how many days of data before any deal is shown?

## Sources

- [TradeSkillMaster blog](https://blog.tradeskillmaster.com/page/3/): market value and sale rate as the community uses them
- [Goblin lingo and gold making glossary](https://reddit.rtrace.io/r/woweconomy/comments/gtxs5s/goblin_lingo_and_gold_making_glossary): resetting, flipping, sniping defined
- [How to trade using the WoW market overview, Saddlebag Exchange](https://saddlebagexchange.com/blog/wow/how-to-trade-using-our-wow-market-overview): sale rate against competition for rare items
- [WoW Classic Era auction house flipping, Timesaver](https://timesaver.gg/blog/wow-classic-era-auction-house-flipping-gold): flipping as buying under market value and keeping the spread after fees
- [Season of Discovery item flipping guide](https://www.baltictimes.com/world_of_warcraft_season_of_discovery_item_flipping_guide_for_beginners): flipping basics
- [What is market liquidity, CMC Markets](https://www.cmcmarkets.com/en-gb/trading-strategy/what-is-market-liquidity): liquidity, spread and depth
- [Evaluating stock liquidity, Bookmap](https://bookmap.com/blog/evaluating-stock-liquidity-what-every-trader-should-know/): reading spread and depth together

The guides are community advice and several are promotional. Their figures are opinions to test against our own scans and ledger, not facts.

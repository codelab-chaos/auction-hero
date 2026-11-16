# Gold ladder: 1g to 10g by flipping

A tiered buy and sell plan for a low-level character (level 15) starting with
about 1g, built from the lab's scans of our auction house. It answers two
questions: what to buy and resell at each stage, and how long reaching 10g
takes if every auction sells within 10 minutes.

## The short answer

- **About 5 to 6 days of market time**, for **about 4.5 to 5 hours of selling**
  (roughly 28 ten-minute cycles) and **about 2.5 hours of buying and posting**
  by hand (roughly 700 auctions at 12 seconds each).
- Starting gold matters very little. What limits the climb is how many
  underpriced listings the market produces, about **1.6g of flip profit a day**
  in the scans we have.

| Start | After 12 scans (2.4 days) | Profit | Selling time |
|---|---|---|---|
| 50s | 4.34g | +3.84g | 120 min |
| 1g | 4.86g | +3.86g | 120 min |
| 2g | 6.47g | +4.47g | 130 min |

With unlimited gold the same 12 scans hold only about 4.5g of flip profit, so
past roughly 2g more gold does not help; waiting for new cheap listings does.

## The tiers

The items below came up again and again across scans, not once. Buy at or
under the first price, post at the second. Margins are after the auction
house's 5% cut.

### Tier 1: up to 1.5g. Cheap goods, big margins

| Item | Buy at or under | Post at | Margin | Sells a day |
|---|---|---|---|---|
| Wool Cloth | 1s | 1s 45c | 35 to 300% | 200 to 900 |
| Tiger Meat | 3s | 5s 50c | ~75% | 25 to 200 |
| Mystery Meat | 1s | 2s 25c | ~110% | 15 to 200 |
| Rumsey Rum Black Label | 1s 50c | 2s | 25 to 90% | 3 to 40 |
| Heavy Stone | 2s | 3s 40c | 40 to 110% | 45 to 570 |
| Light Leather | 25c | 30c | 20 to 40% | 275 to 375 |

### Tier 2: 1.5g to 3g. Mid-priced goods and crates

| Item | Buy at or under | Post at | Margin | Sells a day |
|---|---|---|---|---|
| Solid Stone | 1s 10c | 1s 75c | 45 to 65% | 130 to 1,300 |
| Small Flame Sac | 2s 50c | 5s 95c | ~125% | ~90 |
| Mageweave Cloth | 2s 50c | 5s | ~90% | ~150 |
| Waylaid Crate: Expert Parts | 1s 25c | 1s 75c | ~55% | ~20 |
| Swiftthistle | 2s | 2s 10c | ~20% | ~50 |
| Red Linen Bag | 3s 10c | 4s | ~20% | ~6 |

### Tier 3: 3g to 10g. The same goods in batches of 1g or more

| Item | Buy at or under | Post at | Margin | Sells a day |
|---|---|---|---|---|
| Silk Cloth | 1s 65c | 2s | 15 to 18% | ~800 |
| Raptor Flesh | 2s 50c | 2s 55c | ~19% | ~260 |

Keep taking Tier 1 and Tier 2 flips whenever they appear. In Tier 3 the money
comes from volume, and the limit is how much cheap stock is listed.

Starting with 1g, run Tiers 1 and 2 together from the first market; Tier 3
batches open about a day sooner than from 50s.

## How it was worked out

A simulation walked a character through the real scans in order, carrying its
gold from one to the next. At each scan it bought underpriced listings and
reposted them, under these rules:

- **Sell price.** What the item has actually sold for, from the lab's confident
  sales (vanished before its time could run out, not relisted lower, with a
  dearer listing kept). Each gap between scans gets one vote, the median price
  sold in that gap, and the lower median of the votes is used. One odd gap
  cannot set the price.
- **Evidence.** Only items sold in at least 3 separate gaps.
- **Posting.** One copper under the next listing still up, never above the sell
  price, so the reposted auction is the cheapest.
- **Margin.** At least 15% after the 5% cut.
- **Demand.** No more units per scan than sell in that much time, with the
  busiest gap left out of the rate so one sweep cannot inflate it.
- **Selling.** Every posted auction sells within one 10-minute cycle.

The data: 12 scans from 12 to 15 November 2026, with sales confirmed over 8
gaps covering 28 hours.

## What it does not account for

- **The 10-minute assumption is generous.** Fair for cloth, meat and stone,
  which sell hundreds a day; not for gear such as Scouting Spaulders, which
  sells about once a day. Treat gear flips as a bonus.
- **The days are probably too many.** Scans are 2 to 10 hours apart, so cheap
  listings that came and sold between them are missed. Watching the market
  live, with Auction Hero's price checks before each buy, finds more.
- **Competition.** Other flippers chase the same listings.
- **Deposits.** Refunded on a sale, but they tie up gold while listed.
- **Thrown-out spikes.** Prices set by a single odd gap (a crate whose "49s"
  came from one gap where every other sale was 40c to 5s) were left out.

## Ways to go faster

- **Watch the market more often.** Scanning every 15 minutes, or refreshing the
  filtered view, catches listings the hourly scans miss.
- **Accept a lower margin.** At 10% instead of 15% more flips qualify.
- **Gather Tier 1 goods.** At level 15, Wool Cloth, Light Leather and meats cost
  nothing but time, so the whole sale is profit.

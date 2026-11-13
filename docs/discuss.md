For WoW: Forever, I'd aim for something between Auctioneer and the default Auction House UI.

Auctioneer is powerful, but much of its complexity comes from trying to be an entire trading platform. I think a smaller addon could deliver most of the everyday value with three things:

1. Price intelligence - What's this item actually worth?
2. Simple selling - What should I list it for, and how much will I receive?
3. Quick buying - Is this a good price compared with what I've seen before?

The interesting technical question is how much of the modern Retail Auction House API Forever exposes. That determines whether we can build a lightweight Auctioneer successor or need a more restricted design.

## What exists for WoW: Forever right now

There are already three interesting options, and one is particularly close to what you're describing.

| Addon       | Forever status           | Approach                                      |
| ----------- | ------------------------ | --------------------------------------------- |
| Auctionator | Forever build available  | Simple selling, shopping lists, price history |
| auxForever  | Active Forever beta      | Fast searching, selling, scanning, pricing    |
| Auctioneer  | Community port available | Full traditional Auctioneer suite             |

Auctionator has a Forever-specific release, and auxForever was updated November 10. There's also a community Auctioneer port, although it's not the official release.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://wowforeveraddons.com\&sz=32)

WoW Forever Addons+2



My first recommendation would be to try Auctionator and auxForever before writing anything. They make useful reference implementations even if you ultimately build your own.

[Auctionator - World of Warcraft Addons - CurseForge](https://images.openai.com/static-rsc-4/fGFeRHh2-NUitFp0VHWD20pWM-VCAv18rSYNSmkQhFOQ7Kz35vsq0w7C3sO-iGoje9L-BNZ_gQSKT3tfBL0rhQ_4xe_ueiBXX3mTT82j1GgjnWmbh98hlExikc4GQqLhBAGrdHh7AtpD1_hXQ05TPmnbj3YGCBh8-uyaNb3KM78?purpose=inline)

[Auctionator for Forever](https://wowforeveraddons.com/addons/auctionator?utm_source=chatgpt.com)

Closest to a simplified Auctioneer. Price scanning, tooltips, shopping lists, and quick posting.

[Auctionator vs Auctioneer Which one is the best Auction House Addon In 2026 | by Dia Nape | Medium](https://images.openai.com/static-rsc-4/EB1QJWhuRBeAcDW2kDDY_kZkKvK6tSrlvKaPqcTHvvW1nfilXCAD6PiF0mqMoGhABtbd1hcAZu8y7pN3Ew4xExWuvOPJBmduDplCVVob2q7L7zukkZoFIdS5XSZtPJN9KWJhaJcgMoGLuB4p0Be4biTa1xdscyN9FIb6e59f7mA?purpose=inline)

[auxForever](https://www.curseforge.com/wow/addons/auxforever?utm_source=chatgpt.com)

More ambitious, but its scan, posting, and pricing implementations are especially relevant to your development plans.

## The Auction House API

Forever uses a modern `C_AuctionHouse` interface rather than the old Classic-era auction functions. Its generated API documentation is available in the [Forever API reference](https://github.com/Atraeau/WoW-Addons/blob/main/docs/api/README.md?utm_source=chatgpt.com).&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub



These are the important calls I'd investigate first:

| API                                        | Purpose                               |
| ------------------------------------------ | ------------------------------------- |
| `C_AuctionHouse.SendSearchQuery`           | Search for an item                    |
| `C_AuctionHouse.GetItemSearchResults`      | Retrieve item listings                |
| `C_AuctionHouse.GetCommoditySearchResults` | Retrieve commodity prices             |
| `C_AuctionHouse.ReplicateItems`            | Request a broad auction snapshot      |
| `C_AuctionHouse.GetReplicateItemInfo`      | Read replicated auction entries       |
| `C_AuctionHouse.PostItem`                  | Post equipment or other item auctions |
| `C_AuctionHouse.PostCommodity`             | Post commodities                      |

The exact signatures, permissions, and event sequences need checking against the Forever build. The presence of an API in the client documentation doesn't guarantee unrestricted use.

An important practical detail: auxForever reports that full scans are limited to once every 15 minutes.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://www.curseforge.com\&sz=32)

CurseForge



### There's also an external auction API

This is particularly interesting for development.

Blizzard's Forever API now exposes auction data through ruleset-based endpoints. A November 6 developer report confirms working endpoints for auction-house indexes, item auctions, and commodities.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://us.forums.blizzard.com\&sz=32)

Blizzard Forums



```

GET /data/wow/ruleset/{id}/auctions/
GET /data/wow/ruleset/{id}/auctions/{houseId}
GET /data/wow/ruleset/{id}/auctions/{houseId}/commodities

```

These use Blizzard's authenticated web API, not in-game Lua. You could build an external market analysis service, although the addon itself cannot freely make arbitrary HTTP requests.


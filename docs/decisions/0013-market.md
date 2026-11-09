# 0013: The market (shelter, transfers, stalls, search, auctions, Black Market)

- **Status:** accepted (owner decisions Nov 2 2026: 11:00, 11:35 and 18:00 ET in MAIN_TO_EXT)
- **Date:** 2026-11-03
- **Area:** save / farm / UI (economy)

## Problem
Boki are sold for gems in two places (the Drift Pens, `BokiPens`, and the web town market, `Social.sell_kin`), which made a gem mint (buy a pen Boki, list it higher) and treats Boki as stock. Items have no market at all beyond the Exchange's materials. A farm-start island has no market stall until you build one, so players can't find the shop. The Ransom House is to become the Black Market with rare stock.

## Options
1. Patch the pens (caps, locks) and add item listings beside them. Rejected: two Boki-selling systems stay, and the mint is only capped.
2. Neopets model (decided): Boki never sell for gems. A shelter (adoption for gems that are destroyed, giving pays nothing) and direct transfers (flat fee, weekly). Items get player stalls, a lowest-price search and an auction house; materials stay on the Exchange. One stall on every farm, upgraded L1 to L3, that opens what its level offers.

## Decision
- **Numbers** in `content/rules/market.json` (fees, taxes, shelter prices and limits, transfer fee, auction rules, rarity restock odds, the goods catalogue). Code: `Shelter` (scripts/core/shelter.gd, replaces boki_pens.gd), `Transfer`, `Goods` (what can be traded and where it is held), `Stalls` (stalls, NPC stalls, search), `Auction`, `BlackMarket` (rare stock; `Ransom` keeps the ransom rules). UI: `HomeMarket` (stall tabs), `HomeBlackMarket` (moved out of home.gd), `HomeStall` (placing the stall) and `StallModels`.
- **Stall level** = the tier of the placed `market_stall` (FarmSites tiers, same upgrade costs and Boki labour as other buildings). L1 the general vendor (the old shop tabs) and the Exchange; L2 adds Shelter, My stall and Search; L3 adds Auctions. Locked tabs are hidden, with one line saying what the next level opens. Ungated (classic) farms have no upgrades, so their stall counts as L3. The hub bar's Market button opens the same panel.
- **Every save has a stall:** on load of a farm-start island with no stall placed or stored, one is set down near the portal (search outward, every rotation, `HomeBuild.fits`); if nothing fits it goes to storage with a one-time hint.
- **Shelter:** daily strays (commons) plus Boki players give up. Adopting costs gems by level, rarity, shimmer and mutations; the gems are destroyed. Giving pays nothing; not your last Boki, a pinned one, an egg parent, one under 7 days old, or one already put up today; you can never adopt back one you gave. History keeps "raised by <name>", trust keeps half. Offline, NPC adopters take given Boki now and then.
- **Transfer:** hand a Boki to a named player for a flat fee (destroyed), one per week per sender, both confirm (send, then the other side accepts). The packet is the cleaned record (`Social.clean_kin`). Offline there is nobody to accept, so a sent Boki waits and can be called back (fee refunded); the server delivers it later.
- **Goods:** gear (armory pieces), belt utility, Boki wear (accessories, new collar and charm), dyes (recolour worn accessories), boss trophies (from boss kills), rare materials (expedition finds). Each has a rarity that sets how often NPC stalls restock it. Exchange commodities (tonics, kibble, crops, wood, stone, scrap) stay on the Exchange only.
- **Fees and the anti-mint rule:** stalls and auctions charge a listing fee (5%) and a sale tax (10%). Offline, NPC buyers and bidders pay at most 0.8x an item's reference price, and every NPC seller (stalls, auctions, the vendor, the Black Market) asks at least 1x, so buying from the game and selling back always loses gems. Shelter giving pays 0.
- **Auctions:** start price, minimum increment, 12/24/48h, friends-only flag (NPCs never bid on those). Bids are escrowed at once, refunded when outbid, never withdrawn; a bid in the last minute pushes the end out to two minutes left.
- **Black Market:** the Ransom House flow (buy back, haggle, offer plus a message to a captor, their offers, the log) under the Black Market name, plus a small daily rotation of rare goods and a Rare Egg at 2x+ reference price (a sink). No keys, shards or match-only items.

## Consequences
- Save v7 -> v8 (`MarketMigrate`): open Drift Pens listings and web kin listings go back to their owners' rosters; `pens` is removed; `goods`, `market` (stall listings, auctions, transfers, shelter memory) get defaults.
- Removed: `BokiPens`, `Social.sell_kin` and kin listings on the web market, `origin.pen_line`, the pens' tick and their results line.
- Net.VERSION unchanged (nothing synced). The server protocol shape is in docs/EXCHANGE_SERVER.md.
- Check: `--market-check` (registered). `--economy-floor-check` keeps the floor and Exchange parts.

# The Exchange and the market on the server

Status: **design stub.** The local versions are built and tested (`scripts/core/exchange.gd`,
`scripts/core/shelter.gd`, `stalls.gd`, `auction.gd`, `transfer.gd`, `--economy-floor-check`, `--market-check`; docs/decisions/0013-market.md). This document says how they move onto the
private backend described in `ARCHITECTURE_PLAN.md` (design branch) §4-5, Phase 6. Nothing here is
built yet.

## What exists now (local)

| Piece | Code | What it does offline |
|---|---|---|
| Tradewind Exchange | `Exchange` (`scripts/core/exchange.gd`) | Order book for wood, stone, scrap, crops, kibble, tonics. Price-time matching, partial fills, 4% tax on the seller's gems, price history. Tradewind's market makers stand in for other players: standing offers round today's price, rebuilt daily; resting player offers fill a little each expedition (`Exchange.tick`). |
| Shelter | `Shelter` (`scripts/core/shelter.gd`) | Boki are never sold for gems. Daily strays plus Boki players gave up; adopting costs gems that are destroyed, giving pays nothing (limits: not the last or a pinned Boki, 7 days old, once a day, no re-adopting your own). Offline, NPC adopters take given Boki (`Shelter.tick`). |
| Transfers | `Transfer` (`scripts/core/transfer.gd`) | Hand a Boki to a named player: flat fee (destroyed), one a week, the receiver accepts a packet (`Social.clean_kin`). Offline it waits in the outbox. |
| Stalls and search | `Stalls` (`scripts/core/stalls.gd`), `Goods` | Your stall (5% fee, 10% tax) for gear, utility, Boki wear, trophies, dyes, rare materials; NPC stalls restocked daily by rarity; search for the lowest price. NPC buyers pay at most 0.8x reference. |
| Auction House | `Auction` (`scripts/core/auction.gd`) | Start, step, 12/24/48 h, friends-only; bids escrowed, refunded when outbid, never withdrawn; a bid in the last minute extends to two minutes left. NPC lots and bidders offline. |
| The floor | `Lifeline` (`scripts/core/lifeline.gd`) | A stray common turns up on a farm with no Boki. Combined with pen prices, nobody is ever stuck. |

Every function the UI calls returns a plain dictionary (`{ok, why, ...}`) and never assumes the
result is immediate, so the same calls can become requests to the backend without changing
`scripts/home/home_market.gd`.

## Who owns what online

Following `ARCHITECTURE_PLAN.md` §2 (principles) and §3 (public/private split):

- **Private backend** (`project-boki-backend`): accounts, the inventory ledger (gems, materials,
  Boki ownership), the order book, Boki listings, trades, the stray grant,
  history. Postgres; one small service.
- **Public match server** (headless Godot, this repo): runs matches, then commits the match result
  (what each player extracted) to the backend with its server key. It never touches the order book.
- **Client** (this repo): reads the book and listings, sends post/cancel/buy/list requests, shows
  results. It never decides a fill, a price, an ownership change or a balance.

The local save becomes a cache of the online profile; the offline profile (today's `Save.d`) never
imports into online (ARCHITECTURE_PLAN §7.1).

## The Exchange on the server

### Data

```
commodity(id, name, ref_price, band_lo, band_hi, tax_bp)
inventory(account_id, commodity_id, qty, held)          -- held = escrowed in open sell offers
wallet(account_id, gems, held)                          -- held = escrowed in open buy offers
offer(id, account_id, commodity_id, side, price, qty, left, created_at, state)   -- open|filled|cancelled
fill(id, buy_offer, sell_offer, commodity_id, price, qty, tax, at)
price_bar(commodity_id, bucket_start, open, high, low, close, volume)   -- 5 min / 1 h / 1 day
ledger(id, account_id, kind, delta_gems, delta_item, ref, at)          -- append-only, every change
```

### Requests (client -> backend, authenticated as the account)

| Request | Validation | Effect |
|---|---|---|
| `post {side, item, qty, price}` | commodity exists; 1 <= qty <= 999; price inside the band; open offers < 8; enough free gems (buy) or goods (sell) | escrow, then match (below), then rest the remainder; returns `{ok, id, filled, left}` |
| `cancel {id}` | the offer is the caller's and open | release escrow of `left` |
| `book {item}` | none | aggregated depth by price, 10 levels a side |
| `history {item, span}` | none | price bars |
| `mine` | none | caller's open offers and recent fills |

### Matching

One matcher per commodity, single-threaded (a row lock on the commodity, or a queue partitioned by
commodity). Price-time priority: the incoming offer walks the opposite side from the best price,
oldest first at each price, filling at the resting offer's price. Each fill is one transaction:
move goods buyer-ward and gems seller-ward out of escrow, take the tax from the seller's gems, refund
a buyer's price improvement, write `fill` and two `ledger` rows, update the bar. This is exactly
`Exchange._match` / `Exchange._fill`; port them and replay `tools/` vectors (below) against both.

### Sinks, faucets and guards

- Tax 4% of each fill's gems (basis points per commodity, tunable). The main material sink.
- No market makers online at first. If a closed playtest's book is too thin, a backend "Tradewind"
  account can post bounded standing offers from a budget (a faucet, so it's metered and logged).
- Rate limits: posts and cancels per minute per account; a cancel-repost churn limit.
- Band: offers outside 0.4x-2.5x the reference price are refused (the reference moves with the
  daily close), which blunts price manipulation and fat-finger trades.
- Wash trading: an account can't fill its own offers (the local matcher already skips same-owner).
- Materials enter only through match results and farm production that the backend accepts (farm
  production online needs its own server-side rule: elapsed time x assigned Boki x station caps,
  the same as `Work.catch_up`; until that exists, farm materials are offline-only).

## The market on the server

### Data

```
boki(uid, account_id, species, record_json, edition, serial, origin, created_at)   -- the ledger of Boki
shelter_card(id, boki_uid, giver_id, price, put_up_day, state, adopter_id)       -- adoption gems are burned
transfer(id, boki_uid, from_id, to_id, fee, created_at, state)                   -- pending|accepted|recalled
stall_listing(id, account_id, good_key, payload_json, price, fee_paid, state, buyer_id, sold_at)
lot(id, account_id, good_key, payload_json, start, step, ends_at, friends_only, top, top_bidder, state)
bid(id, lot_id, account_id, amount, held, created_at)
```

### Requests (the local functions, as requests)

| Request | Validation | Effect |
|---|---|---|
| `shelter.give_up {uid}` | `Shelter.why_not` (owned, not last/pinned/egg parent, 7+ days old, not today) | the Boki leaves the roster; no gems move |
| `shelter.adopt {id}` | not your own gift; gems; room | gems burned; ownership moves; trust halves; `raised_by` appends |
| `transfer.send {uid, to}` | as give_up, plus a week since the last; fee | fee burned; pending until `transfer.accept` by `to` |
| `stall.list/unlist/buy`, `search {text}` | owned good; cap 6; price 1..99999 | fee up front; buyer pays, seller gets price less 10% |
| `auction.create/bid` | 12/24/48 h; bid >= top + step; not your own lot | escrow; refund the outbid; extend in the last minute; settle at `ends_at` |

Online there are no NPC buyers, sellers, adopters or bidders: those are the offline stand-ins
(`*.tick`). Friends-only lots take bids only from the seller's friends (guild members until a
friends list exists).

## The floor on the server

- **Strays**: a backend rule on login: an account with zero Boki gets one ordinary common
  (`origin.how = "stray"`). Accounts can't release, give up or hand on their last Boki, so this only follows a
  real loss, and it mints no gems.

## Moving the client over

1. Add `ExchangeApi` / `MarketApi` (client side) with the same function names as `Exchange`,
   `Shelter`, `Transfer`, `Stalls` and `Auction`, returning through callbacks. `BACKEND` picks the implementation.
2. `HomeMarket` already reads results as `{ok, why, ...}` and redraws; switch its calls to the
   callback versions (a spinner while waiting).
3. `Game.apply_result` stops calling `Exchange.tick` / `MarketSave.tick` online (the backend fills
   offers in real time) and shows fills from `mine` instead.
4. Test vectors: `tools/export_econ_vectors.gd` (to write, ROADMAP §2 E6) runs the local matcher on
   scripted books and writes input/expected-output pairs; the backend's tests replay them and must
   match byte for byte.

## Open questions for the owner

- Exchange tax 4%, stall and auction fees 5% / tax 10%, transfer fee 40: fine as starting numbers?
- Online market makers (a metered Tradewind account) for a thin playtest book, or no makers at all?

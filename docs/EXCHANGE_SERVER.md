# The Exchange and the Drift Pens on the server

Status: **design stub.** The local versions are built and tested (`scripts/core/exchange.gd`,
`scripts/core/boki_pens.gd`, `--economy-floor-check`). This document says how they move onto the
private backend described in `ARCHITECTURE_PLAN.md` (design branch) §4-5, Phase 6. Nothing here is
built yet.

## What exists now (local)

| Piece | Code | What it does offline |
|---|---|---|
| Tradewind Exchange | `Exchange` (`scripts/core/exchange.gd`) | Order book for wood, stone, scrap, crops, kibble, tonics. Price-time matching, partial fills, 4% tax on the seller's gems, price history. Tradewind's market makers stand in for other players: standing offers round today's price, rebuilt daily; resting player offers fill a little each expedition (`Exchange.tick`). |
| Drift Pens | `BokiPens` (`scripts/core/boki_pens.gd`) | The Boki market. Wenna's daily stock of ordinary commons at 30-45 gems (the economy floor), plus your own listings (5% listing fee, 5% sale tax), filtered by species, size, IVs, special rolls, provenance. Offline, your listings sell to Wenna's regulars now and then (`BokiPens.tick`). |
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

## The Drift Pens on the server

### Data

```
boki(uid, account_id, species, record_json, edition, serial, origin, created_at)   -- the ledger of Boki
listing(id, boki_uid, seller_id, price, fee_paid, created_at, state, buyer_id, sold_at)
pen_stock(day, slot, boki_uid, price)          -- Wenna's daily commons, minted by the backend
```

### Requests

| Request | Validation | Effect |
|---|---|---|
| `listings {filter}` | none | paged, filtered by species, size, IV total, mutation/shimmer, provenance, edition |
| `list {uid, price}` | the caller owns it; not their only Boki; not pinned (partner/starter); price in the fair range (from `Ransom.value`, ported) | take the 5% fee; lock the Boki (it leaves the roster while listed) |
| `unlist {id}` | the caller's, open | unlock it (fee not refunded) |
| `buy {id}` | open; not the caller's; enough gems; the buyer's box has room | one transaction: gems buyer -> seller less 5% tax; ownership moves; provenance appends a `traded` event with both trainers |

Wenna's stock is minted by the backend each day (commons, ordinary rolls, priced 30-45). It's the
only place new Boki enter the economy for gems, so it's capped per account per day (e.g. 2 buys) to
stop it becoming a farm for resale; pen Boki carry `origin.how = "market"` and `from = "Wenna"`.

Later: auctions (timed, highest bid, anti-snipe extension) and direct player-to-player trades (both
parties confirm a two-sided offer; one transaction) use the same `boki` and `ledger` tables.

## The floor on the server

- **Strays**: a backend rule on login: an account with zero Boki gets one ordinary common
  (`origin.how = "stray"`). Accounts can't release or list their last Boki, so this only follows a
  real loss, and it mints no gems.

## Moving the client over

1. Add `ExchangeApi` / `PensApi` (client side) with the same function names as `Exchange` and
   `BokiPens`, returning through callbacks. `BACKEND` picks the implementation.
2. `HomeMarket` already reads results as `{ok, why, ...}` and redraws; switch its calls to the
   callback versions (a spinner while waiting).
3. `Game.apply_result` stops calling `Exchange.tick` / `BokiPens.tick` online (the backend fills
   offers in real time) and shows fills from `mine` instead.
4. Test vectors: `tools/export_econ_vectors.gd` (to write, ROADMAP §2 E6) runs the local matcher on
   scripted books and writes input/expected-output pairs; the backend's tests replay them and must
   match byte for byte.

## Open questions for the owner

- Exchange tax 4% and pen fees 5%/5%: fine as starting numbers?
- Should Wenna's daily pen buys be capped online (proposed: 2 a day)?
- Online market makers (a metered Tradewind account) for a thin playtest book, or no makers at all?

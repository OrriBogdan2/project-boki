# Handoff: ext/economy (Agent D)

Branch `ext/economy`, merged with main sync59 (fcc3745, Net 0.11.0). Review fixes of 2026-11-01 23:05 are in (table at the end). Trimmed on the owner's call: tamed Boki no longer follow you. Main has follow-by-default for your one active Boki and capture-by-scan into the box, so the follower work was removed.

## Status

| Item | Code | Check | Status |
|---|---|---|---|
| Economy floor (stray common on the farm when you have no Boki; last Boki can't be released or listed) | `scripts/core/lifeline.gd`, wiring in game.gd / home.gd / results.gd | `--economy-floor-check` | done |
| Cheap Boki market (Drift Pens) | `scripts/core/boki_pens.gd`, `scripts/home/home_market.gd` | `--economy-floor-check` | done |
| Free-kit loaner Boki | (was `scripts/core/loaner.gd`) | | removed in ext/equal (docs/decisions/0005-equal-footing.md); the sections below about it are history |
| Tradewind Exchange (order book) + server design | `scripts/core/exchange.gd`, `docs/EXCHANGE_SERVER.md` | `--economy-floor-check` | local version done; server is a design doc |
| `--economy-floor-check` | `tools/economy_floor_check.gd` | | registered inline in main.gd (the registry does not exist on this tree; move it when it lands) |

## What was removed in this trim

`scripts/match/follow.gd`, `follow_demo.gd`, `--follower-check` and its tool, `--follow-demo`, `Follow.net_extra` / `net_apply` (sync fields 23-28, the "fgone" event, `KIN_ROLES`, the `follow` kin state, `Hunter.follower`, the `owner_of` change in net.gd), the `follow_steal` tier keys, the `_bring_home` helper and follower result in game.gd, the follower notes in results.gd, the follower and stray HUD, and every follower hook in kin.gd, match.gd, life.gd, bot.gd, hud.gd and hunter.gd. `scripts/match/kin.gd`, `bot.gd`, `hud.gd`, `hunter.gd` and `net.gd` are now identical to origin/main. The sync shape equals main's, so Net.VERSION stays at main's (0.11.0 now).

An idea for a left-behind active Boki (rivals get a short window to capture it) is filed in `docs/DEBT.md`; main already has the `lost_from` rule.

## How the kept pieces meet sync58

- Boki bought at the Drift Pens or a stray common go to the farm roster (`KinBox.route_new`) and never into a match. A bought Boki only becomes the active one when you have none, and it joins a match only if it is your active pick.
- The free-kit loaner is the hunter's one active Boki (`kin2` is empty). It uses the shipped follow (`cmd = "follow"`, Sic, Call back, wheel) like any other, never drops into a box, is never left behind, and goes home to Wenna.
- Caught Boki in a free-kit run go into the box as usual (capture.gd); nothing here touches capture, taming wording or the reserved Boki-system files.

## Touch points in files the main session owns

- `match.gd`: loaner spawn options in `_spawn_hunters`, `_leave_kin` and `_finish` skip a loaner, `r["loaner"]`. No sync changes.
- `life.gd`: `kin_on_death` keeps a loaner out of the deathbox (it goes "away").
- `game.gd`: `apply_result` calls `Loaner.settle`, `BokiPens.tick`, `Exchange.tick`, `Lifeline.check`.
- `home.gd`: wiring only (the `hmk` helper, the shop's two tab lines, one `open_named` branch, and one call each into `HomeFreeKit` for the card, the buttons and the stray toast); the free-kit card, buttons, start and toast live in `scripts/home/home_freekit.gd`. `results.gd`, `main.gd`: notices and the `--economy-floor-check` hook.
- `tools/boki_system_check.gd`: identical to main's again (the Net version assert there is main's to update).

## Review fixes (main session review, 2026-11-01 23:05)

| # | Item | Fix | Asserted by `--economy-floor-check` |
|---|---|---|---|
| 1 | Pens restock re-rolls | `BokiPens.restock()` keeps the stored day and rolls only when today > stored day. An empty stock stays empty until then; a clock set back neither restocks nor moves the day back. The `force` argument is gone. | "buying the pens out leaves them empty", "...even if something asks for a restock the same day", "tomorrow brings 4 fresh Boki", "a clock set back doesn't re-roll the stock", "the stored day never goes backwards" |
| 2 | Buy-then-list gem mint | Boki with origin market, stray or loaner can't be listed (`BokiPens.can_list`, also hides them in the pens panel); at most `MAX_LISTED` = 3 open listings. | "a pen Boki is marked as market-bought and can't be listed", "so buy-then-list can only lose gems", "a stray can't be listed either", "no more than 3 listings at once", "taking one down makes room" |
| 3 | Exchange tick vs infinite counterparty | `Exchange.tick`: zero chance outside `WALK` (15%) of `mid()`; otherwise the traders' quote walks within +/-15% and your offer fills at THAT quote (never worse than asked); the offline traders' half-spread is max(1, 8% of mid) so buy-off-book-then-tick-sell is a loss for every item. Makers now quote around the item's base price and the date (not the last trade or a counter), so buying a side out and refilling it gives the same quotes, no ratchet. | "out-of-band offers never fill (0 fills in 400 runs)", "an offer at the middle fills ... never worse than it asked", per-item "no round trip profits", "the side refills at the same quotes", "buying out the side and selling it straight back loses gems" |
| 4 | Treat cleared on free-kit runs | `Game.apply_result` clears `treat` only when not `r.loaner`. | "your treat is kept on a free-kit run", "...nor your treat, armory or loadout", "a normal run uses the treat up" |
| 5 | Loaner `r["tonics"]` override | Deleted from `Match._finish`; the stash plus found tonics come home. | "the tonics found on a free-kit run come home with the stash (8, want 8)" |
| 6 | Egg-parent guard in `list_mine` | Copied from `KinBox.release`. | "a Boki whose egg is in the Nesting Nook can't be listed" |
| 7 | Dead loaner filters | Deleted from `list_mine` and the pens panel. | (the lock in item 2 covers loaner origin) |
| 8 | Duplicates `Social.sell_kin` | Can't share it yet (async server doc vs synchronous local listing): `docs/DEBT.md` entry with an owner (the exchange-server task). | n/a |
| 9 | `home.gd` grew +54 | Free-kit card, buttons, start and stray toast moved to `scripts/home/home_freekit.gd`; the pens/exchange `--open` branch moved to `HomeMarket.open_named`. `home.gd` now has 14 added lines, all wiring. | `--home-build-check`, `--economy-floor-check` loads it |
| 10 | Freed `Kin` in `match.gd` | `is_instance_valid(kk)` first at `_leave_kin` and `_finish` (and for `player.kin`). | "a freed Boki node is skipped when leaving and finishing (no crash)" |
| 11 | Exchange fee rounds to 0 | `Exchange.tax_of` rounds up per fill (`ceil(gems * TAX)`). | "the fill tax rounds up: a 12-gem fill pays 1, not 0" |
| 12 | `boki_system_check.gd` Net line | Main's version kept (file identical to main). | `--boki-system-check` |
| 13 | `has_method("_spawn_kin")` | `HomeMarket.new(home, spawn_kin_callable)`; the buy button calls the typed `Callable`. | n/a (compile) |

Also fixed on the way: `Exchange.tick` returned `fills.slice(before)` of a log capped at 40, so once the log was full it reported no new fills; it now collects the fills it makes.

Check gaps added to `--economy-floor-check`:

| Gap | Assertion |
|---|---|
| Gem conservation across buy / list / sell / cancel | `_pens_gems`: buy takes exactly the price, list exactly the fee, take-down refunds nothing and mints nothing, a sale pays price less 5% once |
| Restock after a buy-out and after a clock change | `_pens_restock` |
| Pen buy-then-resell can't profit | `_pens_no_mint` |
| List fee == 5% of the price | `_pen_listing` and `_pens_gems` (120 -> 6) |
| Sell-side partial fill, and cancel after a partial | `_exchange_book` (sell 25 into a 20-deep bid; cancel returns the 5; same for a buy) |
| Out-of-band exchange offers never fill | `_exchange_walk` |
| Loaner run keeps treat, armory, loadout and found tonics | `_loaner_match`, `_loaner_result` |
| Extract minimum doesn't top up at >= 45 gems | `_loaner_result` (45, 46, 200, and through `apply_result`) |

Known and left alone: items with a 3-gem base price (wood) have a walk smaller than their spread, so a resting offer never fills offline; they trade on the book at once. Players who change the system clock can pick cheap and dear days on the local Exchange (DEBT.md); the server backend ends that.

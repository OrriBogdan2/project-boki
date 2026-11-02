# Handoff: ext/economy (Agent D)

Branch `ext/economy`, merged with main sync58 (e5f25ec, Net 0.10.0). Trimmed on the owner's call: tamed Boki no longer follow you. Main has follow-by-default for your one active Boki and capture-by-scan into the box, so the follower work was removed.

## Status

| Item | Code | Check | Status |
|---|---|---|---|
| Economy floor (stray common on the farm when you have no Boki; last Boki can't be released or listed) | `scripts/core/lifeline.gd`, wiring in game.gd / home.gd / results.gd | `--economy-floor-check` | done |
| Cheap Boki market (Drift Pens) | `scripts/core/boki_pens.gd`, `scripts/home/home_market.gd` | `--economy-floor-check` | done |
| Free-kit loaner Boki | `scripts/core/loaner.gd`, wiring in game.gd / match.gd / results.gd / home.gd | `--economy-floor-check` | done |
| Tradewind Exchange (order book) + server design | `scripts/core/exchange.gd`, `docs/EXCHANGE_SERVER.md` | `--economy-floor-check` | local version done; server is a design doc |
| `--economy-floor-check` | `tools/economy_floor_check.gd` | | registered inline in main.gd (the registry does not exist on this tree; move it when it lands) |

## What was removed in this trim

`scripts/match/follow.gd`, `follow_demo.gd`, `--follower-check` and its tool, `--follow-demo`, `Follow.net_extra` / `net_apply` (sync fields 23-28, the "fgone" event, `KIN_ROLES`, the `follow` kin state, `Hunter.follower`, the `owner_of` change in net.gd), the `follow_steal` tier keys, the `_bring_home` helper and follower result in game.gd, the follower notes in results.gd, the follower and stray HUD, and every follower hook in kin.gd, match.gd, life.gd, bot.gd, hud.gd and hunter.gd. `scripts/match/kin.gd`, `bot.gd`, `hud.gd`, `hunter.gd` and `net.gd` are now identical to origin/main. The sync shape equals main's, so Net.VERSION stays at main's 0.10.0.

An idea for a left-behind active Boki (rivals get a short window to capture it) is filed in `docs/DEBT.md`; main already has the `lost_from` rule.

## How the kept pieces meet sync58

- Boki bought at the Drift Pens or a stray common go to the farm roster (`KinBox.route_new`) and never into a match. A bought Boki only becomes the active one when you have none, and it joins a match only if it is your active pick.
- The free-kit loaner is the hunter's one active Boki (`kin2` is empty). It uses the shipped follow (`cmd = "follow"`, Sic, Call back, wheel) like any other, never drops into a box, is never left behind, and goes home to Wenna.
- Caught Boki in a free-kit run go into the box as usual (capture.gd); nothing here touches capture, taming wording or the reserved Boki-system files.

## Touch points in files the main session owns

- `match.gd`: loaner spawn options in `_spawn_hunters`, `_leave_kin` and `_finish` skip a loaner, `r["loaner"]`. No sync changes.
- `life.gd`: `kin_on_death` keeps a loaner out of the deathbox (it goes "away").
- `game.gd`: `apply_result` calls `Loaner.settle`, `BokiPens.tick`, `Exchange.tick`, `Lifeline.check`.
- `home.gd`, `results.gd`, `main.gd`: market tabs, free-kit button, stray notice, the `--economy-floor-check` hook.
- `tools/boki_system_check.gd`: the Net version check is "at least 0.10.0" so branches that bump Net don't fail it.

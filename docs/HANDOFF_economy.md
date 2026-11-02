# Handoff: ext/economy (Agent D)

Branch `ext/economy`. Net.VERSION 0.9.2 (after merging sync57, main 0.9.0). Written on resume after the first agent stopped; this is the running status.

## Status

| Item | Code | Check | Status |
|---|---|---|---|
| Follower Boki | `scripts/match/follow.gd` (+ `follow_demo.gd`), thin wiring in kin.gd / match.gd / hud.gd / life.gd / bot.gd | `--follower-check` | done; rebuilt on the shipped Boki system (below) |
| Economy floor + cheap Boki market (Drift Pens) | `scripts/core/lifeline.gd`, `boki_pens.gd`, `scripts/home/home_market.gd` | `--economy-floor-check` | done |
| Free-kit loaner Boki | `scripts/core/loaner.gd`, wiring in game.gd / match.gd / results.gd / home.gd | `--economy-floor-check` | done |
| Exchange (order book) + server design doc | `scripts/core/exchange.gd`, `docs/EXCHANGE_SERVER.md` | `--economy-floor-check` | local version done; server is a design doc |
| `--follower-check` | `tools/follower_check.gd` | | registered inline in main.gd (the registry does not exist on this tree; move it when it lands) |
| `--economy-floor-check` | `tools/economy_floor_check.gd` | | same |
| Bots | `Follow.bot_goals` called from bot.gd `_choose`; bots run into a downed follower and go after rivals' strays | in `--follower-check` | done |

## Followers on the shipped Boki system (sync57)

A follower is a Kin with `role = "follow"`, state `follow` while walking. It uses the shipped pieces, none of them edited:
- Going down: `Kin.go_down` -> `KinDowned.begin`. It lies where it fell, gets the pillar marker and the squad arrow / label (`BokiHud`), and the owner scoops it by running into it (`KinDowned.tick`), or it comes round on the timer. A fall into the abyss is the timer only. `Follow.on_down` (called from `Match.on_kin_down`) only counts it for stats.
- Coming round hops the Boki onto the shoulder; `Follow.sim_follow` sees `shoulder` on a follower and puts it back to walking beside you.
- Sync: `KinNet.kin_extra` fields 19..22, then `Follow.net_extra` fields 23..28 (role, in the satchel, steal seconds, hunter nid, hunter name, team). `Follow.net_apply` reads them. Events are untouched ("fgone" is the only extra event).
- Bots: a downed follower is a "boki" goal like `BotKin.rescue_goal`; strays use the "catch" goal.
- The old "ko" state, F-to-pick-up interact and `Follow.pick_up` are gone (F stays reserved).

## Touch points in files the main session owns

No edits to scripts/kin/*, kin_merge.gd, kin_companion.gd, kin_command.gd, kin_downed.gd, kin_net.gd, bot_kin.gd, boki_hud.gd, the Hunter R input, or any G/C/R/F binding. In `scripts/match/kin.gd` (not in the faint/recall/command code):
1. `state` comment lists `follow`; new vars `role`, `tucked`, `steal_*`.
2. `hittable()`: a walking follower is hittable unless tucked.
3. sim dispatch: `"follow": Follow.sim_follow` and `shoulder` for a follower goes to `Follow.sim_follow`.
4. `_sim_dazed`: a stray just stands.
5. `hurt()`: tucked takes no damage.
6. `render()`: visibility rules for a follower, and `follow` counts as out for the ring.

## Missing hooks (list for the main session, not edited)
- `KinDowned.rescuable` requires `owner_h` not riding/dropping, fine for followers. A follower tucked while the owner glides can't be hit, so it never goes down in the air; no hook needed.
- If Boki-system code later iterates `h.kin` / `h.kin2` only, followers are invisible to it by design. If the main session wants followers to count for `_check_team`, that needs a line in match.gd `_check_team`.

## Order done
1. sync56 and sync57 merged. Logic moved out of match.gd into `follow_demo.gd` and `Follow.finish_later` so health stays inside budget.
2. Followers rebuilt on KinDowned / KinNet.
3. Checks, screenshots in `/home/claude/shots/D/` (follower_down_after_sync57.png is the downed follower on the shipped marker).

# Handoff: ext/economy (Agent D)

Branch `ext/economy`, Net version 0.8.2 (after merging sync56). Resumed after the first agent was stopped; this file is the running status.

## Status

| Item | Code | Verified | Notes |
|---|---|---|---|
| Follower Boki | `scripts/match/follow.gd`, small wiring in kin.gd / match.gd / hud.gd / life.gd / bot.gd / net.gd | `--follower-check` was 0 failures at 8a1787b (pre sync56) | see "Off-limits touch points" |
| Economy floor + cheap Boki market (Drift Pens) | `scripts/core/lifeline.gd`, `scripts/core/boki_pens.gd`, `scripts/home/home_market.gd` | `--economy-floor-check` written, not yet confirmed green in this session | |
| Free-kit loaner Boki | `scripts/core/loaner.gd`, wiring in game.gd / match.gd / results.gd / home.gd | covered by `--economy-floor-check` | |
| Exchange + server design doc | `scripts/core/exchange.gd`, `docs/EXCHANGE_SERVER.md` | covered by `--economy-floor-check` | local order book, offline NPC counterparty |
| `--follower-check` | `tools/follower_check.gd` | see above | |
| `--economy-floor-check` | `tools/economy_floor_check.gd` | see above | |
| Bots | `bot.gd` (+8 lines), `Follow.bot_goals` | in `--follower-check` | |

## Order of work
1. Merge sync56 (done on main at c7e2e01), set Net.VERSION 0.8.2.
2. `tools/health.py --strict`: bring the grown files back within budget by moving logic into new files.
3. Resolve off-limits touches (below).
4. Full suite, new checks, `--simtest --seed=5`, screenshots in `/home/claude/shots/D/`.

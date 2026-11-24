# 0158: Diminishing returns for chained wall kicks

- **Status:** accepted (owner request 11-13)
- **Date:** 2026-11-18
- **Area:** movement

## Problem
Decision 0007 and item 149 let a hunter kick off a wall again and again with no cooldown. Owner 11-13: "anyone can just wall climb anything? the reference handles this with reduced movement per jump". `HOP_CLIMB_CAP` stops a hop that starts too high, but a mashed chain below the cap still gained a full terrace per press.

## Options
1. A cooldown or a kick limit per airtime: rejected, item 149 wants an unlimited dance and a limit feels like a rule, not physics.
2. Each kick in a row keeps less rise and push (decided).
3. Lower `KICK_RISE`: rejected, it changes the first kick that tops the Cinder Steps (4 terraces).

## Decision
- `WallMoves.chain` counts kicks since the feet last touched the ground (`land()` resets it).
- A kick scales its rise (wall climb) or its push and push-jump (push-off) by the curve entry for its place: 100%, 60%, then 30% for every later kick (`content/rules/wall_kick.json`).
- A climb kick adds its rise to the jump or push-off you are on, as before. It does not add to an earlier climb kick's rise that is still going: then it only lifts the rise left up to its own share. So presses mashed on the way up do not stack (11-18 follow-up: the first pass let a press every step stack 30% kicks past 5 terraces). A push-off then a climb still lifts (item 149).
- `HOP_CLIMB_CAP` stays. The first kick is as before, so 4 terraces still climbs with one kick.

## Consequences
- Movement runs on the owning machine; nothing new on the wire or in saves.
- `--wallmove-check`, 5-terrace wall (4.0m), a press every step: peak 4.98m on main, 4.26m with the curve alone, 1.81m with the no-stack rule (timed kicks: 2.28m). The chain resets on the ground.
- Not chosen: a minimum gap between kicks (it would also block a push-off then an instant climb).

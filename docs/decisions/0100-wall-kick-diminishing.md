# 0100: Diminishing returns for chained wall kicks

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
- `HOP_CLIMB_CAP` stays. The first kick is as before, so 4 terraces still climbs with one kick.

## Consequences
- Movement runs on the owning machine; nothing new on the wire or in saves.
- `--wallmove-check`: a mashed chain on a 5-terrace wall peaks at 4.26m (was 4.98m); the chain resets on the ground.
- Still open: a press every step below the cap adds height with no cooldown, so mashing can top 5 terraces. A minimum gap between kicks would close it; not asked for here.

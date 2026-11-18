# 0096: Hazard moves (swim in Deep Water, footing on ice) and the hunter row

- **Status:** accepted
- **Date:** 2026-11-18 (ported from ext/anim-hazard-moves, 2026-11-12)
- **Area:** networking / movement (animation only)

## Problem
In a Deep Water area a Hunter only waded: its run clip, slowed. On an Ice Sheet a full run stride with grip 0.12
reads as skating. Whether a hunter is warded on ice depends on its Boki, which the other game may not see in time.

## Options
1. Each game works it out from the map and the copy's Boki: no Net change, but a frost Boki holder skates on the
   owner's game and leans on everyone else's.
2. The owner decides and sends one small int on the hunter row: exact on every game, a sync shape change.

## Decision
Option 2. `HazardMoves.of(h)` (scripts/match/hazard_moves.gd): grounded in deep water -> swim (every hunter: the
water is deep, a counter only swims faster); on ice with `ground_grip < 1` (no frost Boki) -> footing; a remote
hunter reads what its row carried. The footing numbers are data (terrain_hazards.json, ice "moves"), laid on the
existing WardenGait (stride, cadence, the loco `arm_swing` arms out). The swim is `HunterSwim`, the crawl on the
procedural rig (every warden_anim file lists `swim` as procedural), the model sunk `HomeWater.SINK_DEEP`.

## Consequences
HunterNet appends `["hz", move]` to its tail; Net.VERSION 0.24.18. hunter.gd: one call in `_anim_state` and the sink
term on the model height. Checks: `--terrain-hazard-check`, `--clip-check`, `--remote-anim-check` rows. No save
change. Monsters and Boki unchanged. Not ported: the shallow-water wade pose and the farm pond's feed.

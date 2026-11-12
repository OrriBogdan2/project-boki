# 0096: Hazard moves (swim in Deep Water, footing on ice) and the hunter row

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** networking / movement (animation only)

## Problem
In a Deep Water area every Hunter ran its run clip at 0.55 speed (wading on the surface reads as a bug), and on an
Ice Sheet a full run stride with grip 0.12 reads as skating. The farm's swim (HunterSwim) and the gait layer
(WardenGait) already exist; the other game must show the same, but whether a hunter is warded on ice depends on its
perks, which never reach the other game.

## Options
1. Each game works it out from the map and the copy's Boki: no Net change, but a Sure Foot holder skates on the owner's
   game and leans on everyone else's.
2. The owner decides and sends one small int on the hunter row: exact on every game, a sync shape change.

## Decision
Option 2. HazardMoves.of(h) (scripts/match/hazard_moves.gd): grounded in deep water -> swim (any hunter: the water is
deep, a counter only swims faster); on ice with ground_grip < 1 (no frost Boki, no ward perk) -> footing; a remote
hunter reads what its row carried. The footing numbers are data (terrain_hazards.json ice "moves"), laid on the
existing WardenGait (stride, cadence, the loco arm_swing arms out); the swim is the existing HunterSwim on the rig.
In the crawl the run cycle's shoulder twist and roll are off (they were mixing into the stroked hand), a Warden's rig hands go
back to their own wrist once the rig owns the pose (WardenGlb Sync), and a floating weapon (Meeko's sun, companion
"swim_stow") is put away in deep water, from the same "swim" state a remote hunter reads.

## Consequences
HunterNet appends ["hz", move] after ["lv", level]; Net.VERSION 0.24.6. hunter.gd: one call in _anim_state and the
sink term on the model height (no growth). Checks: --terrain-hazard-check, --clip-check, --remote-anim-check rows;
--hazard-moves-shots (GPU). No save change. Monsters and Boki unchanged (BokiWade has its own).

# 0022: Lift and carry a Boki at home

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** farm

## Problem
The genre's core touch (briefs/design/CHAO_RESEARCH.md idea 1) is missing: you can pet, feed and bathe a
Boki but not pick it up. The interact key on a Boki already does those care actions, so the lift has to
share it.

## Options
1. A new key for lifting. Cheap, but one more key to teach and a prompt that can't say which is which.
2. The interact key lifts when the Boki wants nothing; press again to set it down. The care actions keep
   priority, so a hungry Boki is still fed first.

## Decision
Option 2. Priority on a Boki: a care want (feed, tuck in, bath, brush), then "pet" for a lonely one, then
**lift**. While carrying, interact means "Set <name> down" wherever you stand.
- `scripts/home/kin_carry.gd` (`KinCarry`) holds the one explicit state `FREE -> LIFT -> CARRIED -> SET -> FREE`
  with a NEXT table. `Fsm`/`Loco` are not on main yet (only on ext/movement-unify and ext/fsm-m1), so this is a
  self-contained copy of the same idea; fold it into the shared base machine when that lands.
- It answers by its nature: loyal or well-trusted (trust 70+) nuzzles, hot-tempered and not loyal and not yet
  trusting sulks, otherwise it wiggles.
- Trust: +0.6 for a nuzzle or a wiggle, once per 30 s per Boki (`carry_ok`, runtime only). A sulk gives none.
- The set-down spot comes from `World.free_spot_near` in front of you, never a wall or the void, always on
  your island.
- Poses: HunterAnim `act` = "lift" / "carry" / "set" (you walk normally while carrying); BokiRig and KinPuppet
  take `kstate` = "carried" (nose up, held).

## Consequences
Save: only `trust` changes, no new fields, no `Net.VERSION` bump. The old "Pet <name>" default prompt is now
"Lift <name>". Check: `--boki-carry-check`. Not yet looked at in a GPU shot, so HOLD_UP / HOLD_FWD in
`kin_carry.gd` are untuned.

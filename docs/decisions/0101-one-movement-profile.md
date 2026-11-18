# 0101: One movement profile; a fall never turns into forward or back

- **Status:** accepted (owner 11-11; ported onto main 11-18 from ext/physics-unify-1111)
- **Date:** 2026-11-18
- **Area:** movement

## Problem
Owner 11-11: in the tutorial and the expedition, falling momentum turns into forward or backward momentum. A straight fall was clean in the physics (0 m drift). Two things made it read that way. (1) Walking down a flight the ground dropped more than the 5 cm a step allowed on the farm, so the avatar fell a little every step (18 air steps) under air rules that don't brake: a let-go slid 1.69 m instead of 0.48 m. (2) The match view followed your height softly (3.5/s), so a fall drew you sliding down the screen and a landing kept scrolling forward.

## Options
1. Raise `World.STEP` to the source's 0.45 m: it moves every walker, Boki included, and turned other checks red (ext/feel-slope-run, reverted 11-10).
2. A downhill-only stick (`HunterMove.step_down`, 0.45 m, the source's MaxStepHeight) for hunters and the farm avatar, and a view whose height follows the ground you stand on, tight whenever it comes down (decided).

## Decision
Option 2. Walk-up (`World.STEP`) and every other walker are unchanged. `HunterMove.walk` and `fall` were already shared on main; this adds `sticks` and `stand_y`, and `Cam.follow` takes the stand height.

## Consequences
- No wire change, no save change.
- `--fall-parity-check` (tutorial, expedition, Training Area, farm): straight and held falls, a running jump (same arc everywhere), a flight, the view after a 10 m landing. With `step_down` at the old 0.05 the farm row fails (18 air steps, 1.69 m slide).

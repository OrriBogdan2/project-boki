# 0060: One movement profile; a fall never turns into forward or back

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
Owner 11-11: in the tutorial (and the expedition) falling momentum turns into forward or backward momentum. Straight falls were clean in the physics (0 m drift). Two things made it read that way. (1) Walking down a flight (one terrace over a tile, 38.7 deg) the ground dropped more than the 5 cm a step allowed, so the hunter fell a little every step: 19-32 air steps down at up to 7 m/s, under air rules that don't brake, and a let-go on the flight slid 1.3-1.6 m instead of 0.37 m. (2) The match view followed your height softly (3.5/s), so a fall drew the hunter sliding down the screen and a landing kept scrolling forward ~0.7 m. The farm camera ignores height, so the farm felt different.

## Options
1. World.STEP up to the source's 0.45 m (ext/feel-slope-run, reverted 11-10): it moves every walker, Boki included, and turned other checks red.
2. A downhill-only stick (HunterMove.step_down, 0.45 m, the source's MaxStepHeight) for hunters and the farm avatar, and a view whose height follows the ground you stand on, tight whenever it comes down.

## Decision
Option 2. Walk-up (World.STEP) and every other walker are unchanged; the hunter and the farm share HunterMove.walk, fall, sticks and the camera rule.

## Consequences
HunterMove (walk, fall, sticks, stand_y), hunter.gd and home.gd call them; CamRig.follow takes the stand height (Match passes it). No Net shape change, no save change. Check: --fall-parity-check (tutorial, expedition, Training Area, farm). feel_golden unchanged (its 84 reds are on main too).

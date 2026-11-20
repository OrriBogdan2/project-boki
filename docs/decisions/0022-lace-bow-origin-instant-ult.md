# 0022: Lace's shots leave the bow, and Starpiercer fires on press

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** combat

## Problem
Owner playtest 11-08 (items 18-20): the Heavy Shot was loaded on her body (a world-space needle at a fixed
height, the shot spawned from her centre), its wall pin left a 7 s stake and a miss a 6x spent arrow;
Starpiercer empowered the bow on X and every beam waited a 0.5 s nock; the perfect window (0.15 s) was
too short to read and gave no body cue. The Hail Wall's slow made foes look like they bounced.

## Options
1. Keep the kit's own offsets and tune them per animation frame. Cheap, drifts from the model.
2. Read the model's anchors (HeroVfx "nock", "bow_root", with body fallbacks for procedural rigs) and let
   KinExec take an exact start point. One shared path for the needle, the Heavy Shot, Starpiercer and the
   aim lanes; follows any model.
3. For the ult: keep the nock but shorten it. Still a delay the owner ruled out.

## Decision
Option 2. `KinExec` gains cx `"muzzle"` (exact 3D start, also the origin for direction and the cast look);
`PinDraw.bow_at()` is the bow anchor. Starpiercer's X press is its first arrow, the next presses fire the
instant the 1.0 s recover is up; the nock state, clip map, sound and demo rows are deleted. Balance is left
to the cooldown and damage (unchanged for now; the three arrows now land in about 2 s instead of 3.5 s).
The perfect window moves to the one tuning file (`content/rules/tuning.json` lace.perfect_window_s, 0.35 s)
with a rim glow on her materials only inside it and a payoff pulse on a perfect. Zone ticks carry
`"tick": true`, so `Ent.hurt` skips the hit squash and hold and Oomph/Juice skip the flinch: a slow only
takes speed.

## Affects
ArcherKit, PinNeedle, PinDraw, PinUlt, PinFx, KinExec (`muzzle`), Ent.hurt (tick), archer data and looks,
hem clip map, arena demo rows, the Lace checks (`--lace-playtest-check`, `--archer-combo-check`).

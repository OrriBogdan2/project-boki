# 0061: A Boki's bite lands on the clip's contact frame

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** combat

## Problem
A Boki's melee hit (damage, knockback, `kinhit`, the "on_hit" trigger) fired the frame its attack timer allowed, while the attack clip had only just started: the bite or pincer snap connects about 0.35 s later, so the hit read ahead of the swing.

## Options
1. Keep the hit instant and start the clip at its contact frame. Cons: no wind-up shows at all.
2. Logic gets a fixed wind-up (`Kin.STRIKE_WINDUP`, 0.3 s) and the clip is played at the rate that puts its contact there. Cons: the hit comes 0.3 s later than before.

## Decision
Option 2. The logic timer stays the authority: `Kin._start_strike` takes the cooldown and arms the bite, `_land_strike` lands it after the wind-up (if the Boki is still fighting and not stunned, and the target is still alive and within its reach + 0.6 m). `BokiRig.CONTACT` holds each starter line's contact (s into the clip at speed 1, its forms wear the same clip) and the rig plays the attack at `CONTACT / STRIKE_WINDUP`. Wild Boki lunge on the bite too now.

## Consequences
scripts/match/kin.gd, scripts/match/boki_rig.gd. No Net or save change (the bite is host-side sim; the clip follows the `kstate` meta). `--boki-anim-audit` asserts each CONTACT matches its clip and, driven live, connects within a frame of the hit.

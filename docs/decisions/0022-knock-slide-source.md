# 0022: How a knock feels to the one knocked

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
A knock set your speed, slid you for a fixed 0.12-0.35 s at 6 m/s^2, then dropped you into our kit-step shed
(110 m/s^2, or 30 with keys held). Speed held nearly flat and then stopped hard, and holding the keys along the knock
carried you on. The source takes a knock as a launch on its normal movement: on the ground UE's over-max brake
(ground_friction 2/s x v + 22.2 m/s^2, keys can't add speed), in the air the falling rules, and a landing goes
straight into the walk. Footage fits that brake: Ghost's recoil 0.5 bh in 0.2 s, his wall cone 3.5 bh in ~0.4 s.

## Options
1. Launch at the push speed itself on the source brake. Ground knocks would travel about 40% as far, which breaks the
   push numbers tuned as distances (that audit is separate work).
2. Launch at 1.8x the push speed on the source brake. Ground distances stay within 5% for pushes 3-14 m/s.

## Decision
Option 2. `HunterMove.knock_step` runs the source curve, `knock_launch` and `knock_max` are in
content/rules/hunter_move.json, and directional influence stays as it was (it's in the source: [patch] Jun 2025).

## Consequences
- Knocks are front-loaded: Albert's bash (push 11) starts at 19.8 m/s and is back at run speed in 0.34 s.
- Air knocks fly 1.8x faster too, so a knock on a foe mid-jump carries further (7.6 m vs about 3.7 m for push 6
  with a 4 m/s lift). Ground distances are unchanged.
- Wall stuns: the rule (over 8 m/s within 0.6 s) is untouched. Pushes 6-8 can now stun against a wall within
  0.4-1.2 m, and hard knocks reach about 0.5 m less far. Vex's recoil moved to the source's 0.9 m (push 4.4), so it
  never crosses 8 m/s.
- Net: no change. Knocks run on the owner's game, and the hit extras are unchanged.
- Checks: `--move-feel-check` knock rows; `--knock-feel-shots` GPU strip.

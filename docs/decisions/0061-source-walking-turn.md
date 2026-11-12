# 0061: Source walking turn, rebuilt on 0.24.6 (GroundFriction bends the velocity)

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** movement

## Problem
With keys held our walk was a constant ramp (`Loco.accel_to`, `move_toward` at MaxAcceleration). The source
(UE's walking CalcVelocity; supervive_physics.md: GroundFriction 1.0, MaxAcceleration 4700-5400, MoveSpeed
445-485) first bends the velocity toward the keys, `V -= (V - dir x |V|) x min(F dt, 1)`, then adds the accel
and caps at run speed. A reversal sheds speed at 2F|v| + a (to 95% back: ln(1 + 2Fv/a)/2F + 0.95v/a, 0.155-0.192 s)
and a 90-degree cut arcs at run speed (to 10 degrees: ln(1/tan 5°)/(F + a/v), 0.185-0.228 s). Ours reversed
4-6% slow and cut the corner in ~0.10-0.125 s through 71% of run speed. The first try (ext/feel-reversal,
decision "0022-source-walking-turn") was reverted from the 0.24.6 feel wave for breaking WASD direction, turn and
slow/haste rows. The walk was not the cause: `--move-feel-check` ran its match with the Blight on, and Skitters
spawned mid-run lunge at the hunter (blight.gd `_strike`, a knock). Which rows they hit depends on the hunter's
exact path and timing, so any change to the walk moved the knocks onto other rows (the WD diagonal 17 deg off,
Ghost's slow_end 0.46x, three reversals 2.2x; the line's haste_land/haste_end reds were the same knocks).

## Options
1. Keep the ramp (snappier cuts, not the source).
2. The source formula once, `HunterMove.walk`, for the match, the farm and home; F is the existing
   `ground_friction` row (GroundFriction itself; the braking factor applies to a let-go only).

## Decision
Option 2. Over the wanted speed by UE's 1% slack (a Slow landing, a knock, a pad's carry) the walk keeps the
0.24.5 rule (`Loco.accel_to` at the walking brake, decision 0022-slow-haste-ramp), so the slow/haste rows do not
move. No new state: the walk runs in the GROUNDED branch of the one locomotion step (no bool, no timer).
`--move-feel-check`: its match starts with `"blight": false` (it measures the hunter's own physics); the
medium-only `ground_reverse_t` (<= 0.19 s) and `ground_turn90_t` (<= 0.13 s, a constant-ramp number, not the
source) become per-hunter `reverse_vs_source`, `cut90_vs_source` and `cut90_min_speed` rows, run last (they
swap through all 12 kits).

## Consequences
Cuts take ~0.08-0.1 s longer but keep run speed; reversals are about one step quicker. Ice (`grip`) scales the
turn friction like the brake. No Net or save change.

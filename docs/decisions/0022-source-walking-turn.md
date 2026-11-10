# 0022: Source walking turn (GroundFriction bends the velocity)

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
With keys held, our ground walk was a constant ramp (`move_toward` at the hunter's accel). The source
(UE's walking CalcVelocity, GroundFriction 1.0, MaxAcceleration 4700-5400, MoveSpeed 445-485 per hunter)
first bends the velocity toward the keys, `V -= (V - dir x |V|) x min(F dt, 1)`, then adds the accel and
caps at run speed. So a reversal sheds speed at 2F|v| + a (ln(1 + 2Fv/a)/2F + 0.95v/a: 0.16-0.19 s) and a
90-degree cut arcs at full run speed (ln(1/tan 5°)/(F + a/v): 0.19-0.23 s). Ours reversed 4-6% slower and
cut the corner in 0.12 s through 71% of run speed.

## Options
1. Keep the ramp (snappier cuts, not the source).
2. The source formula in one place, `HunterMove.walk`, with `turn_friction` 1.0 in `content/rules/hunter_move.json`.

## Decision
Option 2. Braking does not apply while a key is held (as in UE), so the stop, the dash exit and air control
are untouched. Over 1.01x the wanted speed (UE's IsExceedingMaxSpeed slack: a kit step, a knock)
`Hunter.accel2` still bleeds it at GROUND_OVERSPEED as before.

## Consequences
Cuts take ~0.1 s longer but keep run speed; reversals are about one step quicker. `--move-feel-check` asserts
both against the source formulas for all 12 hunters. Ice (`grip`) scales the turn friction like the brake.

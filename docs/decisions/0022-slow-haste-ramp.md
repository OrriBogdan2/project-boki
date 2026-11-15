# 0022: One ramp rule for every Slow and haste (PARITY FIRST)

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
A Slow or a speed boost should change run speed the way the source does and return the same way when it
ends. The source (supervive_physics.md: BrakingDecelerationWalking 2220, GroundFriction 1.0, MaxAcceleration
4700-5400; UE's CharacterMovement) has no ramp time: the cap steps at once and the body follows it, down at
the walking brake and up at MaxAcceleration, ~0.05 s for a 30% Slow on a run. Ours routed every Slow and
haste through the one cap already, but the downward follow borrowed `Hunter.GROUND_OVERSPEED` (30 m/s², a
dash-and-pad bleed constant that only matched the brake by coincidence at run speed), and nothing asserted it.

## Options
1. An eased ramp over a named time (lerp the multiplier). Ours-only; the source has none.
2. The source rule: speed over the cap sheds at the walking brake (brake_decel + ground_friction x speed),
   up at MaxAcceleration, from the data already in hunter_move.json.

## Decision
Option 2. Main landed the rule itself under decision 0020 (`HunterMove.brake_rate` in the ground step,
`HunterMove.slide_speed` in the lunge planner, `GROUND_OVERSPEED` deleted), so this note adds no code: it
records that every Slow and haste follows that one rule and asserts the settle times (`--move-feel-check`
slow_*/haste_* rows, one kit per weight class). There is no ramp-time constant. A pad's carry with keys
held sheds by the same brake (46 m/s² at 12 m/s): also the source's law.

## Consequences
move_feel_check.gd (+6 rows), docs/MOVEMENT_FEEL.md. No Net or save change. Kin, mobs and the boss set
their speed directly (no ramp) and are out of this scope.

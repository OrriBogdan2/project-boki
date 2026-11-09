# 0022: Source step height, so slopes keep your speed and your feet (slope parity)

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
On the Hollow Crown's flights (one 0.8 m terrace over one tile, 38.7°) a medium hunter hopped: going up, the
body sample 0.4 m ahead sat just over the 0.32 m walk-up step, so every tick took the step-up path; going down,
the ground could drop only 5 cm a tick before the hunter was airborne. Up a flight: 31 air frames, 0.954x run
speed. Down a 35° test ramp: 49 air frames, 0.926x, and a let-go slid 1.33 m instead of 0.31 m. The source
(UE) keeps the horizontal speed on any walkable slope (WalkableFloorAngle 50°) and holds the feet to the floor
within MaxStepHeight, which the hero blueprint leaves at UE's default 0.45 m.

## Options
1. A slope-specific snap distance and a bigger body-ahead tolerance, two new numbers.
2. One number: the source's step height, 0.45 m, as `physics.step` in `content/rules/hunter_move.json`.
   `World.STEP` reads it (walk-up), and the Hunter's downhill rule uses the same step (walk-down).

## Decision
Option 2. Nothing of ours stands between 0.32 and 0.45 m except a slope, so walls, ledge rises and the terrace
edge (0.8 m, still a fall) are unchanged; `--move-feel-check` runs the whole ledge, coyote and abyss set green.
`slope_*` rows assert 1.000x speed, 0 air frames and the flat stop on 10/20/35° ramps and the map's flights.
Not done: a speed scale with the grade (no source data, marked [?]) and a slide-off above 50° (no such ground).

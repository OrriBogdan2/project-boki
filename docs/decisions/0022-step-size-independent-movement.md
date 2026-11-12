# 0022: Movement that doesn't depend on the step size

- **Status:** accepted; amended 2026-11-11 (anchored to the 60 Hz step, below)
- **Date:** 2026-11-09
- **Area:** movement

## Problem
A 30 fps machine must play the same game as a 144 fps one. `Match._process` already steps the sim at a fixed 1/60 s, but stepped at other sizes (as DashPace's slow-frame cap, or a future step change) some integrations drifted: a jump's apex (1.46 m at 1/30, 1.55 m at 1/144: plain semi-implicit gravity), and a dash's length (Kael 3.69 / 4.19 m, Albert 3.50 / 3.81 m: the step a dash ran out in moved at exit speed, dropping the dash's last part step).

## Options
1. Leave it: the fixed 60 Hz step hides it today.
2. Make the integrations exact for any step: gravity moves at the step's mean speed, and the step a dash ends in splits its time between the dash and the exit.

## Decision
Option 2, in `HunterMove`: `fall` (trapezoid gravity) and `dash_end_step` / `settle_dash_end` (the step's mean velocity for the move, the exit velocity kept). The hunter's lunge steer and turn use `1 - exp(-k dt)`, with k set so a 60 Hz step is unchanged.

## Consequences
- `--fps-feel-check` runs Vex, Kael, Albert and Sable at 1/30, 1/60, 1/144: apex, dash tap and hold, glide sink, knock agree within 3%; the apex matches JUMP_V^2/2g and the high glide sink the [game data] 3.5 m/s.
- At 60 Hz the apex goes 1.52 -> 1.57 m and a 1 s free fall to 7.10 m (the source's 7.1 m). No Net or save change.

## Amendment (2026-11-11, docs/MERGE_0246_FEEL.md)
The exact version moved the 60 Hz game itself (apex 1.52 -> 1.57 m), and it was taken out twice for that (perf-train-0245, the 0.24.6 feel wave: feel-golden and the 60 Hz feel rows). The game only ever steps at 1/60 (`Match._process`), so the 60 Hz step is the reference. `HunterMove.fall` adds back what a step of another size gains or loses against the 60 Hz arc. That is 0 at 1/60, so 60 Hz is unchanged, and the apex is 1.52 m at every step; the check's apex target is that arc's. Ground dashes already split their last step (0.24.5 `HunterMove.dash_rest`). The dash and knock spread the check saw came from mobs the map respawns by the spawn, which the check now clears. The steer and turn rates are left as they are. Owner alternative: exact gravity (UE's midpoint step) gives 1.57 m at 60 Hz and changes every jump and fall.

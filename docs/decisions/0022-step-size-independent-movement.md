# 0022: Movement that doesn't depend on the step size

- **Status:** accepted
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

# 0083: A turn costs the speed you carry

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
Owner playtest 11-11 (0.24.4): "you can pinball one way then the other and maintain momentum". Every dash, rush and
kit step (`Hunter.dash_with`) set its velocity outright, so a dash straight back from a dash went at full speed at
once, and in the air it then carried its whole speed again. On the ground a dash hands over at the run, so even a
dash pressed a frame after one ended read as "no speed" and turned for free.

## Options
1. Add the dash's push to the velocity you carry (true impulses). Same-way chains would stack past any dash's
   speed, and every measured dash distance would move.
2. Keep each move's own speed, but take off the part of the carried speed that is not along its heading: a
   sharp turn starts the move slower and builds back over a short recovery, and an air move hands over less.

## Decision
Option 2, in `scripts/match/turn_cost.gd` (one `TurnCost` per hunter). Carried speed is your velocity, or the last
dash's top speed for `turn_window` s after it ended. Its weight is its excess over the run (full at `turn_full`
m/s over); its loss is weight x (1 - cos of the turn, clamped at 0). The move runs at (1 - loss) of its speed,
building back to it over `turn_recover` s, and an air move hands over only (1 - loss) of its speed above the run.
Same-way chains, and moves from a walk or a stand, are unchanged.

## Consequences
hunter.gd +5 lines of wiring. Tunables in content/rules/hunter_move.json physics. Knockbacks themselves are not
changed (the hit's push still lands), but a dash out of one pays for turning against it. `--turn-cost-check`
holds it for every hunter. No Net or save change: every peer runs the same step.

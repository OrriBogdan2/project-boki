# 0062: A dash hands over to the mantle

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** movement

## Problem
Ledges are always responsive (DECISIONS), but a ground dash into a rim higher than a step stopped dead, because the ledge catch skips grounded players. An air dash was caught, then rose from a standstill at the 2.5 m/s suction cap and lost 0.3-0.5 s at the face. The source footage shows ~0.2 s from rim to top, with no stop.

## Options
1. Catch rims earlier on a dash, as the source's speed-scaled suction trace does. The trace distances are encrypted, and a fast dash still reaches the face before it reaches the lip.
2. Hand the dash to the rise at the face: the dash counts as the push (from the ground too), its rest is dropped, and it starts the rise with the lift that clears the lip at the cap (the source's mantle Z impulse). Over the lip it keeps 0.6x its speed (MiniMantle, already there).

## Decision
Option 2: it uses only known numbers (the cap, the reach, KEEP), and it is a few lines in `MantleCarry` plus wiring in `Hunter._try_ledge_grab`.

## Consequences
`mantle_carry.gd` (`dashing`, `dash_lift`). `hunter.gd` gains +7 lines of wiring. No Net or save change. `--mantle-check` gains the dash-into-rim rows (`tools/mantle_dash_rows.gd`). A Spirit Walk still climbs on its own. Rims out of reach behave as before.

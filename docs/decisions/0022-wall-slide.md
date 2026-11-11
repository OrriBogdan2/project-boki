# 0022: Sliding along walls and round corners

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
In the source, running into a wall at an angle slides you along it at the tangent part of your speed, and
small corners never catch you. `--wall-slide-check` measured ours (Sable, Vex, Kael at 15/45/75 degrees,
1 s each): cliffs and rock/tree/crate/wall tiles already slid, but a Tenzo rock (an ability barrier, a
capsule off the map's grid) stopped every run at 45 and 75 degrees (44-51 still steps) and cost 78% of the
speed at 15, and after a ground dash along a cliff the walk took ~5 steps to get back to speed (88%).

## Options
1. Leave barriers to `World.occupy`'s axis-at-a-time test and widen the corner slip. It can't slide on a
   slanted face: whichever axis is tried first is stopped.
2. Push the body out of movement-blocking barriers before the axis moves, as `World.push_out_blocks` does
   for rock tiles, and drop the part of the velocity going into them (the existing block path).
3. As 2, plus: the step after the walk pressed into a wall, the walk's target drops its into-wall part,
   so its acceleration all goes along the face (the run's acceleration was split toward the wall and lost).

## Decision
Option 3. `HunterMove.push_out_walls` and `HunterMove.along_wall`; the barrier height rule is
`Verbs.wall_top`/`wall_reach`, shared with `Verbs.wall_blocks` so the two can't drift. The push leaves
`World.BLOCK_SKIN` of room: without it a body sliding at exactly the reach got float-rounding pushes with a
random normal that ate up to 13% of its speed.

## Consequences
- Four lines of wiring in `hunter.gd` (the push-out, `slide_n`, its use in the ground walk, the rock's top
  for the wall kick and the caster's climb, which now reads the push's top as well as occupy's).
- No new tunables (the reach and skin already existed). No Net or save change: each client steps its own hunter.
- Mobs (`Ent`) still meet barriers through `occupy` only; not measured here.

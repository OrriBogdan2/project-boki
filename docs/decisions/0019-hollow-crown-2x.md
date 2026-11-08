# 0019: The Hollow Crown at 2x, with a winding sky train and 40 hunters

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** map / match size / pathing

## Problem
The Hollow Crown should hold about twice the play area. Everything on it has to scale in step (landmarks,
chests, key carriers, extractions, drop spots) so density stays about the same, and travel time can't
double. Jump-pad-only floating islands (Shardfall) are a dead end and go.

## Options
1. Redraw every island at 305 tiles. That's a lot of hand-placed coordinates to retype and re-check.
2. Keep the hand layout on its 216 DESIGN grid and have `scale_layout()` spread it over SIZE (305 ≈ 216·√2,
   so 2x the area). Things with a body keep their size: rocks, trees, stairs, walls. A second wave of
   content (`MORE`) fills the new land. A ring train can't reach every region, so the train runs a
   closed winding `path`.

## Decision
Option 2. SIZE stays the one constant. The train layout gains `path`/`stations` as points beside the
ring form (`TrainRoute` reads either one). A ride averages ~8 m/s between stops (12 m/s top speed, eased in and out), against 4.55 m/s on foot, and `check_train` keeps it so. Data.MATCH_PLAYERS goes from
20 to 40, and three lairs are live, so bosses per hunter stay level. Bot backfill follows MATCH_PLAYERS.
`KinPath` gets a `flat` mode for walkers that can't take stairs or jump (the Shrubling) and doubles
MAX_NODES, because cross-island trips on the bigger land ran out of nodes.

## Consequences
- Net.VERSION 0.25.0 (match size and map change). No save change.
- Matchmaker trio slots should follow the 40-player size on the matchmaker branch (follow-up).
- TEAM_COLORS has 20 entries, so solo colours repeat at 40 (follow-up).
- The generator now fails a rock over the void, and `sc_rocks` moves touching rocks as one group so
  an L-shaped boulder doesn't split under the scale.

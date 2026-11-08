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
- TEAM_COLORS has 40 entries (the 20 added are deeper, hue-nudged shades), so a 40-solo match repeats none.
- Perf at 40 hunters. Offline, `SimLod` (scripts/match/sim_lod.gd) steps a bot (think and sim) every 3rd
  step with the skipped time added, when it is more than 45 m from the player, on the ground, not on a
  moving or scripted goal, not fighting anything near the player and not just hit by them. Its Boki
  follows its rate. Far bot-vs-bot fights count (both sides at 20 Hz), and far things already redraw
  every 4th frame. `Bot._steer` caches its line test and grid path, and pulls its aim forward instead
  of replanning every step. Bots skip the interact prompt scans nobody reads, and spawn-plan reveal
  groups hunters by team and bounds `sees` by range. `--perf-throttle-check` covers SimLod.
  Headless at 40 (box loaded, relative only): fight 74 -> 56 ms wall (script 48 -> 32), ride
  286 -> 137 ms (worst frame 2363 -> ~390). Same map and session at 20/30/40 hunters: fight script
  19/31/32 ms, load 11.7/13.0/13.8 s. So 30 hunters saves little now, and 40 stays (squads per m2 level).
- Load still grows with the hunter count: each hunter model takes ~120 ms (GPU box) to build, and a
  Warden with a 3D model builds the whole procedural body first, then hides it (docs/DEBT.md).
  Alternative not taken: 30 hunters (loses squads-per-area parity for ~0.8 s).
- The generator now fails a rock over the void, and `sc_rocks` moves touching rocks as one group so
  an L-shaped boulder doesn't split under the scale.

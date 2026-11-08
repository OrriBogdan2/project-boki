# 0021: The Hollow Crown at 2x, with a winding sky train and 30 hunters

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
20 to 40 (capped at 30 after the GPU perf pass, below), and three lairs are live, so bosses per hunter stay level. Bot backfill follows MATCH_PLAYERS.
`KinPath` gets a `flat` mode for walkers that can't take stairs or jump (the Shrubling) and doubles
MAX_NODES, because cross-island trips on the bigger land ran out of nodes.

## Consequences
- Net.VERSION 0.26.0 (match size and map change). No save change.
- Matchmaker trio slots follow the match size on ext/matchmaker-map-2x (18 at 30 hunters).
- TEAM_COLORS has 40 entries: the first 8 as before, the other 32 picked farthest-first in OKLab, so no two
  are closer than Data.TEAM_COLOR_GAP (0.08; the earlier deeper shades came as close as 0.028 and two
  squads read as one). `--crowd-check` holds the count and the gap.
- Perf at 40 hunters. Offline, `SimLod` (scripts/match/sim_lod.gd) steps a bot (think and sim) every 3rd
  step with the skipped time added, when it is more than 45 m from the player, on the ground, not on a
  moving or scripted goal, not fighting anything near the player and not just hit by them. Its Boki
  follows its rate. Far bot-vs-bot fights count (both sides at 20 Hz), and far things already redraw
  every 4th frame. `Bot._steer` caches its line test and grid path, and pulls its aim forward instead
  of replanning every step. Bots skip the interact prompt scans nobody reads, and spawn-plan reveal
  groups hunters by team and bounds `sees` by range. `--perf-throttle-check` covers SimLod.
  Headless at 40 (box loaded, relative only): fight 74 -> 56 ms wall (script 48 -> 32), ride
  286 -> 137 ms (worst frame 2363 -> ~390). Same map and session at 20/30/40 hunters: fight script
  19/31/32 ms, load 11.7/13.0/13.8 s. (Superseded by the GPU pass below: capped at 30.)
- Load still grows with the hunter count: each hunter model takes ~120 ms (GPU box) to build, and a
  Warden with a 3D model builds the whole procedural body first, then hides it (docs/DEBT.md).
  Alternative not taken: 30 hunters (loses squads-per-area parity for ~0.8 s).
- Flat pass (job 20261108-121503-a4): an idle camp naps (Mob.NAP_M 36 m, 3D, looked at every 0.5 s);
  a Warden's .glb scene is loaded once a session and prefetched on a thread with the HUD; a bot aboard
  the sky ship picks nothing; a calm bot past SimLod.THINK_FAR_M (90 m) chooses half as often; shots
  gather their possible targets once a step, not every 0.25 m. `--crowd-check` covers the naps, the
  scene cache and the colours.
- The generator now fails a rock over the void, and `sc_rocks` moves touching rocks as one group so
  an L-shaped boulder doesn't split under the scale.
- GPU pass, pc-MRROBOTO, `--perf-probe` (ms a frame; load and steps in s). Main is ext/map-parity-integ at
  20 hunters. Its load benchmark was 32 ms a frame; the 2x runs were 64-79, because the bigger map draws
  more (planning: 4360 draws against 2811).

  | run | fight wall / script | ride wall / script | load | warm_up | build.hunters |
  |---|---|---|---|---|---|
  | main, 20 | 26.5 / 10.6 | 56.2 / 5.8 | 19.7 | 6.6 | 3.0 |
  | 2x before, 40 | 88.1 / 45.2 | 204.7 / 25.1 | 39.0 | 11.7 | 10.6 |
  | 2x after, 40 | 75.6 / 39.0 | 155.2 / 17.0 | 41.1-44.1 | 14.6-18.7 | 8.4 |
  | 2x after, 30 | 65.9 / 31.8 | 127.7 / 13.8 | 35.8 | 12.4 | 7.2 |
  | 2x flat2, 40 | 75.9 / 39.6 | 155.2 / 16.8 | 43.1 | 17.4 | 8.5 |
  | 2x flat2, 30 | 64.5 / 30.7 | 120.9 / 12.6 | 36.2 | 12.7 | 6.8 |
  | 2x flat2, 20 | 50.2 / 24.1 | 99.3 / 10.5 | 35.5 | 12.5 | 5.6 |

  Not flat at either size. Most of the rest is per-hunter sim on the bigger land and map rendering, not
  one hotspot. So the 2x land stays, capped at 30 (Data.MATCH_PLAYERS); that is ~25% fewer hunters per
  m² than the 20-hunter map had. warm_up counts frames, so it follows the box's frame time (11.7 to 18.7 s
  on near-identical code). Alternatives not taken: keep 40 (fight 76 ms), or go back to 20 on 2x land.
- Second flat pass (flat2 rows): far awake monsters step at 20 Hz (Mob.FAR_M), shots check only the props
  in reach (Breakables.near), far pickups don't spin (Wpicks), truce offers spaced by squad count, and
  aboard the sky ship rival plates draw only within 5 m (LabelCull.RIDE_M). Fight mobs 3.6 -> 2.3 ms a
  step at 30; the rest is within run-to-run noise, so the cap stays at 30. The 20-hunter row is the
  finding: the same code with the same hunter count costs 2.3x the script time on the 2x land (fight
  24.1 vs 10.6 ms; hunters 5.6 vs 2.6, Boki 3.8 vs 1.3, bots 3.3 vs 1.0 ms a step). The gap is per-entity
  cost that grows with the land, not the hunter count: the next pass should profile what a hunter, a Boki
  and a bot step ask of the world (ground, walls, line of sight, grass, path grids) on the 2x map against
  the old one, rather than trim more systems. Load: build.hunters is 42 model builds in a 30-hunter
  session (12 are the planning screen's Wardens); see docs/DEBT.md for the split.

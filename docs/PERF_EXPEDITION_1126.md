# Expedition frame time, steady state (11-26)

Owner 11-26: "performance during expeditions is horrible". The load-in hitch is another job's (expedition-loadin-fps-1126);
this one is the frame time while the run is going. Measured on the pods' RTX 4090 (Vulkan Forward+, 1920x1080, Medium)
with `--perf-bench`, through `jobq submit --needs gpu --only rp2g-0` / `rp2g-1`.

## What was measured
- 30 hunters (ten bot trios, the squads a queue builds), ash storm, Blight, lairs, a fight brought to you, 45 s:
  `--perf-bench --bench-trios=10 --bench-secs=45 --bench-view=1920x1080 --quality=medium`.
- The fight worst case (three trios, every E and R, a camp): `--perf-bench --bench-fight ...`.
- Costs split by temporary timers (not committed) around Hunter.sim, Hunter.render, Bot.think and the pickup loops, in the
  same bench, so a number is ms per frame over 2700 frames.

Baseline (main cdbaa701ac, 30 hunters): frame wall 35-42 ms on the pods (they add about 8 ms of X11 window copy at 1080p,
docs/PERF_DRAW_1124.md), match script 17.1-18.8 ms (p99 37-46 ms), GPU 0.6-6 ms, render CPU 1.6 ms, HUD 2.5 ms,
600-900 draws, 1.7M tris, 15000 nodes, 700 shadow casters, 6 lights (1 shadowed), 95 particle emitters running.
It is CPU bound: the script is 17-19 of the ~26 ms a frame costs on the owner's PC (docs/PERF_DRAW_1124.md).

## Ranking (ms per frame, 30 hunters, script only)
| # | cost | ms | what is in it |
|---|---|---|---|
| 1 | hunters' sim (Hunter.sim, 30 of them) | 3.5 | `_physics` 1.05, the kit's tick 1.0 (spread over kits: 0.1 each), kin stats 0.28, attack 0.2 |
| 2 | hunters' render | 3.2 | pose 0.83, anim state 0.40, the three looks 0.42, weapon fx and rest 1.5 |
| 3 | bots' think | 2.6-3.2 | path search: `_grid_path_in` 0.13 calls a frame at 4.5 ms each (0.58), `_clear_line` 3.9 calls at 0.1 ms (0.42), `_choose` 0.6 |
| 4 | mobs and kins, sim and render | 3.0 | |
| 5 | the HUD | 2.5 | already cut by the HUD draw PR (docs/PERF_DRAW_1124.md) |
| 6 | loot loops (hunters x pickups) | 1.2-1.6 | `BeltKeys.tick` 0.64, `Wpicks.update` 0.46, `_update_pickups` 0.36: they asked the belt and the rule tables before the distance |
| 7 | the aim telegraphs (fight) | 1.2-1.4 | `AimDraw` rebuilds its mesh every frame: 120 us an entry (GDScript vertex pushes) |
| 8 | `SideRings` + `ShieldLook` + `BodyTell` | 0.5 | every hunter every frame, also those posed once in 4-6 frames |

Not costs here (measured): GPU time (0.6-9 ms on the 4090), shadows, draws, particles (docs/MATCH_PERF.md,
docs/PERF_DRAW_1124.md). The script cost is flat: no one function above 1 ms except the sums above.

## What changed (PR "perf(expedition): ...")
1. Loot loops: `PickupReach.within` (radius and height only) runs first in `Wpicks.update`, and `BeltKeys.blocked_pickup`
   tests the swap reach before the belt lookups. Same results, `--pickup-reach-check` asserts `within`.
2. `Bot._grid_path` no longer repeats an identical search without hazards on maps that have no hazard ground, and
   `_clear_line` calls the hazard test only where there is hazard ground (same paths).
3. `Hunter.render` runs ShieldLook / SideRings / BodyTell on the pose frames of a pose-throttled hunter (SimLod.pose_every:
   far, off screen, unseen); the looks follow state, not time. `AimDraw.covers` answers false without entries.

Tried and dropped: a rewrite of `_grid_path_in` (window arrays, index queue, ground read once per tile; same paths on 29
real pairs). Bots 3.19 -> 3.18 ms in a same-worker A/B: GDScript's cost is the per-tile work (about 1 us a tile), not the
allocations. Not committed.

## Before -> after (same worker, rp2g-1, 30-hunter bench; match script avg ms, step "pickups" ms)
| run | script avg | p99 | pickups |
|---|---|---|---|
| main, run 1 | 18.79 | 46.1 | 1.64 |
| main, run 2 | 17.08 | 36.9 | 1.19 |
| branch, run 1 (with the path rewrite, since dropped) | 17.80 | 40.8 | 0.48 |
| branch, run 2 | 16.92 | 41.1 | 0.65 |
The pods swing run to run by about 1 ms of script and 4 ms of wall, so only the pickups section is a proven gain
(1.2-1.6 -> 0.5-0.65 ms); the script average moves by less than the noise. The fight bench is unchanged inside noise
(hunters 3.0 / bots 1.0 / aim_draw 1.2-1.3 before and after): it has almost no loot on the ground.

## Next, ranked by what the data says
1. Bots' path search (1.0 ms plus 4.5 ms spikes: an A* or a goal-side flood cut, with a cache of "no path" per goal tile
   for PATH_REPLAN_S; changes paths, so it needs the bot checks and a look).
2. Hunter.render for hunters far from the camera: skip the cosmetic state between pose frames (about 1.5 ms of the 3.2).
3. AimDraw: build only entries near the camera, and keep a built entry's vertices while its inputs do not change.
4. Kit ticks and `_refresh_kin_stats` (a Dictionary rebuilt per hunter per frame, 0.28 ms).

## Round 2 (11-27): hidden Hunters, the path search, the line test
Profiled with temporary per-function timers (not committed) on the same `--bench-trios=10` run, 4090 pods and headless
here. What the counts said (per frame, 30 hunters): 27 Hunters rendered, **23 of them hidden by sight** (fog of war),
yet each ran the whole `Hunter.render` and was posed every 6th frame; 14.6 full bot sims; the tile path search hit its
4000-tile cap about every 2 s and then ran again without hazards (8000 tiles, ~24 ms here, ~50 ms on the pods: the
frames behind the 1% lows); `_clear_line` 4 calls at ~140 us.

What changed:
1. `SimLod.unheard`: a Hunter hidden (not visible) and over 40 m from the listener (past `Sfx.hear_range` 30 and
   StepReach 20) skips pose, looks and fx in `Hunter.render`; the wisp and ult-ready ticks still run, its Hero rig
   holds (`WardenGlb.POSE_HELD`), and it poses at once when it shows (catch-up capped at 0.5 s). Nothing visible or
   audible changes.
2. `Bot._grid_path_in` is A* with a bucket queue (newest first) and a per-search height cache: same found/not-found
   and the same path lengths as the old breadth-first search on 4800 real pairs (Hollow Crown and a generated map),
   3.3-4.6x faster when a path exists. The wide and no-hazard repeats run only when the search before ran into the
   window's edge or its cap, or turned a hazard tile down (otherwise they could not differ).
3. `Bot._clear_line` reads tiles inline and skips samples on the same three tiles: same answers on 8000 lines,
   1.7x faster.

Before -> after (`--perf-bench --bench-trios=10 --bench-secs=45 --bench-view=1920x1080 --quality=medium`):
| run | script avg | script p99 | wall p99 | 1% low | hunter render | bots | gpu | draws / objects |
|---|---|---|---|---|---|---|---|---|
| main rp3g-1 | 35.53 | 107.6 | 198.5 | 3.1 | 5.99 | 6.41 | 5.61 | 535 / 1160 |
| branch rp3g-1 | 36.90 | 77.2 | 128.2 | 4.2 | 3.98 | 5.83 | 0.79 | 471 / 912 |
| main rp3g-2 | 36.33 | 89.1 | 146.9 | 3.8 | 6.48 | 6.99 | 5.56 | 531 / 1178 |
| branch rp3g-2 | 36.36 | 65.9 | 99.9 | 5.4 | 3.88 | 5.66 | 0.65 | 465 / 913 |
| main here (headless, 2 runs) | 18.63 / 18.34 | 45.6 / 40.8 | | | 3.26 / 3.30 | 3.30 / 3.28 | | |
| branch here (headless, 2 runs) | 16.53 / 16.49 | 33.7 / 33.5 | | | 2.07 / 2.00 | 2.62 / 2.78 | | |
The pods were shared with other GPU jobs during the branch runs: sections this PR does not touch (mobs, kins, shots,
separate, interact, lairs, pickups, rest) cost 6% and 18% more there than in the main runs, which eats the average.
The same-box headless A/B (interleaved) has the script average 1.9 ms lower (-10%) and p99 -22%; on the pods the
targeted sections fall 2.0-2.6 ms (render) and 0.6-1.3 ms (bots), script p99 -25 to -28%, wall p99 -32 to -35%.
The 1% lows stay low because of one-off spawn hitches (box spawns, 800+ ms) that are the load-in job's.

## Next, ranked (round 2)
1. Hunter sim (4-8 ms): 14.6 full sims a frame; the kit ticks and the input gates are 1.4 ms, `_physics` 1.1 ms. A
   lower rate for calm bots past THINK_FAR_M (decision 0022 sets 20 Hz) is the big lever; it changes far fights.
2. HUD 5-6 ms on the pods: panels 1.2, world labels 0.9, minimap 0.3 (headless numbers), spread over many parts.
3. The spawn hitches above (box spawns building 24 Nodes each at once).

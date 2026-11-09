# Performance: measuring and the frame budget

Target: an expedition holds 120 fps (8.3 ms a frame) with no frame over 33 ms on the Mac worker, with the
Extraction load in mind (10 trios, 30 Hunters, their Boki, monsters and VFX).

## Measuring
- **`--perf-bench`** (`tools/perf_bench.gd`): a fixed busy expedition and then a farm run. Every frame is logged.
  `--bench-teams=10 --bench-squad=3` is the 30-Hunter load. It prints wall avg, p99, the 1% low, the frames over
  33 ms, the costliest step and visual sections, the heaviest meshes and the CPU particle emitters. Any frame over
  33 ms and 2x the 30 before it is printed with the step's costliest section and the nodes that entered the tree.
  The bench runs one sim step a frame, as play does. Until 11-08 it ran two, so older bench numbers overstate
  match script time about 2x.
- **The gate**: a match p99 more than 15% over the one recorded in `tools/perf_baseline.json` for the same adapter,
  load, quality and length exits 1. Add a key from a run's `BENCH GATE no baseline for '...'` line.
- **`--bench-ablate`**: switches each script's `_process` and each engine class's internal process off for a few
  frames. It is rough: Godot's `TIME_PROCESS` monitor is the worst frame of the last second, so only big
  differences mean anything.
- **The GDScript profiler**: `yes c | godot -d --profiling -- --perf-bench ...` prints per-function totals, self
  time and calls for sampled frames. Sum them over the run to rank the costs.
- **In game**: Settings > Video > Frame rate > Performance overlay. It shows the frame time, 1% low, draws, the
  step's costliest sections, and the **hitch log**: the last three frames over 33 ms, each split into render
  (and GPU wait), script with the step's top section, and physics.

## What runs less often far away
| What | Rule | Knob |
|---|---|---|
| Hero rigs (`WardenGlb.Sync`, `AnimLod`) | off screen every 4th frame, past 48 m every 2nd, catching up on the skipped time | `tuning.json` perf `hero_anim_*`; off on Ultra |
| Hunter, Boki and monster visuals (`Match._render_lod`) | beyond 34 m x zoom from the camera focus every 4th frame | Hunters: off on Ultra |
| Bot decisions | past 45 m from you every 3rd step, each bot on its own step | `Bot.FAR_EVERY` |
| Bot route (`Bot._steer`) | the way to the goal is re-planned every 0.1 s, the heading every step | perf `bot_replan_s` |
| Boki with nothing to fight | looks for a foe every 0.15-0.25 s | perf `boki_retarget_s` |
| Bot belt (`BeltKeys.tick`) | a bot looks for a blocked key every 0.1 s, each bot on its own step; you every step | perf `bot_belt_s` |
| Bot interact (`Match._update_interact`) | a bot that isn't pressing interact skips the box, item, chest, shrine and lair scans | - |

Numbers live in `content/rules/tuning.json` ("perf"), the one shared tuning file. Visual trades are behind the
quality preset (`Settings.QUALITY` `anim_lod`): Ultra keeps everything at full rate.

## Hot-path rules
- Test the cheap things first (range, then score), the costly ones (line of sight, a walk test, `can_see`) last
  and only for a candidate that would win.
- No new arrays or dictionaries per call in per-step code (`World.occupy` uses a const ring).
- Stagger periodic work by entity id so it does not all land on one frame.
- A tiny function called thousands of times a frame costs more in calls than in work. `World.ground_at`,
  `is_block`, `occupy`'s ring and `los` read the tile by hand; `HunterTimers` and `Kin.sim` count their
  timers down by direct access, not `set()`/`get()` by name. `--hotpath-check` keeps the fast paths equal
  to the plain code on random points.
- No `keys()`, string formats or array literals in per-step loops (consts, or iterate the dictionary).

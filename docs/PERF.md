# Performance: measuring and the frame budget

Target: an expedition holds 120 fps (8.3 ms a frame) with no frame over 33 ms on the Mac worker, with the
Extraction load in mind (10 trios, 30 Hunters, their Boki, monsters and VFX).

## Measuring
- **`--perf-bench`** (`tools/perf_bench.gd`): a fixed busy expedition and then a farm run. Every frame is logged.
  `--bench-teams=10 --bench-squad=3` is the 30-Hunter load. `--bench-stress` is the 60-actor load: 30 Hunters,
  every Boki thrown out and kept out, no fight brought to you. It prints wall avg, p99, the 1% low, the frames over
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
| Hero and Boki rigs (`WardenGlb.Sync`, `BokiRig`, `AnimLod.Gate`) | off screen (their `VisibleOnScreenNotifier3D`) every 10th frame, past `actor_far_m` (36/48/56 m on low/medium/high, 0 on very low) every 2nd, catching up on the skipped time | perf `actor_far_m`, `anim_far_every`, `anim_off_every`; off on Ultra |
| Rig shadows and Boki ink outline | off screen or past `actor_far_m`: no shadow, and a Boki draws without its ink pass | as above |
| Boki out of a fight (`KinPace`) | re-plans its walk at 10 Hz; far from you (past 45 m), calm, its whole sim runs at 10 Hz with the skipped time added in | `KinPace.THINK_S`, `FAR_EVERY`; off-line only |
| Hunter, Boki and monster visuals (`Match._render_lod`) | beyond 34 m x zoom from the camera focus every 4th frame | Hunters: off on Ultra |
| Bot decisions | past 45 m from you every 3rd step, past 90 m every 6th, each bot on its own step | `Bot.FAR_EVERY`, `FAR2_EVERY` |
| Bot route (`Bot._steer`) | the way to the goal is re-planned every 0.1 s, the heading every step | perf `bot_replan_s` |
| Boki with nothing to fight | looks for a foe every 0.15-0.25 s | perf `boki_retarget_s` |

Numbers live in `content/rules/tuning.json` ("perf"), the one shared tuning file. Visual trades are behind the
quality preset (`Settings.QUALITY` `anim_lod`): Ultra keeps everything at full rate.

## Particle budget
VFX particles stay **under 4,000 on screen** at every preset (owner 11-08). `ParticleCount` (scripts/perf/) counts
them: a GPU emitter is `amount x amount_ratio`, a CPU one `amount`. `--perf-bench` prints the busiest sample as
`BENCH particles drawn at the peak`, by owner. `--particle-budget-check` (headless, ~1 min) lists what every Hero
move (content/vfx) and every shared `Fx.burst`/`Fx.spark` call asks for, builds a 30-Hunter match at each preset
and adds the worst a fight piles on: the full Fx burst and spark pools and the Hero VFX cap (`HeroVfx.MAX_LIVE`,
420). Each preset must be under 4,000, each one down must draw less, and High and Ultra must draw the same.
- **Biggest emitters (High):** island ash and pickup motes (`Main`, 886), the ash storm (`RaidFx`, 366), the full Fx
  pools (840 + 720), the Hero VFX cap (420). The biggest Hero moves ask for 120 (`ashwick/jets`), 116
  (`ashwick/lance`), 64 (`ashwick/ram_trail`, `juggernaut/drop_hit`).
- **Scaling:** `Settings.QUALITY` has `fx` (amount x) and `fx_life` (lifetime x: 0.5 very low, 0.7 low, 1.0 from
  medium up). Fx bursts and sparks, the Hero VFX layers and the ambient emitters (`ParticleCount.tune`: island ash,
  pickup motes, the ash storm, landmark and exit motes, Hunter weapon smoke, auras) all follow them. High and Ultra
  are untouched. The ash storm no longer has its own `Settings.lite()` cut; it follows `fx`.

| Worst moment, 30 Hunters (particles) | Very Low | Low | Medium | High | Ultra |
|---|---|---|---|---|---|
| before (this branch without `tune`) | 1812 | 2173 | 2750 | 3454 | 3454 |
| after | 1315 | 1808 | 2539 | 3454 | 3454 |

The "before" Very Low and Low rows are 214 too high for the old build, whose ash storm was cut to 152 by `lite()`.

`--perf-bench --bench-stress` (30 Hunters, 40 s, 1920x1080, real GPU through `jobq`), particles at the busiest sample:

| Preset | before | after | wall avg / p99 after (RTX 4090) | render GPU after |
|---|---|---|---|---|
| High | 1684 | 1615 | 63.6 / 91.5 ms | 2.6 ms |
| Low | 923 | 751 | 63.9 / 92.0 ms | 2.7 ms |
| Very Low | n/a (job still queued) | 448 | 60.3 / 87.9 ms | 1.3 ms |

The "before" High and Low runs landed on other machines (Apple M5, RTX 4070 SUPER, Compatibility renderer), so their
frame times do not compare with the 4090's and are left out; particle counts do not depend on the GPU. High differs
by sampling only (the code is unchanged for it). The frame is CPU bound (match script about 30 ms); the render GPU
time is 1-3 ms, so particles at these counts are not what limits the frame. The point of the cut is the weak machines.

## Hot-path rules
- Test the cheap things first (range, then score), the costly ones (line of sight, a walk test, `can_see`) last
  and only for a candidate that would win.
- No new arrays or dictionaries per call in per-step code (`World.occupy` uses a const ring).
- Stagger periodic work by entity id so it does not all land on one frame.

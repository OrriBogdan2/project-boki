# Perf train 0.24.5 (ext/perf-train-0245, 2026-11-10)

The perf branches merge-candidate kept skipping on conflicts, merged onto the 0.24.4 build
(ext/release-integ-0244 at ec7bccf3b, its later tip re-merged), plus two fixes measured on their own.

## Measured
All runs on real GPUs through jobq, auto quality. In every case the load benchmark picked **Very Low**.
`--hitch-check` is the same tool on every tree: the fixed one below, copied into the base snapshot.
Each phase cell is median / p95 / worst ms, then (frames over 50 ms).

**rp1-1 (RTX 4090 box, CPU-bound; Forward+)**
| | base 0.24.4 | merged | + catch-up cap | + prop range (tip) |
|---|---|---|---|---|
| loading screen | 31.5 s, 96 compiles (warm_up 6.3 s, hunters 2.7 s) | 32.5 s, 94 | 34.7 s, 94 | 34.7 s, 96 (warm_up 7.4 s, hunters 3.0 s) |
| first | 43 / 162 / 162 (3) | 44 / 150 / 150 (3) | 35 / 169 / 169 (2) | 43 / 168 / 168 (2) |
| planning | 44 / 54 / 85 (7) | 38 / 55 / 56 (4) | 34 / 45 / 56 (1) | 42 / 57 / 64 (5) |
| ride | 48 / 188 / 270 (119) | 36 / 81 / 145 (122) | 35 / 101 / 207 (108) | 41 / 91 / 186 (136) |
| drop | 54 / 97 / 154 (274) | 42 / 70 / 464 (194) | 48 / 81 / 174 (204) | 47 / 80 / 85 (201) |
| land | 58 / 71 / 155 (160) | 40 / 49 / 83 (5) | 43 / 58 / 99 (36) | 42 / 58 / 87 (39) |
| draws (ride, worst frames) | ~2240 | ~2100 | ~2060 | ~2030 |
| perf-bench match (one step a frame) | 33.8 ms avg, p99 52.7, script 13.0 / p99 26.8, 849 draws | | | 31.5 ms avg, p99 47.3, script 10.9 / p99 21.4, 773 draws |

**mac-Naruto-Founder (Apple M5; the jobq Mac runs GL Compatibility, so the compile counter reads 0)**
| | base 0.24.4 | merged | + catch-up cap | + prop range (tip) |
|---|---|---|---|---|
| loading screen | 22.9 s (warm_up 15.9 s) | 24.3 s (warm_up 17.4 s) | 22.9 s (warm_up 16.4 s) | 23.3 s (warm_up 16.6 s) |
| ride | 29 / 83 / 111 (56) | 21 / 44 / 62 (3) | 20 / 41 / 61 (3) | 21 / 45 / 106 (5) |
| drop | 43 / 70 / 91 (159) | 31 / 50 / 154 (16) | 29 / 45 / 102 (6) | 28 / 51 / 107 (20) |
| land | 34 / 44 / 92 (2) | 25 / 36 / 308 (4) | 24 / 32 / 147 (3) | 25 / 32 / 82 (3) |
| draws (drop / land, worst frames) | | ~2915 / ~1090 | ~2920 / ~1080 | ~2650 / ~960 |
| perf-bench match | 19.0 ms avg, p99 72.2, 854 draws, script 3.0 ms | 17.0 ms avg, p99 41.5, 1019 draws | | 15.5 ms avg, p99 69.6, 730 draws, script 2.5 ms |

**Catch-up cap, A/B** (`--perf-bench --bench-real`, rp1-1, merged vs + cap): match p99 85.2 -> 66.1 ms, script p99
45.4 -> 32.2 ms, frames over 33 ms 953 -> 895; 60 s of match took 67.4 vs 68.8 s of frames (the cap barely slows
the clock). hitch-check can't see the cap: it steps the match itself.

Reading it:
- The merges are the clear win. On the 4090 box the ride, drop and land medians fell 6-18 ms, and frames over 50 ms on
  landing went 160 -> 5-39.
- The two fixes are within run-to-run noise on hitch-check (merged vs + cap is the same code there: compare those
  columns for the noise). The cap shows in the real-time A/B. The prop range takes ~9% of the Mac's drop and land
  draws.
- On the M5 the hitches are render, not script: drop frames of 2600-2900 draws spend 60-140 ms in render submit,
  while the sim runs 4-6 ms. A landing frame of 300 ms came right after the hitch-check's 10-monster pack, first
  drawn on GL (a compile at first draw). The loading screen is mostly warm-up (16-17 s of 23 s on the Mac).
- On the M5, base -> tip: ride, drop and land medians 29/43/34 -> 21/28/25 ms, and frames over 50 ms 56/159 -> 5/20
  in the ride and drop. The tip's perf-bench gate fails on the Mac (p99 69.6 ms against a recorded 54.9). Base
  measures 72.2 with the same bench, so the recorded Mac baseline is stale, not a regression. The owner's 11-10 M5
  medians (44-71 ms) held the hitch-check double step fixed below.

## What merged
| Branch | What it brings | Conflicts and how both intents were kept |
|---|---|---|
| ext/perf-actors-1108-rebased (holds ext/expedition-fps-1108, -r2 and ext/perf-actors-1108) | bots re-plan at 10 Hz, far bots on their own beat, Boki retarget every 0.2 s, AnimLod for Hero and Boki rigs, one tile read per ground sample, timers by direct access, hitch log, bench sections, perf gate | tuning.json: main's movement block kept, the `perf` block added; Boki targeting takes the cheap-tests-first loop with main's `foes_of(team, false)` (no fights started with wild Boki); Kin timers: direct lines without `bark_cd` (main removed it); World.occupy: the inlined ring kept inside main's `ghost` guard; BokiRig: main's KinFlinch beside the LOD gate |
| ext/perf-fight-pools | ring, ghost and beam meshes pooled (FxPool), fight node count in the bench | main's ring look (wash, halo) set on the pooled ring; main's bolt is drawn with beams, so the bolt pool went and the beam pool holds 36 (three bolts and three beams) |
| ext/perf-mobs-1108 | monster counts per preset (MobBudget), gem nodes reused, spare mob models, VFX budget readout | its "fewer, bigger gem drops" dropped: main already drops one pile (DropMerge); pooled gem nodes reset their scale so DropMerge sizes them |
| ext/perf-model-drawcalls | WardenMerge (equal surfaces joined, one ink shell per body), `--model-draws` | `--bench-total` dropped: main's `--bench-teams`/`--bench-squad` do the same |
| ext/perf-occluders | baked occluders, Medium and up | the `occlusion` knob added to main's five presets (off on Very Low and Low) |
| ext/perf-render-presets-1108b | 2 commits: the dead physics-steps knob removed, Very Low stays lit (+ video_v 5: Medium's saved 2x MSAA goes to FXAA) | its first commit is already on main (ext/perf-render-presets-1108) |
| ext/perf-visibility-ranges-rebased | draw distance per scatter class and preset, far cliff version | registry only |
| merge of origin/main 449fcaf48f (this rebase) | nothing new: main had landed `SimLod` (far bots at 20 Hz, think_k), cached bot steering and the home's one-batch scatter (`World.scatter_chunk`) | Bot: main's SimLod/steering replace the branch's `FAR_EVERY`/`FAR2_EVERY` far decisions and `replan_s` (`bot_replan_s` removed; `Bot.FAR_M` users read `SimLod.FAR_M`); the branch's `_clear_line`/`_choose` speedups kept. SpawnPlan: the branch's sliced REVISIT_S pass kept, with main's per-team member lists and sight bound. World: FarRanges kept, `scatter_chunk` added after it. Kin: main's hittable states (no `reviving`) in the branch's const. Match pickups: main's can_take (no rift-key special case). BokiRig: main's BokiHomeClips.install, then the manual AnimLod callback mode. HomeBuild ponds: main's MultiMesh. perf_bench: both flag sets (zone/shots and stress/real/brawl/gate). move_feel_check slope rows: gone with main's revert |
| ext/fight-hitch | World.los one tile read a sample, Hunter gear sums kept a step, SpawnPlan sight checks spread, Bot._clear_line, `--bench-brawl` | los: the branch's version (it also skips a repeated tile); bench: brawl mode wired into main's setup/finish |
| ext/farm-perf-low | small farm props and bank stones cast no shadow | only that half of be4e11fe5; its bench "base part" commits need the garden base demo, which is not on this base |

## Skipped
- ext/fps-feel: merged, then reverted. At 60 Hz it raises the jump apex from 1.52 to 1.57 m and changes Mage's dash
  tap (5 new feel-golden drifts: Gil jump, dive, glide, wall kick; Mage dash tap). That is a feel change, not a perf
  one, since the match steps a fixed 1/60 s. Its own `--fps-feel-check` also fails on main's newer dash curves and
  air drag (Vex, Albert and Sable spread 3-6% across 30/60/144 Hz). Needs a movement pass and the owner's yes on the
  apex.
- ext/feel-first-cast-warm (11 commits, first-cast warm-ups): a feel branch with its own review; it lengthens the
  loading screen.
- Already on the base, nothing to take: perf-94/94b/94c, perf-expedition-1108, perf-load-shaders-1108, perf-merge-drops,
  perf-multimesh, perf-texture-import, perf-render-presets-1108, map-perf-1108.

## Fixes on top
1. **Catch-up cap** (DashPace.CATCH_UP_S): offline a drawn frame advances at most three sim steps (was six), so one
   slow frame no longer queues the steps that make the next frame slower. Under 20 fps the game slows down instead.
   Online is unchanged. `--perf-throttle-check` asserts both.
2. **Prop draw distance** (FarRanges.props): chest and breakable parts draw within 60/80/110 m on Very Low/Low/Medium.
   Every part except the Beacon is limited (the Beacon is the light pillar that shows a chest from afar). From the skyship and in the drop, hundreds of
   lids, locks and keys were drawn map-wide. `--far-ranges-check` asserts it.

## Measuring tools fixed on the way
- `--hitch-check` stepped twice on every judged frame (its own step, then `_process` stepped again), so drop and land
  medians held a whole extra sim step. Its phase lines now also give p95 and frames over 50 ms.
- `--perf-bench --bench-real` hands the match each frame's real wall time, so its own catch-up decides the steps (the
  default steps once a frame, as before).
- The base numbers above use the same hitch-check and a one-step perf-bench, copied into the base snapshot, so both
  sides are measured alike.

## Next (biggest costs left)
- Draw calls in the ride and drop (2000-2900 from the skyship height): render submit is the M5's hitch. The scatter,
  terrain chunks and the 30 Hunters' parts seen from above are next; chests were a small share.
- Warm-up on the loading screen (16-17 s on the M5's GL, 6-7 s on the 4090): no pipeline cache on Metal or the macOS
  GL driver (docs/DEBT.md, loading and shader warm-up). The fix is fewer material variants, or an engine with a
  binary archive.
- Monster packs: their first draw compiles on GL mid-fight (the 300 ms landing frame); warm their materials with the
  stand-ins.

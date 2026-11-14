# Match performance: the 30-hunter profile (2026-11-11)

Owner playtest 11-11 on 0.24.4 (Windows, itch app): "game performance is not great still".

## The tool
`--match-profile` (tools/match_profile.gd, built on `--hitch-check`): a real expedition with 30 hunters (ten squads
of three, as the queue builds one) at 1920x1080, one sim step per drawn frame, in five phases: the skyship
ride, the drop, landing, a fight with every landed hunter brought round you (15 s), then your uplink charged
under monster waves and the lift ridden. Per phase: frame ms p50/p95/p99/max and frames over 33 ms; the
frame split (sim = Match.step, visuals = Match._process, other = every other node's process, render submit,
physics, rest = swap/driver/GPU wait), GPU ms, the HUD's canvas draw, draws, CPU or GPU bound; the sim and
visuals sections; then every frame over 33 ms with its cause (shader or pipeline compile, first draw, build
step, UI build, VFX spawn, or the biggest part with its sections and the nodes spawned in it).

    jobq submit --needs gpu --only <worker> --tree <tree> -- --match-profile [--profile-view=WxH] [--quality=...]

The RunPod workers (rp1-*) run Vulkan Forward+, the owner's desktop renderer; MRROBOTO and the Mac are pinned
to Compatibility by the worker. GDScript has no GC, so there is no GC column.

## What it found
- **The 3D heroes' bone sync (WardenGlb.Sync) was the biggest single cost**: every hunter's skeleton was
  retargeted from its rig every frame, also for hunters aboard the skyship, out of sight or off screen,
  though Hunter.render poses those rigs only every 3rd-6th frame; and each bone went through
  set_bone_global_pose, whose parent read recomputed the dirty bones and told the BoneAttachment3Ds once per
  bone. A same-run A/B (the 31 Sync nodes switched off for 30 frames at a time) put it at 7 ms of a fight frame.
  Now it runs on the frames the rig was posed (Hunter.anim_posed) and sets each bone once.
- **Bots' target pick** ran the sight test (two line-of-sight marches per teammate) on every rival before the
  reach test: 2.4 ms a step in the fight. Reach first now; line of sight reads the ground once a sample.
- Rings and dash after-images made and freed a node and a material each: pooled now.
- The spring chains of the 3D heroes built a Quaternion from a zero vector whenever two chain points met (a
  teleport, the floor clamp): an error print with a backtrace each time. Now no turn there.
- `--perf-bench` and `--hitch-check` ran two sim steps a frame (Match._process steps on its own clock after
  the tool's own step): their match script times were about doubled. Fixed; old and new bench numbers differ by it.
- Not a cause: CPU particle simulation (all 111 systems off: under 1 ms), Skeleton3D updates, the small
  per-prop scripts (prop_anim, key_glint, kin_puppet, boki_rig, the HUD's own _process: under 1 ms together).
- Tried and dropped: `--render-thread separate` (render submission on its own thread) crashes Godot 4.6.2 at
  start (FATAL in propagate_notification).

## Numbers
Local (rpc4, headless, shared box: compare within a row), frame ms p50 / other scripts ms, before -> after
the Sync fix alone: ride 18.5 / 6.7 -> 13.4 / 1.7, drop 20.5 / 6.9 -> 16.8 / 2.7, fight 30.8 / 8.3 -> 27.9 / 5.7
(fight p99 65 -> 37).

GPU: rp1-0 (RTX 4090, Forward+ Vulkan, 1920x1080, auto quality = Medium), the same worker for both; before =
4235ef621 + the final tool (jobs 20261111-184424-31053 and -195259-26987, which agree within 2 ms at p50),
after = 63d70807e (job 20261111-195313-00416). Frame ms p50 / p95 / p99, then "other scripts", bots and draws:

| phase | before | after | other ms | bots ms (sim) | draws |
|---|---|---|---|---|---|
| ride | 57.5 / 80 / 146 | 47.3 / 75 / 106 | 12.4 -> 3.5 | 0.5 -> 0.4 | 1720 |
| drop | 63.9 / 81 / 97 | 55.4 / 91 / 205 | 13.9 -> 5.4 | 2.6 -> 2.7 | 930 |
| land | 67.3 / 80 / 94 | 58.5 / 73 / 82 | 13.0 -> 4.0 | 5.1 -> 4.0 | 1000-1050 |
| 30-hunter fight | 102.5 / 135 / 255 | 85.4 / 127 / 306 | 16.9 -> 10.2 | 10.5 -> 5.9 | 1750-1850 -> 1500 |
| extract | 70.3 / 90 / 146 | 60.5 / 81 / 92 | 15.6 -> 7.4 | 4.3 -> 2.5 | 820-900 |

Every phase is CPU bound: GPU time is 0.3-2 ms a frame. This worker's CPU is slow and shared (one host, four
GPU jobs), so all of its frames are over 33 ms and its p99 swings run to run (a third 'after' run timed out on a
loaded host); compare medians. Per frame in the fight after: sim 27 ms (hunters 11.7: kit ticks and hunter
physics, Boki 4.0), visuals 9.9, render submit 17.8 (1500 draws), the HUD canvas 11.7. Load is 43-49 s from a
cold shader cache (93 compiles, under the loading screen).

Hitches over 33 ms by cause (before): sim (the bone sync, bots' sight and a heavy step), swap/driver waits, a
few first-draw shader compiles on a cold cache (the Ways Out seat beam at the start of the ride: 274 ms), a mob
pack's spawn frame, and a flood of zero-vector Quaternion errors from the 3D heroes' spring chains (20,303 error
prints with backtraces in one run; fixed). No GC (GDScript), no physics (0.1 ms), no navmesh, no network
(offline) costs.

## Merge-candidate history (MERGE_REPORT.md, Mac M5 worker, `--perf-bench` 6 hunters)
Main and candidate swing between two levels on the same worker (match script avg 6-7 ms or 21-27 ms; wall avg
19-26 or 42-49 ms) with no code pattern behind the swing (11-08 11:09: main 47.4 ms, candidate 22.9 ms), so
the history shows no regression since 0.24.2 that it can separate from worker noise. It could not have shown
this one: 6 hunters, not 30, and the doubled sim step.

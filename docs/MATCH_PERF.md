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

## 2026-11-16 pass (owner: "still getting very low fps for my card")
`--match-profile` had stopped parsing on main (its `run()` no longer matched hitch-check's `run(main, mode)`), so
no GPU profile could run; fixed first. Same tool, 30 hunters, 1920x1080, auto quality, origin/main e2bc08e889.
Frame ms p50 / p95, then the split (sim, visuals, other scripts, render submit, rest = swap/driver), the HUD
canvas draw and draws:

| phase | rp1-3 RTX 4090 Forward+ (job 185453-32553) | Mac M5 Compatibility (job 183556-07394) |
|---|---|---|
| ride | 60.1 / 77; sim 12.5, vis 9.1, other 10.0, render 19.5, rest 5.9; hud 2.5; 1303 draws | 28.8 / 39; render 15.8; 1340 draws |
| drop | 69.2 / 89; sim 20.2, vis 9.6, other 12.7, render 16.6, rest 8.6; hud 4.3; 968 | 35.3 / 45; render 17.8; 977 |
| land | 68.9 / 83; sim 26.0, other 9.5, render 14.3; 617 | 32.0 / 42; render 15.5; 588 |
| fight | 96.0 / 130; sim 32.5, vis 14.5, other 18.6, render 16.4, rest 14.8; hud 9.4; 841 | 69.2 / 94; sim 10.5, render 43.0; hud 2.8; 1680 |
| extract | 80.2 / 103 (that run's tail was slow) | 24.8 / 35; render 8.7; 607 |

Every phase is CPU bound (GPU 2-6 ms). The fight's biggest costs on rp1: render submit (16-22 ms, 840-1480
draws), other scripts (18-21 ms), hunters' sim (12 ms: kits and hunter physics), the HUD canvas (9-11 ms, of
which the world labels over other hunters are 8.4 ms and the nameplates alone 3.6 ms), bots (7.4 ms), the
hunters' visuals (7.3 ms). On Compatibility (GL) the render submit is the largest single cost (43 ms at 1680
draws). rp1 workers are shared: two runs of the same tree differ by up to 10 ms at the fight's p50 and its draw
count swings 780-1480, so a change of a few ms only shows in a same-run A/B.

- **MobGlb** (each skinned monster's pivots copied onto its bones) ran every frame for every monster (119 in
  the match) through `set_bone_global_pose`, though Match poses far monsters only every 4th frame. It now copies
  on the frames the monster was posed, one local pose per bone. Same-run A/B on rp1-2 (job 195806-25417, old
  and new code alternating every 30 frames): 1.15-1.36 -> 0.57-0.78 ms a frame.
- PR #158 (perf lane P2: WardenMerge draw joins, gear-stat sums kept for a step, Bot._clear_line, Truce sight
  asks) on the same worker: fight p50 106 vs 96 ms for main, inside that worker's run-to-run spread; its own
  check numbers (draws per 12 Hunters 227 -> 154) are the measured part.
- **Where "other scripts" goes** (probe builds, never pushed: each node's `_process` wrapped in a timer; rp1-2,
  fight, ms a frame, jobs 201219-19953 to 205122-21233): the 3D heroes' WardenSync 12-15 (30 heroes; 4.5-5 in
  the ride), of which WardenClips.step 7.5-9.3 (its AnimationTree `advance`, engine blending, 5.5-6.4; the clip
  pick and blend weights around it ~2.4) and the spring chains 1.9-2.8; BokiRig 1.9, KinPuppet 0.8, MobGlb 0.6
  (after the fix above), key_glint and prop_anim 0.1 each. The HUD's world labels (8.4) split into the plates
  (3.6), the glove and Boki icons under each rival's plate (GripOverhead, 2.0-2.3) and the loop's own lookups.
- **Next targets**, biggest first: WardenClips' AnimationTree advance for rivals in view (a lower clip rate for
  rivals that are not your squad or your target, as SimLod.pose_every already does off screen); render submit
  (draw count); the hunters' sim (12 ms); the HUD plates and GripOverhead (redraw only what changed).

## 2026-11-17 pass (the 11-16 branch gated, the slow-frame pose rate)
The 11-16 branch (MobGlb, the profiler fix, PR #158 folded in) merged with main 11-17 and gated as PR ext/perf-gpu-1116.
The RunPod GPU workers (rp1-0..3) lost libxkbcommon on 11-17 03:30 EST (every Godot start fails before a window, with
or without --pod-x11) and MRROBOTO was offline, so this pass has no new real-GPU frame numbers; the 11-16 table above
stands, and the change below is measured headless (CPU scripts only, rpc8, a loaded box) in a same-run A/B.

- **SimLod.pose_every's slow-frame tier**: under 36 fps (Engine.get_frames_per_second, back to normal over 50) a rival
  on screen past 6 m from the camera's focus that is not your squad's and not in a fight with it is posed every 2nd
  frame: its HunterAnim, and a Hero's clips (the AnimationTree advance), springs and skeleton copy (WardenGlb.Sync)
  hold with it and catch the time up, as the far and off-screen tiers already did. A PC that holds 50 fps sees no
  change. `--perf-throttle-check` asserts the tier (near, after the player, quick again) and the fps hysteresis.
- `--match-profile --profile-ab`: SimLod.force_slow flipped every 30 frames, each phase's line per side, with the
  hunters a frame by pose rate (how many each tier reached). The profile has a new **watch** phase between the landing
  and the fight: every other hunter stood across the view 7.5-12 m to your sides, no bot think and no target (the
  common match frame: rivals in view that are not fighting you); and it reports when the match ends in a wipe before
  the lift (it waited for the lift and sat in the results screen).
- Headless same-run A/B (rpc8, CPU scripts, two runs; frame ms p50 / other scripts / visuals, tier off -> on, and the
  hunters a frame posed every 1 / 2 / 3 / 6 frames):
  - watch: 37.2/12.4/7.2 -> 35.0/11.3/6.7 and 28.9/8.9/5.6 -> 27.3/8.2/5.2; rates 10.1/0/10.4/1.6 -> 7.1/2.7/10.0/1.7.
    The tier reached 2.7-2.8 hunters a frame (the squad's bots engage some, the rest of the 29 are off screen at this
    camera) and took 1.6-2.2 ms off the frame: about 1 ms a frame per hunter it reaches, the same cost per Hero pose
    the 11-16 probe found (WardenSync 12-15 ms for 12-14 poses a frame).
  - fight: 37.8/11.2/6.9 -> 35.8/10.5/6.6 and 38.3/12.8/6.9 -> 37.6/12.5/7.0; rates 7.7/0/5.2/1.6 -> 6.9/0.8/5.1/1.6:
    in the brawl every rival on screen is after your squad, so the older every-frame rule keeps them (by design).
  - ride, drop, land, extract: inside the noise; the tier reaches 0-0.5 hunters a frame there (aboard the skyship they
    stand within 6 m or off screen; on the ground after the drop nearly every rival is unseen).
  So on a slow PC the saving is about 1 ms a frame per uninvolved rival in view; a wide view over a fight across the
  field (6-10 of them) is where it pays. The real-GPU number for it needs the rp1 pods back.

## 2026-11-26 pass (owner: "8 fps on the load in for the expedition")

`--loadin-fps-check` plays the first 30 s after the loading screen of a real expedition in real time (1920x1080, 30
players, the squad of 3 aboard the skyship), logging every frame (wall ms, draws, objects, nodes, sim steps, main-thread
cpu from `/proc/thread-self/schedstat`, `Match.vprof` sections). `--hitch-check` / `--load-check` fast-forward with 6
teams, which is why they never saw it.

- Cause: `Hunter.render` -> `SkyDeck.lift` -> `BootSole.low` skinned every boot vertex in GDScript, every frame, for all 30
  riders; only the squad of 3 is drawn on the deck. 214-227 ms a frame in the visual `hunters` section (about 7 ms a rider).
- Fix: `BootSole.low` folds the skeleton row and each bone's pose into one row per used bind index per call (a dot per vertex
  instead of a full transform); `SkyDeck.lift` skips riders that are not drawn and re-reads a shown rider's soles every
  `SOLE_EVERY` (3) renders. `hunters` is 6-11 ms a frame after. The check fails when the reads exceed that budget.
- RTX 4090 pod, seeds 4101 / 77, 30 s: avg 7.3 / 3.4 fps -> 24.2 / 11.2; main-thread cpu a frame 136 / 284 ms -> 40 / 77 ms.
  Not met yet: the 60 fps target. About 40 ms a frame of main-thread cpu remains, mostly outside the profiled sections
  (render submission for 16-32k objects, 1.6-2.4k draws; other scripts).

## 2026-11-27 pass: the planning map (load-in, part 2)

`--loadin-fps-check --loadin-split` (new: times Match._process, every script `_process` by file and the draw, by
phase: plan / plan-map / air / ground; `--loadin-inv` adds the planning-map scene inventory, `--loadin-shot=` saves
the planning-map frame). RTX 4090 pods, 1920x1080, 30 players, seed 4101 unless named.

- Where the load-in goes after the 11-26 fix (rp2g-1): render CPU only 2-4 ms a frame, GPU 7-10 ms; the main thread is
  Match._process 33 ms on the slow rp1 CPUs (sim ~9 ms a step at 2.4 steps a frame, visuals 12) and the pods' frame end
  (GPU wait + X11 window copy, docs/PERF_DRAW_1124.md: not paid on a real display).
- The drop planning (seconds ~5-13 after the screen): the ride camera sees every island, 2,477 things in view (1,143
  flora MultiMesh chunks, 57k copies; 811 materials), 33.6k objects and 2.4k draws a frame, frames 43 ms vs 19 ms on the
  deck intro just before, while the full map covers the whole screen under a 0.92 shade.
- Fix: `MapCover` (scripts/ui/map_cover.gd): while the planning map covers the screen the root viewport's 3D is off
  (as under the loading screen); the last world frame, copied off the GPU without a stall
  (`texture_get_data_async`), stays under every canvas layer, so the HUD and shade draw over it as before
  (planning-map frame vs main: mean pixel diff 2/255). The map closing or the ship setting off draws the 3D again.
  `--loadin-fps-check` fails (on every box, headless too) if the 3D draws under the planning map or stays off after it.
- rp2g-1, back to back: seed 77 planning 29.5 -> 38.7 fps (p50 34.1 -> 24.4 ms, cpu 32 -> 25 ms; the deck intro, which
  this does not touch, 59.8 / 63.6); seed 4101 planning 24.0 -> 35.2 fps. On rp1-1 (EPYC, busier) the planning cpu fell
  59 -> 54 ms and the wall time stayed within noise.
- Still open (the 60 fps target is not met on the pods): the full map's own 2D draw (FullMap.draw 4.7 ms a frame
  headless on a fast CPU: place names 1.5, train map 0.8, spawns 0.5; HUD draw 5 ms with the map, 2 without) wants
  its static layer cached; after the drop the sim (3.9-9 ms a step) runs 2.4-6 steps a frame on slow CPUs; Hunter
  visuals ~5 ms (the squad's three posed every frame, ~0.7 ms each); one 100-220 ms frame right after the loading
  screen and one ~140 ms frame when the ride view first draws (on main too).

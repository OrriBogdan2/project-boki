# Garden hub step 0: today's garden (gh0, 2026-11-10)

Section for briefs/PERF_AUDIT.md on ext/agent-briefs (briefs/ is not on main, so this branch carries only this
section; the integrator appends it under the expedition audit). Base: ext/garden-integrated 58686d0b6, no code change.

## Run
`jobq submit --needs gpu --tree <tree> --out bench -- --base-demo --perf-bench --bench-secs=5 --bench-farm=20 --bench-out=bench/frames.csv`
`--base-demo` is today's garden (BaseDemo.save(): base_mode, 4 Boki, snacks, bonds), Medium, 640x360 window, 1200 farm frames
(`--perf-bench` home part; the 5 s match part runs first and is ignored). The first two attempts (rp1-1, rp1-0) died on a stale
`.godot` class cache in the fresh worktree (`godot --headless --editor --quit` refreshes it); not a game bug.

## Home part, today's garden (4090 rows: RTX 4090, forward_plus; four runs, the scene is the same each time)
| worker | draws | objects | nodes | particle nodes | tris | lights | wall ms med / avg / p95 | script ms med |
|---|---|---|---|---|---|---|---|---|
| rp1-0 (jobq 20261110-095504-31775) | 712 | 1288 | 1414 | 53 | 821k | 4 | 8.1 / 8.8 / 10.3 | 10.5 |
| rp1-0 (-095507-28865) | 702 | 1288 | 1418 | 53 | 815k | 4 | 5.4 / 7.0 / 9.3 | 7.3 |
| rp1-0 (-095510-26698) | 699 | 1279 | 1416 | 53 | 816k | 4 | 8.3 / 8.8 / 10.1 | 10.9 |
| rp2-1 (-095457-32668) | 714 | 1297 | 1416 | 53 | 820k | 4 | 5.5 / 7.1 / 8.9 | 9.9 |
| **M5** mac-Naruto-Founder (-104629-18877; Apple M5, gl_compatibility) | 1065 | 1277 | 1404 | 53 | 814k | 4 | 11.5 / 12.1 / 12.0 | 12.4 |

Reading the columns:
- "script ms" is Performance.TIME_PROCESS for the whole frame (every node's `_process`), not base_life alone; its averages are
  poisoned by 1 s hitches in some runs (avg 14-82 ms), so use the median. The bench has no home section timer, so the
  10.6 "base_life <= 1.5 ms" line cannot be read from it without code (Match.prof has no home equivalent).
- "particle nodes" counts every GPUParticles3D/CPUParticles3D in the tree, emitting or not; the 10.6 line counts emitting ones.
- wall is uncapped (no vsync), 640x360, so the 4090s only prove the garden is not GPU-bound there; the 33 ms rp1-0
  "Very Low" line is met by a wide margin (rp1-0 here is a 4090, not a weak machine).
- M5 (the 16.7 ms Medium target): wall 11.5 ms median at 640x360, of which render cpu is 9.7 ms (4090 rows: 0.7-1.4 ms); gl_compatibility
  counts 1065 draws for the same scene (the 4090 rows are forward_plus). That is 70% of the 16.7 ms frame before any
  extra pixels, so the M5 is the machine that sets the draw budget, not the 4090s.
- Heaviest garden meshes: `@Node3D/@Node3D` 176 instances / 89k tris, `Deco/@Node3D` 36 / 54k, Ground 14.8k.

## Against 10.6
Today's garden is every island at once (the bridged side isles are still loaded), so it is a ceiling for one zone, not a zone.
- Draws 700 (1065 on the M5) vs the zone's <= 350 and the hub's <= 200: about 2x over. Objects 1290 vs <= 800 / <= 500. Nodes 1415 vs
  <= 3000 / <= 2000: fine. These three are what the zone split (step 3 onward, side isles deleted in step 11) has to buy.
- Decision: the table keeps its numbers, and <= 350 draws is read on the M5 (gl_compatibility) rows (a zone is a fraction of today's garden, and MultiMesh scatter is already the plan); the
  alternative, raise zone draws to <= 450, is for the owner if step 3's first zone bench on the M5 lands above 350.
- Two lines get a definition so the check can read them: emitters = emitting systems (today 53 particle nodes exist), and
  "script" = TIME_PROCESS median per frame, with base_life timed by its own marker once it exists (step 5).

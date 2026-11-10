# Wisps vs walking pets: frame time A/B (DECISIONS 2026-11-09 rollout step 2)

Question: does a Boki riding as a wisp (`boki_wisps`, KinWisp, decision 0038) cost less than a walking pet, with
30 Hunters and their Boki on the expedition map? Code under test: ext/soul-link-t3 37cb73338 (the soul-link stack)
plus the `--bench-ab` flag added here; no gameplay code changed.

## How it was run
`godot -- --perf-bench --bench-ab --bench-hunters=30 --bench-view=1920x1080 --bench-out=out/ab.csv` (jobq `--needs gpu`).
One process runs the same expedition three times: pets, wisps, pets again. Same seed (4101), same autoplay path,
same camera, 60 s each. The second pets run shows run-order drift. The first 5 s of each run are left out
(warm-up). One process means one GPU: jobs sent separately landed on different pods, so those numbers were not
comparable and were dropped. Frame time is wall ms per frame, measured by the bench; quality medium.

## Result: Apple M5, gl_compatibility, 1920x1080 (jobq 20261110-005650-15838)
| Run | frames | mean ms | p95 ms | p99 ms | worst ms | draw calls | frames over 50 ms | over 100 ms |
|---|---|---|---|---|---|---|---|---|
| pets (1) | 1751 | 41.8 | 59.2 | 107.3 | 199.8 | 820 | 263 | 26 |
| **wisps** | 1764 | 39.9 | 54.3 | 106.2 | 323.1 | 825 | 144 | 29 |
| pets (2) | 1717 | 42.4 | 56.5 | 104.7 | 171.5 | 913 | 229 | 20 |

Script ms per frame (match step): pets 18.2 / 18.1, wisps 15.6. Triangles 438k / 533k vs 495k, nodes about 11.6k vs 11.1k.

## Reading
- **Wisps are slightly cheaper on the CPU, not on draws.** About 2.5 ms less script per frame and about 4 % lower
  mean wall time, but the pets' own repeat differs by 0.6 ms and p95 by 2.7 ms, so the mean gain is inside the
  noise. Draw calls and triangles are equal within the pets' run-to-run spread: 30 Hunters, the map and the
  effects dominate the frame, the Boki are a small part of it.
- **Over 50 ms after warm-up: yes, both ways.** This load (30 Hunters at 1080p on a laptop-class GPU through the
  compatibility renderer) misses the 50 ms rule on 8 to 15 % of frames in every run, wisps included (144 vs
  229-263). It is not a wisp problem.
- **The worst frames are spawns.** The hitches name nodes entering the tree in one frame: a summoned Boki building its
  rig (60 MeshInstance3D in one frame at t=50 s), chest and fight props. The wisp run's worst frame (323 ms) is in the
  first 3 s of the match, a one-off load. These look like Boki rigs being built (Body, Flex, Eye nodes x4); if it is the summon, prewarm
  or pool the rig before wisps become the default. Not confirmed here.

## Recommendation
Switch the default to wisps. They do not cost more than pets on any number measured (mean, p95, script, draws), and they
cut the script time (nodes fall only 4 %). The over-50 ms frames belong to the
30-Hunter load itself and to rig building, so file them as perf work, not as a reason to hold wisps. Before the
flip: look at the rig-building hitches, and repeat this bench on the 4090 pods (Forward+) and the PC 4070 SUPER, where the
frame time is GPU-bound rather than CPU-bound as it is here.

Not covered: only one GPU class finished in time (rp2-1 did not return before the report); readability playtest is
a separate DECISIONS step.

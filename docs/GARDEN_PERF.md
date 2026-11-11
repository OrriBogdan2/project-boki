# Garden zone budget: measured (2026-11-10)

GARDEN.md 10.6 sets the budget; `content/rules/garden_zones.json` holds it (`budget`, `budget_hub`) and the
held ceilings (`ratchet`). Candidate stack: origin/main + `ext/garden-cinderstep-zone` (carries hub-zones and
Glasswater) + `ext/garden-hub-horizon`. Since `ext/garden-zone-draws` Hushwood and Kitewind Ridge are ZoneLayout
builds too (data in `garden_zones.json`, themes in `home_layout.gd`), so `--bench-zone=all` covers all five.

## Run
`jobq submit --needs gpu --only <worker> --tree <tree> --out bench -- --perf-bench --bench-secs=5 --bench-farm=10 --bench-zone=all --quality=<medium|low>`
Each built zone runs with 9 Boki out (6 residents, the partner, 2 visitors) and the hub. Draws and objects are read with
the screen UI hidden. `base_life` is the cost of one 10 Hz step with all 9 out. The run exits 1 on any FAIL.

## Numbers (draws / objects / nodes / emitting emitters / frame ms / base_life ms)
| part | M5 Medium (jobq 20261110-135258-04622) | rp1-0 Low, RTX 4090 (20261110-135308-11669) | target |
|---|---|---|---|
| hub | 689 / 689 / 1005 / 2 / 3.4 / - | 358 / - / - / - / 4.1 / - | 200 / 500 / 2000 / 6 / 0.5 ms script |
| Bramblebank | 740 / 740 / 1558 / 2 / 15.1 / 0.02 | 348 / - / - / - / 13.2 / - | 350 / 800 / 3000 / 12 / 16.7 (33 on rp1-0) / 1.5 |
| Glasswater | 375 / 400 / 1374 / 5 / 15.1 / 0.03 | 236 / - / - / - / 8.3 / - | same |
| Cinderstep | 513 / 524 / 1497 / 11 / 18.3 / 0.02 | 264 / - / - / - / 9.4 / - | same |

Over target: every M5 draw figure (Glasswater 375, Cinderstep 513 and 18.3 ms, Bramblebank 740, hub 689) and the hub on rp1-0 (358).
Within target: nodes, emitters, base_life everywhere, objects in every zone, all zone frames on rp1-0.

## Where the draws are
- Boki: each rig is about 14 meshes, so 9 Boki is roughly 150 draws.
- Fixtures: Stall about 44 meshes, Burrow 40, house about 86, hub Deco about 52. These are static and unmerged.
- The hub horizon is 5 draws (hub 358 vs hub without horizon 353 on rp1-0).
- The M5 counts more draws than the 4090 for the same scene (gl_compatibility, shadow passes at Medium).
- Cinderstep costs about 160 draws and 6 emitters more than Glasswater on the M5 for the same Boki; not yet explained.

## Held, not fixed
Draws did not come down in this change: the way to the target is merging the static fixtures (the `World._merge_static`
pattern, which frees its roots and needs `material_override` on every mesh, so each fixture has to be checked for
outside references first) and shrinking the Boki rig's mesh count at Low and Medium. `ratchet` fails the bench
if any held number gets worse.

## Draw fixes (ext/garden-zone-draws, 2026-11-11)
- A home's world scatter goes in one MultiMesh per kind (`World.scatter_chunk`): the whole island is on screen,
  so the match's 32-tile chunks only multiplied draws.
- Every placed layout piece (house, stall, toys, patch) bakes its plain parts into one mesh per material in each
  of its groups (`HomeBuild._merge_parts` over `Models.merge_static`; moving groups merge among themselves).
- Ponds were one mesh per tile plus a foam strip and three rim stones per bank edge: now three MultiMeshes.
  This was the "unexplained" Cinderstep extra: the bench save (NavCheck) paints a stream.
- No lights were added and no materials changed, so looks stay the same on every preset.

Draw passes per part, headless, top 20 owners (`BENCH draw passes by owner`, a pass is one surface, two with an
outline; a GPU adds shadow passes on top). Before = e7f172aa9 (ports only), after = the branch tip:

| part | before | after |
|---|---|---|
| hub | 753 | 615 |
| Bramblebank (zone part) | 782 | 498 |
| Glasswater | 489 | 406 |
| Cinderstep | 675 | 414 |
| Hushwood | 507 | 431 |
| Kitewind Ridge | 660 | 414 |

What is left: nine Boki are about 30 passes each (~270 of a zone: animated pivots, each with an outline), world
far scenery about 50 (six Flora styles of far rocks, kept for the look), and in the hub the incubator, burrow and
nest, built outside the layout path (not merged here).

GPU, `--perf-bench --bench-secs=5 --bench-farm=10 --bench-zone=all`, draws / frame ms, before (e7f172aa9) -> after
(aaccf1179). M5 Medium: jobq 20261111-090814-15113 -> 20261111-090939-17282; pc-MRROBOTO Low (RTX 4070 SUPER,
gl_compatibility): 20261111-090952-22488 -> 20261111-091010-11716.

| part | M5 Medium before | M5 Medium after | MRROBOTO Low before | MRROBOTO Low after |
|---|---|---|---|---|
| hub | 595 / 8.6 | 495 / 8.7 | 577 / 7.0 | 470 / 7.0 |
| Bramblebank | 458 / 15.9 | 349 / 16.6 | 458 / 7.0 | 342 / 7.0 |
| Glasswater | 316 / 18.0 | 255 / 11.5 | 283 / 7.0 | 265 / 7.0 |
| Cinderstep | 385 / 17.4 | 294 / 17.7 | 315 / 7.0 | 257 / 7.0 |
| Hushwood | 357 / 17.2 | 326 / 16.4 | 325 / 7.0 | 301 / 7.0 |
| Kitewind Ridge | 469 / 17.6 | 301 / 17.3 | 434 / 7.0 | 256 / 7.0 |

Every zone is now under 350 draws on both machines; the ratchet keeps only what is still over: the hub (M5 520,
Low 370 held from rp1-0, which MRROBOTO's 470 is past: a different machine, not loosened) and the M5 frame of
Cinderstep and Ridge (17-18 ms at a 640x360 window, near the 60 Hz line on both sides of the fixes, so the frame is
not draw-bound there). Objects, nodes, emitters and base_life are within budget everywhere.

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

## VFX clarity: keep / cut (ext/vfx-garden-clarity, 2026-11-12)
Owner principle: a particle, glow card or decal stays only if it says something (a ripe plant, water, a Boki's mood,
something you can use). `--perf-bench` now prints `BENCH vfx <part> <emitter|card:<shader>|decal> <owner> xN` for every
particle system that is emitting, every Decal and every see-through light/glow mesh in the home
(`FX_SHADERS` in `tools/perf_bench.gd`), and `--bench-shots=<dir>` saves each part's default-camera frame (UI hidden).

| what (hub, Glasswater, Hushwood, Ridge) | what it says | verdict |
|---|---|---|
| Portal beam, 40 motes at the pad | "the expedition portal is here, press E" | keep, 40 -> 20 (`ZoneDress.BEAM_AMOUNT`) |
| Portal Disc (glow card) and Base ring | the portal and where to step | keep |
| Portal Zone ring and ZoneFill (r 2.6 m) | only a match's exit fills them; in a home a dim extra ring round the pad | cut (freed in `ZoneDress.calm_pad`) |
| Landmark motes/snow/sparks, 22 each (Glasswater statue, Hushwood ring, Ridge spire) | nothing: 45 m from the camera frame, simulated all day | cut in built zones (`ZoneDress.quiet_landmarks`); the rocks stay, matches keep theirs |
| Boki Aura, 7 motes while a Boki glows | its mood or type | keep |
| Fx pool bursts (3-16 motes, a few at once at a toy) | a hit, a play, a cheer: one-shot, caused by an action | keep |
| Rain (260) | weather | keep (not emitting unless raining) |
| Decals | none exist in the home | n/a |
| Shallows sheet (Glasswater) | water | keep |
| Sky light shafts, 4 faint glow cards in the void past the island edge (`SkyDeco._shafts`, intensity 0.045-0.08) | nothing, but they sit off the island, never behind a Boki, and are the sky shared with matches | keep; quality `shafts` already drops them on Low (cut alternative: free them in homes) |
| One more ring card on Ridge (under a home station; source not traced) | unchanged before/after | untouched |
| Zone scatter (crystals, reeds, pebbles, mushrooms, ferns, flowers; counts in `garden_zones.json`) | ground dressing, not VFX | untouched; a lighter scatter is a separate look decision |

Numbers, headless-GL (xvfb, opengl3, llvmpipe, 1280x720, 9 Boki out, UI hidden), before = 085d31018 -> after = this
branch; draws / emitting emitters:

| part | before | after |
|---|---|---|
| hub | 455 / 2 | 453 / 2 |
| Glasswater | 244 / 9 | 242 / 4 |
| Hushwood | 290 / 8 | 294 / 3 |
| Kitewind Ridge | 249 / 3 | 243 / 2 |

Draws barely move (a glow card is one draw; the zones are not particle-bound); the win is on screen: the pad is one
lit ring plus a thinner beam, with no faint outer circle, and three fewer simulated landmark systems in the zones.
Emitter counts also swing with how many Boki bursts are live in the frame (Hushwood's 8 -> 3 is mostly that), so the
deterministic part is: Beam 40 -> 20, landmark emitters 1 -> 0 per zone. Shots: `docs/shots/garden-clarity/<part>.jpg`
are now the GPU frames below.

GPU, same machine both sides (rp1-1, Vulkan, `--quality=medium`, 9 Boki out, default home camera, UI hidden):
before = 085d31018 (jobq 20261112-080512-23012), after = eaf834490 (jobq 20261112-081310-12233). Draws / emitting
emitters / glow+ring cards from `BENCH vfx`:

| part | before | after |
|---|---|---|
| hub | 755 / 2 / 6 | 749 / 2 / 4 |
| Glasswater | 524 / 4 / 6 | 512 / 3 / 4 |
| Hushwood | 586 / 3 / 6 | 583 / 3 / 4 |
| Kitewind Ridge | 533 / 3 / 7 | 544 / 3 / 5 |

The fixed part shows in every zone: Beam 40 -> 20, Zone + ZoneFill cards gone, the landmark emitter gone; emitter
counts move only by live Boki bursts (Hushwood had 4 small bursts in the after frame). Draws are within run noise
(Ridge +11 is Boki in frame). `docs/shots/garden-clarity/<part>.jpg` are these GPU frames, left before, right after.
(Before also exits with a core dump at cleanup, rc 134, after all shots and numbers are written; after exits 0.)

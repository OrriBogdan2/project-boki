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
  of its groups (`Models.merge_tree`, keep_casts; moving groups merge among themselves).
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

Every zone is now under 350 draws on both machines; the ratchet keeps only what is still over: the M5 frame of
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

## 30 Boki, real GPU (ext/farm-garden-perf-30, 2026-11-23)
After the zones, hub, rival beats and new clips. `jobq submit --needs gpu --only rp1-1 --tree <tree> --out bench -- --perf-bench
--bench-garden --bench-secs=5 --bench-farm=15 --bench-zone=cinderstep --bench-boki=10,20,30 --bench-view=1920x1080
--quality=<medium|low> [--bench-isolate]`. rp1-1 = RTX 4090, Vulkan (forward_plus), 1920x1080, Low at 3d_scale 0.77.
Cinderstep is the busiest zone (most emitters and draws in the earlier tables). The hub has nobody living in it
(`ZoneAway`), so it is one run and does not move with the count. New: `--bench-garden`, `--bench-boki=a,b,c` (budget
lines are judged at 9 Boki only), `--bench-isolate` (`tools/perf/garden_isolate.gd`). Frame p50 / p95 ms, UI shown
(the part's own `BENCH <part> frames:` line):

| part | Medium before | Medium after | Low before | Low after | target |
|---|---|---|---|---|---|
| hub | 11.8 / 13.7 | 12.2 / 15.6 | 11.5 / 15.1 | 11.7 / 15.6 | 16.7 (60 fps) |
| Cinderstep 10 Boki | 17.9 / 22.1 | 19.2 / 22.9 | 17.3 / 20.8 | 18.2 / 22.3 | 16.7 medium, 33 low |
| Cinderstep 20 Boki | 26.7 / 30.1 | 24.5 / 30.8 | 26.4 / 30.4 | 23.8 / 29.1 | same |
| Cinderstep 30 Boki | 34.9 / 39.4 | 30.3 / 37.2 | 33.4 / 39.4 | 29.1 / 34.8 | same |

Before = origin/main 05d78b9e87 (jobq 20261123-090432-27983 medium, 20261123-090449-14296 low); after = this branch
(20261123-094722-00163 medium, 20261123-094722-03959 low). Draws at 10 / 20 / 30 Boki: 472 / 552 / 634 (Medium, with UI).

Verdict: **over target.** Medium misses 60 fps at 10 Boki already (about 18-19 ms) and reaches about 33 fps at 30;
Low meets 30 fps at 10, 20 and (after) 30 Boki (29.1 ms p50, p95 34.8; before 33.4 / 39.4). The hub is fine. The numbers are CPU-bound:
Medium and Low are within 1-2 ms of each other and the GPU time is 2-6 ms.

Run noise on this pod is large: the same scene in "as is" drifts 2-3 ms inside one run, and runs differ by 1-3 ms, so
only the same-run ABAB below counts as proof of a change; a single before/after frame time does not.

### Where it goes (`--bench-isolate`, Medium and Low, same run, p50 ms)
Cinderstep, with 10 / 20 / 30 Boki. "boki hidden" = no Boki drawn or stepped; "kin script" = `Home._move_kin` timed alone.
| cost | 10 | 20 | 30 |
|---|---|---|---|
| all Boki (hidden saves) | 4.6-5.5 | 5.2-6.5 | 6.1-8.7 |
| rigs paused (animation scripts + skeleton) | 3.6-5.7 | 3.1-4.5 | 3.0-3.5 |
| Boki shadows off | 0.2-3 | ~0 | ~0 |
| screen UI hidden | 1-1.5 | ~1 | ~0-1.5 |
| `Home._move_kin` script | 1.4-2.4 | 3.7-4.7 | 5.5-8.4 |

So: Boki cost 0.45-0.5 ms each at 10 and about 0.25 ms each at 30 (the rig is the first ~5 ms and saturates), the kin script
grows faster than the count (about n squared), shadows and the UI are not the cost. What stays when every Boki is hidden is
~12-14 ms for the island itself (the hub, with nobody, is 10-12 ms): that floor is what keeps Medium over 16.7 ms
and is the next job (not traced here: 1000 nodes, 650 draws, sky, world scripts).

### Fixes (cheapest big ones, all keep behaviour)
1. `RigPace.crowd` (`scripts/perf/rig_pace.gd`, `BokiRig._process`): in a home with more than 6 Boki out and below Ultra,
   a rig off the camera's focus runs its whole step (clip pick, flex, flinch, face, skeleton) every other frame with the
   time it held back, as the Metal path already did for the skeleton. The rig within 1.5 m of the focus keeps every frame.
   Matches never set `crowd`, so pets there are unchanged. Same-run ABAB (eased vs `RigPace.crowd_from = 999`, p50 ms):
   30 Boki 33.4 / 35.6 vs 37.4 / 37.3 (Medium, 20261123-093328-05005), 20 Boki 24.5-25.6 vs 26.6-27.0 and 30 Boki
   31.3-32.1 vs 34.1-34.7 (Medium after); 10 Boki 0-1 ms (inside the noise). Gain: 2-5 ms at 20-30 Boki.
2. `Home._separate_kin`: the pair loop asked `_kin_r` and `BaseLife.pile` for every pair; pairs past touching range
   (`pile` is 0.35, so never more than the two radii) now skip first. Identical pushes, fewer calls.
3. `KinAvoid.around`: tested `parked()` (the dear one) on every Boki before the range check; range first now.
   `Home._move_kin` at 30 Boki: 5.7-8.4 ms before, 5.6 ms after (noisy: the kin script is timed by wall clock).

### Held
- The 60 fps Medium target is not met even at 10 Boki: the island floor (~12 ms with nobody drawn) is the next cost.
- The kin script is still about n squared at 30 Boki (`kins.filter` in the idle choice, `HomeWork`, `life.step`).
- `--boki-rig-check`'s "fliers: hovering they hold 0.5 to 1.5 m up" fails here with the new easing switched off too
  (`crowd_from = 999`, which is main's behaviour), so it is not from this change; not run against a main worktree.
  `--perf-budget-check` timed out at 900 s on software GL here (no result).

## Hub draws (ext/farm-hub-draws, 2026-11-22)
Task: the hub under 350 draws at Medium and Low. Since the numbers above, merged work (zone draw fixes, merged
fixtures) had already brought it to 335 (Medium) and 330 (Low) on current main; the held 520 / 370 were stale. This
branch cuts it further and holds the new numbers.

What costs draws in the hub is distinct mesh + material pairs, not objects: Godot draws identical ones as one
instanced call (merging the incubator's 30 pebbles into one mesh per cradle changed nothing: objects -49, draws +4,
reverted). Switching every shadow caster off saves 8 draws, so shadows are not the lever either. Hiding each piece in
turn (temporary probe, not committed) found the pieces whose copies each had their own mesh:
- Incubator: the eight cradles were eight separately merged meshes (stone, nest, grate) of the same shape. One cradle is
  built and merged (`IncubatorCradle`), the others are `duplicate()`s that share its meshes: 68 -> 42 draws.
- Burrow: six window frames were six identical tori, now one shared mesh: 34 -> 24 draws.
No look changes at any preset (same meshes, same materials).

GPU, `--perf-bench --bench-secs=3 --bench-farm=8`, same machine type both sides (RTX 4090, forward_plus, 640x360,
UI hidden), draws / objects / frame ms. Before = 0a0db9747c (jobq 20261122-050834-16169 Medium, 20261122-050847-04902
Low), after = this branch (20261122-061648-29848 Medium, 20261122-061649-02178 Low):

| quality | before | after |
|---|---|---|
| Medium | 335 / 436 / 5.8 | 300 / 435 / 2.5 |
| Low | 330 / 431 / 5.2 | 292 / 427 / 2.0 |

Ratchet: hub draws 520 -> 310 (Medium), 370 -> 300 (Low). Objects stay at 520 / 560. The M5 (gl_compatibility, which
counts more draws for the same scene) was not available to this job: its hub number is unmeasured since the 495 above.
Still over the 200 target: the partner's rig (37), the terrain and its far scenery (39), the Waystone (22), the stall
(20), the Nook (19), the portal (18) and the incubator's brazier and embers (42).

## Hub draws, second pass (ext/farm-hub-draws, 2026-11-23): 286 -> 270, target 200 not reached
Task: hub draws to 200 or less on rp2g. The 684 in the focus baseline (20261122-083514-a2) is the hub frame with the
screen UI at 1080p; the number `--perf-bench` judges (UI hidden) was 286 on rp2g at Medium (job 20261123-113739-18003).
- `--perf-bench --bench-hub` runs only the hub part (80 s; the full bench ran past the 20 min cap on rp2g).
- The owner list (`BENCH draw passes by owner`) now counts only what the camera sees and charges a mesh+material pair
  once, so it adds up to the draws (about 245 passes for 270 draws) and names each fixture by where it stands.
- Fix: the hub built a building-site model for every lot of Data.BUILDINGS; the side isles' lots always count as
  placed, so six of them (about 16 draws, 190 nodes) floated in the void. The hub holds no lots now (`Home._build_lots`):
  286 -> 270 draws, 530 -> 498 objects, 946 -> 759 nodes (jobq 20261123-114921-15080 vs 20261123-113739-18003).
- Tried and dropped: merging the far drifting rocks and islets into one mesh per material (`World._decorate`). They sit
  outside the view, so draws did not move (270 -> 272); reverted.
- What the 270 are (in view, passes): the partner's rig 35, Burrow 22, world scatter 21, Stall 20, Nook 17 and its
  Incubator 35, Waystone 26, portal and board about 25. Each fixture still draws one mesh per colour (two with the
  outline). The way to 200 is one mesh and one material per fixture (vertex colours in the toon material, shared
  outline), which changes how every fixture is painted; not started.
Ratchet: hub draws 310 -> 295 (Medium), 300 -> 290 (Low), with the margin rp1-0 counts above rp2g.

## Hub draws, third pass (ext/farm-hub-draws, 2026-11-23): 270 -> 178, under the 200 target
The way named above: one mesh per look, not per colour. `PaintMerge` (scripts/match/paint_merge.gd) merges a static
prop's unnamed toon parts as `Models.merge_static` does, but bakes each plain part's albedo into its vertex colours,
so parts that differ only in colour merge into one mesh with one shared material (`use_vertex_color` + `color_srgb`
in toon.gdshader: the colour stays sRGB in the vertex and is turned linear as the albedo is, so 8-bit vertex colour
loses nothing). Parts with their own vertex colours, a texture or markings merge as before.
- PaintMerged: the burrow, stall, Nesting Nook, Incubator (cradle, shelf, embers), the Waystone, the games board,
  the ferry post, the signpost and every decoration (`HomeBuild._sync_deco`: the house and the rest).
- Parts no code looks up lost their names so they merge: the burrow's door, frame, knob and window frames, the
  Waystone's ring, inlay, lock looks and the stones not owed a reveal (`ZoneReveal` only needs the owed stone and
  cap), the board's posts and tabs. The portal's eight runes and its feet share one material each.
- Kept apart: the burrow's squashed mound, turf and lantern. Merged, their normals turn with the squash
  (`MeshArrays.merged` turns normals by the basis, as SurfaceTool does) and they shade darker on top.
- No look change: the prop lineup (`--prop-draws-check --shots-dir`, 1600x600, GPU) differs in 7 pixels of 960k
  (mean 0.003 of 255), jobq 20261123-135435-01742 vs 20261123-135845-26509.

GPU rp2g (RTX 4090, forward_plus, 640x360, UI hidden), `--perf-bench --bench-hub --bench-farm=3`, draws:

| quality | before (jobq) | after (jobq) |
|---|---|---|
| Medium | 270 (20261123-134632-01773) | 178 (20261123-135904-19674) |
| Low | 260 (20261123-134523-26277) | 170 (20261123-135918-27216) |

Objects 381 -> 391 at Medium (named parts now merged count once; within 500). Props alone (`--prop-draws-check`,
GPU): stall L1 20 -> 8, L3 38 -> 18, nook 17 -> 7, incubator 171 -> 155, burrow 37 -> 16; the check holds them.
The hub meets its budget at both presets, so its ratchet entries are gone. What is left (in view, passes): the
partner's rig 35, world scatter about 21, the Waystone 9, Incubator 17, burrow 11. The M5 (gl_compatibility) was
not measured.

## Prop and building textures, close garden camera (ext/garden-prop-textures, 2026-11-28)
The garden buildings (house, stall, burrow, hub deco) are built from code with plain materials: no texture files, so
nothing there can be blurry or over budget. The textures the close camera does show are the props, the Boki, the
eggs, Hob and Pell, items and the look-locker dais. The 3D textures that were still lossless (the committed `.import`
files carried `compress/mode=0` with `detect_3d`, which never fires headless) are now VRAM compressed with mips.
`--texture-budget-check` failures: 414 -> 178 on this branch.

| group | textures | px (longest) | VRAM before -> after (MB, RGBA8+mips vs ~1 B/px, computed) |
|---|---|---|---|
| art/props chest, gust_fan, jump_pad, updraft_vent | 4 | 1024 | 22 -> 3 |
| art/kin (atlas, normal 2048; eye, face 256) | 202 | 2048 | 1832 -> 458 (all loaded; one Boki is ~46 -> ~11) |
| art/eggs | 17 | 512 | 24 -> 6 |
| art/npcs (Hob, Pell, their props) | 4 | 2048 | 48 -> 12 |
| art/items | 8 | 1024 | 45 -> 11 |
| art/look dais | 1 | 1024 | 6 -> 1 |

None is over the 2048 px source cap. Not touched (not garden): 126 UI icons (the check wants them lossless: add
`art/icons/` to its `UI_PREFIXES`), 12 mob and 40 warden Meshy textures (still lossless, hunters are art-sensitive).

Blurry up close, ranked for an art round (no gens here; texel density is source px over the model's width, so a
rough upper bound on an atlas): 1. `updraft_vent` 1024 px over 3.2 m, about 320 px/m, under the 512 px/m wall-sized
target (scene only: updrafts sit over the void, never close to the garden camera); everything else is at or over
512 px/m (jump_pad about 680, gust_fan about 790, chest about 880, eggs 512 px on under 0.5 m, Boki atlases 2048 px
on about 1 m). The 256 px eye and face maps are tiny patches on the Boki's head, fine.

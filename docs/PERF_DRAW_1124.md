# The fight's draw wait on a real GPU (11-24): what it is, and the plan

Owner focus 11-24: performance in game. The fight bench on main (job 20261124-022223-a1: avg 36-41 ms, p99 60-64 ms)
left the engine's draw wait, 7-18 ms of the frame, as the biggest open cost, after the script costs (PRs #790 and
#828 take fx_hunter_cap and the aim geometry). This profiles the draw on the pods' RTX 4090 and ranks what to do.

## How it was measured
`--perf-bench --bench-fight --bench-view=1920x1080 --quality=medium` through `jobq submit --needs gpu --only rp2g-0`
(RTX 4090, Vulkan Forward+, an X11 window on the pod's virtual display, vsync mode 1), eleven runs in a row on that one
worker: three baselines and eight probes, each a flag of the same bench. Noise on one worker: the baselines spread
1.7 ms on the wall p50 and 0.8 ms on the GPU. Jobs 20261124-062536-01125, -065103-15252, -071040-03157 (baselines),
-065534-28455 (shadows off), -065933-22122 (fx off), -070644-18792 (ink off), -070325-02927 (960x540),
-071827-05785 (960x540, 3D at 1080p), -072306-22026 (glow and FXAA off), -072830-31566 (LOD threshold 4 px),
-073233-10878 (HUD hidden).

New in the bench for this (ext/fight-draw-profile): GPU and CPU time between the renderer's own stamps (without the
engine's `--gpu-profile` flag, which jobq cannot pass, only the viewport's begin and end stamps exist, so the passes
are split by probes instead); the scene inventory `tools/perf/fight_scene.gd` (twice in the camp: things by class,
distinct materials and shaders, see-through surfaces and the screens their boxes cover, repeated mesh+material
pairs, meshes with and without LODs, each Hunter's meshes, surfaces, outline passes, casters and LODs); the probes
`--bench-nofx`, `--bench-noink`, `--bench-nopost` and `--bench-3d-scale=`; the display server and vsync mode in the
header.

## Numbers (ms per frame over the 1440 camp frames)

| run | wall p50 / avg / p99 | GPU (viewport) | render CPU | draw: before / viewports / after | process rest | draws | tris k |
|---|---|---|---|---|---|---|---|
| baseline 1 | 42.0 / 43.0 / 60.5 | 9.35 | 2.19 | 1.00 / 1.27 / 17.57 | 5.25 | 795 | 2887 |
| baseline 2 | 43.4 / 44.9 / 62.1 | 10.12 | 2.34 | 1.04 / 1.38 / 18.44 | 5.40 | 855 | 3267 |
| baseline 3 | 43.7 / 45.1 / 61.9 | 9.92 | 2.35 | 1.05 / 1.38 / 18.20 | 5.27 | 807 | 3022 |
| shadows off | 40.7 / 42.7 / 59.6 | 9.21 | 2.22 | 1.00 / 1.29 / 17.42 | 4.99 | 719 | 1679 |
| fx off (Fx and HeroVfx hidden) | 41.9 / 43.2 / 58.7 | 9.62 | 2.22 | 0.91 / 1.32 / 17.60 | 5.36 | 827 | 3270 |
| ink shells and far-ink passes off | 42.7 / 44.4 / 60.5 | 9.64 | 2.33 | 1.04 / 1.37 / 17.93 | 5.41 | 794 | 2492 |
| 960x540 window | 31.2 / 33.3 / 52.6 | 4.67 | 2.15 | 1.02 / 1.20 / 8.06 | 5.21 | 797 | 2669 |
| 960x540 window, 3D at 1080p (`--bench-3d-scale=2.0`) | 34.2 / 34.6 / 56.2 | 6.89 | 2.13 | 1.03 / 1.18 / 9.76 | 4.85 | 705 | 2488 |
| glow and FXAA off | 43.2 / 44.6 / 59.8 | 9.67 | 2.43 | 1.03 / 1.47 / 17.99 | 5.70 | 958 | 3718 |
| LOD threshold 4 px (2 at medium) | 41.6 / 41.6 / 62.0 | 8.65 | 2.21 | 0.97 / 1.31 / 16.76 | 5.01 | 751 | 2534 |
| HUD layer hidden | 35.7 / 37.6 / 53.1 | 8.43 | 2.11 | 1.01 / 1.18 / 16.18 | **1.38** | **457** | 3503 |

"draw: after" is the CPU time from the viewport's last renderer stamp to `frame_post_draw`: the frame end (swap and
present). It is the "draw wait" of the 11-24 report; "before" is the scene update and "viewports" the draw submission.

## What the draw wait is

**1. The frame end is the GPU and the window copy, in series.** `after` = GPU + 8.3 ms at 1080p in all three baselines
(17.6 vs 9.35, 18.4 vs 10.1, 18.2 vs 9.9) and GPU + 3.4 ms at 540p (8.1 vs 4.7); shadows off, fx off and ink off move
it by their GPU delta and nothing else. The pods present into an X11 window on a virtual display: the present waits
for the GPU to finish this frame and then copies the window through the CPU, about 4 ms per megapixel.
With the 3D kept at 1080p inside a 960x540 window the extra fell to 2.9 ms (9.8 vs 6.9): it follows the
window, not the 3D buffer. A real display with a swapchain runs the GPU a frame behind the CPU and copies nothing, so while
the frame is CPU-bound this wait is near zero there. The owner's PC on 11-11 fits (PERF_PLAN_1111: 25.9 ms frame, 13.0
script, 3.3 HUD, 4.1 render CPU, 7.3 GPU): the pods' 43 ms minus the 17.6 ms frame end is 26 ms. So the pods' wall
time overstates the fight by about 17 ms, and the 7-18 ms "draw wait" was never a cost a player pays. Compare GPU ms,
the script sections and the inventory between runs; read the wall only against another pod run.

**2. The GPU itself: 9.8 ms on the 4090 at 1080p**, 5.1 ms of which scales with pixels (4.7 ms at a quarter of them)
and 4.7 ms does not (vertices, draws, shadows, sky, the skinning and particle compute). By probe:
- Shadows: 0.6 ms, for 1.3M of the 3.0M triangles and 90 of the 800 draws (two splits, 660 casters: 264 flora chunk
  MultiMeshes, 227 World pieces, 112 skinned meshes, 58 Car, 46 Beacon, 42 Bars).
- See-through effects: 0.2 ms, within noise. The 125 see-through things' boxes cover 4 screens, mostly the train
  halts' beams (2 screens) and the cloud sea (1).
- The Hunters' ink shells and far-ink passes: 0.2 ms, within noise, for 0.5M triangles and 9 skinned objects. The
  outline shader discards every fragment past 18 match-metres (`far_cut`), and the fight camera is 35-57 m from every
  Hunter, so they are skinned, transformed and rasterised for nothing.
- Glow and FXAA: 0.1 ms, within noise (that run drew a heavier fight, 3.7M triangles, and still came out level).
- Materials and draws are not a cost: 157 distinct materials, 30 shaders, 331 passes at the quiet snapshot, 800
  draws, render CPU 2.3 ms.
- MultiMesh candidates: 59 copies of 8 tiny meshes (a Hunter's 0.1k bits, depth cues). The renderer already
  instances same-mesh copies (1379 objects become 800 draws). Nothing to gain.
- What scales with pixels, by elimination, is the opaque pass's fragment work: 2.2 ms between a 540p and a 1080p
  3D buffer in the same window (4.67 vs 6.89), so about 2.9 ms per 1080p screen. The terrain shader covers most of
  it with 11 value-noise reads, 2 fbm3 and cell functions per pixel; the cloud sea is a screen of 5-octave fbm; the
  Forward+ depth prepass shades the ground twice.
- The other 2.9 ms of the 1080p GPU (9.8 against 6.9 with the same 3D buffer in a quarter-size window) follows the
  window size through two things: the mesh LOD pick (Godot sizes the LOD threshold against the window width, so a
  quarter window picks coarser LODs: 2.5M triangles against 3.0M) and the HUD canvas at a quarter of the pixels.
  Split at 1080p: LODs picked at 4 px instead of 2 take 1.15 ms of GPU and 0.5M triangles (only the meshes that
  carry LODs can answer; the merged Hunter surfaces cannot, see 3); the HUD canvas takes 1.4 ms of GPU, 350 of the
  800 draws and 850 of the 1379 objects.

**4. The HUD is the engine's process cost, not the draw's.** With the HUD layer hidden the "process rest" of the
engine wait (the scene's own processing between the bench's step and `frame_pre_draw`) falls from 5.3 to 1.4 ms:
the HUD's draw callbacks run there every frame (CanvasItem redraws are deferred to the end of the process phase),
3.9 ms of CPU, the Tracy baseline's `hud_draw` 4.1 ms (docs/PERF.md). The pods' wall fell 7.3 ms. On the owner's
CPU-bound PC that is the largest single cost left in the frame after the sim.

**3. The Hunters' draw.** Each on-screen Hunter is 63-120k triangles (a 60k body, a 60k ink shell), 5-16 surfaces
with up to 12 outline next passes, 2-3 shadow casters, 24-85 bones. `WardenMerge._join` rebuilds a mesh with no LODs
(`add_surface_from_arrays(..., {}, fmt)`), so a merged Hunter keeps LODs on 1-6 of its surfaces and the rest draw at
full detail at 40 m and again in both shadow splits. The scene's meshes without LODs: 108 of 124 in view (241k of 539k
triangles), the biggest a Hunter's ink shell (44k), the sky train's track (31k) and the merged train-halt posts (70k).

## Ranked plan
Prove each with the same bench on one worker, 3 runs, reading the GPU column (noise 0.8 ms over three runs, so a
step under 0.5 ms shows only in the triangles, objects and inventory lines) and the "engine wait sections" line,
never the pods' wall. The owner's frame is CPU-bound at 1080p (about 26 ms of CPU against ~16 ms of GPU on a 4070
SUPER), so a GPU step pays on the owner's PC only at 1440p (GPU and CPU about even) and on weaker GPUs, where the
fight is GPU-bound; a CPU step pays everywhere.

| # | step | expected saving | risk | proof |
|---|---|---|---|---|
| 1 | **HUD draw**: the HUD's draw callbacks rebuild about 850 canvas items (350 draws) every frame: 3.9 ms CPU and 1.4 ms GPU (4090). Redraw only what changed: a plate or label keeps its shaped text (TextLine) and queues a redraw when its text, value or position changes; each plate group on its own CanvasItem with a dirty flag; the panels keep their 20 Hz. `hud.gd` is a god file: the logic goes to `hud_plate.gd`, `hud_panels.gd`, `label_cull.gd`. | 2-3 ms of CPU off the owner's frame (the largest cut left), 1-1.5 ms GPU on the 4090, 300 draws | medium: a stale plate. The HUD checks in `tools/checks/ui.gd`, shots at 1920x1080 and 390x844 | "engine wait sections: process rest" 5.3 to under 2.5 (the HUD-off run's 1.4 is the floor), "scene: draws" 800 to under 550 |
| 2 | **Pixel cost** (2.9 ms per 1080p screen on the 4090, ~5 on a 4070 SUPER, ~9 at 1440p; glow and FXAA are not it): split it with two probes next to `--bench-nopost` (the terrain shader's noise behind a `flat` uniform; the cloud sea hidden), then cut the biggest: the terrain's 11 noise reads down to 2-3 past 30 m from the camera (a distance fade in the shader), or the ground pattern baked to a texture per island at load; the sea's fbm at 3 octaves. | 1-2 ms GPU at 1080p and 2-4 at 1440p on the owner's PC; 0 on the pods' wall | medium: look. Before/after shots at the match camera and from the drop | GPU ms at 1920x1080 against 960x540 (the per-screen share shrinks) |
| 3 | **The Hunters' draw** (one job, one code path): (a) keep LODs through `WardenMerge._join` (build the joined mesh with `ImporterMesh.add_surface` + `generate_lods` + `get_mesh()`, cached per key as now, under the loading screen); (b) hide the ink shells and skip the far-ink next passes past 18 match-metres (the shader's `far_d`), from `Hunter.render` or `WardenGlb.Sync`. | 0.5-1.2 ms GPU on the 4090 (the 4 px LOD probe took 1.15 ms with only the LOD-carrying meshes answering), 1M triangles, 9 skinned objects and their skinning compute; more on weak GPUs | low: LOD popping on Hunters (2 px at medium, 1 px at high); nothing is visible past 18 m today, close-ups keep the ink by the same distance rule | hunter lines: "lods on N surfaces" = all, "+0 next passes"; tris -1M; GPU within noise on the 4090 |
| 4 | **Shadow casters**: flora chunk MultiMeshes cast only inside the shadow distance (36 m at medium) and small flora never; World pieces, Car, Beacon and Bars under `_merge_static` share one caster per chunk. | 0.2-0.4 ms GPU (4090), 0.5M triangles, 50 draws | low: flora shadows thin out past 36 m | the shadows-off run is the ceiling (0.6 ms); casters and tris in the scene line |
| 5 | Not worth a job (measured): see-through effect overdraw (0.2 ms), MultiMesh for repeated meshes (59 tiny copies), material and shader counts (render CPU 2.3 ms), glow and FXAA (0.1 ms), vsync (no effect on the pods, 11-24 report). | - | - | - |

## FIX JOB TASK
**(1) HUD draw, branch `ext/perf-hud-draw` from main.** The HUD's draw callbacks cost 3.9 ms of CPU and 1.4 ms of
GPU a frame in the fight (this doc: `--bench-nohud` took the engine's "process rest" from 5.3 to 1.4 ms, draws from
800 to 457, objects from 1379 to 500). In `scripts/ui/hud_plate.gd`, `hud_panels.gd` and `label_cull.gd` (the
world plates and labels; `hud.gd` is a god file, wiring only) make every piece redraw only when its text, value or
position changed: keep one TextLine per plate and reuse it, give each plate group its own CanvasItem with a dirty
flag and `queue_redraw` on change, keep the panels' 20 Hz. Prove it with 3 runs each on main and on the branch of
`jobq submit --needs gpu --only rp2g-0 --tree <tree> --out fight -- --perf-bench --bench-fight
--bench-view=1920x1080 --quality=medium`: the "BENCH fight engine wait sections ... process rest" value must drop by
at least 2 ms and "BENCH fight scene: draws" by at least 200, with the HUD showing the same things (shots at
1920x1080 and 390x844 before and after, every HUD check in `tools/checks/ui.gd` green, `tools/health.py --strict`).
Never read the pods' wall time: it carries an X11 window copy of about 8 ms at 1080p and the GPU in series.
**(2) Ground pixels, branch `ext/perf-ground-pixels` from main.** Add two probes next to `--bench-nopost` in
`tools/perf_fight.gd`: `--bench-flat-ground` (a `uniform bool flat` in `shaders/terrain.gdshader` that returns the
base colour before any noise) and `--bench-nosea` (the World's cloud-sea plane hidden). Run each 3 times at
1920x1080 and read "BENCH fight cpu: ... gpu" (noise 0.8 ms over 3 runs; baseline 9.8 ms on rp2g-0). Cut the bigger
one: the terrain's noise reads down to 2-3 past 30 m from the camera (fade by `d` in the shader), or the ground's
pattern baked to a texture per island at load; the sea's fbm at 3 octaves. The bar is GPU -1 ms at 1080p on the
4090 with before/after shots at the match camera and from the drop that the owner can tell apart only side by side.
Open each as its own PR and drive its gate.

## Result of step 2, ground pixels (11-24, ext/perf-ground-pixels)
Separate pod runs of the same build spread 2.5-9.5 ms of GPU (the pod's other jobs share the 4090), so the probes were
read inside ONE run: `--bench-ab-ground` cycles four variants in blocks of 45 frames over the same fight and averages the
GPU of each (`tools/perf/ground_ab.gd`). Three runs at 1920x1080 medium on rp2g-0, GPU ms (old = the terrain as before):

| variant | run 1 | run 2 | run 3 | mean vs old |
|---|---|---|---|---|
| old (9.8 / 9.7 / 10.1 ms) | 0 | 0 | 0 | 0 |
| terrain noise off (`flat_ground`) | -1.33 | -0.87 | -1.13 | **-1.11** |
| cloud sea hidden | -0.29 | -0.09 | -0.49 | -0.29 |
| the cut (fine detail fades over 14-36 m, 4 of 8 contact directions far out) | -0.49 | -0.52 | -0.47 | **-0.49** |

So the ground is the bigger cost (1.1 ms: its whole shader, noise and contact shade), the sea is 0.3 ms at most. The cut
takes about 45% of the terrain's ceiling; the other half is the big painted patches and the height reads, which are the
look. The plan's bar of -1 ms is the ceiling of removing the ground's pattern altogether, so it is not reachable without
changing the look; a first cut (fade 28-55 m) gave only -0.1 (four runs). A bake of the big patches to a texture per
island is the next step (about 0.3 ms more at best).

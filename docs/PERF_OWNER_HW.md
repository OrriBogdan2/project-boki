# Performance on the owner's own machines (owner order 11-10)

The target, in a real match at default quality:
- PC: median 16.7 ms or lower, p99 33 ms or lower.
- Mac M5: median 25 ms at most (16.7 if it can be reached), p99 40 ms or lower.
- No frame over 100 ms after the reveal.
- Loading under 15 s.
- Auto quality picks a preset that meets this on each machine.

Every number below comes from the owner's own machines as jobq GPU workers (`--only pc-MRROBOTO`, `--only
mac-Naruto-Founder`). None comes from RunPod.

## How it was measured
- **Real match**: `--perf-bench --bench-real --bench-teams=10 --bench-squad=2 --bench-view=1920x1080 --bench-secs=60
  --bench-warm`.
  - A full 20-Hunter match with every Boki, the storm and the Blight, and a fight brought to you at 8 s.
  - The match runs its own loop on the real frame time, so catch-up steps count.
  - `--bench-warm` (new) runs the loading screen's warm-up and the auto-quality pick first, as a player's match
    has them. Without it, the first draws compile shaders mid-run: the Mac's "worst frame" was 1.5-1.8 s of that.
  - The "before" rows ran without the warm-up, at Medium (the adapter guess). Their medians compare fairly; their
    worst frames include those compiles.
- **Hitches and auto quality**: `--hitch-check` (an 18-Hunter expedition as a player gets it: loading screen,
  warm-up, auto-quality benchmark, ride, drop, landing next to a monster pack). Its ride and drop fast-forward the sim
  6 and 3 steps a frame on purpose, and leave those steps out of the judgement, so the "+142 ms x6" lines are that
  fast-forward, not a spiral in play.
- **Loading**: `--warm-twice --hitch-check --load-check` (a first launch from an empty user dir, then a second
  launch).

## PC: RTX 4070 SUPER (pc-MRROBOTO), window 1920x1080

| | median | p99 | worst frame | loading (1st / 2nd launch) | auto preset |
|---|---|---|---|---|---|
| before (release-integ-0244) | 61.3 ms | 136.7 ms | 699 ms | 23.4 s / - | **Low** (benchmark 43.9 ms) |
| after (this branch, train included) | 27.7 ms | 60.7 ms | 106 ms | 16.4 s / 9.9 s | Medium (3.7-7.4 ms GPU) |
| + layered warm-up (fix 5) | 31.7-38.3 ms | 62.5-74.7 ms | 89-117 ms | **13.5 s** / 10.0 s | Medium (5.8-9.8 ms GPU) |

The PC's real-match numbers moved between runs this afternoon on the same sim code: the old code measured 29.8 and
34.9 ms medians (p99 78.3 and 66.5, worst 136 and 132) in the same hour as the three runs in the last row. The
warm-up adds nothing to a frame in play (script, render and GPU times are within that spread). Read the medians as
"about 30-38 ms on this PC today". The PC's cold-cache hitch-check had 0 shader compiles in play (PASS, worst judged
frame 71 ms).

Hitch-check (18 Hunters, 1280x720): the landing phase went from a 56 ms median and a worst frame of 169 ms (10 frames
over budget, FAIL) to a 23 ms median and a worst frame of 65 ms (PASS).

## Mac: Apple M5 (mac-Naruto-Founder), window 1920x1080

| | median | p99 | worst frame | loading (1st / 2nd launch) | auto preset |
|---|---|---|---|---|---|
| before (release-integ-0244) | 36.5 ms | 118.5 ms | 1535 ms | 23.6 s / - | **Very Low** (benchmark 58.4 ms) |
| after (this branch, train included) | 22.8 ms | 42.7 ms | 108 ms | 23.3 s / 22.4 s | Medium |
| round 2 (old warm-up kept, fix 5) | 23.3 ms | 41.7 ms | 113 ms | 21.9 s | Medium |
| (fix 5 layered, tried and dropped) | 24.4 ms | 55.7 ms | 131 ms | 16.0 s / 15.3 s | Medium |

Hitch-check: the landing phase went from a 34 ms median and a worst frame of 91 ms to a 28 ms median and 93 ms
(PASS both times).

## Fixes, each with its before and after on the owner's hardware
The perf train (ext/perf-train-0245, merged here) did most of the sim work: Boki and far bots think less often, the
hot paths are cleaner, and an offline frame catches up at most 3 steps. Its own doc is docs/PERF_TRAIN.md. On top
of it, this branch adds:

1. **Auto quality picked far too low, on both machines.** The loading benchmark timed whole frames of the skyship's
   view of the whole map: about 2,700 draws, loading work still running, the heaviest view in the game. The PC
   (RTX 4070 SUPER) got Low and the M5 got Very Low, so both looked worse while the frame cost (CPU, not GPU)
   stayed the same.
   - Now it times the GPU (`viewport_get_measured_render_time_gpu`) on the landing ground at play's camera height.
     It steps down past 14 ms of GPU.
   - Where the driver has no GPU timer (the Mac: GL over Metal reports 0), it times whole frames with 1.75x the
     room.
   - `video_v` 6 makes an old auto pick get measured again.
   - PC: Low (43.9 ms) → Medium (7.0-7.9 ms GPU). Mac: Very Low (58.4 ms) → Medium (8-22 ms whole frame).
   - `--quality-check` covers the steps.
2. **Glider sounds were synthesized mid-drop.** `Gliders.sound` builds each skin's open and close sound sample by
   sample in GDScript the first time a Hunter opens a glider: 25-60 ms in one sim step, several times in the drop.
   They are now made behind the loading screen (`Gliders.warm_sounds` in WarmUp).
   - PC hitch-check, landing at Low on both sides: worst frame 169 → 104 ms, landing stall 135 → 60 ms, land median
     56 → 47 ms.
3. **HunterPace** (decision 0048; replaced in ext/perf-owner-hw-rebased by main's SimLod, decision 0022, which
   steps far, calm bots at 20 Hz from 45 m, so the numbers below are HunterPace's, not re-measured): offline, a bot Hunter more than 60 m from you that is grounded, not fighting and
   not hit in the last 3 s runs its sim every 2nd step, with the skipped time added. It is the Hunter version of the
   train's KinPace.
   - PC real match: Hunter sim 9.49 → 6.71 ms a frame, median 37.1 → 30.3 ms, p99 91.3 → 71.4 ms (both without
     `--bench-warm`).
   - Mac real match: median 26.2 → 23.6 ms.
   - `--perf-throttle-check` covers the rule.
4. **Measuring tools**: `--bench-warm` and the median and worst frame in perf-bench's summary.
5. **Layered warm-up, PC only** (round 2). The loading warm-up drew each material's stand-in under 4 light setups
   one after the other, 2 frames each: 8 frames a batch. Now each stand-in is drawn 4 times at once, each copy on
   its own render layer, and the warm-up's omni and spot lights reach only their copies through their cull masks.
   A batch is 1 frame, and it stays up for the next batch's frame too (a new stand-in meets its lights a frame
   late; with 1 frame alone, two thirds of the variants waited for play).
   - PC first launch: loading 16.4 → 13.5 s, warm-up stand-ins 7.4 → 4.1 s, 0 compiles in play (cold cache).
   - On the Mac it cut loading 23.3 → 16.0 s (15.3 s on the 2nd launch), but cost play: in 3 hitch-check pairs, the
     drop had 57-76 frames over 50 ms against 4-19 with the old warm-up, and the real match's p99 went 42.7 → 55.7 ms
     (render CPU 9.3 → 11.2 ms). Apple's GL over Metal keeps no shader cache and seems to finish the work in play.
     So the Mac keeps the old, toggled warm-up (`WarmUp._layered`).

My catch-up cap (3 steps a frame) was dropped when the train came in: its `DashPace.CATCH_UP_S` already does the same.

## Cuts, and what they cost visually
None. No preset, effect, light or Hunter count was cut. The presets are unchanged. The only visual change is that
auto quality now picks Medium on both machines instead of Low / Very Low, which is a gain.

## Where the targets stand, and what is left
- **PC median 16.7 / p99 33: not met** (27.7 / 60.7 ms). The frame is CPU-bound: the sim is ~19 ms of script a
  frame for 20 Hunters (`Hunter.sim` 6.6, bots 2.2, Boki 1.8, pickups 1.7). The GPU takes 8-9 ms. A preset can't
  fix this; Low would only cut the GPU share, which is already in parallel. With 12 Hunters the same PC runs a
  21.0 ms median and 40.3 ms p99.
- **Mac median 25: met** (22.8 ms). **p99 40: close** (42.7 ms). The Mac's sim is fast (7 ms); its frame is
  render CPU (10.5-11.5 ms, GL translated to Metal) plus driver stalls in the fight. Low is no better: median
  23.4, p99 75.5.
- **No frame over 100 ms: met in the hitch-check on both machines** (worst 65 ms on the PC, 93 ms on the Mac).
  **Not quite met in the 60 s real match.**
  - PC: four frames of 100-106 ms, all script. One step's Hunter sim takes 30-70 ms in the fight, when an effect is
    used for the first time and builds its meshes.
  - Mac: frames up to 108 ms, all driver time (script ~12 ms, render CPU ~10-13 ms).
  - The fight creates about 2,100 MeshInstance3D nodes (effects made per use, `BENCH created in the fight`).
    Pooling those, as the train's FxPool does for rings and beams, is the next lever for both.
- **Loading under 15 s: met on the PC (13.5 s on a first launch, 10.0 s after), not on the Mac (22-23 s every
  launch).**
  - The Mac's GL driver keeps no shader cache: Godot's `user://shader_cache` stays empty, so WarmStamp never
    trusts it, and every launch compiles all ~110 materials x 4 light setups again (15 s of the 22).
  - The PC's first launch compiles about 325 variants (4 s since fix 5).
- **Where the PC's frame goes** (round 2, timed section by section on a local build, so shares, not PC ms): the
  Hunter sim is spread thin. The class kits' per-step tick is the largest part (35%), split over every kit at
  0.1-0.3 ms each; movement and collision is 25%. The HUD costs 3.5 ms a frame on the PC: world labels ~1 ms every
  frame, the panels (already drawn 20 times a second) ~1.5 ms on average. Other nodes' own processing is ~1.7 ms.
  No single cheap fix is left. The 60 fps target on this PC needs fewer Hunters or a rewrite of the sim's hot
  paths, not a setting.
- **Rendering on its own thread** (`--render-thread separate`) would take render submission off the main thread. With
  the Compatibility renderer it crashes at start (Godot 4.6 warns it is unstable), so it is not an option.

## For the owner to decide
1. **Hunter count.** The PC can't hold 60 fps with 20 Hunters on its CPU. I did not change the count, because it is
   gameplay. The measured case on your PC (real match, Medium):

   | Hunters | median | p99 |
   |---|---|---|
   | 20 | 27.7 ms | 60.7 ms |
   | 12 | 21.0 ms | 40.3 ms |

   - The alternative that keeps 20 is more sim LOD: far Hunters at 20 Hz (HunterPace `FAR_EVERY` 3), or 30 Hz at a
     shorter distance. It is cheap to try, but far bots' movement gets coarser.
2. **Mac loading (22 s every launch).** The options:
   - (a) Accept it.
   - (b) Warm only the no-light and omni-light variants on the Mac (about half the time). The sky train's headlight
     would then compile once, mid-match, the first time it sweeps an island.
   - (c) Fewer distinct materials. This is an art and tech pass.
   - (d) Run the Mac on Godot's Metal renderer (Mobile or Forward+) instead of GL over Metal: a pipeline cache that
     lasts between launches. It is a renderer change for the Mac build, with its own look and perf to check.
   - The faster warm-up the PC now uses would make it 16 s on the Mac, at the cost of slower frames in play (fix 5).
3. **Mac texture format**: 86 textures are BPTC (101 imports have `compress/high_quality=true`, mostly the Boki
   and warden art), which the M5's GL doesn't take. They are decompressed at load
   (more load time and 4x their VRAM). The fix is `rendering/textures/vram_compression/import_etc2_astc=true` and a
   reimport of every texture: a large asset change, so it is not done here.

# A Boki body from Meshy (the scan recipe)

A rigged Boki's body used to be Blender primitives (`tools/boki/<species>.py`). This recipe replaces the body with a
Meshy model of the owner's turnaround sheet and keeps everything else the species already has: skeleton, 13 clips,
emoting face, tools, grown parts, marks. Pilot (11-09): Kestrike (`kestrike`), Cairnback (`cairnback`), Gongibbon
(`gibbelle`). The rig contract is `RIGGED_BOKI.md`; this page is only what is new.

Since then (11-13): Effigeetle (`goliathite`) and Skateron (`hoarheron`), both on Gongibbon's borrowed glomwort rig
with every lobe merged to root, so the body rides the root's bob and turn. Tried and dropped: Knotwyrm (`threadwyrm`),
whose scan's head sits off the midline and tilted, so the face (mirrored about x=0) lands one eye per view. Soakybara
(`lilybara`) waits too: its Meshy model has 6 materials and only one carries a texture, and the loader reads one.

What one species ends as: a body of 16,000 triangles (the whole model 18-19k with face, tools and grown parts), a
2048 colour atlas and a 2048 normal atlas baked from the dense model, in `art/kin/<id>/` (about 2-3 MB).

## Cost per species

| Step | Meshy credits | Time |
|---|---|---|
| Crop the sheet into 4 views | 0 | 1 min |
| Take effects off a view (only where the sheet draws sparks, sound rings, dust) | 0 with a colour key, 9 per `edit` call | 1-10 min |
| `create` (multi-image, best settings) | 40 | 3 min (170-193 s in the pilot) |
| Fit sheet, measure, fill the `SCANS` row | 0 | 20-40 min of a worker, 2-3 builds |
| Build, import, check, shots | 0 | 3-5 min a build, shots 3 min on the GPU worker |

The pilot spent 165 credits on three species: 3 x 40, and 45 on five `edit` calls that took the sound rings off
Gongibbon. Budget 40-85 a species, one run; a second run (40) only when the first is broken (a missing limb, a
fused pair of legs).

## 1. Views

    git show origin/ext/agent-briefs:briefs/boki-art/turnarounds/<Name>.jpg > ~/meshy/boki/<id>/sheet.jpg
    echo '{"auto": ["front", "tq", "side", "back"]}' > auto.json
    python3 tools/meshy/sheet_crops.py ~/meshy/boki/<id>/sheet.jpg ~/meshy/boki/<id>/crops auto.json

Look at the four crops. Meshy models everything it sees, so a view must show the animal only: no sparks, rings,
dust, ground shadow or label. A flat-coloured effect comes off with a colour key; one that overlaps the body needs
`python3 tools/meshy/meshy_task.py edit OUT view.png --prompt "remove the <effect>, keep the animal exactly"`
(9 credits, check the result still matches the sheet). Never feed anything but the owner's own sheets.

## 2. Meshy

    python3 tools/meshy/meshy_task.py create ~/meshy/boki/<id>/run1 crops/front.png crops/tq.png crops/side.png \
        crops/back.png --pose ""

The defaults are the best settings and the ones the pilot used: `multi-image-to-3d`, `meshy-7.1`, geometry `2k`,
texture model `meshy-7` at `8k`, PBR on, no remesh (the dense mesh is the bake source: 0.46-0.98 million triangles,
a 42-80 MB glb), image enhancement on. `--pose ""` keeps the sheet's own stance (the A-pose default is for
Wardens). The run directory holds `glb.glb`, `tex0_base_color.png`, the thumbnails and `task.json` (id, credits). It
stays outside git; the build reads it from `~/meshy/boki/<id>/run1`. Look at `thumbs.png` before going on.

## 3. The species row

The scan rides the species' existing modules (`SPECS` in `build_boki.py`); a species with none borrows the nearest
rig, as Gongibbon borrows Glomwort's. Add a row to `SCANS` in `tools/boki/boki_scan.py` with `height` (game metres
before `SCALE`, as the proxy stands) and `tris` (16000), then print the fit sheet:

    B=~/tools/blender-4.5.15-linux-x64/blender
    $B -b --factory-startup --python tools/boki/build_boki.py -- --species=<id> --no-export --fit-sheet=/tmp/fit.png

It draws the scan from the side, front and top with a 5 cm grid and the proxy's bones and eyes laid over it. Read
off landmark pairs (proxy coordinate, scan coordinate) where the two disagree: ground, belly, shoulder, crown on
`y`; nose, neck, hip, tail tip on `z`; half-width on `x`. Three to six pairs an axis is enough. Then, as needed:

| Key | When |
|---|---|
| `merge` | The scan fused a part into its neighbour (folded wings, horns, ears): the part's bone gives its weights away |
| `drop` | A proxy piece the scan has no shape for (a spark, a puff) |
| `eye_c`, `eye_r`, `eye_yaw` | Where the Boki face goes: read the scan's own eyes off the fit sheet |
| `cover` | The scan's own painted eye shows beside the Boki eye (an off-centre head, a wide eye): the coat inside `cover` eye radii (1.2) takes the colour on that ring |
| `sink`, `pose` | A part hangs below the feet (a tail): lower the scan by `sink`, lift the bone in the rest pose |
| `limbs` | A part the fit cannot follow: a capsule along it, in scan space, that takes the bone and its weights |
| `at` | A grown part lands wrong: its attach point in scan space |
| `sat`, `gain` | The texture's grade, baked into the atlas. Start at `sat` 0.7: see below |
| `lid`, `brow` | Hex colours for the eyelids and brows, only when the build's own pick is wrong: it takes the scan's graded colour in a ring round each eye (lids) and just above it, darkened (brows) |

The game's warm light and tonemap push a painted texture's mid colours to pure hues (Kestrike's rust came out
signal red, its slate deep blue), so every scan needs `sat` below 1: it pulls each texel toward its own grey in
linear light, exactly as the coat shader's `desat` would. The pilot settled on 0.6 for Kestrike (strong reds), 0.8
for Cairnback (with `gain` 1.15, its browns were dark) and 0.8 for Gongibbon. Judge it on the engine shots beside
the sheet, never on the atlas.

Run the same command again: it ends with the `BokiRig.FRAME` row (head, top, carry, marks) through the fit. Paste
it into `scripts/match/boki_rig.gd`, add the id to `SPECIES_LIST` in `tools/boki_rig_check.gd` and to the scan
names beside `MESHY_TRIS` there.

## 4. Build and look

    $B -b --factory-startup --python tools/boki/build_boki.py -- --species=<id> --blend=/tmp/<id>.blend
    godot --headless --path . --import
    godot --headless --path . -- --boki-rig-check
    $B -b /tmp/<id>.blend --python tools/boki/pose_shots.py -- /tmp/<id> idle:0 walk:6 attack:8 carry:10 --views=s,q

The first build decimates the dense mesh (cached beside it) and bakes colour and normals from it. `pose_shots.py`
shows the skinning in seconds: look for a limb that drags its neighbour (move a landmark or add a `limbs` capsule),
a tool inside the body (`at`), eyes off the head (`eye_c`). Then the real pictures and the cost, on the GPU worker:

    jobq submit --tree . --needs gpu --only rp2-1 --app godot --timeout 900 --out shots -- -- \
        --boki-rig-shots --shots-dir=res://shots --species=<id>
    jobq submit --tree . --needs gpu --only rp2-1 --app godot --timeout 900 --out cost -- -- \
        --boki-cost --sets=cindle,puddlet,zapple,pebbit/<id>,<id>,<id>,<id> --shots-dir=res://cost

`--normal-k=0` on the shots leaves the normal map out, for an A/B. Compare runs from one worker only: the Mac
renders brighter and slower than the Linux workers. GPU jobs are taken by `rp1-0`, `rp1-1`, `rp2-0`, `rp2-1` (RTX
4090), the Mac and the PC; `rp1-2` and `rp2-2` never take one, and a worker can sit 20 minutes under another
session's benchmark, so pin (`--only`) to one that just finished a job (`jobq status`).

Unused tools collapse at the point deepest inside the scan (the build finds it), so their ink shell never shows as a
speck beside the body. Look for one anyway on `turntable.png`.

## What it costs to draw (pilot, RTX 4090, 1920x1080, match camera, vsync off, two hunters in frame)

| Bokis in frame | Triangles in frame | Draw calls | Frame, median (p95) |
|---|---|---|---|
| none | 50,632 | 36 | 4.1 ms (5.4) |
| 4 primitive rigs (Vespyx, Prismander, Echolop, Gravadillo) | 83,597 | 56 | 6.04 ms (7.47) |
| 4 scans (Kestrike, Cairnback, Gongibbon, Kestrike) | 169,832 | 56 | 6.08 ms (7.50) |
| 32 primitive rigs | 248,422 | 156 | 9.6 ms (11.0) |
| 32 scans | 765,832 | 156 | 10.6 ms (11.6) |

A scan adds about 21,000 triangles to the frame over a primitive rig (its 16,000 drawn again by the shadow and ink
passes) and no draw calls. At the four the game shows, the frame time is the same within the run-to-run noise (a
second worker measured 5.21 against 5.19 ms); at 32 it is within a millisecond either way (9.6 against 10.6 on one
run, 7.4 against 6.3 on another). On the Mac (Apple M5, the compatibility renderer) four primitive rigs take 10.4 ms
and four scans 10.1 ms: there too the cost is the skinned rig and its passes, not the triangle count. No low-end PC
has been measured.

## What it does not do yet

- Wings, ears and horns that the scan folds against the body move with the body (no flap, no ear twitch). A species
  whose clips live on such a part needs the sheet's part cut apart first, or stays on primitives.
- A species on a borrowed rig moves as that rig does: Gongibbon bobs, turns its head, emotes and holds tools, but its
  arms and legs do not swing. Full limbs need its own `<species>_anim.py` (bones and clips), then a rebuild.
- Fusion forms (`build_fusion.py`) keep their primitive parts.
- Meshy's texture carries the sheet's painted light; the toon ramp flattens most of it, `gain` and `sat` the rest.

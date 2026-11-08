# Kael (juggernaut; was Zedran): import note, stage 1 (2026-11-04)

`kael.glb` is Kael's stage-1 model (INBOX_S2 09:20, 09:30, 10:00/10:15): a hybrid. The body is one Meshy 7.1 run
baked to a clean low-poly and fitted to the Warden contract; the greatsword, the Warchain with its hook, the left
cuff's broken chain and the long mane are built by script in Blender (tools/meshy/kael_parts.py). **No hand polish**
(stage 2): no paint-over, `lift` neutral, no per-Warden shader. Raw files in ~/meshy/zedran/. Run log:
docs/art/wardens/PIPELINE.md.

    BP=~/tools/blender-4.5.15-linux-x64/4.5/python/bin/python3.11; B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    $BP -I tools/meshy/kael_crops.py tools/meshy art/zedran_turnaround.png ~/meshy/zedran/crops
    python3 -I tools/meshy/meshy_task.py edit ...  (x4; prompts in ~/meshy/zedran/edit_*/request.json)
    $BP -I tools/meshy/kael_prep.py tools/meshy ~/meshy/zedran
    python3 -I tools/meshy/meshy_task.py create ~/meshy/zedran/runA in/front.png in/tq.png in/side.png in/back.png \
        --texture-refs in/front.png in/tq.png in/side.png in/back.png --enhance off
    $B tools/meshy/bake_warden.py -- art/wardens/src/kael_bake.json
    godot --headless -- --warden-rig-json --warden=juggernaut       # -> art/wardens/src/kael_rig.json
    $B tools/meshy/fit_warden.py -- art/wardens/src/kael_fit.json

- **Art:** generated from wardens_r3/zedran_* (the final kael_* came after the run): the same body, outfit and
  pieces, the glow white-hot instead of orange. The body is reused; the glow is a game-side colour (below).
- **Inputs:** each of the four views edited once: the greatsword, all chains and both hooks out, his right hand
  hanging empty, the long mane cut to the nape (it is built as geometry). Nothing mirrored.
- **Body:** 979k -> 30k triangles (head 9k), 4096 atlas. Archetype body: size 0.955, head 0.62, legs 1.55,
  neck -0.02, build 0.95. Bone heat found no solution on the scan (skirt plates and scarf pass through each other):
  fit_warden now runs it on a 12 mm voxel proxy and transfers the weights back.
- **Glow (white-hot, switchable):** the right arm's faces (box `hot_boxes`) go on `<slot>-body-hot` copies of their
  materials; hero_toon's `glow_key` lights only the atlas's hot texels there (the rest stays skin). Every glow piece
  (the arm's cracks, the blade's cracks, the hook's tip) takes `model_glow` {core, edge} from
  content/archetypes/juggernaut.json (core #fffaf0, edge #f2d48a), so orange or white is one edit, no rebake.
  Sparks and the black demon smoke are VFX.
- **Greatsword (weapon):** scripted slab with chipped edges and the art's jagged broken tip (from the front and 3/4
  views), bevelled edges, two iron bands, a bar guard, a wrapped grip with chain links round it, cracks down both
  faces as `glow-sword` over `glow-sword_edge` ribbons; built to the procedural greatsword's frame, x0.55 (the heavy
  Gun scale 1.42 sits on top).
- **Warchain:** links wrapped round the right forearm (rigid on forearm.R), then from the wrist by the hilt down to
  ONE heavy hook with a hot tip, on `spring_hangwarchain_*` bones under hand.R. A `hang` chain (new in
  WardenGlb.Springs) settles straight down from its root whichever way the arm points.
- **Left wrist:** the scan's iron cuffs plus a short broken chain (three links and a split one) on
  `spring_hangcuff_*` under hand.L. No second hook.
- **Mane:** 26 chunky tapered locks rooted in the scan's short hair, draped clear of the body, in five groups
  (back, left, right, front-left, front-right), each on a `spring_mane_*` chain under head; `hair-mane` takes the
  ink line (INK_TAGS).
- **Scarf:** always on (the scan's own).
- The pieces share a small 256 px colour atlas (`kael_parts_atlas`), one cell per colour.
- `kael.glb.import`: `generate_lods=false`, `force_disable_compression=true`; atlases lossless.

## Stage 2 (2026-11-04, the Vex r3c recipe + the 12:40 sheets; credit-free)
- **Slots:** the red rule tightened (dark red-brown skin was landing on cloth and took the red ramp); the harness's
  grey-brown straps are on leather (no skin tint).
- **Paint-over:** `smooth`, `ramps` of the art's colours (skin, red, leather, gold, iron, hair), `despeckle`;
  `project_late` of the front art over the face and chest. The skin ramp stops below the cracks' brightness, so the
  arm's red-orange crack rims become skin and only the hot cores light, white-hot.
- **Blade** (kael_blade_sheet; its pommel hook ignored): a long slab with a crenellated broken end, dark stone-iron
  edges, the WHOLE core a broad white-hot channel with thin cracks off it, chain wrapped round the blade's base and
  the grip. The pieces' atlas now holds sRGB colours (stage 1 stored linear values: everything read near-black).
- **Glow:** `model_glow` gains `strength` (2.4); content/rules/warden_look.json `kael` (skin and cloth up at the
  match camera, glow 2.6).
- **Mane** (kael_head_sheet): 48 wider, softer, wavy locks in layers past the shoulders, five spring chains of five
  bones; no ink line on them (it drew every lock as a strip).
- **Stance:** content/rules/warden_stance.json juggernaut: the greatsword hangs in his right hand down across his
  front (the turnaround), the blade's face turned up so its glow reads from the match camera; the chest less
  thrown back, the left arm hanging. Archetype size 0.975 (the sheet height with the new stance).

## Stage 3 (2026-11-04, after the shared painted-look fix 16c18b4f; credit-free)
- The shared look fix cherry-picked (the shader conflict kept both the glow heat key and the own ambient);
  warden_look.json `kael` retuned down on top of it.
- **Arm cracks** (kael_arm_sheet): `hot_paint` grows the arm atlas's hot texels and paints them a warm core the
  shader keys fully hot (lit in the white-hot model_glow), with a duller rim it keys as the pale-gold edge.
- **Collar** (kael_collar_sheet): a scripted broken gold band round the neck base, split at the front, dark rims,
  lower at the front than the nape (kael_parts.collar).
- **Mane:** 36 wider locks (roots lying flat on the scalp, turning out to hang), five spring chains.
- **Blade:** faint zigzag crack lines inside the white-hot core.

## Clips (2026-11-08, KIT_PARITY gap 1)
- **Clips:** the first Kael's 49 hand-keyed clips (ext/art1-kael-2, tools/art1/kael_clips.py, timed to the footage
  frames and the kit's jug_* keys) ported by bone name with tools/art1/kael_retarget.py: rotations as they are (both
  rigs share every rest rotation), the root's motion scaled to the shorter legs (hips 0.651 m, the first's 0.878);
  content/rules/warden_anim/kael.json maps the kit moves. `--clip-check` asserts the slam strikes on footage frame 0158
  (0.6 s) and a slash inside its two frames.
- **Greatsword:** the `weapon` mesh is skinned whole to hand.R along the first Kael's blade (its guard on
  `anchor_blade_root`, its point on `weapon_muzzle`, both new under hand.R), at the size it was held (x1.21), so
  the clips swing it; warden_look `weapon_scale` goes and the blade's bloom runs root to point.

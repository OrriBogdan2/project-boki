# Pip / Meeko (tender): import note, v95 swap of Meeko appeal3, body b (2026-11-10)

**11-13 (ext/showcase-1113):** `pip.glb` is now Meeko's current master (`~/meshy/v95/Meeko/r2/n95/best.glb`, current.json), the same recipe below on `best_nocomp.glb` (its body `Mesh_0` and wings `model_part0`/`model_part5`; the master's sun and cloud stripped). Its wings sit on their own textured material, which needed bake_warden's per-material colour bake. 14,293 tris.

`pip.glb`: the owner's pick (11-10), Meeko v95 r2 appeal3 `cand_b.glb` (the appeal3 face; body widened 7% at the torso and
hips), swapped onto Pip's own skeleton, 45 clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/pip_v95.json`, then the sun and raincloud put back by `tools/art1/pip_companions.py`. Raw files in
~/meshy/v95/Meeko/r2/appeal3 (never in git); the spec reads `meeko_v95_b_body.glb`: `cand_b.glb`'s body (`Mesh_0`) and its
two back wings (`model_part0`, `model_part5`), without the master's own sun and cloud (the game's are pip_companions.py's).

    B=~/tools/blender-4.5.15-linux-x64/blender
    $B -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/pip_v95.json WORK WORK/pip_swap.glb
    $B -b --factory-startup --python tools/art1/pip_companions.py -- WORK/pip_swap.glb art/wardens/pip/pip.glb art/wardens/pip/pip_faces.png

14,293 triangles: the body 13k (head 4.4k) on one 2048 atlas (Godot extracts it to `pip_atlas.jpg`), the companions 1.3k on
flat colours and the 2048x1024 face atlas (`pip_faces.png`, unchanged). Materials: skin-atlas, skin-face-atlas (the head box:
warden_look's `skin-face` look), cloth-atlas (the wings, the capelet), leather-atlas (satchel, strap, pouch), brass-atlas
(the goggles), then cloth-sun, skin-cloud, ice-drop, eyes-mood_sun, eyes-mood_cloud.
Weights: bone heat from the spec's joints; the tail rides `tail` whole, each wing `wing.R`/`wing.L` (their keyed flutter),
the satchel and pouch `hips`, the head box `head`, the ear tips `ear.R`/`ear.L`. The arms stretch to the rig's arm length.

Lost from the v2 build (scans plus scripted arms, hands, lids and wings: replaced, not merged): the lids (blinks no longer
show; `lid` bones move nothing), the emission layers (the constellations are paint now; PipStars.pulse finds no emission
and stays still), the normal maps, and the alpha-card wings (the master's wings are solid: the opaque cloth slot, since the
card shader draws no depth and the baked atlas has no alpha). `jaw`, `apron`, `skirt`, the spring_tail, spring_capeback and
spring_wing chains and `fingers.L`/`thumb.L` carry no weight. The old textures (body/face colour, normal, emission, wing
atlas) are gone with it. `pip_fit.json`, `pip_bake.json`, `pip_recipe.json` belong to older pipelines.

Stretch: skin_relax ran with `CUTS` 0 (relax only, no cut-and-cap holes, like the other v95 swaps), so
`--stretch-check --wardens=tender` flags every clip over 1.3x (worst 6.2x in flare, idle 2.7x, run_f 4.9x; mostly
hips>hips at the belly and thighs, then head and upper_arm.R). The shots show no tear or clip at idle and run.

Rig unchanged (tender.json body: legs 0.98, torso 1.02, shoulder 1.12, neck -0.036; size 0.68, hit_r 0.34).
- **Companions (pip_v2/meeko_v2_companions_sheet):** the sun floats at her left shoulder (skinned to pauldron.L) and the raincloud at her right (pauldron.R), both rigid and thick (the sun 0.62 as deep as wide, the cloud 0.46), replacing the hand-held star lantern. The lantern's faces are gone from the body mesh; its spring_hanglantern bones stay (the shared armature). The FX points weapon_muzzle, anchor_hang_lantern and anchor_lantern_top (names kept) ride the sun on pauldron.L; `"skinned_weapon": true`, `blade` on anchor_lantern_top and weapon_muzzle with bone pauldron.L.
- **Orbit (runtime):** in the game the companions do not ride the pauldrons. At load scripts/heroes/warden_companions.gd cuts their surfaces (cloth-sun, skin-cloud, ice-drop, the two eyes-mood) out of the body mesh into one unskinned MeshInstance3D each, and every frame floats them round her on a mostly horizontal ellipse, 180 degrees apart, with a small Y bob at its own frequency and a slow ease behind her when she moves; the sun's FX points follow it. All numbers: content/rules/warden_anim/pip.json "companions". Checked by `--meeko-orbit-check`; frames by `--meeko-orbit-shots`. No re-bake: a rebuilt GLB with the same material names works unchanged.
  `pip_companions.py` edits the old glb in place (the clips, rig and body untouched; 30 fps, each clip's last key kept): `blender -b --factory-startup --python tools/art1/pip_companions.py -- <old pip.glb> art/wardens/pip/pip.glb <faces.png>`.
- **Expressions:** 8 faces drawn into one atlas, a decal patch on each companion's front: the sun happy / laugh / grumpy / sleep, the cloud shy / happy / sleep / cry. The game swaps cells (shaders/warden_mood_atlas.gdshader, WardenMood `faces`), driven by warden_anim/pip.json "mood": calm (sun happy, cloud shy), happy on emotes and Meeko's own moves, grumpy / cry on a hit, asleep when downed, a blink to the sleep cell.
  FX points are empties: weapon_muzzle, anchor_hang_lantern, anchor_lantern_top, anchor_palm_L, anchor_flower, anchor_tail_tip, anchor_chest, anchor_head_top.
- **Imports:** pip.glb.import `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`, `animation/fps=48` (the walk/run keys' rate); textures VRAM compressed high quality, mipmapped, at most 2048. Normal maps through hero_toon `use_nrm` (from ext/art1-hem).
- **Burrseed `seed` clip (ext/meeko-lane-picks, from ext/meeko-rmb-verify):** the release-hop `seed` (tools/art1/pip_clips.py)
  went onto this appeal3 glb Blender-free with `glb_add_clips.add`, exact name `seed` (the CLI matches by prefix and would
  also take `seed_aim`); the other 44 clips, meshes, skins and nodes are byte-identical.
  Re-applied 2026-11-14 (ext/fix-main-reds-1114) on the v95 master: the v95 swap (61515dc4fc) was built on the glb from
  before the hop went in and brought the flat `seed` back; same command, `=seed` from dd00ee939e's pip.glb.
  Merged into ext/merge-batch-10-1113 the same day: its walk/run glb with `=seed` from main's pip.glb on top (after the eight walk/run clips, re-run `=seed` the same way).
- **Paws, walk and run (2026-11-11):** the appeal3 bone heat left the heels on the shin (left) and the thigh (right);
  `tools/art1/pip_feet_weights.py` moves the 200 paw verts below the ankle onto foot.L/R (blending into the shin across
  the ankle). `tools/art1/pip_gait.py` (ext/anim-pilot-loops-cm-v2) then rebuilds the eight walk/run loops (f, b, l, r)
  on her old upper body with each stance sole pinned to a floor at loco speed, all on one 0.34 s period (16 keys at 48/s:
  0.333 s); warden_anim/pip.json `loco.cycle_s` 0.34 makes WardenClips' BlendSpace2D run them synced, so they stay in
  step at a diagonal and from the walk ring into the run ring. Her legs reach less behind and to the side, so those soles
  are down for less of the period (duty x0.8 back, x0.62 sideways: a longer float). Walk and run 5.9 steps/s, steps 0.37
  and 0.77 m; soles 2.2 and 4.55 m/s in Blender in every direction, ankle miss 0, hence `foot_mps` [2.2, 4.55] (no
  `stride` gain). Re-baked on main's v95 model (2026-11-13, ext/anim-meeko-loops-length): walk and run share one duty
  (0.25) and one heel-to-toe roll, each swing leaves and meets the floor at its speed, and the old clips' forward lean
  sits on the hips instead of the root (walk_f 7 deg, run_f 12 deg: the thighs hang from the root, so two leans put the
  hips in two places). All three keep the walk-run blend planted: --foot-slide-check worst 1.80 m/s (main's loops 2.46),
  --anim-audit run 13 % (main 12 %). At Godot's default 30 fps import the
  run's 80 ms stance kept 2 or 3 keys and the soles wobbled. Run `pip_feet_weights.py`, `pip_gait.py`, then
  `glb_add_clips.py` with the eight names (the lines at the top of pip_gait.py).

- **Idle pilot (ext/anim-pilot-four): NOT carried (2026-11-14).** The Meshy idle's tracks key `brow.R`, which main's v95 model does not have, so `glb_add_clips.py` refuses it; Meeko's `idle` stays main's.

**11-24, body reads (PLAN 4A-4C; Blender-free, in this order):**

    G=art/wardens/pip/pip_meshy.glb
    python3 tools/art1/glb_mat_rename.py $G $G meshy_textured=meshy_textured-wing
    python3 tools/art1/glb_island_dilate.py $G $G --material=meshy_textured-wing --px=8
    python3 tools/art1/glb_clip_hands_cap.py $G $G --clip=Attack --pose=Idle --margin=0.16 \
        --hands=LeftHand,RightHand,LeftHand_End,RightHand_End

- Wings (4C): `meshy_textured` holds only the wings (17,492 tris, all on the Bone_046-051 chains), so the rename puts them on
  their own tag: same slot look, and pip's `"no_ink": ["cloud", "wing"]` drops their ink shell (the dark plum fringe). Their
  material samples its own copy of the body atlas, so the dilate bleeds the wing UV islands 8 px and fills the unused rest
  with their mean colour (the pale broken edge at the eye camera; the glb 0.5 MB smaller).
- Fire pose (4A): Meshy's `Attack` lifted both paws through her muzzle (paw tips 476 mm over the head bone, model units).
  The Meshy rig task (pip-method-1119/A_rig) has expired, so no re-animate: the shoulder and upper-arm keys are slerped
  toward the Idle pose per key, only as far as needed, so the wrists and paw tips stay 0.16 under the head bone (119 mm in
  game, `--meeko-companions-clip-check` "attack hands"); key times, the forearms and every other track are unchanged.
- The dark patch at her shoulder in the knee idle (4B) is her dark-purple paw held at the chest (it moves with the hand,
  the portrait's pose): kept.

**11-24 (plan /home/boki/gens/hunter-round-1124/meeko/PLAN-1124o.md): the wings ride the upper back, not the head.** Meshy hung
both wing chains (`Bone_048` = Bone_046-048, `Bone_051` = Bone_049-051) under `Head` with keys constant to the head, so every head
turn (up to 67 deg against the chest in Idle, 79 in Attack) swung the wings and the 4,066 cape/back verts that share their weight
through her body (wing into torso 13.8 cm in Attack, 12.8 Jump_Run, 11.9 run). Keys only, after the steps above:

    python3 tools/art1/glb_chain_follow.py $G $G --roots=Bone_048,Bone_051 --follow=Spine

Each clip key re-keys the two wing roots so they keep their rest-pose relation to `Spine` (the rest pose is the Meshy model built from
the turnaround: wings spread evenly at shoulder height). Mesh, skin, node tree and every other track are unchanged (+31 KB of keys).
`tools/anim/geo_check.py`: wing clips over 4 cm 400 -> 0, worst 13.8 -> 3.5 cm, wing-vs-arm/hand clips gone; wing+cape edge stretch
p99 lower in all 6 clips (Attack 2.62 -> 1.63). `--ref=Idle@0` (keep the stand's head-tilted relation) was the runner-up: worst 5.8 cm.

## 11-24 round 3: arms pushed off the belly, paw tips curled, Idle legs apart (keys only)
Tool (job folder, not in the repo): `/home/boki/gens/hunter-round-1124/meeko/r3/tools/keys_r3.py`. Each value was picked by a grid
scored with geo_check's own penetration test (every 2nd frame; grids in `r3/geo/search*.txt`). "push" swings the bone each key so the
forearm/hand moves away from the Hips-Spine axis: run LeftArm 12; walk RightArm 4; Attack LeftArm 4, LeftForeArm 20, RightForeArm 10;
Crouch LeftArm 8, RightForeArm 20; Jump_Run LeftForeArm 10, RightForeArm 30. Paws: Middle1 + Middle3 curled 30 deg toward the palm,
all clips. Idle: thighs 3 deg apart each. Mesh, skin and textures are byte-identical.
geo_check: worst clip 4.6 -> 4.4 cm, run 3.7 -> 3.2, Idle 3.8 -> 3.5, Attack paws into each other 2.5 -> under 2.5 cm (no longer
reported); no pair is newly worse than live. Not done: the held Crouch forearm 4.0 cm stays as it was (every push made another pair worse).

## 11-25 round 5: paws get one designed finger curl (weights + keys; mesh and textures byte-identical)
Tools (job folder, not in the repo): `/home/boki/gens/hunter-round-1124/meeko/r5/tools/finger_weights.py` (round 4's re-weight: the
paw lobes past the knuckle ramp onto Middle1-3; thumb verts untouched) then `fingers_r5.py --deg 35,45,35`: every Middle1-3 key in every
clip becomes rest * one curl about the palm-width axis (palm = the side facing the body midline). Meshy's own finger keys were random
(Middle2 up to 95 deg, mixed axes), which crumpled round 4's re-weighted paws; round 3's R curl axis was flipped (thumb-side sign).
geo_check vs round 3: Attack paws into each other 1.4 -> 0 cm, run cloth into R paw 3.2 -> 2.4 (live 2.5), run cloth into L paw
1.0 -> 0, Jump_Run cloth into paws 3.4/2.8 -> 3.0/2.5; Crouch cloth into R forearm 2.9 -> 3.2 (live 3.0). Thumb keys unchanged.

## 11-25 round 6: Crouch R arm and run L arm out (keys only; mesh, skin, textures byte-identical)
Tool (job folder, not in the repo): `/home/boki/gens/hunter-round-1124/meeko/r6/tools/keys_r6.py` (keys_r3 ops, but every ancestor is
sampled at the key's time, so tracks with other key counts are read right). Ops: `push Crouch_Walk_with_Torch RightArm 10`,
`push Crouch_Walk_with_Torch RightForeArm 18`, `push run LeftArm 6`. geo_check vs round 5: Crouch cloth into R forearm 3.2 -> 0.5 cm
(live 3.0), cloth into R paw 2.9 -> 1.2, torso into R forearm 4.0 -> 1.7 (held worst 4.0 -> 3.8); run L forearm into torso 1.6 -> 1.4;
no pair worse. Stretch Crouch 13.7x / run 10.7x unchanged. Tried and dropped: Idle thighs 6/8 deg apart (cape hem into shins
+0.4/+1.0 cm), any R-arm push in run (R forearm into torso 2.5 -> 4.6-5.0), Jump_Run arm pushes (wing into R paw +0.9),
Attack wing yaw damp 30/50 % (wing into back +0.5-2.3 cm, and the A7-A9 fault is the chest's forward pitch, not yaw).

## 11-25 round 7: sun/cloud back to live (body judged alone), wings on the card slot
Tool (job folder, not in the repo): `/home/boki/gens/hunter-round-1124/meeko/r7/tools/r7_glb.py OUT BODY(r6) LIVE(main)`: surfaces 1-5
(sun, cloud, drop, both mood faces), their materials and the faces atlas from origin/main's glb; body, skin, all 6 clips and the
wing texture byte-identical to round 6 (hash-checked). PR #764's bigger sun/cloud stay in #764. The wing material
`meshy_textured-wing` -> `card-wing`, so the wings draw with `warden_card.gdshader`: a wing seen edge-on at the match camera fades
(far_edge), which removes the pale streak the far wing drew down her back and tail (live has it too). pip's `card` look in
warden_look.json: albedo [0.62, 0.64, 0.72] x glow 1.6 keeps both wing sides the texture's pale lavender (looks A-D in
r7/shots: A peach under the warm sun, C/D dark blue on the unlit side). Cards cast no shadow, so the big wing shadow is gone.

## 11-25 round 8: wings back on their own toon material (round 7's card rename undone)
art-gate (run zD5g) failed round 7: no body shadow, wings off the splash. Cause: `WardenGlb._toon` turns cast_shadow OFF for the
whole MeshInstance3D when any surface is a `card`, and Meeko's wings share the body mesh, so the body lost its shadow too; and the
card shader is lambert, so the unlit wing side drew dark blue (splash/live wings are pale). Tool (job folder):
`/home/boki/gens/hunter-round-1124/meeko/r8/tools/mat_rename.py IN OUT card-wing meshy_textured-wing` (JSON only, BIN byte-identical
to round 7: round 6 body + clips, live sun/cloud). pip's `card` block in warden_look.json is back to main. The edge-on wing streak
(same as live) is open: a card wing needs its own mesh node (shadow) and a toon floor in warden_card (colour) first.

## 11-25 round 9: the sun and raincloud at full resolution, their faces drawn off the atlas again
art-gate (run 0pOi) scored sun_cloud 2.5 (live too): black jagged face patches, a cube for the sun. Two causes, both from the
native switch (e0c5e67730): (1) the decimation cut the companions to about a quarter (sun 480 -> 124 tris, cloud 620 -> 164,
faces 32/34 -> 8/9 tris) and baked the calm cell into the face UVs (whole-atlas coordinates); (2) `WardenNative.dress` never made
a `WardenMood`, so the `eyes-mood_*` faces wore the opaque toon and their clear texels drew black. Fix: the contract pip.glb's
companion surfaces (same design, materials and atlas) fitted onto the native ones (`tools/art1/glb_companions_restore.py`,
similarity ICP, fit error 0.6-0.7 cm mean; body, wings, skin and clips byte-identical to round 8), and the native path makes
the mood for arts with atlas faces (Meeko only; Breaker's baked faces untouched). 79,973 -> 80,936 tris.

Round 10 (11-25, keys only): Meshy's clips sank the planted foot under the floor (model origin = the ground; lowest foot
median Idle -3.3 cm, Attack -7.6, min -12.3) and dragged the tail through it (Idle every frame, -8.4 cm; Attack half the tail,
-32.6 cm). `tools/art1/glb_ground_clips.py` lifts Hips per key until the lowest foot is +0.3 cm in every clip, and pitches the
tail root (Bone_013) up in Idle (14 deg max) and Attack (capped 35 deg; tail min -6.8 cm). walk/run tail left alone (pitching
it pushed the cape hem into the R shin). Mesh, skin, textures byte-identical; geo_check and stretch same as round 9.

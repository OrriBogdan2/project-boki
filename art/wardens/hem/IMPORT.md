# Hem (Lace): native Meshy model r4b (2026-11-22, ext/lace-native-r4)

`hem_meshy.glb` is Lace on Meshy's own 66+2-joint rig, drawn by `scripts/heroes/warden_native.gd` when `hem.meshy_native`
is on in `content/rules/warden_native.json` (off = the contract `hem.glb` below, unchanged). Source:
`/home/boki/gens/native-next-1122/Lace/r4/glb/hem_meshy_lace_r4b.glb` (never edited in git). 71,050 tris, 6 clips
(Idle walk run Jump_Run Attack Crouch_Walk_with_Torch), images extracted by Godot to `hem_meshy_*.jpg/png`.
Body, head and bow are round 3's (PART-LOCK); the skirt is a Meshy image-to-3d skirt + retexture, weighted by position
(Hips at the waist, thighs toward the hem, no shin/foot), +10% wide, back faces culled
(Lace/r5/tools/build_r5.py, notes in Lace/r4/RESULT.md). Art gate run.Hajq: game view 7.2 vs live 3.5.
Open polish: right-side skirt split in close-ups at run/dash/jump, skirt brighter than the deep-red ref and no slit,
short hair, corset side texture, bow string through the chest in attack.

# Hem (archer; shown as Ravyl): import note, v95 swap of Lace appeal3, body b (2026-11-10)

## LIVE v95 master in game (2026-11-12, ext/hunters-v95-ingame)
`~/meshy/v95/lace/r2/body6/lace_v95_body6_body.glb` (the body6 pick, CURRENT_OVERRIDES 11-12) on main's hem.glb rig (no keep parts, so the earlier swap's mesh is dropped whole); bow, arrow and anchor_nock unchanged. Was appeal3 body b below. 13.9k tris (body 13.0k), 2048 atlas + 2048, 51 clips (pet/give/cheer gain sampled channels, same timing).
Spec `art/wardens/src/hem_v95.json`; proof sheet ~/meshy/v95/_closeups/ingame-1112/sheet.jpg.

`hem.glb`: the owner's pick (11-10), Lace v95 r2 appeal3 `cand_b.glb` (the slimmer body; its face is the appeal3 face, one mesh), swapped
onto Hem's own skeleton, 48 clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with `art/wardens/src/hem_v95.json`.
Raw files in ~/meshy/v95/lace/r2/appeal3 (never in git); the spec reads `lace_v95_b_body.glb`, which is `cand_b.glb` without its
`lace_bow` node (cut from the glTF JSON, the buffer untouched): the game's bow and arrow (`bow_mesh`, `arrow_mesh`, on `bow*`/`arrow`)
stay as they were, with their weights.

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/hem_v95.json WORK art/wardens/hem/hem.glb

Body: 13k triangles (head 2.6k), one 2048 atlas embedded (Godot extracts it to `hem_atlas_1.jpg`; `hem_atlas.jpg` is the bow's).
Slots by colour and box (first match wins): metal (the back needles), hair, skin, cloth (red corset), leather (dark skirt, boots).
Weights: bone heat from the spec's joints; the back needles ride `hips`, the head box `head`, the left shoulder mask `pauldron.L`.

Lost from the scripted build (tools/art1/hem_pieces.py, hem_finish.py: that build is replaced, not merged):
the modelled eyelids (blinks no longer show; `lid`/`brow` bones move nothing), the lit strings on her right hand (no glow slot),
the thread and smoke cards, and the closed bow hand (her hands are the master's, open; the bow sits in the left hand as before).
`cape`, `skirt` and the spring chains carry no weight, so the skirt follows the legs. tools/warden_glb_check.gd no longer
asks for the lids and strings.

Rig unchanged: `legs` 2.35, `neck` -0.05, `size` 0.922 in content/archetypes/archer.json.

Shots on the game rig (idle, run, draw, loose; front, 3/4, side, face): docs/shots/lace-appeal-b/. No tearing and no arm
through the chest; the bow passes through her open left hand.

**walk_f / run_f (anim pilot, 11-11):** rebuilt on the v2 rig (the clips carry over to the appeal3 body by bone name, `tools/art1/glb_add_clips.py`, same rig) by retargeting Meshy animation-library actions (her pilot2 Meshy
rig task), loops rebuilt, sole planted at loco speed. Blind Fable 5.2 judge (pilot1 rubric): walk 4.17 vs 3.67 current,
run 4.17 vs 3.67. Licence: Meshy API output on the paid plan, commercial use allowed under Meshy's terms. Idle unchanged
(owned by the pilot4 idle job).
Re-key (ext/anim-dash-clips-cinder-lace, 11-12): `roll` (Spirit Walk) re-keyed to her felt roll, 3.0 m in 0.386 s
(roll_t 0.27 at tuning.json dash_speed 0.7): 0.52 s, the turn on the dash curve, low and crouched at 0.386 s where the walk
takes over (PinSpirit.roll_time). Baked on this glb through `tools/art1/clip_blend.py ... pinch=fing_a2.R` (a control bake
of `roll` and `flick` matched this glb's exactly) and copied on with `glb_add_clips.py ... roll`; `flick` unchanged.
On the v95 swap (body6 pick, above) the `roll` re-key was copied again onto main's v95 glb with `glb_add_clips.py ... roll`.

walk and run b, l, r, fl, fr, bl, br (2026-11-11, ext/anim-dirloops-lace-kael): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/hem/hem.glb OUT.glb 1.18 3.72`,
then `python3 tools/art1/glb_add_clips.py art/wardens/hem/hem.glb OUT.glb walk_b,walk_l,walk_r,walk_fl,walk_fr,walk_bl,walk_br,run_b,run_l,run_r,run_fl,run_fr,run_bl,run_br`.
The speeds are the forward loops' `loco.foot_mps`, not the loco speeds: walk_f/run_f are the old clips and stay, so
the ring keeps `stride`/`foot_mps` and the game's rate and stride lift every direction to loco speed the way they lift
forward. The blind Fable judge kept the old walk_r, run_l (tie or loss), so those are
the old clips put back with `glb_add_clips.py` (judge: docs/art/wardens/dirloops/JUDGE.md).

NOT APPLIED on main (11-16 merge): the diagonal and re-baked back/side loops (walk_/run_ fl fr bl br, b l r) described here were baked into the old model's glb with a walk_f/run_f of a different length than main's v95 clips, so main's glb and warden_anim json are kept. Re-bake: `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- SRC.glb OUT.glb WALK RUN` on main's glb, then `glb_add_clips.py`, then restore the json map from ext/anim-dirloops-lace-kael.

Idle and stance rework (11-09, ported 11-17): `python3 tools/art1/glb_add_clips.py art/wardens/hem/hem.glb <old idle glb> idle,stance --drop-missing`; the old glb's `x_breath` track has no bone here and is dropped (docs/art/IDLE_AUDIT.md).

Native bow clips (ext/anim-lace-native-clips, 11-23): `hem_clips.glb` is the animation-only file for her Meshy skeleton
(`hem_meshy.glb`, untouched): `/home/boki/venv-img/bin/python3 tools/meshy/lace_clips.py art/wardens/hem/hem_clips.glb`.
No mesh, skeleton nodes and ten clips, 30 fps, keyed from poses (no Meshy animation, no retarget). Mapped by `kmoves` in
`content/rules/warden_native.json` (docs/art/wardens/MESHY_NATIVE.md).

11-23 hem_meshy.glb (native path, ext/lace-face-dress-1123): the face, hood hair and bun of the body soup are replaced by a Meshy head
(own skinned mesh `Head_new`, material `body-face`, 8k tris, grafted at the choker, weighted Head/neck) plus two hair pins (`Pins`, material `metal-pin`).
The skirt is welded (1.5 mm), gets a flipped red inner face (2 mm inset) and eight `SkirtSw*` billow bones on the Hips that swing the cloth out
of the legs in every frame of every clip (radius margin 0.12 m = thigh radius; pivot 1.1 m). The stray unskinned Icosphere is gone.
Build scripts and renders: /home/boki/gens/lace-face-dress-1123 (tools/build_b.py, tools/graft_head.py). Needs an owner visual check before it goes live.
11-25 r20 (ext/lace-r13-slit): the body's crude thighs/knees and the r16/r18 thigh-liner tubes are replaced by Meshy porcelain doll legs
(prim `leg-meshy` in Mesh_0, 9.7k tris, own 1024 texture `hem_meshy_leg20.jpg`; legs-only Meshy multi-image task from turnaround edits).
Tools: tools/art1/hem_r20 (README). Renders: /home/boki/gens/hunter-round-1124/lace/r20. Needs an owner visual check before it goes live.
11-25 r23 (ext/lace-r13-slit): skirt-meshy gets COLOR_0 (ink room 0 on the inner layer and fray band), its inner-layer faces move to
prim `skirt-lining23` (wine copy of the skirt texture, `hem_meshy_skirt_lining23.jpg`), the bow fist `body-hand17` gets ink room 0:
no black ink blotches on the skirt / fist. Tools: tools/art1/hem_r23 (README). Needs an owner visual check before it goes live.

r27 (2026-11-26): slit-closing keys only (tools/art1/hem_r26/slitclose.py, args in its README): Idle/walk closed like Attack so the
game camera no longer sees the ground through the slit; Jump_Run/run closed less so the knee stays inside. Mesh/textures = r26
(partlock PASS). Needs an owner visual check before it goes live.

r29 (2026-11-26): the skirt shell is turned +14 deg so the slit sits in front of her right leg (it was ~20 deg too far to her side,
so the knee hit the panel beside it), knee-follow s 0.6 and the r28 V godet re-centred; skirt texture = a Meshy retexture of the r21
skirt model (dark wine, `hem_meshy_skirt29.jpg`), lining = a darker copy (`hem_meshy_skirt_lining29.jpg`; replaces skirt22 /
skirt_lining23). Tools: tools/art1/hem_r29 (README). Needs an owner visual check before it goes live.

r30 (2026-11-26): the r28/r29 slit godet (a membrane 10-15 cm in front of the right thigh; the swinging thigh crossed it = white
shards in the front slit) is replaced by a wine curtain BETWEEN the legs (prim `skirt-godet30`, 320 tris, each edge skinned to its
own leg), and the lining = the outer skirt image x0.55 with no hue shift (`hem_meshy_skirt_lining30.jpg`; replaces skirt_lining29,
which read as a pale-pink flap). Outer skirt, body, hands, bow unchanged (partlock PASS). 90,391 tris. Tools: tools/art1/hem_r30
(README). Needs an owner visual check before it goes live.

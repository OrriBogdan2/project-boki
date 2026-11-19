# Hem (archer; shown as Ravyl): import note, v95 swap of Lace appeal3, body b (2026-11-10)

## 2026-11-19: hands/forearms split from the skirt, weights + vertex split (ext/hunter-fix-hem-1118, retry 11-19k)
Restarted from main's glb (sha1 fd2a8ff1). Positions, UVs, normals, colours of every live vertex, every live triangle, the
skeleton, bone names, all 53 clips, textures, bow and arrow are unchanged; the rest pose is identical. Body mesh only:
1. Each forearm/hand was welded to the skirt/hip skin. A min cut (unary = live arm weight, cut cost = rest edge length / live
   stretch^2, skin/leather and arm-band cloth only; skirt and belt pouches stay on the body) gives every triangle near a
   forearm/hand bone a side. The 196 verts shared by both sides are duplicated (same position, normal, UV, colour); the arm
   triangles use the copy. No triangle deleted. Islands the cut would leave hanging are given to the side they touch.
2. Weights: arm side = arm bones only (harmonic fill from clean arm verts, below the chest); body side below the chest = no arm
   bones at all (harmonic fill from verts with no arm weight; hips, legs, skirt bone, cape); chest/shoulder keep their upper
   arm share and lose only forearm/hand. Then three robust (Cauchy) weight relax passes over every clip (glb_relax sampling).
3. The cut leaves closed rims; 3 of them get a hidden cap (19 extra triangles, centroid fan, one flat colour) that a ray test
   (190 directions, none from below) shows is never seen at rest; the others stay open (a cap there would show at rest).
4. 11-19 retry (review hem.md: black hole in the skirt at the left hip under the belt when the hand leaves it). Every skirt-side
   rim the cut left (arm weight < 0.2; left hip 11 rims incl. 18.2 cm and 8.7 cm, right hip 2) gets a cap: rim on a disk by arc
   length, Delaunay with interior points at >= 1.6x the median edge, harmonic 3D membrane with the rim fixed, then sunk up to
   6 mm toward the body axis (0 at the rim) so it stays under the hand at rest, harmonic weights from the rim (hips/thigh only), one median texel of the material
   of the skirt leather (leather-v95b: renders as the skirt mauve; a cloth texel read as a red patch), cap edge 0.05 mm inside the rim with the rim's own
   weights. 394 verts / 577 triangles added, nothing deleted or moved. Edges over 3x stay 0 (worst 2.72), Godot stretch
   worst 2.72 (hail), hunter_mesh_check nonmanifold 18 and spike edges 127 (both unchanged). Rest pose: at most 47 px of a
   1024 px frame change (wrist/belt seam line, 8 views), as small as live vs the previous fix (12-45 px). Script: cap.py in ~/cj/20261119-191052-a1/work (job dir).
Scripts: job dir split.py (FIT=0, D=0.15, LAM=4, KAP=2, GAM=3, CLOTHY=1.15, ISL=200) + capray.py (Blender BVH) + lb.py
(PEN=cauchy CS=1 CALMW=30, T=2 / 1.6 / 1.4), all in ~/gens/hunter-fix-hem-1119c/scripts.
Numbers vs live (welded, rest edge >= 8 mm, every clip at 0.1 s): edges over 3x 252 -> 0 of 46,445 (live 46,376; 0.54% -> 0%),
over 10x 4 -> 0, worst 17.2x -> 2.72x, clips with an edge over 3x 53 -> 0; hunter_mesh_check stretched_tris 660 -> 1,
far_bone_verts 586 -> 170; Godot `--stretch-check` worst 17.81 (roll) -> 2.72 (hail), every clip under 3.0,
60 of 61 clips lower than live (g_nod 1.12 -> 1.39 at the left shoulder) (spike edges 127, floating islands 1, black texels unchanged: geometry/texture).
Look change: the skirt no longer hangs on the arm weights, so in idle/stance/crouch it drapes as in the rest pose instead of
being pulled toward the hands (the live drape came from the ~25% hand weight on the thigh/skirt skin that tore in bow clips).

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

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

Re-key (ext/anim-dash-clips-cinder-lace, 11-12): `roll` (Spirit Walk) re-keyed to her felt roll, 3.0 m in 0.386 s
(roll_t 0.27 at tuning.json dash_speed 0.7): 0.52 s, the turn on the dash curve, low and crouched at 0.386 s where the walk
takes over (PinSpirit.roll_time). Baked on this glb through `tools/art1/clip_blend.py ... pinch=fing_a2.R` (a control bake
of `roll` and `flick` matched this glb's exactly) and copied on with `glb_add_clips.py ... roll`; `flick` unchanged.
On the v95 swap (body6 pick, above) the `roll` re-key was copied again onto main's v95 glb with `glb_add_clips.py ... roll`.

# Hem (archer; shown as Ravyl): import note, v95 swap of Lace appeal3, body b (2026-11-10)

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

**walk_f / run_f (anim pilot slice3, 11-11):** rebuilt by retargeting Meshy animation-library actions (her pilot2 Meshy rig
task), loops rebuilt, sole planted at loco speed. Blind Fable 5.2 judge (pilot1 rubric): walk 4.17 vs 3.67 current, run
4.17 vs 3.67. Licence: Meshy API output on the paid plan, commercial use allowed under Meshy's terms. Judged on the pre-appeal
body; ported onto appeal-b (legs x1.146) with `tools/art1/gait_port.py`: same joint rotations, hips height x1.146, time
x1.19 walk / x1.16 run so the planted foot still covers walk_speed/run_speed (FK: 2.15 / 4.24 m/s vs 2.12 / 4.27 before).
Idle unchanged (owned by the pilot4 idle job).

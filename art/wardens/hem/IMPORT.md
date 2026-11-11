# Hem (archer; shown as Ravyl): import note, v95 swap of Lace appeal3, body b (2026-11-10)

## Women body pass 11-11 (ext/women-body-1111): the current hem.glb

Owner 11-10: Lace less wide, thin, good chest, pretty/porcelain. `~/meshy/v95/lace/r2/body5/cand_1.glb` (pick.txt and sheet_lace.jpg beside it; cand_2 is slimmer still but distorts the arm) is appeal3 cand_b with a position+normal displacement: slimmer arms, waist and shoulders, a fuller bust (area p95 1.06 / p99 1.17). The spec reads `lace_v95_body5_body.glb` (cand_1 without its lace_bow node, as before). The swap ran on ext/women-body-1111's older tree (d31afaa66), so the 0.24.5 glb's clips were copied back on by node name (tools/art1/glb_add_clips.py, same skeleton: the pet/give/cheer clips and the last frame the older swap dropped) and the glb's orphaned bytes dropped. Shots: docs/shots/women-body-1111/ (sheet_<name>.jpg is 0.24.5 against this build, front and side, rest pose).

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

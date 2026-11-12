# Claire (rimewright): import note, v95 swap of Claire appeal3, body a (2026-11-10)

`claire.glb`: the owner's pick (11-10), Claire v95 r2 appeal3 `cand_a.glb` (the appeal3 face on body a, one mesh), swapped onto
Claire's own skeleton, 49 clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/claire_v95.json`. Raw files in ~/meshy/v95/claire/r2/appeal3 (never in git); the spec reads
`claire_v95_a_body.glb`, which is `cand_a.glb` without its spear node: the game's spear (its shaft and ice blade on `hand.R`,
`keep_slots` cloth and ice, so the old glove is left out) stays as it was, with its weights and the old atlas `claire_atlas.jpg`.

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/claire_v95.json WORK art/wardens/claire/claire.glb

Body: 13k triangles (head 2.6k) plus the spear, one 2048 atlas embedded. The master's sheer skirt is a flat colour with no
texture; tools/meshy/bake_warden.py now bakes such a material's base colour (opaque).
Slots by colour and box (first match wins): hair (white, head box), skin, fur (white trim), ice (cyan), cloth (the rest).
Slot fix: a face box comes first and is all skin. Without it the pale face triangles split between hair, skin and ice,
and the face shaded in facets.
Weights: bone heat from the spec's joints; the sheer back cape rides `hips` (legs excepted), the head box `head`.
Clip fix: the front braid hangs over her left chest; by heat it went to `forearm.L` and stretched from the chest to the hand
in idle. A `hips` box over the braid (the left arm and thigh capsules excepted) keeps it on the torso.

Lost from the scripted build (tools/art1/claire_source.py, claire_pieces.py, claire_finish.py, claire_paint.py: replaced, not merged):
the modelled lids (blinks no longer show; `lid`/`brow` bones move nothing); the ears, braid, bow, scarf and puff tail are the
master's, part of the body by bone heat (the ears on `head`), so the spring chains, `skirt` and `scarf` carry no weight; her hands
are the master's open gloves.

Rig unchanged: archetype body legs 2.04, torso 0.96, shoulder 0.84, neck -0.04, size 1.1.
Anchors moved through the fit: `anchor_head_top`, `anchor_chest`, `anchor_eye_l/r`, `anchor_clasp`, `anchor_tail_tip`.

Shots on the in-game rig (Godot, `--shots`): docs/shots/claire-appeal-a/ (front/3-quarter, back, side in the turnaround,
face close-ups, idle/run/attack/cast/ult at the match camera, run close). Checks: --warden-glb-check rimewright ok (the one
fail is tender's hit flash, the same on the base), --warden-model-check 157/157.
Stretch check: all 49 clips over 1.3 (worst 6.61 revive, idle 6.01, run_f 3.15), almost all
in `hips`; before the braid fix: worst 8.01, idle 6.35, run_f 5.72. The relax runs with CUTS 0 (no holes), as Lace, Sparkle and Meeko, so a stretched
edge stays rather than a hole; it is not reworked here.

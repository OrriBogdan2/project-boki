# Talking NPCs: design and pipeline

The NPCs you talk to (Hob on the farm, Pell in the tutorial) are rigged Meshy models drawn by `NpcModel`
(`scripts/match/npc_model.gd`): the painted atlas on the hero toon shader (`WardenGlb.PAINTED` light, ink line),
a pose string that picks a clip, a name tag, "!" mark and shout bubble, and a talk-box portrait. Sizes and the
pose -> clip table are data: `content/rules/npcs.json`. Check: `--npc-check` (`tools/npc_check.gd`).

## The designs (Nov 11, owner: "Hob and the future tutorial person need a design - and a Meshy design")

Sheets (not in git): `/home/boki/meshy/npc-hob-guide-1111/` `options.jpg` (3 front-view options each, with notes),
`turnaround-hob.jpg`, `turnaround-pell.jpg`, the Meshy runs in `m3d/`.

- **Hob Brackenridge, "Old Road Hob"** (picked from 3): a retired adventurer turned builder. Patched ochre coat,
  goggled wide-brim hat, braided grey beard, blueprint satchel, a big mallet across his back. The hat and mallet
  read at the farm camera, ochre is no Hunter's colour, and it fits his voice (MAIN_TO_EXT item 169: a jolly,
  crass old adventurer-builder). Not picked: a closer-to-placeholder apron builder (the smallest silhouette) and a
  straw-hat farmer (green too near Vex).
- **Pell, "Lantern Owl"** (LORE_MASKS round 5: the tutorial guide, a freed soul, part bird, part humanoid): an
  owl-folk in a deep-teal hooded cloak with a gold soul-star on the chest. Upright and cloaked, so a person, not a
  Boki. Kind, patient, a little wry. Not picked: a heron (thin legs and neck vanish at the camera and mesh badly)
  and a sparrow (reads as a Boki).

## Steps (r2, Nov 12: the hero-quality pass, `~/meshy/npc-spend-1112/`, RESULTS.txt there)

1. Options and turnaround: `vertex-gen` with house-style refs (front, side, back in a relaxed A-pose). The props
   come off the sheet: Meshy image-to-image (nano-banana-pro, 9 credits each) redraws the turnaround without the
   prop (Hob's mallet, Pell's lantern) and draws the prop alone in a three-quarter view; the views are cropped
   square at 1024 px.
2. Meshy multi-image-to-3D from the three views: meshy-7.1, 2k geometry, meshy-7 8k texture, remeshed to 16k
   triangles, A-pose, enhancement on (40 credits a take; take several and keep one with a frontal face and whole
   hands). The props: image-to-3D from their own drawing, 3k triangles (40).
3. Meshy rig (`meshy_task_v9.py rig <out> <task> --height <m>`, 5 credits), then `animate <out> <rig_task> --actions`
   (3 credits a clip, up to 10 a call): Idle 3 (243), Talk Passionately 308 / Talk with Hands Open 313 (talk),
   Big Wave Hello 28 / Wave One Hand 290 (wave), Casual Walk 30, Call Gesture 29 / Talk with Right Hand Open 314
   (point), Heavy Hammer Swing 128 (Hob's hammer). The library has no plain point; the library Idle turns its back.
4. `blender -b --factory-startup --python tools/meshy/npc_bake.py -- <src dir> art/npcs/<id>/<id>.glb <id>`: the
   recipe in `tools/meshy/npc_recipes.json` names the animate outputs (merged), clip -> pose, the albedo size
   (2048 px JPEG) and the props: each prop is skinned to its own bone, keyed in every clip to ride its carrier
   (Hob's mallet on his back, in his right hand for "hammer"; Pell's lantern hangs upright from Pell's left hand).
   About 17k triangles and 2-2.4 MB each.
5. A row in `content/rules/npcs.json`; `NpcModel.new("<id>")` (or a subclass, like `HobModel`).

Meshy task ids (r2): Hob 01a1cff2-7449-7692-a3d8-261a7018aeb0 (rig 01a1cff8-d7d3-71fa-93eb-140ea4462df4), mallet 01a1cfe9-eb6f-770e-8a4e-031f6f845995; Pell 01a1cfe9-1a8d-70d0-a575-8881baba2315 (rig 01a1cff2-7419-7537-bc15-28616b28ac5e), lantern 01a1cfe9-1a84-7455-9017-5d3fe979d3b5.
Known gaps: docs/DEBT.md ("The NPCs' Meshy models").

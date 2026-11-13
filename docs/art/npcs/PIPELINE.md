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

## Steps

1. Options and turnaround: `vertex-gen` with house-style refs (front, side, back in a relaxed A-pose); the views
   cropped square at 1024 px.
2. Meshy multi-image-to-3D from the three views (15k triangles, 2k texture, A-pose; 35 credits each).
3. Meshy rig (`meshy_task_v9.py rig <out> <task> --height <m>`, 5 credits), then `animate <out> <rig_task> --actions`
   (3 credits each): Idle 0, Stand and Chat 56 (talk), Big Wave Hello 28 (wave), Casual Walk 30, and for Hob
   Call Gesture 29 (point) and Heavy Hammer Swing 128 (hammer).
4. `blender -b --factory-startup --python tools/meshy/npc_bake.py -- <animation_glb.glb> art/npcs/<id>/<id>.glb
   <id> Idle=idle Stand_and_Chat=talk ...`: clips renamed to poses, albedo only (1024 px JPEG), ~1.5 MB. The bake
   applies Meshy's 0.01 Armature scale (bones in metres): left on, Godot drew the skinned mesh 100x big (`--npc-check`
   measures the skeleton for it; `--npc-shots` ends on a close lineup of both).
5. A row in `content/rules/npcs.json`; `NpcModel.new("<id>")` (or a subclass, like `HobModel`).

Meshy task ids: Hob 01a1cc6a-dcbc-7294-931b-58221c420800, Pell 01a1cc6a-dce0-777c-b6be-636f72364352.
Known gaps: docs/DEBT.md ("The NPCs' Meshy models").

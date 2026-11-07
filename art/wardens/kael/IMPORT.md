# Kael (juggernaut): import note, v2 (2026-11-07)

`kael.glb` is the owner's locked v2 redesign (briefs/art-refs/kael_v2 on ext/agent-briefs: the 4K
kael_v2_turnaround and kael_v2_master_sheet) through the ART-1 pipeline. One Meshy body scan of the turnaround,
fitted onto the contract rig by script; the sword, the wrist chains and the alpha cards are built by script. Raw
files in ~/meshy/kael_v2/ (never in git; `build.sh` there reruns everything). Run log: docs/art/wardens/PIPELINE.md.

    T=tools/meshy/meshy_task.py; B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    python3 -I $T edit ...   (x4: the turnaround's front, 3/4, left side, back; prompts in ~/meshy/kael_v2/edit.sh)
    python3 -I $T create runB in/front.png in/tq.png in/side.png in/back.png --texture-refs <same> --pose ""
    godot --headless -- --warden-rig-json --warden=juggernaut       # -> art/wardens/src/kael_rig.json
    $B tools/art1/kael_source.py -- runB/glb.glb art/wardens/src/kael_rig.json stage/source.blend
    $B tools/art1/kael_finish.py -- stage/source.blend art/wardens/src/kael_rig.json kael.glb

- **Edits:** each view loses both wrist chains (cuffs kept) and the long sash tails (knot kept); nothing else.
- **Scan:** meshy-7.1, no pose (the A-pose run opened his fists and gloved the cursed hand black: not used). It
  keeps his own head, white mane, scarf over the mouth, the two-tone torn shawl, the X-harness, belts, trousers,
  knee guards, boots, the black right glove and the bare crimson left hand.
- **Rig:** the v2 sheet is a tall build (8 heads, long legs). juggernaut.json `body`: legs 1.55 -> 2.05, head
  0.62 -> 0.48, neck -0.02 -> -0.012 put the rig's joints on the scan's (hip 0.52, shoulder 0.79, head pivot 0.87
  of his height); `size` 1.06 -> 0.97 keeps his height in the game (the owner's Nov 4 size).
- **Fit** (kael_source): soft weights by distance to the bone segments, each bone moves its vertices onto the rig;
  girth 1.07 (torso) and 1.1 (arms) for the sheet's broad build; decimated to 11k triangles.
- **Finish** (kael_finish): the scan's colour baked onto the low mesh (one 2048 atlas, the scripted pieces on flat
  cells at its right edge). Slots by colour and by distance off the body (the shawl and scarf stand off the skin).
- **Curse:** on his LEFT arm and hand and the chest, as all four turnaround views draw it (the sword stays in his
  right hand, as the clips and kit hold it). The veins are a 2048 emission map (kael_emit), tinted by
  juggernaut.json `model_glow.core` (crimson); the arm blooms (warden_look `kael`) sit on anchor_arm_up / _elbow /
  _fore, now on the left arm.
- **Cards** (`card-kael`, a 512x256 RGBA kael_cards atlas): the shawl's torn hem (a card under each rim edge, down
  the shawl's own surface) and two sash tails from the knot at his right hip, placed on the trousers by ray.
- **Wrist chains:** short chains from each cuff, two bones each on the hang chains the game knows
  (spring_hangcuff_* left, spring_hangwarchain_* right).
- **Sword (`weapon`, Gun space):** the turnaround's broad cracked blade (bevelled slab, white-hot cracks as
  `glow-sword` ribbons in model_glow `sword`), the guard with its point, the red wrapped grip, the ring pommel and
  its hooked chain. Sized to the turnaround against his height: whole sword 0.80, blade 0.61, blade width 0.10
  (after the Gun's 1.42 and warden_look weapon_scale 0.85).
- **Armature:** the contract's plus the spring chains of v1 (mane x5, hangcuff, hangwarchain); every anchor of v1
  kept (anchor_head_top, anchor_chest, anchor_arm_*). 12.6k triangles in all (body 11.7k, sword 0.9k).
- `kael.glb.import`: `generate_lods=false` (LODs would eat the thin cards), `force_disable_compression=true`.

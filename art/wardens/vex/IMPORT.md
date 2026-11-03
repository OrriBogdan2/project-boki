# Vex: import note

`vex.glb` is built in Blender by a script, nothing hand-edited:

    godot --headless -- --warden-rig-json --warden=gunslinger      # -> art/wardens/src/vex_rig.json
    ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/blender/vex.py -- [--render <dir>]

- **Armature:** the shared contract skeleton (docs/art/wardens/RIG_CONTRACT.md), read from her rig JSON so every
  bone sits on the rig node it follows. Skin weights are set per piece: limbs blend over short spans at the
  joints, the shoulder plate rides `pauldron.L`, the scarf tails `scarf`.
- **Mesh:** about 15k triangles in the body, 1.9k in the rifle. Blocked against her turnaround and splash
  (`docs/art/gen/wardens/venatrix_*`): lofted and subdivided body forms with soft cloth displacement, bevelled
  hard-surface pieces, fingers, the beret, boots, a sculpted head. She is a woman. Her mechanical arm and the
  sigil plate are on her **left**, as her Warden block and splash have them (the sheet draws them on her right);
  the mechanical eye is her right.
- **Atlas:** one 1024 image baked in Cycles from procedural paint (a light-to-dark gradient over each part, AO,
  edge wear, painted noise), embedded in the .glb (Godot extracts `vex_atlas.png`). Values are lifted so she
  reads at dusk under the hero toon shader. Materials are named after the toon slots.
- **Weapon:** the ember rifle is its own mesh, `weapon`, modelled in the Gun node's space (muzzle at the Gun's
  Muzzle); its magazine is the child `weapon_mag`, which the loader makes the Gun's Mag for the reload.
- **Anchors:** `anchor_head_top` (head), `anchor_chest` (hips).

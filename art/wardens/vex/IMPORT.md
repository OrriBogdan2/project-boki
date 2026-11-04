# Vex: import note

`vex.glb` is a Meshy image-to-3D model fitted to the Warden contract in Blender by script, nothing hand-edited.
The steps, settings and run log are in docs/art/wardens/PIPELINE.md.

    blender -b --factory-startup --python tools/meshy/vex_inputs.py -- ~/meshy/vex ~/meshy/vex/prep2
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex/run3 <prep2 front, side, back> --polycount 30000
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex/run2_rifle <rifle_front, rifle_back> --polycount 6000 --pose ""
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex/run5_head <prep2 head_portrait> --polycount 20000 --pose ""
    godot --headless -- --warden-rig-json --warden=gunslinger      # -> art/wardens/src/vex_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/vex_fit.json

- **Body:** Meshy multi-image-to-3D from her turnaround's front, side and back (rifle painted out), as drawn:
  mechanical RIGHT arm, the sigil plate on her right shoulder. Posed into the contract rest pose.
- **Head:** a separate Meshy run from the portrait (her face, eye, smile and beret badge), mirrored so the lens is
  on her right eye as the turnaround and her Warden block have it (the portrait draws it on her left), fitted onto
  the body's beret; the turnaround's back view is painted onto the back of the head.
- **Texture:** Meshy's base colour, flattened toward the sheet's own colours (median, then halfway to the nearest
  of the sheet's 18 colours), lifted a step; the scarf's orange made flat; the profile projected onto the plate.
  Materials are named "<slot>-<texture>" after the toon slots; the game shades them with the hero toon shader
  (albedo only, no PBR maps, no procedural brushwork).
- **Weapon:** a separate Meshy run of the rifle alone, fitted to the Gun node's space (`weapon`, muzzle at the
  Gun's Muzzle). It has no separate magazine, so the procedural Mag node is emptied.
- **Armature:** the shared contract skeleton; body auto-weighted, the head rigid on `head`. 14.3k triangles in
  the body and head, 5.8k in the rifle. Anchors: `anchor_head_top`, `anchor_chest`.
- `vex.glb.import` has `generate_lods=false` (the LODs collapsed her face at the match camera).

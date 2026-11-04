# Vex: import note

`vex.glb` is a Meshy image-to-3D model fitted to the Warden contract in Blender by script, nothing hand-edited.
The steps, settings and run log are in docs/art/wardens/PIPELINE.md.

    blender -b --factory-startup --python tools/meshy/vex_inputs.py -- ~/meshy/vex ~/meshy/vex/prep
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex/run1 <prep front, side, back> --polycount 30000
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex/run2_rifle <prep rifle_front, rifle_back> --polycount 6000 --pose ""
    godot --headless -- --warden-rig-json --warden=gunslinger      # -> art/wardens/src/vex_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/vex_fit.json

- **Body:** Meshy multi-image-to-3D from her turnaround's front, side and back, with the rifle painted out. The
  views are mirrored so her mechanical arm and sigil plate are on her **left**, as her Warden block and splash
  have them (the sheet draws them on her right); the head is kept as drawn, so the lens eye is her right.
  Posed into the contract's rest pose and decimated to 15k triangles. Her proportions are the art's (archetype
  body: head 0.39, legs 1.78, neck -0.04, build 0.86).
- **Texture:** Meshy's base colour, textured from the same views, lifted a step. The art's own front view is
  projected onto her face and beret, and its profile onto the sigil plate. Materials are named after the toon
  slots by painted colour; the game shades them with the hero toon shader (albedo only, no PBR maps).
- **Weapon:** a separate Meshy run of the rifle alone, fitted to the Gun node's space (`weapon`, muzzle at the
  Gun's Muzzle). It has no separate magazine, so the procedural Mag node is emptied.
- **Armature:** the shared contract skeleton, auto-weighted. Anchors: `anchor_head_top`, `anchor_chest`.

# Vex (r2): import note

`vex.glb` is the r2 Vex (owner-approved art: docs/art/gen/wardens_r2/vex_* on ext/imagegen): one Meshy
image-to-3D run fitted to the Warden contract in Blender by script, nothing hand-edited. Steps and run log:
docs/art/wardens/PIPELINE.md.

    blender -b --factory-startup --python tools/meshy/vex_inputs.py -- ~/meshy/vex_r2/vex_turnaround.png ~/meshy/vex_r2/prep
    blender -b --factory-startup --python tools/meshy/vex_inputs.py -- ~/meshy/vex_r2/vex_turnaround_2k.png ~/meshy/vex_r2/prep2k
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_r2/run1 prep/view0.png prep/view1.png prep/view2.png prep/view3.png --polycount 30000
    godot --headless -- --warden-rig-json --warden=gunslinger      # -> art/wardens/src/vex_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/vex_fit.json

- **Body:** from the turnaround's four views as drawn: minigun RIGHT arm, monocle on her left eye. Posed into the
  contract rest pose; head x1.12, free hand x1.2, girth x1.06 over the art (game proportions); 15k triangles.
- **Gun-arm:** the minigun cut from her right forearm into `weapon` (the Gun node's space, its muzzle on the
  Gun's Muzzle; 5.8k triangles), its barrels the child `weapon_spin`, which HunterAnim spins while firing; the
  vents on the glow slot. Her stance (ext/warden-stance) hangs it barrel-down at her side.
- **Texture:** Meshy's base colour, filtered and flattened toward the sheet's colours within each UV island
  only, lifted; the 2000 px art projected on her face, hair, vest (front) and back. Materials named
  "<slot>-<texture>"; the game shades the atlas with a soft light toon ramp (no self-shadow, AO or ink shell).
- `vex.glb.import`: `generate_lods=false`, `force_disable_compression=true`.

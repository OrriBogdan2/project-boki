# Pin (r2): import note (WIP, paused 2026-11-04 05:00 for the Vex recipe rerun)

`pin.glb` is the r2 Pin (owner-approved art: docs/art/gen/wardens_r2/pin_* on ext/imagegen): one Meshy
image-to-3D run fitted to the Warden contract in Blender by script, nothing hand-edited. Steps and run log:
docs/art/wardens/PIPELINE.md.

    blender -b --factory-startup --python tools/meshy/pin_inputs.py -- ~/meshy/pin/r2/pin_turnaround.png ~/meshy/pin/r2/pin_side.png ~/meshy/pin/prep
    blender -b --factory-startup --python tools/meshy/pin_face.py -- ~/meshy/pin/r2/pin_portrait.png ~/meshy/pin/prep/portrait_face.png
    python3 -I tools/meshy/meshy_task.py create ~/meshy/pin/run1 prep/view0.png prep/view1.png prep/view2.png prep/view3.png --polycount 30000
    godot --headless -- --warden-rig-json --warden=archer      # -> art/wardens/src/pin_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/pin_fit.json

- **Inputs:** the turnaround's front, 3/4 and back plus the side view (planted boots). The bow, its string and
  the loose arrow, the shin smoke, the ground shadows and the cape's smoke wisps are painted out; the red
  handprint is painted out of the mask (not used: it matches a real-world movement's symbol).
- **Body:** archetype body legs 1.85, neck -0.03, build 1.1; head x1.12, hand x1.2, girth x1.06; 15k triangles.
  The hanging, pointed boots are turned flat and shortened onto the ground (`feet`). Hair strands Meshy hung
  in front of the mask are cut (`cut_strands`). The cloak behind her rides the Cape bone (`cape`), so
  HunterAnim streams it back on its spring.
- **Face:** the portrait's mask (handprint painted out, mouth seam redrawn) with four red-brown claw scratches
  across the lower face (tools/meshy/pin_face.py), projected onto the face by three landmarks.
- **Bow:** built by script (tools/meshy/bow_parts.py), not Meshy: `weapon` in the Gun node's space (black
  faceted recurve, hooked tips, red grip and tip wraps, steel fins, pale string), its nocked arrow the child
  `weapon_mag` (the loader makes it the Gun's Mag); `anchor_nock` on hand.R.
- `pin.glb.import`: `generate_lods=false`, `force_disable_compression=true`.

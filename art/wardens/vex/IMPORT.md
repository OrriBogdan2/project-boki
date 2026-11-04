# Vex (r3): import note

`vex.glb` is the r3 Vex (owner-approved art: docs/art/gen/wardens_r2/vex_* on ext/imagegen): one Meshy 7.1 run at
its best settings, baked to a clean game mesh and fitted to the Warden contract in Blender by script, nothing
hand-edited. Steps, settings and the run log: docs/art/wardens/PIPELINE.md.

    blender -b --factory-startup --python tools/meshy/vex_inputs.py -- ~/meshy/vex_r3/art/vex_turnaround_2k.png ~/meshy/vex_r3/prep2k
    ffmpeg -i prep2k/viewN.png -vf scale=1582:1582:flags=lanczos in/viewN.png             # each of the four views
    python3 -I tools/meshy/meshy_task.py edit ~/meshy/vex_r3/edit_front prep2k/view0.png --prompt "..."   # and 3/4, back
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_r3/runI_armdown_prof_noenh in2/front.png in2/34.png in2/profile.png in2/back.png --texture-refs in2/front.png in2/34.png in2/profile.png in2/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/vex_bake.json
    godot --headless -- --warden-rig-json --warden=gunslinger      # -> art/wardens/src/vex_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/vex_fit.json

- **Inputs:** the turnaround's four views (ground line painted out, enlarged 2x); her left arm, drawn with the hand
  on her hip, redrawn hanging free in the front, 3/4 and back views by Meshy's image-to-image (so the mesh comes
  out with the arm apart from the hip). Monocle on her left eye and minigun arm on her right, as drawn.
- **Mesh:** meshy-7.1, no remesh, geometry 2k, meshy-7 texture 8k: 1.19M triangles. Baked to 40k (10k on the head)
  with new UVs; the body is 33.9k triangles after the gun-arm comes off, the weapon 4.4k. Head x1.12, free hand x1.25,
  girth x1.14 over the art (game proportions); archetype body build 1.12.
- **Gun-arm:** the minigun cut from her right forearm into `weapon` (the Gun node's space, its muzzle on the Muzzle),
  its barrels the child `weapon_spin`, spun by HunterAnim while firing; all metal but its vents, which keep Meshy's
  orange on the glow slot. The feed belt that came off with it is trimmed; the body's forearm weights went to the hips.
- **Texture:** Meshy's 8k base colour baked onto one 4096 atlas, shipped at 2048 (vex_atlas.jpg). Touch-ups: the
  skin slot warmed toward the art's tan, the monocle's lens on the glow slot. The vertex colour's alpha is the ink
  room (the ink shell's limit per vertex).
- `vex.glb.import`: `generate_lods=false`, `force_disable_compression=true`.

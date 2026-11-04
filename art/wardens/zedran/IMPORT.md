# Zedran (r2): import note

`zedran.glb` is the r2 Zedran (owner-approved art: docs/art/gen/wardens_r2/zedran_* on ext/imagegen): one Meshy
image-to-3D run for the body, fitted to the Warden contract in Blender by script, and a greatsword cut flat from the
art itself. Nothing is hand-edited. Steps and run log: docs/art/wardens/PIPELINE.md.

    blender -b --factory-startup --python tools/meshy/zedran_inputs.py -- ~/meshy/zedran/r2 ~/meshy/zedran/r2/prep
    python3 -I tools/meshy/meshy_task.py create ~/meshy/zedran/r2/run1 prep/view0.png prep/view1.png prep/view2.png --polycount 30000
    godot --headless -- --warden-rig-json --warden=juggernaut      # -> art/wardens/src/zedran_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/zedran_fit.json

- **Inputs:** the turnaround's front and back and the side view (his right side); not the art's 3/4 views, which
  lose the magma arm's cracks and swap the hands. The greatsword is painted out of all three (in the front, his left
  leg mirrored onto the right leg it hid; in the side view, the thigh and skirt filled with their own colours). The
  side view's yellow cape is painted out below the lion pelt: the turnaround has none (the pelt hangs down his back).
- **Body:** as the turnaround draws him: magma arm, lion pauldron and greatsword on his RIGHT, the chain in his LEFT
  hand (the chain and its burning hook ride the left hand bone alone), the burning eye on his left. Posed into the
  contract rest pose; head x1.12 and both hands x1.2, girth x1.06 over the art; 15k triangles.
- **Face:** the portrait's face projected onto the front of the head (registered on the eyes and the mouth), before
  the paint-up so it takes the body's lift and warmth; the portrait's orange rim light on his right cheek left out.
- **Magma:** the whole magma arm, and every face holding a hot orange texel (the eye, the hook's flame), on the
  `glow` slot as `glow-<texture>-hot`: the shader keys the emission per texel (`glow_key`), so the cracks glow and
  the rock between them doesn't.
- **Greatsword:** `weapon`, unskinned, in the Gun node's space: the side view's sword pixels as a 3.5 cm slab with the
  art painted on both faces (its rim one texel of the art's edge colour), the grip on the Gun's origin, the spine
  up, 0.8 m pommel to tip (x1.42, the heavy class's weapon scale, in game). `anchor_fuller` sits on the blade's eye,
  `anchor_weapon_tip` at its end. Its own texture (zedran_sword.jpg).
- **Texture:** Meshy's base colour, flattened toward the sheet's colours within each UV island only, lifted
  (gamma 0.8, a warm tint) and the skin pulled warm (the dark skin read blue-black under the toon shadow tint).
- `zedran.glb.import`: `generate_lods=false`, `force_disable_compression=true`.

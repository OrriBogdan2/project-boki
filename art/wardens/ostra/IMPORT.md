# Ostra: import note (ART-1, 2026-11-05)

`ostra.glb` is rebuilt from scratch in Blender by script on the shared armature (no Meshy scan left in it): 16.2k tris, the orb and its
swirl skinned on `x_weapon` (item 76b), 36 hand-keyed clips. References: ext/imagegen docs/art/gen/wardens_r2 (OSTRA_REFS.md,
ostra_head_sheet, ostra_mask_sheet, ostra_cap_halo_sheet, ostra_front_float).

    blender -b --factory-startup --python tools/art1/ostra_build.py            # ~/art1/ostra/ostra.blend (OSTRA_WORK moves it)
    blender -b ~/art1/ostra/ostra.blend --python tools/art1/ostra_anim.py -- all --export art/wardens/ostra/ostra.glb
    godot --headless --path . --import

- **Mask:** `tools/art1/ostra_mask.py`, a height-field sculpt on an egg, decimated to 4.5k tris; `ostra_paint.mask_textures` paints its light,
  cracks, tear and teeth from that same height field (`ostra_mask.jpg`, `ostra_mask_emit.jpg`). It moves: `x_jaw`, `x_brow.*`, `x_cheek.*`
  (the bones deform the porcelain) and `x_lid.*` (the eyes narrow).
- **Body:** `tools/art1/ostra_parts.py`, lofts and sweeps with their own texture patch: coat, torn skirt with its Void lining, collar points,
  ruff, cap with spring-hung horns and bells, long hands with `x_fing<n>`, `x_fing<n>b`, `x_thumb`, `x_thumbb`.
- **Wisp:** a twisted rope and three strands on `spring_wisp_*`, `void-wisp` (fades by its v, so `ostra_wisp.jpg` is its own image).
- **Halo:** the violet crescent on `x_halo`, leaned back 19 degrees so the match camera sees its face; `glow-halo`.
- **Clips:** `tools/art1/ostra_clips.py` (keys), `ostra_pose.py` (hands by target, two-bone IK, fingers, face), `ostra_anim.py` (samples at
  60 fps, one action per clip). `content/rules/warden_anim/ostra.json` maps them; `rig_root` keeps the root bone on the Rig so his hover and the
  kit's lifts, squashes and turns stay under the clips.
- Imports: atlases lossless (`compress/mode=0`); `ostra.glb.import`: `animation/fps=60`, `remove_immutable_tracks=false`, `generate_lods=false`,
  `force_disable_compression=true`.

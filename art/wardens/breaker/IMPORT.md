# Breaker (bulwark, was Bjorn): ART-1 rebuild

`breaker.glb` is built entirely by script in Blender 4.5, with no scan and no hand-edited geometry: an SDF sculpt on voxel
grids, surface nets, a decimate to the game mesh, a per-texel paint that samples the sculpt, and hand-keyed clips.
Art: docs/art/gen/wardens_r3/breaker_front, _head_sheet, _hammer_sheet, _shield_sheet, BREAKER_KIT.md (ext/imagegen).

    godot --headless --path . --import                   # once in a fresh worktree
    godot --headless --path . -- --warden-rig-json --warden=bulwark --out=res://art/wardens/src/breaker_rig.json
    blender -b --factory-startup --python tools/art1/breaker_art1.py -- WORK                 # sculpt, mesh, atlas, skin
    blender -b WORK/breaker_art1.blend --python tools/art1/breaker_anims.py -- WORK/breaker_anims.blend art/wardens/breaker/breaker.glb
    godot --headless --path . --import

- **Files:** tools/art1/sculpt_kit.py (SDFs, surface nets, texel raster; nothing Breaker-specific), breaker_sculpt.py (the
  shapes), breaker_paint.py (the paint), breaker_art1.py (meshes, UVs, armature, weights), anim_kit.py (keys -> IK -> baked
  clips), breaker_anims.py (the clips), art1_render.py (review turntables and sheets).
- **Budget:** under 20k triangles with hammer and shield (--warden-clips-check holds it). One 2048 atlas, eight slots.
- **Skinned weapon (76b):** the hammer is its own mesh `hammer`, skinned 100% to `x_weapon` (a child of hand.R), so it moves with
  the hand in every clip. `weapon_muzzle` sits on the block, `anchor_hammer_grip`, `anchor_hammer_head`, `anchor_weapon_tip`
  and `weapon_thrown` ride the bone. While the hammer is thrown the bone scales to zero and the kit flies a plain copy of
  the same mesh (WardenGlb.thrown_piece). The shield is skinned to `x_shield` (hand.L) in the body mesh; the empty `shield`
  only tells the loader to hide the procedural prow.
- **Hold:** the art's mirror: hammer in the right hand across the right shoulder, the prow at the left side (the rig's
  sides), so the compass moves to his left and the teddy to his right hip as the art has them against the weapon.
- **Bones beyond the contract:** content/rules/warden_anim/breaker.json `extra_bones`; springs spring_braidR/L/C_*, spring_apronF/B_*,
  spring_teddy_*.
- **Size:** body.size stays 1.335 (1.5x a medium hunter), body.build 1.18 -> 1.4 so the arms hang clear of the belly and
  the silhouette has the art's width; hit radius unchanged.

# Breaker, the Sunken Bulwark (bulwark): ART-1 rebuild on the final design

`breaker.glb` is built entirely by script in Blender 4.5: SDF sculpt on voxel grids, surface nets, a decimate, a per-texel paint that
samples the sculpt, and hand-keyed clips. No scan. Art: briefs/art-refs/breaker_FINAL_sheet (master, expression row), breaker_turnaround,
breaker_weapons (shape only). The menu splash and portrait (art/portraits/bulwark*.jpg) are crops of breaker_splash.

    godot --headless --path . --import                   # once in a fresh worktree
    godot --headless --path . -- --warden-rig-json --warden=bulwark --out=res://art/wardens/src/breaker_rig.json
    blender -b --factory-startup --python tools/art1/breaker_art1.py -- WORK                 # sculpt, mesh, atlas, skin
    blender -b WORK/breaker_art1.blend --python tools/art1/breaker_anims.py -- WORK/breaker_anims.blend art/wardens/breaker/breaker.glb
    godot --headless --path . --import

- **Files:** tools/art1/sculpt_kit.py (hero-independent), breaker_sculpt.py (shapes), breaker_paint.py (paint), breaker_art1.py (mesh, UVs,
  armature, rigid weights), anim_kit.py (keys -> IK -> baked clips), breaker_anims.py (clips), art1_render.py (Cycles review).
- **Body:** content/archetypes/bulwark.json body: legs 0.46, torso 1.06, shoulder 1.15, build 1.4, head 0.3, size 2.0: the rig's arms are a
  fixed length, so the art's proportions need a 1.03 m neutral body; size 2.0 keeps the helmet's top at 1.5x a medium hunter. The masts stand over
  that (1.9x). The hit radius stays 0.46 (docs/HITBOX_SIZE.md): the hull's own half width is 0.95 m.
- **Paint:** hull from the fitted Meshy scan (tools/art1/breaker_scan.py, nearest surface; a decimated scan cracks), arms and legs projected from breaker_turnaround, helmet from breaker_head_squat, door from breaker_weapons.
- **Budget:** under 15k triangles, weapon and shield included (S1). Rivets are painted, not modelled, and each part's game mesh is cut from a low-passed copy of its field (`blur`): a decimate left to the detail spends everything there and collapses the big forms.
- **Pieces are rigid**, each on its bone, overlapping at the joints. Glow: `leather-wood-hot` keys per texel to archetype model_glow.
- **Weapon (76b):** mesh `hammer` skinned to `x_weapon`; `anchor_hammer_head`, `weapon_muzzle`, `anchor_hammer_grip`, `weapon_thrown` on it. The hold
  whirl seeks from the kit's angle (WardenClips.PHASE). Mirrored from the art: hammer in the right hand, shield in the left (the rig's sides).
- **Mood and fish:** scripts/heroes/warden_mood.gd + shaders/warden_mood.gdshader, data in warden_anim/breaker.json "mood". Fish on spring_hangfish_*, cosmetic.
- **Smash arm (11-09, no Blender):** after the bake, `lmb_slam` has the upper arm pitched up so the hammer head lands on the ground 2.45 m out, not 0.6 m under it (`--strike-reach-check`): `python3 tools/art1/glb_bone_turn.py art/wardens/breaker/breaker.glb lmb_slam upper_arm.R 0.91,0,-0.42 36 0.0:0.067:0.2:0.3`, then `godot --headless --import`.

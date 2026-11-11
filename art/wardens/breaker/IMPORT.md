# Mossy, the Barnacle Knight (bulwark): ART-1 v2 on mossy_v2

`breaker.glb` is the Meshy scan of `briefs/art-refs/mossy_v2/mossy_v2_turnaround.jpg` (hull, moss, arms and legs, retopo 9k, refit to the rig)
plus scripted parts: SDF sculpt on voxel grids, surface nets, a decimate, a per-texel paint, and hand-keyed clips. Art: mossy_v2_turnaround
(body, helmet, collar, compass, fists), mossy_v2_master_sheet (compass, cracks), breaker_weapons (hammer and hatch shield, shape only).
Meshy raw files stay in ~/meshy/breaker_v2 (not in git); the measured scan joints are art/wardens/src/breaker_scan_joints.json.

    godot --headless --path . --import                   # once in a fresh worktree
    godot --headless --path . -- --warden-rig-json --warden=bulwark --out=res://art/wardens/src/breaker_rig.json
    cp art/wardens/src/breaker_scan_joints.json WORK/scan_joints.json
    blender -b --factory-startup --python tools/art1/breaker_scan.py -- SCAN.glb art/wardens/src/breaker_rig.json WORK RETOPO.glb
    BOKI_ART_REFS=<briefs>/art-refs blender -b --factory-startup --python tools/art1/breaker_art1.py -- WORK   # sculpt, mesh, atlas, skin
    blender -b WORK/breaker_art1.blend --python tools/art1/breaker_anims.py -- WORK/breaker_anims.blend art/wardens/breaker/breaker.glb
    godot --headless --path . --import

- **Files:** tools/art1/sculpt_kit.py (hero-independent), breaker_sculpt.py (shapes), breaker_paint.py (paint), breaker_art1.py (mesh, UVs,
  armature, rigid weights), anim_kit.py (keys -> IK -> baked clips), breaker_anims.py (clips), art1_render.py (Cycles review).
- **Body:** content/archetypes/bulwark.json body: legs 0.46, torso 1.06, shoulder 1.15, build 1.4, head 0.3, size 2.0: the rig's arms are a
  fixed length, so the art's proportions need a 1.03 m neutral body; size 2.0 keeps the helmet's top at 1.5x a medium hunter. The masts stand over
  that (1.9x). The hit radius stays 0.46 (docs/HITBOX_SIZE.md): the hull is no longer a ball (owner 11-08): `hull_scale` in breaker_scan.py tapers it, 0.55x wide at the waist to 1.0x at the shoulders, 0.7x front to back, for a hammer-bruiser V.
- **Paint:** body from the scan (albedo + normal baked from the dense scan; warm non-key texels capped below the glow key and shifted browner by `tame_warm`, the turnaround's wood is brown not red); helmet, collar, compass dial and fists projected from mossy_v2_turnaround (breaker_paint.py, 298 px/m at 1600 wide); door from breaker_weapons.
- **Budget:** under 15k triangles, weapon and shield included (S1). Rivets are painted, not modelled, and each part's game mesh is cut from a low-passed copy of its field (`blur`): a decimate left to the detail spends everything there and collapses the big forms.
- **Pieces are rigid**, each on its bone, overlapping at the joints. Glow: `*-hot` materials key per texel to archetype model_glow (the scan's cyan plank cracks are re-keyed by `hot()`, so they glow; the compass brass does not key); the helmet's port glass is `glow-lure`. `anchor_head_top` sits over the crown port.
- **Weapon (76b):** mesh `hammer` skinned to `x_weapon`; `anchor_hammer_head`, `weapon_muzzle`, `anchor_hammer_grip`, `weapon_thrown` on it. The hold
  whirl seeks from the kit's angle (WardenClips.PHASE). Mirrored from the art: hammer in the right hand, shield in the left (the rig's sides).
- **Mood and fish:** scripts/heroes/warden_mood.gd + shaders/warden_mood.gdshader, data in warden_anim/breaker.json "mood". Fish on spring_hangfish_*, cosmetic.

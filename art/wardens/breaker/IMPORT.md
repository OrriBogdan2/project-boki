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
- **Budget:** at most 25k triangles, weapon and shield included (RIG_CONTRACT; was 15k, S1). Rivets are painted, not modelled, and each part's game mesh is cut from a low-passed copy of its field (`blur`): a decimate left to the detail spends everything there and collapses the big forms.
- **Pieces are rigid**, each on its bone, overlapping at the joints. Glow: `leather-wood-hot` keys per texel to archetype model_glow.
- **Weapon (76b):** mesh `hammer` skinned to `x_weapon`; `anchor_hammer_head`, `weapon_muzzle`, `anchor_hammer_grip`, `weapon_thrown` on it. The hold
  whirl seeks from the kit's angle (WardenClips.PHASE). Mirrored from the art: hammer in the right hand, shield in the left (the rig's sides).
- **Mood and fish:** scripts/heroes/warden_mood.gd + shaders/warden_mood.gdshader, data in warden_anim/breaker.json "mood". Fish on spring_hangfish_*, cosmetic.
- **Revamp (owner 11-09):** 21.7k triangles (body 19.8k, hammer 1.9k). The hull is a fresh Meshy retopo of the same runA scan at 19k
  triangles (`meshy_task.py remesh ... --polycount 19000 --topology triangle`; the default quad topology triangulates to about 2x), down from 9.3k.
  `breaker_scan.py` bakes scan_albedo and scan_normal from runA onto it: `-- ~/meshy/breaker_v2/runA/glb.glb art/wardens/src/breaker_rig.json WORK
  ~/meshy/breaker_v2/remesh19kt/glb.glb` (WORK held scan_joints.json; this build is in ~/art1-breaker-v2/rv1109). The normal map imports
  VRAM RG (`compress/mode=2`, `compress/normal_map=1`), like the other revamped hunters. The anims export stays JPEG.
  Old vs new renders: docs/art/wardens/revamp/breaker/. A follow-up is to adopt ~/meshy/breaker_v2/full_1109, a full-body scan with
  the helmet, masts, sails and fish. It would mean re-splitting those scripted parts onto their bones.

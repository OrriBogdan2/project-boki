# Mossy, the Breaker (Albert, bulwark): v95 master with the appeal3 face (owner pick 11-10)

`breaker.glb` is the v95 swap (docs/art/wardens/V95_SWAP.md, spec `art/wardens/src/breaker_v95.json`) of Albert's v95 master
with the owner-approved appeal3 face (`~/meshy/v95/Albert/r2/appeal3/cand.glb`; Meshy files stay out of git) onto the
skeleton, the 48 hand-keyed clips and the anchors of the 11-08 build. `albert_v95_body.glb` there is cand.glb without its
copies of the hammer, the shield and the lure ball, which stay the game's: the `hammer` mesh on `x_weapon` and the old
hatch shield kept on `x_shield` (`keep`).

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/breaker_v95.json WORK OUT.glb
    cp OUT.glb art/wardens/breaker/breaker.glb
    godot --headless --path . --import

- **Fit:** the rig is as wide as the master and much shorter: the pelvis sits at the rig's hips (k 1, the girth stays), the
  torso squashes ~0.76 to the head bone, the helmet rides `head` whole. The masts and sails ride `hips`; they stand ~1.7 m,
  over the helmet as before. 13.8k body triangles in one 2048 atlas; `relax` with no cuts, as the other v95 swaps (the
  cut pass shreds the torso).
- **Glow:** the cracks and lure glow from the master's emission map (`emit`), which WardenGlb tints to the bulwark
  model_glow; the lure ball is `glow-lure`.
- **Fish:** hangs from his left mast on `x_fish`; the spring chain `spring_hangfish_*` moved there with it (`move_bones`).
- **Face:** the porthole glass is `eyes-mood` with a flat disc UV (`screen`), so the baked face never shows: WardenMood swaps
  the material for shaders/warden_mood.gdshader, which draws the approved face (cyan rounded half-moon eyes, D smile, pale
  core, glossy teal glass) in its 5 moods. Mood data: warden_anim/breaker.json "mood".
- **Old build:** the 11-08 scan-and-sculpt build (tools/art1/breaker_scan.py, breaker_art1.py, breaker_anims.py,
  `art/wardens/src/breaker_scan_joints.json`) made the skeleton and clips this swap keeps.
- **Files:** tools/art1/sculpt_kit.py (hero-independent), breaker_sculpt.py (shapes), breaker_paint.py (paint), breaker_art1.py (mesh, UVs,
  armature, rigid weights), anim_kit.py (keys -> IK -> baked clips), breaker_anims.py (clips), art1_render.py (Cycles review).
- **Body:** content/archetypes/bulwark.json body: legs 0.46, torso 1.06, shoulder 1.15, build 1.4, head 0.3, size 2.0: the rig's arms are a
  fixed length, so the art's proportions need a 1.03 m neutral body; size 2.0 keeps the helmet's top at 1.5x a medium hunter. The masts stand over
  that (1.9x). The hit radius is 0.50 (DECISIONS: the heavy class's; docs/HITBOX_SIZE.md): the hull is no longer a ball (owner 11-08): `hull_scale` in breaker_scan.py tapers it, 0.55x wide at the waist to 1.0x at the shoulders, 0.7x front to back, for a hammer-bruiser V.
- **Paint:** body from the scan (albedo + normal baked from the dense scan; warm non-key texels capped below the glow key and shifted browner by `tame_warm`, the turnaround's wood is brown not red); helmet, collar, compass dial and fists projected from mossy_v2_turnaround (breaker_paint.py, 298 px/m at 1600 wide); door from breaker_weapons.
- **Budget:** under 15k triangles, weapon and shield included (S1). Rivets are painted, not modelled, and each part's game mesh is cut from a low-passed copy of its field (`blur`): a decimate left to the detail spends everything there and collapses the big forms.
- **Pieces are rigid**, each on its bone, overlapping at the joints. Glow: `*-hot` materials key per texel to archetype model_glow (the scan's cyan plank cracks are re-keyed by `hot()`, so they glow; the compass brass does not key); the helmet's port glass is `glow-lure`. `anchor_head_top` sits over the crown port.
- **Weapon (76b):** mesh `hammer` skinned to `x_weapon`; `anchor_hammer_head`, `weapon_muzzle`, `anchor_hammer_grip`, `weapon_thrown` on it. The hold
  whirl seeks from the kit's angle (WardenClips.PHASE). Mirrored from the art: hammer in the right hand, shield in the left (the rig's sides).
- **Mood and fish:** scripts/heroes/warden_mood.gd + shaders/warden_mood.gdshader, data in warden_anim/breaker.json "mood". Fish on spring_hangfish_*, cosmetic.

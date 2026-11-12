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

Walk and run loops (2026-11-11, merged 11-12 by ext/sfx-steps-dirloops): `walk_f`/`run_f` come from tools/art1/breaker_gait.py (a generated
stride, soles locked to the floor at 2.0 and 4.8 m/s, 2.7 and 3.2 steps/s, hammer carried clear of the floor), and the b, l, r, fl, fr,
bl, br loops from tools/art1/hunter_dir_gait.py (docs/art/wardens/dirloops/JUDGE.md):
`blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/breaker/breaker.glb OUT.glb 2.0 4.8 b,l,r,fl,fr,bl,br 0 0 2.0 2,1 55`
then `python3 tools/art1/glb_add_clips.py art/wardens/breaker/breaker.glb OUT.glb <the 16 walk_*/run_* names>`. They were baked on the 11-08
build; the v95 swap keeps that skeleton, so the 16 clips were copied onto the swap by node name (rest poses equal; no Blender here, the
swap was not re-baked). Their foot plants (`loco.plants`) are read off the clips by `--step-sync-check --plants-json`.

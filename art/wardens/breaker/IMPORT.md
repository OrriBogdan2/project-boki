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

- **Directional loops (ext/anim-dirloops-albert-neve):** `walk_*` and `run_*` (f, b, l, r, fl, fr, bl, br) are the clips of that branch, copied onto this
  build with `glb_add_clips.py ... --skip=spring_hangfish,x_fish` (the rig is the 11-08 one; main's build moved the fish chain to the left mast, so the
  old chain's keys are left out and the spring solver poses it). They were baked on the scan-and-sculpt model: walk_f/run_f with
  tools/art1/breaker_gait.py (a generated giant stride, soles locked at 2.0 and 4.8 m/s, 2.7 and 3.2 steps/s, hammer carried clear of the floor), the
  rest with `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- breaker.glb OUT.glb 2.0 4.8 b,l,r,fl,fr,bl,br 0 0 2.0 2,1 55`
  in step with walk_f/run_f (the walks take two steps a side in walk_f's time, his legs can't reach one; docs/art/wardens/dirloops/JUDGE.md).
  Re-run both on the v95 model in Blender when one is free; the legs and hips are the same rig, so the loops carry over as they are.

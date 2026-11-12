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

**Gait and directional loops** (ext/anim-dirloops-albert-neve, on the clips this swap keeps): walk_f and run_f from
`tools/art1/breaker_gait.py` (soles locked to the floor at 2.0 and 4.8 m/s), every other walk/run direction from
`tools/art1/hunter_dir_gait.py` (docs/art/wardens/dirloops/JUDGE.md); merged into this model with `glb_add_clips.py`:

    blender -b --factory-startup --python tools/art1/breaker_gait.py -- breaker.glb WORK/breaker_gait.glb
    python3 tools/art1/glb_add_clips.py breaker.glb WORK/breaker_gait.glb walk_f,run_f
    blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- breaker.glb WORK/breaker_dir.glb 2.0 4.8 b,l,r,fl,fr,bl,br 0 0 2.0 2,1 55
    python3 tools/art1/glb_add_clips.py breaker.glb WORK/breaker_dir.glb walk_b,walk_l,walk_r,walk_fl,walk_fr,walk_bl,walk_br,run_b,run_l,run_r,run_fl,run_fr,run_bl,run_br

crouch_bl, crouch_br (2026-11-12, ext/anim-dir-all-1112): the recipe can't step his crouch (14 cm legs under hips 9 cm up:
`hunter_dir_gait.py ... crouch` plants no sole), so these are crouch_b turned 45 degrees into the move, the chest on the
source's facing: `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/breaker/breaker.glb
OUT.glb 1 1 "bl~,br~" 0 0 2.0 2,1 55 crouch`, then `glb_add_clips.py breaker.glb OUT.glb crouch_bl,crouch_br`. crouch_fl, crouch_fr (2026-11-12, ext/anim-loco-dir-kael-crouch): crouch_l and crouch_r turned 45 degrees into the move
(`hunter_dir_gait.py ... "fl~l,fr~r" 0 0 2.0 2,1 55 crouch`, then `glb_add_clips.py breaker.glb OUT.glb crouch_fl,crouch_fr`,
data crouch.walk fl/fr). The same turn of crouch_f does not carry a front diagonal (it barely plants). Forearm.R of the
crouch loops (179..189 deg off its rest, the idle 177: Godot blends a bone as a turn off its rest, so every crouch start
and stop flipped the arm) is held at 177 by `python3 tools/art1/breaker_crouch_arm.py art/wardens/breaker/breaker.glb`
(the tracks only; the rest of the .glb stays byte for byte). A hand-made sneak is docs/DEBT.md.

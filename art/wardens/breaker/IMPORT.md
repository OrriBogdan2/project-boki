# Mossy, the Breaker (Albert, bulwark): v95 master with the appeal3 face (owner pick 11-10)

`breaker.glb` is the v95 swap (docs/art/wardens/V95_SWAP.md, spec `art/wardens/src/breaker_v95.json`) of Albert's v95 master
with the owner-approved appeal3 face (`~/meshy/v95/Albert/r2/appeal3/cand.glb`; Meshy files stay out of git) onto the
skeleton, the 48 hand-keyed clips and the anchors of the 11-08 build. `albert_v95_body.glb` there is cand.glb without its
copies of the hammer, the shield and the lure ball, which stay the game's: the `hammer` mesh on `x_weapon` and the old
hatch shield kept on `x_shield` (`keep`).

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/breaker_v95.json WORK OUT.glb
    python3 tools/art1/glb_prop_scale.py OUT.glb art/wardens/breaker/breaker.glb hammer x_weapon 1.012
    godot --headless --path . --import

- **Hammer:** the swap keeps the game's 0.84 m hammer on a taller body (crown 1.15 -> 1.28 m: 0.66 of his height), so
  `glb_prop_scale.py` scales it about the grip (x_weapon's origin, with its anchors) to 1.012 m, 0.79 of his height as on
  breaker_FINAL_sheet and breaker_weapons (`--warden-clips-check`). Uniform: the clips only turn x_weapon, so the hand
  keeps the grip and every swing its arc; the head keeps the mesh's own shape (its drum is thicker and its spikes
  shorter than on breaker_weapons: drum 0.46 against 0.33 of the length, spike span 0.59 against 0.63).
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
- **Albert feel pass (ext/albert-size-boop):** the swap in git was not re-run for it: its `shield_boop`, `x_wind` and `x_slam`
  clips (the boop, the Faultline hop) were copied from that branch's 11-08-build bake with no Blender
  (`python3 tools/art1/glb_add_clips.py breaker.glb <branch breaker.glb> shield_boop,x_wind,x_slam`), and their
  `spring_hangfish_0` translation set to this swap's constant (the fish moved to `x_fish`). breaker_anims.py holds the same
  keys, so a re-swap from a re-baked 11-08 build gives the same clips.

# Mossy, the Breaker (Albert, bulwark): v95 master with the appeal3 face (owner pick 11-10)

**11-14 i1 (live master):** the master is now `~/meshy/v95/Albert/r3/meshy1112/candidates/i1/glb.glb` (current.json since 11-12
20:35Z: angry porthole eyes, no drum or shield over the front; the scan has no hammer, shield or lure ball, so the whole glb is the
master). It starts from main's breaker.glb (the clean1 swap plus the x1.205 hammer): every moved point in the spec (`to`, the
anchors, the screen) is absolute, so nothing applies twice and the hammer, shield (`keep`) and clips come through untouched.
- **Cyan fix:** i1 has no emission map (its cracks are painted cyan), so `emit` baked the base colour as glow (PR #44's solid cyan).
  `emit_paint` makes the emissive texture from the baked atlas's cyan texels instead (h 0.44-0.56, s >= 0.35, v >= 0.55).
- **Face:** `screen_uvs` was lost from v95_swap.py in a merge before the clean1 swap, so since 11-11 the mood shader drew on atlas
  UVs: a blank teal porthole in game. Restored; shaders/warden_mood.gdshader now draws i1's face (pale-cyan eyes under a lid
  slanting to the middle, no mouth, near-black glass), the ring's copper past the glass edge so the porthole reads round.
- Model top 1.774x a medium hunter (i1's masts stand higher): `height_3d` 1.77 in warden_model_check. Shots and the compare
  sheet: `~/meshy/albert-ingame-i1-1114/`.

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/breaker_v95.json WORK OUT.glb
    (WORK/game.glb: main's breaker.glb from before this swap; the hammer is already at 1.012 m, no glb_prop_scale step)


**11-11 clean1:** the master is now `~/meshy/v95/Albert/r2/clean1/cand_A.glb` (masts pulled in to x 0.72, cleaned; job 20261111-172943-a4), as
`albert_clean1_body.glb` beside it (its mesh `body.001` only; the copies of the hammer, shield and lure ball dropped). Same spec and
steps; the game .glb the swap starts from is the pre-swap 11-08 one (`git show 8a738e4dd:art/wardens/breaker/breaker.glb` as WORK/game.glb).
Owner 11-11: too big, so `body.size` 2.0 -> 1.6. Shots: docs/shots/albert-clean1/.

`breaker.glb` is the v95 swap (docs/art/wardens/V95_SWAP.md, spec `art/wardens/src/breaker_v95.json`) of Albert's v95 master
with the owner-approved appeal3 face (`~/meshy/v95/Albert/r2/appeal3/cand.glb`; Meshy files stay out of git) onto the
skeleton, the 48 hand-keyed clips and the anchors of the 11-08 build. `albert_v95_body.glb` there is cand.glb without its
copies of the hammer, the shield and the lure ball, which stay the game's: the `hammer` mesh on `x_weapon` and the old
hatch shield kept on `x_shield` (`keep`).

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/breaker_v95.json WORK OUT.glb
    python3 tools/art1/glb_prop_scale.py OUT.glb art/wardens/breaker/breaker.glb hammer x_weapon 1.012
    # a changed clip after the swap (no WORK/breaker_art1.blend; the swap keeps the 11-08 skeleton): re-bake the clips on the
    # shipped .glb's armature and take back only the ones you changed (Albert's `land` was done this way on the v95 glb)
    blender -b --factory-startup --python tools/art1/glb_rebake.py -- art/wardens/breaker/breaker.glb tools/art1/breaker_anims.py WORK/re.blend WORK/re.glb
    python3 tools/art1/glb_add_clips.py art/wardens/breaker/breaker.glb WORK/re.glb land
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

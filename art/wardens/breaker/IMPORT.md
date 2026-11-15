# Mossy, the Breaker (Albert, bulwark): v95 master with the appeal3 face (owner pick 11-10)

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

- **Idle pilot (2026-11-11, ext/anim-pilot-four):** `idle` is now a Meshy animation-library idle (action 89, generated through Meshy's API on the Tarek rig, task 01a1c429-a8e4-75b0-943c-8f3e89f43a9a; licence: Meshy generated asset, our account) retargeted onto Albert's x_foot rig with his own arms carried from the old idle (pose and attitude stay his), 1.71 s played twice (3.42 s), seam 0.08 deg (was 4.2). Meshy can't auto-rig Albert, so the source is cross-rig. Blind judge (6-point pilot1 rubric): 4.8 vs the old idle 4.2. Walk/run unchanged (ext/anim-pilot-albert-neve). Recipe: `python3 tools/art1/glb_pick_clip.py <candidate.glb> <clip> <name> <tile> /tmp/x.glb`, then `python3 tools/art1/glb_add_clips.py <this glb> /tmp/x.glb <name>`. Candidate GLBs and renders: ~/anim/four (glb/, renders/blind/).

- **Walk/run (ext/anim-pilot-albert-neve, stacked):** the generated stride of tools/art1/breaker_gait.py (soles locked to the floor at 2.0 and 4.8 m/s in Blender). Not carried (2026-11-13): walk_f/run_f; `--anim-audit` on the game rig reads run slide 51% and the arms swing with their leg (-0.32) (main's own clip 11%, arms 0.68, limit 25%), so main's clip stays. The candidate is `walk_f`/`run_f` in ext/anim-pilot-four 37d910944's breaker.glb, to copy with `glb_add_clips.py --hold-moved-rest` once the in-game foot slide is fixed.
- Carried onto the v95 appeal3 swap by `python3 tools/art1/glb_add_clips.py <this glb> <ext/anim-pilot-four 37d910944 glb> idle --hold-moved-rest` (2026-11-13, merge of origin/main 18402df5b): the core bones' rest is identical between the two builds and main's old idle matched the judged ones, so the clips are the judged ones; the spring bones the new model moved (spring_hangfish_0) hold this model's rest in them, as every other clip does.
- **Directional loops (ext/anim-dirloops-albert-neve):** `walk_*` and `run_*` (f, b, l, r, fl, fr, bl, br) are the clips of that branch, copied onto this
  build with `glb_add_clips.py ... --skip=spring_hangfish,x_fish` (the rig is the 11-08 one; main's build moved the fish chain to the left mast, so the
  old chain's keys are left out and the spring solver poses it). They were baked on the scan-and-sculpt model: walk_f/run_f with
  tools/art1/breaker_gait.py (a generated giant stride, soles locked at 2.0 and 4.8 m/s, 2.7 and 3.2 steps/s, hammer carried clear of the floor), the
  rest with `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- breaker.glb OUT.glb 2.0 4.8 b,l,r,fl,fr,bl,br 0 0 2.0 2,1 55`
  in step with walk_f/run_f (the walks take two steps a side in walk_f's time, his legs can't reach one; docs/art/wardens/dirloops/JUDGE.md).
  Re-run both on the v95 model in Blender when one is free; the legs and hips are the same rig, so the loops carry over as they are.

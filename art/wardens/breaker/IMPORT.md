# Mossy, the Breaker (Albert, bulwark): v95 master with the appeal3 face (owner pick 11-10)

**11-16 superseded:** main's e3038a4866 (v95_to_game, all 13 hunters) re-made breaker.glb from the same i1 master with its own embedded paint, so the i1 swap below is history; the loose breaker_atlas/emit jpgs are main's. That glb has no `glow-lure` material, so --warden-clips-check's lure item is red on main and here (open).

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
- **Face (11-18, ext/hunter-picks-1118):** the porthole glass is `eyes-v95` (since 28d0f88bc3 the baked paint shows, not
  WardenMood's drawn glass face). The owner picked face A of ~/meshy/face-albert-1118 (`final_A.glb` = FhapS_1: fat cyan
  crescent eyes, modest smile) as the default, keeping the old angry eyes in game. `v95` here = the happy face A embedded by ext/faces-ship-1118 (tools/art1/face_swap.py, main's glb kept at the merge); the pre-face image is kept the old image is kept
  as `breaker_v95_angry.jpg` (import size limit 2048: 2.7 MB of VRAM). The master's new normal/roughness maps are not
  ported (this glb has albedo only). WardenMood's `tex_faces` (warden_anim/breaker.json "mood") puts the angry texture
  on the glass for angry/determined/sad and for `combat`: 4 s after he swings, casts or is hit; the smile otherwise.
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

The strikes lmb_slam and lmb_throw are keyed at 60 fps (`bake(fps=60)`; tools/art1/fine_export.py exports them at that rate and splices
them in), so the .glb.import keeps `animation/fps=60`. Clips only, with no raw files (the swap keeps the clips): import the shipped .glb in Blender
(bone_heuristic BLENDER, actions dropped, the armature named `Armature`) as WORK, run the clip script on it, and splice
the changed clips into the shipped .glb with `python3 tools/art1/glb_add_clips.py <shipped> <new> <clip,...>` (the
other clips re-bake byte-equal that way).

Face pass (2026-11-18, ext/faces-ship-1118, owner "upload all of these"): Albert's happy ^^ face A texture-only: `python3 -I tools/art1/face_swap.py <game glb> /home/boki/meshy/face-albert-1118/final_A.glb /home/boki/meshy/face-albert-1118/cand/LIVE.glb OUT.glb` blends the face-pass albedo changes into the embedded 4096 `v95` image (mesh, rig, clips, props untouched; the game glb has no normal/roughness map, so those face-pass maps are not used). The old angry paint stays as his fight face.

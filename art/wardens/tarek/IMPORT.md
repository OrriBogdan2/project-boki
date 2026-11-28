# Tarek (dolm): import note, v95 swap of Tarek appeal3, candidate b (2026-11-11)

`tarek.glb`: Tarek's v95 r2 appeal3 `cand_b.glb` (a new warm-brown face with a gentle smile and a firmer jaw, plus a
waist taper, from `briefs/art-refs/tarek_v2/` only) swapped onto dolm's own skeleton, clips and anchors by
`tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with `art/wardens/src/tarek_v95.json`. Raw files in
~/meshy/v95/tarek/r2/appeal3 (never in git; `cmp.png` is the current-vs-cand_b sheet, `pick.txt` the pick and why); the
spec reads `tarek_v95_b_body.glb`, which is `cand_b.glb` without its three floating eye stones (the game's own
`stone_0-2` stay).

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/tarek_v95.json WORK art/wardens/tarek/tarek.glb

The appeal pass: the face is a texture-only edit (one Meshy edit of a flat head render, projected back onto the master's
head with the baked position and normal maps); the body moves positions and normals only (topology and UVs identical to
the v95 master), a V-taper at the waist (max move 2 cm). The v95 body already matched the turnaround within ~1 cm.

HY-Motion pilot 2 (NOT applied to the v95 glb): the branch baked `idle` and `walk_f` from HY-Motion-1.0-Lite clips into the old 13k-tri
tarek.glb. To redo it on the current glb: `python3 tools/art1/glb_swap.py G CLIPS.glb G hy_idle_s2:idle:loop` (see the script header).
Licence: tencent-hunyuan-community excludes the EU, UK and South Korea; legal signs off before these ship.

Body: 13k triangles (head 3.2k), one 2048 atlas embedded (Godot extracts it to `tarek_atlas.jpg`; the old
`tarek_tarek_atlas.jpg` and `tarek_tarek_emit.jpg` are gone). No emission map (`"emit"` off): the master has none.
Slots by colour, bone and box (first match wins): hair (the locs, box z >= 1.3, dark), cloth (dark trousers, the sash),
metal (the stone arm and gauntlet, grey), cloth (saturated orange sash; the cream blindfold and wrap), skin (the rest).
Weights: bone heat from the spec's joints, limbs on the rig's own segments (`spread: "rig"`); the head box takes the
head, the hips box the cloth and trousers, the pauldron box the stone shoulder. The spec's neck joint sits at z 1.58 (the
head box's line): at 1.5 the master's head took the rig's low neck at full body scale and stood 1.157x a medium hunter
against the sheet's 1.08x; now 1.106x (`--warden-model-check` allows 4%).

Kept from the old build: the three floating eye stones (`stone_0-2`, halos on `anchor_stones_0-2`), the fist shards
(`shard_0-4`) and the ground rings, as separate nodes, untouched, with their anchors and `far_hide` in warden_look.json.
`anchor_head_top` and `anchor_chest` move onto the new mesh (the spec's `anchors`).

**Stone arm:** the master carries it on his LEFT, as the v2 turnaround does. It sits in the `metal` slot (grey toon);
alternative not taken: the `leather` slot (emission 1.8, the old build's stone slot).

**Known gap:** the old build's jade glyphs glowed (an emission map keyed from the atlas, tinted by dolm.json
`model_glow`); the master's arm has no glyph paint to key, so the arm is plain grey stone and the glow now comes only
from the kit FX on the anchors. Follow-up: paint the glyphs on the master's atlas and set `"emit": true`.

Clips: the 48 clips of the v2 build, unchanged (the swap keeps the game rig).

`tarek.glb.import`: unchanged.

Shots on the game rig (`--warden-shots`): docs/shots/tarek-appeal/ (before_after.jpg first).

Checks (2026-11-11): `--warden-glb-check` 183/0 failed, `--warden-model-check` 157/0 failed. `--stretch-check
--wardens=dolm` still flags all 48 clips (worst 19.5x in fuse, run_f 10.0x, idle 5.0x, mostly the thighs and hips;
skin_relax's own worst edge 19.4x after 59 passes): not under 1.3x, as for Kael and Grimble. No tearing, arm or
chest clipping shows in the turnaround, idle, run or kit poses.

## Re-swap on the current rig (2026-11-11, patch 0.24.6)
The appeal3 swap above was made on a pre-IDLE_AUDIT tarek.glb, whose clips had no `x_breath` bone, so on current main
`--warden-glb-check` rejected it ("variant bone x_breath missing") and Tarek fell back to the procedural model. Re-swapped
with the same spec (`art/wardens/src/tarek_v95.json`) onto main's tarek.glb as the rig input (fresh WORK): same master,
12999 tris, 48 clips, `x_breath` kept.

## Stone arm A look (2026-11-13, job 20261113-153317-a4)
Owner-approved A look for the stone arm, shoulder plates and bracer: V1 blue slate with teal runes. The colour was graded from
Meshy retexture gen 1 (the only gen used) onto the original UVs. Lab LUT: L is quantile-matched and the median is recentred
on the A swatch [62,78,85]. Runes are masked out and keep their emission.
- The game glb splits the `metal-atlas` primitive in two. 141 tris keep `metal-atlas` (tarek_atlas.jpg, byte-identical).
  The 1359 arm tris move to the new material `metal-slate`, a copy of metal-atlas whose albedo is `tarek_slate.jpg`
  (the graded 2048 atlas). `warden_glb.gd` reads the slot as the slice before "-", so `metal-slate` is set up exactly
  like metal. A separate image is needed because a JPEG edit of the shared atlas spills chroma into the hair, skin and cloth islands.
- Proof: Blender Workbench flat-texture renders, old vs new, 4 views. 0-3 px changed outside the slate prim.
  Face, skin, sash, beads, hair and trousers are unchanged. On the site master, head_diff is [].
- Re-running `v95_swap` on this rig drops the split. The recolour scripts (grade.py, gamesplit.py, armprim.py) and their
  inputs are in /home/boki/meshy/tenzo-arm-3d-1113/ (NOTES.md, work/).

walk and run b, l, r, fl, fr, bl, br (2026-11-11): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/tarek/tarek.glb OUT.glb 2.2 5.0`,
then `python3 tools/art1/glb_add_clips.py art/wardens/tarek/tarek.glb OUT.glb walk_b,walk_l,walk_r,walk_fl,walk_fr,walk_bl,walk_br,run_b,run_l,run_r,run_fl,run_fr,run_bl,run_br`
(judge: docs/art/wardens/dirloops/JUDGE.md).

Merge of origin/main (2026-11-13): tarek.glb is main's v95 model; the 16 walk/run clips (f, b, l, r, fl, fr, bl, br; pilot-length rings, pelvis on the forward loop) were put back with `python3 tools/art1/glb_add_clips.py art/wardens/tarek/tarek.glb <branch glb> walk_f,...,run_br` (same rig, rest pose checked equal).

The strikes lmb_punch and lmb_throw are keyed at 60 fps (`bake(fps=60)`; tools/art1/fine_export.py exports them at that rate and splices
them in), so the .glb.import keeps `animation/fps=60`. Clips only, with no raw files: import the shipped .glb in Blender
(bone_heuristic BLENDER, actions dropped, the armature named `Armature`) as WORK, run the clip script on it, and splice
the changed clips into the shipped .glb with `python3 tools/art1/glb_add_clips.py <shipped> <new> <clip,...>` (the
other clips re-bake byte-equal that way).

NOT APPLIED on main (11-16 merge): the diagonal and re-baked back/side loops (walk_/run_ fl fr bl br, b l r) described here were baked into the old model's glb with a walk_f/run_f of a different length than main's v95 clips, so main's glb and warden_anim json are kept. Re-bake: `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- SRC.glb OUT.glb WALK RUN` on main's glb, then `glb_add_clips.py`, then restore the json map from ext/anim-dirloops-lace-kael.

## Native albedo grade (2026-11-24, job 20261124-163412-a1, round 28 "H")
`tarek_meshy.glb`: only the bytes of image `Image_0` (base colour, bufferView 1) changed; the other 1033 bufferViews
(mesh, UVs, skin, 6 clips, Image_1/Image_2) are byte-identical. `tarek_meshy_Image_0.jpg` = the same jpg.
Per-region HSV grade on the original UVs, regions baked from the skin weights (left-arm bones = stone, legs = pants,
head dark texels = hair): stone hue +14 deg S x1.15 V x1.2 (runes untouched), pants V x1.4 S x0.6 toward H 346 (plum),
hair V x1.6 to H 22 S x0.6 (dark brown), skin S x0.65 V x0.88 (sash S > 0.58 untouched). Measured at the game's eye view
(idle f010): chest S 0.92 -> 0.73, pants V 0.25 -> 0.45 (plum), hair V 0.18 -> 0.22 brown. Four Meshy retextures with
--original-uv (60 credits) came back with live's colours (stone S 0.35 V 0.36), so they were not used.
Scripts, region map and renders: /home/boki/gens/hunter-round-1124/tenzo/A/ (grade.py, swap.py, masks.py).

## Clip offsets + skin islands (2026-11-24, job 20261124-202920-a1, round 29)
`tarek_meshy.glb`: Image_0 bytes plus the float32 values of 28 rotation-key accessors changed (same accessors, same
lengths, glTF JSON identical); mesh, UVs, skin weights, Image_1/2 byte-identical.
- Clips (C/clip_offsets.py, spec C/b4.json): RightArm -14 / LeftArm +13 deg abduction about the chest's forward axis in
  Idle/walk/run/Jump_Run/Crouch (LeftArm +17 in walk, RightArm -20 in Jump_Run); RightHand slerped 50% to rest
  (wrist no longer bent back into the hip); thighs spread 6/8 deg (gait) and 6/16 deg (crouch) about the hips'
  forward/up axes; Attack: arms spread in the wind-up (0.55-0.95 s), forward in the smash (1.08-1.9 s), neck back 12.
  geo_check: worst clip 13.2 -> 5.8 cm, held worst 13.2 -> 3.0 cm, clipping frames 154 -> 47.
- Skin islands: round 28 skipped skin skinned to LeftShoulder/LeftArm (left pec, left shoulder blade) and dark bare-arm
  skin; C/fix_islands.py gives those 20.8k texels the same grade (S x0.65, V x0.9). Sash untouched.
Scripts, specs, renders: /home/boki/gens/hunter-round-1124/tenzo/C/.

### Round 30 (2026-11-24, job 20261124-233706-a1): game-crouch arms, Attack arc, crotch plum
- The game plays crouch with the WALK clip's arms (warden_native.json `crouch_arms_from`), so crouch arm fixes go in
  `walk`. Measured on the game's crouch (gens/hunter-round-1124/tenzo/D/crouch_game.py): stone hand in thigh held
  7.5 cm (round 29) -> 1.5 cm. Offsets D/z5.json via C/clip_offsets.py (rotation floats only): walk LeftArm +15,
  RightArm -5 deg abduct; run/Jump_Run thighs +3 deg spread; Attack stone arm lowered out in the wind-up (clear of the
  head), both arms swung apart in the smash (palms no longer inside the other forearm).
- Image_0: dark/grey inner-crotch pants texels lifted to the outer plum (D/crotch.py, 66.6k texels, V 0.36 -> 0.40).

### Round 32 (2026-11-25, job 20261125-083305-a1): seeing-stones teal glow
- `tarek.glb` (contract file; on the native path only its `orbit_stones` props are used): the `glow-tarek` eye disc on
  mesh `eye_stone` scaled x1.7 in its own plane (r 2.1 -> 3.5 cm; the rock's flat face reaches 5.3 cm). Only that
  POSITION accessor's floats + its min/max changed (1 of 5306 bufferViews; JSON padded to the same length).
  Tool: gens/hunter-round-1124/tenzo/F/disc.py.
- `warden_look.json` tarek `bloom` on anchor_stones_0-2 (WardenFx.bloom, world-sized additive puffs): dolm teal
  [0.36, 0.9, 0.72], alpha 0.40, 0.30 m, depth_test on (a stone turned away only rims; depth_test off washed the cobalt
  rock teal: rejected). Halos unchanged. The screen-sized halos alone sat inside the brighter cobalt rock (round 27+)
  and only lifted it to light blue at the long-lens judge view.

### Round 33 (2026-11-25, job 20261125-102228-a1): eyed seeing-stones, no bloom
Owner on r32: the bloom puffs were flat mint discs wider than the stones that washed over the body, and the stones read
as blank cups. So:
- `warden_look.json` tarek: the r32 `bloom` block is gone (halos kept as live, px 5.5, now sitting on the eye).
- `tarek.glb` mesh `eye_stone` (stone_0-2 share it) is now the Meshy eye-rock of job 20261120-053503-a6 (m4 retexture
  pick, 5480 tris; game copy from ext/tenzo-eye-rocks-1120): cobalt cracked slate, almond eye with a slit pupil.
  Turned 180 deg about Y (its eye faced +Z; the seeing-stone eye is -Z, warden_orbits._face), 0.17 m tall, material
  `leather-eyerock` (base jpg + eye-only emission mask, embedded; Godot extracts `tarek_eyerock_{base,emit}.jpg`).
  The new primitive, images and material are APPENDED: all 5306 old bufferViews are byte-identical (the old rock and
  disc accessors are left unused). Not decimated: Blender collapse tore the UV seams; Godot's import LODs thin it at range.
- Ring: stone_0-2 translations x/z x0.72, y +0.08 m (the front stone sits at the chest at the match camera, not on
  the belly/bare hand). anchor_stones_0-2 moved onto the eye's front.
- Look slot `leather-eyerock`: desat 0.45, albedo 1.2, emit 5.0 (the emission is a mask in dolm's model_glow teal, the
  same teal as the arm runes).
- Rejected: ring tilted 25/35 deg (front up) turns the back stones' eyes away (eye.camera median 0.78 -> 0.56/0.43);
  ring x0.6 +0.2 m puts the front stone over the face.
Tools: gens/hunter-round-1124/tenzo/G/scripts/{swap_rock,ring,slot,eyepitch}.py. Sheets: G/GAME_tenzo_r33_*.jpg.

## r47 (2026-11-28): sash material split + stones lowered
- tarek_meshy.glb: the sash faces (19,467 of 79,978; orange texels in the hip box) moved into a 2nd primitive with
  material `Material_0-sash` (same verts, UVs, skin, textures; only the index order changes, +368 B). The hero-toon pass
  blew the sash out to value 1.0 / sat 0.95 at the match camera; the one "Material_0" let warden_look tune only the
  whole body. Look slot `Material_0-sash`: albedo 0.85/0.85/0.83, desat 0.12, far_lift 0 (match sash value 0.81 -> 0.76,
  no clipped highlights; hue 16.5 vs ref 17.5).
- tarek.glb: stone_0-2 lowered 3 cm (y 0.63/0.67/0.59 -> 0.60/0.64/0.56) so `--warden-native-check` orbit_stones passes
  (0.78 m from the head, limit < 0.8).
Tools: gens/hunter-round-1124/tenzo/V/{split,stones}.py. Sheet: V/GAME_r47.jpg (art-gate 5.8 vs live 4.5, r43 5.5).

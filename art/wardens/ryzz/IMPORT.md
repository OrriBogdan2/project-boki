# Ryzz (ART-1 rebuild): how this model is made

## LIVE v95 master in game (2026-11-12, ext/hunters-v95-ingame)
`~/meshy/v95/Sparkle/r2/prop1111/cand_A.glb` (CURRENT_OVERRIDES 11-12), on the rig before the underbust swap (95f0fef3e5^, so the move_bones deltas apply once). 13.2k tris, one 4096 atlas (head_uv 4), 45 clips.
Spec `art/wardens/src/ryzz_v95.json`; proof sheet ~/meshy/v95/_closeups/ingame-1112/sheet.jpg.

## v95 swap (2026-11-10, ext/sparkle-underbust2): the current ryzz.glb

The mesh is now the v95 master: Sparkle round 2, underbust variant c (owner pick) with the owner-approved round-2 face (r2/face_appeal2/cand_face.glb) merged in, kept on hetzner as ~/meshy/v95/Sparkle/r2/final/sparkle_final.glb. It was put on this rig with `tools/art1/v95_swap.py` and `art/wardens/src/ryzz_v95.json` (docs/art/wardens/V95_SWAP.md). The skeleton, the 38 clips and the anchors are unchanged; the anchors were moved through the fit, and the gum bone's rest is moved 3 cm up (`move_bones`) so the bubble sits on her lips. The model is 13.2k tris with one embedded 4096 atlas and no normal map. ryzz_atlas.jpg and ryzz_nrm.jpg belong to the build below. The first swap used a 2048 atlas with the face island at about 250 px, which smeared the round-2 face (lashes, freckles, heart); the redo uses `tex` 4096, `head_uv` 4.0 (about 850 px for the face) and `cage`/`ray` 0.02/0.06 (closes a bake miss on the forehead). Shots are in docs/shots/sparkle-appeal-final/.
Limits: the pigtails, rods and wire loops are rigid on their region's bone (spring_pig and the skirt bones are now unweighted). The rodlit tips are gone, so Kitefall's rod blaze is only the anchor_rod bloom. Lids, brows and fingers no longer move v95 geometry. The garter hoops stretch between the legs in run and dash.

## Previous build (ART-1)

Source art: briefs/art-refs/ryzz_FINAL_sheet.png (master), ryzz_turnaround_apose.png. Budget: 15k tris (14,368 here), a 2048 atlas + a 2048 relief normal map, 8 surfaces.

1. The turnaround's four views, Meshy image-to-image with the loose parts taken out (pigtails, rods, harness, wires, chain), then a multi-image scan: ~/meshy/ryzz_f (edit.sh, runA).
2. `tools/art1/ryzz_source.py`: scan -> contract rest pose; the head stays the scan's sculpt, the density on the face; hands cut at the wrist.
3. `tools/art1/ryzz_pieces.py`, `ryzz_paint.py`, `ryzz_finish.py`: rebuilt hair, pigtails on spring chains, hands (index/curl/thumb bones), harness, rods, wires, chain, gum, lids; atlas, skin, anchors.
4. `tools/art1/ryzz_clips.py`: 38 clips on the kit's timings (scripts/match/kmoves_vv.gd), content/rules/warden_anim/ryzz.json maps them.

The face and corset are projected from the art: the corset from the master (registered by its neon), the face from the first ryzz_head.png (git 3e988ae8 of ext/agent-briefs, her grin; kept as ~/meshy/ryzz_f/ryzz_head_nogum.png, because the later sheet paints the bubble and the bubble is geometry here).

Run it all with INSTALL=1 ~/meshy/ryzz_f/build.sh [source]. No weapon: fingertips carry the FX points (weapon_muzzle, anchor_finger_L); rods anchor_rod_0..3.

v95 swap 11-12 (ext/hunters-v95-ingame): re-baked with `fill_misses` (docs/art/wardens/V95_SWAP.md), which fills the
texels the bake missed (exact black where the decimation folded a triangle under) from their neighbours.

## Pigtail graft (2026-11-15, ext/sparkle-hair-1115): Meshy pigtails on the live model
Owner 11-15: the in-game hair "goes out too far and isn't wavy enough". Only the pigtails change: the live ones are cut from `Body`
(hair-atlas faces outside |x| > 0.085 or below z 1.56) and Meshy-made wavy ones (a multi-image-to-3d bust from four head crops of
the v2 turnaround) are grafted on by `tools/meshy/pigtail_graft.py` (`art/wardens/src/ryzz_pigtails.json`): aligned to the head, sheared in
toward the neck, graded to the live palette, remeshed to 1.5k tris a side, baked into free atlas rectangles, skinned to `head`. Face, body,
chest, backpack, rig and clips are untouched (the same file through Blender's glTF export); the pigtails stay rigid on the head bone.
13.9k tris (live 13.2k). `ryzz_atlas.jpg` is Godot's extract of the new embedded atlas.
Re-run 11-15 on main's glb (main moved at bfae359ad9: Sparkle's idle/clips): `pigtail_graft.py` on main's current ryzz.glb, then
`python3 tools/art1/glb_add_clips.py <graft.glb> <main ryzz.glb> =<every clip> <out.glb>` (Blender's export resamples the clips; this puts
main's 45 clips back byte for byte: same names, key counts and values) and `python3 tools/art1/glb_compact.py <out.glb> ryzz.glb` (drops the
resampled clips' leftover data). Nothing but the pigtails differs from main's glb.

Idle/run pilot (2026-11-11, ext/anim-pilot-four), licence for both: Meshy generated asset, our account. Sparkle's Meshy rig is 01a1c8ac-ed6a-7214-a6e0-3250ea3170f7, auto-rigged from her static mesh at height 1.9. `idle` is now animation-library action 89 (task 01a1c8ad-9df6-7391-bae2-a82e739cf522), retargeted with feet planted, 1.71 s played twice (3.42 s), seam 0.14 deg; blind judge 4.8 vs the old idle 2.8. `run_f` is now the rig's own running clip, retargeted at 1.11x with feet planted at 4.55 m/s and her arms carried from the old run_f, 0.62 s, seam 0.04 deg; judge 4.5 vs 4.0. The rig's walking candidate lost (3.0-3.2 vs 4.0), so walk_f is unchanged. Recipe: `python3 tools/art1/glb_pick_clip.py <candidate.glb> <clip> <name> <tile> /tmp/x.glb`, then `python3 tools/art1/glb_add_clips.py <this glb> /tmp/x.glb <name>`. Candidate GLBs and renders: ~/anim/four (glb/, renders/blind/).


Carried onto the v95 swap by `python3 tools/art1/glb_add_clips.py <this glb> <ext/anim-pilot-four 37d910944 glb> idle --hold-moved-rest` (2026-11-13, merge of origin/main 18402df5b): the core bones' rest is identical between the two builds and main's old idle matched the judged ones, so the clips are the judged ones; the spring bones the new model moved (spring_pig*, gum) hold this model's rest in them, as every other clip does.
`run_f`: Not carried (2026-11-13): the pilot run_f above; `--anim-audit` on the game rig reads run slide 97% (sole sweep 1.03 m/s at a 4.83 m/s run) (main's own clip 9%, limit 25%), so main's clip stays. The candidate is `run_f` in ext/anim-pilot-four 37d910944's ryzz.glb, to copy with `glb_add_clips.py --hold-moved-rest` once the in-game foot slide is fixed.

Merge 11-15 (ext/merge-lane-anim-hard2-1115): main's glb (45 clips, idle, pigtails) with only the key-pose-read `lmb_l` put back from the branch (`glb_add_clips.py <main ryzz.glb> <branch ryzz.glb> =lmb_l`, then `glb_compact.py`); the other 44 clips are main's byte for byte.

Doll pass A (2026-11-18, ext/sparkle-dollA-game-1118, owner pick): `/home/boki/meshy/sparkle-doll-1118/A_face_skin_bust_hips.glb` (new face with smirk, violet-magenta eyes, matte skin; bust -14%, thighs -7%, hips -3%; same tris/UVs as the v95 `cand_A.glb`) swapped in with `python3 tools/art1/v95_to_game.py` (keep_uv own-paint swap, spec `art/wardens/src/ryzz_v95.json`, 60k tris; work dir `~/meshy/v95/_ingame_doll1118/`). Rig, 49 clips and anchors kept from the previous glb; `ryzz_v95.jpg`, `ryzz_v95b.jpg`, `ryzz_v95c.jpg` are the new textures. Height unchanged (y -0.014..1.684 vs -0.014..1.685).

Gum onto the lips (2026-11-20, ext/ryzz-gum-mouth, owner 11-20 "why is sparkles gum still on her forehead?"): doll pass A
put a face ~12 cm lower than the old one onto the kept rig, and the kept bubble (bone `gum`, 138 vertices skinned whole to
it, child `anchor_gum`) stayed where the old lips were: on her hairline in every clip (it shows at 0.72 scale in idle/run,
grows to 1.25 in `gum`, the laugh emote and `mage_gum`). `python3 tools/art1/glb_prop_move.py ryzz.glb ryzz.glb Body gum
0 1.419 -0.119` puts the bone's head (glTF metres, Y up) just behind her lips (bubble from the lips, as on the splash); its
inverse bind and the 47 clips' gum translation keys shift with it, nothing else changes. v95_to_game keeps a fixed-offset
`move_bones` out of re-runs, so a re-swap keeps this spot; a new face needs the same step at its lips. The lid/brow/mouth
bones and `anchor_eye_glow` also sit at the old face's height, but no vertex is weighted to them and no look uses the anchor.

No-gum version (2026-11-20, ext/ryzz-gum-mouth, owner 11-20 "want TWO versions"): the look-only design variant
`ryzz_nogum` (`content/rules/warden_look.json` `"ryzz_nogum": {"hide_bones": ["gum"]}`, no .glb of its own) is this
same model with the `gum` bone shrunk away every frame (WardenSync), and no gum fidget (MageGum). Pick it with
`--warden-variant=ryzz_nogum`; shipping it as the default would move `hide_bones` onto `"ryzz"`.

## Meshy-native model (ryzz_meshy.glb), polish 2026-11-24 (ext/sparkle-native-polish-1124)
`meshy_native` in `content/rules/warden_native.json` draws her from this glb (blob 8a64d9b5666 before this round, 79,980 tris,
66 Meshy joints, 6 clips); `ryzz.glb` (the contract) is not drawn and not touched.

Source: the hybrid-rig round-1 pick `~/gens/meshy-skel-pack-1121/Sparkle/hybrid/Sparkle_hybrid_rig.glb` (Meshy rig task
`01a1fc24-71e6-70e7-9410-4a59826594ac` on the owner's doll pick A of 11-18), packed by
`tools/meshy/native_hunters/pack.sh ryzz RIG.glb DECIMATED.glb` (decimate 35 % head keep, graft, `native_pack.py
--max-tex=2048 --max-tex-maps=1024`; Image_0 head, Image_3 body, Image_6 face_donor base colour, 2048 px JPEG q90 4:2:0).

This round changes three images and the shirt tail's skin weights, nothing else (mesh, UVs, skeleton, inverse binds, clips,
materials and Image_0 are byte-equal to the live glb; `tools/art1/glb_image_swap.py` + a DCT-level splice):
- Image_3 (body), masks built by rasterising the glb's triangles into UV space with the vertex position / dominant bone as the
  selector, then a colour gate: copper (pack and torso back, plus the ribbed arm coils: local luma std > 0.03; 556,756 texels):
  value x0.75, saturation pulled into 0.58-0.70, hue +14 deg (texture mean V 0.66 -> 0.50, H 9 -> 23); boot leather (below
  y 0.27 m, not sole V < 0.10, not laces V > 0.55; 480,312 texels): V 0.25 -> 0.37, H 339 -> 3; fishnet: the smooth no-net band
  and a smudge in the right-thigh island refilled from the lattice above (shift found by line-mask matching, seam-cloned).
- Image_6 (face_donor): a pink bolt (H 331, S 0.54, V 0.83, 1.1 mm core, soft edge) under the character's left eye, placed by 3D
  position on the front-most surface only (3,901 texels). Both eyes and everything else untouched: the iris boxes plus 60 px
  are cmp-equal to live.
- Body prim JOINTS_0/WEIGHTS_0: the 3,031 shirt-tail verts below the knot (y < 1.02 m) ramp LeftUpLeg -> Hips, 0 % at the knot, 30 %
  at the tip, faded over 10 mesh rings. 50 % tore nothing but sank the tip into the thigh in Attack (1.6 cm from the axis);
  30 % keeps it 7.0 cm out.
Meshy retexture (original UV, 3 tasks, 45 credits, ids in docs/art/wardens/PIPELINE.md) kept the copper at the live level
(V 0.66-0.72) and the boots at 0.27-0.30, so it was not used.
The masks and scripts are in the job folder (`~/gens/hunter-round-1124/sparkle/tools/`: masks_body.py, grade.py, face.py,
tail.py, jpgsplice.py, assemble.py); rerun `assemble.py LABEL body.png face.png` for any new grade.

Limits: at the match camera (>= 8 m) the toon look's `far_lift` brightens the copper back to V ~0.92-0.98, so the grade shows in
the close views (copper vs skin value gap 0.08 -> 0.29 at eye level) and the boots, much less at the match camera; the look
(`content/rules/warden_look.json`) is the other lever and is not changed here. Scratch test (not shipped): `"far_lift": 0.0` in
`ryzz.painted` on top of this glb moves the copper-vs-skin value gap at the match camera from -0.10 / +0.03 (idle / run) to +0.15 / +0.16
(turnaround 0.22); it also changes every other colour on her at that range, so it is an owner call.

### Follow-up, same branch (glb b70b92c4333b, supersedes the tail and "clips byte-equal" lines above)
- Image_3: the two dark spots and the smear on the fishnet inner leg are covered with netting cloned from the outer side of the same
  leg (6,881 texels, 149 of 16,384 MCUs spliced). The copper and boot grades are unchanged from the round above.
- Shirt tail: LeftUpLeg -> Hips ramp as above with the fade at 0.03 (`tail2.py 0.30 0.03`); glbstretch is identical to live in all six clips (the
  first version stretched more than live in Jump and Crouch). JOINTS_0 is equal to live, only WEIGHTS_0 differs.
- Forearm rotation keys nudged 6-12 deg where a hand entered the body (`arm.py`): Attack L, Jump L and R, walk L. Frames deeper than 8 mm:
  Attack L 5 -> 0, Jump L 2 -> 0, Jump R 1 -> 0, walk L 2 -> 0. No other animation channel differs from live.
Scripts: `~/gens/hunter-round-1124/sparkle/o/tools/` (build.sh, tail2.py, arm.py).

### Round 1124o-2, same branch (glb 292acacd05df, supersedes the copper/boot grade lines above)
- Image_3: back to the live texels everywhere except the fishnet inner-leg fix from the follow-up above (DCT splice, 220 MCUs from the
  follow-up atlas, all other MCUs bit-exact live). This drops the copper pack grade and the red boot grade (the review flagged both as pixel
  recolours); they need an AI masked edit, which this round could not run (Meshy balance 6 credits, every edit HTTP 402).
- Side torso / armpit weights: the crouch and attack tears at bind x 0.09-0.22, y 1.17-1.28 come from LeftArm/RightArm + Spine02 weights next
  to Hips + Spine02 weights. Weights diffused along the welded mesh edge graph (10 iterations, 5 cm Gaussian fade around the stretched verts,
  top 4 kept). Stretched-edge frames (edge >3x bind and >6% height): Attack 10/42 -> 0/42, Crouch 16/16 -> 0/16, the other clips stay 0.
  Largest edge gain: Attack 26.7 -> 11.9 cm, Crouch 20.5 -> 12.3 cm. JOINTS_0/WEIGHTS_0 change only near the armpits.
- geo_check vs live: PASS; held clip frames 6 (live) -> 0, held worst 3.83 cm (follow-up) -> 0.4 cm.
Scripts: `~/gens/hunter-round-1124/sparkle/p2/tools/` (armpit_g.py, vis.py, ctree.sh, submit.sh).

### Round 1124o-3, same branch (glb d9e0dbfb1f55, 79,980 tris, on top of 292acacd05df)
- Image_3: copper pack, coils, bronze rods, shoulder straps and both boots repainted by Meshy nano-banana-pro edits of flat unlit views
  (A1, B2, C3, D2), projected back onto the atlas (z-buffer, diff masks) and spliced at JPEG MCU level. Image_0 to Image_2 and Image_4 to
  Image_6 are byte-identical; the face, eyes, hair, skin and top texels keep their old values.
- Attack: LeftArm/RightArm rotation keys bent around t .87 s and 1.8 s (`p3/atk/S6.spec`), so the forearms pass outside the head.
  geo_check worst 8.2 -> 1.8 cm, frames 25 -> 13. No other channel differs from 292acacd05df.
Scripts: `~/gens/hunter-round-1124/sparkle/p3/tools/` (views.py, proj.py, swap.sh, atk.py).

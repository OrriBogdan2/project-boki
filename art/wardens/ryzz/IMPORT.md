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

walk and run b, l, r, fl, fr, bl, br (2026-11-12, ext/anim-dir-all-1112): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/ryzz/ryzz.glb OUT.glb 1.22 3.87` (walk_f's and run_f's own planted sole speed), then `python3 tools/art1/glb_add_clips.py art/wardens/ryzz/ryzz.glb OUT.glb walk_b,walk_l,walk_r,walk_fl,walk_fr,walk_bl,walk_br,run_b,run_l,run_r,run_fl,run_fr,run_bl,run_br`. The ring is in step; `loco.stride` is gone and `foot_mps` is the ring's in-game sole median (docs/art/LOCO_DIR.md).

walk_ and run_ re-timed to 0.75 s (one length, one strike key) on 2026-11-12 (ext/anim-loco-dir-last): `python3 tools/art1/glb_add_clips.py --stretch art/wardens/ryzz/ryzz.glb walk_,run_ 0.75`; `loco.foot_mps` 1.11 / 3.47 -> 1.38 / 2.77 (measured on the sole), `loco.ring_start` 0.25.

v95 swap 11-12 (ext/hunters-v95-ingame): re-baked with `fill_misses` (docs/art/wardens/V95_SWAP.md), which fills the
texels the bake missed (exact black where the decimation folded a triangle under) from their neighbours.

# Ryzz (ART-1 rebuild): how this model is made

Source art: briefs/art-refs/ryzz_FINAL_sheet.png (master), ryzz_turnaround_apose.png. Budget: 15k tris, one 2048 atlas, 7 surfaces.

1. The turnaround's four views, Meshy image-to-image with the loose parts taken out (pigtails, rods, harness, wires, chain), then a multi-image scan: ~/meshy/ryzz_f (edit.sh, runA).
2. `tools/art1/ryzz_source.py`: scan -> contract rest pose; the head stays the scan's sculpt, the density on the face; hands cut at the wrist.
3. `tools/art1/ryzz_pieces.py`, `ryzz_paint.py`, `ryzz_finish.py`: rebuilt hair, pigtails on spring chains, hands (index/curl/thumb bones), harness, rods, wires, chain, gum, lids; atlas, skin, anchors.
4. `tools/art1/ryzz_clips.py`: 37 clips on the kit's timings (scripts/match/kmoves_vv.gd), content/rules/warden_anim/ryzz.json maps them.

Run it all with ~/meshy/ryzz_f/build.sh [source]. No weapon: fingertips carry the FX points (weapon_muzzle, anchor_finger_L); rods anchor_rod_0..3.

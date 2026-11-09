# Ryzz (ART-1 rebuild): how this model is made

Source art: briefs/art-refs/ryzz_FINAL_sheet.png (master), ryzz_turnaround_apose.png. Budget: ~25k tris (24,903 here, owner 11-09 revamp), a 2048 atlas + a 2048 normal map (the scan's bake plus the leather and metal relief), 8 surfaces.

1. The turnaround's four views, Meshy image-to-image with the loose parts taken out (pigtails, rods, harness, wires, chain), then a multi-image scan: ~/meshy/ryzz_f (edit.sh, runA).
2. `tools/art1/ryzz_source.py`: scan -> contract rest pose; the head stays the scan's sculpt, the density on the face; hands cut at the wrist.
3. `tools/art1/ryzz_pieces.py`, `ryzz_paint.py`, `ryzz_finish.py`: rebuilt hair, pigtails on spring chains, hands (index/curl/thumb bones), harness, rods, wires, chain, gum, lids; atlas, skin, anchors.
4. `tools/art1/ryzz_clips.py`: 38 clips on the kit's timings (scripts/match/kmoves_vv.gd), content/rules/warden_anim/ryzz.json maps them.

The face and corset are projected from the art: the corset from the master (registered by its neon), the face from the first ryzz_head.png (git 3e988ae8 of ext/agent-briefs, her grin; kept as ~/meshy/ryzz_f/ryzz_head_nogum.png, because the later sheet paints the bubble and the bubble is geometry here).

Run it all with INSTALL=1 ~/meshy/ryzz_f/build.sh [source]. No weapon: fingertips carry the FX points (weapon_muzzle, anchor_finger_L); rods anchor_rod_0..3.

Revamp (owner 11-09, ext/hunter-revamp-pz): ~25k triangles, face, hands and weapon kept denser, the 2048 normal baked from the dense Meshy raw (`warden_kit.bake_normal`, docs/art/wardens/PIPELINE.md "The ~25k revamp") and shipped as PNG beside the JPEG atlas. A fresh Meshy re-roll was compared and not used. Old vs new: docs/art/wardens/revamp/ryzz/. ryzz_source.py LOW_TRIS 21500, FACE_TRIS 4800.

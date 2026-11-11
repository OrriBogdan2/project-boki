# Ryzz (ART-1 rebuild): how this model is made

Source art: briefs/art-refs/ryzz_FINAL_sheet.png (master), ryzz_turnaround_apose.png. Budget: 15k tris (14,368 here), a 2048 atlas + a 2048 relief normal map, 8 surfaces.

1. The turnaround's four views, Meshy image-to-image with the loose parts taken out (pigtails, rods, harness, wires, chain), then a multi-image scan: ~/meshy/ryzz_f (edit.sh, runA).
2. `tools/art1/ryzz_source.py`: scan -> contract rest pose; the head stays the scan's sculpt, the density on the face; hands cut at the wrist.
3. `tools/art1/ryzz_pieces.py`, `ryzz_paint.py`, `ryzz_finish.py`: rebuilt hair, pigtails on spring chains, hands (index/curl/thumb bones), harness, rods, wires, chain, gum, lids; atlas, skin, anchors.
4. `tools/art1/ryzz_clips.py`: 38 clips on the kit's timings (scripts/match/kmoves_vv.gd), content/rules/warden_anim/ryzz.json maps them.

The face and corset are projected from the art: the corset from the master (registered by its neon), the face from the first ryzz_head.png (git 3e988ae8 of ext/agent-briefs, her grin; kept as ~/meshy/ryzz_f/ryzz_head_nogum.png, because the later sheet paints the bubble and the bubble is geometry here).

Run it all with INSTALL=1 ~/meshy/ryzz_f/build.sh [source]. No weapon: fingertips carry the FX points (weapon_muzzle, anchor_finger_L); rods anchor_rod_0..3.

Idle/run pilot (2026-11-11, ext/anim-pilot-four), licence for both: Meshy generated asset, our account. Sparkle's Meshy rig is 01a1c8ac-ed6a-7214-a6e0-3250ea3170f7, auto-rigged from her static mesh at height 1.9. `idle` is now animation-library action 89 (task 01a1c8ad-9df6-7391-bae2-a82e739cf522), retargeted with feet planted, 1.71 s played twice (3.42 s), seam 0.14 deg; blind judge 4.8 vs the old idle 2.8. `run_f` is now the rig's own running clip, retargeted at 1.11x with feet planted at 4.55 m/s and her arms carried from the old run_f, 0.62 s, seam 0.04 deg; judge 4.5 vs 4.0. The rig's walking candidate lost (3.0-3.2 vs 4.0), so walk_f is unchanged. Recipe: `python3 tools/art1/glb_pick_clip.py <candidate.glb> <clip> <name> <tile> /tmp/x.glb`, then `python3 tools/art1/glb_add_clips.py <this glb> /tmp/x.glb <name>`. Candidate GLBs and renders: ~/anim/four (glb/, renders/blind/).

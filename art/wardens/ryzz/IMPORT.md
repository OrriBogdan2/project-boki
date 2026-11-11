# Ryzz (ART-1 rebuild): how this model is made

Source art: briefs/art-refs/ryzz_FINAL_sheet.png (master), ryzz_turnaround_apose.png. Budget: 15k tris (14,368 here), a 2048 atlas + a 2048 relief normal map, 8 surfaces.

1. The turnaround's four views, Meshy image-to-image with the loose parts taken out (pigtails, rods, harness, wires, chain), then a multi-image scan: ~/meshy/ryzz_f (edit.sh, runA).
2. `tools/art1/ryzz_source.py`: scan -> contract rest pose; the head stays the scan's sculpt, the density on the face; hands cut at the wrist.
3. `tools/art1/ryzz_pieces.py`, `ryzz_paint.py`, `ryzz_finish.py`: rebuilt hair, pigtails on spring chains, hands (index/curl/thumb bones), harness, rods, wires, chain, gum, lids; atlas, skin, anchors.
4. `tools/art1/ryzz_clips.py`: 38 clips on the kit's timings (scripts/match/kmoves_vv.gd), content/rules/warden_anim/ryzz.json maps them.

The face and corset are projected from the art: the corset from the master (registered by its neon), the face from the first ryzz_head.png (git 3e988ae8 of ext/agent-briefs, her grin; kept as ~/meshy/ryzz_f/ryzz_head_nogum.png, because the later sheet paints the bubble and the bubble is geometry here).

Run it all with INSTALL=1 ~/meshy/ryzz_f/build.sh [source]. No weapon: fingertips carry the FX points (weapon_muzzle, anchor_finger_L); rods anchor_rod_0..3.

**Walk/run loops (2026-11-11, pilot gait):** walk_f/b/l/r and run_f/b/l/r rebuilt by `tools/art1/hunter_dir_gait.py` (closed L+R cycle, stance
sole pinned to a floor that passes at loco speed, soles on the floor from the skinned foot verts; no Meshy retarget). Walk 0.938 -> 0.792 s, run
0.604 -> 0.542 s; planted sole 1.17 -> 2.20 m/s (loco 2.2) and 3.73 -> 4.80 (loco 4.8); pelvis dip 0 on f/b and run, up to 4.6 cm on walk_l/r;
seam last key = first. Rebuild: `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- ryzz.glb out.glb walk_f run_f b,l,r,f 0.792 0.542`.

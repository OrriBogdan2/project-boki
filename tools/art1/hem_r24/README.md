# Lace (hem) r24 tools: skirt rides the SkirtSw sway bones (no "wing" flare in run, no "trouser" split in Attack)
(plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md; numbers + renders /home/boki/gens/hunter-round-1124/lace/r24/)
Cause: r21-r23 legfollow21 weights (hmax 1.0) gave each skirt vert below y 0.65 to ONE thigh, so the panel sheared apart at the
front/back centre whenever the thighs differ (run swing -25..+59 deg; Attack L +33 / R -7 held).
1. `sway24.py IN OUT keep=0.2 keept=0.9 ykt=0.80 ykb=0.55 iters=24 shin=1 shiny=0.36 cap=80 margin=0.010
   clips=hem_clips.glb clipsout=OUT_clips.glb`: weights (top band kept, panel on the 2 nearest sway bones by angle, thigh share
   0.9 at the hip crease -> 0.2 at the hem) + per-frame sway tilt keys solved closed loop against poke22's thigh set and the shins
   above the hem, for the 6 model clips and the 10 kit-move clips (8 SkirtSw joints added to hem_clips.glb's skin; the game
   borrows those clips by bone name).
2. `meas24.py GLB`: skirt edges >3x / worst stretch per clip and the game-camera silhouette notch.
r23 -> r24: skirt edges >3x (max frame, sum of 6 clips) 423 -> 68 (run 98 -> 3, Jump_Run 107 -> 9, Attack 49 -> 0); poke22 thigh
run/Jump_Run/Attack 0 -> 0, Crouch 1 vert 0.7 cm -> 3 verts 2.0 cm (live main 7.4 cm); geo_check PASS, held worst 0.8 -> 0.7 cm.
Regenerating hem_clips.glb with tools/meshy/lace_clips.py drops the SkirtSw tracks: rerun sway24 with clips= after it.

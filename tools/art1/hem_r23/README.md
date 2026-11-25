# Lace (hem) r23 tools: no ink shell on the skirt's inner layer / fray / bow fist, wine skirt lining
(plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md; renders + numbers /home/boki/gens/hunter-round-1124/lace/r23/)
Cause found: the r21 Meshy skirt is ONE closed thin shell (outer + inner layer ~4 mm apart) with no COLOR_0, so the painted
ink shell (shaders/outline.gdshader, cull_front, ink room = COLOR.a) grew on every vertex; the inner layer's black shell showed
where the layers touch/cross: the black diamonds on the front panel (held Idle at the match camera) and the black fray rim.
The r17 bow fist (body-hand17) is near triangle soup (2,542 open edges): its inside's ink showed as a black patch.
1. `lintex23.py skirt22.jpg lining23c.jpg 0.85 0.70 0.90`: lining texture = the skirt texture x a wine factor (median 96,6,27).
2. `lining23.py r22.glb lining23c.jpg t1.glb 0.52 0.44 0.0`: skirt COLOR_0 (alpha = ink room: inner layer 0, outer 1 above
   y 0.52 fading to 0 at 0.44) + the inner-layer faces on their own prim `skirt-lining23` (same vertices, lining texture).
3. `inkzero23.py t1.glb t2.glb body-hand17`: ink room 0 on the fist (`@LLeftHand:r0:r1` keeps ink at the wrist; tried, the
   patch came back: it is the open wrist end).
4. `hem_r21/repack.py t2.glb out.glb`. Positions, weights, clips and other prims are byte-identical to r22 (geo_check PASS,
   held worst 0.8 cm).
Tried and dropped: legfollow21 lat=15 (wider thigh blend for the Attack "culottes"): Jump_Run thigh poke 0 -> 548 verts 9.4 cm.

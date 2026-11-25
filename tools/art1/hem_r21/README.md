# Lace (hem) r21 tools: Meshy skirt with a closed panel + fray hem, leg porcelain tone (plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md)
Run from the repo root (they import ../hem_r17/glbio.py). Gens + gen_log.tsv: /home/boki/gens/hunter-round-1124/lace/r21/.
Shipped chain (from r20 glb 949ef89a):
1. `legtone.py r20.glb tone.glb`: leg-meshy base colour per-channel gain to the forearm/hand porcelain median (181,178,177 -> 223,216,219);
   mesh bytes untouched. (Meshy leg retextures L1-L3 via `legx.py` + `rtxt.py` / meshy_task retexture were all rejected: grey with boot
   black projected on the thighs, or flat white with no cracks.)
2. Meshy: 8 edits of r13/sel skirt views (closed panel past the knee, fine fray hem to mid-calf, slit kept) -> multi-image-to-3d A
   (all W1 edits) -> retexture TA (original UV, red text) -> `blender -b -P bl_prep.py -- A/glb.glb skA.glb 26000 2048`.
3. `graft21.py tone.glb skA.glb out.glb ymin=0.30 wy=0.10 mir=-1 yaw=0 fl=0.08 tex=TA.jpg`: replaces the skirt-meshy prim only (liner
   prims, legs, body, clips byte-identical), hem tips at y 0.30, width fit 0.10 m under the waist, slit on her right, 8% hem flare
   (geo_check Idle skirt>shin_R held 1.5 -> 0.7 cm), JOINTS/WEIGHTS 0+1 from the nearest old skirt vertex; own texture slot.
4. `repack.py out.glb final.glb` (drops orphan bufferViews). Checks: tools/anim/geo_check.py PASS, hem_r11/partlock.py PASS,
   `loops.py GLB mesh prim` (open boundary loops), hem_r13/stretch4.py.
5. `wsmooth.py in.glb out.glb 30 0.5` (r21b): Laplacian smoothing of the new skirt's 8-influence weights (waist 3 cm fixed). Skirt edges
   >3x 1,816 -> 371 (r20 358), >1.3x 6,480 -> 5,126 (r20 6,218); geo PASS held 0.8. 60 iterations: >3x 253 but geo held 1.2 cm (FAIL).
6. r21c: TA (red text) read neon flat red at game view; re-textured TA2 with the exact r13 T1 prompt (median 88,9,27 vs T1 104,9,27);
   graft again with tex=TA2.jpg, wsmooth 30, then `swscale.py in.glb out.glb 0.4`: SkirtSw rotation keys slerped 40% of the way
   from rest (the r12/r13 keys were solved for a knee-length skirt; on a mid-calf hem the same tilt spread it into a tent).
   geo PASS held 0.7 (k 0.5: held 1.2 FAIL, k 0.6: 0.8). `bl_game.py`: Blender quick views at the match camera.
7. r21d: `legfollow21.py in.glb out.glb hmax=0.7` (numpy port of hem_r10/legfollow.py, weights written in place) on the TA2+wsmooth glb,
   then swscale 0.4 and repack. In-game attack/hit run the kmove clips from hem_clips.glb (arc_loose -> lace_loose), which have no
   SkirtSw keys, so the left knee punched through the closed panel; the thigh share moves the panel with the knee in every clip.

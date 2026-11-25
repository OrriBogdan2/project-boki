# Lace (hem) r22 tools: red skirt + no hip/thigh poke-through (plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md)
Run from the repo root. Gens + measurements: /home/boki/gens/hunter-round-1124/lace/r22/.
1. `poke22.py GLB [out.npz]`: hip/upper-thigh verts that poke OUT through the skirt per clip frame (8-influence skinning;
   geo_check reads only JOINTS_0 and tests cloth only as the sinking part, so it missed the art-gate "hip hole").
   r21e: run 9 verts 4.5 cm, Jump_Run 476 verts 13.2 cm, Crouch 1200 verts. r22: run 0, Jump_Run 0, Crouch 1 vert 0.8 cm.
2. `legfollow21.py r21/cand/r21c.glb lf_j.glb hmax=1.0 ybot=0.65 pw=0.5 ytop=1.08 lat=40` (r21e was hmax=0.85 ybot=0.60 pw=1.0,
   reproduced to 0.0 weight diff). Variants with back>=0.4 put the back panel 1.1-17.5 cm into shin_R in walk (geo FAIL).
3. `skirtcol22.py TA2.jpg TA.jpg skirt22.jpg`: skirt base colour from the two r21 Meshy retextures (same UV), gained to the
   live skirt median 114,9,31 (out 113,9,30); near-black texels 12.8% -> 0.3% (the black shredded hem).
4. `build22.py r21e.glb lf_j.glb skirt22.jpg out.glb` then `hem_r21/repack.py`: only the skirt weights and skirt image change
   (partlock PASS vs r21e).

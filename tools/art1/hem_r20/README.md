# Lace (hem) r20 tools: Meshy porcelain legs replace the body's thighs/knees (plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md)
Needs glbio.py from ../hem_r17 on sys.path (copy it next to these scripts). Renders/gens: /home/boki/gens/hunter-round-1124/lace/r20/.
Shipped chain (from r19 glb f832cb7b):
1. Meshy: 8 edits of r13/crops (front/tq/side/back x 2 wordings) to legs-only; inputs cropped below the brief (uncropped: HTTP 403
   ForbiddenForNSFW); multi-image-to-3d A = front_w1 + tq_w1 + back_w1 (r20/m/A, 40 cr). gen_log.tsv has every gen + verdict.
2. `python3 legcutA.py m/A/glb.glb mask.npz -0.27 0.60` (boot top -5 cm .. upper thigh), `blender -b -P bl_bake.py -- m/A/glb.glb mask.npz
   legs.glb 10000 1024` (cut, weld, decimate to 10k tris, smart-UV, bake the 8k Meshy colour to a 1024 map, matte).
3. `python3 graft20.py r19.glb legs.glb out.glb my=9 b_boot=-0.22 b_knee=-0.07 b_top=0.43 sh=0.62 kb=0.05 ytin=0.90`: drops the body-retex
   thigh/knee faces (8,408) and both thigh-liner prims (r16/r18 shards), fits the legs on the leg bones (piecewise boot top/knee/crotch
   heights, horizontal 0.62, inner side tanh-limited to the leg midline), nearest-vertex weights from the old leg verts (same side only),
   smooth UpLeg/Leg blend at the knee, slanted top (inner thigh top 0.90). Then `../hem_r19/compact19.py` (body-retex, leg-meshy).
4. `python3 bowkey20.py in.glb out.glb` (walk): the bow's lower limb entered the left knee ball at walk f12 (geo 2.4 cm). The Bow joint
   rotation of walk is re-keyed at 30 fps with a smoothed tilt about the grip (max 5.3 deg over 23 frames): 2.4 cm -> 0. Not used:
   bowdent.py (dents the knee instead; even capped at 2.2 cm it crumples the ball at knee height, r20/meas/kz.jpg).
Checks: tools/anim/geo_check.py PASS (held worst 0.8 cm, bow>thigh 0); legstretch.py (leg edges > 3x: 10).
Not used: graft20 mirror step (my=) and legcut.py were for the r13 B donor (its upper thighs were open: skirt fused).

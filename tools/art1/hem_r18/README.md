# Lace (hem) r18 tools (plan: /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md). Needs glbio.py + fk.py from ../hem_r17 on sys.path
(copy them next to these scripts, as r18 did).
Shipped chain (from r17b, glb blob d06c549e):
1. `python3 keyfix18.py r17b.glb k.glb d=0.05`: Attack only; RightArm keys rotate about the shoulder so the draw hand sits 5 cm
   further from the head (weight by hand-head distance), StringMid keys follow the hand (string stays in the hand).
   geo_check Attack: forearm_R>head 3.78 -> 0, hand_R>head 3.74 -> 0, bow>head 2.40 -> 0 cm.
2. `python3 legfill18.py k.glb a2.glb yb=0.46`: inner porcelain leg tubes (thigh-liner material) y 0.75..0.46 at 0.86x the
   body's leg radius; UpLeg above 0.60, blend to Leg by 0.54. The Meshy body's thigh/knee/boot-top holes (hem.md D1 "black
   blotches", D6 boot cuff void) now show porcelain instead of the dark inside. Body bytes untouched.
Tried, not shipped: rhand18.py (r17 Meshy fist mirrored onto the right hand: wrist gap, open fist hole, and the ref draws the
free hand open), collar18.py (waist annulus: <0.4% pixels changed; the dark waist ring is the corset's black peplum texture).
Inspection: texprobe.py (dark texels per material/height), waistgap.py, bl_views/bl_hand/bl_waist.py (Workbench views), pairs.py
(worst depth per clip/pair from geo_check TSV).

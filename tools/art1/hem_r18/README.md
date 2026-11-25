# Lace (hem) r18 tools (plan: /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md). Needs glbio.py + fk.py from ../hem_r17 on sys.path
(copy them next to these scripts, as r18 did).
Shipped chain (from r17b, glb blob d06c549e):
1. `python3 keyfix18.py r17b.glb k.glb d=0.05`: Attack only; RightArm keys rotate about the shoulder so the draw hand sits 5 cm
   further from the head (weight by hand-head distance), StringMid keys follow the hand (string stays in the hand).
   geo_check Attack: forearm_R>head 3.78 -> 0, hand_R>head 3.74 -> 0, bow>head 2.40 -> 0 cm.
2. `blender -b -P handpts18.py -- k.glb handpts18.npz` (hand/bow points per frame in UpLeg and Leg rest space), then
   `python3 legfill18.py k.glb a10.glb yt=0.75 yb=0.62 hp=handpts18.npz`: inner porcelain thigh tubes, capped both ends, (thigh-liner material)
   y 0.75..0.62 at 0.86x the body's thigh radius, rigid on UpLeg, carved off hand/bow points. The Meshy body's thigh holes
   (hem.md D1 "black blotches") now show porcelain instead of the dark inside. Body bytes untouched. geo_check: no new pair.
   Not shipped: the knee band (bow presses the knee in walk: bow>tube 1.7 cm) and a boot-top tube (D6; skirt strands already
   hang inside the open boot cuff: skirt>tube 3.7 cm). bl_dbg.py = which bow vert touches the liner at a clip frame.
Tried, not shipped: rhand18.py (r17 Meshy fist mirrored onto the right hand: wrist gap, open fist hole, and the ref draws the
free hand open), collar18.py (waist annulus: <0.4% pixels changed; the dark waist ring is the corset's black peplum texture).
Inspection: texprobe.py (dark texels per material/height), waistgap.py, bl_views/bl_hand/bl_waist.py (Workbench views), pairs.py
(worst depth per clip/pair from geo_check TSV).

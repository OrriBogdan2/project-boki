# Lace (hem) r16 tools: close the missing pelvis + back panel over the calf
Finding: the Meshy body (head_graft prim 2) has no surface between the corset bottom (y ~0.98) and the thigh tops (y ~0.78);
`slice.py GLB out.png 1.0,0.9,...` draws body (black), skirt (red) and added parts per height; `topo.py` = skirt boundary loops (0: watertight).
Chain for the r16 glb (from r14 k3, b3d2ef47):
1. `blender -b -P ../hem_r13/refine13.py -- K3.glb solve Idle sol_Idle.json zlow=0.30 amax=65 xmax=35` (Attack: xmax=25),
   then `refine13.py -- K3.glb apply kC.glb sol_Idle.json sol_Attack.json` (back panel tilts over the rear calf; keys only).
2. `blender -b -P handpts.py -- kC.glb handpts.npz` (hand/forearm/bow points over every clip in UpLeg rest space).
3. `python3 fill.py K3.glb f7.glb tgrow=0 mgap=0.012 dome=0.85 tpad=0.001 hp=handpts.npz`: adds to the Skirt mesh
   (body bytes untouched) inner shorts (material skirt-liner = copy of skirt-meshy, wine texel, Hips) and two upper-thigh
   tubes (thigh-liner = copy of body-retex, porcelain texel, rigid on UpLeg, clamped to their side of the midplane, carved
   6 mm off every hand/bow point). Liner materials are skipped by clipcheck11 ('liner' in the name).
4. `python3 ../glb_add_clips.py f7.glb kC.glb =Idle,=Attack f7C.glb` (mesh stays byte-identical to step 3).
`snap3.py` (waist band snap per angle) was tried and NOT used: below y 0.97 there is no body to snap to (534 folded faces).

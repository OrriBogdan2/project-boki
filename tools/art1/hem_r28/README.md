# Lace (hem) r28 tools: knee-follow weights + inner under-panel behind the slit
(plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md r28; numbers + renders /home/boki/gens/hunter-round-1124/lace/r28/)
Why: r14-r27 only moved slit keys; nothing sat behind the slit, so the 66-deg game camera saw ground through it (seethru 0.078 vs
live 0.009), and the knee ball poked through the middle of the front panel (poke22 run 2.5 cm, Jump_Run 1.3 cm), not through the slit.
Chain from the r27 glb (md5 e11fd7b4), run from the repo root:
1. `kneefollow.py r27.glb k.glb s=0.5 rx=0.14 ry=0.16`: up to 50% UpLeg weight on skirt verts in front of each knee (shared
   skirt-meshy/lining23 accessors). poke22 run 25 v/2.5 cm -> 0, Jump_Run 3 v/1.3 cm -> 0, walk 11 v/1.0 cm -> 0.
2. `gusset.py k.glb g.glb` (defaults ytop=0.60 hw=30 rot=80 inset=0.010 mat=skirt-lining23): Meshy skirt faces from the closed side
   copied into the slit, 1 cm inside, own primitive, weights = membrane between the slit edges. seethru 0.078 -> 0.054.
   Sweep ytop 0.55-0.68 / hw 30-38 / inset 0.010-0.018: all 0.050-0.053 (the rest is hull slivers + frayed hem gaps).
   SHIPPED (r28 V2): `gusset.py k.glb g.glb ytop=0.74 hw=32 vpow=1` = V-shaped godet (the rectangle A showed a dark box with a
   hard top edge at eye level in GPU renders); seethru 0.056 (Idle 0.034, run 0.061, Jump_Run 0.087, Crouch 0.082).
3. `../hem_r21/repack.py g.glb final.glb`. Checks: geo_check PASS (held 0.7 cm, hands = r27), hem_r11/partlock.py PASS,
   hem_r24/meas24.py edges>3x 321 -> 325.
Clips file unchanged (weights and the new primitive live in hem_meshy.glb only).

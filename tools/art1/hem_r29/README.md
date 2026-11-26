# Lace (hem) r29 tools: slit re-centred in front of her right leg + Meshy wine skirt texture
(plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md r29; numbers + renders /home/boki/gens/hunter-round-1124/lace/r29/)
Why: the slit was cut at -40 deg (atan2(x,z) about the hip axis) but her right knee swings forward at about -15..-20 deg, so the
knee hit the panel beside the slit; r14-r28 answered with keys and knee-follow weights, and that thigh share made the panel flare
out like a cape at the game camera. The turnaround has the slit straight in front of her right leg. The skirt texture (skirt22)
was a near-flat crimson (median 113,9,30, no fold shading) that the toon shader lifts to hot red.
Chain from the r27 glb (git 8df220ac8d, md5 e11fd7b4), run from the repo root:
1. `rot29.py r27.glb t.glb deg=14 mix=0.6`: skirt shell (skirt-meshy + lining prim, shared accessors) turned +14 deg; weights 60% taken
   in space at the new spot, 40% kept with the vertex; slit joints (SkirtSlitA/B) travel with the vertex.
   Sweep (poke22 Jump_Run cm / meas24 Jump_Run+run edges>3x): mix 1.0 0.0/392, 0.7 0.0/217, 0.6 0.0/154, 0.5 1.2/102, 0 9.4/48
   (r28: 0.0/32). Laplacian weight smoothing (hem_r21/wsmooth.py) removes the stretch but lets the knee through (Jump_Run 6.6-12.7 cm).
2. `../hem_r28/kneefollow.py t.glb tk.glb s=0.6 rx=0.16 ry=0.18` (r28 used 0.5/0.14/0.16 before any turn).
3. `../hem_r28/gusset.py tk.glb g.glb ytop=0.74 hw=32 vpow=1 gapc=-26` (the r28 V godet, re-centred with the slit).
4. `../hem_r21/repack.py g.glb r.glb`, then `tex29.py r.glb R6/tex_base_color.png final.glb`: skirt image = Meshy retexture R6
   of the r21 skirt model A (input_task_id, original UV, text only; median 74,12,29), lining = R6 x (0.70,0.60,0.80); images
   renamed skirt29 / skirt_lining29 (Godot extracts hem_meshy_skirt29.jpg / hem_meshy_skirt_lining29.jpg).
Checks: tools/anim/geo_check.py PASS, hem_r11/partlock.py PASS vs r28, hem_r22/poke22.py, hem_r26/seethru.py, hem_r24/meas24.py.

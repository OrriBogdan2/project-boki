# Lace (hem) r26 tools: the game-camera "trouser V" is the slit seen from above; close it per clip, keep the slit on design
(plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md; numbers + renders /home/boki/gens/hunter-round-1124/lace/r26/)
Cause (measured): the skirt covers 360 deg with a round radius (no figure-8), but the game camera looks down ~66 deg, so a ray
through any front gap leaves through the open hem 10-15 cm later and hits the ground. r25's slit (20-30 deg wedge, hem to y 0.60,
centred -40 deg) faces the camera in idle/attack; r25 closed it only in Attack, by 16 deg, and only below y 0.60 (a tear hole stayed above).
- `slitclose.py` (post-pass on the shipped r25 glb + clips; mesh, textures, non-slit weights and all other keys untouched):
  extra closing yaw on the SkirtSlitA/B keys per clip; band1/sy0/sy1 rebuild the slit weights with sway25's formula.
  Shipped: `clo=Crouch:1.0,Idle:0.7,walk:0.7,run:0.7,Jump_Run:0.5,*:1.8 band1=30 sy0=0.92 sy1=0.66` (first substring match wins:
  Jump_Run gets run's 0.7; list Crouch before walk). Idle 1.2 (variant p) shut the signature idle slit to a sliver at eye level.
- `seethru.py GLB`: share of the skirt's game-camera hull (below the waist) where the ground shows through (all body prims as
  occluders), mean/max over clip frames and model yaw -45/0/45. Live bell 0.009; r25 0.109; r26 0.089 (Attack 0.063 -> 0.039).
- r27 (2026-11-26, plan PLAN-1124o.md r27): same tool from r25, `clo=Crouch:1.4,Jump_Run:0.3,Idle:1.8,walk:1.8,run:1.0,*:1.8
  band1=30 sy0=0.92 sy1=0.66`. Idle/walk closed like Attack (game view sees no slit V); Jump_Run/run closed less (r26's 0.5/0.7
  pushed the knee through the slit edge, 4.8 cm). seethru Idle 0.066 -> 0.043, mean 0.089 -> 0.078; poke22 Jump_Run 4.8 -> 1.3 cm.

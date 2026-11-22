# Sable hybrid rig (Meshy auto-rig + scripted weight fixes)
Skeleton, bone names and clips are Meshy's, untouched. Only per-vertex JOINTS_0/WEIGHTS_0 and the rotation keys of
the coat bones change. Python with numpy and scipy.
1. Decimate the master to <= 80k tris BEFORE rigging, rig and animate it with Meshy (fingers on).
2. `patchglb.py IN.glb OUT.glb` (rig and each clip file): `fixrule.py` rewrites the weights.
   R1 pistol rigid on its hand; R1b no leg/hip weight on arm verts; R2 coat/arm split; R3 coat Laplacian;
   R4 armpit band; R5 wrist band; R6 contact bands (arm group against body below the armpit: weights blended over
   RINGS=16 rings, ITK=120 passes, so a hand leaving the thigh stretches many short edges, not a few).
3. `chainhang.py IN.glb OUT.glb`: gravity hang plus thigh/floor collision baked into the coat chains' rotation keys
   (roots Bone_009/Bone_013: root, mid, stub, leaf).
4. `native_pack.py` builds `art/wardens/sable/sable_meshy.glb`. Checks: `glbstretch.py OUT.json GLB` (torn frames),
   `coathit.py GLB...` (coat verts under the floor / inside the legs).

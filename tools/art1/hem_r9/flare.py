"""flare.py IN.glb OUT.glb [kx=1.3 ky=1.5 h0=0.05 h1=0.9]: r9 skirt fit. Radial A-line flare of the Skirt about the hip axis
(top stays on the waist) so the hem covers the legs from the match camera and clears the thighs. Rig/fit only."""
import bpy, sys, numpy as np
A = sys.argv[sys.argv.index('--') + 1:]; SRC, OUT = A[:2]; O = dict(a.split('=') for a in A[2:])
KX, KY, H0, H1 = (float(O.get(k, d)) for k, d in (('kx', 1.3), ('ky', 1.5), ('h0', 0.05), ('h1', 0.9)))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; sk = bpy.data.objects['Skirt']
hip = arm.matrix_world @ arm.data.bones['Hips'].head_local
mw = sk.matrix_world; imw = mw.inverted(); V = sk.data.vertices
P = np.array([mw @ v.co for v in V]); z1, z0 = P[:, 2].max(), P[:, 2].min()
h = (z1 - P[:, 2]) / (z1 - z0); t = np.clip((h - H0) / (H1 - H0), 0, 1); s = t * t * (3 - 2 * t)
P[:, 0] = hip.x + (P[:, 0] - hip.x) * (1 + (KX - 1) * s); P[:, 1] = hip.y + (P[:, 1] - hip.y) * (1 + (KY - 1) * s)
for v, p in zip(V, P): v.co = imw @ __import__('mathutils').Vector(p)
sk.data.update()
print('actions', [a.name for a in bpy.data.actions][:12])
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_skins=True, export_apply=False)

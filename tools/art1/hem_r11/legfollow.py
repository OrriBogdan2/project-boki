"""legfollow.py IN.glb OUT.glb [hmax=0.8 front=1.0 back=0.45 lat=1.6 pw=1.3] : r10 skirt rig pass (weights only). Each skirt
vert gets a share w of Left/RightUpLeg (split by side, centre 50/50), w = hmax * smoothstep(depth below the hips)^pw *
(front..back by facing), the rest keeps its Hips/SkirtSw* weights scaled by (1-w). The narrow-slit skirt then moves with
the thigh instead of the thigh punching through it."""
import bpy, sys, numpy as np
A = sys.argv[sys.argv.index('--') + 1:]; SRC, OUT = A[:2]; O = dict(a.split('=') for a in A[2:])
HM, FR, BK, LAT, PW = (float(O.get(k, d)) for k, d in (('hmax', .8), ('front', 1.), ('back', .45), ('lat', 1.6), ('pw', 1.3)))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; sk = bpy.data.objects['Skirt']; mw = arm.matrix_world
hl, hr, hip = (mw @ arm.data.bones[b].head_local for b in ('LeftUpLeg', 'RightUpLeg', 'Hips'))
kz = (mw @ arm.data.bones['LeftLeg'].head_local).z
cx = (hl.x + hr.x) / 2; hw = abs(hl.x - hr.x) / 2; top = hl.z
gL = sk.vertex_groups.get('LeftUpLeg') or sk.vertex_groups.new(name='LeftUpLeg')
gR = sk.vertex_groups.get('RightUpLeg') or sk.vertex_groups.new(name='RightUpLeg')
sgn = 1 if hl.x > hr.x else -1
names = {g.index: g.name for g in sk.vertex_groups}; ws = []
for v in sk.data.vertices:
    p = sk.matrix_world @ v.co
    t = np.clip((top + 0.03 - p.z) / max(top - kz, 1e-3), 0, 1); h = (t * t * (3 - 2 * t)) ** PW
    fy = np.clip((hip.y - p.y) / 0.12, -1, 1)   # -Y = front
    face = BK + (FR - BK) * (fy + 1) / 2
    w = HM * h * face; ws.append(w)
    if w <= 1e-3: continue
    xl = np.clip(0.5 + sgn * (p.x - cx) / hw / LAT, 0, 1)
    for g in v.groups:
        if names[g.group] not in ('LeftUpLeg', 'RightUpLeg'): g.weight *= (1 - w)
    gL.add([v.index], w * xl, 'ADD'); gR.add([v.index], w * (1 - xl), 'ADD')
print('LEGFOLLOW mean w %.2f max %.2f' % (np.mean(ws), np.max(ws)))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_skins=True, export_apply=False)

"""pxclip.py GLB CLIP [NF=8 res=160] : visible poke-through pixels. Pinhole cams: eye (z1.55, d3.0, look z0.9) and knee
(z0.55, d2.6, look z0.65) x az 0,45,90,180,270 (0 = front). A pixel counts when the first hit is a leg-owned body face and,
continuing the ray, the next skirt face (within 0.35 m) faces the camera on its OUTER side = leg outside the cloth."""
import bpy, sys, math, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
A = sys.argv[sys.argv.index('--') + 1:]; G, CLIP = A[0], A[1]; O = dict(a.split('=') for a in A[2:]); NF = int(O.get('nf', 8)); R = int(O.get('res', 160))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=G)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; ob = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
body, sk = ob['head_graft'], ob['Skirt']; CX, CY = -0.027, -0.042
LEG = {'LeftUpLeg', 'LeftLeg', 'LeftFoot', 'LeftToeBase', 'RightUpLeg', 'RightLeg', 'RightFoot', 'RightToeBase'}
gi = {g.index: g.name for g in body.vertex_groups}
vleg = np.array([bool(v.groups) and gi[max(v.groups, key=lambda g: g.weight).group] in LEG for v in body.data.vertices])
fleg = np.array([vleg[list(p.vertices)].mean() > .5 for p in body.data.polygons])
mw = sk.matrix_world; sgn = []
for p in sk.data.polygons:
    c = mw @ p.center; n = mw.to_3x3() @ p.normal; sgn.append(1 if n.x * (c.x - CX) + n.y * (c.y - CY) >= 0 else -1)
sgn = np.array(sgn)
def bvh(o):
    dg = bpy.context.evaluated_depsgraph_get(); e = o.evaluated_get(dg); me = e.to_mesh(); M = e.matrix_world
    t = BVHTree.FromPolygons([M @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons]); e.to_mesh_clear(); return t
VIEWS = [('eye', 1.55, 3.0, 0.9), ('knee', 0.55, 2.6, 0.65)]; AZ = [0, 45, 90, 180, 270]; FOV = math.radians(40)
arm.animation_data_create(); act = bpy.data.actions[CLIP]; arm.animation_data.action = act; f0, f1 = act.frame_range
tot = {}; rows = []
for f in np.linspace(f0, f1, NF):
    bpy.context.scene.frame_set(int(round(f))); bpy.context.view_layer.update()
    T = {n: bvh(o) for n, o in ob.items()}; cnt = {}
    for vn, cz, d, tz in VIEWS:
        for az in AZ:
            a = math.radians(az - 90); C = Vector((CX + d * math.cos(a), CY + d * math.sin(a), cz)); fw = (Vector((CX, CY, tz)) - C).normalized()
            rt = fw.cross(Vector((0, 0, 1))).normalized(); up = rt.cross(fw); n = 0; s = math.tan(FOV / 2)
            for iy in range(R):
                for ix in range(R):
                    u = (ix + .5) / R * 2 - 1; v = 1 - (iy + .5) / R * 2
                    if v * s * d + tz > 1.25 or v * s * d + tz < 0.05: continue          # lower-body rows only
                    dr = (fw + rt * (u * s) + up * (v * s)).normalized(); best = None
                    for nm, t in T.items():
                        h = t.ray_cast(C, dr, 10)
                        if h[0] is not None and (best is None or h[3] < best[1][3]): best = (nm, h)
                    if not best or best[0] != 'head_graft' or not fleg[best[1][2]]: continue
                    h2 = T['Skirt'].ray_cast(best[1][0] + dr * 0.001, dr, 0.35)
                    if h2[0] is not None and sgn[h2[2]] * h2[1].dot(dr) < 0: n += 1
            cnt[vn + str(az)] = n
    rows.append((int(round(f)), cnt)); print('PX %s f%d %s' % (CLIP, int(round(f)), cnt), flush=True)
for vn in ('eye', 'knee'):
    v = [sum(c[k] for k in c if k.startswith(vn)) for _, c in rows]; print('PXSUM %s %s mean/frame %.1f worst %d' % (CLIP, vn, np.mean(v), max(v)))

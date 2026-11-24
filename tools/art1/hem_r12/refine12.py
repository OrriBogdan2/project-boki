"""refine12.py -- closed-loop billow refine (rig keys only, no geometry/weights change).
blender -b -P refine12.py -- IN.glb solve CLIP OUT.json [amax=75 it=10]   -> per-frame per-sector extra outward tilt (deg)
blender -b -P refine12.py -- IN.glb apply OUT.glb J1.json J2.json ...      -> keys every frame = old pose @ extra tilt, export
Per frame: leg/foot verts outside the Skirt (ray bone->vert crosses the skirt, same test as clipcheck11) are measured;
each sector k gets +atan(depth+pad, pivot-z) * cos-weight; repeat until 0 hits or the cap."""
import bpy, sys, math, json, numpy as np
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree
A = sys.argv[sys.argv.index('--') + 1:]; SRC, MODE = A[0], A[1]
O = dict(a.split('=') for a in A if '=' in a); F = lambda k, d: float(O.get(k, d))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; ob = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
body, sk = ob['head_graft'], ob['Skirt']; NSW = 8; SWN = ['SkirtSw%d' % k for k in range(NSW)]
AMW = arm.matrix_world; PIV = (AMW @ arm.data.bones['SkirtSw0'].head_local).z; CX, CY = -0.027, -0.042
axl = {}
for k in range(NSW):
    th = 2 * math.pi * k / NSW; B3 = AMW.to_3x3() @ arm.data.bones[SWN[k]].matrix_local.to_3x3()
    axl[k] = (B3.inverted() @ Vector((-math.sin(th), math.cos(th), 0))).normalized()
SEG = {'LeftUpLeg': 'LeftLeg', 'LeftLeg': 'LeftFoot', 'LeftFoot': 'LeftToeBase', 'RightUpLeg': 'RightLeg', 'RightLeg': 'RightFoot', 'RightFoot': 'RightToeBase'}
gi = {g.index: g.name for g in body.vertex_groups}; own = {}
for v in body.data.vertices:
    b = max(v.groups, key=lambda g: g.weight, default=None)
    if b and gi[b.group] in SEG: own[v.index] = gi[b.group]
idx = np.array(sorted(own)); bones = np.array([own[i] for i in idx])
SF = [tuple(p.vertices) for p in sk.data.polygons]
def evco(o):
    dg = bpy.context.evaluated_depsgraph_get(); e = o.evaluated_get(dg); me = e.to_mesh(); n = len(me.vertices)
    co = np.empty(n * 3, np.float32); me.vertices.foreach_get('co', co); e.to_mesh_clear()
    M = np.array(o.matrix_world); co = co.reshape(-1, 3); return co @ M[:3, :3].T + M[:3, 3]
def hits():
    SP = evco(sk); tree = BVHTree.FromPolygons([Vector(p) for p in SP], SF); BP = evco(body)[idx]; z0, z1 = SP[:, 2].min(), SP[:, 2].max(); out = []
    S = {b: (np.array(AMW @ arm.pose.bones[b].head), np.array(AMW @ arm.pose.bones[b].tail)) for b in SEG}
    for p, b in zip(BP, bones):
        if not (z0 < p[2] < z1 - 0.05): continue
        a, c = S[b]; d = c - a; t = np.clip(np.dot(p - a, d) / max(np.dot(d, d), 1e-9), 0, 1); q = a + t * d; r = p - q; L = np.linalg.norm(r)
        if L < 1e-4: continue
        h = tree.ray_cast(Vector(q), Vector(r / L), L - 0.002)
        if h[0] is not None: out.append((math.atan2(p[1] - CY, p[0] - CX), p[2], L - h[3]))
    return out
def setx(ex, base):
    for k in range(NSW): arm.pose.bones[SWN[k]].rotation_quaternion = base[k] @ Quaternion(axl[k], -math.radians(ex[k]))
    bpy.context.view_layer.update()
for k in range(NSW): arm.pose.bones[SWN[k]].rotation_mode = 'QUATERNION'
arm.animation_data_create(); sc = bpy.context.scene
if MODE == 'solve':
    CLIP, OUTJ = A[2], A[3]; act = bpy.data.actions[CLIP]; arm.animation_data.action = act; AM, IT, PAD, ZMX = F('amax', 75), int(F('it', 10)), F('pad', .015), F('zmax', .95)
    res = {}; f0, f1 = int(act.frame_range[0]), int(act.frame_range[1]); n0 = n1 = 0
    for f in range(f0, f1 + 1):
        sc.frame_set(f); base = [arm.pose.bones[SWN[k]].rotation_quaternion.copy() for k in range(NSW)]
        cur = [0.0] * NSW; ang0 = [2 * math.degrees(math.acos(min(1, abs(q.w)))) for q in base]; h = hits(); n0 += len(h)
        for it in range(IT):
            if not [x for x in h if x[1] <= ZMX]: break
            add = [0.0] * NSW
            for a_, z, d in h:
                if z > ZMX: continue
                lev = max(PIV - z, 0.12)
                for k in range(NSW):
                    cc = math.cos(a_ - 2 * math.pi * k / NSW)
                    if cc > 0.3: add[k] = max(add[k], math.degrees(math.atan2(d + PAD, lev)) * min(1, cc * 1.3))
            add = [max(add[k], 0.4 * add[(k - 1) % NSW], 0.4 * add[(k + 1) % NSW]) for k in range(NSW)]
            new = [min(cur[k] + add[k], max(0.0, AM - ang0[k]), F('xmax', 90)) for k in range(NSW)]
            if all(abs(new[k] - cur[k]) < 0.2 for k in range(NSW)): break
            cur = new; setx(cur, base); h = hits()
        hd = [x for x in h if x[1] <= ZMX]
        n1 += len(h); res[f] = [round(x, 2) for x in cur]
        print('F %s %3d left %4d extra %s' % (CLIP[:8], f, len(h), [round(x) for x in cur]), flush=True)
    json.dump({'clip': CLIP, 'extra': res, 'hits_before': n0, 'hits_after': n1}, open(OUTJ, 'w')); print('DONE', CLIP, n0, '->', n1)
else:
    OUT = A[2]; J = [json.load(open(p)) for p in A[3:] if p.endswith('.json')]; SM = F('smooth', 1)
    for j in J:
        act = bpy.data.actions[j['clip']]; arm.animation_data.action = act; ex = {int(k): v for k, v in j['extra'].items()}; fr = sorted(ex)
        if SM:   # temporal: a frame keeps at least 60% of its neighbours' extra (no one-frame pops)
            ex = {f: [max(ex[f][k], 0.6 * ex.get(f - 1, ex[f])[k], 0.6 * ex.get(f + 1, ex[f])[k]) for k in range(NSW)] for f in fr}
        poses = {}
        for f in fr:
            sc.frame_set(f); poses[f] = [(arm.pose.bones[SWN[k]].rotation_quaternion @ Quaternion(axl[k], -math.radians(ex[f][k]))).copy() for k in range(NSW)]
        for fc in [c for c in act.fcurves if 'SkirtSw' in c.data_path]: act.fcurves.remove(fc)
        for f in fr:
            for k in range(NSW):
                pb = arm.pose.bones[SWN[k]]; pb.rotation_quaternion = poses[f][k]; pb.keyframe_insert('rotation_quaternion', frame=f, group=SWN[k])
        print('applied', j['clip'], len(fr), 'frames, max extra', max(max(v) for v in ex.values()))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animation_mode='ACTIONS', export_yup=True, export_apply=False, export_skins=True, export_morph=False)
    print('wrote', OUT)

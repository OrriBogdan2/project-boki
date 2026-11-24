"""clipcheck.py GLB [frames=8] : part-vs-part poke-through over every clip. For each sampled frame, every leg/foot vert of
the body is tested: a ray from its own (posed) bone segment out to the vert; if it crosses the Skirt surface, the leg is
outside the skirt there = pokes through. Also Bow vs body/skirt and Pins/Head_new vs body. Prints CLIP lines + a TOTAL."""
import bpy, sys, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import math
A = sys.argv[sys.argv.index('--') + 1:]; G = A[0]; NF = int(A[1]) if len(A) > 1 else 8; SLIT = 'slit=1' in A; CX, CY = -0.027, -0.042
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=G)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
ob = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
body = ob['head_graft']; sk = ob['Skirt']
SEG = {'LeftUpLeg': 'LeftLeg', 'LeftLeg': 'LeftFoot', 'LeftFoot': 'LeftToeBase', 'RightUpLeg': 'RightLeg', 'RightLeg': 'RightFoot', 'RightFoot': 'RightToeBase'}
SEG = {k: v for k, v in SEG.items() if k in arm.data.bones}
gi = {g.index: g.name for g in body.vertex_groups}
own = {}
for v in body.data.vertices:
    best = max(v.groups, key=lambda g: g.weight, default=None)
    if best and gi[best.group] in SEG: own[v.index] = gi[best.group]
idx = np.array(sorted(own)); bones = [own[i] for i in idx]
print('legverts', len(idx))
def ev(o):
    dg = bpy.context.evaluated_depsgraph_get(); e = o.evaluated_get(dg); me = e.to_mesh()
    P = np.array([e.matrix_world @ v.co for v in me.vertices]); ms = [m.name if m else '' for m in me.materials]
    F = [tuple(p.vertices) for p in me.polygons if 'liner' not in (ms[p.material_index] if ms else '')]; e.to_mesh_clear(); return P, F
def seg(b):
    pb = arm.pose.bones[b]; m = arm.matrix_world
    return np.array(m @ pb.head), np.array(m @ pb.tail)
tot = {}; H = {}; FT = [0]
for act in bpy.data.actions:
    arm.animation_data_create(); arm.animation_data.action = act
    f0, f1 = act.frame_range; worst = (0, 0, 0)
    vals = []
    for f in np.linspace(f0, f1, NF):
        bpy.context.scene.frame_set(int(round(f))); bpy.context.view_layer.update()
        SP, SF = ev(sk); tree = BVHTree.FromPolygons([Vector(p) for p in SP], SF)
        BP, _ = ev(body); z0, z1 = SP[:, 2].min(), SP[:, 2].max()
        S = {b: seg(b) for b in SEG}; n = k = 0
        for i, b in zip(idx, bones):
            p = BP[i]
            if not (z0 < p[2] < z1 - 0.05): continue
            if SLIT and -165 < math.degrees(math.atan2(p[1]-CY, p[0]-CX)) < -45 and p[2] < 0.9: continue
            a, c = S[b]; d = c - a; t = np.clip(np.dot(p - a, d) / max(np.dot(d, d), 1e-9), 0, 1); q = a + t * d
            r = p - q; L = np.linalg.norm(r)
            if L < 1e-4: continue
            k += 1
            hit = tree.ray_cast(Vector(q), Vector(r / L), L - 0.002)
            if hit[0] is not None:
                n += 1; FT[0] += (b in ('LeftFoot','RightFoot')); H.setdefault(round(float(p[2]),1),[0,0,0]); H[round(float(p[2]),1)][0]+=1; H[round(float(p[2]),1)][1 if p[1]<0 else 2]+=1
        vals.append(n)
        if n > worst[0]: worst = (n, k, int(round(f)))
    tot[act.name] = (np.mean(vals), worst)
    print('CLIP %-24s mean %6.0f  worst %5d of %5d legverts-in-band (frame %d)' % (act.name, np.mean(vals), *worst))
print('ZHIST', sorted(H.items())); print('FOOTHITS', FT[0])
print('TOTAL mean-per-frame %.0f  worst %d' % (np.mean([v[0] for v in tot.values()]), max(v[1][0] for v in tot.values())))

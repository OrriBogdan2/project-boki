"""ART-1 Lisette, stage A: the Meshy scan of the owner's A-pose turnaround (hair, scarf, mask, scissors edited out) -> the contract's rest pose. Recipe: Kael's and
Cinder's (scan joints read off gridded renders, soft weights by distance to the bone segments, each bone moves its vertices onto the rig). Her own: the chest twists a
long way over the bare midriff at full draw, so the waist's blend is wide. In: the scan glb, hem_rig.json. Out: objects Src (the fitted scan, the paint source) and Low.
Run: blender -b --factory-startup --python tools/art1/hem_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def smooth(a, b, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 4900
SOLE = -0.95                    # the scan's sole (z)
ANKLE = 0.082                   # the rig has no ankle node: the foot bone sits here
# Scan joints (flipped to face +Y, his right +X, z from the sole), measured on grid_front/grid_right.
S_J = {"neck": (0, 0, 1.65), "pelvis": (0, 0, 1.00), "shoulder.R": (0.150, 0, 1.54), "elbow.R": (0.310, 0, 1.30), "wrist.R": (0.504, 0, 1.04),
       "shoulder.L": (-0.150, 0, 1.54), "elbow.L": (-0.310, 0, 1.30), "wrist.L": (-0.504, 0, 1.04), "hip.R": (0.100, 0, 1.01), "knee.R": (0.125, 0, 0.63),
       "ankle.R": (0.160, 0, 0.10), "hip.L": (-0.100, 0, 1.01), "knee.L": (-0.125, 0, 0.63), "ankle.L": (-0.160, 0, 0.10)}
# name: (scan head, scan tail, rig head bone, rig tail bone or point, reach radius, girth)
rig = json.load(open(RIG))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, ANKLE])
SEG = [("torso", "pelvis", "neck", 0.15, 0.90)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.055, 0.90), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.045, 0.90),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.10, 0.88), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.065, 0.88)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
ms = [o for o in bpy.data.objects if o.type == "MESH"]
src = ms[0]
for o in list(bpy.data.objects):
    if o is not src:
        bpy.data.objects.remove(o)
src.parent = None
src.matrix_world = np.eye(4).tolist() if False else src.matrix_world
me = src.data
n = len(me.vertices)
co = np.zeros(n * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
mw = np.array(src.matrix_world)
co = co @ mw[:3, :3].T + mw[:3, 3]
src.matrix_world = np.eye(4).tolist() if False else src.matrix_world
from mathutils import Matrix
src.matrix_world = Matrix.Identity(4)
P = np.stack([-co[:, 0], -co[:, 1], co[:, 2] - SOLE], 1)        # to +Y facing, sole on 0
print("scan", n, P.min(0).round(3), P.max(0).round(3))

# ---- soft weights by distance to the segments
names = [s[0] for s in SEG]
D = np.zeros((n, len(SEG)))
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    u = a1 - a0
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    d = np.linalg.norm(P - (a0 + h[:, None] * u), axis=1)
    if nm == "torso":
        q = P - (a0 + h[:, None] * u)
        d = np.linalg.norm(q * [0.8, 1.05, 1.0], axis=1)         # a wide, flat chest
    D[:, i] = d - rad
    if nm.endswith(".R"):
        D[P[:, 0] < -0.02, i] = 9.0
    if nm.endswith(".L"):
        D[P[:, 0] > 0.02, i] = 9.0
    if nm.startswith("thigh") or nm.startswith("shin"):
        D[P[:, 2] > 1.10, i] = 9.0
    if nm.startswith(("upper_arm", "forearm")):
        D[P[:, 2] < 0.85, i] = 9.0
W = np.exp(-(D - D.min(1, keepdims=True)) / 0.016)
W /= W.sum(1, keepdims=True)

# ---- each bone moves its vertices onto the rig
def rot_between(u, v):
    u, v = u / np.linalg.norm(u), v / np.linalg.norm(v)
    c = np.cross(u, v)
    s, d = np.linalg.norm(c), u @ v
    if s < 1e-7:
        return np.eye(3)
    k = np.array([[0, -c[2], c[1]], [c[2], 0, -c[0]], [-c[1], c[0], 0]]) / s
    return np.eye(3) + k * s + k @ k * (1 - d)


Q = np.zeros_like(P)
for i, (nm, j0, j1, rad, girth) in enumerate(SEG):
    p0, p1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    q0, q1 = T[j0], T[j1]
    up = p1 - p0
    ln = np.linalg.norm(up)
    u = up / ln
    v = (q1 - q0) / np.linalg.norm(q1 - q0)
    R = rot_between(u, v)
    sa = np.linalg.norm(q1 - q0) / ln
    r = P - p0
    ax = r @ u
    rad_v = (r - ax[:, None] * u) * girth
    Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + rad_v @ R.T)
print("fitted", Q.min(0).round(3), Q.max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()

# ---- contract weights
GROUP = {}
for i, nm in enumerate(names):
    if nm != "torso":
        GROUP[nm] = W[:, i].copy()
tw = W[:, 0]
k = smooth(0.98, 1.32, P[:, 2])                # the waist, wide: the chest turns 66 degrees at full draw (scan heights)
GROUP["root"], GROUP["hips"] = tw * (1 - k), tw * k
for sd in "RL":
    f = smooth(0.17, 0.11, P[:, 2])
    GROUP["foot." + sd] = GROUP["shin." + sd] * f
    GROUP["shin." + sd] = GROUP["shin." + sd] * (1 - f)
    # past the wrist the forearm is the hand's, cut away below
    jw = np.array(S_J["wrist." + sd], float)
    je = np.array(S_J["elbow." + sd], float)
    u = jw - je
    h = ((P - je) @ u) / (u @ u)
    hand = smooth(1.03, 1.1, h) * GROUP["forearm." + sd]
    GROUP["hand." + sd] = hand
    GROUP["forearm." + sd] = GROUP["forearm." + sd] - hand
for b, w in GROUP.items():
    g = src.vertex_groups.get(b) or src.vertex_groups.new(name=b)
    ids = np.nonzero(w > 0.01)[0]
    for vi, wv in zip(ids.tolist(), w[ids].tolist()):
        g.add([vi], wv, "REPLACE")
src.name = "Src"
low = src.copy()
low.data = src.data.copy()
low.name = "Low"
bpy.context.scene.collection.objects.link(low)
hand_w = GROUP["hand.R"] + GROUP["hand.L"]
bm = bmesh.new()
bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
bm.verts.ensure_lookup_table()
neck_z = T["neck"][2] - 0.045       # (under the cowl: the scan's stand collar must not show past the scarf)
kill = [f for f in bm.faces if f.calc_center_median().z > neck_z or max(hand_w[v.index] for v in f.verts) > 0.5]
# weld in the scan's pose, not the fitted one: fitted, the arms hang through the hips, and a weld there sews them together
fit = bm.verts.layers.float_vector.new("fit")
for v in bm.verts:
    v[fit] = v.co.copy()
    v.co = P[v.index].tolist()
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0006)
for v in bm.verts:
    v.co = v[fit]
bm.verts.layers.float_vector.remove(fit)
bm.to_mesh(low.data)
bm.free()
now = sum(len(p.vertices) - 2 for p in low.data.polygons)
m = low.modifiers.new("d", "DECIMATE")
m.ratio = min(1.0, LOW_TRIS / max(now, 1))
m.use_collapse_triangulate = True
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.modifier_apply(modifier=m.name)
# Meshy winds some triangles inward: Cycles draws both sides, the game culls them and shows holes (PIPELINE.md). recalc alone leaves many on an open scan, so each
# face is tested: a ray out along its normal that crosses the surface an odd number of times started inside. Arms apart from the body: fitted, they hang through the hips.
from mathutils import Vector
from mathutils.bvhtree import BVHTree
bm = bmesh.new()
bm.from_mesh(low.data)
bmesh.ops.triangulate(bm, faces=bm.faces)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.faces.ensure_lookup_table()
bm.verts.ensure_lookup_table()
dl = bm.verts.layers.deform.verify()
arm_g = {g.index for g in low.vertex_groups if g.name.startswith(("upper_arm", "forearm", "hand"))}
is_arm = [sum(w for k, w in v[dl].items() if k in arm_g) > 0.5 for v in bm.verts]
flip = []
for part in (True, False):
    fs = [f_ for f_ in bm.faces if (sum(is_arm[v.index] for v in f_.verts) >= 2) == part]
    if not fs:
        continue
    tree = BVHTree.FromPolygons([v.co.copy() for v in bm.verts], [[v.index for v in f_.verts] for f_ in fs], all_triangles=True)
    for f_ in fs:
        n_ = f_.normal
        o_ = f_.calc_center_median() + n_ * 2e-4
        hits = 0
        for _ in range(16):
            h_ = tree.ray_cast(o_, n_)
            if h_[0] is None:
                break
            hits += 1
            o_ = h_[0] + n_ * 2e-4
        if hits % 2:
            flip.append(f_)
print("faces turned out", len(flip), "of", len(bm.faces))
bmesh.ops.reverse_faces(bm, faces=flip)
bm.to_mesh(low.data)
bm.free()
print("Low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT)

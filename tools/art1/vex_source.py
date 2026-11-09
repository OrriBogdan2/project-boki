"""ART-1 Vex, stage A (from kael_source.py): the Meshy scan of the owner's v2 turnaround (briefs/art-refs/vex_v2/) -> the contract's rest pose.
Scan joints are read off gridded renders; each vertex gets soft weights by distance to the bone segments, then moves bone by
bone onto the rig (a length along the bone, a girth across it), so the proportions land on the armature without Blender's bone
heat. Then the rebuilt parts are cut away and the body decimated. In: the scan glb, kael_rig.json. Out: stage/source.blend,
objects Src (the fitted scan, the paint source) and Low (what ships), with vertex groups.
Run: blender -b --factory-startup --python tools/art1/kael_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth, norm

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 5400
CUT_FORE = 0.12                  # along the left forearm: the sleeve ends here
CHIN_Z = 1.668                   # the scan head goes above this; rebuilt from the scan in vex_head
SOLE = -0.946                   # the scan's sole (z)
ANKLE = 0.16                    # the rig has no ankle node: the foot bone sits here (sole on 0)
# Scan joints (flipped to face +Y, his right +X, z from the sole), measured on grid_front/grid_right.
S_J = {"neck": (0, -0.02, 1.616), "pelvis": (0, -0.02, 1.03), "crown": (0, -0.02, 1.896), "shoulder.R": (0.18, -0.02, 1.53), "elbow.R": (0.265, -0.02, 1.245),
       "wrist.R": (0.425, 0, 1.02), "shoulder.L": (-0.18, -0.02, 1.53), "elbow.L": (-0.258, -0.02, 1.245), "wrist.L": (-0.424, 0, 1.016), "hip.R": (0.095, -0.01, 1.0),
       "knee.R": (0.11, -0.02, 0.566), "ankle.R": (0.14, -0.07, 0.166), "hip.L": (-0.095, -0.01, 1.0), "knee.L": (-0.11, -0.02, 0.566), "ankle.L": (-0.136, -0.07, 0.166)}
# name: (scan head, scan tail, rig head bone, rig tail bone or point, reach radius, girth)
rig = json.load(open(RIG))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
HEAD_K = (np.array(T["neck"])[2] - np.array(T["pelvis"])[2]) / (S_J["neck"][2] - S_J["pelvis"][2]) * 1.0
T["crown"] = T["neck"] + np.array([0, 0, (S_J["crown"][2] - S_J["neck"][2]) * 1.08])
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, ANKLE])
SEG = [("torso", "pelvis", "neck", 0.20, 0.92), ("headseg", "neck", "crown", 0.09, 1.08)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.07, 0.95), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.055, 0.95),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.09, 0.95), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.06, 0.95)]

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
        d = np.linalg.norm(q * [0.62, 1.1, 1.0], axis=1)         # a wide, flat chest
    D[:, i] = d - rad
    if nm.endswith(".R"):
        D[P[:, 0] < -0.02, i] = 9.0
    if nm.endswith(".L"):
        D[P[:, 0] > 0.02, i] = 9.0
    if nm.startswith("thigh") or nm.startswith("shin"):
        D[P[:, 2] > 1.15, i] = 9.0
    if nm.startswith(("upper_arm", "forearm")):
        D[P[:, 2] < 0.74, i] = 9.0
    if nm == "headseg":
        D[P[:, 2] < 1.60, i] = 9.0
    if nm == "torso":
        D[P[:, 2] > 1.70, i] = 9.0
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
    if nm not in ("torso", "headseg"):
        GROUP[nm] = W[:, i].copy()
tw = W[:, 0]
GROUP["head"] = W[:, names.index("headseg")].copy()
k = smooth(1.06, 1.22, P[:, 2])                # the waist: pelvis on the root, chest on the hips (scan heights)
GROUP["root"], GROUP["hips"] = tw * (1 - k), tw * k
for sd in "RL":
    f = smooth(0.2, 0.15, P[:, 2])
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
    g = src.vertex_groups.new(name=b)
    ids = np.nonzero(w > 0.01)[0]
    for vi, wv in zip(ids.tolist(), w[ids].tolist()):
        g.add([vi], wv, "REPLACE")
src.name = "Src"
low = src.copy()
low.data = src.data.copy()
low.name = "Low"
bpy.context.scene.collection.objects.link(low)
# cut: her right forearm and hand (the minigun is her forearm from the elbow down, its cuff closes the sleeve), the left forearm below the sleeve and the hand (rebuilt in vex_arm)
elbow = np.array(S_J["elbow.L"], float); wrist = np.array(S_J["wrist.L"], float); u_ = wrist - elbow
hL = ((P - elbow) @ u_) / (u_ @ u_)
cutL = (hL > CUT_FORE) * (GROUP["forearm.L"] + GROUP["hand.L"]) 
cutR = GROUP["forearm.R"] + GROUP["hand.R"]
bm = bmesh.new()
bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
kill = [f for f in bm.faces if P[f.verts[0].index, 2] > CHIN_Z or max(cutL[v.index] for v in f.verts) > 0.5 or max(cutR[v.index] for v in f.verts) > 0.55]
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0006)
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
print("Low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT)

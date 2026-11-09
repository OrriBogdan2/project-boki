"""ART-1 Kael v2, stage A: the Meshy scan of the owner's v2 turnaround (briefs/art-refs/kael_v2/) -> the contract's rest pose.
Scan joints are read off gridded renders (~/meshy/tools/grid.py); each vertex gets soft weights by distance to the bone
segments, then moves bone by bone onto the rig (a length along the bone, a girth across it), so the proportions land on the
armature without Blender's bone heat. The scan keeps its own head, hair, scarf, shawl and fists; only the decimation is
ours. In: the scan glb, kael_rig.json. Out: stage/source.blend, objects Src (the fitted scan, the paint source) and Low
(what ships), with vertex groups.
Run: blender -b --factory-startup --python tools/art1/kael_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 11000
SOLE = -0.950                   # the scan's sole (z)
# Scan joints (flipped to face +Y, his right +X, z from the sole), measured on grid_front / grid_right.
S_J = {"neck": (0, 0.0, 1.60), "pelvis": (0, 0.0, 1.01), "crown": (0, 0.0, 1.83), "shoulder.R": (0.27, 0.0, 1.45),
       "elbow.R": (0.34, 0.0, 1.20), "wrist.R": (0.35, 0.03, 0.99), "shoulder.L": (-0.27, 0.0, 1.45), "elbow.L": (-0.34, 0.0, 1.20),
       "wrist.L": (-0.35, 0.03, 0.99), "hip.R": (0.115, 0.0, 0.95), "knee.R": (0.15, 0.0, 0.54), "ankle.R": (0.16, -0.02, 0.11),
       "hip.L": (-0.115, 0.0, 0.95), "knee.L": (-0.15, 0.0, 0.54), "ankle.L": (-0.16, -0.02, 0.11)}
Z_LEGS = 1.05                    # scan heights: no leg weight above, no arm weight below Z_ARMS, no head weight below Z_HEAD
Z_ARMS = 0.8
Z_HEAD = 1.56
rig = json.load(open(RIG))
CROWN = rig["land"]["crown"]
bones = rig["bones"]


def r_j(b):
    x, y, z = bones[b]["head"]
    return np.array([x, -z, y], float)


K = CROWN / S_J["crown"][2]
T = {"pelvis": r_j("hips"), "neck": r_j("head"), "crown": np.array([0.0, 0.0, CROWN])}
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, S_J["ankle." + sd][2] * T["knee." + sd][2] / S_J["knee." + sd][2]])
# name, scan joints, reach radius, girth
SEG = [("torso", "pelvis", "neck", 0.20, 1.07), ("headseg", "neck", "crown", 0.1, 1.0)]       # (girth: the sheet's broad build)
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.07, 1.12), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.06, 1.1),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.10, 1.0), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.07, 1.0)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
src = next(o for o in bpy.data.objects if o.type == "MESH" and len(o.data.vertices) > 1000)
for o in list(bpy.data.objects):
    if o is not src:
        bpy.data.objects.remove(o)
me = src.data
n = len(me.vertices)
co = np.zeros(n * 3)
me.vertices.foreach_get("co", co)
mw = np.array(src.matrix_world)
co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
src.parent = None
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
    q = P - (a0 + h[:, None] * u)
    d = np.linalg.norm(q * ([0.62, 1.1, 1.0] if nm == "torso" else 1.0), axis=1)        # a wide, flat chest
    D[:, i] = d - rad
    if nm.endswith(".R"):
        D[P[:, 0] < -0.02, i] = 9.0
    if nm.endswith(".L"):
        D[P[:, 0] > 0.02, i] = 9.0
    if nm.startswith(("thigh", "shin")):
        D[P[:, 2] > Z_LEGS, i] = 9.0
    if nm.startswith(("upper_arm", "forearm")):
        D[P[:, 2] < Z_ARMS, i] = 9.0
    if nm == "headseg":
        D[P[:, 2] < Z_HEAD, i] = 9.0
W = np.exp(-(D - D.min(1, keepdims=True)) / 0.016)
W /= W.sum(1, keepdims=True)


def rot_between(u, v):
    u, v = u / np.linalg.norm(u), v / np.linalg.norm(v)
    c = np.cross(u, v)
    s, d = np.linalg.norm(c), u @ v
    if s < 1e-7:
        return np.eye(3)
    k = np.array([[0, -c[2], c[1]], [c[2], 0, -c[0]], [-c[1], c[0], 0]]) / s
    return np.eye(3) + k * s + k @ k * (1 - d)


# ---- each bone moves its vertices onto the rig
Q = np.zeros_like(P)
for i, (nm, j0, j1, rad, girth) in enumerate(SEG):
    p0, p1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    q0, q1 = T[j0], T[j1]
    ln = np.linalg.norm(p1 - p0)
    u = (p1 - p0) / ln
    v = (q1 - q0) / np.linalg.norm(q1 - q0)
    R = rot_between(u, v)
    sa = np.linalg.norm(q1 - q0) / ln
    r = P - p0
    ax = r @ u
    across = (r - ax[:, None] * u) * girth * K       # across the bone: the whole hero's scale (the rig is shorter than the scan)
    Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + across @ R.T)
print("fitted", Q.min(0).round(3), Q.max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()

# ---- contract weights (main's armature: no foot bones, the feet ride the shins)
GROUP = {nm: W[:, i].copy() for i, nm in enumerate(names) if nm not in ("torso", "headseg")}
GROUP["head"] = W[:, names.index("headseg")].copy()
tw = W[:, 0]
k = smooth(S_J["pelvis"][2] + 0.06, S_J["pelvis"][2] + 0.22, P[:, 2])      # the waist: pelvis on the root, chest on the hips
GROUP["root"], GROUP["hips"] = tw * (1 - k), tw * k
for sd in "RL":
    jw, je = np.array(S_J["wrist." + sd], float), np.array(S_J["elbow." + sd], float)
    u = jw - je
    h = ((P - je) @ u) / (u @ u)
    hand = smooth(1.0, 1.08, h) * GROUP["forearm." + sd]
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
bm = bmesh.new()
bm.from_mesh(low.data)
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

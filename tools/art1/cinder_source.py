"""ART-1 Cinder, stage A: the Meshy scan of the owner's A-pose turnaround (hair, tail, tank, vials edited out) -> the contract's rest pose.
Same recipe as Kael's. Her own: the figure from the master sheet (a little fuller than the turnaround), and the apron found by its paint and hung
from the pelvis, so a stride doesn't tear it between the thighs.
Scan joints are read off gridded renders; each vertex gets soft weights by distance to the bone segments, then moves bone by
bone onto the rig (a length along the bone, a girth across it), so the proportions land on the armature without Blender's bone
heat. Then the rebuilt parts are cut away and the body decimated. In: the scan glb, cinder_rig.json. Out: stage/source.blend,
objects Src (the fitted scan, the paint source) and Low (what ships), with vertex groups.
Run: blender -b --factory-startup --python tools/art1/cinder_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth, norm

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 7700
SOLE = -0.95                    # the scan's sole (z)
ANKLE = 0.10                    # the rig has no ankle node: the foot bone sits here
# Scan joints (flipped to face +Y, his right +X, z from the sole), measured on grid_front/grid_right.
S_J = {"neck": (0, 0, 1.60), "pelvis": (0, 0, 0.98), "shoulder.R": (0.208, 0, 1.495), "elbow.R": (0.364, 0, 1.28), "wrist.R": (0.496, 0, 1.07),
       "shoulder.L": (-0.208, 0, 1.495), "elbow.L": (-0.364, 0, 1.28), "wrist.L": (-0.496, 0, 1.07), "hip.R": (0.118, 0, 1.0), "knee.R": (0.14, 0, 0.59),
       "ankle.R": (0.17, 0, 0.11), "hip.L": (-0.118, 0, 1.0), "knee.L": (-0.14, 0, 0.59), "ankle.L": (-0.17, 0, 0.11)}
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
SEG = [("torso", "pelvis", "neck", 0.17, 0.84)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.055, 0.84), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.045, 0.84),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.10, 0.84), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.065, 0.84)]

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

# ---- the master sheet's figure, a little fuller than the turnaround (stylised; the corset keeps its cut)
for s_ in (1.0, -1.0):
    c_ = np.array([s_ * 0.085, 0.10, 1.335])
    d_ = (P - c_) / np.array([0.10, 0.10, 0.095])
    k_ = np.exp(-np.sum(d_ * d_, 1) * 1.6) * (P[:, 1] > -0.02)
    P += k_[:, None] * np.array([s_ * 0.008, 0.028, -0.006])

# ---- which vertices are the apron: brown paint hanging in front of the thighs
tex = None
for mt in me.materials:
    for nd in mt.node_tree.nodes:
        if nd.type == "TEX_IMAGE" and nd.image is not None and "base" in nd.image.name.lower():
            tex = nd.image
if tex is None:
    tex = next(nd.image for mt in me.materials for nd in mt.node_tree.nodes if nd.type == "TEX_IMAGE")
tw_, th_ = tex.size
px_ = np.zeros(tw_ * th_ * tex.channels, np.float32)
tex.pixels.foreach_get(px_)
px_ = px_.reshape(th_, tw_, tex.channels)[..., :3]
uv_ = np.zeros(len(me.loops) * 2)
me.uv_layers.active.data.foreach_get("uv", uv_)
uv_ = uv_.reshape(-1, 2)
lv_ = np.zeros(len(me.loops), np.int64)
me.loops.foreach_get("vertex_index", lv_)
vuv = np.zeros((n, 2))
vuv[lv_] = uv_
cv = px_[np.clip((vuv[:, 1] % 1) * th_, 0, th_ - 1).astype(int), np.clip((vuv[:, 0] % 1) * tw_, 0, tw_ - 1).astype(int)]
sat_ = (cv.max(1) - cv.min(1)) / np.maximum(cv.max(1), 0.01)
apron = (np.abs(P[:, 0]) < 0.135) & (P[:, 1] > 0.035) & (P[:, 2] < 1.03) & (cv[:, 0] > cv[:, 2] * 1.25) & (cv[:, 0] > 0.14) & (P[:, 2] > 0.5)
print("apron verts", apron.sum())

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
        D[P[:, 2] > 1.13, i] = 9.0
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
k = smooth(1.08, 1.24, P[:, 2])                # the waist: pelvis on the root, chest on the hips (scan heights)
GROUP["root"], GROUP["hips"] = tw * (1 - k), tw * k
for sd in "RL":
    f = smooth(0.2, 0.15, P[:, 2]) * (1.0 if sd == "R" else 1.0)
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
# the apron hangs from the pelvis on the skirt bone, whatever the thighs do
ap_w = np.zeros(n)
ap_w[apron] = 1.0
if apron.any():
    for b in list(GROUP):
        GROUP[b] = GROUP[b] * (1 - ap_w)
    k2 = smooth(1.03, 0.88, P[:, 2]) * ap_w
    GROUP["root"] = GROUP["root"] + ap_w * (1 - k2)
    GROUP["skirt"] = k2
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
neck_z = T["neck"][2] + 0.02
kill = [f for f in bm.faces if f.calc_center_median().z > neck_z or max(hand_w[v.index] for v in f.verts) > 0.5]
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

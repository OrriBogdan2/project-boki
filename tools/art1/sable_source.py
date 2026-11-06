"""ART-1 Sable, stage A: the Meshy scan of the owner's A-pose turnaround (antennae, braid, wings, coat tails, pistols and belt hangers edited out) -> the contract's rest pose.
Recipe: kael_source.py / claire_source.py (soft weights by distance to the bones, then each bone moves its vertices onto the rig). Her own: the scan's head came out turned 30 degrees and with a
stray bun at the nape, so the head is turned back about its centre by the ears' line and the bun pressed into the skull; the white and lilac head is told from the dark high collar by its paint.
Run: blender -b --factory-startup --python tools/art1/sable_source.py -- <scan.glb> <small base colour.png> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, TEX, RIG, OUT = a[0], a[1], a[2], a[3]
LOW_TRIS, FACE_TRIS = 11000, 2600
SOLE = -0.95                    # the scan's sole (z)
K_ = 0.92                       # scan metres -> rig metres, where a bone's length doesn't set it
SOLE_Z, ANKLE = 0.0, 0.145      # the rig: the boot's sole, the foot bone
S_J = {"neck": (0, 0, 1.60), "pelvis": (0, 0, 1.02), "crown": (0, 0, 1.92)}
for sd, sg in (("R", 1.0), ("L", -1.0)):
    S_J.update({"shoulder." + sd: (sg * 0.165, 0, 1.515), "elbow." + sd: (sg * 0.335, 0, 1.27), "wrist." + sd: (sg * 0.515, 0, 1.01), "hip." + sd: (sg * 0.105, 0, 0.955),
                "knee." + sd: (sg * 0.185, 0, 0.625), "ankle." + sd: (sg * 0.25, 0, 0.16), "sole." + sd: (sg * 0.26, 0, 0.0)})
rig = json.load(open(RIG))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
T["crown"] = T["neck"] + np.array([0, 0, (1.92 - 1.60) * K_])
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, ANKLE])
    T["sole." + sd] = np.array([T["knee." + sd][0], 0, SOLE_Z])
SEG = [("torso", "pelvis", "neck", 0.17, 0.92), ("head", "neck", "crown", 0.16, K_)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.05, 0.86), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.042, 0.86),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.09, 0.9), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.06, 0.9),
            ("foot." + sd, "ankle." + sd, "sole." + sd, 0.05, 0.9)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
ms = [o for o in bpy.data.objects if o.type == "MESH"]
src = ms[0]
for o in list(bpy.data.objects):
    if o is not src:
        bpy.data.objects.remove(o)
src.parent = None
me = src.data
n = len(me.vertices)
co = np.zeros(n * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
mw = np.array(src.matrix_world)
co = co @ mw[:3, :3].T + mw[:3, 3]
src.matrix_world = Matrix.Identity(4)
P = np.stack([-co[:, 0], -co[:, 1], co[:, 2] - SOLE], 1)        # to +Y facing, sole on 0
print("scan", n, P.min(0).round(3), P.max(0).round(3))

# ---- each vertex's paint, off a small copy of the scan's base colour
tex = bpy.data.images.load(TEX)
tw, th_ = tex.size
tp = np.array(tex.pixels[:], np.float32).reshape(th_, tw, tex.channels)[..., :3]
luv = np.zeros(len(me.loops) * 2)
me.uv_layers.active.data.foreach_get("uv", luv)
luv = luv.reshape(-1, 2)
lv = np.zeros(len(me.loops), np.int64)
me.loops.foreach_get("vertex_index", lv)
vuv = np.zeros((n, 2))
vuv[lv] = luv
tx = np.clip((vuv[:, 0] % 1) * tw, 0, tw - 1).astype(int)
ty = np.clip((vuv[:, 1] % 1) * th_, 0, th_ - 1).astype(int)
lum = tp[ty, tx].mean(1)
bright = lum > 0.38

# ---- the head: turned back to the front, by the line through the ear tips
hd = bright & (P[:, 2] > 1.6)
upper = hd & (P[:, 2] > 1.74)
cen = P[upper].mean(0)
print("skull", cen.round(3))
band = hd & (P[:, 2] > 1.70) & (P[:, 2] < 1.84)
d2 = P[band][:, :2] - cen[:2]
rr = np.linalg.norm(d2, axis=1)
t1 = d2[np.argmax(rr)]
oth = d2 @ t1 < 0
t2 = d2[oth][np.argmax(rr[oth])]
ax = t1 - t2
if ax[0] < 0:
    ax = -ax
YAW = -np.arctan2(ax[1], ax[0]) + np.radians(5.0)     # (the ears sit a little off the face's own line)
print("ears", t1.round(3), t2.round(3), "yaw deg", round(float(np.degrees(YAW)), 1))
E_C, E_R = np.array([0, cen[1], 1.75]), np.array([0.135, 0.15, 0.165])
inside = (np.linalg.norm((P - E_C) / E_R, axis=1) < 1.2) & (P[:, 2] > 1.66)       # the dark eyes and lashes turn with the head
ramp = smooth(1.545, 1.60, P[:, 2]) * (bright | inside)
ang = YAW * ramp
c_, s_ = np.cos(ang), np.sin(ang)
q = P[:, :2] - cen[:2]
SKY = -0.015
shift = np.array([-cen[0], SKY - cen[1]])
P[:, 0], P[:, 1] = q[:, 0] * c_ - q[:, 1] * s_ + cen[0] + shift[0] * ramp, q[:, 0] * s_ + q[:, 1] * c_ + cen[1] + shift[1] * ramp
# the bun: everything bright or metal behind the skull's ellipsoid below the crown is pressed onto it (the braid's root covers the place)
E_C, E_R = np.array([0, SKY, 1.75]), np.array([0.135, 0.15, 0.165])
e = (P - E_C) / E_R
er = np.linalg.norm(e, axis=1)
bun = (P[:, 2] > 1.42) & (P[:, 1] < -0.05) & (er > 0.98) & (np.abs(P[:, 0]) < 0.2) & (lum > 0.3)
P[bun] = E_C + e[bun] / er[bun, None] * 0.98 * E_R
print("bun verts", int(bun.sum()))

# ---- soft weights by distance to the segments
names = [s[0] for s in SEG]
D = np.zeros((n, len(SEG)))
Z0, x = P[:, 2].copy(), P[:, 0]
is_head = (bright & (Z0 > 1.588)) | (Z0 > 1.67) | ((Z0 > 1.64) & (np.hypot(P[:, 0], P[:, 1] - SKY) < 0.1))
rt = np.minimum.reduce([np.hypot(P[:, 0] - sg * (0.105 + (0.955 - Z0) * 0.24), P[:, 1]) for sg in (1.0, -1.0)])
jacket = (Z0 > 0.925) & (rt > 0.098)                    # the jacket's flared hem stays on the pelvis
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    u = a1 - a0
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    qq = P - (a0 + h[:, None] * u)
    d = np.linalg.norm(qq * [0.8, 1.05, 1.0], axis=1) if nm == "torso" else np.linalg.norm(qq, axis=1)
    D[:, i] = d - rad
    if nm == "torso":
        D[(np.abs(x) > 0.2) & (Z0 > 1.12), i] = 9.0     # the sleeve's inner side stays on the arm: a bent arm would stretch it back to the waist
    if nm.endswith(".R"):
        D[x < -0.02, i] = 9.0
    if nm.endswith(".L"):
        D[x > 0.02, i] = 9.0
    if nm == "head":
        D[~is_head, i] = 9.0
    else:
        D[is_head, i] = 9.0
    if nm.startswith(("thigh", "shin", "foot")):
        D[Z0 > 1.0, i] = 9.0
        D[jacket, i] = 9.0
    if nm.startswith("shin"):
        D[Z0 < 0.12, i] = 9.0
    if nm.startswith("foot"):
        D[Z0 > 0.2, i] = 9.0
    if nm.startswith(("upper_arm", "forearm")):
        D[np.abs(x) < 0.13, i] = 9.0
W = np.exp(-(D - D.min(1, keepdims=True)) / 0.014)
W /= W.sum(1, keepdims=True)


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
    ax_ = r @ u
    rad_v = (r - ax_[:, None] * u) * girth
    Q += W[:, i, None] * (q0 + ax_[:, None] * sa * v + rad_v @ R.T)
print("fitted", Q.min(0).round(3), Q.max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()
# where the jacket's hem and the belt landed: the tails and hangers start there
hemb = (Z0 > 0.975) & (Z0 < 1.0) & (np.abs(P[:, 0]) < 0.3)
belt = (Z0 > 1.03) & (Z0 < 1.05) & (np.abs(P[:, 0]) < 0.15)
src["hem_z"] = float(np.median(Q[hemb, 2]))
src["hem_rx"] = float(np.percentile(np.abs(Q[hemb, 0]), 96))
src["hem_ry"] = float((np.percentile(Q[hemb, 1], 98) - np.percentile(Q[hemb, 1], 2)) / 2)
src["hem_cy"] = float((np.percentile(Q[hemb, 1], 98) + np.percentile(Q[hemb, 1], 2)) / 2)
src["belt_z"] = float(np.median(Q[belt, 2]))
src["belt_y"] = float(np.percentile(Q[belt, 1], 96))
print("hem", src["hem_z"], src["hem_rx"], src["hem_ry"], src["hem_cy"], "belt", src["belt_z"], src["belt_y"])

# ---- contract weights
GROUP = {}
for i, nm in enumerate(names):
    if nm != "torso":
        GROUP[nm] = W[:, i].copy()
tw_ = W[:, 0]
kz = smooth(1.12, 1.27, Z0)                     # the waist: pelvis on the root, chest on the hips
GROUP["root"], GROUP["hips"] = tw_ * (1 - kz), tw_ * kz
for sd, sg in (("R", 1.0), ("L", -1.0)):
    jw = np.array(S_J["wrist." + sd], float)
    je = np.array(S_J["elbow." + sd], float)
    u = jw - je
    h = ((P - je) @ u) / (u @ u)
    hand = smooth(1.02, 1.07, h) * GROUP["forearm." + sd]
    GROUP["hand." + sd] = hand
    GROUP["forearm." + sd] = GROUP["forearm." + sd] - hand
for b, w in GROUP.items():
    g = src.vertex_groups.get(b) or src.vertex_groups.new(name=b)
    ids = np.nonzero(w > 0.01)[0]
    for vi, wv in zip(ids.tolist(), w[ids].tolist()):
        g.add([vi], wv, "REPLACE")
src["sole_z"] = SOLE_Z
src.name = "Src"
low = src.copy()
low.data = src.data.copy()
low.name = "Low"
bpy.context.scene.collection.objects.link(low)
hand_w = GROUP["hand.R"] + GROUP["hand.L"]
bm = bmesh.new()
bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
# the hands go (rebuilt); the bun's crumpled patch goes too (left in, its folds take the whole decimate budget); the holes are capped after the decimate, which stalls on caps
kill = [f for f in bm.faces if max(hand_w[v.index] for v in f.verts) > 0.5 or any(bun[v.index] for v in f.verts)]
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
bm.to_mesh(low.data)
bm.free()
HN = T["neck"]
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low


def decimate(pick, target):
    """Edit-mode decimate of the faces pick() marks: the selection's border stays, so the two regions keep meeting."""
    bpy.ops.object.mode_set(mode="OBJECT")
    c0 = np.zeros(len(low.data.vertices) * 3)
    low.data.vertices.foreach_get("co", c0)
    c0 = c0.reshape(-1, 3)
    sel = pick(np.array([c0[list(p.vertices)].mean(0) for p in low.data.polygons]))
    low.data.polygons.foreach_set("select", sel.tolist())
    low.data.edges.foreach_set("select", [False] * len(low.data.edges))
    low.data.vertices.foreach_set("select", [False] * len(low.data.vertices))
    low.data.update()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    tris = int(sel.sum())
    bpy.ops.mesh.decimate(ratio=min(1.0, target / max(tris, 1)))
    bpy.ops.object.mode_set(mode="OBJECT")


def is_face(c):
    return (np.abs(c[:, 0]) < 0.095) & (c[:, 1] > 0.02) & (c[:, 2] > HN[2] - 0.01) & (c[:, 2] < HN[2] + 0.2)


decimate(is_face, FACE_TRIS)
decimate(lambda c: ~is_face(c), LOW_TRIS - FACE_TRIS)
bm = bmesh.new()
bm.from_mesh(low.data)
cap = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=400)
bmesh.ops.triangulate(bm, faces=[f for f in cap["faces"] if len(f.verts) > 3])
bm.to_mesh(low.data)
bm.free()
print("Low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT)

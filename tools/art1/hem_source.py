"""ART-1 Ravel v2 (ids stay `hem`), stage A: the Meshy scan of the A-pose turnaround (crossed needles, bun needles and the
skirt below the knee edited out) -> the contract's rest pose. Recipe: ryzz_source.py / kael_source.py. Her own: the skirt
fits the knee on its own segment, the right hand turns palm-in for the finger bones, the shoulder mask rides the upper
arm, the long hair hangs on the tail chain, the left hand is cut for the closed bow fist (hem_pieces.fist).
Run: blender -b --factory-startup --python tools/art1/hem_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 12900
FACE_TRIS = 2300
HAND_TRIS = 900
MASK_TRIS = 900                   # the shoulder mask keeps its face
SOLE = -0.951
HEEL_Z = 0.015                    # the scan's boots keep a small heel: everything under the toe's sole is cut flat
ANKLE = 0.1
HEAD_K = 1.06                     # the head a touch big for the match camera
HAND_TWIST = -np.pi / 2           # the scan's palm faces forward, the rig's faces her thigh
HAIR_Z = (1.62, 1.215)            # scan heights: the hair leaves the head, its tip
ARM_SLOPE = 0.6056                # scan: the forearm's run in x per unit of z
HEM_Z = 0.56                      # scan: the skirt's hem
MASK_Z = (1.355, 1.6)             # scan: the shoulder mask's height
S_J = {"neck": (0, 0.02, 1.605), "pelvis": (0, -0.01, 0.99), "shoulder.R": (0.155, -0.02, 1.5), "elbow.R": (0.26, -0.02, 1.26), "wrist.R": (0.3875, -0.02, 1.05),
       "tip.R": (0.465, -0.02, 0.875), "hip.R": (0.09, -0.01, 1.03), "knee.R": (0.075, 0, 0.545), "ankle.R": (0.085, -0.03, ANKLE), "sole.R": (0.085, -0.03, 0.0),
       "crown": (0, 0.02, 1.9), "hem": (0, 0, HEM_Z)}
for k_ in list(S_J):
    if k_.endswith(".R"):
        x, y, z = S_J[k_]
        S_J[k_[:-1] + "L"] = (-x, y, z)
# scan points on the right hand (x, z): the finger bones' knuckles and tips, the thumb's base, middle and tip
FINGER_A = ((0.4675, 0.9425), (0.463, 0.905), (0.4575, 0.875))
FINGER_B = ((0.425, 0.9425), (0.4275, 0.91), (0.4225, 0.88))
THUMB = ((0.4375, 1.0), (0.4575, 0.9875), (0.4825, 0.9725))
FINGER_SPLIT = 0.4575             # scan x: the index finger is outside it
FINGER_Z = 0.948                  # scan z: the fingers start under it
rig = json.load(open(RIG))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
T["crown"] = T["neck"] + np.array([0, 0, (S_J["crown"][2] - S_J["neck"][2]) * HEAD_K])
T["hem"] = np.array([0, 0, r_j("shin.R")[2] + (HEM_Z - S_J["knee.R"][2]) * 0.84])
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["tip." + sd] = T["wrist." + sd] + np.array([0, 0, -0.165])
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, ANKLE])
    T["sole." + sd] = np.array([T["knee." + sd][0], 0, 0.0])
SEG = [("torso", "pelvis", "neck", 0.15, 0.96), ("head", "neck", "crown", 0.14, HEAD_K), ("skirt", "pelvis", "hem", 0.3, 0.86)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.055, 0.92), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.042, 0.92),
            ("hand." + sd, "wrist." + sd, "tip." + sd, 0.04, 1.0),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.09, 0.92), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.06, 0.92),
            ("foot." + sd, "ankle." + sd, "sole." + sd, 0.05, 0.94)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
src = [o for o in bpy.data.objects if o.type == "MESH"][0]
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
P = np.stack([-co[:, 0], -co[:, 1], co[:, 2] - SOLE], 1)
P[:, 2] = np.maximum(P[:, 2], HEEL_Z) - HEEL_Z
print("scan", n, P.min(0).round(3), P.max(0).round(3))

# the paint per vertex tells hair and cloth from skin
tex = next(lk.from_node.image for nd in me.materials[0].node_tree.nodes if nd.type == "BSDF_PRINCIPLED" for lk in nd.inputs["Base Color"].links)
tex = tex.copy()
tex.scale(1024, 1024)
px = np.array(tex.pixels[:], np.float32).reshape(1024, 1024, 4)
loops = np.zeros(len(me.loops), int)
me.loops.foreach_get("vertex_index", loops)
luv = np.zeros(len(me.loops) * 2)
me.uv_layers[0].data.foreach_get("uv", luv)
luv = luv.reshape(-1, 2)
vuv = np.zeros((n, 2))
vuv[loops] = luv
ij = np.clip((vuv * 1024).astype(int), 0, 1023)
lum = px[ij[:, 1], ij[:, 0], :3].mean(1)
dark = lum < 0.32


def seg_d(p, a0, a1):
    a0, a1 = np.array(a0, float), np.array(a1, float)
    u = a1 - a0
    h = np.clip(((p - a0) @ u) / (u @ u), 0, 1)
    return np.linalg.norm(p - (a0 + h[:, None] * u), axis=1)


x, z = P[:, 0], P[:, 2]
rt = np.minimum(seg_d(P, S_J["hip.R"], S_J["knee.R"]), seg_d(P, S_J["hip.L"], S_J["knee.L"]))
sk = ((rt > 0.096) | (dark & (rt > 0.07) & (z > 0.62))) * smooth(HEM_Z - 0.09, HEM_Z - 0.06, z) * smooth(1.03, 0.98, z) * (np.abs(x) < 0.33)
hair = dark & (P[:, 1] < -0.075) & (z > HAIR_Z[1] - 0.02) & (z < HAIR_Z[0]) & (np.abs(x) < 0.15)
is_head = (z > S_J["neck"][2]) | (dark & (z > 1.54) & (np.abs(x) > 0.085) & (np.abs(x) < 0.2))
mask = (z > MASK_Z[0]) & (z < MASK_Z[1]) & (x < -0.125) & ~hair & ~is_head

# the right hand turns palm-in about its own axis, the bracelet takes the twist
wr, tp = np.array(S_J["wrist.R"], float), np.array(S_J["tip.R"], float)
u_h = (tp - wr) / np.linalg.norm(tp - wr)
h_t = (P - wr) @ u_h
ang = HAND_TWIST * smooth(-0.012, 0.018, h_t) * (x > 0.3)
hr = P - wr
par = (hr @ u_h)[:, None] * u_h
perp = hr - par
P0 = P.copy()
P = wr + par + perp * np.cos(ang)[:, None] + np.cross(u_h, perp) * np.sin(ang)[:, None]
P = np.where((x > 0.3)[:, None], P, P0)
x, z = P[:, 0], P[:, 2]

names = [s[0] for s in SEG]
inner = (z < 1.2) & (np.abs(x) < np.minimum(S_J["elbow.R"][0] + (S_J["elbow.R"][2] - z) * ARM_SLOPE - 0.065, 0.335))   # the body side of the arm
D = np.zeros((n, len(SEG)))
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    u = a1 - a0
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    q = P - (a0 + h[:, None] * u)
    d = np.linalg.norm(q * [0.8, 1.1, 1.0], axis=1) if nm == "torso" else np.linalg.norm(q, axis=1)
    D[:, i] = d - rad
    if nm.endswith(".R"):
        D[x < -0.02, i] = 9.0
    if nm.endswith(".L"):
        D[x > 0.02, i] = 9.0
    if nm == "head":
        D[~is_head, i] = 9.0
    else:
        D[is_head, i] = 9.0
    if nm.startswith(("thigh", "shin", "foot")):
        D[z > 1.04, i] = 9.0
        D[sk > 0.5, i] = 9.0
    if nm.startswith("shin"):
        D[z < 0.1, i] = 9.0
    if nm.startswith("foot"):
        D[z > 0.17, i] = 9.0
    if nm.startswith(("upper_arm", "forearm", "hand")):
        D[inner, i] = 9.0
    if nm.startswith("hand"):
        D[(np.abs(x) < 0.34) | (z > 1.06), i] = 9.0
    if nm in ("torso",):
        D[(np.abs(x) > 0.3) | (~inner & (z < 1.2)), i] = 9.0
        D[mask, i] = 9.0
    if nm == "skirt":
        D[:, i] = 9.0
    if nm == "upper_arm.L":
        D[mask, i] = -1.0
W = np.exp(-(D - D.min(1, keepdims=True)) / 0.014)
W /= W.sum(1, keepdims=True)
W *= (1.0 - sk)[:, None]
W[:, names.index("skirt")] += sk


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
    Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + ((r - ax[:, None] * u) * girth) @ R.T)
print("fitted", Q.min(0).round(3), Q.max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()

GROUP = {nm: W[:, i].copy() for i, nm in enumerate(names) if nm not in ("torso", "skirt")}
tw, sw = W[:, 0], W[:, names.index("skirt")]
k = smooth(1.12, 1.24, z)                     # the waist: pelvis on the root, chest on the hips
GROUP["root"], GROUP["hips"] = tw * (1 - k), tw * k
# the skirt hangs from the pelvis: down it the skirt bone, the thigh on its side, the spring chains at the hem
down = smooth(1.0, 0.7, z)
GROUP["skirt"] = sw * down * 0.5
for sd, sg in (("R", 1.0), ("L", -1.0)):
    GROUP["thigh." + sd] = GROUP["thigh." + sd] + sw * down * 0.32 * smooth(-0.03, 0.03, sg * x)
GROUP["root"] = GROUP["root"] + sw * (1 - down * 0.82)


def on_chain(prefix, s, w):
    """Weights w over a 6-bone chain at the chain parameter s (0 root, 6 tip)."""
    s = np.clip(s, 0, 5.999)
    i0 = s.astype(int)
    f = s - i0
    for b in range(6):
        nm = "%s_%d" % (prefix, b)
        GROUP[nm] = GROUP.get(nm, 0.0) + w * ((i0 == b) * (1 - f) + (i0 + 1 == b) * f)


SKIRT_CHAIN = {"R": ((0.2, -0.1, 0.8), (0.26, -0.14, 0.12)), "L": ((-0.2, -0.1, 0.8), (-0.26, -0.14, 0.12))}
hem_w = sw * smooth(0.82, 0.6, z) * 0.18
GROUP["skirt"] = GROUP["skirt"]
GROUP["root"] = np.maximum(GROUP["root"] - hem_w, 0.0)
for sd, sg in (("R", 1.0), ("L", -1.0)):
    (c0, c1) = SKIRT_CHAIN[sd]
    on_chain("spring_scarftail" + sd, (c0[2] - Q[:, 2]) / (c0[2] - c1[2]) * 6, hem_w * smooth(-0.04, 0.04, sg * x))

# the long hair on the tail chain: its root on the head
s_h = (HAIR_Z[0] - z) / (HAIR_Z[0] - HAIR_Z[1])
hw = tw * hair
for nm in ("root", "hips"):
    GROUP[nm] = GROUP[nm] * (1 - hair)
GROUP["head"] = GROUP["head"] + hw * smooth(0.22, 0.05, s_h)
on_chain("spring_tail", s_h * 6, hw * smooth(0.05, 0.22, s_h))
zs = np.linspace(HAIR_Z[0] - 0.02, HAIR_Z[1] + 0.03, 8)
tail_pts = [Q[hair & (np.abs(z - zz) < 0.03)].mean(0).tolist() for zz in zs]

# the right hand's fingers (scan x, z)
hand_w = GROUP["hand.R"]
x0, z0 = P0[:, 0], P0[:, 2]
thumb = (seg_d(np.stack([x0, 0 * x0, z0], 1), (THUMB[0][0], 0, THUMB[0][1]), (THUMB[2][0], 0, THUMB[2][1])) < 0.0215) & (z0 > 0.955)
fingers = (z0 < FINGER_Z) & ~thumb
index = fingers & (x0 > FINGER_SPLIT)
rest = fingers & (x0 <= FINGER_SPLIT)


def on_finger(sel, pts, b1, b2):
    a0, a1, a2 = [np.array((p[0], p[1])) for p in pts]
    q = np.stack([x0, z0], 1)
    t = (q - a0) @ (a2 - a0) / ((a2 - a0) @ (a2 - a0))
    w = hand_w * sel
    k1 = smooth(-0.08, 0.1, t)
    k2 = smooth(0.32, 0.5, t)
    GROUP[b1] = w * k1 * (1 - k2)
    GROUP[b2] = w * k2
    GROUP["hand.R"] = GROUP["hand.R"] - w * k1


on_finger(index, FINGER_A, "fing_a1.R", "fing_a2.R")
on_finger(rest, FINGER_B, "fing_b1.R", "fing_b2.R")
on_finger(thumb, THUMB, "thumb1.R", "thumb2.R")


def fitted(xz):
    """Where a scan point of the right hand landed."""
    d = np.linalg.norm(np.stack([x0, z0], 1) - np.array(xz), axis=1) + (x0 < 0.33) * 9.0
    return Q[np.argsort(d)[:12]].mean(0).tolist()


META = {"tail": tail_pts, "skirt_chain": SKIRT_CHAIN, "fing_a": [fitted(p) for p in FINGER_A], "fing_b": [fitted(p) for p in FINGER_B], "thumb": [fitted(p) for p in THUMB]}

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
bm.faces.ensure_lookup_table()
hl = GROUP["hand.L"]
kill = [f for f in bm.faces if max(hl[v.index] for v in f.verts) > 0.5]
print(len(kill), "faces cut")
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0006)
seen = set()                                  # scan crumbs: the slivers beside the boots
for v0 in [v for v in bm.verts if v.co.z < 0.45 and abs(v.co.y + 0.03) < 0.03 and 0.1 < abs(v.co.x) < 0.16]:
    if v0 in seen:
        continue
    seen.add(v0)
    part, st = [v0], [v0]
    while st:
        for e in st.pop().link_edges:
            for q in e.verts:
                if q not in seen:
                    seen.add(q)
                    part.append(q)
                    st.append(q)
    if len(part) < 20000:
        bmesh.ops.delete(bm, geom=part, context="VERTS")
bm.to_mesh(low.data)
bm.free()
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
HN = T["neck"]
HAND_C = T["wrist.R"] + np.array([0, 0, -0.09])


def decimate(pick, target):
    """Edit-mode decimate of the faces pick() marks: the selection's border stays, so the regions keep meeting (claire_source)."""
    bpy.ops.object.mode_set(mode="OBJECT")
    co_ = np.zeros(len(low.data.vertices) * 3)
    low.data.vertices.foreach_get("co", co_)
    co_ = co_.reshape(-1, 3)
    sel = pick(np.array([co_[list(p.vertices)].mean(0) for p in low.data.polygons]))
    low.data.polygons.foreach_set("select", sel.tolist())
    low.data.edges.foreach_set("select", [False] * len(low.data.edges))
    low.data.vertices.foreach_set("select", [False] * len(low.data.vertices))
    low.data.update()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.decimate(ratio=min(1.0, target / max(int(sel.sum()), 1)))
    bpy.ops.object.mode_set(mode="OBJECT")


def is_face(c):
    return (np.abs(c[:, 0]) < 0.105) & (c[:, 1] > 0.0) & (c[:, 2] > HN[2] - 0.0) & (c[:, 2] < HN[2] + 0.24)


def is_hand(c):
    return np.linalg.norm(c - HAND_C, axis=1) < 0.11


def is_mask(c):
    return (c[:, 0] < -0.11) & (c[:, 2] > 1.2) & (c[:, 2] < 1.5)


decimate(is_face, FACE_TRIS)
decimate(is_hand, HAND_TRIS)
decimate(is_mask, MASK_TRIS)
decimate(lambda c: ~is_face(c) & ~is_hand(c) & ~is_mask(c), LOW_TRIS - FACE_TRIS - HAND_TRIS - MASK_TRIS)
print("Low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bpy.context.scene["hem"] = json.dumps(META)
bpy.ops.wm.save_as_mainfile(filepath=OUT)

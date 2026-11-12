"""ART-1 Cinder v2 (ids stay `ashwick` / `cinder`), stage A: the Meshy scan of the A-pose turnaround (tank, hose, goggles and tail
edited out, DECISIONS 'Cinder the Flame Queen') -> the contract's rest pose. Recipe: hem_source.py / kael_source.py. Her own: both
hands stay open for casting, so each gets fingers and thumb groups; the long hair leaves the head on the hairr/hairl/hairc chains;
the heels keep their height (ANKLE); the tail is new geometry (cinder_pieces), the scan has none.
Run: blender -b --factory-startup --python tools/art1/cinder_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 12500
FACE_TRIS = 2300
HAND_TRIS = 800                   # each: the fingers are the casting read
HORN_TRIS = 300
SOLE = -0.951
ANKLE = 0.13                      # the heel holds the ankle up
HEAD_K = 1.0
HAIR_BACK = 1.27                  # scan: the back hair's tip
HAIR_FRONT = 1.38                 # scan: the front locks' tip
HAIR_TOP = 1.56                   # scan: under this hair is told from skin by paint
S_J = {"neck": (0, 0.0, 1.54), "pelvis": (0, 0.0, 0.98), "shoulder.R": (0.195, -0.02, 1.455), "elbow.R": (0.29, -0.035, 1.24), "wrist.R": (0.41, 0.04, 1.055),
       "tip.R": (0.46, 0.045, 0.855), "hip.R": (0.12, 0.0, 0.98), "knee.R": (0.125, 0.01, 0.59), "ankle.R": (0.158, -0.06, 0.17), "sole.R": (0.178, -0.05, 0.0),
       "crown": (0, 0.0, 1.83)}
for k_ in list(S_J):
    if k_.endswith(".R"):
        x, y, z = S_J[k_]
        S_J[k_[:-1] + "L"] = (-x, y, z)
KNUCKLE_Z = 0.962                 # scan z: the fingers start under it
THUMB = ((0.395, 1.03), (0.3825, 0.92))    # scan (x, z): base, tip
rig = json.load(open(RIG))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
T["crown"] = T["neck"] + np.array([0, 0, (S_J["crown"][2] - S_J["neck"][2]) * HEAD_K])
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["tip." + sd] = T["wrist." + sd] + np.array([0, 0, -0.175])
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, ANKLE])
    T["sole." + sd] = np.array([T["knee." + sd][0], 0, 0.0])
SEG = [("torso", "pelvis", "neck", 0.15, 0.95), ("head", "neck", "crown", 0.14, HEAD_K)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.055, 0.9), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.042, 0.9),
            ("hand." + sd, "wrist." + sd, "tip." + sd, 0.04, 0.9),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.09, 0.88), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.06, 0.88),
            ("foot." + sd, "ankle." + sd, "sole." + sd, 0.05, 0.9)]

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
P[:, 2] = np.maximum(P[:, 2], 0.0)
print("scan", n, P.min(0).round(3), P.max(0).round(3))

# the paint per vertex tells hair from skin and armour
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
col = px[ij[:, 1], ij[:, 0], :3]
lum = col.mean(1)
ember = (col[:, 0] - col[:, 1]) > 0.2
edges = np.zeros(len(me.edges) * 2, int)
me.edges.foreach_get("vertices", edges)
edges = edges.reshape(-1, 2)


def clean(m, passes=3):
    """A majority vote over the mesh's edges: paint specks don't move vertices between bones."""
    m = m.astype(np.float32)
    deg = np.bincount(edges.ravel(), minlength=n).astype(np.float32) + 1
    for _ in range(passes):
        s = m.copy()
        np.add.at(s, edges[:, 0], m[edges[:, 1]])
        np.add.at(s, edges[:, 1], m[edges[:, 0]])
        m = (s / deg > 0.5).astype(np.float32)
    return m > 0.5


x, y, z = P[:, 0], P[:, 1], P[:, 2]
ax_ = np.abs(x)
inked = ember | (lum < 0.26)
back = (y < -0.05) & (z > HAIR_BACK) & (ax_ < np.where(z < 1.45, 0.16, 0.19)) & inked
front = (ax_ > 0.055) & (ax_ < 0.19) & (z > HAIR_FRONT) & (y > -0.05) & (y < 0.13) & inked
hair = clean((back | front) & (z < HAIR_TOP + 0.3))
is_head = (z > S_J["neck"][2]) | hair
if os.environ.get("CINDER_DEBUG"):
    np.save(os.environ["CINDER_DEBUG"], np.column_stack([P, hair]))

names = [s[0] for s in SEG]
arm_x = np.minimum(S_J["elbow.R"][0] + (S_J["elbow.R"][2] - z) * 0.46 - 0.075, 0.33)
inner = (z < 1.34) & (ax_ < arm_x)                             # the body side of the arm
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
        D[hair, i] = -1.0
    else:
        D[is_head, i] = 9.0
    if nm.startswith(("thigh", "shin", "foot")):
        D[z > 1.04, i] = 9.0
        D[(ax_ > 0.27) & (z > 0.8), i] = 9.0
    if nm.startswith("shin"):
        D[z < 0.1, i] = 9.0
    if nm.startswith("foot"):
        D[z > 0.21, i] = 9.0
    if nm.startswith(("upper_arm", "forearm", "hand")):
        D[inner, i] = 9.0
    if nm.startswith("hand"):
        D[(ax_ < 0.36) | (z > 1.075), i] = 9.0
    if nm == "torso":
        D[(ax_ > 0.3) | (~inner & (z < 1.34)), i] = 9.0
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
    ax = r @ u
    Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + ((r - ax[:, None] * u) * girth) @ R.T)
print("fitted", Q.min(0).round(3), Q.max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()

GROUP = {nm: W[:, i].copy() for i, nm in enumerate(names) if nm != "torso"}
tw = W[:, 0]
k = smooth(1.1, 1.24, z)                      # the waist: pelvis on the root, chest on the hips
GROUP["root"], GROUP["hips"] = tw * (1 - k), tw * k


def on_chain(prefix, count, s, w):
    """Weights w over a bone chain at the chain parameter s (0 root, count tip)."""
    s = np.clip(s, 0, count - 0.001)
    i0 = s.astype(int)
    f = s - i0
    for b in range(count):
        nm = "%s_%d" % (prefix, b)
        GROUP[nm] = GROUP.get(nm, 0.0) + w * ((i0 == b) * (1 - f) + (i0 + 1 == b) * f)


# the hair: rooted on the head, then down the three chains. Back mass on hairc, the side locks on hairr / hairl
LOW_HAIR = np.where(y < -0.05, HAIR_BACK, HAIR_FRONT)
s_h = (HAIR_TOP - z) / (HAIR_TOP - LOW_HAIR)
sw = W[:, names.index("head")] * hair * smooth(0.12, 0.45, s_h)
GROUP["head"] = GROUP["head"] - sw
side = smooth(0.03, 0.09, ax_) * (y > -0.05)
on_chain("spring_scarftail_hairc", 5, s_h * 2.2, sw * (1 - side))
on_chain("spring_scarftail_hairr", 6, s_h * 2.2, sw * side * (x > 0))
on_chain("spring_scarftail_hairl", 6, s_h * 2.2, sw * side * (x < 0))
hc = hair & (y < -0.05)
hs = hair & (y >= -0.05) & (x > 0)


def line(m, count):
    """Where a chain starts on the fitted hair: the mean of a mask's rungs, from the root down (right side; left mirrors)."""
    zs = np.linspace(HAIR_TOP - 0.02, z[m].min() + 0.02, count)
    return [Q[m & (np.abs(z - zz) < 0.03)].mean(0).tolist() for zz in zs]


# the hands: fingers past the knuckles, the thumb by its segment
thumb_d = np.stack([ax_ - THUMB[0][0], z - THUMB[0][1]], 1)
du = np.array([THUMB[1][0] - THUMB[0][0], THUMB[1][1] - THUMB[0][1]])
h_t = np.clip(thumb_d @ du / (du @ du), 0, 1)
thumb = (np.linalg.norm(thumb_d - h_t[:, None] * du, axis=1) < 0.032) & (y > 0.045) & (ax_ > 0.36)
for sd, sel in (("R", x > 0), ("L", x < 0)):
    hw = GROUP["hand." + sd]
    fng = hw * sel * (z < KNUCKLE_Z + 0.012) * ~thumb
    GROUP["fingers." + sd] = fng * smooth(KNUCKLE_Z + 0.012, KNUCKLE_Z - 0.012, z)
    GROUP["thumb." + sd] = hw * sel * thumb * smooth(0.0, 0.2, h_t)
    GROUP["hand." + sd] = hw - GROUP["fingers." + sd] - GROUP["thumb." + sd]


knk = Q[(x > 0.36) & (np.abs(z - KNUCKLE_Z) < 0.006) & ~thumb].mean(0).tolist()
fgt = Q[(x > 0.36) & (z < 0.875) & ~thumb].mean(0).tolist()
META = {"hairc": line(hc, 3), "hairr": line(hs, 3), "knuckle": knk, "fingertip": fgt, "thumb": [Q[thumb & (x > 0) & (h_t < 0.25)].mean(0).tolist(), Q[thumb & (x > 0) & (h_t > 0.8)].mean(0).tolist()], "head_top": float(T["crown"][2])}
print("meta", json.dumps({k_: np.round(v, 3).tolist() for k_, v in META.items()}))

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
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0006)
bm.to_mesh(low.data)
bm.free()
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
ARMPIT_Z = 1.0
HN = T["neck"]
HANDS = [T["wrist." + s] + np.array([0, 0, -0.09]) for s in "RL"]


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
    return (np.abs(c[:, 0]) < 0.105) & (c[:, 1] > 0.0) & (c[:, 2] > HN[2]) & (c[:, 2] < HN[2] + 0.24)


def is_hand(i):
    return lambda c: np.linalg.norm(c - HANDS[i], axis=1) < 0.12


def is_horn(c):
    return c[:, 2] > HN[2] + 0.275


decimate(is_face, FACE_TRIS)
decimate(is_hand(0), HAND_TRIS)
decimate(is_hand(1), HAND_TRIS)
decimate(is_horn, HORN_TRIS)
decimate(lambda c: ~is_face(c) & ~is_hand(0)(c) & ~is_hand(1)(c) & ~is_horn(c), LOW_TRIS - FACE_TRIS - 2 * HAND_TRIS - HORN_TRIS)


def part_arms():
    """The scan welded the forearm shards to the hip plates: drop the faces across that seam, close both sides."""
    arm = {g.index for g in low.vertex_groups if g.name.split(".")[0] in ("upper_arm", "forearm", "hand", "fingers", "thumb")}
    bm = bmesh.new()
    bm.from_mesh(low.data)
    dv = bm.verts.layers.deform.verify()
    below = [v for v in bm.verts if v.co.z < ARMPIT_Z]
    on_arm = {v: sum(w for g, w in v[dv].items() if g in arm) > 0.5 for v in below}
    for v in below:
        for g in [g for g in v[dv].keys() if (g in arm) != on_arm[v]]:
            if len(v[dv]) > 1:
                del v[dv][g]
    seam = [f for f in bm.faces if len({on_arm.get(v) for v in f.verts if v in on_arm}) > 1]
    rim = {e for f in seam for e in f.edges}
    bmesh.ops.delete(bm, geom=seam, context="FACES_ONLY")
    made = bmesh.ops.holes_fill(bm, edges=[e for e in rim if e.is_valid and e.is_boundary], sides=0)["faces"]
    bmesh.ops.triangulate(bm, faces=made)
    bm.to_mesh(low.data)
    bm.free()
    print("tris: arm seam", len(seam), "faces cut,", len(made), "closed")


part_arms()
print("Low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bpy.context.scene["cinder"] = json.dumps(META)
bpy.ops.wm.save_as_mainfile(filepath=OUT)

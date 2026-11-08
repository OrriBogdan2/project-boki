"""ART-1 Sparkle, stage A: the Meshy scan of the owner's A-pose turnaround (pigtails, rods, harness, wires, chain edited out) -> the contract's rest pose.
Recipe: kael_source.py / claire_source.py. Her own: the skirt hangs from the pelvis, its hem following the thighs a little; heads cut at the jaw; hands rebuilt.
Run: blender -b --factory-startup --python tools/art1/ryzz_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 8900
FACE_TRIS = 2000
SOLE = -0.946
K_ = 0.90
ANKLE = 0.135
S_J = {"neck": (0, 0, 1.596), "pelvis": (0, 0, 0.99), "shoulder.R": (0.17, 0, 1.476), "elbow.R": (0.33, 0, 1.256), "wrist.R": (0.456, 0, 1.122),
       "hip.R": (0.09, 0, 0.95), "knee.R": (0.146, 0, 0.646), "ankle.R": (0.23, 0, 0.15), "sole.R": (0.25, 0, 0.0), "crown": (0, 0, 1.894)}
for k_ in list(S_J):
    if k_.endswith(".R"):
        x, y, z = S_J[k_]
        S_J[k_[:-1] + "L"] = (-x, y, z)
rig = json.load(open(RIG))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
T["crown"] = T["neck"] + np.array([0, 0, (1.894 - 1.596) * 0.95])     # the head a touch big for the match camera
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, ANKLE])
    T["sole." + sd] = np.array([T["knee." + sd][0], 0, 0.0])
SEG = [("torso", "pelvis", "neck", 0.15, 0.96), ("head", "neck", "crown", 0.14, 0.95)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.055, 0.9), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.042, 0.9),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.09, 0.92), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.06, 0.92),
            ("foot." + sd, "ankle." + sd, "sole." + sd, 0.05, 0.92)]

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
P = np.stack([-co[:, 0], -co[:, 1], co[:, 2] - SOLE], 1)
print("scan", n, P.min(0).round(3), P.max(0).round(3))

# ---- the skirt: everything round the thighs that isn't the thigh, down to the hem
def seg_d(p, a0, a1):
    a0, a1 = np.array(a0, float), np.array(a1, float)
    u = a1 - a0
    h = np.clip(((p - a0) @ u) / (u @ u), 0, 1)
    return np.linalg.norm(p - (a0 + h[:, None] * u), axis=1)


rt = np.minimum(seg_d(P, S_J["hip.R"], S_J["knee.R"]), seg_d(P, S_J["hip.L"], S_J["knee.L"]))
sk = smooth(0.088, 0.104, rt) * smooth(0.82, 0.86, P[:, 2]) * smooth(1.2, 1.1, P[:, 2]) * (np.abs(P[:, 0]) < 0.34)
for s_ in (1.0, -1.0):
    sk *= smooth(0.075, 0.1, seg_d(P, S_J["elbow.R"] if s_ > 0 else S_J["elbow.L"], S_J["wrist.R"] if s_ > 0 else S_J["wrist.L"]))
    sk *= smooth(0.07, 0.09, seg_d(P, S_J["wrist.R"] if s_ > 0 else S_J["wrist.L"], (s_ * 0.6, 0, 0.98)))

# ... and by paint: the pleat valleys dip to the thigh, so distance alone gives them to the leg and they tear. The skirt is dark, the fishnets are not.
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import imgio, subprocess
_t = OUT + "_col.png"
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(os.path.dirname(SCAN), "tex0_base_color.png"), "-vf", "scale=1024:1024", _t], check=True)
_c = imgio.load(_t)[::-1].mean(2)
os.remove(_t)
_uv = np.zeros(len(me.loops) * 2)
me.uv_layers.active.data.foreach_get("uv", _uv)
_uv = _uv.reshape(-1, 2)
_vi = np.zeros(len(me.loops), np.int64)
me.loops.foreach_get("vertex_index", _vi)
_L = np.ones(n)
_L[_vi] = _c[np.clip((_uv[:, 1] % 1 * 1024).astype(int), 0, 1023), np.clip((_uv[:, 0] % 1 * 1024).astype(int), 0, 1023)]
dark = (_L < 0.24) & (P[:, 2] > 0.862) & (P[:, 2] < 1.02) & (rt < 0.16)      # (only beside the thighs: the valleys, nothing of the torso)
print("skirt by distance", int((sk > 0.5).sum()), "by paint adds", int((dark & (sk <= 0.5)).sum()))
sk = np.maximum(sk, dark * 1.0)
names = [s[0] for s in SEG]
D = np.zeros((n, len(SEG)))
z, x = P[:, 2].copy(), P[:, 0]
is_head = z > 1.60
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
        D[z < 0.12, i] = 9.0
    if nm.startswith("foot"):
        D[z > 0.2, i] = 9.0
    if nm.startswith(("upper_arm", "forearm")):
        D[(z < 0.98) & (np.abs(x) < 0.3), i] = 9.0
        D[sk > 0.5, i] = 9.0
    elif np.abs(a0[0]) < 0.3 and nm != "torso" or nm == "torso":
        D[(np.abs(x) > 0.36), i] = 9.0
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
    rad_v = (r - ax[:, None] * u) * girth
    Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + rad_v @ R.T)
print("fitted", Q.min(0).round(3), Q.max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()

GROUP = {}
for i, nm in enumerate(names):
    if nm != "torso":
        GROUP[nm] = W[:, i].copy()
tw = W[:, 0]
k = smooth(1.12, 1.24, P[:, 2])                # the waist: pelvis on the root, chest on the hips (scan heights)
GROUP["root"], GROUP["hips"] = tw * (1 - k), tw * k
# the skirt hangs from the pelvis: its lower half on the skirt bone, the hem drawn a little after each thigh
hem = sk * smooth(1.06, 0.90, P[:, 2]) * tw
GROUP["skirt"] = hem * 0.55
GROUP["root"] = GROUP["root"] - hem * 0.55
for sd, sg in (("R", 1.0), ("L", -1.0)):
    q = hem * smooth(-0.02, 0.05, sg * P[:, 0]) * 0.3
    GROUP["thigh." + sd] = GROUP["thigh." + sd] + q
    GROUP["root"] = GROUP["root"] - q
GROUP["root"] = np.maximum(GROUP["root"], 0.0)
for sd in "RL":
    jw, je = np.array(S_J["wrist." + sd], float), np.array(S_J["elbow." + sd], float)
    u = jw - je
    h = ((P - je) @ u) / (u @ u)
    hand = smooth(1.03, 1.08, h) * GROUP["forearm." + sd]
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
hand_w = GROUP["hand.R"] + GROUP["hand.L"]
bm = bmesh.new()
bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
arm_w = sum(GROUP[b_] for b_ in ("forearm.R", "forearm.L", "hand.R", "hand.L"))
wrist_z = T["wrist.R"][2] + 0.004


def past_wrist(f):
    """The rebuilt hands start here: anything of the arm below the wrist goes, the scan's thumb and cuff stubs too (they'd stick out of the new hand)."""
    return max(hand_w[v.index] for v in f.verts) > 0.5 or (max(arm_w[v.index] for v in f.verts) > 0.3 and f.calc_center_median().z < wrist_z)


all_arm = arm_w + GROUP["upper_arm.R"] + GROUP["upper_arm.L"]


# the thighs under the skirt go: drawn in from the A-pose they push through its pleat valleys, and they'd feed the skirt their paint
thigh_w = GROUP["thigh.R"] + GROUP["thigh.L"]
under = (thigh_w > 0.5) & (sk < 0.5) & (P[:, 2] > 0.885) & (rt < 0.12)


def hidden_thigh(f):
    return all(under[v.index] for v in f.verts)




def bridge(f):
    """A face from the arm to the body (the scan's sleeve or cuff touches the hip at rest): it stretches as a blade whenever the arm moves."""
    w_ = [all_arm[v.index] for v in f.verts]
    return max(w_) > 0.5 and min(w_) < 0.08 and f.calc_center_median().z < 1.08


kill = [f for f in bm.faces if past_wrist(f) or hidden_thigh(f) or bridge(f)]
print("under the skirt", int(under.sum()), "verts;", len(kill), "faces cut")
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
# (welded per side of the arm: at rest the forearms touch the skirt, and one weld across would stretch hip to hand in every raised-arm pose)
bm.verts.ensure_lookup_table()
on_arm = [v for v in bm.verts if all_arm[v.index] > 0.5]
off_arm = [v for v in bm.verts if all_arm[v.index] <= 0.5]
bmesh.ops.remove_doubles(bm, verts=on_arm, dist=0.0006)
bmesh.ops.remove_doubles(bm, verts=[v for v in off_arm if v.is_valid], dist=0.0006)
bm.to_mesh(low.data)
bm.free()
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
HN = T["neck"]


def decimate(pick, target):
    """Edit-mode decimate of the faces pick() marks: the selection's border stays, so the two regions keep meeting (claire_source)."""
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
    return (np.abs(c[:, 0]) < 0.1) & (c[:, 1] > 0.02) & (c[:, 2] > HN[2] + 0.03) & (c[:, 2] < HN[2] + 0.24)


decimate(is_face, FACE_TRIS)
decimate(lambda c: ~is_face(c), LOW_TRIS - FACE_TRIS)
print("Low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bs = bmesh.new()
bs.from_mesh(src.data)
bmesh.ops.delete(bs, geom=[f for f in bs.faces if all(under[v.index] for v in f.verts)], context="FACES_ONLY")
bs.to_mesh(src.data)
bs.free()
bpy.ops.wm.save_as_mainfile(filepath=OUT)

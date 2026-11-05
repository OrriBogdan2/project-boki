"""ART-1 Claire, stage A: the Meshy scan of the owner's A-pose turnaround (horns, ears, wings, tail, bow and blades edited out, the neckline closed) ->
the contract's rest pose. Recipe: kael_source.py (soft weights by distance to the bones, then each bone moves its vertices onto the rig).
Her own: the head and hood are the scan's sculpt, kept on the head bone with the density on the face; the capelet hangs off the torso, not the arms;
the skirt is lengthened to mid-thigh over the stocking tops and hangs from the pelvis, its hem following the thighs a little; the boots stand on the blades.
Run: blender -b --factory-startup --python tools/art1/claire_source.py -- <scan.glb> <rig.json> <out.blend>"""
import sys, os, json
import bpy, bmesh
import numpy as np
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, OUT = a[0], a[1], a[2]
LOW_TRIS = 11850
SOLE = -0.95                    # the scan's sole (z)
K_ = 0.92                       # scan metres -> rig metres, where a bone's length doesn't set it
SOLE_Z, ANKLE = 0.052, 0.19     # the rig: the boot's sole on the blade, the foot bone
S_J = {"neck": (0, 0, 1.50), "pelvis": (0, 0, 0.90), "shoulder.R": (0.125, 0, 1.38), "elbow.R": (0.244, 0, 1.206), "wrist.R": (0.364, 0, 1.056),
       "shoulder.L": (-0.125, 0, 1.38), "elbow.L": (-0.244, 0, 1.206), "wrist.L": (-0.364, 0, 1.056), "hip.R": (0.10, 0, 0.86), "knee.R": (0.09, 0, 0.51),
       "ankle.R": (0.085, 0, 0.15), "sole.R": (0.085, 0, 0.0), "hip.L": (-0.10, 0, 0.86), "knee.L": (-0.09, 0, 0.51), "ankle.L": (-0.085, 0, 0.15),
       "sole.L": (-0.085, 0, 0.0), "crown": (0, 0, 1.92)}
rig = json.load(open(RIG))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
T["crown"] = T["neck"] + np.array([0, 0, (1.92 - 1.50) * K_])
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, ANKLE])
    T["sole." + sd] = np.array([T["knee." + sd][0], 0, SOLE_Z])
# name, scan joints, reach radius, girth
SEG = [("torso", "pelvis", "neck", 0.17, 0.97), ("head", "neck", "crown", 0.16, 1.0)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.05, 0.92), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.042, 0.92),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.09, 0.93), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.06, 0.93),
            ("foot." + sd, "ankle." + sd, "sole." + sd, 0.05, 0.93)]

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

# ---- a grown woman's face: a little longer below the eyes, a slimmer jaw (the sheet's face is a touch round for her)
EYE_Z = 1.69
fm = (P[:, 2] > 1.5) & (P[:, 2] < EYE_Z) & (P[:, 1] > 0.0) & (np.abs(P[:, 0]) < 0.115)
fk = smooth(0.115, 0.085, np.abs(P[:, 0])) * smooth(0.0, 0.05, P[:, 1]) * fm
low = smooth(EYE_Z, 1.60, P[:, 2]) * fk
P[:, 2] -= low * (EYE_Z - P[:, 2]) * 0.09
P[:, 0] *= 1 - 0.06 * low

# ---- the skirt: everything round the thighs that isn't the thigh, down to the hem; lengthened over the stocking tops to mid-thigh
rt = np.minimum(np.hypot(P[:, 0] - 0.097, P[:, 1]), np.hypot(P[:, 0] + 0.097, P[:, 1]))
sk = smooth(0.082, 0.102, rt) * smooth(0.76, 0.80, P[:, 2]) * smooth(1.16, 1.12, P[:, 2]) * (np.abs(P[:, 0]) < 0.36)
for s_ in (1.0, -1.0):
    e_, w_ = np.array([s_ * 0.244, 0, 1.206]), np.array([s_ * 0.40, 0, 1.02])
    u_ = w_ - e_
    h_ = np.clip(((P - e_) @ u_) / (u_ @ u_), 0, 1)
    sk *= 1 - smooth(0.115, 0.095, np.linalg.norm(P - (e_ + h_[:, None] * u_), axis=1)) * ((P[:, 2] > 0.985) | (np.abs(P[:, 0]) > 0.345))      # (the cuff and glove, not the hem beside them)
ZT = 1.10
stretch = sk * smooth(ZT, ZT - 0.08, P[:, 2])
Z0 = P[:, 2].copy()
P[:, 2] = ZT - (ZT - P[:, 2]) * (1 + 0.34 * stretch)
print("hem z", round(float(P[sk > 0.5, 2].min()), 3))

# ---- soft weights by distance to the segments
names = [s[0] for s in SEG]
D = np.zeros((n, len(SEG)))
z, x = Z0, P[:, 0]
head_th = np.clip(1.50 + 0.6 * P[:, 1], 1.46, 1.56)
is_head = Z0 > head_th
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    u = a1 - a0
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    q = P - (a0 + h[:, None] * u)
    d = np.linalg.norm(q * [0.8, 1.05, 1.0], axis=1) if nm == "torso" else np.linalg.norm(q, axis=1)
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
        D[z > 1.13, i] = 9.0
        D[sk > 0.5, i] = 9.0
    if nm.startswith("shin"):
        D[z < 0.13, i] = 9.0
    if nm.startswith("foot"):
        D[z > 0.17, i] = 9.0
    if nm.startswith(("upper_arm", "forearm")):
        D[z < 0.85, i] = 9.0
        D[sk > 0.5, i] = 9.0
        if nm.startswith("upper"):
            D[(z > 1.3) & (d > 0.06), i] = 9.0         # the capelet stays on the torso
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
# the skirt's bell either side of the pit the scan left where the hand stood by the hem: claire_pieces covers the pit with a panel at this radius
az_ = np.arctan2(np.abs(Q[:, 1]), np.abs(Q[:, 0]))
rq_ = np.hypot(Q[:, 0], Q[:, 1])
arm_ = sum(W[:, i] for i, sg_ in enumerate(SEG) if sg_[0].startswith(("upper_arm", "forearm")))
bell = []
for zc_ in np.arange(0.80, 1.05, 0.02):
    near_ = (np.abs(Q[:, 2] - zc_) < 0.012) & (sk > 0.3) & (arm_ < 0.3) & (az_ > 0.55) & (az_ < 0.85)
    bell.append((round(float(zc_), 3), round(float(np.percentile(rq_[near_], 70)), 4) if near_.sum() > 8 else 0.0))
print("BELL", bell)
src["bell"] = json.dumps(bell)
print("fitted", Q.min(0).round(3), Q.max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()

# ---- contract weights
GROUP = {}
for i, nm in enumerate(names):
    if nm != "torso":
        GROUP[nm] = W[:, i].copy()
tw = W[:, 0]
kz = smooth(1.08, 1.24, Z0)                     # the waist: pelvis on the root, chest on the hips
GROUP["root"], GROUP["hips"] = tw * (1 - kz), tw * kz
for sd, sg in (("R", 1.0), ("L", -1.0)):
    jw = np.array(S_J["wrist." + sd], float)
    je = np.array(S_J["elbow." + sd], float)
    u = jw - je
    h = ((P - je) @ u) / (u @ u)
    hand = smooth(1.04, 1.1, h) * GROUP["forearm." + sd]
    GROUP["hand." + sd] = hand
    GROUP["forearm." + sd] = GROUP["forearm." + sd] - hand
    # the capelet's edge lifts a little with the arm
    cape = 0.32 * smooth(0.13, 0.25, sg * x) * smooth(1.26, 1.32, Z0) * smooth(1.52, 1.44, Z0) * GROUP["hips"]
    GROUP["hips"] = GROUP["hips"] - cape
    GROUP["upper_arm." + sd] = GROUP["upper_arm." + sd] + cape
# the skirt hangs from the pelvis; the skirt bone sways the hem, which follows the thighs a little
hf = smooth(1.0, 0.84, Z0) * sk
skb = 0.45 * hf
GROUP["skirt"] = skb * GROUP["root"]
for sd, sg in (("R", 1.0), ("L", -1.0)):
    th = 0.34 * hf * smooth(-0.02, 0.1, sg * x) * GROUP["root"]
    GROUP["thigh." + sd] = GROUP["thigh." + sd] + th
    GROUP["root"] = GROUP["root"] - th
GROUP["root"] = GROUP["root"] - GROUP["skirt"]
for b, w in GROUP.items():
    g = src.vertex_groups.get(b) or src.vertex_groups.new(name=b)
    ids = np.nonzero(w > 0.01)[0]
    for vi, wv in zip(ids.tolist(), w[ids].tolist()):
        g.add([vi], wv, "REPLACE")
# (what the paint needs later: which scan vertices were the bare thigh above the stocking tops)
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
# (the scan welds a cuff to the hem beside it here and there: those faces would stretch from the hand to the skirt)
arm_w = sum(GROUP[b + sd_] for b in ("upper_arm.", "forearm.", "hand.") for sd_ in ("R", "L"))
kill = [f for f in bm.faces if max(hand_w[v.index] for v in f.verts) > 0.5 or (
    Z0[f.verts[0].index] < 1.12 and abs(x[f.verts[0].index]) > 0.16 and max(arm_w[v.index] for v in f.verts) - min(arm_w[v.index] for v in f.verts) > 0.35)]
print("cut faces", len(kill))
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
bm.verts.index_update()
# (bits the cut left floating, cuff scraps that would ride the arm through the skirt)
seen_, comps_ = set(), []
for v0_ in bm.verts:
    if v0_.index in seen_:
        continue
    st_, cp_ = [v0_], []
    seen_.add(v0_.index)
    while st_:
        q_ = st_.pop()
        cp_.append(q_)
        for e_ in q_.link_edges:
            o_ = e_.other_vert(q_)
            if o_.index not in seen_:
                seen_.add(o_.index)
                st_.append(o_)
    comps_.append(cp_)
comps_.sort(key=len, reverse=True)
print("islands", [len(c) for c in comps_[:8]], len(comps_))
bmesh.ops.delete(bm, geom=[v for c in comps_[1:] for v in c], context="VERTS")
filled = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=2000)
print("holes filled", len(filled["faces"]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(low.data)
bm.free()
# the density goes to the face: a vertex group the Decimate spares
HN = T["neck"]
lv = np.zeros(len(low.data.vertices) * 3)
low.data.vertices.foreach_get("co", lv)
lv = lv.reshape(-1, 3)
FACE_TRIS = 2900
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low


def decimate(pick, target):
    """Edit-mode decimate of the faces pick() marks: the selection's border stays, so the two regions keep meeting."""
    bpy.ops.object.mode_set(mode="OBJECT")
    co = np.zeros(len(low.data.vertices) * 3)
    low.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    sel = pick(np.array([co[list(p.vertices)].mean(0) for p in low.data.polygons]))
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
    return (np.abs(c[:, 0]) < 0.092) & (c[:, 1] > 0.035) & (c[:, 2] > HN[2] + 0.085) & (c[:, 2] < HN[2] + 0.31)


decimate(is_face, FACE_TRIS)
decimate(lambda c: ~is_face(c), LOW_TRIS - FACE_TRIS)
lv = np.zeros(len(low.data.vertices) * 3)
low.data.vertices.foreach_get("co", lv)
lv = lv.reshape(-1, 3)
fc = np.array([lv[list(p.vertices)].mean(0) for p in low.data.polygons])
inface = is_face(fc)
print("Low tris", len(fc), "on the face", int(inface.sum()))
bpy.ops.wm.save_as_mainfile(filepath=OUT)

"""Pip (ART-1 + item 76b): the sculpt to a game mesh on the contract armature with a painted atlas, saved as a .blend for
tools/art1/pip_clips.py, which keys the clips and exports the .glb:
  blender -b --factory-startup --python tools/art1/pip_art1.py -- WORKDIR [--shape]
Shapes pip_sculpt.py, paint pip_paint.py. Budget 15k triangles, the lantern included (S1's item 94 number). The lantern is skinned in the
.glb on a hanging spring chain under hand.R; FX points are empties."""
import math
import os
import pickle
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import hem_sdf as S
import meshkit as M
from meshkit import Piece, smooth
import pip_sculpt as K
import warden_kit as WK

a_ = sys.argv[sys.argv.index("--") + 1:]
WORK = a_[0]
SHAPE = "--shape" in a_
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
os.makedirs(WORK, exist_ok=True)
F = np.float32


def ob_from(name, v, q):
    me = bpy.data.meshes.new(name)
    me.from_pydata(np.asarray(v, dtype=np.float64).tolist(), [], [list(map(int, f)) for f in q])
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def read(ob):
    """(verts, faces) of an object with its modifiers applied."""
    dg = bpy.context.evaluated_depsgraph_get()
    e = ob.evaluated_get(dg)
    me = e.to_mesh()
    v = np.zeros((len(me.vertices), 3))
    me.vertices.foreach_get("co", v.ravel())
    f = [list(p.vertices) for p in me.polygons]
    e.to_mesh_clear()
    return v, f


def lowpoly(name, fld, tris, protect=None):
    """Field -> a smooth decimated closed mesh, back on the iso surface."""
    v, q = S.surface_nets(fld)
    ob = ob_from(name, v, q)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    m0 = ob.modifiers.new("s", "SMOOTH")
    m0.factor, m0.iterations = 0.6, 4
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="s")
    n0 = len(ob.data.polygons) * 2
    d = ob.modifiers.new("d", "DECIMATE")
    d.decimate_type = "COLLAPSE"
    if protect is not None:
        vv = np.zeros((len(ob.data.vertices), 3))
        ob.data.vertices.foreach_get("co", vv.ravel())
        g = ob.vertex_groups.new(name="keep")
        w = protect(vv)
        for i in range(len(vv)):
            g.add([i], float(w[i]), "REPLACE")
        d.vertex_group = "keep"
        d.vertex_group_factor = 10.0
    d.ratio = min(1.0, tris / n0)
    v, f = read(ob)
    bpy.data.objects.remove(ob)
    vf = fld.project(v.astype(F), it=2).astype(np.float64)
    print(name, "tris", sum(len(x) - 2 for x in f), "from", n0)
    return Piece(name, "skin", vf, f)


def seg_chain(v, chain, blend):
    """Weights along a limb: chain [(bone, a, b)]; blends across each joint by `blend` metres."""
    pts = [np.asarray(c[1], dtype=np.float64) for c in chain] + [np.asarray(chain[-1][2], dtype=np.float64)]
    L = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(chain))]
    best, tv = np.full(len(v), 1e9), np.zeros(len(v))
    off = 0.0
    for i, (bn, a, b) in enumerate(chain):
        ab = pts[i + 1] - pts[i]
        t = np.clip((v - pts[i]) @ ab / (ab @ ab), 0, 1)
        d = np.linalg.norm(v - (pts[i] + np.outer(t, ab)), axis=1)
        m = d < best
        best[m] = d[m]
        tv[m] = off + t[m] * L[i]
        off += L[i]
    w = {c[0]: np.zeros(len(v)) for c in chain}
    off = 0.0
    for i, (bn, a, b) in enumerate(chain):
        lo = 0.0 if i == 0 else smooth(off - blend, off + blend, tv)
        end = off + L[i]
        hi = 1.0 if i == len(chain) - 1 else 1.0 - smooth(end - blend, end + blend, tv)
        w[bn] = np.clip((lo if i else 1.0) * hi, 0, 1) if i else np.clip(hi, 0, 1)
        off = end
    return w


def norm_w(p):
    tot = sum(p.w.values())
    tot = np.where(tot > 1e-6, tot, 1.0)
    p.w = {b: x / tot for b, x in p.w.items() if np.max(x) > 0.005}
    return p


# ------------------------------------------------------------------ build
t0 = __import__("time").time()
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)
J = K.J
body_f = K.body_field()
armR_f, armL_f = K.arm_field("R"), K.arm_field("L")
head_f = K.head_field()
print("fields", __import__("time").time() - t0)
body = lowpoly("body", body_f, 2300, protect=lambda v: smooth(0.14, 0.05, v[:, 2]) * 0.8 + 0.2)
armR = lowpoly("armR", armR_f, 640, protect=lambda v: smooth(K.WRIST_Z + 0.02, K.WRIST_Z - 0.03, v[:, 2]) * 0.8 + 0.2)
armL = lowpoly("armL", armL_f, 640, protect=lambda v: smooth(K.WRIST_Z + 0.02, K.WRIST_Z - 0.03, v[:, 2]) * 0.8 + 0.2)


def face_protect(v):
    q = v - K.HC
    r = np.linalg.norm((q - (0, 0.17, -0.05)) / (0.16, 0.13, 0.11), axis=1)
    e = np.minimum(np.linalg.norm(q - K.EYE, axis=1), np.linalg.norm(q - K.EYE * (-1, 1, 1), axis=1))
    return np.clip(0.12 + 0.88 * np.maximum(smooth(1.15, 0.7, r), smooth(0.12, 0.07, e)), 0, 1)


head = lowpoly("head", head_f, 2600, protect=face_protect)

pieces = [body, armR, armL, head]
earR, earL = K.ear(1.0), K.ear(-1.0)
pieces += [earR, earL, K.bandage(earL)]
for s in (1.0, -1.0):
    pieces += [K.eyeball(s), K.lid(s), K.brow(s, head_f)]
pieces.append(K.nose())
pieces.append(K.band(head_f))
pieces += K.goggles()
pieces += K.flower("flowerR", "cloth", K.h((0.163, 0.062, 0.102)), (0.55, 0.75, 0.32), 0.052, rot=0.3, w=0.8)
pieces += K.flower("flowerL", "cloth", K.h((-0.163, 0.062, 0.102)), (-0.55, 0.75, 0.32), 0.052, rot=1.1, w=0.8)
tail = K.tail()
pieces.append(tail)
cape = K.cape(body_f, [armR_f, armL_f])
pieces += cape
pieces += K.flower("cflower", "cloth", (0.0, 0.17, 1.045), (0, 0.92, 0.38), 0.105, rot=1.57, w=0.62, n=4)
apron = K.apron(body_f)
pieces.append(apron)
pieces.append(K.strap(body_f))
pouch = K.pouch()
pieces += pouch
lant = K.lantern()
pieces += lant
wings = [K.wing(1.0, True), K.wing(-1.0, True), K.wing(1.0, False), K.wing(-1.0, False)]
pieces += wings

# ------------------------------------------------------------------ weights
BODY_BONES = ["root", "hips", "thigh.R", "thigh.L", "shin.R", "shin.L", "foot.R", "foot.L"]
v = body.v
top = smooth(0.40, 0.60, v[:, 2])
ww = {"hips": top}
for sd, sx in (("R", 1.0), ("L", -1.0)):
    th, sh = J["thigh." + sd], J["shin." + sd]
    an = np.array((sx * 0.118, -0.012, K.ANKLE_Z))
    leg = seg_chain(v, [("thigh." + sd, th + (0, 0, 0.03), sh), ("shin." + sd, sh, an), ("foot." + sd, an, an + (0, 0.12, -0.05))], 0.03)
    mask = (1 - top) * smooth(0.0, 0.05, v[:, 0] * sx) * smooth(0.50, 0.38, v[:, 2]) ** 0.7
    for b, x in leg.items():
        ww[b] = x * mask
ww["root"] = np.clip(1 - sum(ww.values()), 0, 1)
body.w = ww
norm_w(body)
for sd, p, sx in (("R", armR, 1.0), ("L", armL, -1.0)):
    su, el, wr = J["upper_arm." + sd], J["forearm." + sd], J["hand." + sd]
    tip = wr + (0, 0, -0.2)
    arm = seg_chain(p.v, [("upper_arm." + sd, su + (0, 0, 0.1), el), ("forearm." + sd, el, wr), ("hand." + sd, wr, tip)], 0.03)
    # (the arm's root stays with the chest until the shoulder's joint)
    if sd == "L":
        kn = K.WRIST_Z - 0.04 - 0.035
        fing = arm["hand.L"] * smooth(kn + 0.012, kn - 0.012, p.v[:, 2]) * (1 - smooth(0.01, 0.02, sx * (p.v[:, 0] - sx * K.SH) - 0.004 + 0.03 - 0.02 * 0))
        # the thumb: on the inside, toward the front
        thm = arm["hand.L"] * smooth(0.02, 0.035, p.v[:, 1]) * smooth(K.SH - 0.012, K.SH + 0.012, np.abs(p.v[:, 0]) * -1 + 2 * K.SH)
        thm = np.minimum(thm, smooth(K.WRIST_Z - 0.03, K.WRIST_Z - 0.06, p.v[:, 2]))
        fing = fing * (1 - thm)
        arm["fingers.L"] = fing
        arm["thumb.L"] = thm
        arm["hand.L"] = np.clip(arm["hand.L"] - fing - thm, 0, 1)
    p.w = arm
    norm_w(p)
JAW = K.jaw_weight(head.v)
head.w = {"jaw": JAW, "head": 1 - JAW}
for p_, sd in ((earR, "R"), (earL, "L")):
    q = (p_.v - p_.c0) @ p_.ax / p_.L
    w = smooth(0.10, 0.24, q)
    p_.w = {"ear." + sd: w, "head": 1 - w}
ban = next(p for p in pieces if p.name == "bandage")
ban.w = {"ear.L": np.ones(len(ban.v))}


def rigid(names, bone):
    for p in pieces:
        if p.name.startswith(names):
            p.w = {bone: np.ones(len(p.v))}


rigid(("eyeR", "eyeL", "nose", "band", "gog", "lens", "flowerR", "flowerL"), "head")
rigid(("lidR",), "lid.R")
rigid(("lidL",), "lid.L")
rigid(("browR",), "brow.R")
rigid(("browL",), "brow.L")
rigid(("cflower",), "hips")
rigid(("strap",), "hips")
rigid(("pouch", "flap", "buckle", "vial", "scroll"), "root")
for p in pieces:
    if p.name == "strap":
        lo = smooth(0.66, 0.84, p.v[:, 2])
        p.w = {"hips": lo, "root": 1 - lo}
rigid(("lring", "lneck", "lroof", "lbody", "lfoot", "lpost", "lpane"), "spring_hanglantern_0")
HANG_PTS = [tuple(K.GRIP), tuple(K.GRIP + (0, 0, -0.24)), tuple(K.GRIP + (0, 0, -0.47))]

# the tail on its chain
tn = ["spring_tail_%d" % i for i in range(K.TAIL_N)]
idx = np.linspace(0.08, 0.98, K.TAIL_N)
sl = np.linspace(0, 1, len(tail.path))
TAIL_PTS = [tuple(np.interp(t_, sl, tail.path[:, i]) for i in range(3)) for t_ in idx]
wt = {n: np.zeros(len(tail.v)) for n in tn}
wt["tail"] = np.zeros(len(tail.v))
for i, t_ in enumerate(tail.t):
    x = np.clip((t_ - 0.08) / 0.90, -0.2, 0.9999) * (K.TAIL_N - 1)
    if x < 0:
        k = -x / 0.72
        wt["tail"][i] = min(k, 1.0)
        wt[tn[0]][i] = 1 - min(k, 1.0)
        continue
    b = int(x)
    q = x - b
    wt[tn[b]][i] += 1 - q
    wt[tn[min(b + 1, K.TAIL_N - 2)]][i] += q
wt.pop(tn[-1])
tail.w = wt

# the mantle: on the chest; the side leaves go with the arm; the long back ones hang on their own chain
CAPE_PTS = [(0.0, -0.20, 1.02), (0.0, -0.27, 0.86), (0.0, -0.30, 0.72), (0.0, -0.31, 0.58)]
cn = ["spring_capeback_%d" % i for i in range(4)]
for p in cape:
    th = p.th
    side = abs(((th + 180) % 360) - 180)
    wh = np.ones(len(p.v))
    p.w = {"hips": wh}
    if 55 <= side <= 128:
        sd = "L" if th < 180 else "R"
        k = 0.5 * smooth(0.1, 0.5, p.u) * (1 - abs(side - 90) / 50)
        p.w = {"hips": 1 - k, "upper_arm." + sd: k}
    if side >= 140 and not p.name.startswith("collar"):
        d = np.clip((1.02 - p.v[:, 2]) / 0.44, 0, 0.999) * 3
        wk = {n: np.zeros(len(p.v)) for n in cn[:3]}
        for i, x in enumerate(d):
            b = int(x)
            q = x - b
            wk[cn[b]][i] += 1 - q
            wk[cn[min(b + 1, 2)]][i] += q
        lock = smooth(1.10, 0.98, p.v[:, 2])
        p.w = {n: x * lock for n, x in wk.items()}
        p.w["hips"] = 1 - lock
y_ = smooth(0.78, 0.56, apron.v[:, 2])
apron.w = {"hips": 1 - y_, "apron": y_}

for p in wings:
    sd = p.name[-1]
    if p.name.startswith("wingU"):
        ch = ["spring_wing%s_%d" % (sd, i) for i in range(3)]
        u = p.u
        p.w = {"wing." + sd: 1 - smooth(0.2, 0.55, u), ch[0]: smooth(0.2, 0.55, u) * (1 - smooth(0.55, 0.9, u)), ch[1]: smooth(0.55, 0.9, u)}
    else:
        p.w = {"wing." + sd: np.ones(len(p.v))}
for p in pieces:
    if not p.w:
        print("NO WEIGHTS", p.name)
        p.w = {"hips": np.ones(len(p.v))}
    norm_w(p)
    if p.name.startswith(("wing", "lpane", "lens", "lidR", "lidL", "browR", "browL")):
        continue
    if p.name in ("body", "armR", "armL", "head"):
        continue
    p.orient()

n_t = sum(p.tris() for p in pieces)
by = {}
for p in pieces:
    k = p.name.rstrip("0123456789RL_pc")
    by[k] = by.get(k, 0) + p.tris()
print("TRIS", n_t, sorted(by.items(), key=lambda kv: -kv[1])[:24])
meta = {"HANG_PTS": HANG_PTS, "TAIL_PTS": TAIL_PTS, "CAPE_PTS": CAPE_PTS, "cn": cn, "tn": tn}
pickle.dump((pieces, meta), open(os.path.join(WORK, "pieces.pkl"), "wb"))

if SHAPE:
    COL = {"skin": (0.8, 0.35, 0.45), "cloth": (0.3, 0.5, 0.2), "leather": (0.3, 0.17, 0.08), "metal": (0.6, 0.4, 0.15), "glow": (1, 0.8, 0.3), "eyes": (0.1, 0.05, 0.02), "card": (1, 0.8, 0.85)}
    mats = {}
    for p in pieces:
        c = COL[p.mat]
        if p.name.startswith(("petal", "cflower", "flower")):
            c = (0.9, 0.5, 0.6)
        if p.name.startswith(("apron", "bandage", "scroll")):
            c = (0.9, 0.82, 0.65)
        k = str(c)
        if k not in mats:
            mt = bpy.data.materials.new(k)
            mt.use_nodes = True
            mt.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (*c, 1)
            if p.mat == "card":
                mt.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.45
                mt.blend_method = "BLEND"
            mats[k] = mt
        ob = ob_from("P_" + p.name, p.v, p.f)
        ob.data.materials.append(mats[k])
        ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "shape.blend"))
    sys.exit(0)

# ------------------------------------------------------------------ the atlas: Smart UV per piece at one texel density, packed; tiles to the right
import imgio
import pip_paint as P

ATLAS = 2048
UNIQ_W = 0.90
EYE_TILE = (0.905, 0.0, 1.0, 0.095)
GLOW_TILE = (0.905, 0.10, 1.0, 0.16)
DENS = {"head": 1.7, "lid": 1.2, "brow": 1.2, "eye": 1.0, "nose": 0.6, "apron": 1.25, "pouch": 1.2, "flap": 1.2, "cflower": 1.3, "petal": 1.1, "lpane": 1.3,
        "lroof": 1.2, "body": 0.8, "tail": 0.8, "armR": 1.0, "armL": 1.0, "strap": 0.5}


def dens(nm):
    for k, x in DENS.items():
        if nm.startswith(k):
            return x
    return 1.0


unique = [p for p in pieces if not p.name.startswith(("eye", "wing"))]
obs = []
for pid, p in enumerate(unique):
    ob = ob_from("U_%03d" % pid, p.v, p.f)
    ob.data.uv_layers.new(name="UVMap")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62 if p.name in ("body", "head", "armR", "armL", "tail") else 75), island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = ob.data
    uv = np.zeros(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    a3, a2 = 0.0, 0.0
    for poly in me.polygons:
        ids = list(poly.loop_indices)
        a3 += poly.area
        pts = uv[ids]
        a2 += 0.5 * abs(np.dot(pts[:, 0], np.roll(pts[:, 1], -1)) - np.dot(pts[:, 1], np.roll(pts[:, 0], -1)))
    uv *= math.sqrt(a3 / max(a2, 1e-9)) * dens(p.name)
    me.uv_layers[0].data.foreach_set("uv", uv.ravel())
    obs.append(ob)
bpy.ops.object.select_all(action="DESELECT")
for ob in obs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = obs[0]
pids = np.concatenate([np.full(len(ob.data.polygons), i, np.int32) for i, ob in enumerate(obs)])
bpy.ops.object.join()
joined = bpy.context.view_layer.objects.active
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.0035, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
me_j = joined.data
uvj = np.zeros(len(me_j.loops) * 2)
me_j.uv_layers[0].data.foreach_get("uv", uvj)
uvj = uvj.reshape(-1, 2) * (UNIQ_W, 1.0)  # (squeezed a little: tiles to the right; the paint comes from position, so it stays honest)
print("pack done", __import__("time").time() - t0)

# ------------------------------------------------------------------ the final mesh
MATN = {"skin": "skin-fur", "cloth": "cloth-pip", "leather": "leather-pip", "metal": "brass-pip", "eyes": "eyes-pip", "glow": "glow-pip", "card": "card-wing"}
ORDER = ["skin", "cloth", "leather", "metal", "eyes", "glow", "card"]
V, FV, FM, FP, FU, W, RO = [], [], [], [], [], [], []
base = 0
loop_i = 0
names = []
polys_j = list(me_j.polygons)
offs = 0
uq_idx = {id(p): i for i, p in enumerate(unique)}
start_face = {}
fi = 0
for i, ob_faces in enumerate(np.bincount(pids)):
    start_face[i] = fi
    fi += ob_faces
for pid_all, p in enumerate(pieces):
    names.append(p.name)
    V.append(p.v)
    W += [{b: float(x[i]) for b, x in p.w.items() if x[i] > 0.01} for i in range(len(p.v))]
    RO += [p.room] * len(p.v)
    tile = None
    if id(p) in uq_idx:
        f0 = start_face[uq_idx[id(p)]]
        for k, q in enumerate(p.f):
            FV.append([i + base for i in q])
            FM.append(ORDER.index(p.mat))
            FP.append(pid_all)
            poly = polys_j[f0 + k]
            FU.append([tuple(uvj[li]) for li in poly.loop_indices])
    else:
        for k, q in enumerate(p.f):
            FV.append([i + base for i in q])
            FM.append(ORDER.index(p.mat))
            FP.append(pid_all)
            u0, v0, u1, v1 = EYE_TILE if p.mat == "eyes" else (0, 0, 1, 1)
            FU.append([(u0 + (u1 - u0) * a, v0 + (v1 - v0) * b) for a, b in p.uv[k]])
    base += len(p.v)
bpy.data.objects.remove(joined)
V = np.vstack(V)
me = bpy.data.meshes.new("Pip")
me.from_pydata(V.tolist(), [], FV)
me.update()
ob = bpy.data.objects.new("Pip", me)
bpy.context.scene.collection.objects.link(ob)
assert len(me.polygons) == len(FV), (len(me.polygons), len(FV))
uvl = me.uv_layers.new(name="UVMap")
uvd = np.zeros(len(me.loops) * 2)
for poly in me.polygons:
    fuv = FU[poly.index]
    for k, li in enumerate(poly.loop_indices):
        uvd[li * 2:li * 2 + 2] = fuv[k]
uvl.data.foreach_set("uv", uvd)
me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
me.polygons.foreach_set("material_index", FM)
print("mesh", len(me.polygons), "polys", sum(len(f) - 2 for f in FV), "tris")

# ------------------------------------------------------------------ rasterise position, normal, piece
me.calc_loop_triangles()
vn = np.zeros((len(me.vertices), 3))
me.vertices.foreach_get("normal", vn.ravel())
tv, tuv, tp = [], [], []
for lt in me.loop_triangles:
    if FM[lt.polygon_index] == ORDER.index("card"):
        continue
    tv.append(lt.vertices[:])
    tuv.append([uvd[li * 2:li * 2 + 2] for li in lt.loops])
    tp.append(FP[lt.polygon_index])
tv, tuv = np.array(tv), np.array(tuv, F)
R = None
tp = np.array(tp)
for pid_all in np.unique(tp):
    m = tp == pid_all
    R = S.raster(tuv[m], V[tv[m]].astype(F), vn[tv[m]].astype(F), np.arange(m.sum()), ATLAS, part=int(pid_all), out=R)
POS, NOR, PID = R["p"], R["n"], R["id"]
NOR /= np.maximum(np.linalg.norm(NOR, axis=2, keepdims=True), 1e-6)
print("raster", __import__("time").time() - t0)

# ------------------------------------------------------------------ AO, baked by Cycles on the rest pose (the wings hidden)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
sc.render.threads_mode = "FIXED"
sc.render.threads = 10
aoi = bpy.data.images.new("ao", 1024, 1024, float_buffer=True)
for nm in ORDER:
    mt = bpy.data.materials.new(MATN[nm])
    mt.use_nodes = True
    me.materials.append(mt)
    n_ = mt.node_tree.nodes.new("ShaderNodeTexImage")
    n_.image = aoi
    n_.name = "bake"
    mt.node_tree.nodes.active = n_
wings_idx = [i for i, m_ in enumerate(FM) if m_ == ORDER.index("card")]
me.materials[ORDER.index("card")].node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.0
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
ob_h = ob.copy()
bmw = bmesh.new()
bmw.from_mesh(me)
bmesh.ops.delete(bmw, geom=[f for f in bmw.faces if FM[f.index] == ORDER.index("card")], context="FACES_ONLY")
me_b = bpy.data.meshes.new("baker")
bmw.to_mesh(me_b)
bmw.free()
for m__ in me.materials:
    me_b.materials.append(m__)
ob_h.data = me_b
sc.collection.objects.link(ob_h)
bpy.ops.object.select_all(action="DESELECT")
ob_h.select_set(True)
bpy.context.view_layer.objects.active = ob_h
sc.cycles.bake_type = "AO"
sc.world = bpy.data.worlds.new("w")
bpy.ops.object.bake(type="AO", margin=8)
ao = np.zeros((1024, 1024, 4), F)
aoi.pixels.foreach_get(ao.ravel())
ao = ao[..., 0]
bpy.data.objects.remove(ob_h)
AO = np.repeat(np.repeat(ao, 2, 0), 2, 1)
print("ao", __import__("time").time() - t0, ao.mean())

# ------------------------------------------------------------------ paint
OUTC = np.zeros((ATLAS, ATLAS, 3), F)
OUTE = np.zeros((ATLAS, ATLAS, 3), F)
mask = PID >= 0
ys, xs = np.nonzero(mask)
pp, nn, ids, aa = POS[ys, xs], NOR[ys, xs], PID[ys, xs].astype(np.int32), np.clip(AO[ys, xs], 0, 1)
col = np.ones((len(pp), 3), F)
emi = np.zeros((len(pp), 3), F)
mouth_pts = []
for s_ in (1.0, -1.0):
    pass


def mouth_dist(p):
    M_ = [(-0.062, 0.156, -0.087), (-0.036, 0.195, -0.100), (-0.012, 0.222, -0.103), (0.0, 0.226, -0.096), (0.012, 0.222, -0.103), (0.036, 0.195, -0.100), (0.062, 0.156, -0.087)]
    M_ = np.array(M_, F) + K.HC.astype(F)
    d = np.full(len(p), 9.0, F)
    for i in range(len(M_) - 1):
        ab = M_[i + 1] - M_[i]
        t = np.clip(((p - M_[i]) @ ab) / (ab @ ab), 0, 1)
        d = np.minimum(d, np.linalg.norm(p - (M_[i] + np.outer(t, ab)), axis=1))
    return d


by_name = {p.name: p for p in pieces}
for pi_, p in enumerate(pieces):
    m = ids == pi_
    if not m.any():
        continue
    q, n_, a = pp[m], nn[m], aa[m]
    nm = p.name
    if p.mat == "eyes":
        continue
    if nm == "body":
        c = P.body(q, n_, a)
    elif nm in ("armR", "armL"):
        c = P.arm(q, n_, a)
    elif nm == "head":
        c = P.head(q, n_, a, mouth_dist(q))
    elif nm in ("earR", "earL"):
        c = P.ear_paint(q, n_, a, p, nm)
    elif nm == "bandage":
        c = P.bandage(q, n_, a, p)
    elif nm == "tail":
        s_, sf, nf = [np.asarray(x, F) for x in p.frames]
        d2 = ((q[:, None, :] - s_[None, :, :]) ** 2).sum(2)
        ni = d2.argmin(1)
        tan = s_[np.minimum(ni + 1, len(s_) - 1)] - s_[np.maximum(ni - 1, 0)]
        tan /= np.maximum(np.linalg.norm(tan, axis=1, keepdims=True), 1e-6)
        along = ((q - s_[ni]) * tan).sum(1) / (np.linalg.norm(np.diff(s_, axis=0), axis=1).sum())
        tt = (ni / (len(s_) - 1)).astype(F) + along
        # the cream's edge is a row of fur points
        rel = q - s_[ni]
        ang = np.arctan2((rel * nf[ni]).sum(1), (rel * sf[ni]).sum(1))
        edge = 0.58 + 0.055 * np.abs(np.sin(ang * 3.5))
        cr = K.smooth(edge - 0.008, edge + 0.008, tt)
        c = P.mix(P.fur(q, n_, a), P.CREAM_T, cr)
        emi[np.nonzero(m)[0]] = P.rgb("ffdf9c")[None, :] * (K.smooth(0.72, 0.97, tt) * 0.42)[:, None]
        c = P.mix(c, P.rgb("ffeeb4"), K.smooth(0.72, 0.95, tt))
    elif nm.startswith("lid"):
        c = np.broadcast_to(P.ROSE * 0.98 + P.PINK * 0.02, q.shape).astype(F).copy()
        e_ = K.h(K.EYE * (1 if nm.endswith("R") else -1, 1, 1)).astype(F)
        ax = K.eye_axis(1 if nm.endswith("R") else -1).astype(F)
        c = P.mix(c, P.INK, K.smooth(0.55, 0.72, ((q - e_) @ ax) / K.EYE_R))
    elif nm.startswith("brow"):
        c = np.broadcast_to(P.rgb("fbd3d2"), q.shape).astype(F)
    elif nm == "nose":
        c = np.broadcast_to(P.rgb("2a1a22"), q.shape).astype(F).copy()
        c = P.mix(c, P.rgb("6b5560"), K.smooth(0.72, 0.95, n_[:, 2]) * 0.8)
    elif nm == "apron":
        c = P.apron(q, n_, a)
    elif nm.startswith("leafG") or nm.startswith("collar"):
        c = P.leaf_paint(q, n_, a, p, "green")
    elif nm.startswith("petal"):
        c = P.leaf_paint(q, n_, a, p, "pink")
    elif nm.startswith(("cflower_p", "flowerR_p", "flowerL_p")):
        c, e_ = P.flower_paint(q, n_, a, p, nm.startswith("cflower"))
        emi[np.nonzero(m)[0]] = e_
    elif nm.endswith("_c") and "flower" in nm:
        c = np.broadcast_to(P.rgb("ffe9a8"), q.shape).astype(F)
    elif nm == "pouch":
        c = P.pouch(q, n_, a)
    elif nm == "flap":
        c = P.flap(q, n_, a)
    elif nm in ("strap", "band") or nm.endswith("_cork") or nm == "scrolltie":
        c = P.leather(q, n_, a)
    elif nm == "scroll":
        c = np.broadcast_to(P.rgb("efd9b0"), q.shape).astype(F).copy()
    elif nm.startswith(("vialP", "vialV", "vialT")) and not nm.endswith(("_neck", "_cork")):
        col_ = {"vialP": "f0509a", "vialV": "9a55e8", "vialT": "4fd2c0"}[nm[:5]]
        c = P.mix(np.broadcast_to(P.rgb(col_), q.shape).astype(F), np.ones(3, F), K.smooth(0.72, 0.95, n_[:, 2] * 0.8 + n_[:, 1] * 0.3))
        emi[np.nonzero(m)[0]] = P.rgb(col_) * 0.5
    elif nm.endswith("_neck"):
        c = np.broadcast_to(P.rgb("c8d6dc"), q.shape).astype(F)
    elif nm.startswith("lens"):
        c = P.lens(q, n_, a)
    elif nm == "lroof":
        c = P.roof(q, n_, a)
    elif nm.startswith("lpane"):
        c = P.pane(q, p)
    elif p.mat == "metal":
        c = P.brass(q, n_, a)
    else:
        print("UNPAINTED", nm)
        c = np.ones_like(q)
    col[m] = c
line, star = P.constellation(pp, nn, ids, names)
col, emi = P.stack(col, emi, line, star)
# AO: soft, tinted plum on the fur, never black
ak = 0.62 + 0.38 * np.clip(aa * 1.3, 0, 1)
tint = P.mix(np.broadcast_to(P.rgb("a6609a"), col.shape).astype(F), np.ones(3, F), ak)
glow_ids = np.array([p.mat == "glow" or p.name.startswith("lpane") for p in pieces])
col = np.where(glow_ids[ids][:, None], col, col * tint)
OUTC[ys, xs] = col
OUTE[ys, xs] = emi
OUTC = S.dilate(OUTC, mask, it=8)
OUTE = S.dilate(OUTE, mask, it=8)
x0, y0 = int(EYE_TILE[0] * ATLAS), int(EYE_TILE[1] * ATLAS)
x1, y1 = int(EYE_TILE[2] * ATLAS), int(EYE_TILE[3] * ATLAS)
OUTC[y0:y1, x0:x1] = P.eyeball_tile(max(x1 - x0, y1 - y0))[: y1 - y0, : x1 - x0]
# (the atlas's row 0 is Blender's v = 0)
imgio.save(OUTC[::-1], os.path.join(WORK, "atlas.jpg"))
imgio.save(OUTE[::-1], os.path.join(WORK, "emit.jpg"))
wa = P.wing_atlas()
imgio.save(wa[::-1], os.path.join(WORK, "wing_atlas.png"))
print("paint", __import__("time").time() - t0)

# ------------------------------------------------------------------ materials
atlas = bpy.data.images.load(os.path.join(WORK, "atlas.jpg"))
atlas.name = "atlas"
emit = bpy.data.images.load(os.path.join(WORK, "emit.jpg"))
emit.name = "emit"
wimg = bpy.data.images.load(os.path.join(WORK, "wing_atlas.png"))
wimg.name = "wing_atlas"
for nm, mt in zip(ORDER, me.materials):
    nt = mt.node_tree
    nt.nodes.remove(nt.nodes["bake"])
    pb = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = wimg if nm == "card" else atlas
    nt.links.new(t.outputs[0], pb.inputs[0])
    pb.inputs["Roughness"].default_value = 0.7
    pb.inputs["Metallic"].default_value = 0.0
    if nm == "card":
        pb.inputs["Alpha"].default_value = 1.0
        nt.links.new(t.outputs[1], pb.inputs["Alpha"])
        mt.blend_method = "BLEND"
    elif nm not in ("eyes", "glow"):
        e = nt.nodes.new("ShaderNodeTexImage")
        e.image = emit
        nt.links.new(e.outputs[0], pb.inputs["Emission Color"])
        pb.inputs["Emission Strength"].default_value = 1.0

# ink room
attr = me.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
ic = np.ones((len(me.vertices), 4), F)
ic[:, 3] = RO
attr.data.foreach_set("color", ic.ravel())
me.color_attributes.active_color = attr

# ------------------------------------------------------------------ armature
sys.path.insert(0, HERE)
rig = WK.load_rig(os.path.join(REPO, "art", "wardens", "src", "pip_rig.json"))
arm = WK.build_armature(rig)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones


def bone(name, parent, head, tail_):
    e = eb.new(name)
    e.head, e.tail = Vector(head), Vector(tail_)
    e.parent = eb[parent]
    e.use_connect = False
    e.align_roll((0, 0, 1) if abs(Vector(tail_).z - Vector(head).z) < 0.5 * (Vector(tail_) - Vector(head)).length else (0, 1, 0))
    return e


def spring(names_, pts, parent):
    prev = parent
    for i, n in enumerate(names_):
        p = Vector(pts[i])
        q = Vector(pts[i + 1]) if i + 1 < len(pts) else p + (p - Vector(pts[i - 1]))
        bone(n, prev, p, q)
        prev = n


for s_, sd in ((1.0, "R"), (-1.0, "L")):
    c = K.h(K.EYE * (s_, 1, 1))
    bone("lid." + sd, "head", c, c + Vector((0, 0.03, 0)))
    b = K.h((s_ * 0.062, 0.135, 0.085))
    bone("brow." + sd, "head", b, b + Vector((0, 0.03, 0)))
    p0 = K.h((s_ * 0.112, -0.022, 0.13))
    bone("ear." + sd, "head", p0, p0 + Vector((s_ * 0.03, 0, 0.08)))
    hd = np.array([s_ * 0.118, -0.012, K.ANKLE_Z])
    bone("foot." + sd, "shin." + sd, hd, hd + [0, 0.12, 0])
    r_, sp, ch_, L_, W_ = K.wing_frame(s_, True)
    bone("wing." + sd, "hips", r_, r_ + sp * 0.2)
    spring(["spring_wing%s_%d" % (sd, i) for i in range(3)], [tuple(r_ + sp * L_ * t) for t in (0.3, 0.62, 0.95)], "wing." + sd)
kn = np.array([-K.SH, 0.006, K.WRIST_Z - 0.075])
bone("fingers.L", "hand.L", kn, kn + [0, 0, -0.06])
th = np.array([-K.SH + 0.03, 0.04, K.WRIST_Z - 0.035])
bone("thumb.L", "hand.L", th, th + [0, 0.02, -0.05])
j0 = K.h((0, 0.09, -0.085))
bone("jaw", "head", j0, j0 + Vector((0, 0.1, 0)))
ap = (0, 0.17, 0.80)
bone("apron", "hips", ap, (0, 0.17, 0.62))
spring(meta["tn"], meta["TAIL_PTS"], "tail")
spring(meta["cn"], meta["CAPE_PTS"], "hips")
spring(["spring_hanglantern_%d" % i for i in range(3)], meta["HANG_PTS"], "hand.R")
bpy.ops.object.mode_set(mode="OBJECT")
ob.parent = arm
md = ob.modifiers.new("arm", "ARMATURE")
md.object = arm
groups = {}
for vi, d in enumerate(W):
    tot = sum(d.values())
    for b, w in d.items():
        if b not in groups:
            groups[b] = ob.vertex_groups.new(name=b)
        groups[b].add([vi], w / tot if tot > 0 else 0.0, "REPLACE")

# ------------------------------------------------------------------ anchors, FX points
LZ = K.LZ
gx, gy = K.GRIP[0], K.GRIP[1]
A = {"anchor_head_top": ("head", K.h((0, 0, 0.16))), "anchor_chest": ("hips", (0, 0.17, 0.98)),
     "anchor_lantern_top": ("spring_hanglantern_0", (gx, gy, LZ["top"])), "anchor_hang_lantern": ("spring_hanglantern_0", (gx, gy, (LZ["eave"] + LZ["bottom"]) / 2)),
     "weapon_muzzle": ("spring_hanglantern_0", (gx, gy, (LZ["eave"] + LZ["bottom"]) / 2)),
     "anchor_flower": ("hips", (0.0, 0.20, 1.055)), "anchor_tail_tip": ("spring_tail_%d" % (K.TAIL_N - 2), tuple(K.TAIL_PATH[-1] * (1, 1, 1) + (0.03, 0.0, -0.06))),
     "anchor_palm_L": ("hand.L", (-K.SH, 0.03, K.WRIST_Z - 0.09))}
for nm, (bn, at) in A.items():
    WK.anchor(arm, bn, nm, tuple(at))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "pip_art1.blend"))
print("saved", __import__("time").time() - t0, "tris", sum(len(f) - 2 for f in FV))

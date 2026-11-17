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
    m0.factor, m0.iterations = 0.7, 8
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
armR_f, armL_f = K.arm_field("R"), K.arm_field("L")
armR = lowpoly("armR", armR_f, 500, protect=lambda v: smooth(K.WRIST_Z + 0.02, K.WRIST_Z - 0.03, v[:, 2]) * 0.8 + 0.2)
armL = lowpoly("armL", armL_f, 500, protect=lambda v: smooth(K.WRIST_Z + 0.02, K.WRIST_Z - 0.03, v[:, 2]) * 0.8 + 0.2)
BODY_FLOWER = (0.0, 0.0, 0.0)
hv, hf, huv = pickle.load(open(os.path.join(WORK, "head_scan.pkl"), "rb"))    # tools/art1/pip_head_scan.py: head, ears, bandage, goggles, band, flowers
head = Piece("head", "skin", hv, hf, huv, room=0.08)
bs = pickle.load(open(os.path.join(WORK, "body_scan.pkl"), "rb"))    # tools/art1/pip_source.py
body = Piece("body", "skin", bs["v"], bs["f"], bs["uv"], room=0.15)
pieces = [body, armR, armL, head]
for s_, sd in ((1.0, "R"), (-1.0, "L")):
    # a skin dome behind each eye, slid out through it to shut the eye (the scan's eyes are paint)
    c_ = K.h(K.EYE * (s_, 1, 1))
    near = hv[np.argmin(np.linalg.norm((hv - c_) * (1, 0, 1), axis=1) + (hv[:, 1] < c_[1] - 0.1) * 9)]
    p_ = K.ball("lid" + sd, "skin", (c_[0], near[1] - 0.04, c_[2]), (0.046, 0.016, 0.048), n=10, m=5, room=0.0)
    pieces.append(p_)
fi_ = np.argmax(-np.abs(body.v[:, 0]) * 3 - np.abs(body.v[:, 2] - 1.04) * 3 + body.v[:, 1])
BODY_FLOWER = tuple(body.v[fi_])
lant = K.lantern()
pieces += lant
wings = [K.wing(1.0, True), K.wing(-1.0, True), K.wing(1.0, False), K.wing(-1.0, False)]
pieces += wings

# ------------------------------------------------------------------ weights
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
q_ = head.v - K.HC
JAW = smooth(-0.088, -0.108, q_[:, 2]) * smooth(0.08, 0.13, q_[:, 1]) * smooth(0.085, 0.06, np.abs(q_[:, 0]))
EAR = smooth(0.165, 0.235, q_[:, 2]) * smooth(0.07, 0.1, np.abs(q_[:, 0])) * smooth(0.075, 0.04, q_[:, 1])
head.w = {"jaw": JAW, "ear.R": EAR * (q_[:, 0] > 0), "ear.L": EAR * (q_[:, 0] < 0), "head": np.clip(1 - JAW - EAR, 0, 1)}


def rigid(names, bone):
    for p in pieces:
        if p.name.startswith(names):
            p.w = {bone: np.ones(len(p.v))}


rigid(("lidR",), "lid.R")
rigid(("lidL",), "lid.L")
rigid(("lring", "lneck", "lroof", "lbody", "lfoot", "lpost", "lpane"), "spring_hanglantern_0")
HANG_PTS = [tuple(K.GRIP), tuple(K.GRIP + (0, 0, -0.24)), tuple(K.GRIP + (0, 0, -0.47))]

# the scan's body: its weights came through the decimation; the tail and the long back leaves go on their chains
Wb = bs["w"]
tpath = bs["tail_path"]
tn = ["spring_tail_%d" % i for i in range(K.TAIL_N)]
idx = np.linspace(0.05, 0.98, K.TAIL_N)
sl = np.linspace(0, 1, len(tpath))
TAIL_PTS = [tuple(np.interp(t_, sl, tpath[:, i]) for i in range(3)) for t_ in idx]
d2 = ((body.v[:, None, :] - tpath[None, :, :]) ** 2).sum(2)
tpar = d2.argmin(1) / (len(tpath) - 1)
tw_ = Wb.get("tailw", np.zeros(len(body.v)))
wt = {n: np.zeros(len(body.v)) for n in tn[:-1]}
wt["tail"] = np.zeros(len(body.v))
for i, t_ in enumerate(tpar):
    x = np.clip((t_ - 0.05) / 0.93, -0.3, 0.9999) * (K.TAIL_N - 1)
    if x < 0:
        wt["tail"][i] = tw_[i]
        continue
    b_ = int(x)
    q = x - b_
    wt[tn[b_]][i] += (1 - q) * tw_[i]
    wt[tn[min(b_ + 1, K.TAIL_N - 2)]][i] += q * tw_[i]
wb_ = {k_: x.copy() for k_, x in Wb.items() if k_ not in ("tailw", "capew", "kill", "cape", "brown", "cream")}
wb_.update(wt)
CAPE_PTS = [(0.0, -0.10, 1.02), (0.0, -0.14, 0.92), (0.0, -0.17, 0.84), (0.0, -0.18, 0.76)]   # the capelet's back hem
cn = ["spring_capeback_%d" % i for i in range(4)]
cw_ = Wb.get("capew", np.zeros(len(body.v)))
dz = np.clip((1.02 - body.v[:, 2]) / 0.26, 0, 0.999) * 3
for n_ in cn[:3]:
    wb_[n_] = np.zeros(len(body.v))
for i, x in enumerate(dz):
    b_ = int(x)
    q = x - b_
    wb_[cn[b_]][i] += (1 - q) * cw_[i]
    wb_[cn[min(b_ + 1, 2)]][i] += q * cw_[i]
for k_ in ("hips", "root", "apron"):
    if k_ in wb_:
        wb_[k_] = wb_[k_] * (1 - cw_)
body.w = wb_

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
    if p.name.startswith(("wing", "lpane")):
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


FACE = 1024


def smart_uv(p, angle):
    ob = ob_from("F_" + p.name, p.v, p.f)
    ob.data.uv_layers.new(name="UVMap")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.006, scale_to_bounds=True)
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.008, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")
    uv = np.zeros(len(ob.data.loops) * 2)
    ob.data.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    p.uv = [[tuple(uv[li]) for li in poly.loop_indices] for poly in ob.data.polygons]
    bpy.data.objects.remove(ob)


unique = [p for p in pieces if not p.name.startswith("wing") and p is not head and p is not body]
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
MATN = {"face": "skin-face", "hand": "skin-hand", "skin": "skin-fur", "cloth": "cloth-body", "leather": "leather-body", "metal": "brass-pip", "glow": "glow-pip", "card": "card-wing"}
ORDER = ["skin", "cloth", "leather", "metal", "hand", "glow", "card", "face"]
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
            FM.append(ORDER.index("hand" if p.mat == "skin" else p.mat))
            FP.append(pid_all)
            poly = polys_j[f0 + k]
            FU.append([tuple(uvj[li]) for li in poly.loop_indices])
    else:
        for k, q in enumerate(p.f):
            FV.append([i + base for i in q])
            cl = p.mat
            if p is body:
                gw, bw = [np.mean(Wb.get(c_, np.zeros(len(body.v)))[q]) for c_ in ("cape", "brown")]
                cl = "leather" if bw > 0.5 else ("cloth" if gw > 0.5 else "skin")
            FM.append(ORDER.index("face" if p is head else cl))
            FP.append(pid_all)
            u0, v0, u1, v1 = (0, 0, 1, 1) if p.mat == "eyes" else (0, 0, 1, 1)
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
    if FP[lt.polygon_index] in (names.index("body"), names.index("head")) or FM[lt.polygon_index] == ORDER.index("card"):
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
btv, btuv = [], []
for lt in me.loop_triangles:
    if FP[lt.polygon_index] == names.index("body"):
        btv.append(lt.vertices[:])
        btuv.append([uvd[li * 2:li * 2 + 2] for li in lt.loops])
btv, btuv = np.array(btv), np.array(btuv, F)
RB = S.raster(btuv, V[btv].astype(F), vn[btv].astype(F), np.arange(len(btv)), 2048, part=0)
RB["n"] /= np.maximum(np.linalg.norm(RB["n"], axis=2, keepdims=True), 1e-6)
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
    if nm in ("head", "body"):
        continue
    if nm in ("armR", "armL"):
        c = P.arm(q, n_, a)
    elif nm.startswith("lid"):
        c = np.broadcast_to(P.PINK, q.shape).astype(F).copy()
        e_ = np.array(p.v.mean(0), F)
        c = P.mix(c, P.INK, K.smooth(0.006, 0.002, np.abs(q[:, 2] - e_[2] + 0.012 + ((q[:, 0] - e_[0]) / 0.046) ** 2 * -0.012)))
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
# (the atlas's row 0 is Blender's v = 0)
# the scan's body: the gold constellations, the tail tip's and the flower's light on top of its bake
bm_ = RB["id"] >= 0
by, bx = np.nonzero(bm_)
bp, bn = RB["p"][by, bx], RB["n"][by, bx]
BC = S.dilate(imgio.load(os.path.join(WORK, "body.jpg"))[::-1].copy(), bm_, it=6)
bc = BC[by, bx]
# the scan's cream runs yellow under the toon light: back to the sheet's linen
yel = K.smooth(0.72, 0.84, bc[:, 0]) * K.smooth(0.8, 0.86, bc[:, 1] / np.maximum(bc[:, 0], 0.01)) * K.smooth(0.82, 0.72, bc[:, 2] / np.maximum(bc[:, 0], 0.01))
bc = P.mix(bc, bc.mean(1, keepdims=True) * np.array((1.05, 1.0, 0.92), F), yel * 0.55)
bl, bst = P.constellation(bp, bn, np.full(len(bp), names.index("body")), names)
tl2, ts2 = P.tail_stars(bp, bn, tpath)
bl, bst = np.maximum(bl, tl2), np.maximum(bst, ts2)
bc, be = P.stack(bc, np.zeros_like(bc), bl, bst)
d2t = ((bp[:, None, :] - tpath[None, -6:, :].astype(F)) ** 2).sum(2).min(1) ** 0.5
tipk = K.smooth(0.24, 0.08, d2t)
be = np.maximum(be, P.rgb("ffdf9c")[None, :] * (tipk * 0.3)[:, None])
fl_c = np.array(BODY_FLOWER, F)
frad = np.linalg.norm(bp - fl_c, axis=1)
be = np.maximum(be, P.rgb("ffdf9a")[None, :] * (K.smooth(0.05, 0.012, frad) * 0.6)[:, None])
BC[by, bx], BE = bc, np.zeros_like(BC)
BE[by, bx] = be
imgio.save(np.clip(BC, 0, 1)[::-1], os.path.join(WORK, "body_lit.jpg"))
imgio.save(np.clip(BE, 0, 1)[::-1], os.path.join(WORK, "body_emit.jpg"))
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
body_i = bpy.data.images.load(os.path.join(WORK, "body_lit.jpg"))
body_i.name = "body"
body_e = bpy.data.images.load(os.path.join(WORK, "body_emit.jpg"))
body_e.name = "body_emit"
nimg = bpy.data.images.load(os.path.join(WORK, "body_normal.jpg"))
nimg.name = "body_normal"
nimg.colorspace_settings.name = "Non-Color"
face_i = bpy.data.images.load(os.path.join(WORK, "face.jpg"))
face_i.name = "face"
face_e = bpy.data.images.load(os.path.join(WORK, "face_emit.jpg"))
face_e.name = "face_emit"
face_n = bpy.data.images.load(os.path.join(WORK, "face_normal.jpg"))
face_n.name = "face_normal"
face_n.colorspace_settings.name = "Non-Color"
for nm, mt in zip(ORDER, me.materials):
    nt = mt.node_tree
    nt.nodes.remove(nt.nodes["bake"])
    pb = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = wimg if nm == "card" else (face_i if nm == "face" else (body_i if nm in ("skin", "cloth", "leather") else atlas))
    nt.links.new(t.outputs[0], pb.inputs[0])
    pb.inputs["Roughness"].default_value = 0.7
    pb.inputs["Metallic"].default_value = 0.0
    if nm == "card":
        pb.inputs["Alpha"].default_value = 1.0
        nt.links.new(t.outputs[1], pb.inputs["Alpha"])
        mt.blend_method = "BLEND"
    if nm in ("skin", "cloth", "leather", "face"):
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = face_n if nm == "face" else nimg
        nn_ = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tn.outputs[0], nn_.inputs["Color"])
        nt.links.new(nn_.outputs[0], pb.inputs["Normal"])
    if nm not in ("glow", "card", "metal"):
        e = nt.nodes.new("ShaderNodeTexImage")
        e.image = face_e if nm == "face" else (body_e if nm in ("skin", "cloth", "leather") else emit)
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
    p0 = K.h((s_ * 0.13, -0.022, 0.17))
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
A = {"anchor_head_top": ("head", K.h((0, 0, 0.26))), "anchor_chest": ("hips", tuple(np.array(BODY_FLOWER) + (0, 0.02, -0.08))),
     "anchor_lantern_top": ("spring_hanglantern_0", (gx, gy, LZ["top"])), "anchor_hang_lantern": ("spring_hanglantern_0", (gx, gy, (LZ["eave"] + LZ["bottom"]) / 2)),
     "weapon_muzzle": ("spring_hanglantern_0", (gx, gy, (LZ["eave"] + LZ["bottom"]) / 2)),
     "anchor_flower": ("hips", tuple(np.array(BODY_FLOWER) + (0, 0.03, 0))), "anchor_tail_tip": ("spring_tail_%d" % (K.TAIL_N - 2), tuple(tpath[-2])),
     "anchor_palm_L": ("hand.L", (-K.SH, 0.03, K.WRIST_Z - 0.09))}
for nm, (bn, at) in A.items():
    WK.anchor(arm, bn, nm, tuple(at))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "pip_art1.blend"))
print("saved", __import__("time").time() - t0, "tris", sum(len(f) - 2 for f in FV))

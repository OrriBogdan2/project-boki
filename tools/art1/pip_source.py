"""Pip's body from the Meshy scan of the turnaround (wings out; 40 credits): fitted on the rig, arms and head cut (the arms and hands are scripted, pip_sculpt;
the head is its own scan), the tail swung up and back for the top-down read, decimated, baked to its own 2048 colour and normal.
Run: blender -b --factory-startup --python tools/art1/pip_source.py -- <scan.glb> <WORK> [tris]
Out: WORK/body_scan.pkl (verts, faces, per-corner uv, weights, per-face class), body.jpg, body_normal.jpg. Space as pip_sculpt: +Y front, her right +X."""
import math
import os
import pickle
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import imgio
import pip_sculpt as K
from meshkit import catmull, smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, WORK = a[0], a[1]
TRIS = int(a[2]) if len(a) > 2 else 6200
SIZE = 2048
SOLE = -0.95                 # the scan's sole
KS = 1.63 / 1.9              # scan metres -> rig metres (ear tip to sole)
TAIL_LIFT = math.radians(48)  # the tail swung back and up about its root
F = np.float32
# scan joints, read off grid_front and grid_right (x her right, y forward, z up, raw metres)
S_J = {"pelvis": (0, 0.17, -0.46), "neck": (0, 0.22, 0.30), "hip.R": (0.10, 0.16, -0.46), "knee.R": (0.17, 0.08, -0.66), "ankle.R": (0.205, 0.10, -0.86),
       "hip.L": (-0.10, 0.16, -0.46), "knee.L": (-0.17, 0.08, -0.66), "ankle.L": (-0.205, 0.10, -0.86)}
ARM = {"R": ((0.23, 0.20, 0.12), (0.39, 0.20, -0.01), (0.50, 0.2, -0.12), (0.60, 0.2, -0.21))}
ARM["L"] = tuple((-p[0], p[1], p[2]) for p in ARM["R"])
TAIL = np.array(((0.0, 0.0, -0.36), (-0.05, -0.14, -0.52), (-0.14, -0.24, -0.68), (-0.22, -0.30, -0.82), (-0.27, -0.33, -0.93)))
J = K.J
T = {"pelvis": J["hips"], "neck": J["head"]}
for sd in "RL":
    T["hip." + sd], T["knee." + sd] = J["thigh." + sd], J["shin." + sd]
    T["ankle." + sd] = np.array((J["shin." + sd][0] * 1.08, -0.012, K.ANKLE_Z))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
hi = next(o for o in bpy.data.objects if o.type == "MESH")
mw = hi.matrix_world.copy()
hi.parent = None
hi.matrix_world = mw
hi.select_set(True)
bpy.context.view_layer.objects.active = hi
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = hi.data
n = len(me.vertices)
co = np.zeros(n * 3)
me.vertices.foreach_get("co", co)
P = co.reshape(-1, 3) * (-1, -1, 1)
print("scan", n, P.min(0).round(3), P.max(0).round(3))
# the paint per vertex, for what is cloth, leaf, leather or fur
tex = next(nd for nd in me.materials[0].node_tree.nodes if nd.type == "BSDF_PRINCIPLED").inputs[0].links[0].from_node.image
tw, th = tex.size
px = np.array(tex.pixels[:], F).reshape(th, tw, -1)[..., :3] if tw <= 4096 else None
if px is None:
    tex.scale(2048, 2048)
    tw, th = tex.size
    px = np.array(tex.pixels[:], F).reshape(th, tw, -1)[..., :3]
uvl = np.zeros(len(me.loops) * 2)
me.uv_layers[0].data.foreach_get("uv", uvl)
uvl = uvl.reshape(-1, 2)
lv = np.zeros(len(me.loops), np.int32)
me.loops.foreach_get("vertex_index", lv)
vuv = np.zeros((n, 2))
vuv[lv] = uvl
C = px[np.clip((vuv[:, 1] * th).astype(int), 0, th - 1), np.clip((vuv[:, 0] * tw).astype(int), 0, tw - 1)]
r_, g_, b_ = C.T
GREEN = g_ > r_ * 0.98
BROWN = (b_ / np.maximum(r_, 0.01) < 0.62) & (g_ / np.maximum(r_, 0.01) < 0.78) & (r_ < 0.72) & ~GREEN
CREAM = (g_ / np.maximum(r_, 0.01) > 0.78) & (r_ > 0.72) & ~GREEN & (P[:, 2] < 0.08) & (P[:, 1] > 0.08)
FUR = ~(GREEN | BROWN | CREAM)
print("classes", GREEN.sum(), BROWN.sum(), CREAM.sum(), FUR.sum())

def seg(a0, a1, p=P):
    a0, a1 = np.asarray(a0, float), np.asarray(a1, float)
    u = a1 - a0
    t = np.clip(((p - a0) @ u) / (u @ u), 0, 1)
    return np.linalg.norm(p - (a0 + t[:, None] * u), axis=1), t


# the arms come off: all fur near their line, outside the torso (scripted arms hang there); the head comes off at the collar
kill = (P[:, 2] > 0.415)
for sd in "RL":
    pts = ARM[sd]
    d = np.minimum.reduce([seg(pts[i], pts[i + 1])[0] for i in range(3)])
    s = 1.0 if sd == "R" else -1.0
    kill |= FUR & (d < 0.105) & (P[:, 0] * s > 0.20)
    kill |= (P[:, 0] * s > 0.40) & (P[:, 2] < 0.02) & ~GREEN & ~CREAM
# the tail
dt = np.min([seg(TAIL[i], TAIL[i + 1])[0] for i in range(len(TAIL) - 1)], 0)
tail_w = (FUR & (P[:, 1] < 0.0) & (P[:, 2] < -0.26) & (dt < 0.34)).astype(F) * smooth(0.0, -0.05, P[:, 1]).astype(F)
# weights
Wn = {}
torso_w = np.ones(n, F)
for sd in "RL":
    d1, _ = seg(S_J["hip." + sd], S_J["knee." + sd])
    d2, _ = seg(S_J["knee." + sd], S_J["ankle." + sd])
    s = 1.0 if sd == "R" else -1.0
    side = smooth(-0.005, 0.03, P[:, 0] * s)
    below = smooth(-0.40, -0.50, P[:, 2]) * FUR * (1 - tail_w)
    legs = side * below * (d1 < 0.2)
    k = smooth(-0.70, -0.62, P[:, 2])                # 1: thigh, 0: shin
    f = smooth(-0.84, -0.89, P[:, 2])
    Wn["thigh." + sd] = legs * k
    Wn["shin." + sd] = legs * (1 - k) * (1 - f)
    Wn["foot." + sd] = legs * (1 - k) * f
    Wn["thigh." + sd][(P[:, 2] < -0.60) & (d2 < 0.2) & (side > 0.5) & FUR & (tail_w < 0.5)] *= 1.0
legsum = sum(Wn.values())


def lerp_move(p, j0, j1):
    """Moves points riding a segment from the scan's joints to the rig's."""
    a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    b0, b1 = T[j0], T[j1]
    u = a1 - a0
    L = np.linalg.norm(u)
    u = u / L
    v = b1 - b0
    Lv = np.linalg.norm(v)
    v = v / Lv
    ax = (p - a0) @ u
    rad = (p - a0) - ax[:, None] * u
    c = np.cross(u, v)
    s_, d_ = np.linalg.norm(c), u @ v
    R = np.eye(3)
    if s_ > 1e-6:
        kk = np.array([[0, -c[2], c[1]], [c[2], 0, -c[0]], [-c[1], c[0], 0]]) / s_
        R = np.eye(3) + kk * s_ + kk @ kk * (1 - d_)
    return b0 + ax[:, None] * (Lv / L) * v + (rad * KS) @ R.T


Q_t = lerp_move(P, "pelvis", "neck")
Q = Q_t.copy()
legp = Wn["thigh.R"] * 0
for sd in "RL":
    q1 = lerp_move(P, "hip." + sd, "knee." + sd)
    q2 = lerp_move(P, "knee." + sd, "ankle." + sd)
    wth = smooth(-0.72, -0.60, P[:, 2])[:, None]
    ql = q1 * wth + q2 * (1 - wth)
    wl = (Wn["thigh." + sd] + Wn["shin." + sd] + Wn["foot." + sd])[:, None]
    Q = Q * (1 - wl) + ql * wl
# the tail rides the pelvis, swung up and back about its root
root = T["pelvis"] + (np.array((0.0, -0.13, 0.03)))
qt = Q_t - root
c, s = math.cos(TAIL_LIFT), math.sin(TAIL_LIFT)
y2 = qt[:, 1] * c - qt[:, 2] * s
z2 = qt[:, 1] * s + qt[:, 2] * c
# (the rotation sends down to back: y' = y cos + z sin for z < 0)
y2 = qt[:, 1] * c + qt[:, 2] * s
z2 = -qt[:, 1] * s + qt[:, 2] * c
qr = np.stack([qt[:, 0], y2, z2], 1) + root
Q = Q * (1 - tail_w[:, None]) + qr * tail_w[:, None]
# the path, for the chain
TP = lerp_move(np.array(TAIL), "pelvis", "neck") - root
TP = np.stack([TP[:, 0], TP[:, 1] * c + TP[:, 2] * s, -TP[:, 1] * s + TP[:, 2] * c], 1) + root
TP = catmull(TP, 16)
Q[:, 1] += CREAM * smooth(0.78, 0.56, Q[:, 2]) * 0.024      # the apron stands off the thighs, or a stride pokes through
print("fitted", Q[~kill].min(0).round(3), Q[~kill].max(0).round(3))
me.vertices.foreach_set("co", Q.ravel())
me.update()
g = hi.vertex_groups.new(name="kill")
ids = np.nonzero(kill)[0].tolist()
g.add(ids, 1.0, "REPLACE")

# weights of the kept mesh, as vertex groups, carried through the decimation
hips_k = smooth(0.50, 0.72, Q[:, 2]) * (1 - legsum) * (1 - tail_w)
root_k = (1 - hips_k - legsum - tail_w).clip(0, 1)
apron = (CREAM * smooth(0.72, 0.56, Q[:, 2])).astype(F)
# (its hem follows the pelvis, not the chest's twist; the bone adds the swing)
hem = smooth(0.8, 0.6, Q[:, 2]) * CREAM
root_k = root_k + hips_k * hem
hips_k = hips_k * (1 - hem)
root_k *= (1 - apron * 0.45)
hips_k *= (1 - apron * 0.45)
apron = apron * 0.45
cape_back = (GREEN | (FUR & (Q[:, 2] > 0.68))) & (Q[:, 1] < -0.1) & (Q[:, 2] < 1.0)
WG = {"root": root_k, "hips": hips_k, "apron": apron, "tailw": tail_w, "capew": cape_back.astype(F) * smooth(0.98, 0.85, Q[:, 2])}
for k_ in list(Wn):
    WG[k_] = Wn[k_]
for b, w in WG.items():
    vg = hi.vertex_groups.new(name=b)
    for v_, ww in zip(np.nonzero(w > 0.01)[0].tolist(), w[w > 0.01].tolist()):
        vg.add([v_], float(ww), "REPLACE")
for name, m_ in (("green", GREEN), ("brown", BROWN), ("cream", CREAM)):
    vg = hi.vertex_groups.new(name=name)
    vg.add(np.nonzero(m_)[0].tolist(), 1.0, "REPLACE")

low = hi.copy()
low.data = me.copy()
low.name = "BodyLow"
bpy.context.scene.collection.objects.link(low)
bm = bmesh.new()
bm.from_mesh(low.data)
dl = bm.verts.layers.deform.verify()
gi = low.vertex_groups["kill"].index
bmesh.ops.delete(bm, geom=[v for v in bm.verts if gi in v[dl]], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)     # (the scan is split along its UV seams: weld, or every island cracks open)
bm.to_mesh(low.data)
bm.free()
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
d = low.modifiers.new("d", "DECIMATE")
d.decimate_type = "COLLAPSE"
d.ratio = min(1.0, TRIS / max(sum(len(p.vertices) - 2 for p in low.data.polygons), 1))
d.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="d")
print("low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
while low.data.uv_layers:
    low.data.uv_layers.remove(low.data.uv_layers[0])
low.data.uv_layers.new(name="UVMap")
low.data.materials.clear()
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003, scale_to_bounds=True)
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.003, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
low.data.polygons.foreach_set("use_smooth", [True] * len(low.data.polygons))
low.data.update()
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 4
sc.render.threads_mode = "FIXED"
sc.render.threads = 8
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.03
sc.render.bake.max_ray_distance = 0.07
sc.render.bake.margin = 16
mt = bpy.data.materials.new("bake")
mt.use_nodes = True
low.data.materials.append(mt)
node = mt.node_tree.nodes.new("ShaderNodeTexImage")
mt.node_tree.nodes.active = node


def bake(name, kind, **kw):
    im = bpy.data.images.new(name, SIZE, SIZE, float_buffer=True)
    if kind == "NORMAL":
        im.colorspace_settings.name = "Non-Color"
    node.image = im
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type=kind, **kw)
    pix = np.zeros((SIZE, SIZE, 4), F)
    im.pixels.foreach_get(pix.ravel())
    return pix[..., :3]


col = bake("c", "DIFFUSE", pass_filter={"COLOR"})
nor = bake("n", "NORMAL", normal_space="TANGENT")
srgb = np.clip(np.where(col <= 0.0031308, col * 12.92, 1.055 * np.maximum(col, 1e-5) ** (1 / 2.4) - 0.055), 0, 1)
imgio.save(srgb[::-1], os.path.join(WORK, "body.jpg"))
imgio.save(np.clip(nor, 0, 1)[::-1], os.path.join(WORK, "body_normal.jpg"))
lm = low.data
nv = len(lm.vertices)
v = np.zeros(nv * 3)
lm.vertices.foreach_get("co", v)
uv = np.zeros(len(lm.loops) * 2)
lm.uv_layers[0].data.foreach_get("uv", uv)
uv = uv.reshape(-1, 2)
faces = [list(p.vertices) for p in lm.polygons]
fuv = [[tuple(uv[i]) for i in p.loop_indices] for p in lm.polygons]
gn = {g_.index: g_.name for g_ in low.vertex_groups}
W = {}
for vi, vert in enumerate(lm.vertices):
    for ge in vert.groups:
        W.setdefault(gn[ge.group], np.zeros(nv))[vi] = ge.weight
pickle.dump({"v": v.reshape(-1, 3), "f": faces, "uv": fuv, "w": W, "tail_path": TP}, open(os.path.join(WORK, "body_scan.pkl"), "wb"))
print("BODY_DONE", len(faces))

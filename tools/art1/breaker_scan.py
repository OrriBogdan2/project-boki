"""Breaker's body from the Meshy scan of the turnaround (ART-1 fine detail): the scan's joints -> the rig's, a decimated game mesh,
and the scan's paint and fine relief baked onto it (Cycles selected-to-active: base colour + tangent normals).
  blender -b --factory-startup --python tools/art1/breaker_scan.py -- SCAN.glb RIG.json WORK [tris]
Out: WORK/scan_low.npz (verts, tris, uvs, per-vertex rigid bone), WORK/scan_albedo.png, WORK/scan_normal.png.
The helmet, masts, fish, hammer and shield stay scripted (breaker_art1.py): the turnaround has no clean version of them."""
import json
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, WORK = a[0], a[1], a[2]
TRIS = int(a[3]) if len(a) > 3 else 9000
SIZE = 2048
J = json.load(open(os.path.join(WORK, "scan_joints.json")))     # measured on the grid renders
rig = json.load(open(RIG))["bones"]


def rj(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"hull": (np.array((0, 0, 0.2)), np.array((0, 0, 0.82)))}
SEG = [("hull", "hull_bot", "hull_top", 0.3, "hips")]
TJ = {"hull_bot": np.array((0, 0, 0.16)), "hull_top": np.array((0, 0, 0.84))}
for s in "RL":
    TJ["shoulder." + s], TJ["elbow." + s], TJ["wrist." + s] = rj("upper_arm." + s), rj("forearm." + s), rj("hand." + s)
    TJ["fist." + s] = TJ["wrist." + s] + (0, 0, -0.14)
    TJ["hip." + s], TJ["knee." + s] = rj("thigh." + s), rj("shin." + s)
    TJ["ankle." + s] = np.array((TJ["knee." + s][0], 0, 0.06))
    TJ["toe." + s] = np.array((TJ["knee." + s][0], 0.2, 0.03))
    SEG += [("up" + s, "shoulder." + s, "elbow." + s, 0.1, "upper_arm." + s), ("fore" + s, "elbow." + s, "wrist." + s, 0.12, "forearm." + s),
            ("fist" + s, "wrist." + s, "fist." + s, 0.1, "hand." + s), ("thigh" + s, "hip." + s, "knee." + s, 0.08, "thigh." + s),
            ("shin" + s, "knee." + s, "ankle." + s, 0.08, "shin." + s), ("foot" + s, "ankle." + s, "toe." + s, 0.07, "x_foot." + s)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
src = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o is not src:
        bpy.data.objects.remove(o)
src.parent = None
mw = np.array(src.matrix_world)
n = len(src.data.vertices)
co = np.empty(n * 3)
src.data.vertices.foreach_get("co", co)
co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
src.matrix_world.identity()
P = np.stack((-co[:, 0], -co[:, 1], co[:, 2]), 1)         # to +Y facing, his right +X
print("scan", n, P.min(0).round(3), P.max(0).round(3), flush=True)

SJ = {k: np.array(v, float) for k, v in J.items()}
D = np.zeros((n, len(SEG)))
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    a0, a1 = SJ[j0], SJ[j1]
    u = a1 - a0
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    q = P - (a0 + h[:, None] * u)
    D[:, i] = np.linalg.norm(q, axis=1) - (rad if nm != "hull" else float(J["hull_r"]))
    if nm[-1] in "RL" and nm != "hull":
        side = 1.0 if nm[-1] == "R" else -1.0
        D[P[:, 0] * side < 0.02, i] = 9.0
W = np.exp(-(D - D.min(1, keepdims=True)) / 0.012)
W /= W.sum(1, keepdims=True)
Q = np.zeros_like(P)
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    p0, p1, q0, q1 = SJ[j0], SJ[j1], TJ[j0], TJ[j1]
    ln = np.linalg.norm(p1 - p0)
    u = (p1 - p0) / ln
    v = (q1 - q0) / np.linalg.norm(q1 - q0)
    c = np.cross(u, v)
    sn, d = np.linalg.norm(c), u @ v
    R = np.eye(3)
    if sn > 1e-7:
        k = np.array([[0, -c[2], c[1]], [c[2], 0, -c[0]], [-c[1], c[0], 0]]) / sn
        R = np.eye(3) + k * sn + k @ k * (1 - d)
    sa = np.linalg.norm(q1 - q0) / ln
    girth = float(J.get("girth", {}).get(nm, sa if nm == "hull" else 1.0))
    r = P - p0
    ax = r @ u
    Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + (r - ax[:, None] * u) @ R.T * girth)
src.data.vertices.foreach_set("co", Q.astype(np.float32).ravel())
src.data.update()
BONE = np.array([SEG[i][4] for i in np.argmax(W, axis=1)])

# ---- the game mesh
bpy.context.view_layer.objects.active = src
low = src.copy()
low.data = src.data.copy()
low.name = "Low"
bpy.context.scene.collection.objects.link(low)
bpy.context.view_layer.objects.active = low
m = low.modifiers.new("d", "DECIMATE")
m.ratio = TRIS / max(len(low.data.polygons), 1)
bpy.ops.object.modifier_apply(modifier="d")
for u in list(low.data.uv_layers):
    low.data.uv_layers.remove(u)
low.data.materials.clear()
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.uv.smart_project(angle_limit=1.13, island_margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
print("low", len(low.data.polygons), flush=True)

# ---- bake
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 4
sc.render.threads_mode = "FIXED"
sc.render.threads = 6
mat = bpy.data.materials.new("bake")
mat.use_nodes = True
low.data.materials.append(mat)
out = {}
for nm, kind, cs in (("scan_albedo", "DIFFUSE", "sRGB"), ("scan_normal", "NORMAL", "Non-Color")):
    img = bpy.data.images.new(nm, SIZE, SIZE, alpha=False)
    img.colorspace_settings.name = cs
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    mat.node_tree.nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    kw = dict(type=kind, use_selected_to_active=True, cage_extrusion=0.03, max_ray_distance=0.08, margin=8)
    if kind == "DIFFUSE":
        kw["pass_filter"] = {"COLOR"}
    bpy.ops.object.bake(**kw)
    img.filepath_raw = os.path.join(WORK, nm + ".png")
    img.file_format = "PNG"
    img.save()
    print("baked", nm, flush=True)

# ---- the low mesh, its rigid bones (nearest scan vertex's)
me = low.data
v = np.empty(len(me.vertices) * 3, np.float32)
me.vertices.foreach_get("co", v)
v = v.reshape(-1, 3)
lv = np.empty(len(me.loops), np.int32)
me.loops.foreach_get("vertex_index", lv)
uv = np.empty(len(me.loops) * 2, np.float32)
me.uv_layers.active.data.foreach_get("uv", uv)
from mathutils.kdtree import KDTree
kd = KDTree(n)
for i, p in enumerate(Q):
    kd.insert(p, i)
kd.balance()
nb = [BONE[kd.find(p)[1]] for p in v]
np.savez(os.path.join(WORK, "scan_low.npz"), v=v, tri=lv.reshape(-1, 3), uv=uv.reshape(-1, 2), bone=np.array(nb))
print("done", len(v), flush=True)

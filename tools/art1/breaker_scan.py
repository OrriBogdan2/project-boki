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
TJ = {"hull_bot": np.array((0, 0, 0.2)), "hull_top": np.array((0, 0, 0.83))}
HC = np.array((-0.045, -0.21, -0.015))
HS = np.array((1.05, 0.93, 0.68))         # the hull, axis by axis: wider than tall, as the owner asks
for s in "RL":
    TJ["shoulder." + s], TJ["elbow." + s], TJ["wrist." + s] = rj("upper_arm." + s), rj("forearm." + s), rj("hand." + s)
    TJ["hip." + s], TJ["knee." + s] = rj("thigh." + s), rj("shin." + s)
    TJ["ankle." + s] = np.array((TJ["knee." + s][0], 0, 0.05))
    TJ["toe." + s] = np.array((TJ["knee." + s][0], 0.17, 0.02))
    SEG += [("up" + s, "shoulder." + s, "elbow." + s, 0.1, "upper_arm." + s), ("fore" + s, "elbow." + s, "wrist." + s, 0.12, "forearm." + s),
            ("thigh" + s, "hip." + s, "knee." + s, 0.08, "thigh." + s),
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

SJ = {k: np.array(v, float) for k, v in J.items() if isinstance(v, list)}
D = np.zeros((n, len(SEG)))
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    a0, a1 = SJ[j0], SJ[j1]
    u = a1 - a0
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    q = P - (a0 + h[:, None] * u)
    D[:, i] = np.linalg.norm(q, axis=1) - rad
    if nm == "hull":
        D[:, i] = (np.linalg.norm((P - HC) / (0.46, 0.44, 0.47), axis=1) - 1.0) * 0.3
    if nm[-1] in "RL" and nm != "hull":
        side = 1.0 if nm[-1] == "R" else -1.0
        D[P[:, 0] * side < 0.02, i] = 9.0
W = np.exp(-(D - D.min(1, keepdims=True)) / 0.012)
W /= W.sum(1, keepdims=True)
Q = np.zeros_like(P)
for i, (nm, j0, j1, rad, _) in enumerate(SEG):
    if nm == "hull":
        Q += W[:, i, None] * ((P - HC) * HS + (0, 0, 0.515))
        continue
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

# ---- cut what the scripted parts replace: helmet and collar, stumps, the fists past the wrist; drop floaters
import bmesh
cut = (np.hypot(P[:, 0] - HC[0], (P[:, 1] - HC[1]) * 1.1) < 0.33) & (P[:, 2] > 0.38) | (P[:, 2] > 0.5)
for sd, sx in (("R", 1.0), ("L", -1.0)):
    u = SJ["wrist." + sd] - SJ["elbow." + sd]
    cut |= (P[:, 0] * sx > 0.4) & (((P - SJ["wrist." + sd]) @ u) > 0.0)
bm = bmesh.new()
bm.from_mesh(src.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(cut)[0].tolist()], context="VERTS")
seen = set()
isl = []
for vv in bm.verts:
    if vv in seen:
        continue
    st, cur = [vv], []
    seen.add(vv)
    while st:
        a_ = st.pop()
        cur.append(a_)
        for e in a_.link_edges:
            o_ = e.other_vert(a_)
            if o_ not in seen:
                seen.add(o_)
                st.append(o_)
    isl.append(cur)
big = max(len(c) for c in isl)
bmesh.ops.delete(bm, geom=[a_ for c in isl if len(c) < big * 0.01 for a_ in c], context="VERTS")
bm.to_mesh(src.data)
bm.free()
keep = ~cut
Q, BONE = Q[keep], BONE[keep]
n = len(Q)
print("cut, left", len(src.data.vertices), flush=True)

AXES = np.array(((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)), np.float32)


def chart_seams(ob, min_faces=24):
    """Seams for a clean unwrap: each face goes to the axis it faces, the labels are smoothed over neighbours and small
    islands merged, so the charts follow the form instead of the decimated triangles."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    n = len(bm.faces)
    nrm = np.array([f.normal for f in bm.faces], np.float32)
    lab = np.argmax(nrm @ AXES.T, axis=1)
    nb = [[e2.index for e in f.edges for e2 in e.link_faces if e2.index != f.index] for f in bm.faces]
    for _ in range(4):
        new = lab.copy()
        for i in range(n):
            c = np.bincount(lab[nb[i]], minlength=6) if nb[i] else None
            if c is not None and c.max() >= 2:
                new[i] = int(np.argmax(c))
        lab = new
    for _ in range(6):
        seen = np.zeros(n, bool)
        changed = False
        for i in range(n):
            if seen[i]:
                continue
            st, comp = [i], []
            seen[i] = True
            while st:
                a = st.pop()
                comp.append(a)
                for b in nb[a]:
                    if not seen[b] and lab[b] == lab[a]:
                        seen[b] = True
                        st.append(b)
            if len(comp) < min_faces:
                out = [lab[b] for a in comp for b in nb[a] if lab[b] != lab[a]]
                if out:
                    lab[comp] = int(np.bincount(out).argmax())
                    changed = True
        if not changed:
            break
    for e in bm.edges:
        fs = e.link_faces
        e.seam = len(fs) == 2 and lab[fs[0].index] != lab[fs[1].index]
    bm.to_mesh(ob.data)
    bm.free()


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
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode="OBJECT")
print("low", len(low.data.polygons), flush=True)

# ---- a clean unwrap by form (decimating the scan's own UVs drags triangles across its islands), then the bake
for u in list(low.data.uv_layers):
    low.data.uv_layers.remove(u)
low.data.materials.clear()
low.data.uv_layers.new(name="UVMap")
chart_seams(low, 60)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.004)
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 4
sc.render.threads_mode = "FIXED"
sc.render.threads = 6
mat = bpy.data.materials.new("bake")
mat.use_nodes = True
low.data.materials.append(mat)
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
    kw = dict(type=kind, use_selected_to_active=True, cage_extrusion=0.09, max_ray_distance=0.22, margin=12)
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
for i, p in enumerate(Q.tolist()):
    kd.insert(p, i)
kd.balance()
nb = [BONE[kd.find(p)[1]] for p in v]
np.savez(os.path.join(WORK, "scan_low.npz"), v=v, tri=lv.reshape(-1, 3), uv=uv.reshape(-1, 2), bone=np.array(nb))
print("done", len(v), flush=True)

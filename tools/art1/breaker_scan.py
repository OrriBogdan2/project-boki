"""Mossy's body from the Meshy scan of mossy_v2_turnaround (ART-1 fine detail): the dense scan and Meshy's remesh of it, both moved from
the scan's joints to the rig's. The remesh is the game mesh (a decimate tears a scan); albedo and normals are baked onto it from the dense scan.
  blender -b --factory-startup --python tools/art1/breaker_scan.py -- SCAN.glb RIG.json WORK RETOPO.glb
In: WORK/scan_joints.json (joints, hull_c/hull_r and cut_neck, measured on tools/meshy/grid_renders.py renders of the scan).
Out: WORK/scan_low.npz (the retopo: verts, tris, uvs, bones, weights), WORK/scan_albedo.png, WORK/scan_normal.png.
The helmet, collar, compass dial, fists, masts, fish, hammer and shield stay scripted (breaker_art1.py)."""
import json
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
a = sys.argv[sys.argv.index("--") + 1:]
SCAN, RIG, WORK, RETOPO = a[0], a[1], a[2], a[3]
SIZE = 2048
J = json.load(open(os.path.join(WORK, "scan_joints.json")))     # measured on the grid renders
rig = json.load(open(RIG))["bones"]


def rj(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"hull": (np.array((0, 0, 0.16)), np.array((0, 0, 0.9)))}
SEG = [("hull", "hull_bot", "hull_top", 0.3, "hips")]
TJ = {"hull_bot": np.array((0, 0, 0.16)), "hull_top": np.array((0, 0, 0.9))}
HC = np.array(J["hull_c"])                # the scan's hull: centre and half sizes (scan_joints.json, read off the grid renders)
HR = np.array(J["hull_r"])
HS = np.array((0.419, 0.392, 0.376)) / HR  # its half sizes on the rig: 1.1 wide to tall, so bulk 0.8 lands on the art's 0.9
for s in "RL":
    TJ["shoulder." + s], TJ["elbow." + s], TJ["wrist." + s] = rj("upper_arm." + s), rj("forearm." + s), rj("hand." + s)
    TJ["hip." + s], TJ["knee." + s] = rj("thigh." + s), rj("shin." + s)
    TJ["ankle." + s] = np.array((TJ["knee." + s][0], 0, 0.05))
    TJ["toe." + s] = np.array((TJ["knee." + s][0], 0.17, 0.02))
    SEG += [("up" + s, "shoulder." + s, "elbow." + s, 0.1, "upper_arm." + s), ("fore" + s, "elbow." + s, "wrist." + s, 0.12, "forearm." + s),
            ("thigh" + s, "hip." + s, "knee." + s, 0.08, "thigh." + s),
            ("shin" + s, "knee." + s, "ankle." + s, 0.08, "shin." + s), ("foot" + s, "ankle." + s, "toe." + s, 0.07, "x_foot." + s)]



def load(path):
    """The mesh of a glb, its verts in the scan's +Y-facing frame (P), and the object."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    ob = [o for o in new if o.type == "MESH"][0]
    for o in new:
        if o is not ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    mw = np.array(ob.matrix_world)
    n = len(ob.data.vertices)
    co = np.empty(n * 3)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    ob.matrix_world.identity()
    return ob, np.stack((-co[:, 0], -co[:, 1], co[:, 2]), 1)


SJ = {k: np.array(v, float) for k, v in J.items() if isinstance(v, list)}


def fit(P):
    """P -> (Q on the rig, W per SEG)."""
    n = len(P)
    D = np.zeros((n, len(SEG)))
    for i, (nm, j0, j1, rad, _) in enumerate(SEG):
        a0, a1 = SJ[j0], SJ[j1]
        u = a1 - a0
        h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
        q = P - (a0 + h[:, None] * u)
        D[:, i] = np.linalg.norm(q, axis=1) - rad
        if nm == "hull":
            D[:, i] = (np.linalg.norm((P - HC) / HR, axis=1) - 1.0) * 0.3
        if nm[-1] in "RL":
            side = 1.0 if nm[-1] == "R" else -1.0
            D[P[:, 0] * side < 0.02, i] = 9.0
    W = np.exp(-(D - D.min(1, keepdims=True)) / 0.012)
    W /= W.sum(1, keepdims=True)
    Q = np.zeros_like(P)
    for i, (nm, j0, j1, rad, _) in enumerate(SEG):
        if nm == "hull":
            Q += W[:, i, None] * ((P - HC) * HS + (0, 0, 0.53))
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
        girth = float(J.get("girth", {}).get(nm, 1.0))
        r = P - p0
        ax = r @ u
        Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + (r - ax[:, None] * u) @ R.T * girth)
    return Q, W


def cut_mask(P):
    """What the scripted parts replace: helmet and collar, stumps, the fists past the wrist."""
    neck_r, neck_z, top_z = J["cut_neck"]
    cut = (np.hypot(P[:, 0] - HC[0], (P[:, 1] - HC[1]) * 1.1) < neck_r) & (P[:, 2] > neck_z) | (P[:, 2] > top_z)
    for sd, sx in (("R", 1.0), ("L", -1.0)):
        u = SJ["wrist." + sd] - SJ["elbow." + sd]
        cut |= (P[:, 0] * sx > 0.4) & (((P - SJ["wrist." + sd]) @ u) > 0.0)
    return cut


import bmesh
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
src, P = load(SCAN)
Q, _ = fit(P)
src.data.vertices.foreach_set("co", Q.astype(np.float32).ravel())
src.data.update()
low, PL = load(RETOPO)
QL, WL = fit(PL)
low.data.vertices.foreach_set("co", QL.astype(np.float32).ravel())
low.data.update()
print("scan", len(P), "retopo", len(PL), len(low.data.polygons), flush=True)

# ---- cut, dropping crumbs
keep_v = ~cut_mask(PL)
bm = bmesh.new()
bm.from_mesh(low.data)
bm.verts.ensure_lookup_table()
idx = bm.verts.layers.int.new("orig")
for v_ in bm.verts:
    v_[idx] = v_.index
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(~keep_v)[0].tolist()], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)      # (Meshy's verts are split along its UV islands)
seen, isl = set(), []
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
bmesh.ops.delete(bm, geom=[a_ for c in isl if len(c) < big * 0.05 for a_ in c], context="VERTS")
bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
orig = np.array([v_[idx] for v_ in bm.verts])
bm.to_mesh(low.data)
bm.free()
W_low = WL[orig]
print("low", len(low.data.polygons), flush=True)

# ---- unwrap by form, bake from the dense scan
for u in list(low.data.uv_layers):
    low.data.uv_layers.remove(u)
low.data.materials.clear()
low.data.uv_layers.new(name="UVMap")
bpy.context.view_layer.objects.active = low
low.select_set(True)
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
    kw = dict(type=kind, use_selected_to_active=True, cage_extrusion=0.04, max_ray_distance=0.12, margin=12)
    if kind == "DIFFUSE":
        kw["pass_filter"] = {"COLOR"}
    bpy.ops.object.bake(**kw)
    img.filepath_raw = os.path.join(WORK, nm + ".png")
    img.file_format = "PNG"
    img.save()
    print("baked", nm, flush=True)

me = low.data
v = np.empty(len(me.vertices) * 3, np.float32)
me.vertices.foreach_get("co", v)
lv = np.empty(len(me.loops), np.int32)
me.loops.foreach_get("vertex_index", lv)
uv = np.empty(len(me.loops) * 2, np.float32)
me.uv_layers.active.data.foreach_get("uv", uv)
names = sorted(set(s_[4] for s_ in SEG))
w_b = np.zeros((len(W_low), len(names)), np.float32)
for i, s_ in enumerate(SEG):
    w_b[:, names.index(s_[4])] += W_low[:, i]
np.savez(os.path.join(WORK, "scan_low.npz"), v=v.reshape(-1, 3), tri=lv.reshape(-1, 3), uv=uv.reshape(-1, 2), bones=np.array(names), w=w_b)
print("done", len(v) // 3, flush=True)

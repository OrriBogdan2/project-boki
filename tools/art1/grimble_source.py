"""ART-1 Grimble, fine-detail pass: the Meshy scans -> Low meshes on the rig plus their paint sources.
In WORK (~/meshy/grimble): runB (the body, hoard and gear edited out), runF (the head sheet, the monocle edited out), runH (the hoard alone).
The body moves bone by bone onto the rig (tools/art1/kael_source.py's method: length along the bone, girth across it). The head and hoard are
placed rigidly. Out: WORK/source.blend (objects Low_body, Low_head, Low_hoard, with vertex groups) and src_{B,F,H}.npz (the dense scans, placed,
for the nearest-surface paint), tex_{B,F,H}.png.
Run: blender -b --factory-startup --python tools/art1/grimble_source.py -- WORK"""
import json
import os
import subprocess
import sys

import bmesh
import bpy
import numpy as np
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import grimble_sculpt as G
from meshkit import smooth

WORK = sys.argv[sys.argv.index("--") + 1]
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
F = np.float32
BODY_TRIS, HEAD_TRIS, HOARD_TRIS = 3000, 2500, 3000
SRC_FACES = 350000
SOLE = -0.949
# the body scan's joints: flipped to face +Y, his right +X, z from the sole; measured on the grids and slices
S_J = {"pelvis": (0, -0.30, 1.00), "neck": (0, -0.17, 1.60)}
for sd, sx in (("R", 1), ("L", -1)):
    S_J.update({"shoulder." + sd: (sx * 0.33, -0.17, 1.52), "elbow." + sd: (sx * 0.615, -0.18, 1.24), "wrist." + sd: (sx * 0.82, -0.08, 0.96),
                "hip." + sd: (sx * 0.125, -0.30, 1.03), "knee." + sd: (sx * 0.215, -0.22, 0.54), "ankle." + sd: (sx * 0.235, -0.36, 0.14)})
rig = json.load(open(os.path.join(REPO, "art/wardens/src/dredge_rig.json")))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


T = {"pelvis": r_j("hips"), "neck": r_j("head")}
for sd in "RL":
    T["shoulder." + sd], T["elbow." + sd], T["wrist." + sd] = r_j("upper_arm." + sd), r_j("forearm." + sd), r_j("hand." + sd)
    T["hip." + sd], T["knee." + sd] = r_j("thigh." + sd), r_j("shin." + sd)
    T["ankle." + sd] = np.array([T["knee." + sd][0], 0, G.ANKLE])
# name, joints, reach radius (scan m), girth (scan -> rig)
SEG = [("torso", "pelvis", "neck", 0.30, 0.66)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.10, 0.60), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.09, 0.60),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.13, 0.68), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.10, 0.68)]


def load(glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    ms = [o for o in bpy.data.objects if o.type == "MESH"]
    src = max(ms, key=lambda o: len(o.data.vertices))
    for o in list(bpy.data.objects):
        if o is not src:
            bpy.data.objects.remove(o)
    src.parent = None
    me = src.data
    co = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(src.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    src.matrix_world = np.eye(4).tolist()
    P = np.stack([-co[:, 0], -co[:, 1], co[:, 2]], 1)
    me.vertices.foreach_set("co", P.ravel())
    me.update()
    return src


def verts(ob):
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimate(ob, target, keep=None):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    for _ in range(3):
        now = tris(ob)
        if now <= target * 1.08:
            break
        m = ob.modifiers.new("d", "DECIMATE")
        m.ratio = target / now
        m.use_collapse_triangulate = True
        if keep is not None:
            vg = ob.vertex_groups.new(name="keep")
            w = keep(verts(ob))
            for i in range(len(w)):
                vg.add([i], float(w[i]), "REPLACE")
            m.vertex_group = "keep"
            m.vertex_group_factor = 8.0
        bpy.ops.object.modifier_apply(modifier="d")
        if keep is not None:
            ob.vertex_groups.clear()
    print(ob.name, "->", tris(ob), flush=True)


def dup(ob, name):
    """A copy for decimating, welded: Meshy splits its vertices along the UV seams, and a decimate of that comes apart in shards."""
    o = ob.copy()
    o.data = ob.data.copy()
    o.name = o.data.name = name
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return o


def save_src(ob, tag):
    """The dense scan as arrays (triangles, their UVs), and its base colour at a size the painter can hold."""
    decimate(ob, SRC_FACES)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    me = ob.data
    v = verts(ob).astype(F)
    lv = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", lv)
    uv = np.empty(len(me.loops) * 2, F)
    me.uv_layers.active.data.foreach_get("uv", uv)
    np.savez(os.path.join(WORK, "src_%s.npz" % tag), v=v, f=lv.reshape(-1, 3), uv=uv.reshape(-1, 3, 2))
    t = os.path.join(WORK, "tex_%s.png" % tag)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(WORK, "run" + tag, "tex0_base_color.png"), "-vf", "scale=3072:3072", "-update", "1", t], check=True)
    print("src", tag, len(v), flush=True)


def rot_between(u, v):
    u, v = u / np.linalg.norm(u), v / np.linalg.norm(v)
    c = np.cross(u, v)
    s, d = np.linalg.norm(c), u @ v
    if s < 1e-7:
        return np.eye(3)
    k = np.array([[0, -c[2], c[1]], [c[2], 0, -c[0]], [-c[1], c[0], 0]]) / s
    return np.eye(3) + k * s + k @ k * (1 - d)


def seg_weights(P):
    n = len(P)
    D = np.zeros((n, len(SEG)))
    for i, (nm, j0, j1, rad, _) in enumerate(SEG):
        a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
        u = a1 - a0
        h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
        d = np.linalg.norm(P - (a0 + h[:, None] * u), axis=1)
        if nm == "torso":
            d = np.linalg.norm((P - (a0 + h[:, None] * u)) * [0.75, 1.0, 1.0], axis=1)
        D[:, i] = d - rad
        if nm.endswith(".R"):
            D[P[:, 0] < -0.02, i] = 9.0
        if nm.endswith(".L"):
            D[P[:, 0] > 0.02, i] = 9.0
        if nm.startswith(("thigh", "shin")):
            D[P[:, 2] > 1.12, i] = 9.0
    W = np.exp(-(D - D.min(1, keepdims=True)) / 0.03)
    return W / W.sum(1, keepdims=True)


def fit(P, W):
    Q = np.zeros_like(P)
    for i, (nm, j0, j1, rad, girth) in enumerate(SEG):
        p0, p1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
        q0, q1 = T[j0], T[j1]
        ln = np.linalg.norm(p1 - p0)
        u = (p1 - p0) / ln
        v = (q1 - q0) / np.linalg.norm(q1 - q0)
        R = rot_between(u, v)
        sa = np.linalg.norm(q1 - q0) / ln
        r = P - p0
        ax = r @ u
        Q += W[:, i, None] * (q0 + ax[:, None] * sa * v + ((r - ax[:, None] * u) * girth) @ R.T)
    return Q


def set_groups(ob, W):
    names = list(W)
    a = np.stack([W[k] for k in names], 1)
    idx = np.argsort(-a, axis=1)[:, :4]
    top = np.take_along_axis(a, idx, 1)
    top[top < top[:, :1] * 0.05] = 0
    top /= np.maximum(top.sum(1, keepdims=True), 1e-6)
    for i, nm in enumerate(names):
        vg = ob.vertex_groups.new(name=nm)
        r = np.nonzero((idx == i) & (top > 0))
        for v, c in zip(r[0].tolist(), r[1].tolist()):
            vg.add([v], float(top[v, c]), "REPLACE")


def body():
    ob = load(os.path.join(WORK, "runB", "glb.glb"))
    P = verts(ob) + (0, 0, -SOLE)
    W0 = seg_weights(P)
    Q = fit(P, W0)
    low = dup(ob, "Low_body")
    P = verts(low) + (0, 0, -SOLE)
    # the cuts: past the wrists (gauntlet and hook are rebuilt), and the head-and-hump lump (the head scan sits there)
    bm = bmesh.new()
    bm.from_mesh(low.data)
    bm.verts.ensure_lookup_table()
    kill = []
    for sd, sx in (("R", 1.0), ("L", -1.0)):
        je, jw = np.array(S_J["elbow." + sd]), np.array(S_J["wrist." + sd])
        u = jw - je
        h = ((P - je) @ u) / (u @ u)
        kill.append((h > 0.97) & (P[:, 0] * sx > 0.45))
    kill.append(P[:, 2] > 1.60 + 0.42 * np.abs(P[:, 0]))
    kill.append((P[:, 2] > 1.34) & (P[:, 1] > 0.10) & (np.abs(P[:, 0]) < 0.36))      # (the scan's own face and muzzle, on the front of the lump)
    gone = np.any(kill, axis=0)
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(gone)[0].tolist()], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(low.data)
    bm.free()
    cl0, p0 = cloth_mask(low, "B"), verts(low)
    decimate(low, BODY_TRIS)
    Pl = verts(low) + (0, 0, -SOLE)
    W = seg_weights(Pl)
    set_verts(low, fit(Pl, W))
    names = [s[0] for s in SEG]
    gr = {nm: W[:, i].copy() for i, nm in enumerate(names) if nm != "torso"}
    tw = W[:, 0]
    k = smooth(1.08, 1.26, Pl[:, 2])
    gr["root"], gr["hips"] = tw * (1 - k) + 1e-5, tw * k
    for sd in "RL":
        f = smooth(0.24, 0.16, Pl[:, 2])
        gr["foot." + sd] = gr["shin." + sd] * f
        gr["shin." + sd] = gr["shin." + sd] * (1 - f)
    # the hide and the belt ride the hips: the loincloth is found by its colour
    kd = KDTree(len(p0))
    for i, q in enumerate(p0.tolist()):
        kd.insert(q, i)
    kd.balance()
    cl = np.array([cl0[kd.find(q)[1]] for q in (Pl - (0, 0, -SOLE)).tolist()], F)
    for nm in list(gr):
        gr[nm] = gr[nm] * (1 - cl)
    zk = smooth(0.98, 0.84, Pl[:, 2])
    gr["skirt"] = cl * zk + 1e-6
    gr["root"] = gr["root"] + cl * (1 - zk)
    set_groups(low, gr)
    print("cloth verts", int((cl > 0.5).sum()), flush=True)
    # (the paint source loses the scan's face too, or the cap under the head paints itself with teeth)
    Pa = verts(ob) + (0, 0, -SOLE)
    set_verts(ob, Q)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    away = (Pa[:, 2] > 1.60 + 0.42 * np.abs(Pa[:, 0])) | ((Pa[:, 2] > 1.34) & (Pa[:, 1] > 0.10) & (np.abs(Pa[:, 0]) < 0.36))
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(away)[0].tolist()], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    save_src(ob, "B")
    return low


def set_verts(ob, v):
    ob.data.vertices.foreach_set("co", np.asarray(v, F).ravel())
    ob.data.update()


def cloth_mask(ob, tag):
    """Olive hide against grey skin, from the scan's paint under each vertex."""
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(WORK, "run" + tag, "tex0_base_color.png"), "-vf", "scale=512:512", "-f", "rawvideo", "-pix_fmt", "rgb24",
                    os.path.join(WORK, "t512.rgb")], check=True)
    t = np.fromfile(os.path.join(WORK, "t512.rgb"), np.uint8).reshape(512, 512, 3).astype(F) / 255
    me = ob.data
    lv = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", lv)
    uv = np.empty(len(me.loops) * 2, F)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    px = np.clip((uv[:, 0] * 511).astype(int), 0, 511)
    py = np.clip(((1 - uv[:, 1]) * 511).astype(int), 0, 511)
    c = t[py, px]
    vc = np.zeros((len(me.vertices), 3), F)
    vc[lv] = c
    return ((vc[:, 1] - vc[:, 2]) > 0.05).astype(F)


# the head: the scan's own numbers, flipped
H_EYE = np.array((0.227, 0.55, 0.30))        # the hollow, on the scan
H_K = 0.190


def head_xf(p):
    return (np.asarray(p) - H_EYE) * H_K + (G.EYE_C[0], G.EYE_C[1] + 0.012, G.EYE_C[2])


def head():
    ob = load(os.path.join(WORK, "runF", "glb.glb"))
    low = dup(ob, "Low_head")
    S0 = verts(low)
    bm = bmesh.new()
    bm.from_mesh(low.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(S0[:, 2] < -0.66)[0].tolist()], context="VERTS")
    bm.to_mesh(low.data)
    bm.free()

    def face(p):
        return np.clip(0.12 + 1.0 * smooth(0.0, 0.35, p[:, 1]) * smooth(-0.40, -0.25, p[:, 2]) * smooth(0.62, 0.48, p[:, 2]), 0.02, 1)
    decimate(low, HEAD_TRIS, face)
    S = verts(low)
    jw = smooth(-0.075, -0.125, S[:, 2]) * smooth(0.0, 0.14, S[:, 1]) * smooth(-0.46, -0.36, S[:, 2])
    br = np.exp(-(np.linalg.norm((S - (0.24, 0.52, 0.48)) * (0.7, 1, 1.2), axis=1) / 0.17) ** 2)
    # (neck and collar ride the head: the head hangs far ahead of the chest, and a neck tied to the chest stretched to his belt in the hunch)
    set_groups(low, {"head": (1 - jw) * (1 - br) + 1e-4, "jaw": jw, "brow": br * (1 - jw)})
    set_verts(low, head_xf(S))
    set_verts(ob, head_xf(verts(ob)))
    save_src(ob, "F")
    return low


def hoard():
    ob = load(os.path.join(WORK, "runH", "glb.glb"))
    S = verts(ob)
    k = np.array((0.50, 0.46, 0.555))

    def xf(p):
        return p * k + (0.0, -0.40, 1.245)
    set_verts(ob, xf(S))
    low = dup(ob, "Low_hoard")
    # (a pile of thin chain and loose bits stalls the decimator near 10k: a voxel remesh first; the paint comes from the scan anyway)
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    m = low.modifiers.new("r", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = 0.009
    bpy.ops.object.modifier_apply(modifier="r")
    print("remeshed", tris(low), flush=True)
    decimate(low, HOARD_TRIS)
    set_groups(low, {"hoard": np.ones(len(low.data.vertices), F)})
    save_src(ob, "H")
    return low


def main():
    os.makedirs(WORK, exist_ok=True)
    out = []
    only = os.environ.get("ONLY", "").split(",") if os.environ.get("ONLY") else []
    for fn, nm in ((hoard, "hoard"), (head, "head"), (body, "body")):
        if only and nm not in only:
            continue
        fn()
        p = os.path.join(WORK, "low_%s.blend" % nm)
        for o in list(bpy.data.objects):
            if not o.name.startswith("Low_"):
                bpy.data.objects.remove(o)
        bpy.ops.wm.save_as_mainfile(filepath=p)
        out.append(p)
    print("source done", out, flush=True)


main()

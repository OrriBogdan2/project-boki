"""ART-1 Grimble v2 (the owner's locked redesign, briefs/art-refs/grimble_v2/): the Meshy scan -> the Low mesh on the rig plus its paint source.
In WORK (~/meshy/grimble_v2): runA, one scan of the FINAL turnaround's front, left and back views with the hoard, the blunderbuss, the
loupe and the sludge edited out (edit.sh). The scan keeps its own head, the bone-hook right arm and the gauntlet. It moves bone by bone
onto the rig (kael_source.py's method: a length along the bone, a girth across it); past a bone's ends the scan keeps its own scale, so
the hook and the gauntlet keep their shape. The hunch stays: the neck and the head keep the scan's lean ahead of the hips.
Out: WORK/low_body.blend (object Low_body, with vertex groups), src_A.npz (the dense scan, placed, for the nearest-surface paint), tex_A.png.
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
from meshkit import smooth

WORK = sys.argv[sys.argv.index("--") + 1]
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
F = np.float32
BODY_TRIS = 7800
SRC_FACES = 350000
SOLE = -0.950
# the scan's joints: flipped to face +Y, his right +X, z from the sole; measured on the grids (~/meshy/tools/grid.py)
S_J = {"pelvis": (-0.035, -0.20, 0.77), "neck": (-0.03, 0.12, 1.45), "crown": (-0.03, 0.30, 1.77), "face": (-0.03, 0.40, 1.55),
       "shoulder.R": (0.29, -0.06, 1.48), "elbow.R": (0.46, -0.14, 1.05), "wrist.R": (0.50, -0.10, 0.67),
       "shoulder.L": (-0.32, -0.06, 1.48), "elbow.L": (-0.47, -0.05, 1.09), "wrist.L": (-0.58, 0.08, 0.83),
       "hip.R": (0.10, -0.20, 0.79), "knee.R": (0.13, -0.20, 0.41), "ankle.R": (0.20, -0.20, 0.08),
       "hip.L": (-0.17, -0.20, 0.79), "knee.L": (-0.20, -0.20, 0.41), "ankle.L": (-0.29, -0.20, 0.08)}
LOIN_X, LOIN_Z = 0.28, (0.55, 1.15)
LEG_R = (0.095, 0.075)                  # the right thigh's and shin's core (scan m): the hook's crescent passes just outside        # the loincloth's box on the scan: the colour test only counts in here
rig = json.load(open(os.path.join(REPO, "art/wardens/src/dredge_rig.json")))["bones"]


def r_j(b):
    x, y, z = rig[b]["head"]
    return np.array([x, -z, y], float)


# the scan's scale: the legs land on the rig's. The limbs keep the scan's spread and lean (x, y) and take the rig's joint heights:
# moved onto the rig's narrow arms and wide hips, the hook arm hung through his right leg.
K = r_j("hips")[2] / S_J["pelvis"][2]


def on_rig(j, z):
    return (np.array(S_J[j]) - (S_J["pelvis"][0], S_J["pelvis"][1], 0)) * (K, K, 0) + (0, 0, z)


T = {"pelvis": r_j("hips"), "neck": on_rig("neck", r_j("head")[2])}
T["crown"] = T["neck"] + (np.array(S_J["crown"]) - S_J["neck"]) * K
for sd in "RL":
    for j, b in (("shoulder", "upper_arm"), ("elbow", "forearm"), ("wrist", "hand"), ("hip", "thigh"), ("knee", "shin")):
        T[j + "." + sd] = on_rig(j + "." + sd, r_j(b + "." + sd)[2])
    T["ankle." + sd] = on_rig("ankle." + sd, S_J["ankle." + sd][2] * K)
# name, joints, reach radius (scan m), girth (x the scan's scale)
SEG = [("torso", "pelvis", "neck", 0.30, 1.0), ("headseg", "neck", "crown", 0.12, 1.0)]
for sd in "RL":
    SEG += [("upper_arm." + sd, "shoulder." + sd, "elbow." + sd, 0.10, 1.0), ("forearm." + sd, "elbow." + sd, "wrist." + sd, 0.09, 1.0),
            ("thigh." + sd, "hip." + sd, "knee." + sd, 0.13, 1.0), ("shin." + sd, "knee." + sd, "ankle." + sd, 0.10, 1.0)]


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
            D[P[:, 2] > S_J["pelvis"][2] + 0.12, i] = 9.0
        if nm == "headseg":
            D[P[:, 2] < S_J["neck"][2] - 0.04, i] = 9.0
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
        inside = np.clip(ax, 0, ln)
        ax2 = inside * sa + (ax - inside) * K          # (past the ends: the scan's own scale, the hook keeps its shape)
        Q += W[:, i, None] * (q0 + ax2[:, None] * v + ((r - ax[:, None] * u) * girth * K) @ R.T)
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
    ob = load(os.path.join(WORK, "runA", "glb.glb"))
    P = verts(ob) + (0, 0, -SOLE)
    Q = fit(P, hook_weights(P))
    low = dup(ob, "Low_body")
    cl0 = cloth_mask(low, "A")
    p0 = verts(low)
    decimate(low, BODY_TRIS, face_keep)
    Pl = verts(low) + (0, 0, -SOLE)
    kd = KDTree(len(p0))
    for i, q in enumerate(p0.tolist()):
        kd.insert(q, i)
    kd.balance()
    W = hook_weights(Pl)
    set_verts(low, fit(Pl, W))
    gr = {nm: W[:, i].copy() for i, (nm, *_) in enumerate(SEG) if nm not in ("torso", "headseg")}
    tw = W[:, 0]
    k = smooth(0.85, 1.03, Pl[:, 2])
    gr["root"], gr["hips"], gr["head"] = tw * (1 - k) + 1e-5, tw * k, W[:, 1]
    # past the wrists: the bone hook rides `hook`, the gauntlet hand.L
    for sd, bone in (("R", "hook"), ("L", "hand.L")):
        gr[bone] = gr["forearm." + sd] * smooth(0.92, 1.04, along(Pl, "elbow." + sd, "wrist." + sd))
        gr["forearm." + sd] -= gr[bone]
    for sd in "RL":
        f = smooth(0.15, 0.07, Pl[:, 2])
        gr["foot." + sd] = gr["shin." + sd] * f
        gr["shin." + sd] = gr["shin." + sd] * (1 - f)
    # the hide and the belt ride the hips: the loincloth is found by its colour
    cl = np.array([cl0[kd.find(q)[1]] for q in (Pl - (0, 0, -SOLE)).tolist()], F)
    cl *= (np.abs(Pl[:, 0] - S_J["pelvis"][0]) < LOIN_X) * (Pl[:, 2] > LOIN_Z[0]) * (Pl[:, 2] < LOIN_Z[1])      # (the bone hook is tan too)
    for nm in list(gr):
        gr[nm] = gr[nm] * (1 - cl)
    zk = smooth(1.0, 0.88, Pl[:, 2])
    gr["skirt"] = cl * zk + 1e-6
    gr["root"] = gr["root"] + cl * (1 - zk)
    set_groups(low, gr)
    print("cloth verts", int((cl > 0.5).sum()), "hook verts", int((gr["hook"] > 0.5).sum()), flush=True)
    set_verts(ob, Q)
    save_src(ob, "A")
    return low


def seg_dist(P, j0, j1):
    a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    u = a1 - a0
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    return np.linalg.norm(P - (a0 + h[:, None] * u), axis=1)


def hook_weights(P):
    """seg_weights, but the hook's crescent, which curls in by his right leg and foot, is all the arm's: below the right wrist,
    whatever is not the leg's core (a capsule round the thigh and shin, a box round the foot) or the loincloth."""
    W = seg_weights(P)
    a = np.array(S_J["ankle.R"])
    leg = (seg_dist(P, "hip.R", "knee.R") < LEG_R[0]) | (seg_dist(P, "knee.R", "ankle.R") < LEG_R[1])
    leg |= (P[:, 2] < a[2] + 0.06) & (np.abs(P[:, 0] - a[0]) < 0.075) & (P[:, 1] > a[1] - 0.09) & (P[:, 1] < a[1] + 0.26)
    loin = (P[:, 2] > LOIN_Z[0]) & (P[:, 0] < S_J["hip.R"][0] + 0.12)
    hk = (P[:, 0] > 0.0) & (P[:, 2] < S_J["wrist.R"][2]) & ~leg & ~loin
    names = [s[0] for s in SEG]
    W[hk] = np.eye(len(SEG))[names.index("forearm.R")]
    # the head hangs far ahead of the neck (the hunch): all of it, ears and jaw, rides the head
    hw = smooth(S_J["neck"][1] - 0.02, S_J["neck"][1] + 0.08, P[:, 1]) * smooth(S_J["neck"][2] - 0.14, S_J["neck"][2] - 0.05, P[:, 2])
    return W * (1 - hw[:, None]) + np.eye(len(SEG))[1] * hw[:, None]


def along(P, j0, j1):
    a0, a1 = np.array(S_J[j0], float), np.array(S_J[j1], float)
    u = a1 - a0
    return ((P - a0) @ u) / (u @ u)


def face_keep(v):
    """The decimator spares the face (the grin, the squint and the ears read at the close camera)."""
    p = v + (0, 0, -SOLE)
    return np.clip(0.1 + np.exp(-(np.linalg.norm(p - S_J["face"], axis=1) / 0.16) ** 2), 0.02, 1)


def set_verts(ob, v):
    ob.data.vertices.foreach_set("co", np.asarray(v, F).ravel())
    ob.data.update()


def cloth_mask(ob, tag):
    """The brown hide against grey-mauve skin, from the scan's paint under each vertex."""
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
    r, g, b = vc[:, 0], vc[:, 1], vc[:, 2]
    return ((r - b > 0.07) & (g - b > -0.02)).astype(F)


def main():
    os.makedirs(WORK, exist_ok=True)
    out = []
    for fn, nm in ((body, "body"),):
        fn()
        p = os.path.join(WORK, "low_%s.blend" % nm)
        for o in list(bpy.data.objects):
            if not o.name.startswith("Low_"):
                bpy.data.objects.remove(o)
        bpy.ops.wm.save_as_mainfile(filepath=p)
        out.append(p)
    print("source done", out, flush=True)


main()

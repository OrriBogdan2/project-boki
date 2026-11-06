"""Tarek's ART-1 model: builds every part from its field (tools/art1/tarek_shape.py) on the contract armature.
    blender -b --factory-startup --python tools/art1/tarek_build.py -- <rig.json> <out dir> [clay|low|full] [parts,...]
clay: dense meshes and a grey turnaround, to judge the forms. Outputs in <out dir>; `full` also writes tarek.blend.
"""
import json
import math
import os
import subprocess
import sys
import time

import bmesh
import bpy
import mathutils
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "blender"))
import sdf_kit as S  # noqa: E402
import tarek_shape as T  # noqa: E402
import warden_kit as K  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:]
RIG_PATH, OUT = ARGS[0], ARGS[1]
MODE = ARGS[2] if len(ARGS) > 2 else "clay"
ONLY = ARGS[3].split(",") if len(ARGS) > 3 and MODE != "scan" else None
os.makedirs(OUT, exist_ok=True)
RIG = K.load_rig(RIG_PATH)
R = T.Rig(RIG["bones"])
HC = R.hc


def log(*a):
    print("TAREK", *a, flush=True)


# ---------------------------------------------------------------------------------------------------- the parts
def head_f(P):
    return T.head_base(P - HC)


def teeth_f(P):
    return T.teeth(P - HC)


def bandana_f(P):
    q = P - HC
    return S.smin(T.bandana(q), T.bandana_knot(q), 0.006)


def cap_f(P):
    return T.hair_cap(P - HC)


SEEDS_A = T.stone_seeds(R)
SEEDS_G = T.gauntlet_seeds(R)
_rs = np.random.RandomState(41)
H_A = np.asarray(_rs.uniform(0.018, 0.05, SEEDS_A.shape[0]), np.float32)
H_G = np.asarray(_rs.uniform(0.02, 0.055, SEEDS_G.shape[0]), np.float32)


def mx(P):
    """His left side in the right-side frame the stone arm is built in."""
    return P * S.vec(-1, 1, 1)


REF = os.environ.get("TAREK_REF", os.path.expanduser("~/shots-s2/art1/tarek/ref2"))     # the master sheets (briefs/art-refs)
FACE_PX = 1300.0               # sheet px per model m on the front view of tarek_head
FACE_CX = 362.0               # the inset's nose line, sheet px
FACE_MOUTH_Y = 803.0           # the mouth line, sheet px
X = float(R.sh[0])
GEO_R = 0.1
Z_S = float(R.sh[2])

# name: field, bounds (lo, hi), low step, target tris, clay colour, slot
SEEDS_F = T.fist_seeds(R)
H_F = np.asarray(_rs.uniform(0.012, 0.03, SEEDS_F.shape[0]), np.float32)
PARTS = {
    "fist_L": dict(f=lambda P: T.stone_arm(mx(P), R, SEEDS_F, H_F, lambda Q, r: T.fist(Q - r.wr, 1.42)), lo=S.vec(-0.56, -0.2, R.wr[2] - 0.32), hi=S.vec(-0.04, 0.2, R.wr[2] + 0.08), h=0.004, tris=520, col="8c90a0"),
    "fist_R": dict(f=lambda P: T.stone_arm(P, R, SEEDS_F, H_F, lambda Q, r: T.fist(Q - r.wr, 1.2)), lo=S.vec(0.06, -0.16, R.wr[2] - 0.27), hi=S.vec(0.52, 0.16, R.wr[2] + 0.08), h=0.004, tris=420, col="8c90a0"),
    "head": dict(f=head_f, lo=HC + S.vec(-0.14, -0.17, -0.3), hi=HC + S.vec(0.14, 0.17, 0.17), h=0.0032, tris=1800, col="8a5a3c"),
    "bandana": dict(f=bandana_f, lo=HC + S.vec(-0.14, -0.19, -0.06), hi=HC + S.vec(0.14, 0.17, 0.14), h=0.0035, tris=450, col="c9b89a"),
    "cap": dict(f=cap_f, lo=HC + S.vec(-0.16, -0.19, -0.14), hi=HC + S.vec(0.16, 0.17, 0.2), h=0.0075, tris=560, col="1c1618"),
    "torso": dict(f=lambda P: T.torso(P, R), lo=S.vec(-0.33, -0.2, R.waist[2] - 0.03), hi=S.vec(0.33, 0.2, R.neck[2] + 0.03), h=0.005, tris=850, col="8a5a3c"),
    "arms": dict(f=lambda P: T.arm(P, R), lo=S.vec(0.14, -0.13, R.wr[2]), hi=S.vec(0.43, 0.13, Z_S + 0.11), h=0.005, tris=400, col="8a5a3c"),
    "hands": dict(f=lambda P: T.fist(P - R.wr, 1.36), lo=S.vec(0.06, -0.16, R.wr[2] - 0.27), hi=S.vec(0.48, 0.16, R.wr[2] + 0.05), h=0.0034, tris=430, col="8a5a3c"),
    "stone": dict(f=lambda P: T.stone_arm(mx(P), R, SEEDS_A, H_A), lo=S.vec(-0.6, -0.27, R.wr[2] - 0.3), hi=S.vec(-0.02, 0.26, Z_S + 0.24), h=0.0065, tris=1950, col="8c90a0"),
    "gauntlet": dict(f=lambda P: T.stone_arm(P, R, SEEDS_G, H_G, T.gauntlet_core), lo=S.vec(0.08, -0.16, R.wr[2] - 0.02), hi=S.vec(0.46, 0.16, R.el[2] + 0.02), h=0.0058, tris=760, col="8c90a0"),
    "wrap": dict(f=lambda P: T.wrap_band(P, R), lo=S.vec(-0.22, -0.17, R.waist[2] + 0.04), hi=S.vec(0.22, 0.17, R.waist[2] + 0.2), h=0.006, tris=140, col="d8cfba"),
    "sash": dict(f=lambda P: T.sash(P, R), lo=S.vec(-0.27, -0.2, R.waist[2] - 0.06), hi=S.vec(0.27, 0.25, R.waist[2] + 0.18), h=0.0045, tris=380, col="b04a26"),
    "skirt": dict(f=lambda P: T.skirt(P, R), lo=S.vec(-0.33, -0.27, R.waist[2] - 0.46), hi=S.vec(0.33, 0.27, R.waist[2] + 0.1), h=0.0055, tris=560, col="b04a26"),
    "trousers": dict(f=lambda P: T.trousers(P, R), lo=S.vec(-0.31, -0.18, 0.35), hi=S.vec(0.31, 0.18, R.hip[2] + 0.12), h=0.006, tris=880, col="4a3c34"),
    "legs": dict(f=lambda P: T.shin_foot(P, R), lo=S.vec(-0.26, -0.14, -0.01), hi=S.vec(0.26, 0.26, 0.5), h=0.0045, tris=480, col="8a5a3c"),
    "wraps": dict(f=lambda P: T.foot_wraps(P, R), lo=S.vec(-0.26, -0.14, -0.01), hi=S.vec(0.26, 0.26, 0.44), h=0.004, tris=340, col="8a7258"),
}


# ------------------------------------------------------------------------------------------------- mesh helpers
def mesh_from(name, V, Q):
    me = bpy.data.meshes.new(name)
    n = Q.shape[0]
    me.vertices.add(V.shape[0])
    me.vertices.foreach_set("co", V.astype(np.float32).ravel())
    me.loops.add(n * 4)
    me.loops.foreach_set("vertex_index", Q.astype(np.int32).ravel())
    me.polygons.add(n)
    me.polygons.foreach_set("loop_start", np.arange(n, dtype=np.int32) * 4)
    me.update(calc_edges=True)
    me.validate()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def part_mesh(name, p, h_k=1.0):
    t0 = time.time()
    G, lo = S.field_grid(lambda X_: S.chunked(p["f"], X_), p["lo"], p["hi"], p["h"] * h_k)
    V, Q = S.surface_nets(G, lo, p["h"] * h_k)
    V = S.relax(lambda X_: S.chunked(p["f"], X_), V, 1)
    ob = mesh_from(name, V, Q)
    log("%s: %d verts, %d quads, %.1f s" % (name, V.shape[0], Q.shape[0], time.time() - t0))
    return ob


def col_mat(hexs):
    m = bpy.data.materials.new("c" + hexs)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*[c ** 2.2 for c in S.hexc(hexs)], 1)
    b.inputs["Roughness"].default_value = 0.6
    return m


def turnaround(objs, path, zoom=None, res=(1600, 800), mid=None, views=(0, 40, 90, 180), samples=12):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.render.resolution_x, sc.render.resolution_y = res[0] // len(views), res[1]
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.62, 0.66, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.data.angle = 0.3
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    top = float(R.hc[2] + 0.34)
    c = Vector(mid) if mid else Vector((0, 0, top / 2))
    cam.data.ortho_scale = zoom or (top * 1.04)
    shots = []
    for i, a in enumerate(views):
        r = math.radians(a)
        d = Vector((math.sin(r), math.cos(r), 0.08))
        cam.location = c + d * 5
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sun.rotation_euler = (Vector((0.45, 0.5, 0.75)) * -1).rotated(__import__("mathutils").Euler((0, 0, -r))).to_track_quat("-Z", "Y").to_euler() if False else (-(Matrix.Rotation(r, 3, "Z") @ Vector((-0.5, 0.65, 0.8)))).to_track_quat("-Z", "Y").to_euler()
        f = "%s_%d.png" % (path, i)
        sc.render.filepath = f
        bpy.ops.render.render(write_still=True)
        shots.append(f)
    return shots


# ------------------------------------------------------------------------------------------------ swept pieces
class Bag:
    """Vertices, faces, uvs (per corner) and per-vertex paint attributes of a swept part."""

    def __init__(self, name):
        self.name, self.v, self.f, self.uv, self.a = name, [], [], [], []

    def ob(self):
        V = np.array(self.v, np.float32)
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(V.tolist(), [], self.f)
        me.update()
        lay = me.uv_layers.new(name="UVMap")
        for pl, uvs in zip(me.polygons, self.uv):
            for li, uv in zip(pl.loop_indices, uvs):
                lay.data[li].uv = uv
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob["swept"] = 1
        ATTR[self.name] = np.array(self.a, np.float32)
        return ob


ATTR = {}


def sweep(b, path, rads, sides, attr, wobble=0.0, flat=None, ofs=(0.0, 0.0)):
    """A closed tube along path; each ring's u wraps once, the v runs in metres. attr(i, k) -> per-vertex attributes."""
    t, Nn, B = T.frames(path)
    n0 = len(b.v)
    L = 0.0
    n = len(path)
    vs = []
    for i in range(n):
        if i:
            L += float(np.linalg.norm(path[i] - path[i - 1]))
        vs.append(L)
        for k in range(sides):
            a = 2 * math.pi * k / sides + i * 0.55
            wr = rads[i] * (1.0 + wobble * math.sin(i * 1.9 + k * 2.1))
            ax, ay = (wr, wr) if flat is None else (flat[i][0], flat[i][1])
            b.v.append(tuple(path[i] + Nn[i] * math.cos(a) * ax + B[i] * math.sin(a) * ay))
            b.a.append(attr(i, k))
    perim = 2 * math.pi * float(np.mean(rads)) if flat is None else 2 * float(flat[len(flat) // 2][0]) * 2
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            a, c = n0 + i * sides + k, n0 + i * sides + k2
            d, e = n0 + (i + 1) * sides + k, n0 + (i + 1) * sides + k2
            b.f.append((a, c, e, d))
            u0, u1 = k / sides * perim + ofs[0], (k + 1) / sides * perim + ofs[0]
            b.uv.append(((u0, vs[i] + ofs[1]), (u1, vs[i] + ofs[1]), (u1, vs[i + 1] + ofs[1]), (u0, vs[i + 1] + ofs[1])))
    # the tip's cap
    last = n0 + (n - 1) * sides
    b.f.append(tuple(last + k for k in range(sides)))
    b.uv.append(tuple((ofs[0] + perim * (0.5 + 0.03 * math.cos(2 * math.pi * k / sides) * 3), ofs[1] + L + perim * 0.2 + 0.03 * perim * math.sin(2 * math.pi * k / sides) * 3) for k in range(sides)))


CHAIN_NAMES = list(T.CHAINS)


def lowball(b, c, r, attr, ofs):
    """A small bead: 6 sides, 3 rows, about 24 tris."""
    n0 = len(b.v)
    rows = ((0.0, 0.0, 1.0), (0.87, 0.0, 0.5), (0.87, 0.0, -0.5), (0.0, 0.0, -1.0))
    b.v.append(tuple(c + np.array((0, 0, r), np.float32)))
    b.a.append(attr)
    for rr, _, z in rows[1:3]:
        for k in range(6):
            a = 2 * math.pi * (k + 0.5 * (z < 0)) / 6
            b.v.append(tuple(c + np.array((math.cos(a) * rr * r, math.sin(a) * rr * r, z * r), np.float32)))
            b.a.append(attr)
    b.v.append(tuple(c + np.array((0, 0, -r), np.float32)))
    b.a.append(attr)
    uv = lambda k, v: (ofs[0] + 0.02 * k, ofs[1] + 0.02 * v)
    for k in range(6):
        k2 = (k + 1) % 6
        b.f.append((n0, n0 + 1 + k, n0 + 1 + k2))
        b.uv.append((uv(k + 0.5, 3), uv(k, 2), uv(k + 1, 2)))
        b.f.append((n0 + 1 + k, n0 + 7 + k, n0 + 7 + k2, n0 + 1 + k2))
        b.uv.append((uv(k, 2), uv(k, 1), uv(k + 1, 1), uv(k + 1, 2)))
        b.f.append((n0 + 13, n0 + 7 + k2, n0 + 7 + k))
        b.uv.append((uv(k + 0.5, 0), uv(k + 1, 1), uv(k, 1)))


def along(pts, step):
    """Points every `step` m along a smooth path."""
    p = T.smooth_path(np.array(pts, np.float32), 80)
    d = np.concatenate(([0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))))
    return [p[int(np.searchsorted(d, x))] for x in np.arange(0.0, d[-1], step)]


def prayer_bag():
    """His prayer beads: a long loop slung from the neck across the chest to the far hip, a strand down over the sash."""
    b = Bag("prayer")
    z0 = float(R.waist[2])
    nz = float(R.neck[2])
    # (from the right of his neck down across the stone's chest to his left hip, and back up)
    front = [(0.075, 0.075, nz - 0.03), (0.03, 0.135, nz - 0.2), (-0.05, 0.158, nz - 0.36), (-0.12, 0.158, z0 + 0.25), (-0.2, 0.1, z0 + 0.16), (-0.215, 0.0, z0 + 0.15)]
    back = [(-0.215, 0.0, z0 + 0.15), (-0.16, -0.135, z0 + 0.2), (-0.04, -0.15, z0 + 0.4), (0.05, -0.12, nz - 0.1), (0.075, 0.075, nz - 0.03)]
    i = 0
    for c in along(front, 0.074) + along(back, 0.085):
        lowball(b, c, 0.03, (0.0, 0.0, 12.0, float(i % 5 == 4)), (0.13 * (i % 7), 4.0 + 0.1 * (i // 7)))
        i += 1
    strand = [(0.03, 0.2, z0 + 0.03), (0.11, 0.215, z0 - 0.09), (0.2, 0.21, z0 - 0.19), (0.27, 0.16, z0 - 0.27)]
    d = 0.0
    for c in along(strand, 0.066):
        lowball(b, c, 0.027, (d, 0.0, 11.0, float(i % 5 == 4)), (0.13 * (i % 7), 4.0 + 0.1 * (i // 7)))
        i += 1
        d += 0.066
    return [b]


def locs_bag():
    b = Bag("locs")
    jw = Bag("beads")
    for li, (ch, rad, pts) in enumerate(T.LOCS):
        P = np.array(pts, np.float32) + HC
        L = float(np.linalg.norm(np.diff(P, axis=0), axis=1).sum())
        n = max(6, int(L / 0.07) + 1)
        path = T.smooth_path(P, n)
        s = np.linspace(0, 1, n)
        rr = [rad * 1.14 * (0.82 + 0.28 * min(1.0, x * 6)) * (1.0 - 0.28 * x ** 3) if x < 0.97 else rad * 0.64 for x in s]
        ci = CHAIN_NAMES.index(ch)
        d = np.concatenate(([0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))))
        sweep(b, path, rr, 6, lambda i, k: (d[i], k / 6.0, ci, li), wobble=0.08, ofs=(li * 0.25, 0.0))
    for gi, (li, at, kind) in enumerate(T.BEADS):
        ch, rad, pts = T.LOCS[li]
        P = np.array(pts, np.float32) + HC
        path = T.smooth_path(P, 40)
        i = int(at * 39)
        i = min(max(i, 1), 38)
        tan = path[i + 1] - path[i - 1]
        tan /= np.linalg.norm(tan)
        ci = CHAIN_NAMES.index(ch)
        d = float(np.linalg.norm(np.diff(path[:i + 1], axis=0), axis=1).sum())
        c = path[i]
        R0 = rad * 1.14
        if kind in ("copper", "steel", "stone", "geode"):
            ln = {"copper": 0.021, "steel": 0.019, "stone": 0.022, "geode": 0.03}[kind]
            fat = {"copper": 1.32, "steel": 1.3, "stone": 1.34, "geode": 1.65}[kind]
            r0 = R0 * fat
            seg = np.array((c - tan * ln, c, c + tan * ln), np.float32)
            kid = {"copper": 0.0, "steel": 1.0, "stone": 2.0, "geode": 3.0}[kind]
            sweep(jw, seg[:3], [r0 * 0.9, r0, r0 * 0.9], 6, lambda i_, k: (d, k / 6.0, ci, kid), ofs=(gi * 0.2, 2.0))
            # (the near end's cap)
            n0 = len(jw.v) - 7 * 4
    return [b, jw]


SASH_TAILS = {"sa": [(-0.03, 0.2, 0.0), (-0.02, 0.222, -0.1), (-0.042, 0.225, -0.28), (-0.05, 0.215, -0.46), (-0.04, 0.2, -0.64)],
              "sb": [(-0.075, 0.186, -0.01), (-0.1, 0.205, -0.09), (-0.125, 0.208, -0.24), (-0.14, 0.2, -0.38)]}
BAND_TAILS = {"ba": [(0.01, -0.158, 0.05), (0.03, -0.2, 0.0), (0.05, -0.225, -0.07), (0.075, -0.24, -0.15)],
              "bb": [(-0.015, -0.158, 0.05), (-0.04, -0.195, -0.0), (-0.055, -0.215, -0.06), (-0.065, -0.225, -0.13)]}


def ribbons_bag():
    sash = Bag("sash_tails")
    band = Bag("band_tails")
    z0 = float(R.waist[2]) + 0.07
    for j, (nm, pts) in enumerate(SASH_TAILS.items()):
        P = np.array(pts, np.float32) + S.vec(0, 0, z0)
        n = 9 if nm == "sa" else 6
        path = T.smooth_path(P, n)
        d = np.concatenate(([0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))))
        flat = [(0.034 + 0.05 * min(1.0, i / 3.0) * (1 - 0.32 * (i == n - 1)), 0.008) for i in range(n)]
        sweep(sash, path, [0.03] * n, 6, lambda i, k: (d[i], k / 6.0, 7 + j, 0.0), flat=flat, ofs=(j * 0.3, 0.0))
    for j, (nm, pts) in enumerate(BAND_TAILS.items()):
        P = np.array(pts, np.float32) + HC
        path = T.smooth_path(P, 6)
        d = np.concatenate(([0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))))
        flat = [(0.012 + 0.024 * min(1.0, i / 2.0), 0.006) for i in range(6)]
        sweep(band, path, [0.02] * 6, 6, lambda i, k: (d[i], k / 6.0, 9 + j, 0.0), flat=flat, ofs=(j * 0.3, 0.0))
    return [sash, band]


# ----------------------------------------------------------------------------------------------- low meshes
PROTECT = {"head": lambda P: 0.15 + 0.85 * S.sstep(-0.01, 0.06, P[:, 1] - HC[1]) * S.sstep(0.02, -0.03, P[:, 2] - HC[2]),
           "hands": lambda P: np.ones(P.shape[0])}


def verts_np(ob):
    n = len(ob.data.vertices)
    a = np.zeros(n * 3, np.float32)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def drop_floaters(bm, keep=0.015):
    """Removes specks: islands under keep of the part's vertices."""
    seen = set()
    isles = []
    for v0 in bm.verts:
        if v0 in seen:
            continue
        stack, isle = [v0], []
        seen.add(v0)
        while stack:
            v = stack.pop()
            isle.append(v)
            for e in v.link_edges:
                o = e.other_vert(v)
                if o not in seen:
                    seen.add(o)
                    stack.append(o)
        isles.append(isle)
    n = len(bm.verts)
    kill = [v for i in isles if len(i) < n * keep for v in i]
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
    return len(isles)


REMESH_FIRST = ("cap", "geode")


def decimate(ob, target, protect=None):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    isles = drop_floaters(bm)
    if ob.name in REMESH_FIRST:
        # (the slabs' jumps leave pinched sheets the collapse turns into duplicate faces, which validate then deletes as
        # holes: a voxel remesh first makes the part manifold)
        bm.to_mesh(me)
        bm.free()
        r = ob.modifiers.new("rem", "REMESH")
        r.mode = "VOXEL"
        r.voxel_size = 0.0042
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=r.name)
        bm = bmesh.new()
        bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    n = len(me.polygons)
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = min(1.0, target / n)
    if protect is not None:
        vg = ob.vertex_groups.new(name="keep")
        w = protect(verts_np(ob))
        for i, v in enumerate(w):
            vg.add([i], float(v), "REPLACE")
        mod.vertex_group = "keep"
        mod.vertex_group_factor = 4.0
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if protect is not None:
        ob.vertex_groups.clear()
    if len(ob.data.polygons) > target * 1.08:
        # (surface nets' pinched edges stop the collapse early: a voxel remesh makes it manifold, then go again)
        r = ob.modifiers.new("rem", "REMESH")
        r.mode = "VOXEL"
        r.voxel_size = 0.006
        bpy.ops.object.modifier_apply(modifier=r.name)
        mod = ob.modifiers.new("dec2", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = target / sum(len(q.vertices) - 2 for q in ob.data.polygons)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    log("%s: %d isles, %d tris" % (ob.name, isles, len(ob.data.polygons)))
    for pl in ob.data.polygons:
        pl.use_smooth = True


ROCK = ("geode", "shard")


def sharp_edges(ob, deg=38):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for e in bm.edges:
        if e.is_manifold and e.calc_face_angle(0.0) > math.radians(deg):
            e.smooth = False
    bm.to_mesh(ob.data)
    bm.free()


def geode_parts():
    """The seeing-stone's rock and its iris, one mesh shared by the three stones (in its own space, the face to +Y)."""
    rk = dict(f=lambda P: T.geode(P, GEO_R), lo=S.vec(-0.12, -0.11, -0.13), hi=S.vec(0.12, 0.09, 0.13), h=0.0035, tris=260)
    ir = dict(f=lambda P: T.geode_iris(P, GEO_R), lo=S.vec(-0.06, -0.01, -0.06), hi=S.vec(0.06, 0.05, 0.06), h=0.003, tris=60)
    shard = dict(f=lambda P: S.ellipsoid(P, (0, 0, 0), (0.03, 0.022, 0.04)) + 0.008 * S.fbm(P, 50.0, 4, 2), lo=S.vec(-0.05, -0.04, -0.06), hi=S.vec(0.05, 0.04, 0.06), h=0.004, tris=24)
    PARTS["geode"] = rk
    PARTS["iris"] = ir
    PARTS["shard"] = shard
    out = []
    for nm in ("geode", "iris", "shard"):
        ob = part_mesh(nm, PARTS[nm])
        decimate(ob, PARTS[nm]["tris"])
        out.append(ob)
    return out


# ---------------------------------------------------------------------------------------------------------- uvs
UV_K = {"head": 2.4, "teeth": 1.2, "bandana": 1.3, "hands": 1.4, "torso": 1.5, "stone": 1.4, "gauntlet": 1.4, "geode": 2.2, "iris": 3.0, "locs": 0.7, "beads": 0.6, "prayer": 0.5,
        "cap": 0.8, "shard": 8.0, "wraps": 1.1, "legs": 1.0}


def smoothed(ob, iters=30, k=0.8):
    V = verts_np(ob).copy()
    n = V.shape[0]
    e = np.zeros(len(ob.data.edges) * 2, np.int32)
    ob.data.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    deg = np.bincount(e.ravel(), minlength=n).astype(np.float32)
    deg[deg == 0] = 1
    for _ in range(iters):
        s = np.zeros_like(V)
        for ax in range(3):
            s[:, ax] = np.bincount(e[:, 0], V[e[:, 1], ax], n) + np.bincount(e[:, 1], V[e[:, 0], ax], n)
        V = V + (s / deg[:, None] - V) * k
    return V


def islands(ob):
    """UV islands of a mesh: lists of polygon indices, joined where polygons share a vertex at the same uv."""
    me = ob.data
    uv = me.uv_layers.active.data
    parent = list(range(len(me.polygons)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    seen = {}
    for pl in me.polygons:
        for li in pl.loop_indices:
            u = uv[li].uv
            key = (me.loops[li].vertex_index, round(u[0], 5), round(u[1], 5))
            if key in seen:
                parent[find(pl.index)] = find(seen[key])
            else:
                seen[key] = pl.index
    out = {}
    for pl in me.polygons:
        out.setdefault(find(pl.index), []).append(pl.index)
    return list(out.values())


def shelves(items, k, gap):
    """Shelf layout of (w, h) at scale k in the unit square: [(x, y)] or None when it overflows."""
    x = y = gap
    row = 0.0
    out = []
    for w, h in items:
        w, h = w * k, h * k
        if x + w + gap > 1.0:
            x = gap
            y += row + gap
            row = 0.0
        if w + 2 * gap > 1.0 or y + h + gap > 1.0:
            return None
        out.append((x, y))
        x += w + gap
        row = max(row, h)
    return out


def pack(objs, gap=0.0016):
    """A plain shelf pack (Blender's packer left most of the atlas empty here): islands stood on end, tallest first, at the
    largest scale that fits."""
    isl = []
    for ob in objs:
        lay = ob.data.uv_layers.active
        u = np.zeros(len(lay.data) * 2, np.float32)
        lay.data.foreach_get("uv", u)
        u = u.reshape(-1, 2)
        me = ob.data
        tex = float(UV_K.get(ob.name, 1.0))
        for polys in islands(ob):
            loops = [li for pi in polys for li in me.polygons[pi].loop_indices]
            q = u[loops].copy()
            a3 = sum(me.polygons[pi].area for pi in polys)
            a2 = 0.0
            for pi in polys:
                p = u[list(me.polygons[pi].loop_indices)]
                a2 += 0.5 * abs(float(np.dot(p[:, 0], np.roll(p[:, 1], 1)) - np.dot(p[:, 1], np.roll(p[:, 0], 1))))
            # (each island to metres, whatever the unwrap left it at; a collapsed one stays a speck)
            if a2 < 1e-6:
                # (collapsed on the smoothed copy: projected flat from the real shape instead, or its faces sample one texel)
                co = np.array([me.vertices[me.loops[li].vertex_index].co[:] for li in loops], np.float32)
                nr = np.sum([np.array(me.polygons[pi].normal[:]) * me.polygons[pi].area for pi in polys], axis=0)
                keep_ax = [i for i in range(3) if i != int(np.argmax(np.abs(nr)))]
                q = co[:, keep_ax] * tex
            else:
                q *= tex * math.sqrt(a3 / a2)
            lo, hi = q.min(0), q.max(0)
            size = np.minimum(hi - lo, 3.0) + 1e-4
            q = np.minimum(q - lo, size) + lo
            turn = size[0] > size[1]
            isl.append((float(max(size)), float(min(size)), turn, lo, ob, loops, q))
    isl.sort(key=lambda t: -t[0])
    items = [(t[1], t[0]) for t in isl]
    lo_k, hi_k = 0.0, 1e4
    for _ in range(40):
        k = 0.5 * (lo_k + hi_k)
        if shelves(items, k, gap) is None:
            hi_k = k
        else:
            lo_k = k
    places = shelves(items, lo_k, gap)
    data = {}
    for (h, w, turn, lo, ob, loops, q), (x, y) in zip(isl, places):
        p = (q - lo) * lo_k
        if turn:
            p = p[:, ::-1]
        p = p + np.array((x, y), np.float32)
        arr = data.setdefault(ob.name, np.zeros((len(ob.data.uv_layers.active.data), 2), np.float32))
        arr[loops] = p
    for ob in objs:
        ob.data.uv_layers.active.data.foreach_set("uv", data[ob.name].ravel())
    log("%d islands, scale %.3f" % (len(isl), lo_k))


def unwrap(objs):
    sdf = [o for o in objs if not o.get("swept")]
    bpy.ops.object.select_all(action="DESELECT")
    # (unwrapped on a heavily smoothed copy of each part: the sculpted noise would cut it into thousands of islands;
    # the paint is sampled in 3D, so the seams and the small stretch don't show)
    keep = {}
    for o in sdf:
        o.select_set(True)
        keep[o.name] = verts_np(o).copy()
        o.data.vertices.foreach_set("co", smoothed(o, {"stone": 6, "iris": 0, "geode": 3}.get(o.name, 30)).ravel())
        o.data.update()
    bpy.context.view_layer.objects.active = sdf[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(72), island_margin=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in sdf:
        o.data.vertices.foreach_set("co", keep[o.name].ravel())
        o.data.update()
    t0 = time.time()
    pack(objs)
    log("packed in %.1f s" % (time.time() - t0))
    for o in objs:
        lay = o.data.uv_layers.active
        u = np.zeros(len(lay.data) * 2, np.float32)
        lay.data.foreach_get("uv", u)
        u = u.reshape(-1, 2)
        tr = u[:, 0]
        o.data.calc_loop_triangles()
        lt = np.zeros(len(o.data.loop_triangles) * 3, np.int32)
        o.data.loop_triangles.foreach_get("loops", lt)
        q = u[lt].reshape(-1, 3, 2)
        area = np.abs((q[:, 1, 0] - q[:, 0, 0]) * (q[:, 2, 1] - q[:, 0, 1]) - (q[:, 2, 0] - q[:, 0, 0]) * (q[:, 1, 1] - q[:, 0, 1])).sum() / 2
        log("uv", o.name, len(o.data.polygons), "area %.4f" % area)


# -------------------------------------------------------------------------------------------- paint: fields
def world_grids():
    """Coarse min-of-all-parts fields for the shared occlusion: the body without the arms, and with them."""
    h = 0.012
    lo = np.array((-0.5, -0.32, -0.02), np.float32)
    hi = np.array((0.5, 0.34, float(HC[2] + 0.24)), np.float32)
    n = np.ceil((hi - lo) / h).astype(int)
    pts = np.stack(np.meshgrid(*[lo[i] + np.arange(n[i]) * h for i in range(3)], indexing="ij"), -1).reshape(-1, 3).astype(np.float32)
    arms = ("arms", "hands", "stone", "gauntlet")
    b = np.full(pts.shape[0], 9.0, np.float32)
    a = b.copy()
    for nm, p in PARTS.items():
        if nm in ("geode", "iris", "shard", "teeth"):
            continue
        m = ((pts >= p["lo"] - 0.1) & (pts <= p["hi"] + 0.1)).all(1)
        d = S.chunked(p["f"], pts[m])
        if nm in arms:
            a[m] = np.minimum(a[m], d)
        else:
            b[m] = np.minimum(b[m], d)
    g_body = b.reshape(tuple(n))
    g_all = np.minimum(a, b).reshape(tuple(n))
    def sampler(g):
        def f(P):
            q = (P - lo) / h
            i = np.clip(q.astype(np.int32), 0, n - 2)
            t = np.clip(q - i, 0, 1)
            c = 0.0
            for dx in (0, 1):
                for dy in (0, 1):
                    for dz in (0, 1):
                        w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                        c = c + w * g[i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz]
            return c
        return f
    return sampler(g_body), sampler(g_all)


exec(open(os.path.join(os.path.dirname(__file__), "tarek_paint.py")).read())
exec(open(os.path.join(os.path.dirname(__file__), "tarek_rigging.py")).read())


def scan_main():
    """The body from the fitted Meshy scan (~/meshy/tarek_m/fit.blend, FINE-DETAIL PASS); fists, eye-stones and rings scripted."""
    bpy.ops.wm.open_mainfile(filepath=os.path.expanduser(ARGS[3]))
    for k in list(PARTS):
        if k not in ("fist_L", "fist_R"):
            PARTS.pop(k)
    objs = []
    for nm, p in list(PARTS.items()):
        ob = part_mesh(nm, p)
        decimate(ob, p["tris"])
        objs.append(ob)
    objs += geode_parts()
    log("props tris", K.tris(objs))
    unwrap(objs)
    img, emit = paint_all(objs)
    assemble_scan(objs, img, emit)


def main():
    if MODE == "scan":
        scan_main()
        return
    K.reset()
    t0 = time.time()
    if MODE == "clay":
        objs = []
        for nm in ONLY or list(PARTS):
            ob = part_mesh(nm, PARTS[nm])
            ob.data.materials.append(col_mat(PARTS[nm]["col"]))
            for pl in ob.data.polygons:
                pl.use_smooth = True
            objs.append(ob)
        kw = {}
        if len(ARGS) > 5 and ARGS[5] == "head":
            kw = dict(zoom=0.62, mid=(HC[0], HC[1], HC[2] - 0.05), res=(2000, 600), views=(0, 35, 90))
        turnaround(objs, os.path.join(OUT, ARGS[4] if len(ARGS) > 4 else "clay"), **kw)
        return
    objs = []
    for nm, p in list(PARTS.items()):
        ob = part_mesh(nm, p)
        decimate(ob, p["tris"], PROTECT.get(nm))
        objs.append(ob)
    swept = [b.ob() for b in locs_bag() + ribbons_bag() + prayer_bag()]
    props = geode_parts()
    objs += swept + props
    log("tris", {o.name: len(o.data.polygons) for o in objs}, "total", K.tris(objs))
    unwrap(objs)
    log("unwrapped %.0f s" % (time.time() - t0))
    if MODE == "low":
        for o in objs:
            n = len(o.data.polygons)
            ch = o.data.validate(verbose=False)
            log("valid", o.name, n, "->", len(o.data.polygons), ch)
        return
    img, emit = paint_all(objs)
    assemble(objs, img, emit)
    log("done %.0f s" % (time.time() - t0))


main()

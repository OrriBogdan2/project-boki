"""Zippelith (caecilith): a thick ringed legless worm standing up in a column, its tail flat on the ground behind,
zipper teeth down its back and a pull tag at the tail tip.

Unlike the other Boki its body is not built from primitives: it is the Meshy model of the owner's sheet
(briefs/art-refs/boki/caecilith_turnaround.png), read from ~/meshy/caecilith/run1 (raw files stay out of git), turned
into game axes, decimated to the budget and painted from Meshy's own texture. The primitives below are a proxy: the
skin weights and the rig read them; MeshShape answers the face's and the occlusion's surface questions from the
full Meshy surface."""
import math
import os

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from vespyx_paint import hexc, mixc, paint_shell, sat, tool_colour

MESHY_DIR = os.path.expanduser("~/meshy/caecilith/run1")
HEIGHT = 0.62            # the Meshy model's height in game metres, before SCALE and the reshape below
SCALE = 0.9
BODY_TRIS = 3000
# The reshape toward the sheet (owner 11-09: head and neck proportions): Meshy's head rises to a point and sits on a
# neck as thick as itself; the sheet's is a round dome a size up. Heights in the Meshy model's metres.
CROWN_Y = 0.47           # where the head is widest: above it the crown is squashed this much
CROWN_K = 0.9
HEAD_PIVOT = (0.0, 0.40, -0.14)     # the chin's level: the head grows about it
HEAD_GROW = 1.1
HEAD_FROM, HEAD_TO = 0.36, 0.45     # the neck, where the growth fades in
NECK_Y, NECK_W, NECK_Z = 0.37, 0.05, -0.115    # the neck's thinnest height, the reach of its thickening, its axis
NECK_GROW = 0.05
# the zipper's teeth and stop over the crown (owner 11-09: the stray thing on top of the head): laid down onto this
# dome (centre y, z; radii x, y, z) and painted as skin, so the zipper starts at the back of the head
CROWN_DOME = (0.47, -0.15, 0.112, 0.14, 0.135)
CROWN_FRONT = 0.0        # z: the crown's part forward of this (the back of the head)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def on_crown(p):
    """1 on the crown forward of the back of the head (Meshy model metres), 0 elsewhere."""
    return (smooth(0.50, 0.53, p[:, 1]) * smooth(CROWN_FRONT + 0.015, CROWN_FRONT - 0.015, p[:, 2])
            * smooth(0.065, 0.045, np.abs(p[:, 0])))


def lay_crown(p):
    cy, zc, rx, ry, rz = CROWN_DOME
    e = 1 - (p[:, 0] / rx) ** 2 - ((p[:, 2] - zc) / rz) ** 2
    dome = cy + ry * np.sqrt(np.clip(e, 0.0, 1.0))
    p[:, 1] -= np.maximum(p[:, 1] - dome, 0.0) * on_crown(p)
    return p


def reshape(p):
    """The Meshy model's points (N, 3) in the sheet's proportions."""
    p = lay_crown(np.array(p, float).reshape(-1, 3))
    up = p[:, 1] > CROWN_Y
    p[up, 1] = CROWN_Y + (p[up, 1] - CROWN_Y) * CROWN_K
    k = 1 + NECK_GROW * np.exp(-((p[:, 1] - NECK_Y) / NECK_W) ** 2)
    p[:, 0] *= k
    p[:, 2] = NECK_Z + (p[:, 2] - NECK_Z) * k
    w = smooth(HEAD_FROM, HEAD_TO, p[:, 1])[:, None]
    return p + w * (HEAD_GROW - 1) * (p - np.array(HEAD_PIVOT))


def at(x, y, z):
    """A point placed on the Meshy model, where it lies after the reshape."""
    return reshape([x, y, z])[0]


HEAD_C = at(0, 0.51, -0.145)


def hd(x, y, z):
    """A point on the head, from its centre (offsets in the Meshy model's metres, grown with the head)."""
    return HEAD_C + HEAD_GROW * v3(x, y, z)


EYE_C = at(0.057, 0.514, -0.241)
EYE_R = HEAD_GROW * v3(0.034, 0.037, 0.018)
EYE_YAW = 0.48
GLOW_PIECES = ()
PALE_PIECES = ()
BERRY_C = v3(0, 0.05, -0.40)
_MOUTH = at(0, 0.458, -0.272)
FACE = {"mouth_w": 0.07 * HEAD_GROW, "mouth_y": _MOUTH[1], "mouth_z": _MOUTH[2], "cat_mouth": False,
        "brow_x": 0.058 * HEAD_GROW, "brow_up": 0.014, "brow_k": 0.55, "fang_k": 0.0}
# the body chain, head to tail: the column up from the ground, then the tail flat behind; segment i rides BODY_BONES[i]
SPINE = [at(0, 0.42, -0.125), v3(0, 0.33, -0.125), v3(0, 0.24, -0.145), v3(0, 0.13, -0.12), v3(0, 0.095, -0.03),
         v3(0, 0.09, 0.04), v3(0, 0.088, 0.10), v3(0, 0.085, 0.15), v3(0, 0.08, 0.20), v3(0, 0.05, 0.25)]
SPINE_R = [0.095, 0.095, 0.105, 0.11, 0.095, 0.09, 0.085, 0.07, 0.05, 0.03]
BODY_BONES = ["neck", "spine", "hips", "tail1", "tail2", "tail3", "tail4", "tail5", "tail6"]
TAIL_N = 6
HEAD_TOP = at(0, 0.62, -0.14)
GRIP = at(0, 0.455, -0.29)
AXIS = np.array((0.0, 0.5, -0.866))
# Meshy painted its own eyes and mouth; the Boki face (lids, brows, mouth that move) takes their place
PAINTED_EYES = [at(sx * 0.078, 0.512, -0.222) for sx in (1, -1)]
PAINTED_MOUTH = tuple(at(0, 0.455, -0.27)[1:])
BLUSH_AT = [at(sx * 0.088, 0.474, -0.225) for sx in (1, -1)]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def proxy_prims():
    out = [Cone("seg%d" % i, bone, SPINE[i], SPINE[i + 1], SPINE_R[i], SPINE_R[i + 1], k=0.03)
           for i, bone in enumerate(BODY_BONES)]
    out.append(Ellipsoid("head", "head", HEAD_C, HEAD_GROW * v3(0.105, 0.11, 0.135), k=0.04))
    return out


class Meshy:
    """The Meshy model in game axes: the full surface (a BVH), its texture, and a decimated copy for the game."""
    _it = None

    @classmethod
    def get(cls):
        if cls._it is None:
            cls._it = cls()
        return cls._it

    def __init__(self):
        import bpy
        from mathutils.bvhtree import BVHTree
        glb = os.path.join(MESHY_DIR, "glb.glb")
        if not os.path.exists(glb):
            raise SystemExit("caecilith: the raw Meshy model is not at %s (see docs/art/kin/RIGGED_BOKI.md)" % glb)
        before = {k: set(getattr(bpy.data, k)) for k in ("objects", "meshes", "materials", "images", "textures")}
        bpy.ops.import_scene.gltf(filepath=glb)
        o = next(o for o in bpy.data.objects if o.type == "MESH" and o not in before["objects"])
        me = o.data
        me.calc_loop_triangles()
        v = np.zeros(len(me.vertices) * 3)
        me.vertices.foreach_get("co", v)
        m = np.array(o.matrix_world)
        w = v.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
        g = np.stack([-w[:, 0], w[:, 2], w[:, 1]], -1)     # game axes, facing -Z
        g[:, 1] -= g[:, 1].min()
        g *= HEIGHT / g[:, 1].max()
        g[:, 0] -= (g[:, 0].max() + g[:, 0].min()) / 2
        self.raw = g.copy()                                # where the texture's zipper and seam were painted
        g = reshape(g)
        nt = len(me.loop_triangles)
        tv = np.zeros(nt * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("vertices", tv)
        tl = np.zeros(nt * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("loops", tl)
        uv = np.zeros(len(me.loops) * 2)
        me.uv_layers.active.data.foreach_get("uv", uv)
        self.v, self.t = g, tv.reshape(-1, 3)
        self.tuv = uv.reshape(-1, 2)[tl.reshape(-1, 3)]
        self.bvh = BVHTree.FromPolygons(g.tolist(), self.t.tolist(), all_triangles=True)
        img = bpy.data.images.load(os.path.join(MESHY_DIR, "tex0_base_color.png"))
        img.scale(4096, 4096)
        px = np.zeros(4096 * 4096 * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        self.tex = px.reshape(4096, 4096, 4)[..., :3]
        lum = self.tex[::16, ::16].reshape(-1, 3) @ np.array([0.3, 0.55, 0.15])
        self.coat_lum = float(np.median(lum[(lum > 0.02) & (lum < 0.3)]))     # the coat's typical light
        for k, old in before.items():
            coll = getattr(bpy.data, k)
            for item in [i for i in coll if i not in old]:
                coll.remove(item)

    def nearest(self, p):
        """Closest surface points, their face normals and triangle ids."""
        loc = np.zeros((len(p), 3))
        nor = np.zeros((len(p), 3))
        idx = np.zeros(len(p), dtype=np.int64)
        f = self.bvh.find_nearest
        for i, q in enumerate(p.reshape(-1, 3).tolist()):
            hit = f(q)
            loc[i], nor[i], idx[i] = hit[0], hit[1], hit[2]
        return loc, nor, idx

    def colour(self, p):
        return self.source(p)[0]

    def source(self, p):
        """The texture's colour at the surface points nearest p, and where they were before the reshape."""
        loc, _, idx = self.nearest(p)
        a, b, c = (self.v[self.t[idx, k]] for k in range(3))
        v0, v1, v2 = b - a, c - a, loc - a
        d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
        d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
        den = np.maximum(d00 * d11 - d01 * d01, 1e-18)
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        bary = np.stack([1 - bv - bw, bv, bw], -1)[..., None]
        uv = (self.tuv[idx] * bary).sum(1)
        raw = (self.raw[self.t[idx]] * bary).sum(1)
        x = np.clip((uv[:, 0] % 1.0) * 4095, 0, 4095).astype(int)
        y = np.clip((uv[:, 1] % 1.0) * 4095, 0, 4095).astype(int)
        return self.tex[y, x], raw

    def decimated(self, target):
        import bmesh
        import bpy
        me = bpy.data.meshes.new("zip_tmp")
        me.from_pydata(self.v.tolist(), [], self.t.tolist())
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new("zip_tmp", me)
        bpy.context.scene.collection.objects.link(obj)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new("d", "DECIMATE")
        mod.ratio = min(1.0, target / max(len(me.polygons), 1))
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        v = np.zeros(len(me.vertices) * 3)
        me.vertices.foreach_get("co", v)
        t = np.zeros(len(me.polygons) * 3, dtype=np.int32)
        me.polygons.foreach_get("vertices", t)
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(me)
        return v.reshape(-1, 3), t.reshape(-1, 3)


class MeshShape(Shape):
    """The proxy primitives (for the rig and the paint), but the surface is the Meshy one."""

    def mesh(self, tris):
        return Meshy.get().decimated(tris)

    def eval(self, p):
        q = np.asarray(p, float)
        loc, nor, _ = Meshy.get().nearest(q)
        d = q.reshape(-1, 3) - loc
        sign = np.where((d * nor).sum(1) < 0, -1.0, 1.0)
        return (np.linalg.norm(d, axis=1) * sign).reshape(q.shape[:-1])

    def project(self, p, offset=0.0, steps=6):
        q = np.asarray(p, float)
        loc, nor, _ = Meshy.get().nearest(q)
        return (loc + nor * offset).reshape(q.shape)

    def grad(self, p, e=0.0012):
        q = np.asarray(p, float)
        _, nor, _ = Meshy.get().nearest(q)
        return nor.reshape(q.shape)


def parts():
    return {"body": (MeshShape(proxy_prims()), 0.0035, BODY_TRIS)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.045, 0.08, 0.0), hd(0.085, 0.17, 0.03), 0.022),
    "fang": (hd(0.03, -0.05, -0.122), hd(0.032, -0.078, -0.125), 0.009),
    "antenna": (hd(0.035, 0.09, -0.02), hd(0.08, 0.19, -0.06), 0.008),
    "brow": (hd(0.015, 0.042, -0.112), hd(0.085, 0.048, -0.08), 0.011),
    "head_top": hd(0, 0.105, 0.0), "fang_at": hd(0, -0.05, -0.12), "brow_at": hd(0, 0.04, -0.11),
    "third_eye": hd(0, 0.06, -0.112), "back_at": (0, 0.30, -0.03), "plates": (0, 0.30, -0.04),
    "back": ((0, 0.37, -0.04), (0, 0.29, -0.03), (0, 0.21, -0.04)),
    "plate_r": (0.07, 0.03, 0.06), "shell_c": (0, 0.13, 0.06), "shell_r": (0.1, 0.07, 0.1), "tail_bone": "tail5",
    "club_at": tuple(SPINE[8]), "club_dir": tuple(SPINE[9] - SPINE[7]), "club_r": 0.045,
    "spots": ((0.098, 0.31, -0.13, 0.016), (0.104, 0.22, -0.14, 0.016), (0.09, 0.1, 0.02, 0.014)),
    "spots_at": (0, 0.22, -0.12),
    "wing": ((0.06, 0.36, -0.06), (0.18, 0.44, 0.0), (0.16, 0.40, 0.05)), "wing_at": (0, 0.36, -0.06),
    "fin": ((0.08, 0.1, 0.12), (0.14, 0.06, 0.2)), "fin_at": (0, 0.1, 0.12),
    "crest": (HEAD_C[1] + 0.105, HEAD_C[2] + 0.03, 0.04, 0.05),
    "crest_at": hd(0, 0.105, 0.03),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


OBSIDIAN = hexc("2b2233")
GLOW = hexc("a87aff")
LILAC = hexc("6a5a7a")     # brows
INK = hexc("120c18")
LID = hexc("3a2f45")
MOUTH_DARK = hexc("3a1430")
TONGUE = hexc("ff7fa0")
BLUSH = hexc("a8405e")
IRIS = hexc("6b3fd0")
IRIS_DEEP = hexc("1c0c3a")
SHELL_A = hexc("b8b4c4")
SHELL_B = hexc("5f5b6b")
SHELL_C = hexc("2a2730")
# the sheet's colours (owner 11-09: the body too grey-purple, the zipper and pull dark grey, all matte): Meshy baked a
# glossy grey-violet coat with white teeth, so the coat is laid flat in the sheet's aubergine-black and Meshy's own
# shading is kept only as soft light and dark (the ring grooves), its highlights clipped
COAT = hexc("3a3040")
ZIP = hexc("4a4a52")
SEAM = hexc("b07ef0")
SHADE = (0.8, 1.06)


def paint_body(q, nn):
    me = Meshy.get()
    tex, raw = me.source(q)
    lum = tex @ np.array([0.3, 0.55, 0.15])
    chroma = tex.max(1) - tex.min(1)
    seam = sat((chroma - 0.12) / 0.08) * sat((tex[:, 2] - tex[:, 0]) / 0.05)
    teeth = sat((lum - 0.32) / 0.1) * (1 - seam)
    crown = on_crown(raw)
    teeth *= 1 - crown
    seam *= 1 - crown                  # the stop on the crown is gone: the zipper starts behind the head
    shade = np.clip(lum / me.coat_lum, *SHADE)
    col = COAT * shade[:, None]
    col = mixc(col, np.tile(ZIP, (len(q), 1)) * np.clip(lum / 0.6, 0.85, 1.1)[:, None], teeth)
    col = mixc(col, 0.5 * (tex + SEAM), seam)
    gone = np.zeros(len(q))
    for c in PAINTED_EYES:
        gone = np.maximum(gone, sat((0.05 - np.linalg.norm((q - c) * v3(1, 0.9, 1.2), axis=1)) / 0.012))
    my, mz = PAINTED_MOUTH
    mouth = (sat((0.022 - np.abs(q[:, 1] - my - 6 * q[:, 0] ** 2)) / 0.008) * sat((-0.2 - q[:, 2]) / 0.02)
             * sat((0.068 - np.abs(q[:, 0])) / 0.012))
    gone = np.maximum(gone, mouth)
    col = mixc(col, np.tile(COAT, (len(q), 1)), gone)
    blush = np.zeros(len(q))
    for c in BLUSH_AT:
        blush = np.maximum(blush, sat((0.024 - np.linalg.norm((q - c) * v3(0.8, 1.3, 1), axis=1)) / 0.014))
    return mixc(col, np.tile(BLUSH, (len(q), 1)), 0.7 * blush)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)

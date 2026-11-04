"""Hem's quiver needles as clean geometry (tools/meshy/fit_warden.py `needles`; docs/art/wardens/PIPELINE.md): the
scan's thin needles bake ragged (a smeared, jagged outline at every zoom), so they are cut from the scan
(`cut_boxes`) and built here: arm-length iron sewing needles standing out of the quiver on her back, each with
its long eye at the top, one with a loop of red thread through the eye (the art's turnaround and portrait).

Positions come in Meshy's frame (as measured on the scan, +Z up, facing -Y) and go through the fit's own
transform (scale, the turn to face +Y, the soles on 0) and its girth, so they land where the scan's were. They
ride the hips (the quiver's bone). The pieces share a small colour atlas, one flat cell per colour.
"""
import math

import bpy
import numpy as np
from mathutils import Vector

COL = {"needle": ("metal", "c9ccd2"), "needle_dk": ("metal", "7c8088"), "thread": ("cloth", "c3202c")}
ATLAS = 64


def _atlas():
    img = bpy.data.images.get("hem_parts_atlas")
    if img is None:
        img = bpy.data.images.new("hem_parts_atlas", ATLAS, ATLAS, alpha=False)
        px = np.ones((ATLAS, ATLAS, 4), np.float32)
        for i, (_n, (_s, hexc)) in enumerate(COL.items()):
            px[:, i * 16:(i + 1) * 16, :3] = [int(hexc[k:k + 2], 16) / 255.0 for k in (0, 2, 4)]   # (sRGB, as stored)
        img.pixels = px.ravel()
        img.pack()
    return img


def _uv(name):
    i = list(COL).index(name)
    return ((i * 16 + 8) / ATLAS, 0.5)


def _mat(name):
    slot = COL[name][0]
    full = "%s-%s" % (slot, name)
    m = bpy.data.materials.get(full)
    if m is None:
        m = bpy.data.materials.new(full)
        m.use_nodes = True
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = _atlas()
        m.node_tree.links.new(tex.outputs[0], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return m


class _B:
    def __init__(self):
        self.v, self.f, self.part = [], [], []

    def tube(self, pts, radii, sides, part, cap=True):
        pts = [np.asarray(p, float) for p in pts]
        n = len(pts)
        base = len(self.v)
        ref = np.array([0.0, 0.0, 1.0])
        for i, p in enumerate(pts):
            t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
            t /= max(np.linalg.norm(t), 1e-9)
            r0 = ref if abs(t @ ref) < 0.9 else np.array([1.0, 0.0, 0.0])
            e1 = np.cross(t, r0)
            e1 /= np.linalg.norm(e1)
            e2 = np.cross(t, e1)
            for j in range(sides):
                a = 2 * math.pi * j / sides
                self.v.append(p + radii[i] * (math.cos(a) * e1 + math.sin(a) * e2))
                self.part.append(part)
        for i in range(n - 1):
            for j in range(sides):
                a, b = base + i * sides + j, base + i * sides + (j + 1) % sides
                self.f.append((a, b, b + sides, a + sides))
        if cap:
            self.f.append(tuple(base + j for j in range(sides))[::-1])
            self.f.append(tuple(base + (n - 1) * sides + j for j in range(sides)))


def needles(arm, sp, m, girth):
    """The quiver's needles (sp["needles"]: [{"tip": [x, y, z], "eye": [x, y, z], "thread": bool}] in Meshy's frame,
    the point down in the quiver, the eye up), skinned wholly to `sp.get("bone", "hips")`."""
    bld = _B()
    r = float(sp.get("r", 0.0075))

    def fit(p):
        q = m @ Vector(p)
        return np.array([q.x * girth, q.y * girth, q.z])
    for nd in sp["needles"]:
        tip, eye = fit(nd["tip"]), fit(nd["eye"])
        ax = eye - tip
        L = np.linalg.norm(ax)
        ax /= L
        side = np.cross(ax, [0.0, 0.0, 1.0] if abs(ax[2]) < 0.9 else [1.0, 0.0, 0.0])
        side /= np.linalg.norm(side)
        # the shaft, from a point to just under the eye
        zs = [0.0, 0.04, 0.12, 0.5, 0.82]
        rs = [0.0006, r * 0.6, r, r, r * 0.95]
        bld.tube([tip + ax * (z * (L - 0.06)) for z in zs], rs, 6, "needle")
        # the eye: a long loop, two bars round the slot meeting over it
        e0 = tip + ax * (L - 0.07)
        loop = []
        for k in range(17):
            a = 2 * math.pi * k / 16
            loop.append(e0 + ax * (0.035 + 0.035 * math.cos(a - math.pi)) + side * (r * 1.1 * math.sin(a)))
        bld.tube(loop, [r * 0.5] * len(loop), 5, "needle_dk", cap=False)
        if nd.get("thread"):
            # a loop of red thread through the eye, hanging down the back of the quiver
            c = e0 + ax * 0.035
            th = [c - side * 0.006, c + side * 0.01 - ax * 0.02, c + side * 0.02 - ax * 0.07 + np.array([0, 0, -0.01]),
                  c + side * 0.012 - ax * 0.12, c + side * 0.004 - ax * 0.16]
            bld.tube(th, [0.0022] * len(th), 5, "thread")
    me = bpy.data.meshes.new("Needles")
    me.from_pydata([tuple(x) for x in bld.v], [], bld.f)
    me.update()
    names = []
    for p in bld.part:
        if p not in names:
            names.append(p)
    for nm in names:
        me.materials.append(_mat(nm))
    lay = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        part = bld.part[poly.vertices[0]]
        poly.material_index = names.index(part)
        poly.use_smooth = True
        for li in poly.loop_indices:
            lay.data[li].uv = _uv(part)
    ob = bpy.data.objects.new("Needles", me)
    bpy.context.scene.collection.objects.link(ob)
    g = ob.vertex_groups.new(name=sp.get("bone", "hips"))
    g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    print("HEMPARTS needles: %d, %d tris" % (len(sp["needles"]), sum(len(f) - 2 for f in bld.f)), flush=True)
    return ob

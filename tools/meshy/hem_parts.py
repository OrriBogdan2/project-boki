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

COL = {"needle": ("metal", "c9ccd2"), "needle_dk": ("metal", "9a9ea6"), "thread": ("glow", "e0180e")}
ATLAS = 128


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
            # (the loose end drifts out and down past the quiver: the art's red thread "at rest")
            th = [c - side * 0.006, c + side * 0.012 - ax * 0.02, c + side * 0.03 - ax * 0.06 + np.array([0, 0, -0.01]),
                  c + side * 0.045 - ax * 0.12, c + side * 0.03 - ax * 0.19, c + side * 0.05 - ax * 0.25]
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


COL.update({"thimble": ("metal", "c6c9cf"), "claw": ("metal", "8e929a")})


def thimbles(body, arm, sp):
    """Silver thimble claws on her RIGHT (draw) hand's fingertips (hem_weapons_sheet): a dimpled cap over each of the
    four fingertips (the lowest hand.R vertices in the hanging rest pose, in four clusters across the hand) and a
    hooked claw out of its end, curving forward. Rigid on hand.R."""
    me = body.data
    g = body.vertex_groups.get(sp.get("bone", "hand.R"))
    co = np.array([v.co[:] for v in me.vertices])
    w = np.zeros(len(co))
    for v in me.vertices:
        for x in v.groups:
            if x.group == g.index:
                w[v.index] = x.weight
    wrist = np.array(arm.data.bones[sp.get("bone", "hand.R")].head_local[:])
    # (the hand itself: weighted to the bone, below the wrist and near it; the coat and shears share some weight)
    near = (np.linalg.norm(co - wrist, axis=1) < float(sp.get("reach", 0.15))) & (co[:, 2] < wrist[2] - 0.02)
    hand = co[(w > 0.5) & near]
    zlo = hand[:, 2].min()
    tips = hand[hand[:, 2] < zlo + float(sp.get("band", 0.045))]
    # four clusters across the hand's width (the fingers side by side, hanging)
    # (the fingers side by side along the hand's widest horizontal spread at the tips)
    c0 = tips[:, :2] - tips[:, :2].mean(axis=0)
    _u, _sv, vt = np.linalg.svd(c0, full_matrices=False)
    order = np.argsort(c0 @ vt[0])
    groups = np.array_split(tips[order], int(sp.get("fingers", 4)))
    bld = _B()
    r = float(sp.get("r", 0.0095))
    fwd = np.array(sp.get("forward", [0.0, 1.0, 0.0]))
    for gp in groups:
        tip = gp[np.argmin(gp[:, 2])]
        c = gp.mean(axis=0)
        c[2] = tip[2]
        up = np.array([0.0, 0.0, 1.0])
        bld.tube([c + up * 0.026, c + up * 0.012, c - up * 0.002], [r, r * 1.02, r * 0.8], 8, "thimble")
        claw = [c - up * 0.002, c - up * 0.014 + fwd * 0.004, c - up * 0.024 + fwd * 0.012, c - up * 0.028 + fwd * 0.022]
        bld.tube(claw, [r * 0.55, r * 0.42, r * 0.25, 0.0006], 6, "claw")
    me2 = bpy.data.meshes.new("Thimbles")
    me2.from_pydata([tuple(x) for x in bld.v], [], bld.f)
    me2.update()
    names = []
    for p in bld.part:
        if p not in names:
            names.append(p)
    for nm in names:
        me2.materials.append(_mat(nm))
    lay = me2.uv_layers.new(name="UVMap")
    for poly in me2.polygons:
        part = bld.part[poly.vertices[0]]
        poly.material_index = names.index(part)
        poly.use_smooth = True
        for li in poly.loop_indices:
            lay.data[li].uv = _uv(part)
    ob = bpy.data.objects.new("Thimbles", me2)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name=sp.get("bone", "hand.R"))
    vg.add(list(range(len(me2.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    print("HEMPARTS thimbles: %d on %s, %d tris" % (len(groups), sp.get("bone", "hand.R"), sum(len(f) - 2 for f in bld.f)), flush=True)
    return ob


COL.update({"shears": ("metal", "b8bcc4"), "shears_dk": ("metal", "4a4c52")})


def shears(arm, sp):
    """Tailor's shears hanging at her hip (the turnaround: at her right hip, the image's left in the front view):
    two long tapering blades crossed at a pivot, two oval finger rings above it; rigid on the hips.
    sp: at [x, y, z] (fitted frame: her right +X, front +Y), tilt (deg, the blades' lean outward), length."""
    bld = _B()
    at = np.array(sp["at"], float)
    L = float(sp.get("length", 0.2))
    tl = math.radians(float(sp.get("tilt", 12.0)))
    down = np.array([math.sin(tl), 0.0, -math.cos(tl)])
    side = np.array([math.cos(tl), 0.0, math.sin(tl)])
    for s in (-1, 1):
        # a blade: flat, tapering to its point from the pivot, a little apart from the other
        tip = at + down * L + side * s * 0.006
        mid = at + down * L * 0.5 + side * s * 0.01
        bld.tube([at, mid, tip], [0.008, 0.006, 0.0008], 4, "shears")
        # a finger ring above the pivot
        rc = at - down * 0.04 + side * s * 0.022
        ring = [rc + side * 0.018 * math.cos(a) - down * 0.022 * math.sin(a) for a in np.linspace(0, 2 * math.pi, 13)]
        bld.tube(ring, [0.0035] * len(ring), 5, "shears_dk", cap=False)
        bld.tube([at, at - down * 0.02 + side * s * 0.012], [0.004, 0.004], 5, "shears_dk")
    return _finish(bld, arm, "Shears", sp.get("bone", "hips"))


def lapel_needle(arm, sp):
    """Her calling card (HEM_KIT): a red-threaded needle pinned through her left lapel, aslant; rigid on the hips."""
    bld = _B()
    a, b = np.array(sp["from"], float), np.array(sp["to"], float)
    ax = (b - a) / np.linalg.norm(b - a)
    bld.tube([a, a + (b - a) * 0.15, b], [0.0006, 0.0028, 0.0028], 6, "needle")
    side = np.cross(ax, [0.0, 1.0, 0.0])
    side /= np.linalg.norm(side)
    th = [b, b + side * 0.01 - ax * 0.005, b + side * 0.016 - ax * 0.03 + np.array([0, 0, -0.02]),
          b + side * 0.012 - ax * 0.05 + np.array([0, 0, -0.045])]
    bld.tube(th, [0.0018] * len(th), 5, "thread")
    return _finish(bld, arm, "LapelNeedle", sp.get("bone", "hips"))


def _finish(bld, arm, name, bone):
    me2 = bpy.data.meshes.new(name)
    me2.from_pydata([tuple(x) for x in bld.v], [], bld.f)
    me2.update()
    names = []
    for p in bld.part:
        if p not in names:
            names.append(p)
    for nm in names:
        me2.materials.append(_mat(nm))
    lay = me2.uv_layers.new(name="UVMap")
    for poly in me2.polygons:
        part = bld.part[poly.vertices[0]]
        poly.material_index = names.index(part)
        poly.use_smooth = True
        for li in poly.loop_indices:
            lay.data[li].uv = _uv(part)
    ob = bpy.data.objects.new(name, me2)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(me2.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    print("HEMPARTS %s: %d tris" % (name, sum(len(f) - 2 for f in bld.f)), flush=True)
    return ob

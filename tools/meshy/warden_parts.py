"""Pieces a Meshy scan can't give cleanly, built as real geometry on the fitted Warden (tools/meshy/fit_warden.py,
docs/art/wardens/PIPELINE.md "r3b"), in Blender 4.5:

- braid(): a three-strand braid hanging from the head (Vex r3b's long green braids): the strands are tubes woven
  around a path that is draped against the body (never through it), with copper wire wraps, steel bolts through
  them and a loose tuft at the end. It rides a chain of `spring_<name>_<i>` bones under the head that the game
  swings on a damped spring (WardenGlb.Springs). Its texture is painted here: flat colour per part, darkened
  where the strands cross under each other and against the body (an ambient-occlusion bake), with hair lines.
- lens(): a cyber eye as geometry on the face: a brass rim and a glowing lens (the `glow` slot), riding the head.

All in the fitted frame: Blender, +Z up, her front +Y, her right +X, soles on Z = 0.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

TEX = 1024


def log(*a):
    print("WARDENPARTS", *a, flush=True)


def hexcol(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


# ------------------------------------------------------------------------------------------------ the path
def body_bvh(obs):
    """A BVH of the evaluated (posed) meshes, for draping."""
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for ob in obs:
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ob.matrix_world
        base = len(verts)
        verts.extend([mw @ v.co for v in me.vertices])
        polys.extend([[base + i for i in p.vertices] for p in me.polygons])
        ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys)


def resample(pts, n):
    pts = np.asarray(pts, np.float64)
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    t = np.linspace(0.0, s[-1], n)
    return np.stack([np.interp(t, s, pts[:, i]) for i in range(3)], axis=1), s[-1]


def drape(bvh, ctrl, n, clear, iters=60, smooth=0.35, length=None):
    """The control polyline resampled to n points, then relaxed: each pass smooths it a little, keeps every
    point at least `clear` from the body (pushed out along the surface normal) and keeps the root where it is.
    With `length`, the rope is cut or extended (straight on) to that length."""
    p, total = resample(ctrl, n)
    if length is not None and abs(length - total) > 1e-4:
        d = p[-1] - p[-2]
        d /= np.linalg.norm(d)
        ext = np.vstack([p, p[-1] + d * max(0.0, length - total)])
        p, total = resample(ext, n)
        if length < total:
            seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
            s = np.concatenate([[0.0], np.cumsum(seg)])
            t = np.linspace(0.0, length, n)
            p = np.stack([np.interp(t, s, p[:, i]) for i in range(3)], axis=1)
    root = p[0].copy()
    for _it in range(iters):
        q = p.copy()
        q[1:-1] = p[1:-1] * (1 - smooth) + (p[:-2] + p[2:]) * 0.5 * smooth
        for i in range(1, len(q)):
            loc, nrm, _idx, dist = bvh.find_nearest(Vector(q[i]))
            if loc is None:
                continue
            off = Vector(q[i]) - loc
            if nrm is None or not all(math.isfinite(x) for x in nrm) or nrm.length < 1e-6:
                # (a degenerate face, e.g. on a fresh cut: push straight away from the surface point)
                if off.length < 1e-9:
                    continue
                nrm = off.normalized()
            inside = off.dot(nrm) < 0.0
            if inside or off.length < clear:
                q[i] = np.array(loc + nrm.normalized() * clear)
        q[0] = root
        p = q
    # evenly spaced again (the push-out can stack two points on one spot: a zero tangent)
    keep = np.concatenate([[True], np.linalg.norm(np.diff(p, axis=0), axis=1) > 1e-6])
    p = p[keep]
    if length is not None:
        # (pushing out stretches the rope: cut it back to its length from the root)
        s = arclen(p)
        if s[-1] > length:
            t = np.linspace(0.0, length, n)
            p = np.stack([np.interp(t, s, p[:, i]) for i in range(3)], axis=1)
    p, _total = resample(p, n)
    return p


def frames(p, side_hint):
    """Tangents and a parallel-transported normal/binormal along the path; the normal starts as side_hint
    (the braid's width lies along it), made perpendicular to the first tangent."""
    t = np.gradient(p, axis=0)
    ln = np.linalg.norm(t, axis=1)
    for i in range(len(t)):                         # (a zero step: the neighbour's direction)
        if ln[i] < 1e-9:
            t[i] = t[i - 1] if i > 0 else p[min(2, len(p) - 1)] - p[0]
            ln[i] = max(np.linalg.norm(t[i]), 1e-9)
    t /= ln[:, None]
    n0 = np.array(side_hint, np.float64)
    n0 -= t[0] * n0.dot(t[0])
    if np.linalg.norm(n0) < 1e-3:                   # (the hint along the path: any perpendicular)
        n0 = np.cross(t[0], [0.0, 0.0, 1.0] if abs(t[0][2]) < 0.9 else [1.0, 0.0, 0.0])
    n0 /= np.linalg.norm(n0)
    ns = [n0]
    for i in range(1, len(p)):
        # parallel transport: the previous normal turned by the rotation from the previous tangent to this one
        a, b = t[i - 1], t[i]
        ax = np.cross(a, b)
        sn, cs = np.linalg.norm(ax), float(np.clip(a.dot(b), -1.0, 1.0))
        nv = ns[-1]
        if sn > 1e-9:
            k = ax / sn
            nv = nv * cs + np.cross(k, nv) * sn + k * k.dot(nv) * (1.0 - cs)
        nv = nv - b * nv.dot(b)
        nv /= max(np.linalg.norm(nv), 1e-9)
        ns.append(nv)
    ns = np.array(ns)
    bs = np.cross(t, ns)
    return t, ns, bs


def arclen(p):
    return np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])


def at(p, s_arr, s):
    """The point at arc length s (and its index fraction)."""
    return np.stack([np.interp(s, s_arr, p[:, i]) for i in range(3)], axis=-1)


# ------------------------------------------------------------------------------------------------ geometry
class Builder:
    """Vertices, faces, UVs, a part id and an arc-length parameter per vertex (for the bone weights)."""

    def __init__(self):
        self.v, self.f, self.uv, self.part, self.s = [], [], [], [], []

    def tube(self, rings, radii, sides, u0, u1, v0, v1, part, s_of_ring, cap_end=False, cap_start=False):
        """A tube through ring centres (k x 3) with per-ring radius; UV u around (u0..u1), v along (v0..v1)."""
        rings = np.asarray(rings, np.float64)
        k = len(rings)
        t = np.gradient(rings, axis=0)
        t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
        ref = np.array([0.0, 0.0, 1.0]) if abs(t[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        nv = ref - t[0] * ref.dot(t[0])
        nv /= np.linalg.norm(nv)
        base = len(self.v)
        for i in range(k):
            nv = nv - t[i] * nv.dot(t[i])
            nv /= max(np.linalg.norm(nv), 1e-9)
            bv = np.cross(t[i], nv)
            for j in range(sides + 1):
                a = 2.0 * math.pi * j / sides
                self.v.append(rings[i] + radii[i] * (math.cos(a) * nv + math.sin(a) * bv))
                self.uv.append((u0 + (u1 - u0) * j / sides, v0 + (v1 - v0) * i / max(k - 1, 1)))
                self.part.append(part)
                self.s.append(s_of_ring[i])
        row = sides + 1
        for i in range(k - 1):
            for j in range(sides):
                a = base + i * row + j
                self.f.append((a, a + 1, a + row + 1, a + row))
        for cap, i in ((cap_start, 0), (cap_end, k - 1)):
            if not cap:
                continue
            c = len(self.v)
            self.v.append(rings[i])
            self.uv.append((u0 + (u1 - u0) * 0.5, v0 + (v1 - v0) * i / max(k - 1, 1)))
            self.part.append(part)
            self.s.append(s_of_ring[i])
            for j in range(sides):
                a = base + i * row + j
                self.f.append((a + 1, a, c) if i == 0 else (a, a + 1, c))
        return base

    def torus(self, centre, axis, major, minor, seg, sides, uv_box, part, s):
        axis = np.asarray(axis, np.float64)
        axis /= np.linalg.norm(axis)
        ref = np.array([0.0, 0.0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        e1 = np.cross(axis, ref)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(axis, e1)
        base = len(self.v)
        u0, v0, u1, v1 = uv_box
        for i in range(seg + 1):
            a = 2.0 * math.pi * i / seg
            d = math.cos(a) * e1 + math.sin(a) * e2
            for j in range(sides + 1):
                b = 2.0 * math.pi * j / sides
                self.v.append(np.asarray(centre) + d * (major + minor * math.cos(b)) + axis * minor * math.sin(b))
                self.uv.append((u0 + (u1 - u0) * i / seg, v0 + (v1 - v0) * j / sides))
                self.part.append(part)
                self.s.append(s)
        row = sides + 1
        for i in range(seg):
            for j in range(sides):
                a = base + i * row + j
                self.f.append((a, a + row, a + row + 1, a + 1))

    def prism(self, a, b, r, sides, uv_box, part, s, rot=0.0):
        """A capped prism from a to b (a hex bolt's shank or head)."""
        a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
        ax = b - a
        ax /= np.linalg.norm(ax)
        ref = np.array([0.0, 0.0, 1.0]) if abs(ax[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        e1 = np.cross(ax, ref)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(ax, e1)
        u0, v0, u1, v1 = uv_box
        base = len(self.v)
        for end in (a, b):
            for j in range(sides + 1):
                ang = rot + 2.0 * math.pi * j / sides
                self.v.append(end + r * (math.cos(ang) * e1 + math.sin(ang) * e2))
                self.uv.append((u0 + (u1 - u0) * j / sides, v0 if end is a else v1))
                self.part.append(part)
                self.s.append(s)
        row = sides + 1
        for j in range(sides):
            self.f.append((base + j, base + j + 1, base + row + j + 1, base + row + j))
        for end, off in ((a, 0), (b, row)):
            c = len(self.v)
            self.v.append(end)
            self.uv.append(((u0 + u1) * 0.5, (v0 + v1) * 0.5))
            self.part.append(part)
            self.s.append(s)
            for j in range(sides):
                p0, p1 = base + off + j, base + off + j + 1
                self.f.append((p1, p0, c) if off == 0 else (p0, p1, c))

    def object(self, name):
        bad = ~np.isfinite(np.asarray(self.v)).all(axis=1)
        if bad.any():
            raise ValueError("%s: %d vertices are not finite" % (name, int(bad.sum())))
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(x) for x in self.v], [], self.f)
        me.update()
        lay = me.uv_layers.new(name="UVMap")
        uvs = np.array(self.uv, np.float32)
        for poly in me.polygons:
            for li in poly.loop_indices:
                lay.data[li].uv = uvs[me.loops[li].vertex_index]
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        for poly in me.polygons:
            poly.use_smooth = True
        return ob


# ------------------------------------------------------------------------------------------------ the braid
STRAND_COLS = 6       # texture columns: 3 strands per braid on the left 3/4 of the atlas (braids() sets it)


def braid(bld, spec, bvh, index):
    """One braid into the builder; returns its path (n x 3) and its total length (strands + tuft)."""
    ctrl = [Vector(c) for c in spec["path"]]
    n = int(spec.get("samples", 160))
    clear = float(spec.get("clear", 0.03))
    p = drape(bvh, [tuple(c) for c in ctrl], n, clear, length=spec.get("length"))
    s_arr = arclen(p)
    L = s_arr[-1]
    t, nrm, bin_ = frames(p, spec.get("side", [1.0, 0.0, 0.0]))
    log("braid %s: %d points, %.3f m%s" % (spec["name"], len(p), L, "" if np.isfinite(p).all() and np.isfinite(nrm).all()
                                            and np.isfinite(bin_).all() else " (NOT FINITE: p %d, n %d, b %d, t %d)" % (
        int((~np.isfinite(p)).any(axis=1).sum()), int((~np.isfinite(nrm)).any(axis=1).sum()),
        int((~np.isfinite(bin_)).any(axis=1).sum()), int((~np.isfinite(t)).any(axis=1).sum()))))
    W = float(spec.get("width", 0.05)) * 0.5            # half width
    rs = float(spec.get("strand_r", 0.0115))
    period = float(spec.get("period", 0.15))
    depth = float(spec.get("depth", 0.45))              # the strands' front/back swing, x their side swing
    sides = int(spec.get("sides", 6))
    taper_in = float(spec.get("taper_in", 0.06))
    taper_out = float(spec.get("taper_out", 0.05))
    end_k = float(spec.get("end_k", 0.7))
    amp = W - rs
    col_w = 0.75 / STRAND_COLS
    if spec.get("style") == "loose":
        # loose wavy hair, not a plait (Claire's pigtails): `locks` strands side by side across the width, fanning
        # out toward the end (`fan`), all waving together sideways (`wave`, metres; `period`) with a small phase
        # step between them so the lock reads as soft waves, a little depth between the front and back ones
        nl = int(spec.get("locks", 7))
        fan = float(spec.get("fan", 1.6))
        wave = float(spec.get("wave", 0.02))
        for k in range(nl):
            u = (k / max(nl - 1, 1)) * 2.0 - 1.0
            ph = 0.5 * k
            dz = (0.5 if k % 2 else -0.5) * rs * 1.2
            rings, radii = [], []
            for i in range(n):
                s = s_arr[i]
                f = s / max(L, 1e-6)
                g = min(1.0, 0.55 + 0.45 * s / taper_in) * (1.0 - (1.0 - end_k) * max(0.0, (s - (L - taper_out)) / taper_out))
                a = 2.0 * math.pi * s / period
                spread = amp * g * (1.0 + (fan - 1.0) * f)
                off = (u * spread + wave * math.sin(a + ph) * min(1.0, 3.0 * f)) * nrm[i] + dz * bin_[i]
                rings.append(p[i] + off)
                radii.append(rs * (0.7 + 0.3 * g) * (1.0 - 0.25 * abs(u)))
            c = index * 3 + k % 3
            bld.tube(rings, radii, sides, c * col_w + 0.004, (c + 1) * col_w - 0.004, 0.01, 0.01 + 0.98 * L / 1.0,
                     "strand", s_arr, cap_start=True, cap_end=True)
    for k in (range(3) if spec.get("style") != "loose" else []):
        ph = 2.0 * math.pi * k / 3.0
        rings, radii = [], []
        for i in range(n):
            s = s_arr[i]
            g = min(1.0, 0.55 + 0.45 * s / taper_in) * (1.0 - (1.0 - end_k) * max(0.0, (s - (L - taper_out)) / taper_out))
            a = 2.0 * math.pi * s / period
            off = amp * g * math.sin(a + ph) * nrm[i] + amp * g * depth * math.sin(2.0 * (a + ph)) * bin_[i]
            rings.append(p[i] + off)
            radii.append(rs * (0.75 + 0.25 * g))
        c = index * 3 + k
        bld.tube(rings, radii, sides, c * col_w + 0.004, (c + 1) * col_w - 0.004, 0.01, 0.01 + 0.98 * L / 1.0,
                 "strand", s_arr, cap_start=True, cap_end=True)
    # copper wire wraps (stacked rings) and bolts through some of them; the atlas's right quarter holds, per
    # braid (a column 0.11 wide), the rings (v 0-0.45), the bolts (0.46-0.52) and the tuft's locks (0.54-0.99)
    wire_r = float(spec.get("wire_r", 0.0028))
    rings_per = int(spec.get("wrap_rings", 3))
    cu0 = 0.76 + 0.12 * (index % 2)
    ring_i = 0
    for w in spec.get("wraps", []):
        s = float(w["at"]) * L if w["at"] <= 1.0 else float(w["at"])
        nr = int(w.get("rings", rings_per))
        g = 1.0 if s < L - taper_out else end_k
        for r in range(nr):
            sr = min(L, s + (r - (nr - 1) * 0.5) * wire_r * 2.4)
            c = at(p, s_arr, sr)
            i = int(np.clip(np.searchsorted(s_arr, sr), 0, n - 1))
            v0 = 0.005 + 0.025 * min(ring_i, 17)
            bld.torus(c, t[i], W * g + wire_r * 0.4, wire_r, 10, 4, (cu0, v0, cu0 + 0.1, v0 + 0.02), "copper", sr)
            ring_i += 1
        if w.get("crystals"):
            # (ice-crystal shards on the tie, pointing up and out: Claire's pigtail clips)
            c = at(p, s_arr, s)
            i = int(np.clip(np.searchsorted(s_arr, s), 0, n - 1))
            nc = int(w["crystals"])
            box = (cu0, 0.465, cu0 + 0.1, 0.515)
            for j in range(nc):
                a = math.pi * (0.15 + 0.7 * j / max(nc - 1, 1))
                d = math.cos(a) * nrm[i] + math.sin(a) * bin_[i]
                ln = float(w.get("crystal_len", 0.035)) * (0.7 + 0.3 * ((j * 7) % 3) / 2.0)
                root = c + d * W * 0.7
                tip = root + (d * 0.6 - t[i] * 0.8) * ln
                bld.prism(root, tip, float(w.get("crystal_r", 0.006)), 4, box, "steel", s)
        if w.get("bolt"):
            c = at(p, s_arr, s)
            i = int(np.clip(np.searchsorted(s_arr, s), 0, n - 1))
            d = nrm[i] * math.cos(float(w.get("bolt_turn", 0.0))) + bin_[i] * math.sin(float(w.get("bolt_turn", 0.0)))
            half = W * g + float(spec.get("bolt_out", 0.011))
            box = (cu0, 0.465, cu0 + 0.1, 0.515)
            br = float(spec.get("bolt_r", 0.0035))
            bld.prism(c - d * half, c + d * half, br, 6, box, "steel", s)
            hr, ht = br * 1.9, br * 1.3
            bld.prism(c + d * half, c + d * (half + ht), hr, 6, box, "steel", s)
            bld.prism(c - d * (half + ht), c - d * half, hr, 6, box, "steel", s)
    # the tuft: tapered locks fanning out of the end
    tf = spec.get("tuft", {})
    nl = int(tf.get("locks", 9))
    tl = float(tf.get("length", 0.1))
    spread = math.radians(float(tf.get("spread", 22.0)))
    rng = np.random.default_rng(7 + index)
    end = p[-1]
    tu0 = cu0
    for j in range(nl):
        ang = 2.0 * math.pi * j / nl + rng.uniform(-0.3, 0.3)
        rad = (0.35 + 0.65 * ((j % 3) / 2.0)) * W * end_k * 0.8
        start = end - t[-1] * 0.01 + (math.cos(ang) * nrm[-1] + math.sin(ang) * bin_[-1]) * rad * 0.6
        out_dir = (math.cos(ang) * nrm[-1] + math.sin(ang) * bin_[-1])
        ln = tl * rng.uniform(0.75, 1.1)
        k = 6
        rings = []
        radii = []
        for m in range(k):
            f = m / (k - 1)
            bend = math.sin(spread) * (f ** 1.4) * ln
            rings.append(start + t[-1] * ln * f + out_dir * (bend + rad * 0.5 * math.sin(math.pi * f)))
            radii.append(max(0.0012, float(tf.get("r", 0.011)) * (1.0 - f) ** 0.8 * (1.0 + 0.25 * math.sin(math.pi * f))))
        sv = [L + ln * m / (k - 1) for m in range(k)]
        v0 = 0.545 + 0.05 * (j % 9)
        bld.tube(rings, radii, 5, tu0, tu0 + 0.1, v0, v0 + 0.044, "tuft", sv, cap_end=True)
    return p, L + tl


def chain_bones(arm, name, parent, p, L_total, nb, tip):
    """The spring chain: nb bones along the path (heads on it, each the next one's parent) and a leaf at the
    tuft's tip. Returns the bone names and their arc-length spans."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    s_arr = arclen(p)
    L = s_arr[-1]
    names, spans = [], []
    prev = eb[parent]
    for i in range(nb + 1):
        s0 = L * i / nb if i < nb else L
        h = Vector(at(p, s_arr, s0))
        if i < nb:
            tl = Vector(at(p, s_arr, L * (i + 1) / nb))
        else:
            tl = Vector(tip)
        if (tl - h).length < 1e-3:
            tl = h + Vector((0, 0, -0.02))
        nm = "spring_%s_%d" % (name, i)
        e = eb.new(nm)
        e.head = h
        e.tail = tl
        e.parent = prev
        e.use_connect = False
        prev = e
        names.append(nm)
        spans.append((s0, L * (i + 1) / nb if i < nb else L_total))
    bpy.ops.object.mode_set(mode="OBJECT")
    for nm in names:
        arm.data.bones[nm].use_deform = True
    return names, spans


def weights(ob, sel, names, spans):
    """Each vertex of the braid (sel: its vertex indices, s: arc length) between the two nearest bones of its
    chain, blended across each joint."""
    groups = [ob.vertex_groups.get(nm) or ob.vertex_groups.new(name=nm) for nm in names]
    mids = np.array([(a + b) * 0.5 for a, b in spans])
    lens = np.array([max(b - a, 1e-3) for a, b in spans])
    for vi, s in sel:
        w = np.clip(1.0 - np.abs(s - mids) / lens, 0.0, 1.0)
        if s <= mids[0]:
            w[:] = 0.0
            w[0] = 1.0
        if s >= mids[-1]:
            w[:] = 0.0
            w[-1] = 1.0
        tot = w.sum()
        if tot <= 0:
            w[int(np.argmin(np.abs(s - mids)))] = 1.0
            tot = 1.0
        for gi in np.nonzero(w > 1e-3)[0]:
            groups[gi].add([int(vi)], float(w[gi] / tot), "REPLACE")


def bake_ao(ob, size, samples=48):
    """Ambient occlusion of the braid onto its own UVs (the strands crossing under each other, the body)."""
    img = bpy.data.images.new(ob.name + "_ao", size, size, alpha=False)
    mat = ob.data.materials[0]
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.render.bake.margin = 6
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type="AO", margin=6, use_clear=True)
    nt.nodes.remove(node)
    w, h = img.size
    return np.array(img.pixels[:], np.float32).reshape(h, w, 4)[..., 0]


def paint(ob, ao, colours, part_masks):
    """The braid atlas: each part's flat colour, darkened by the AO, with fine hair lines along the strands."""
    h, w = ao.shape
    out = np.zeros((h, w, 4), np.float32)
    out[..., 3] = 1.0
    yy, xx = np.mgrid[0:h, 0:w]
    for part, mask in part_masks.items():
        lit, dark = hexcol(colours[part][0]), hexcol(colours[part][1])
        a = np.clip((ao - 0.35) / 0.6, 0.0, 1.0) ** 1.2
        a = 1.0 - (1.0 - a) * float(colours.get("ao_k", 1.0))       # (a lighter AO: solid plaits, no speckle)
        col = dark[None, None] * (1 - a[..., None]) + lit[None, None] * a[..., None]
        if part in ("strand", "tuft"):
            la = float(colours.get("lines", 0.1))
            lines = 1.0 - la + la * np.sin(xx * (2 * math.pi / 9.0) + np.sin(yy * 0.05) * 2.0)
            col = col * lines[..., None]
            if len(colours[part]) > 2:
                hi = hexcol(colours[part][2])
                band = np.clip((a - 0.85) / 0.15, 0.0, 1.0)[..., None] * 0.5
                col = col * (1 - band) + hi[None, None] * band
        out[mask, :3] = col[mask]
    return out


def part_masks(ob, size, parts):
    """Texels covered by each part's faces (rasterised from the UVs)."""
    me = ob.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    masks = {p: np.zeros((size, size), bool) for p in set(parts)}
    for tri in me.loop_triangles:
        part = parts[me.loops[tri.loops[0]].vertex_index]
        q = np.array([[uv[li].uv.x * size, uv[li].uv.y * size] for li in tri.loops])
        lo = np.maximum(np.floor(q.min(axis=0)).astype(int) - 2, 0)
        hi = np.minimum(np.ceil(q.max(axis=0)).astype(int) + 2, size - 1)
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        pts = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
        a, b, c = q
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (pts[:, 0] - c[0]) + (c[0] - b[0]) * (pts[:, 1] - c[1])) / d
        l2 = ((c[1] - a[1]) * (pts[:, 0] - c[0]) + (a[0] - c[0]) * (pts[:, 1] - c[1])) / d
        inside = (l1 >= -0.08) & (l2 >= -0.08) & (1 - l1 - l2 >= -0.08)
        masks[part][pts[inside, 1].astype(int), pts[inside, 0].astype(int)] = True
    return masks


def braids(body_obs, arm, specs, colours, tag="braid", size=TEX):
    """Every braid in `specs` as one mesh skinned to its spring chains on `arm`, with its painted atlas and the
    materials hair-<tag> (strands, tuft) and metal-<tag> (wire, bolts)."""
    global STRAND_COLS
    STRAND_COLS = 3 * max(2, len(specs))      # (a strand column per strand of every braid: Breaker has three)
    bvh = body_bvh(body_obs)
    bld = Builder()
    chains = []
    for i, sp in enumerate(specs):
        v0 = len(bld.v)
        p, Ltot = braid(bld, sp, bvh, i)
        chains.append((sp, p, Ltot, v0, len(bld.v)))
    ob = bld.object("Braids")
    img = bpy.data.images.new(tag + "_atlas", size, size, alpha=False)
    mats = {}
    for slot in ("hair", "metal"):
        m = bpy.data.materials.new("%s-%s" % (slot, tag))
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
        ob.data.materials.append(m)
        mats[slot] = len(ob.data.materials) - 1
    parts = bld.part
    for poly in ob.data.polygons:
        pt = parts[poly.vertices[0]]
        poly.material_index = mats["metal"] if pt in ("copper", "steel") else mats["hair"]
    ao = bake_ao(ob, size)
    masks = part_masks(ob, size, parts)
    px = paint(ob, ao, colours, masks)
    img.pixels = px.ravel()
    img.pack()
    # bones and weights
    for sp, p, Ltot, v0, v1 in chains:
        names, spans = chain_bones(arm, sp["name"], sp.get("parent", "head"), p, Ltot, int(sp.get("bones", 6)),
                                   bld.v[v1 - 1] if v1 > v0 else p[-1])
        weights(ob, [(vi, bld.s[vi]) for vi in range(v0, v1)], names, spans)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("braids: %d, %d tris" % (len(specs), sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ the lens
def lens(arm, spec, tag="lens"):
    """A cyber eye: a brass rim (metal) round a glowing lens (glow) with a dark pupil ring, facing `normal`
    at `centre`, riding the head bone rigidly."""
    c = Vector(spec["centre"])
    nrm = Vector(spec["normal"]).normalized()
    r = float(spec.get("r", 0.016))
    bld = Builder()
    nrm_np = np.array(nrm[:])
    cc = np.array(c[:])
    # the rim: a torus round the lens; the lens: a shallow dome
    bld.torus(cc + nrm_np * r * 0.15, nrm_np, r * 1.02, r * 0.22, 20, 6, (0.0, 0.0, 0.5, 0.5), "rim", 0.0)
    rings, radii = [], []
    k = 5
    for m in range(k):
        f = m / (k - 1)
        rings.append(cc + nrm_np * (r * 0.1 + r * 0.35 * math.sin(f * math.pi / 2)))
        radii.append(max(1e-4, r * 0.95 * math.cos(f * math.pi / 2)))
    bld.tube(rings, radii, 20, 0.5, 1.0, 0.5, 1.0, "lens", [0.0] * k, cap_end=True)
    ob = bld.object("Lens")
    n = 256 if spec.get("iris") else 64
    img = bpy.data.images.new(tag + "_atlas", n, n, alpha=False)
    img.pixels = _lens_atlas(spec, n).ravel()
    img.pack()
    mats = {}
    for slot in ("metal", "glow"):
        m = bpy.data.materials.new("%s-%s" % (slot, tag))
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Linear" if spec.get("iris") else "Closest"
        m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        ob.data.materials.append(m)
        mats[slot] = len(ob.data.materials) - 1
    for poly in ob.data.polygons:
        poly.material_index = mats["metal"] if bld.part[poly.vertices[0]] == "rim" else mats["glow"]
    g = ob.vertex_groups.new(name="head")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("lens at %s, r %.3f, %d tris" % (tuple(round(x, 3) for x in c), r, sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ the hoses
def hoses(body_obs, arm, specs, colours, tag="hose", size=64):
    """Armoured hoses (Vex: from the backpack to her gun-arm): ribbed tubes along a path draped against the body,
    brass fittings at both ends. Each hose rides a chain of bones along its length (`bones`: [[bone, t], ...],
    t from 0 at its start to 1 at its end; weights blend linearly between neighbours), so its ends stay on the
    backpack and on the gun-arm while the arm aims and the middle follows between them."""
    global STRAND_COLS
    STRAND_COLS = 3 * max(2, len(specs))      # (a strand column per strand of every braid: Breaker has three)
    bvh = body_bvh(body_obs)
    bld = Builder()
    chains = []
    for i, sp in enumerate(specs):
        n = int(sp.get("samples", 40))
        p = drape(bvh, [tuple(c) for c in sp["path"]], n, float(sp.get("clear", 0.024)))
        s_arr = arclen(p)
        L = s_arr[-1]
        r = float(sp.get("r", 0.013))
        rib, ribk = float(sp.get("rib", 0.014)), float(sp.get("rib_k", 0.2))
        m = max(8, int(L / (rib / 3.0)))
        ss = np.linspace(0.0, L, m)
        rings = at(p, s_arr, ss)
        radii = [r * (1.0 + ribk * (0.5 + 0.5 * math.cos(2.0 * math.pi * s / rib))) for s in ss]
        v0 = len(bld.v)
        bld.tube(rings, radii, int(sp.get("sides", 8)), 0.02, 0.46, 0.02, 0.98, "hose", list(ss / L), cap_start=True,
                 cap_end=True)
        # brass fittings: a short collar at each end
        for t0, t1 in ((0.0, 0.035), (1.0 - 0.035, 1.0)):
            cs = np.linspace(t0 * L, t1 * L, 4)
            bld.tube(at(p, s_arr, cs), [r * 1.55] * 4, 10, 0.54, 0.98, 0.02, 0.98, "fitting", list(cs / L),
                     cap_start=True, cap_end=True)
        chains.append((sp, v0, len(bld.v)))
    ob = bld.object("Hoses")
    img = bpy.data.images.new(tag + "_atlas", size, size, alpha=False)
    px = np.ones((size, size, 4), np.float32)
    px[:, :size // 2, :3] = hexcol(colours.get("hose", "2e2e34"))
    px[:, size // 2:, :3] = hexcol(colours.get("fitting", "a08050"))
    img.pixels = px.ravel()
    img.pack()
    m = bpy.data.materials.new("metal-%s" % tag)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    ob.data.materials.append(m)
    for sp, v0, v1 in chains:
        anchors = sp.get("bones", [["hips", 0.0], ["forearm.R", 1.0]])
        groups = {b: (ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)) for b, _t in anchors}
        ts = [float(t) for _b, t in anchors]
        for vi in range(v0, v1):
            t = min(1.0, max(0.0, bld.s[vi]))
            k = max(0, min(len(ts) - 2, int(np.searchsorted(ts, t, side="right")) - 1))
            f = (t - ts[k]) / max(ts[k + 1] - ts[k], 1e-6)
            f = min(1.0, max(0.0, f))
            f = f * f * (3.0 - 2.0 * f)
            groups[anchors[k][0]].add([vi], 1.0 - f, "ADD")
            groups[anchors[k + 1][0]].add([vi], f, "ADD")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("hoses: %d, %d tris" % (len(specs), sum(len(f) - 2 for f in bld.f)))
    return ob


def _lens_atlas(spec, n):
    """The lens's atlas (rows bottom up, as Blender's pixels): the rim's quarter (u 0..0.5, v 0..0.5: u round the
    ring, v round its tube; the tube's front at v 0.125) and the lens's (u 0.5..1 round it, v 0.5 at its edge to
    1 at its middle). With spec "iris" (the eyeplate detail: blades, dots, pupil, screws), polar paint; else the
    plain rings."""
    rim, glow = hexcol(spec.get("rim", "b08a48")), hexcol(spec.get("glow", "6dff5a"))
    px = np.ones((n, n, 4), np.float32)
    h = n // 2
    yy, xx = np.mgrid[0:h, 0:h]
    u = (xx + 0.5) / h                     # 0..1 round
    v = (yy + 0.5) / h                     # 0..1 across the quarter
    iris = spec.get("iris")
    if not iris:
        dark = hexcol(spec.get("pupil", "103a14"))
        ring = np.exp(-((v - 0.55) / 0.12) ** 2)[..., None]
        lens = glow[None, None] * (1 - 0.75 * ring) + dark[None, None] * 0.75 * ring
        lens = np.where((v > 0.92)[..., None], np.ones(3) * 0.95 + glow * 0.05, lens)
        px[:h, :h, :3] = rim
        px[h:, h:, :3] = lens
        px[:h, h:, :3] = rim
        px[h:, :h, :3] = glow
        return px
    # the rim: brass, darker toward the tube's back, slotted screws round its front
    shade = 0.72 + 0.28 * np.cos((v - 0.25) * 2.0 * np.pi)
    col = rim[None, None] * shade[..., None]
    k = int(iris.get("screws", 8))
    a = (u * k) % 1.0 - 0.5
    sv = (v - 0.25) / 0.5
    screw = (a / 0.18) ** 2 + (sv / 0.12) ** 2 < 1.0
    slot_line = screw & (np.abs(a) < 0.035)
    col = np.where(screw[..., None], rim[None, None] * 0.62, col)
    col = np.where(slot_line[..., None], np.array([0.12, 0.09, 0.05]), col)
    px[:h, :h, :3] = col
    px[:h, h:, :3] = rim
    # the lens: t from its edge (0) to its middle (1); blades spiral in, a ring of dots, the dark pupil
    t = v
    ang = u
    base = glow[None, None] * (0.55 + 0.45 * np.clip(1.0 - np.abs(t - 0.45) / 0.45, 0.0, 1.0))[..., None]
    nb, tw = int(iris.get("blades", 9)), float(iris.get("twist", 1.3))
    edge = np.abs(((ang * nb + t * tw * nb) % 1.0) - 0.5) > 0.44
    blades = (t > 0.32) & (t < 0.8) & edge
    base = np.where(blades[..., None], base * float(iris.get("blade_k", 0.65)), base)
    outer = t < 0.05
    base = np.where(outer[..., None], glow[None, None] * 0.5, base)
    nd = int(iris.get("dots", 12))
    da = ((ang * nd) % 1.0 - 0.5) / nd * 2.0 * np.pi * 0.2
    dots = (da / 0.012) ** 2 + ((t - 0.2) / 0.035) ** 2 < 1.0
    arcs = (np.abs(t - 0.14) < 0.012) & (((ang * 4) % 1.0) < 0.7)
    base = np.where((dots | arcs)[..., None], np.minimum(glow[None, None] * 1.35 + 0.1, 1.0), base)
    if iris.get("rings"):
        # (vex_face's lens: glowing toxic-green glass with bright concentric rings and a bright core)
        g = np.clip(glow[None, None] * (0.62 + 0.38 * t[..., None]), 0, 1)
        for r0, r1 in iris["rings"]:
            ring = (t > r0) & (t < r1)
            g = np.where(ring[..., None], np.minimum(glow[None, None] * 1.25 + 0.12, 1.0), g)
        g = np.where((t > 0.9)[..., None], np.minimum(glow[None, None] * 1.3 + 0.25, 1.0), g)
        base = g
    pupil = hexcol(iris.get("pupil", "1a1020"))
    if not iris.get("rings"):
        base = np.where((t > float(iris.get("pupil_t", 0.86)))[..., None], pupil[None, None], base)
    hi = ((ang - 0.12) % 1.0 < 0.06) & (t > 0.84) & (t < 0.9)
    base = np.where(hi[..., None], np.array([0.92, 1.0, 0.92]), base)
    px[h:, h:, :3] = base
    px[h:, :h, :3] = glow
    return px


def dorsal(body, arm, spec, atlas_spec, tag="dorsal"):
    """The crest's fin carried down her back to the tail (Cinder r3): a fin along the back at `x` (the fitted
    frame; beside the spine so a back tank isn't in the way) from height z0 down to z1, its base found by rays at
    the body from behind, leaning back and up; same atlas as the crest; rides `bone`."""
    bvh = body_bvh([body])
    x = float(spec["x"])
    z0, z1 = spec["z"]
    n = int(spec.get("samples", 40))
    base, ups = [], []
    for z in np.linspace(z0, z1, n):
        loc, nrm, _i, _d = bvh.ray_cast(Vector((x, -1.5, z)), Vector((0.0, 1.0, 0.0)))
        if loc is None:
            continue
        up = np.array([0.0, -1.0, float(spec.get("lean", 0.35))])
        up /= np.linalg.norm(up)
        base.append(np.array(loc[:]) - up * float(spec.get("sink", 0.01)))
        ups.append(up)
    base = np.array(base)
    bld = Builder()
    ribbon_fin(bld, base, np.array(ups), arclen(base), spec)
    ob = bld.object("Dorsal")
    img = bpy.data.images.new(tag + "_atlas", MEM_TEX, MEM_TEX, alpha=False)
    img.pixels = membrane_atlas(atlas_spec).ravel()
    img.pack()
    mi = _mats(ob, img, ("fur", "glow"), tag)
    for poly in ob.data.polygons:
        poly.material_index = mi["glow"] if all(bld.part[v] == "edge" for v in poly.vertices) else mi["fur"]
    g = ob.vertex_groups.new(name=spec.get("bone", "hips"))
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("dorsal fin: %d points, %d tris" % (len(base), sum(len(f) - 2 for f in bld.f)))
    return ob


def vials(body, arm, spec, tag="vials"):
    """Cinder's bandolier vials, bigger than Meshy's: n glass vials (glow, each its colour) with cork tops
    (leather), one on each stretch of the body's own glow faces (Meshy's small vial caps) along the strap,
    standing out from the chest along its normal; they ride `bone`."""
    me = body.data
    names = [m.name for m in me.materials]
    cen, nrm = [], []
    for p in me.polygons:
        if names[p.material_index].startswith("glow-"):
            cen.append(p.center[:])
            nrm.append(p.normal[:])
    cen, nrm = np.array(cen), np.array(nrm)
    mu = cen.mean(axis=0)
    _u, _s, vt = np.linalg.svd(cen - mu, full_matrices=False)
    ax = vt[0]
    t = (cen - mu) @ ax
    n = len(spec["colours"])
    edges = np.quantile(t, np.linspace(0, 1, n + 1))
    bld = Builder()
    for k in range(n):
        sel = (t >= edges[k]) & (t <= edges[k + 1])
        c = cen[sel].mean(axis=0)
        nv = nrm[sel].mean(axis=0)
        nv /= max(np.linalg.norm(nv), 1e-9)
        up = np.cross(nv, ax)
        up /= max(np.linalg.norm(up), 1e-9)
        if up[2] < 0:
            up = -up
        r, h = float(spec.get("r", 0.017)), float(spec.get("h", 0.056))
        mid = c + nv * (r + float(spec.get("out", 0.004)))
        a, b = mid - up * h * 0.5, mid + up * h * 0.5
        u0 = k / n
        bld.prism(a, b, r, 10, (u0 + 0.01, 0.02, u0 + 1.0 / n - 0.01, 0.48), "glass%d" % k, 0.0)
        bld.prism(b - up * 0.002, b + up * float(spec.get("cork_h", 0.016)), r * 0.7, 8,
                  (u0 + 0.01, 0.52, u0 + 1.0 / n - 0.01, 0.98), "cork", 0.0)
    ob = bld.object("Vials")
    size = 64
    img = bpy.data.images.new(tag + "_atlas", size, size, alpha=False)
    px = np.ones((size, size, 4), np.float32)
    for k, col in enumerate(spec["colours"]):
        x0, x1 = int(size * k / n), int(size * (k + 1) / n)
        px[: size // 2, x0:x1, :3] = hexcol(col)
        px[size // 2:, x0:x1, :3] = hexcol(spec.get("cork", "7a4a2a"))
    img.pixels = px.ravel()
    img.pack()
    mi = _mats(ob, img, ("glow", "leather"), tag)
    for poly in ob.data.polygons:
        poly.material_index = mi["leather"] if bld.part[poly.vertices[0]] == "cork" else mi["glow"]
    g = ob.vertex_groups.new(name=spec.get("bone", "hips"))
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("vials: %d along %.2f m of strap" % (n, float(t.max() - t.min())))
    return ob


def ribbon_fin(bld, base, up, s_arr, spec):
    """A fin along a ridge (Cinder's tail): `base` points (n x 3) with `up` directions, heights rising from 0 to
    `height` and back to 0 over the run, a spiky edge between `rays` rays; s_arr the arc length at each base."""
    n = len(base)
    rows = int(spec.get("rows", 5))
    nr = int(spec["rays"])
    H = float(spec["height"])
    grid = np.zeros((rows, n, 3))
    nrm = np.zeros((rows, n, 3))
    uvg = np.zeros((rows, n, 2))
    sg = np.zeros((rows, n))
    v0, v1 = spec.get("v", [0.5, 1.0])
    tang = np.gradient(base, axis=0)
    for j in range(n):
        u = j / (n - 1)
        h = H * math.sin(math.pi * min(1.0, u * 1.25)) ** 0.6 if u < 0.8 else H * 0.4 * (1.0 - (u - 0.8) / 0.2) + 0.002
        ph = abs((u * nr) % 1.0 - 0.5) * 2.0
        h *= 1.0 - float(spec.get("spike", 0.3)) * ph ** 1.5
        side = np.cross(tang[j], up[j])
        side /= max(np.linalg.norm(side), 1e-9)
        for i in range(rows):
            t = i / (rows - 1)
            grid[i, j] = base[j] + up[j] * h * t
            nrm[i, j] = side
            uvg[i, j] = (u, v0 + (v1 - v0) * (0.02 + 0.96 * t))
            sg[i, j] = s_arr[j]
    part = ["edge" if i >= rows - 2 else "mem" for i in range(rows)]
    _sheet(bld, grid, nrm, float(spec.get("th", 0.002)), part, sg, uvg)
    return bld


MEM_TEX = 512

def fins(arm, specs, atlas_spec, tag="fin"):
    """The crest fan(s) as one mesh on the head bone, with their atlas (membrane on fur, the edge on glow)."""
    bld = Builder()
    for sp in specs:
        fan(arm, sp, bld)
    ob = bld.object("Fins")
    img = bpy.data.images.new(tag + "_atlas", MEM_TEX, MEM_TEX, alpha=False)
    img.pixels = membrane_atlas(atlas_spec).ravel()
    img.pack()
    mi = _mats(ob, img, ("fur", "glow"), tag)
    parts = bld.part
    for poly in ob.data.polygons:
        poly.material_index = mi["glow"] if all(parts[v] == "edge" for v in poly.vertices) else mi["fur"]
    g = ob.vertex_groups.new(name=specs[0].get("bone", "head"))
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("fins: %d, %d tris" % (len(specs), sum(len(f) - 2 for f in bld.f)))
    return ob, img


def fan(arm, spec, bld=None):
    """A fin-crest fanned round the back of the skull (Cinder r3: a newt's sail that reads from the front as a
    halo of rays): `rays` rays from angle a0 to a1 (degrees: 0 straight up, + to her right), their roots on a
    ring of radius `r_base` about `centre` (the fitted frame, rel the head bone), tilted `tilt` degrees back,
    `length` long at the top and `side_k` x that at the ends, a spiky edge (`spike` deep between the rays).
    Rides the head bone. Rows: `rows` from the root to the edge (the last `edge_rows` on the glow slot); `yaw`
    degrees turns the fan about the vertical (behind a head that Meshy turned)."""
    bld = bld or Builder()
    c = np.array(spec["centre"], np.float64)
    nr = int(spec["rays"])
    per = int(spec.get("per_ray", 6))
    cols = nr * per + 1
    rows = int(spec.get("rows", 7))
    a0, a1 = math.radians(spec["a0"]), math.radians(spec["a1"])
    tilt = math.radians(spec.get("tilt", 30.0))
    back = float(spec.get("back", 0.03))
    grid = np.zeros((rows, cols, 3))
    nrm = np.zeros((rows, cols, 3))
    uvg = np.zeros((rows, cols, 2))
    sg = np.zeros((rows, cols))
    v0, v1 = spec.get("v", [0.0, 0.5])
    for j in range(cols):
        u = j / (cols - 1)
        a = a0 + (a1 - a0) * u
        radial = np.array([math.sin(a), 0.0, math.cos(a)])
        d = radial * math.cos(tilt) + np.array([0.0, -1.0, 0.0]) * math.sin(tilt)
        d /= np.linalg.norm(d)
        root = c + radial * float(spec["r_base"]) + np.array([0.0, -back, 0.0])
        k = float(spec.get("side_k", 0.8))
        L = float(spec["length"]) * (k + (1.0 - k) * math.cos(a) ** 2 if abs(a) < math.pi / 2 else k * 0.9)
        ph = abs((u * nr) % 1.0 - 0.5) * 2.0
        L *= 1.0 - float(spec.get("spike", 0.16)) * ph ** 1.5
        side = np.cross(d, radial)
        side /= max(np.linalg.norm(side), 1e-9)
        for i in range(rows):
            t = i / (rows - 1)
            tt = t if i < rows - 1 else 1.0
            grid[i, j] = root + d * L * tt
            nrm[i, j] = side
            uvg[i, j] = (u, v0 + (v1 - v0) * (0.02 + 0.96 * t))
            sg[i, j] = 0.0
    yaw = math.radians(float(spec.get("yaw", 0.0)))         # (+ toward her right: behind a head Meshy turned)
    if yaw:
        cz, sz = math.cos(yaw), math.sin(yaw)
        rz = np.array([[cz, -sz, 0.0], [sz, cz, 0.0], [0.0, 0.0, 1.0]])
        grid = (grid - c) @ rz.T + c
        nrm = nrm @ rz.T
    ne = int(spec.get("edge_rows", 1))
    part = ["edge" if i >= rows - 1 - ne else "mem" for i in range(rows)]
    _sheet(bld, grid, nrm, float(spec.get("th", 0.0016)), part, sg, uvg)
    return bld


def _mats(ob, img, slots, tag):
    out = {}
    for slot in slots:
        m = bpy.data.materials.new("%s-%s" % (slot, tag))
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
        ob.data.materials.append(m)
        out[slot] = len(ob.data.materials) - 1
    return out


def membrane_atlas(spec, size=MEM_TEX):
    """The fins' atlas: v from the base (0) to the tip (1) inside each fin's band, the membrane's ramp along it,
    dark fin rays at the ray columns (stronger at the base), the last `edge` share the glowing orange edge."""
    px = np.ones((size, size, 4), np.float32)
    for band in spec["bands"]:
        v0, v1 = band["v"]
        r0, r1 = int(v0 * size), int(v1 * size)
        t = (np.arange(r1 - r0) + 0.5) / max(1, r1 - r0)
        cols = np.array([hexcol(c) for c in band["ramp"]], np.float32)
        x = np.clip(t, 0, 1) * (len(cols) - 1)
        i0 = np.clip(np.floor(x).astype(int), 0, len(cols) - 2)
        f = (x - i0)[:, None]
        mem = cols[i0] * (1 - f) + cols[i0 + 1] * f                     # (rows, 3)
        img = np.repeat(mem[:, None, :], size, axis=1)
        u = (np.arange(size) + 0.5) / size
        nr = int(band["rays"])
        ph = np.abs((u * nr) % 1.0 - 0.5) * 2.0                           # 1 between rays, 0 on a ray
        ray = np.clip(1.0 - ph / float(band.get("ray_w", 0.22)), 0, 1)[None, :] * (1.0 - 0.6 * t[:, None])
        img = img * (1 - ray[..., None]) + hexcol(band["ray"])[None, None, :] * ray[..., None]
        e = float(band.get("edge", 0.12))
        edge = np.clip((t - (1.0 - e)) / 0.03, 0, 1)[:, None, None]
        img = img * (1 - edge) + hexcol(band["edge_col"])[None, None, :] * edge
        px[r0:r1, :, :3] = img
    return px


def _sheet(bld, grid, nrm, th, part, s_grid, uv_grid):
    """A thin closed sheet through a grid of points (rows x cols x 3) with per-point normals: a front and a back
    layer `th` apart and their rims joined, so it reads from both sides under back-face culling."""
    rows, cols = grid.shape[:2]
    base = len(bld.v)
    for side in (1.0, -1.0):
        for i in range(rows):
            for j in range(cols):
                bld.v.append(grid[i, j] + nrm[i, j] * th * side)
                bld.uv.append(tuple(uv_grid[i, j]))
                bld.part.append(part[i])
                bld.s.append(s_grid[i, j])
    n = rows * cols

    def vid(side, i, j):
        return base + (0 if side > 0 else n) + i * cols + j
    for i in range(rows - 1):
        for j in range(cols - 1):
            bld.f.append((vid(1, i, j), vid(1, i, j + 1), vid(1, i + 1, j + 1), vid(1, i + 1, j)))
            bld.f.append((vid(-1, i, j), vid(-1, i + 1, j), vid(-1, i + 1, j + 1), vid(-1, i, j + 1)))
    for i in range(rows - 1):
        for j in (0, cols - 1):
            bld.f.append((vid(1, i, j), vid(1, i + 1, j), vid(-1, i + 1, j), vid(-1, i, j)))
    for j in range(cols - 1):
        for i in (0, rows - 1):
            bld.f.append((vid(1, i, j), vid(-1, i, j), vid(-1, i, j + 1), vid(1, i, j + 1)))


def gauntlets(arm, spec, tag="gauntlet"):
    """Stone gauntlets grown round both forearms (Tarek), elbow to knuckle: a glowing amber core (glow slot)
    wrapped in rough stone plates (`slot`, leather) set a little apart, so the core shows through the gaps as
    bright cracks; the plates past the wrist ride the hand bone, the rest the forearm. An empty
    anchor_<tag>_<L|R> on each forearm's middle carries a glow halo at the match camera (warden_look.json).
    Returns [mesh, anchors...]."""
    rng = np.random.default_rng(int(spec.get("seed", 5)))
    img = _stone_cells(128, spec, tag + "_cells")
    bld = Builder()
    owners = []           # per vertex: (bone, weight) via ranges
    spans = []
    for sd in ("L", "R"):
        e = np.array(arm.data.bones["forearm." + sd].head_local[:])
        w = np.array(arm.data.bones["hand." + sd].head_local[:])
        ax = w - e
        L = float(np.linalg.norm(ax))
        ax /= L
        k = w + ax * float(spec.get("fist", 0.1))
        ref = np.array([0.0, 1.0, 0.0]) if abs(ax[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
        e1 = np.cross(ax, ref)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(ax, e1)
        r_arm = float(spec.get("r", 0.06))
        v0 = len(bld.v)
        # the core: a tube elbow -> knuckle, thicker toward the fist
        rings = [e + (k - e) * f for f in np.linspace(0.0, 1.0, 8)]
        core_k = float(spec.get("core", 0.8))       # (a thinner core: thin cracks between the plates)
        radii = [r_arm * (core_k + 0.25 * f) for f in np.linspace(0.0, 1.0, 8)]
        bld.tube(rings, radii, 12, 0.05, 0.45, 0.55, 0.95, "core", [0.0] * 8, cap_end=True, cap_start=True)
        # the plates: rows along the arm, each a lumpy rock on the surface, slightly apart
        rows = int(spec.get("rows", 5))
        per = int(spec.get("per_row", 5))
        for i in range(rows):
            t = (i + 0.5) / rows
            c = e + (k - e) * t
            rr = r_arm * (0.85 + 0.3 * t)
            for j in range(per):
                a = 2.0 * math.pi * (j + 0.5 * (i % 2)) / per + rng.uniform(-0.15, 0.15)
                out_d = math.cos(a) * e1 + math.sin(a) * e2
                p = c + out_d * rr * 1.02
                s = rr * float(spec.get("plate", 0.62)) * rng.uniform(0.85, 1.15)
                side = np.cross(ax, out_d)
                _lumpy(bld, p, (side, ax, -out_d), (s, s * 1.25, s * float(spec.get("thick", 0.45))), "rock",
                       (0.05, 0.05, 0.45, 0.45),
                       int(rng.integers(1, 9999)), rings=5, sides=8, lump=float(spec.get("lump", 0.3)))
        spans.append((sd, v0, len(bld.v), e, w, ax, L))
    ob = bld.object(tag.capitalize() + "s")
    mi = {"rock": _flat_material(ob, spec.get("slot", "leather"), tag, img, "Closest")}
    mi["core"] = _flat_material(ob, "glow", tag, img, "Closest")
    for poly in ob.data.polygons:
        poly.material_index = mi[bld.part[poly.vertices[0]]]
    anchors = []
    for sd, v0, v1, e, w, ax, L in spans:
        gf = ob.vertex_groups.new(name="forearm." + sd)
        gh = ob.vertex_groups.new(name="hand." + sd)
        for vi in range(v0, v1):
            t = float((np.asarray(bld.v[vi]) - e) @ ax) / L
            f = min(1.0, max(0.0, (t - 0.9) / 0.15))     # (past the wrist: the hand's)
            if f < 1.0:
                gf.add([vi], 1.0 - f, "REPLACE")
            if f > 0.0:
                gh.add([vi], f, "REPLACE")
        an = bpy.data.objects.new("anchor_%s_%s" % (tag, sd), None)
        bpy.context.scene.collection.objects.link(an)
        an.parent = arm
        an.parent_type = "BONE"
        an.parent_bone = "forearm." + sd
        bpy.context.view_layer.update()
        an.matrix_world = Matrix.Translation(Vector(e + ax * L * 0.6))
        anchors.append(an)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("gauntlets: %d tris" % sum(len(f) - 2 for f in bld.f))
    return [ob] + anchors


# ------------------------------------------------------------------------------------------------ simple materials
def _flat_material(ob, slot, tag, img, interp="Linear"):
    m = bpy.data.materials.new("%s-%s" % (slot, tag))
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = interp
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    ob.data.materials.append(m)
    return len(ob.data.materials) - 1


def _rigid(ob, arm, bone):
    g = ob.vertex_groups.new(name=bone)
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def _quads_uv(size, cells, name="cells"):
    """An atlas of flat colour cells (a 2x2 grid, row 0 at the bottom as Blender stores it): cells is
    [colour hex] x 4 (bottom-left, bottom-right, top-left, top-right) -> the image."""
    img = bpy.data.images.new(name, size, size, alpha=False)
    px = np.ones((size, size, 4), np.float32)
    hlf = size // 2
    for i, c in enumerate(cells):
        y, x = divmod(i, 2)
        px[y * hlf:(y + 1) * hlf, x * hlf:(x + 1) * hlf, :3] = hexcol(c)
    img.pixels = px.ravel()
    img.pack()
    return img


def _stone_cells(size, spec, name):
    """A seeing-stone's atlas (the _quads_uv cells): mottled rock, a crystal ring of radial facets, an iris that
    glows hot at its middle, a black pupil."""
    img = bpy.data.images.new(name, size, size, alpha=False)
    px = np.ones((size, size, 4), np.float32)
    hl = size // 2
    rng = np.random.default_rng(3)
    yy, xx = np.mgrid[0:hl, 0:hl] / float(hl - 1)
    # rock: value noise (two octaves), darker in its crevices
    n = np.zeros((hl, hl), np.float32)
    for oc, amp in ((6, 0.6), (14, 0.4)):
        g = rng.random((oc + 1, oc + 1)).astype(np.float32)
        gx, gy = xx * oc, yy * oc
        x0, y0 = np.floor(gx).astype(int), np.floor(gy).astype(int)
        fx, fy = gx - x0, gy - y0
        x1, y1 = np.minimum(x0 + 1, oc), np.minimum(y0 + 1, oc)
        n += amp * ((g[y0, x0] * (1 - fx) + g[y0, x1] * fx) * (1 - fy) + (g[y1, x0] * (1 - fx) + g[y1, x1] * fx) * fy)
    rock, rock_dk = hexcol(spec.get("rock", "8a7a66")), hexcol(spec.get("rock_dark", "4e4236"))
    px[:hl, :hl, :3] = rock_dk + (rock - rock_dk) * np.clip(n * 1.3 - 0.15, 0, 1)[..., None]
    # crystal ring: radial facets about the cell's middle, light and dark
    cx, cy = xx - 0.5, yy - 0.5
    ang = np.arctan2(cy, cx)
    fac = (np.sin(ang * 22.0) * 0.5 + 0.5) * np.clip(np.hypot(cx, cy) * 2.0, 0, 1)
    rim, rim_dk = hexcol(spec.get("rim", "c9b4c4")), hexcol(spec.get("rim_dark", "5a3f5e"))
    px[:hl, hl:, :3] = rim_dk + (rim - rim_dk) * fac[..., None]
    # iris: hot yellow at its middle to deep orange at its edge
    d = np.clip(np.hypot(cx, cy) * 2.0, 0, 1)[..., None]
    hot, iris = hexcol(spec.get("iris_hot", "ffe27a")), hexcol(spec.get("iris", "ff8a1c"))
    px[hl:, :hl, :3] = hot * (1 - d) + iris * d
    px[hl:, hl:, :3] = hexcol(spec.get("pupil", "2a0d04"))
    img.pixels = px.ravel()
    img.pack()
    return img


# ------------------------------------------------------------------------------------------------ orbiting props
def _lumpy(bld, centre, frame, radii, part, uv_box, seed, rings=7, sides=12, lump=0.18):
    """A rough rock: a squashed sphere (radii along the frame's axes) with lumpy noise, as a tube capped at both
    poles (u around, v pole to pole)."""
    rng = np.random.default_rng(seed)
    e1, e2, e3 = (np.asarray(a, np.float64) for a in frame)     # e3: the face's normal (the flat axis)
    noise = rng.uniform(1.0 - lump, 1.0 + lump * 0.4, (rings + 2, sides + 1))
    noise[:, -1] = noise[:, 0]
    base = len(bld.v)
    u0, v0, u1, v1 = uv_box
    for i in range(rings + 2):
        t = math.pi * i / (rings + 1)               # 0: the back pole .. pi: the front pole
        for j in range(sides + 1):
            a = 2.0 * math.pi * j / sides
            k = noise[i, j] if 0 < i < rings + 1 else 1.0
            d = (math.sin(t) * (math.cos(a) * e1 * radii[0] + math.sin(a) * e2 * radii[1]) - math.cos(t) * e3 * radii[2])
            bld.v.append(np.asarray(centre) + d * k)
            bld.uv.append((u0 + (u1 - u0) * j / sides, v0 + (v1 - v0) * i / (rings + 1)))
            bld.part.append(part)
            bld.s.append(0.0)
    row = sides + 1
    for i in range(rings + 1):
        for j in range(sides):
            a = base + i * row + j
            bld.f.append((a, a + 1, a + row + 1, a + row))


def _disc(bld, centre, nrm, r, part, uv_box, sides=16, dome=0.25):
    nrm = np.asarray(nrm, np.float64)
    ref = np.array([0.0, 0.0, 1.0]) if abs(nrm[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    e1 = np.cross(nrm, ref)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(nrm, e1)
    u0, v0, u1, v1 = uv_box
    c = len(bld.v)
    bld.v.append(np.asarray(centre) + nrm * r * dome)
    bld.uv.append(((u0 + u1) * 0.5, (v0 + v1) * 0.5))
    bld.part.append(part)
    bld.s.append(0.0)
    for j in range(sides):
        a = 2.0 * math.pi * j / sides
        bld.v.append(np.asarray(centre) + r * (math.cos(a) * e1 + math.sin(a) * e2))
        bld.uv.append((u0 + (u1 - u0) * (0.5 + 0.5 * math.cos(a)), v0 + (v1 - v0) * (0.5 + 0.5 * math.sin(a))))
        bld.part.append(part)
        bld.s.append(0.0)
    for j in range(sides):
        bld.f.append((c, c + 1 + j, c + 1 + (j + 1) % sides))


def orbit_props(arm, spec):
    """Stones that float on an orbit round a bone (Tarek's three seeing-stones round his head): each a rough
    geode, its glowing iris (the `glow` slot, with a slit pupil) on the side facing out from the orbit's
    centre and its back plain rock. Every stone is its own unskinned mesh under one empty `spec["name"]`
    (an `orbit_` name) that rides the bone; WardenGlb.Orbits turns that empty round its up axis and bobs each
    stone, so the orbit is data, not baked. Returns [empty, stones...]."""
    c = Vector(spec["centre"])
    e = bpy.data.objects.new(spec["name"], None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = spec.get("bone", "head")
    bpy.context.view_layer.update()
    e.matrix_world = Matrix.Translation(c)
    img = _stone_cells(128, spec, spec["name"] + "_cells")
    out = [e]
    for i, it in enumerate(spec["items"]):
        a = math.radians(float(it["angle"]))           # 0: in front of the face (+Y), counter-clockwise from above
        out_dir = np.array([-math.sin(a), math.cos(a), 0.0])
        p = np.array(c[:]) + out_dir * float(it.get("radius", spec.get("radius", 0.4))) \
            + np.array([0.0, 0.0, float(it.get("height", 0.0))])
        r = float(it.get("size", 0.07))
        up = np.array([0.0, 0.0, 1.0])
        side = np.cross(up, out_dir)
        bld = Builder()
        # (the rock: flat along the outward axis, so its face meets the eye; its rim and iris on the front)
        # (the cells of _quads_uv: rock bottom-left, rim bottom-right, iris top-left, pupil top-right)
        kind = spec.get("kind", "eye")
        if kind == "card":
            # (a playing-card shard: a thin flat slab facing out, on a glowing string back to the orbit's centre;
            # `card_tilt` leans its face up toward the high match camera, so it is never seen only edge-on)
            tl = math.radians(float(spec.get("card_tilt", 0.0)))
            face = out_dir * math.cos(tl) + up * math.sin(tl)
            cup = up * math.cos(tl) - out_dir * math.sin(tl)
            bld.prism(p - cup * r * 0.7, p + cup * r * 0.7, r * 0.5, 4, (0.55, 0.05, 0.95, 0.45), "rim", 0.0, rot=0.785)
            for q in range(len(bld.v) - 12, len(bld.v)):
                d = np.asarray(bld.v[q]) - p
                bld.v[q] = p + d - face * d.dot(face) * 0.85
            sr = float(spec.get("string_r", 0.0025))
            bld.tube([np.array(c[:]), p], [sr, sr], 4, 0.05, 0.45, 0.55, 0.95, "iris", [0.0, 0.0])
        if kind != "card":
            # (a geode: the rough rock, a raised rim round its cut face, a ring of crystals sunk inside it, and the
            # eye's domed iris standing out of the crystals; "rock": the rough rock alone, a shard)
            _lumpy(bld, p, (side, up, -out_dir), (r, r * 1.08, r * float(spec.get("depth", 0.66))), "rock",
                   (0.05, 0.05, 0.45, 0.45), 7 + i, rings=9, sides=16, lump=0.26)
        if kind != "eye":
            ob = bld.object("%s_%d" % (spec["name"], i))
            mi = {"rock": _flat_material(ob, spec.get("slot", "leather"), spec["name"], img, "Closest")}
            mi["rim"] = mi["rock"]
            mi["iris"] = _flat_material(ob, "glow", spec["name"], img, "Closest")
            for poly in ob.data.polygons:
                poly.material_index = mi[bld.part[poly.vertices[0]]]
            ob.data.transform(Matrix.Translation(-Vector(p)))
            ob.matrix_world = Matrix.Translation(Vector(p))
            mw = ob.matrix_world.copy()
            ob.parent = e
            ob.matrix_world = mw
            out.append(ob)
            if spec.get("anchors"):
                # (an anchor on each prop: the game hangs a match-zoom glow on it, warden_look.json "halos")
                an = bpy.data.objects.new("anchor_%s_%d" % (spec["name"], i), None)
                bpy.context.scene.collection.objects.link(an)
                an.parent = ob
                an.matrix_world = Matrix.Translation(Vector(p))
            continue
        # (the opening on the rock's outer face, wherever `depth` puts it, so a rounder rock never hides it)
        fz = float(spec.get("depth", 0.66)) * 0.88
        oz = fz - 0.16
        bld.torus(p + out_dir * r * fz, out_dir, r * 0.68, r * 0.14, 18, 6, (0.05, 0.05, 0.45, 0.45), "rock", 0.0)
        _disc(bld, p + out_dir * r * fz, out_dir, r * 0.68, "rim", (0.55, 0.05, 0.95, 0.45), dome=-0.18)
        _disc(bld, p + out_dir * r * oz, out_dir, r * float(spec.get("iris_r", 0.4)), "iris", (0.05, 0.55, 0.45, 0.95),
              dome=0.45)
        bld.prism(p + out_dir * r * (oz + 0.2) - up * r * 0.24, p + out_dir * r * (oz + 0.2) + up * r * 0.24, r * 0.06, 4,
                  (0.55, 0.55, 0.95, 0.95), "pupil", 0.0)
        ob = bld.object("%s_%d" % (spec["name"], i))
        mi = {"rock": _flat_material(ob, spec.get("slot", "leather"), spec["name"], img, "Closest")}
        mi["rim"] = mi["rock"]
        mi["pupil"] = mi["rock"]
        mi["iris"] = _flat_material(ob, "glow", spec["name"], img, "Closest")
        for poly in ob.data.polygons:
            poly.material_index = mi[bld.part[poly.vertices[0]]]
        # (its origin on its own centre, so the prop node itself circles and bobs)
        ob.data.transform(Matrix.Translation(-Vector(p)))
        ob.matrix_world = Matrix.Translation(Vector(p))
        mw = ob.matrix_world.copy()
        ob.parent = e
        ob.matrix_world = mw
        out.append(ob)
        if spec.get("anchors"):
            # (an empty on the eye, anchor_<name>_<i>, for a glow halo at the match camera; it rides the stone)
            an = bpy.data.objects.new("anchor_%s_%d" % (spec["name"].replace("orbit_", ""), i), None)
            bpy.context.scene.collection.objects.link(an)
            an.parent = ob
            an.location = Vector(out_dir * r * (fz + 0.05))
            out.append(an)
    log("orbit %s: %d props round %s" % (spec["name"], len(spec["items"]), tuple(round(x, 3) for x in c)))
    return out


# ------------------------------------------------------------------------------------------------ crescent halo
def crescent(arm, spec, tag="halo"):
    """A crescent moon (Ostra's cracked halo) behind the head: a tube along an arc whose thickness swells in the
    middle and tapers to points, in the plane facing `normal`, riding `bone` rigidly; its own small atlas
    (the colour by `slot`, `glow` for a glowing one)."""
    c = np.array(spec["centre"], np.float64)
    nrm = np.array(spec.get("normal", [0.0, 1.0, 0.0]), np.float64)
    nrm /= np.linalg.norm(nrm)
    R = float(spec["r"])
    th = float(spec.get("thick", R * 0.18))
    a0, a1 = math.radians(spec.get("from", 200.0)), math.radians(spec.get("to", 520.0))
    up = np.array([0.0, 0.0, 1.0]) - nrm * nrm[2]
    up /= np.linalg.norm(up)
    rt = np.cross(up, nrm)
    k = 40
    rings, radii = [], []
    for i in range(k):
        f = i / (k - 1)
        a = a0 + (a1 - a0) * f
        rings.append(c + R * (math.cos(a) * rt + math.sin(a) * up))
        radii.append(max(1e-4, th * math.sin(math.pi * f) ** 0.8))
    bld = Builder()
    bld.tube(rings, radii, 10, 0.0, 1.0, 0.0, 1.0, "moon", [0.0] * k, cap_end=True, cap_start=True)
    # (squash the tube flat across the plane: a moon's crescent, not a ring of pipe)
    for i, v in enumerate(bld.v):
        d = np.asarray(v) - c
        bld.v[i] = c + d - nrm * d.dot(nrm) * (1.0 - float(spec.get("flat", 0.35)))
    ob = bld.object(tag.capitalize())
    n = int(spec.get("atlas", 64))
    img = bpy.data.images.new(tag + "_atlas", n, n, alpha=False)
    px = np.ones((n, n, 4), np.float32)
    yy, xx = np.mgrid[0:n, 0:n] * (64.0 / n)
    base, crack = hexcol(spec.get("colour", "d9b8ff")), hexcol(spec.get("crack", "8a4ad8"))
    # a few dark crack lines across the moon (u around the tube, v along the arc)
    lines = (np.abs(((yy * 0.37 + xx * 0.11) % 13) - 6.5) < float(spec.get("crack_w", 0.6))) & (xx % 21 < 15)
    col = np.broadcast_to(base, (n, n, 3)).copy()
    if spec.get("core"):
        # (the glow's falloff: a pale core along the moon's faces, deepening to the violet rim at its edges)
        f = (0.5 + 0.5 * np.cos(xx / 63.0 * 4.0 * math.pi))[..., None] ** 1.5
        col = base * (1 - f) + hexcol(spec["core"]) * f
    if spec.get("cracks"):
        # (jagged cracks across the moon, each from one edge toward the other with a fork, as the cap_halo sheet
        # draws them; v along the arc is the atlas's rows, u round the flattened tube its columns)
        rng = np.random.default_rng(int(spec.get("seed", 5)))
        lines = np.zeros((n, n), bool)
        sc = n / 64.0
        for k in range(int(spec["cracks"])):
            y = (k + 0.5 + rng.uniform(-0.25, 0.25)) * n / int(spec["cracks"])
            fy = y
            for x in range(n):
                y += rng.uniform(-1.0, 1.0) * float(spec.get("crack_jitter", 1.1)) * sc
                for t in range(max(1, int(sc * float(spec.get("crack_rows", 0.8))))):
                    lines[int(y + t) % n, x] = True
                if x == int(30 * sc):
                    fy = y
                if int(30 * sc) < x < int(48 * sc):
                    fy += rng.uniform(0.2, 1.4) * sc
                    lines[int(fy) % n, x] = True
    px[..., :3] = np.where(lines[..., None], crack, col)
    img.pixels = px.ravel()
    img.pack()
    _flat_material(ob, spec.get("slot", "glow"), tag, img)
    _rigid(ob, arm, spec.get("bone", "head"))
    log("%s: r %.3f at %s, %d tris" % (tag, R, tuple(round(x, 3) for x in c), sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ wisp
def wisp(arm, spec, tag="wisp"):
    """A smoky tail a hovering body dissolves into (Ostra below his coat): a tube along a curling path from
    `path`[0] (up inside the hem) down to a point, plus thinner tendrils peeling off it, all on one spring chain
    `spring_<tag>_*` under `parent` (hips) so it trails and swings. Material `void-<tag>`: WardenGlb draws the
    `void` slot with the starfield shader, soft (fading to nothing toward the tip, v = 1) for this tag."""
    p, _l = resample(np.array(spec["path"], np.float64), 40)
    s_arr = arclen(p)
    L = s_arr[-1]
    r0, r1 = float(spec.get("r_top", 0.2)), float(spec.get("r_tip", 0.015))
    bld = Builder()
    fr = s_arr / L
    radii = r1 + (r0 - r1) * (1.0 - fr) ** float(spec.get("taper", 1.3))
    # (v runs 1 at the top to 0 at the tip here: the glTF export flips v, so the game sees 0 at the top and 1 at
    # the tip, where hero_void.gdshader's soft fade wants it)
    bld.tube(p, radii, 18, 0.0, 1.0, 1.0, 0.0, "wisp", list(s_arr), cap_end=True)
    for j, td in enumerate(spec.get("tendrils", [])):
        t0 = float(td["from"]) * L
        q0 = at(p, s_arr, t0)
        d = np.array(td["dir"], np.float64)
        n = 12
        pts, rr, ss = [], [], []
        for i in range(n):
            f = i / (n - 1)
            curl = np.array([math.sin(f * 3.0 + j), math.cos(f * 3.0 + j), 0.0]) * float(td.get("curl", 0.05)) * f
            pts.append(q0 + d * f + curl)
            rr.append(float(td.get("r", 0.05)) * (1.0 - 0.9 * f))
            ss.append(min(L, t0 + f * np.linalg.norm(d)))
        # (the tendril's v runs on from where it leaves the tail, so the fade carries on along it)
        bld.tube(pts, rr, 8, 0.0, 1.0, 1.0 - float(td["from"]), 0.0, "tendril", ss, cap_end=True)
    ob = bld.object(tag.capitalize())
    img = bpy.data.images.new(tag + "_atlas", 32, 32, alpha=False)
    px = np.ones((32, 32, 4), np.float32)
    top, tip = hexcol(spec.get("colour", "5a2a8a")), hexcol(spec.get("tip", "9a5ad8"))
    v = (np.arange(32) / 31.0)[:, None, None]
    px[..., :3] = tip * (1 - v) + top * v
    img.pixels = px.ravel()
    img.pack()
    _flat_material(ob, "void", tag, img)
    names, spans = chain_bones(arm, tag, spec.get("parent", "hips"), p, L, int(spec.get("bones", 4)), p[-1])
    weights(ob, list(enumerate(bld.s)), names, spans)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("%s: length %.2f, %d tendrils, %d tris" % (tag, L, len(spec.get("tendrils", [])), sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ studs
def studs(body, arm, spec):
    """Small props seeded on the body's surface (Tarek's glowing amber crystals among his locs): `count`
    elongated octahedra on faces of the slot `on` (its material name's slot) whose centre is in `box` (fitted
    frame), standing out along the face's normal, each skinned as the face's first vertex is (so it rides that
    loc). Material "<slot>-<name>" (glow by default) in one flat colour."""
    rng = np.random.default_rng(int(spec.get("seed", 1)))
    b = [(-1e9, 1e9)[i % 2] if x is None else x for i, x in enumerate(spec.get("box", [None] * 6))]
    on = [i for i, m in enumerate(body.data.materials) if m and m.name.split("-")[0] == spec.get("on", "hair")]
    cand = [p for p in body.data.polygons if p.material_index in on and b[0] <= p.center.x <= b[1]
            and b[2] <= p.center.y <= b[3] and b[4] <= p.center.z <= b[5] and p.normal.length > 0.5]
    n = min(int(spec.get("count", 10)), len(cand))
    if n == 0:
        log("studs %s: no faces to sit on" % spec["name"])
        return None
    pick = []
    for i in rng.permutation(len(cand)):
        p = cand[int(i)]
        if all((p.center - q.center).length > float(spec.get("spacing", 0.06)) for q in pick):
            pick.append(p)
        if len(pick) >= n:
            break
    r = float(spec.get("size", 0.016))
    bld = Builder()
    owners = []
    for p in pick:
        nrm = np.array(p.normal[:])
        c = np.array(p.center[:]) + nrm * r * 0.6
        ref = np.array([0.0, 0.0, 1.0]) if abs(nrm[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        e1 = np.cross(nrm, ref)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(nrm, e1)
        base = len(bld.v)
        tip = float(spec.get("tip", 1.6))       # (how far it stands out: 1.6 a crystal spike, ~0.8 a round bead)
        for d in (nrm * r * tip, -nrm * r * 0.4, e1 * r, -e1 * r, e2 * r * 0.7, -e2 * r * 0.7):
            bld.v.append(c + d)
            bld.uv.append((0.5, 0.5))
            bld.part.append("stud")
            bld.s.append(0.0)
        for a, bb, cc in ((0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2), (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5)):
            bld.f.append((base + a, base + bb, base + cc))
        owners.append(body.data.vertices[p.vertices[0]])
    ob = bld.object(spec["name"].capitalize())
    img = bpy.data.images.new(spec["name"] + "_atlas", 8, 8, alpha=False)
    px = np.ones((8, 8, 4), np.float32)
    px[..., :3] = hexcol(spec.get("colour", "ffb040"))
    img.pixels = px.ravel()
    img.pack()
    _flat_material(ob, spec.get("slot", "glow"), spec["name"], img, "Closest")
    groups = {g.index: g.name for g in body.vertex_groups}
    for k, vx in enumerate(owners):
        for x in vx.groups:
            g = ob.vertex_groups.get(groups[x.group]) or ob.vertex_groups.new(name=groups[x.group])
            g.add(list(range(k * 6, k * 6 + 6)), x.weight, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("studs %s: %d on %s" % (spec["name"], len(pick), spec.get("on", "hair")))
    return ob


def face_marks(target, arm, spec):
    """Painted-on glowing marks laid onto a part's surface as thin ribbons (Ostra's violet tear and the glowing
    crack on his mask: the projected art was a pixel-wide smudge there). Each mark is a polyline `pts` of [x, z]
    on the front view (the fitted rest frame: his right +X, front +Y), cast from the front onto `target`'s mesh
    and lifted `lift` off it; `w` its width (tapering to `tip_w` at its end), `bulb` a round drop at its end (the
    tear). On the glow slot in `colour`, rigid on `bone`."""
    from mathutils.bvhtree import BVHTree
    from mathutils import Vector as V
    tree = BVHTree.FromObject(target, bpy.context.evaluated_depsgraph_get())
    bld = Builder()
    lift = float(spec.get("lift", 0.0015))
    n_ok = 0
    for mk in spec["marks"]:
        hits = []
        for x, z in mk["pts"]:
            loc, nrm, _i, _d = tree.ray_cast(V((x, 1.0, z)), V((0.0, -1.0, 0.0)))
            if loc is not None:
                nv = np.array(nrm[:])
                if nv[1] < 0.0:
                    nv = -nv               # (toward the viewer, whichever way the scan's faces wind)
                hits.append((np.array(loc[:]) + nv * lift, nv))
        if len(hits) < 2:
            log("face mark %s: missed the surface" % mk.get("name", "?"))
            continue
        # (resample the polyline so the ribbon follows the surface between the given points)
        w0, w1 = float(mk.get("w", 0.004)), float(mk.get("tip_w", mk.get("w", 0.004) * 0.4))
        k = len(hits)
        base = len(bld.v)
        for i, (p, nv) in enumerate(hits):
            t = hits[min(i + 1, k - 1)][0] - hits[max(i - 1, 0)][0]
            t /= max(np.linalg.norm(t), 1e-9)
            sd = np.cross(t, nv)
            sd /= max(np.linalg.norm(sd), 1e-9)
            w = (w0 + (w1 - w0) * i / (k - 1)) * 0.5
            for sg in (-1.0, 1.0):
                bld.v.append(p + sd * w * sg)
                bld.uv.append((0.5, 0.5))
                bld.part.append("mark")
                bld.s.append(0.0)
        for i in range(k - 1):
            a = base + 2 * i
            bld.f.append((a, a + 1, a + 3, a + 2))
        if mk.get("bulb"):
            p, nv = hits[-1]
            r = float(mk["bulb"])
            c = len(bld.v)
            ref = np.array([1.0, 0.0, 0.0])
            e1 = np.cross(nv, ref)
            e1 /= max(np.linalg.norm(e1), 1e-9)
            e2 = np.cross(nv, e1)
            bld.v.append(p - np.array([0.0, 0.0, r * 0.6]))
            bld.uv.append((0.5, 0.5)); bld.part.append("mark"); bld.s.append(0.0)
            for j in range(12):
                a = 2.0 * math.pi * j / 12
                bld.v.append(p - np.array([0.0, 0.0, r * 0.6]) + r * (math.cos(a) * e1 + math.sin(a) * e2))
                bld.uv.append((0.5, 0.5)); bld.part.append("mark"); bld.s.append(0.0)
            for j in range(12):
                bld.f.append((c, c + 1 + j, c + 1 + (j + 1) % 12))
        n_ok += 1
    if not bld.v:
        return None
    ob = bld.object(spec.get("name", "marks").capitalize())
    img = bpy.data.images.new(spec.get("name", "marks") + "_atlas", 8, 8, alpha=False)
    px = np.ones((8, 8, 4), np.float32)
    px[..., :3] = hexcol(spec.get("colour", "b070ff"))
    img.pixels = px.ravel()
    img.pack()
    _flat_material(ob, spec.get("slot", "glow"), spec.get("name", "marks"), img, "Closest")
    _rigid(ob, arm, spec.get("bone", "head"))
    log("face marks on %s: %d of %d" % (target.name, n_ok, len(spec["marks"])))
    return ob


def claws(body, arm, spec):
    """Long claws on a scanned glove (Ostra's clawed fingers; Meshy rounds them off): for each hand in `sides`
    the body's fingertips are its vertices furthest along the hand bone (weighted to it), `count` of them at
    least `spacing` apart; on each a tapering curved spike `length` long (base radius `r`) carries the finger
    on outward and `curl`s toward the palm. Skinned rigidly to the hand bone. Material "<slot>-claws"."""
    bld = Builder()
    groups = {}
    for side in spec.get("sides", ["L", "R"]):
        bn = "hand." + side
        b = arm.data.bones[bn]
        h, t = np.array(b.head_local[:]), np.array(b.tail_local[:])
        d = (t - h) / max(np.linalg.norm(t - h), 1e-9)
        vg = body.vertex_groups.get(bn)
        if vg is None:
            continue
        pts = []
        for vx in body.data.vertices:
            for gr in vx.groups:
                if gr.group == vg.index and gr.weight > float(spec.get("min_w", 0.5)):
                    pts.append(np.array(vx.co[:]))
        if not pts:
            log("claws: no vertices on %s" % bn)
            continue
        pts = np.array(pts)
        proj = (pts - h) @ d
        centroid = pts.mean(axis=0)
        order = np.argsort(-proj)
        picks = []
        lim = proj.max() - float(spec.get("depth", 0.06))
        for i in order:
            if proj[i] < lim:
                break
            if all(np.linalg.norm(pts[i] - q) > float(spec.get("spacing", 0.018)) for q in picks):
                picks.append(pts[i])
            if len(picks) >= int(spec.get("count", 5)):
                break
        L, r0, curl = float(spec.get("length", 0.08)), float(spec.get("r", 0.006)), float(spec.get("curl", 0.35))
        m = 7
        start = len(bld.v)
        for tip in picks:
            out = tip - h
            out /= max(np.linalg.norm(out), 1e-9)
            fwd = 0.6 * d + 0.4 * out
            fwd /= np.linalg.norm(fwd)
            palm = centroid - tip
            palm -= fwd * palm.dot(fwd)
            palm /= max(np.linalg.norm(palm), 1e-9)
            rings = [tip - fwd * r0 * 1.5 + fwd * L * (i / (m - 1)) + palm * curl * L * (i / (m - 1)) ** 2
                     for i in range(m)]
            radii = [max(r0 * 0.06, r0 * (1.0 - i / (m - 1)) ** 0.8) for i in range(m)]
            bld.tube(rings, radii, 6, 0.1, 0.9, 0.1, 0.9, "claw", [0.0] * m, cap_start=True, cap_end=True)
        groups[bn] = (start, len(bld.v))
        log("claws on %s: %d" % (bn, len(picks)))
    if not bld.v:
        return None
    ob = bld.object("Claws")
    img = bpy.data.images.new("claws_atlas", 8, 8, alpha=False)
    px = np.ones((8, 8, 4), np.float32)
    px[..., :3] = hexcol(spec.get("colour", "120d18"))
    img.pixels = px.ravel()
    img.pack()
    _flat_material(ob, spec.get("slot", "leather"), "claws", img, "Closest")
    for bn, (a, z) in groups.items():
        g = ob.vertex_groups.new(name=bn)
        g.add(list(range(a, z)), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def orb(arm, spec, tag="orb"):
    """A hand-held orb (Ostra's swirling void orb): a sphere on the `void` slot (the starfield, opaque) inside a
    thin glowing ring (glow), or with style "glow" one glowing sphere, at `centre`, riding `bone` rigidly."""
    c = np.array(spec["centre"], np.float64)
    r = float(spec.get("r", 0.05))
    bld = Builder()
    k = 10
    rings = [c + np.array([0.0, 0.0, -r + 2.0 * r * i / (k - 1)]) for i in range(k)]
    radii = [max(1e-4, r * math.sin(math.pi * i / (k - 1))) for i in range(k)]
    glow_ball = spec.get("style") == "glow"     # (one glowing sphere: what reads at the match camera)
    if spec.get("style") == "vortex":
        return _vortex(arm, spec, tag, c, r)
    bld.tube(rings, radii, 14, *((0.55, 0.95, 0.05, 0.95) if glow_ball else (0.05, 0.45, 0.05, 0.95)), "ring" if glow_ball
             else "ball", [0.0] * k, cap_end=True, cap_start=True)
    if not glow_ball:
        # (a black hole: the dark ball inside bright rings; several crossed rings read as a glowing rim from any side)
        for k_i, nv in enumerate(spec.get("rings", [spec.get("normal", [0.0, 1.0, 0.0])])):
            nrm = np.array(nv, np.float64)
            bld.torus(c, nrm / np.linalg.norm(nrm), r * (1.1 + 0.06 * k_i), r * 0.16, 24, 6, (0.55, 0.05, 0.95, 0.95),
                      "ring", 0.0)
    ob = bld.object(tag.capitalize())
    img = bpy.data.images.new(tag + "_atlas", 64, 64, alpha=False)
    px = np.ones((64, 64, 4), np.float32)
    px[:, :32, :3] = hexcol(spec.get("colour", "1a0c2e"))
    px[:, 32:, :3] = hexcol(spec.get("colour" if glow_ball else "ring", "b07cff"))
    if spec.get("swirl"):
        # (a swirl on the glowing ball: bright violet arms winding into a dark core, u round it, v pole to pole)
        yy, xx = np.mgrid[0:64, 0:32]
        u, v = xx / 31.0, yy / 63.0
        spiral = 0.5 + 0.5 * np.sin(u * 2.0 * math.pi * 3.0 + v * 14.0)
        core = np.exp(-((v - 0.5) / 0.18) ** 2)
        k = np.clip(spiral * (1.0 - 0.8 * core), 0.0, 1.0)[..., None]
        dark, lit = hexcol(spec.get("dark", "12081f")), hexcol(spec["swirl"])
        px[:, 32:, :3] = dark * (1 - k) + lit * k
    img.pixels = px.ravel()
    img.pack()
    vi = _flat_material(ob, "void", tag, img)
    gi = _flat_material(ob, "glow", tag, img)
    for poly in ob.data.polygons:
        poly.material_index = gi if bld.part[poly.vertices[0]] == "ring" else vi
    _rigid(ob, arm, spec.get("bone", "hand.R"))
    log("%s on %s, r %.3f" % (tag, spec.get("bone", "hand.R"), r))
    return ob


def _vortex(arm, spec, tag, c, r):
    """Ostra's void orb as the art draws it: a black core (`core` x r) with `arms` glowing violet spiral arms
    winding into it (log spirals in the plane facing `normal`, each a tapering tube, dim at its outer end and hot
    where it falls into the core), a little out of the plane by turns so it reads from the side too."""
    bld = Builder()
    rc = r * float(spec.get("core", 0.62))
    k = 10
    rings = [c + np.array([0.0, 0.0, -rc + 2.0 * rc * i / (k - 1)]) for i in range(k)]
    radii = [max(1e-4, rc * math.sin(math.pi * i / (k - 1))) for i in range(k)]
    bld.tube(rings, radii, 14, 0.05, 0.45, 0.05, 0.95, "ball", [0.0] * k, cap_end=True, cap_start=True)
    nrm = np.array(spec.get("normal", [0.0, 0.8, 0.6]), np.float64)
    nrm /= np.linalg.norm(nrm)
    e1 = np.cross(nrm, [0.0, 0.0, 1.0]) if abs(nrm[2]) < 0.95 else np.array([1.0, 0.0, 0.0])
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(nrm, e1)
    n_arms, sweep = int(spec.get("arms", 3)), float(spec.get("sweep", 1.5)) * math.pi
    r_out, r_in, th = r * float(spec.get("reach", 1.55)), rc * 0.92, r * float(spec.get("arm_r", 0.13))
    m = 18
    for a in range(n_arms):
        a0 = 2.0 * math.pi * a / n_arms
        if spec.get("planes"):
            # (each arm in its own plane, turned about the vertical through the core: a swirl from every side)
            tilt = math.pi * a / n_arms
            ct, st = math.cos(tilt), math.sin(tilt)
            n2 = np.array([nrm[0] * ct - nrm[1] * st, nrm[0] * st + nrm[1] * ct, nrm[2]])
            if spec.get("plane_normals"):
                n2 = np.array(spec["plane_normals"][a % len(spec["plane_normals"])], np.float64)
                n2 /= np.linalg.norm(n2)
            e1 = np.cross(n2, [0.0, 0.0, 1.0]) if abs(n2[2]) < 0.95 else np.array([1.0, 0.0, 0.0])
            e1 /= np.linalg.norm(e1)
            e2 = np.cross(n2, e1)
        pts, rad = [], []
        for i in range(m):
            t = i / (m - 1)
            rr = r_out * (r_in / r_out) ** t                     # (a log spiral: out -> in)
            ang = a0 + sweep * t
            lift = 0.25 * r * math.sin(math.pi * t) * (1 if a % 2 else -1)
            pts.append(c + rr * (math.cos(ang) * e1 + math.sin(ang) * e2) + lift * nrm)
            rad.append(max(th * 0.15, th * math.sin(math.pi * min(1.0, 0.15 + t)) * (0.45 + 0.55 * t)))
        bld.tube(pts, rad, 6, 0.55, 0.95, 0.05, 0.95, "ring", [0.0] * m, cap_end=True, cap_start=True)
    if spec.get("orbit_ring"):
        # (a glowing ring through the card orbit round the orb: the cards and their strings read as one shape at
        # the match camera, where each card alone is a pixel)
        rr, rt = spec["orbit_ring"]
        bld.torus(c, np.array([0.0, 0.0, 1.0]), float(rr), float(rt), 32, 6, (0.55, 0.05, 0.95, 0.95), "ring", 0.0)
    ob = bld.object(tag.capitalize())
    img = bpy.data.images.new(tag + "_atlas", 64, 64, alpha=False)
    px = np.ones((64, 64, 4), np.float32)
    px[:, :32, :3] = hexcol(spec.get("colour", "05020a"))
    v = (np.arange(64) / 63.0)[:, None, None]
    dim, hot = hexcol(spec.get("ring", "6a32c0")), hexcol(spec.get("hot", "e0c0ff"))
    px[:, 32:, :3] = dim[None, None] * (1 - v ** 1.5) + hot[None, None] * v ** 1.5
    img.pixels = px.ravel()
    img.pack()
    vi = _flat_material(ob, spec.get("core_slot", "void"), tag, img)
    gi = _flat_material(ob, "glow", tag, img)
    for poly in ob.data.polygons:
        poly.material_index = gi if bld.part[poly.vertices[0]] == "ring" else vi
    _rigid(ob, arm, spec.get("bone", "hand.R"))
    log("%s vortex on %s, r %.3f, %d arms" % (tag, spec.get("bone", "hand.R"), r, n_arms))
    return ob

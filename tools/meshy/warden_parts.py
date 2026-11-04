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
STRAND_COLS = 6       # texture columns: 2 braids x 3 strands, each 0.125 wide on the left 3/4 of the atlas


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
    for k in range(3):
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
        col = dark[None, None] * (1 - a[..., None]) + lit[None, None] * a[..., None]
        if part in ("strand", "tuft"):
            lines = 0.9 + 0.1 * np.sin(xx * (2 * math.pi / 9.0) + np.sin(yy * 0.05) * 2.0)
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
    img = bpy.data.images.new(tag + "_atlas", 64, 64, alpha=False)
    px = np.ones((64, 64, 4), np.float32)
    px[:32, :32, :3] = hexcol(spec.get("rim", "b08a48"))          # (the rim's quarter)
    yy, xx = np.mgrid[0:32, 0:32]
    v = yy / 31.0                                                   # 0 at the lens's edge ring, 1 at its middle
    glow = hexcol(spec.get("glow", "6dff5a"))
    dark = hexcol(spec.get("pupil", "103a14"))
    ring = np.exp(-((v - 0.55) / 0.12) ** 2)[..., None]
    lens_col = glow[None, None] * (1 - 0.75 * ring) + dark[None, None] * 0.75 * ring
    lens_col = np.where((v > 0.92)[..., None], np.ones(3) * 0.95 + glow * 0.05, lens_col)
    px[32:, 32:, :3] = lens_col
    px[:32, 32:, :3] = hexcol(spec.get("rim", "b08a48"))
    px[32:, :32, :3] = glow
    img.pixels = px.ravel()
    img.pack()
    mats = {}
    for slot in ("metal", "glow"):
        m = bpy.data.materials.new("%s-%s" % (slot, tag))
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
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

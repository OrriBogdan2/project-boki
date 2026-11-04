"""A held bow as the Warden's `weapon` (RIG_CONTRACT: unskinned, in the Gun node's space) with its nocked arrow as
the child `weapon_mag` (the reload/draw's Mag), built in Blender by script from the art's own shapes (Pin r2:
docs/art/gen/wardens_r2/pin_turnaround + pin_side): a black lacquered recurve, faceted, its tips hooked forward,
the limbs flared into angled steel-grey fins where they leave the grip, red cord wrapped on the grip and under
each tip, a pale string; the arrow black-shafted with red fletching and a bone broadhead.

Frame (Blender, the Gun node's space): forward +Y (where the arrow flies), her right +X, up +Z. It matches the
procedural longbow (scripts/match/pin_bjorn_weapons.gd): the string on y = 0.06, the grip 0.13 in front of it
(the left hand's grip, HunterAnim's "_gun" hold), the arrow along +Y to the Muzzle (0.75).
Materials are flat colours named "<slot>-<tag>" (WardenGlb maps the slot to the toon surface).
"""
import math

import bmesh
import bpy
from mathutils import Vector

COL = {
    "lacquer": ("metal", "26252b"), "edge": ("metal", "5a5c66"), "wrap": ("cloth", "a8202f"),
    "wrap_dk": ("cloth", "6e1520"), "string": ("cloth", "d8d2c4"), "shaft": ("leather", "201f24"),
    "fletch": ("cloth", "b3202f"), "head": ("metal", "d8cbb0"), "horn": ("metal", "141418"),
}


def _mat(name):
    slot, hexc = COL[name]
    full = "%s-bow_%s" % (slot, name)
    m = bpy.data.materials.get(full)
    if m is None:
        m = bpy.data.materials.new(full)
        m.use_nodes = True
        c = tuple(int(hexc[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        lin = tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin + (1.0,)
        m.diffuse_color = lin + (1.0,)
    return m


class Builder:
    def __init__(self, name):
        self.bm = bmesh.new()
        self.mats = []
        self.name = name

    def mi(self, mat):
        m = _mat(mat)
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def loft(self, pts, sec, mat, caps=True):
        """A tube along pts (Vectors); sec(i) gives (half-width x, half-depth along the local normal, n sides)."""
        bm, mi = self.bm, self.mi(mat)
        rings = []
        for i, p in enumerate(pts):
            a = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
            t = a.normalized()
            side = Vector((1, 0, 0))
            nrm = t.cross(side).normalized()
            side = nrm.cross(t).normalized()
            hw, hd, n = sec(i)
            ring = []
            for k in range(n):
                ang = 2 * math.pi * (k + 0.5) / n
                ring.append(bm.verts.new(p + side * (math.cos(ang) * hw) + nrm * (math.sin(ang) * hd)))
            rings.append(ring)
        for r0, r1 in zip(rings[:-1], rings[1:]):
            n = len(r0)
            for k in range(n):
                f = bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
                f.material_index = mi
        if caps:
            for r in (rings[0], rings[-1][::-1]):
                f = bm.faces.new(r[::-1])
                f.material_index = mi

    def poly(self, vs, mat, thick):
        """A flat polygon (Vectors, one plane) given thickness along its normal."""
        bm, mi = self.bm, self.mi(mat)
        n = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized() * (thick / 2)
        a = [bm.verts.new(v + n) for v in vs]
        b = [bm.verts.new(v - n) for v in vs]
        bm.faces.new(a).material_index = mi
        bm.faces.new(b[::-1]).material_index = mi
        m = len(vs)
        for k in range(m):
            bm.faces.new((a[k], b[k], b[(k + 1) % m], a[(k + 1) % m])).material_index = mi

    def obj(self):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def _limb_profile(height, depth):
    """(z, forward) along the bow, tip to tip: the string's line is forward 0, the grip `depth` in front."""
    h = height / 2
    key = [(0.0, 1.0), (0.12, 1.0), (0.3, 1.12), (0.5, 1.05), (0.7, 0.72), (0.86, 0.3), (0.93, 0.06),
           (0.97, 0.02), (1.0, 0.16), (1.04, 0.38)]
    out = []
    for s in (-1, 1):
        seq = key if s > 0 else key[::-1]
        for u, f in seq:
            if s < 0 and u == 0.0:
                continue
            out.append((s * u * h, f * depth))
    out.sort(key=lambda p: p[0])
    return out


def build_bow(height=1.25, depth=0.13, string_y=0.06, x=0.0):
    b = Builder("weapon")
    prof = _limb_profile(height, depth)
    h = height / 2

    def pt(z, f):
        return Vector((x, string_y + f, z))

    # the limbs (faceted: 6 sides), widest and thickest at the grip, thin at the tips
    zs = [p[0] for p in prof]
    dense = []
    for (z0, f0), (z1, f1) in zip(prof[:-1], prof[1:]):
        for k in range(4):
            t = k / 4
            dense.append((z0 + (z1 - z0) * t, f0 + (f1 - f0) * t))
    dense.append(prof[-1])
    pts = [pt(z, f) for z, f in dense]

    def sec(i):
        u = min(abs(dense[i][0]) / h, 1.05)
        w = 0.022 * (1.0 - 0.55 * u) + 0.006
        d = 0.016 * (1.0 - 0.5 * u) + 0.005
        return (w, d, 6)
    b.loft(pts, sec, "lacquer")
    # the hooked horn tips past the string's knot
    for s in (-1, 1):
        tip = [pt(s * (h * 0.99), depth * 0.12), pt(s * (h * 1.03), depth * 0.32), pt(s * (h * 1.05), depth * 0.6),
               pt(s * (h * 1.04), depth * 0.85)]
        b.loft(tip, lambda i: (0.009 - 0.0018 * i, 0.008 - 0.0015 * i, 6), "horn")
    # the grip wrap and the cord under each tip (red, in bands)
    def wrap(z0, z1, r, bands):
        f = depth
        for k in range(bands):
            za = z0 + (z1 - z0) * k / bands
            zb = z0 + (z1 - z0) * (k + 0.85) / bands
            ff = dict(_interp(prof, za)), dict(_interp(prof, zb))
            pa, pb = pt(za, _f(prof, za)), pt(zb, _f(prof, zb))
            b.loft([pa, pb], lambda i: (r, r, 8), "wrap" if k % 2 == 0 else "wrap_dk")
    wrap(-0.1, 0.1, 0.031, 6)
    for s in (-1, 1):
        a, c = s * h * 0.78, s * h * 0.88
        wrap(min(a, c), max(a, c), 0.02, 3)
    # the angled fins where the limbs leave the grip (the art's steel-edged flare on the belly side)
    for s in (-1, 1):
        z0, z1, z2 = s * 0.1, s * 0.2, s * 0.32
        vs = [pt(z0, _f(prof, z0) - 0.02), pt(z1, _f(prof, z1) - 0.065), pt(z2, _f(prof, z2) - 0.012),
              pt(z1 * 0.9, _f(prof, z1) + 0.0)]
        b.poly([v + Vector((0, 0, 0)) for v in vs], "edge", 0.014)
    # the string, tip knot to tip knot
    knot = h * 0.97
    b.loft([pt(-knot, 0.0), pt(knot, 0.0)], lambda i: (0.0035, 0.0035, 4), "string")
    return b.obj()


def _f(prof, z):
    for (z0, f0), (z1, f1) in zip(prof[:-1], prof[1:]):
        if z0 <= z <= z1:
            return f0 + (f1 - f0) * (z - z0) / max(z1 - z0, 1e-9)
    return prof[-1][1]


def _interp(prof, z):
    return [("f", _f(prof, z))]


def build_arrow(x=0.022, nock_y=0.035, tip_y=0.78):
    b = Builder("weapon_mag")
    head0 = tip_y - 0.1
    b.loft([Vector((x, nock_y, 0)), Vector((x, head0 + 0.01, 0))], lambda i: (0.0055, 0.0055, 6), "shaft")
    # the nock's notch end, a little bone cap
    b.loft([Vector((x, nock_y - 0.012, 0)), Vector((x, nock_y + 0.005, 0))], lambda i: (0.007, 0.007, 6), "head")
    # three red vanes, swept back
    for k in range(3):
        a = math.pi / 2 + k * 2 * math.pi / 3
        d = Vector((0, 0, 0))
        d.x, d.z = math.cos(a), math.sin(a)
        p0 = Vector((x, nock_y + 0.02, 0))
        vs = [p0 + d * 0.006, p0 + Vector((0, 0.13, 0)) + d * 0.006, p0 + Vector((0, 0.1, 0)) + d * 0.03,
              p0 + Vector((0, 0.0, 0)) + d * 0.034]
        b.poly(vs, "fletch", 0.004)
    # the bone broadhead: a flat barbed leaf, edge-on to the bow, with a socket
    c = Vector((x, head0, 0))
    leaf = [c + Vector((0.0, -0.015, 0)), c + Vector((0.034, 0.012, 0)), c + Vector((0.016, 0.03, 0)),
            c + Vector((0.0, tip_y - head0, 0)), c + Vector((-0.016, 0.03, 0)), c + Vector((-0.034, 0.012, 0))]
    b.poly(leaf, "head", 0.006)
    b.loft([c + Vector((0, -0.03, 0)), c + Vector((0, 0.02, 0))], lambda i: (0.008, 0.008, 6), "head")
    return b.obj()

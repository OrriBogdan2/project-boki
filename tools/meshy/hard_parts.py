"""Pieces scripted in Blender for a fitted Warden (fit_warden.py spec `parts`; docs/art/wardens/PIPELINE.md
"Stage 1 hybrids"), in Blender 4.5:

- hammer(): Breaker's plain ice-block hammer (no pick, no anchor, no lantern): a block of glacier ice bound by two
  riveted iron bands on an oak haft with an iron socket, a leather grip and a pommel. Modelled in the space of the
  Gun node's "Hammer" pivot (meta hammer_pivot): the grip on the origin, the haft along -Z, the block's middle at
  (0, 0, -0.62) where BjornFx finds the head. It is the .glb's `weapon`; the loader seats it on that pivot.
- prow(): Breaker's prow shield: oak strakes on a keel facing out (-Z), iron rails down both edges and two riveted
  bands, an iron-shod foot, icicles, the faint green crack, and the stem post curling over the top into a scroll
  (the art's scroll top; the figurehead carved flat stays for the paint-over). Modelled in the space of the left
  hand's "Shield" node; the .glb's `shield`, seated there by the loader.
- spear(): Claire's slim ice spear (the `ice` slot), in the Gun node's space: the blade's tip just past the Muzzle.
- wings(): bat wings as flat cut-out cards (two layers) whose outline and paint come from the art's back view, each
  on a spring chain from her back that the game swings and folds while she skates (WardenGlb.Springs "wing").
- tail(): a spaded tail, a tube draped clear of the legs, on a spring chain from the hips.
- split(): faces of some slots (Claire's horns) made their own mesh, riding one bone rigidly.
- feet_forward(): the assert that each foot (skate) points the way the body faces.

Frames: the fitted frame (+Z up, the Warden's front +Y, its right +X, soles on Z = 0); a held piece in its rig
node's space, Godot (x, y, z) -> Blender (x, -z, y) (G()).
"""
import math
import os
import subprocess
import json

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import warden_parts as WP


def log(*a):
    print("HARDPARTS", *a, flush=True)


def G(x, y, z):
    """A point in a Godot node space -> the same point in Blender's (x, -z, y)."""
    return np.array([x, -z, y], np.float64)


# ------------------------------------------------------------------------------------------------ atlas
class Atlas:
    """A small texture of square cells, one per surface finish; each part's UVs land inside its cell."""

    def __init__(self, n, px=128):
        self.n, self.px = n, px
        self.img = np.zeros((n * px, n * px, 3), np.float32)
        self.cells = {}

    def cell(self, name, paint):
        """paint(u, v) -> (px, px, 3) over the cell's own 0..1 coordinates."""
        i = len(self.cells)
        cx, cy = i % self.n, i // self.n
        p = self.px
        yy, xx = np.mgrid[0:p, 0:p]
        u, v = (xx + 0.5) / p, (yy + 0.5) / p
        self.img[cy * p:(cy + 1) * p, cx * p:(cx + 1) * p] = paint(u, v)
        m = 1.5 / (self.n * p)          # (a texel and a half in from the cell's edge: no bleeding)
        self.cells[name] = (cx / self.n + m, cy / self.n + m, (cx + 1) / self.n - m, (cy + 1) / self.n - m)
        return self.cells[name]

    def image(self, name):
        s = self.n * self.px
        img = bpy.data.images.new(name, s, s, alpha=False)
        rgba = np.ones((s, s, 4), np.float32)
        rgba[..., :3] = np.clip(self.img, 0.0, 1.0)
        img.pixels = rgba.ravel()
        img.pack()
        return img


def hexcol(h):
    return np.array(WP.hexcol(h), np.float32)


def noise(u, v, k, seed):
    """Smooth value noise (a few octaves of sines), 0..1."""
    rnd = np.random.RandomState(seed)
    out = np.zeros_like(u)
    for o in range(4):
        f = k * (2 ** o)
        a, b, c = rnd.uniform(0, 6.283, 3)
        out += (np.sin(u * f + a + np.sin(v * f * 0.7 + b)) * np.cos(v * f + c)) / (2 ** o)
    return np.clip(out * 0.35 + 0.5, 0.0, 1.0)


def flat(col, var=0.06, seed=1, k=6.0):
    c = hexcol(col)
    return lambda u, v: c[None, None] * (1.0 - var + 2 * var * noise(u, v, k, seed))[..., None]


def ice_paint(u, v):
    """Glacier ice: a pale cyan body clouded with deeper blue, bright white streaks and a few dark cracks."""
    lo, mid, hi = hexcol("6fa6d6"), hexcol("a9d6f2"), hexcol("eef8ff")
    n = noise(u, v, 7.0, 3)
    col = lo[None, None] * (1 - n[..., None]) + mid[None, None] * n[..., None]
    streak = np.clip((noise(u * 1.3 + v * 0.4, v, 11.0, 5) - 0.72) / 0.12, 0, 1)[..., None]
    col = col * (1 - streak) + hi[None, None] * streak
    crack = np.exp(-((np.sin(u * 9.0 + np.sin(v * 7.0) * 1.6) * 0.5 + 0.5 - 0.5) / 0.03) ** 2)
    return col * (1 - 0.35 * crack[..., None])


def wood_paint(u, v, base="6e4a32", dark="4a2f1f", planks=4, frost=0.0):
    """Oak strakes: planks along v (seams across u), grain along them, frost creeping up from v = 1."""
    b, d = hexcol(base), hexcol(dark)
    grain = noise(u * 0.4, v * 6.0, 9.0, 7)
    col = b[None, None] * (0.82 + 0.3 * grain[..., None])
    seam = np.abs(((u * planks) % 1.0) - 0.5) > 0.47
    col[seam] = d
    if frost > 0:
        f = np.clip((v - (1 - frost)) / frost, 0, 1) * (0.6 + 0.4 * noise(u, v, 13.0, 9))
        col = col * (1 - f[..., None] * 0.7) + hexcol("dfeefa")[None, None] * f[..., None] * 0.7
    return col


def material(ob, slot, tag, img):
    m = bpy.data.materials.new("%s-%s" % (slot, tag))
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    ob.data.materials.append(m)
    return len(ob.data.materials) - 1


# ------------------------------------------------------------------------------------------------ primitives
def cuboid(bld, c, axes, half, uvb, part, bevel=0.0):
    """A box centred on c with its three (unit) axes and half sizes; each face's UVs fill the cell box uvb.
    bevel: the corners cut back that far (a chamfered block: 6 faces inset + the bevel strips, as quads)."""
    c = np.asarray(c, np.float64)
    ax = [np.asarray(a, np.float64) / np.linalg.norm(a) for a in axes]
    hx, hy, hz = half
    u0, v0, u1, v1 = uvb
    for k in range(3):
        for sg in (-1.0, 1.0):
            n = ax[k] * sg
            a, b = ax[(k + 1) % 3], ax[(k + 2) % 3]
            ha, hb = half[(k + 1) % 3] - bevel, half[(k + 2) % 3] - bevel
            ctr = c + n * half[k]
            base = len(bld.v)
            for (i, j) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                bld.v.append(ctr + a * ha * i + b * hb * j)
                bld.uv.append((u0 + (u1 - u0) * (i + 1) / 2, v0 + (v1 - v0) * (j + 1) / 2))
                bld.part.append(part)
                bld.s.append(0.0)
            f = (base, base + 1, base + 2, base + 3)
            bld.f.append(f if sg > 0 else f[::-1])
    if bevel > 0:
        # the chamfer: rebuild as one convex hull of the 24 face corners (bmesh) happens in finish()
        bld.hulls = getattr(bld, "hulls", []) + [(len(bld.v) - 24, len(bld.v))]


def spike(bld, base, tip, r, sides, uvb, part):
    """A cone from base (radius r) to tip, capped at the base."""
    rings = [base, base + (np.asarray(tip) - base) * 0.5, tip]
    bld.tube(rings, [r, r * 0.55, 1e-4], sides, uvb[0], uvb[2], uvb[1], uvb[3], part, [0.0] * 3, cap_start=True)


def finish(bld, name):
    """The Builder's object, with each chamfered box replaced by the convex hull of its corners, every piece
    turned outward by its signed volume."""
    hulls = getattr(bld, "hulls", [])
    ob = bld.object(name)
    if hulls:
        _hulls(ob, bld, hulls)
    outward(ob)
    return ob


def outward(ob):
    """Each connected piece's faces turned so its signed volume is positive (normals out); recalc_face_normals
    misjudges a slab whose rows collapse to a point (the prow's foot)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen = set()
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        comp, st = [], [f0]
        seen.add(f0.index)
        while st:
            f = st.pop()
            comp.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        st.append(g)
        vol = 0.0
        for f in comp:
            vs = [v.co for v in f.verts]
            for i in range(1, len(vs) - 1):
                vol += vs[0].dot(vs[i].cross(vs[i + 1]))
        if vol < 0:
            for f in comp:
                f.normal_flip()
    bm.to_mesh(ob.data)
    bm.free()


def _hulls(ob, bld, hulls):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    hull_edges = []
    for a, b in hulls:
        vs = [bm.verts[i] for i in range(a, b)]
        uvs = {v.index: bld.uv[v.index] for v in vs}
        old = set(f for v in vs for f in v.link_faces)
        bmesh.ops.delete(bm, geom=list(old), context="FACES_ONLY")
        res = bmesh.ops.convex_hull(bm, input=vs)
        for f in [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]:
            for lp in f.loops:
                lp[uvl].uv = uvs.get(lp.vert.index, (0.5, 0.5))
            hull_edges.extend(f.edges)
    # (the hull's coplanar triangles back into the box's faces)
    bmesh.ops.dissolve_limit(bm, angle_limit=0.01, verts=[], edges=list(set(e for e in hull_edges if e.is_valid)),
                             delimit={"UV"})
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def assign(ob, bld, slot_of_part, mats):
    for poly in ob.data.polygons:
        poly.material_index = mats[slot_of_part[bld.part[poly.vertices[0]]]]


def hard_edges(ob, deg=40.0):
    """Flat-shaded faces across sharp edges (iron and ice read as hard surface), smooth elsewhere."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for e in bm.edges:
        e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(deg))
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(ob.data)
    bm.free()


# ------------------------------------------------------------------------------------------------ hammer
def hammer(spec):
    """Breaker's ice-block hammer in the Hammer pivot's space (see the module doc), as the owner's hammer sheet
    draws it: a plain glacier-ice block in two rusty riveted ship-bands with icicles, an iron socket, a weathered
    haft wrapped in rope in two places, an iron end cap. No anchor, no pick."""
    at = Atlas(3)
    cells = {"ice": at.cell("ice", ice_paint), "iron": at.cell("iron", flat("4e5258", 0.1, 2)),
             "rust": at.cell("rust", flat("6a4434", 0.16, 5, 11.0)),
             "wood": at.cell("wood", lambda u, v: wood_paint(u, v, "6a543f", "463526", 1)),
             "rope": at.cell("rope", flat("8f7c5e", 0.12, 4, 18.0))}
    bld = WP.Builder()
    hz = float(spec.get("head_z", -0.62))
    L, W, D = (float(x) for x in spec.get("block", [0.19, 0.125, 0.13]))     # half: long (gun up), side, along the haft

    def ring(z0, z1, r, cell, part, sides=12):
        bld.tube([G(0, 0, z0), G(0, 0, z1)], [r, r], sides, *cells[cell][0::2], *cells[cell][1::2], part, [0, 0],
                 cap_end=True, cap_start=True)
    ring(0.30, 0.235, 0.036, "iron", "iron", 8)                           # the end cap
    ring(0.24, hz + D - 0.01, 0.026, "wood", "wood", 10)                  # the haft
    for z0 in (0.17, -0.2):                                               # the two rope wraps
        for i in range(6):
            bld.torus(G(0, 0, z0 - i * 0.022), G(0, 0.25, 1) - G(0, 0, 0), 0.028, 0.0075, 12, 5, cells["rope"],
                      "rope", 0.0)
    ring(hz + D + 0.07, hz + D - 0.005, 0.034, "rust", "rust")           # the socket
    # the block, chamfered, its long axis along the gun's up (it strikes with an end face)
    axes = [G(1, 0, 0), G(0, 1, 0), G(0, 0, 1)]
    cuboid(bld, G(0, 0, hz), axes, (W, L, D), cells["ice"], "ice", bevel=0.022)
    # two rusty ship-bands round the block, riveted
    t, w = 0.012, 0.024
    for yb in (-L * 0.45, L * 0.45):
        for (cx, cz, hx, hzz) in ((W + t / 2, 0, t / 2, D + t), (-W - t / 2, 0, t / 2, D + t),
                                  (0, D + t / 2, W + t, t / 2), (0, -D - t / 2, W + t, t / 2)):
            cuboid(bld, G(cx, yb, hz + cz), axes, (hx, w, hzz), cells["rust"], "rust")
        for sx in (-1, 1):
            for sz in (-0.6, 0.0, 0.6):
                bld.prism(G(sx * (W + t), yb, hz + sz * D), G(sx * (W + t + 0.009), yb, hz + sz * D), 0.008, 6,
                          cells["iron"], "iron", 0.0)
    # icicles off the block's haft side (they hang down while he carries it raised)
    for (x, y, ln) in ((-0.07, 0.15, 0.07), (0.05, 0.1, 0.05), (0.08, -0.16, 0.06), (-0.04, -0.12, 0.045),
                       (0.0, 0.17, 0.05), (-0.08, -0.05, 0.04)):
        spike(bld, G(x, y, hz + D - 0.004), G(x, y, hz + D + ln), 0.013, 5, cells["ice"], "ice")
    ob = finish(bld, "weapon")
    img = at.image("hammer_atlas")
    mats = {s: material(ob, s, "hammer", img) for s in ("metal", "leather", "ice")}
    assign(ob, bld, {"ice": "ice", "iron": "metal", "rust": "metal", "wood": "leather", "rope": "leather"}, mats)
    hard_edges(ob)
    log("hammer: %d tris" % sum(len(p.vertices) - 2 for p in ob.data.polygons))
    return ob


# ------------------------------------------------------------------------------------------------ prow
def prow(spec):
    """Breaker's prow shield in the Shield node's space (see the module doc)."""
    top, foot, depth = (float(x) for x in spec.get("hull", [0.42, -0.62, 0.13]))
    hw = float(spec.get("half_width", 0.25))
    th = 0.035
    at = Atlas(3)
    cells = {"face": at.cell("face", lambda u, v: wood_paint(u, v, "7b5235", "4a2e1d", 5, frost=0.3)),
             "back": at.cell("back", lambda u, v: wood_paint(u, v, "5d3e29", "3b2618", 5)),
             "iron": at.cell("iron", flat("5f6873", 0.08, 2)),
             "stem": at.cell("stem", lambda u, v: wood_paint(v, u, "65432b", "432a1b", 1)),
             "ice": at.cell("ice", ice_paint),
             "glow": at.cell("glow", flat("8dffc9", 0.02, 6))}

    def hull(u, v, off):
        y = top + (foot - top) * v
        w = hw * (1.0 - 0.12 * (y - 0.06) / (top - 0.06)) if y >= 0.06 else \
            hw * math.sqrt(max(0.0, 1.0 - ((y - 0.06) / (foot - 0.06)) ** 2))
        a = 2.0 * u - 1.0
        keel = (1.0 - a * a) ** 0.6
        p = np.array([a * w, y, 0.04 - depth * keel])
        n = np.array([a * 0.6, 0.0, -1.0])
        n /= np.linalg.norm(n)
        q = p + n * off
        return G(*q)

    bld = WP.Builder()
    NU, NV = 16, 26
    for layer, off, cell in ((0, 0.0, "face"), (1, -th, "back")):
        base = len(bld.v)
        u0, v0, u1, v1 = cells[cell]
        for j in range(NV + 1):
            for i in range(NU + 1):
                bld.v.append(hull(i / NU, j / NV, off))
                bld.uv.append((u0 + (u1 - u0) * i / NU, v0 + (v1 - v0) * j / NV))
                bld.part.append(cell)
                bld.s.append(0.0)
        for j in range(NV):
            for i in range(NU):
                a = base + j * (NU + 1) + i
                f = (a, a + NU + 1, a + NU + 2, a + 1)
                bld.f.append(f if layer == 0 else f[::-1])
    # the rim between the two layers (the oak's edge)
    for (i0, j0, di, dj, n) in ((0, 0, 1, 0, NU), (NU, 0, 0, 1, NV), (NU, NV, -1, 0, NU), (0, NV, 0, -1, NV)):
        for k in range(n):
            i, j = i0 + di * k, j0 + dj * k
            a = j * (NU + 1) + i
            b = (j + dj) * (NU + 1) + (i + di)
            off = (NU + 1) * (NV + 1)
            bld.f.append((a, b, b + off, a + off))
    # iron rails down both edges, bands across the face with rivets
    for u in (0.0, 1.0):
        pts = [hull(u, j / 20, 0.006) for j in range(21)]
        bld.tube(pts, [0.017] * 21, 6, *cells["iron"][0::2], *cells["iron"][1::2], "iron", [0] * 21,
                 cap_end=True, cap_start=True)
    for vb in (0.16, 0.5):
        pts = [hull(0.02 + 0.96 * i / 16, vb, 0.006) for i in range(17)]
        bld.tube(pts, [0.014] * 17, 6, *cells["iron"][0::2], *cells["iron"][1::2], "iron", [0] * 17,
                 cap_end=True, cap_start=True)
        for uu in (0.12, 0.3, 0.7, 0.88):
            c = hull(uu, vb, 0.018)
            nn = hull(uu, vb, 0.03) - c
            bld.prism(c, c + nn * 0.6, 0.009, 6, cells["iron"], "iron", 0.0)
    # the stem post up the keel, over the top edge, curling back over itself into the scroll
    keel_z = 0.04 - depth
    path = [G(0, top - 0.16, keel_z + 0.004), G(0, top - 0.06, keel_z - 0.006), G(0, top, keel_z - 0.01),
            G(0, top + 0.07, keel_z - 0.006)]
    c = np.array([top + 0.15, keel_z + 0.07])            # the scroll's centre (y, z), behind and above the top
    r0 = 0.095
    for k in range(1, 22):
        f = k / 21.0
        ang = math.pi + f * 2.3 * math.pi * 0.75          # from the front, up and back, round and in
        r = r0 * (1.0 - 0.62 * f)
        y = c[0] + r * math.cos(ang - math.pi * 0.5) * -1.0
        z = c[1] + r * math.sin(ang - math.pi * 0.5) * -1.0
        path.append(G(0, y, z))
    path = np.array(path)
    rad = [0.014, 0.024, 0.028, 0.028] + [0.028 * (1.0 - 0.45 * k / 21.0) for k in range(1, 22)]
    bld.tube(path, rad, 10, *cells["stem"][0::2], *cells["stem"][1::2], "stem", [0] * len(path),
             cap_end=True, cap_start=True)
    # the iron-shod foot and a cap where the stem meets the top edge
    spike(bld, G(0, foot + 0.06, keel_z - 0.004), G(0, foot - 0.05, keel_z + 0.02), 0.045, 8, cells["iron"], "iron")
    bld.tube([G(0, top - 0.005, keel_z - 0.014), G(0, top + 0.045, keel_z - 0.01)], [0.042, 0.042], 10,
             *cells["iron"][0::2], *cells["iron"][1::2], "iron", [0, 0], cap_end=True, cap_start=True)
    # icicles: along the lower edges and off the foot
    rnd = np.random.RandomState(4)
    for k in range(9):
        u = (k + 0.5) / 9
        vv = 0.78 + 0.18 * (1 - abs(2 * u - 1))
        b = hull(u, vv, 0.004)
        bld_len = 0.05 + 0.06 * rnd.rand()
        spike(bld, b, b + G(0, -bld_len, 0) - G(0, 0, 0), 0.012, 5, cells["ice"], "ice")
    for k in range(3):
        b = G((k - 1) * 0.035, foot + 0.07, keel_z + 0.03)
        spike(bld, b, b + G((k - 1) * 0.03, -0.11 + abs(k - 1) * 0.03, 0) - G(0, 0, 0), 0.016, 5, cells["ice"], "ice")
    # the crack down the left strakes, glowing a faint cold green
    zig = [hull(0.3 + 0.05 * (k % 2), 0.25 + k * 0.08, 0.004) for k in range(6)]
    bld.tube(zig, [0.006, 0.009, 0.009, 0.008, 0.007, 0.004], 4, *cells["glow"][0::2], *cells["glow"][1::2], "glow",
             [0] * 6)
    ob = finish(bld, "shield")
    if spec.get("at"):
        # (the prow moved in its node's space: toward the body and back, so it rides close as the art holds it)
        ob.data.transform(Matrix.Translation(Vector(G(*spec["at"]))))
    img = at.image("prow_atlas")
    mats = {s: material(ob, s, "prow", img) for s in ("leather", "metal", "ice", "glow")}
    assign(ob, bld, {"face": "leather", "back": "leather", "stem": "leather", "iron": "metal", "ice": "ice",
                     "glow": "glow"}, mats)
    hard_edges(ob, 50.0)
    log("prow: %d tris" % sum(len(p.vertices) - 2 for p in ob.data.polygons))
    return ob


def shield_card(spec):
    """Breaker's shield from the owner's shield sheet (breaker_shield_sheet: front, side, back): a thick card cut
    to the front view's outline (the broken top planks, the iron rim, the icicles below), its face painted with
    the front view (the carved bearded figurehead, the rivets), its back with the back view (the rope grip and
    strap), bent so the middle stands out (-Z), in the Shield node's space. spec: art, front and back boxes
    [x0, y0, x1, y1] on the sheet, height (m, the node's units), centre_y, bend, thick, at, eps."""
    sheet = _load_png(os.path.expanduser(spec["art"]))
    # the sheet's grey darkens toward its foot (a vignette): each row's own ground, from the sheet's right edge
    bg_rows = np.median(sheet[:, -35:-5], axis=1)

    def view(box, drops=()):
        x0, y0, x1, y1 = box
        crop = sheet[y0:y1, x0:x1]
        mask = np.abs(crop - bg_rows[y0:y1, None, :]).sum(axis=2) > 0.12
        for dx0, dy0, dx1, dy1 in drops:          # (the sheet's scale figure beside the front view)
            mask[max(0, dy0 - y0):max(0, dy1 - y0), max(0, dx0 - x0):max(0, dx1 - x0)] = False
        outline, blob = _trace(mask)
        ys, xs = np.nonzero(blob)
        return crop, blob, outline, (xs.min(), xs.max(), ys.min(), ys.max())
    fc, fb, fo, (fx0, fx1, fy0, fy1) = view(spec["front"], spec.get("drop_boxes", []))
    bc, bb, _bo, (bx0, bx1, by0, by1) = view(spec["back"])
    fo = _simplify(fo, float(spec.get("eps", 2.0)))
    H = float(spec["height"])
    k = H / float(fy1 - fy0)                                  # m per sheet pixel (front)
    cx, cy = (fx0 + fx1) * 0.5, (fy0 + fy1) * 0.5
    hw = (fx1 - fx0) * 0.5 * k
    bend, th = float(spec.get("bend", 0.04)), float(spec.get("thick", 0.035))
    at = np.array(spec.get("at", [0.0, 0.0, 0.0]), np.float64)
    yc = float(spec.get("centre_y", 0.0))
    # the atlas: front and back side by side, at the front's height; bled past the outlines
    fw, bw = fc.shape[1], bc.shape[1]
    tex = np.zeros((max(fc.shape[0], bc.shape[0]), fw + bw, 3), np.float32)
    tex[:fc.shape[0], :fw] = fc
    tex[:bc.shape[0], fw:] = bc
    img = bpy.data.images.new("prow_atlas", tex.shape[1], tex.shape[0], alpha=False)
    rgba = np.ones((tex.shape[0], tex.shape[1], 4), np.float32)
    rgba[..., :3] = tex[::-1]
    img.pixels = rgba.ravel()
    img.pack()
    TW, TH = tex.shape[1], tex.shape[0]

    def pos(px, py, back):
        x = -(px - cx) * k                                    # (seen from outside, the sheet's right is -X)
        y = yc + (cy - py) * k
        z = -bend * (1.0 - min(1.0, (x / hw) ** 2)) + (th if back else 0.0)
        return G(*(np.array([x, y, z]) + at))

    def uv_front(px, py):
        return ((px + 0.5) / TW, 1.0 - (py + 0.5) / TH)

    def uv_back(px, py):
        # the back view seen from behind: the same point mirrored, scaled onto the back view's box
        u = (px - fx0) / max(fx1 - fx0, 1)
        v = (py - fy0) / max(fy1 - fy0, 1)
        bpx = bx1 - u * (bx1 - bx0)
        bpy = by0 + v * (by1 - by0)
        return ((fw + bpx + 0.5) / TW, 1.0 - (bpy + 0.5) / TH)

    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    # a grid inside the outline for the bend (a flat n-gon can't curve): the outline's polygon cut by rows
    front = [bm.verts.new(pos(px, py, False)) for px, py in fo]
    back = [bm.verts.new(pos(px, py, True)) for px, py in fo]
    ff = bm.faces.new(front)
    bf = bm.faces.new(back[::-1])
    for lp in ff.loops:
        i = front.index(lp.vert)
        lp[uvl].uv = uv_front(*fo[i])
    for lp in bf.loops:
        i = back.index(lp.vert)
        lp[uvl].uv = uv_back(*fo[i])
    n = len(fo)
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new((front[j], front[i], back[i], back[j]))
        for lp, (px, py) in zip(f.loops, (fo[j], fo[i], fo[i], fo[j])):
            lp[uvl].uv = uv_front(px, py)
    # the bend: cut the faces into vertical strips so the middle can stand out
    strips = int(spec.get("strips", 10))
    for si in range(1, strips):
        xcut = -hw + 2 * hw * si / strips
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(xcut + at[0], 0, 0), plane_no=(1, 0, 0))
    bm.verts.ensure_lookup_table()
    # (re-bend every vertex by its own x: the bisect interpolated straight across the curve)
    for v in bm.verts:
        x = v.co.x - at[0]
        zb = -v.co.y - at[2]                                   # Godot z of the point
        is_back = zb > -bend * (1.0 - min(1.0, (x / hw) ** 2)) + th * 0.5
        z = -bend * (1.0 - min(1.0, (x / hw) ** 2)) + (th if is_back else 0.0)
        v.co.y = -(z + at[2])
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    me = bpy.data.meshes.new("shield")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("shield", me)
    bpy.context.scene.collection.objects.link(ob)
    outward(ob)
    material(ob, "leather", "prow", img)
    hard_edges(ob, 50.0)
    log("shield card: outline %d points, %.4f m per sheet px, %d tris" % (n, k, sum(len(p.vertices) - 2 for p in me.polygons)))
    return ob


# ------------------------------------------------------------------------------------------------ spear
def spear(spec):
    """Claire's ice spear in the Gun node's space: the haft along -Z, a barbed leaf blade ending `tip` (just past
    the Muzzle), a short spike at the butt."""
    butt, tip = float(spec.get("butt", 0.62)), float(spec.get("tip", -0.82))
    blade = float(spec.get("blade", 0.24))
    at = Atlas(2)
    cells = {"ice": at.cell("ice", ice_paint), "core": at.cell("core", flat("cfeaff", 0.05, 8)),
             "frost": at.cell("frost", flat("f4fbff", 0.04, 9))}
    bld = WP.Builder()
    b0 = tip + blade                                         # the blade's base
    bld.tube([G(0, 0, butt - 0.06), G(0, 0, b0 + 0.02)], [0.013, 0.013], 6, *cells["ice"][0::2],
             *cells["ice"][1::2], "ice", [0, 0], cap_start=True, cap_end=True)
    spike(bld, G(0, 0, butt - 0.07), G(0, 0, butt), 0.016, 4, cells["ice"], "ice")
    for z in (b0 + 0.02, b0 + 0.06):                         # frost collars under the blade
        bld.prism(G(0, 0, z), G(0, 0, z - 0.02), 0.022, 6, cells["frost"], "frost", 0.4)
    # the blade: a flat diamond (wide along the gun's x), and two barbs swept back from its base
    wmax, th = 0.042, 0.012
    prof = [(b0, 0.012), (b0 - blade * 0.25, wmax), (b0 - blade * 0.55, wmax * 0.7), (tip, 0.0)]
    base = len(bld.v)
    u0, v0, u1, v1 = cells["core"]
    for i, (z, w) in enumerate(prof):
        for (x, y) in ((w, 0.0), (0.0, th), (-w, 0.0), (0.0, -th)):
            bld.v.append(G(x, y, z))
            bld.uv.append((u0 + (u1 - u0) * (x / (2 * wmax) + 0.5), v0 + (v1 - v0) * i / 3))
            bld.part.append("core")
            bld.s.append(0.0)
    for i in range(len(prof) - 1):
        for k in range(4):
            a, b = base + i * 4 + k, base + i * 4 + (k + 1) % 4
            bld.f.append((a, b, b + 4, a + 4))
    bld.f.append(tuple(base + k for k in range(4))[::-1])
    for sx in (-1, 1):
        spike(bld, G(sx * 0.02, 0, b0 - 0.03), G(sx * 0.05, 0, b0 + 0.05), 0.009, 4, cells["ice"], "ice")
    ob = finish(bld, "weapon")
    img = at.image("spear_atlas")
    mats = {"ice": material(ob, "ice", "spear", img)}
    for p in ob.data.polygons:
        p.material_index = mats["ice"]
    hard_edges(ob, 35.0)
    log("spear: %d tris, butt %.2f, tip %.2f" % (sum(len(p.vertices) - 2 for p in ob.data.polygons), butt, tip))
    return ob


# ------------------------------------------------------------------------------------------------ wings
def _load_png(path):
    """(h, w, 3) floats via ffmpeg (no PIL in Blender's python)."""
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                          "-of", "json", path], capture_output=True, check=True).stdout
    s = json.loads(out)["streams"][0]
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(s["height"], s["width"], 3).astype(np.float32) / 255.0


def _trace(mask):
    """The outer boundary of the largest blob in mask, as (x, y) pixel corners, in order (Moore tracing)."""
    h, w = mask.shape
    lab = np.zeros(mask.shape, np.int32)
    best, best_n, n = 0, 0, 0
    for y0 in range(h):
        for x0 in np.nonzero(mask[y0] & (lab[y0] == 0))[0]:
            n += 1
            st = [(y0, x0)]
            lab[y0, x0] = n
            cnt = 0
            while st:
                y, x = st.pop()
                cnt += 1
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and lab[yy, xx] == 0:
                        lab[yy, xx] = n
                        st.append((yy, xx))
            if cnt > best_n:
                best, best_n = n, cnt
    m = lab == best
    ys, xs = np.nonzero(m)
    start = (ys.min(), xs[ys == ys.min()].min())
    nb = [(-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1)]
    pts = [start]
    cur, d = start, 6
    for _i in range(200000):
        for k in range(8):
            dd = (d + k) % 8
            y, x = cur[0] + nb[dd][0], cur[1] + nb[dd][1]
            if 0 <= y < h and 0 <= x < w and m[y, x]:
                cur = (y, x)
                d = (dd + 6) % 8
                break
        if cur == start:
            break
        pts.append(cur)
    return np.array([(x, y) for y, x in pts], np.float64), m


def _simplify(p, eps):
    """Douglas-Peucker on a closed polyline."""
    def dp(a):
        if len(a) < 3:
            return a
        s, e = a[0], a[-1]
        d = e - s
        ln = np.linalg.norm(d)
        dist = np.abs(np.cross(d, a - s)) / ln if ln > 1e-9 else np.linalg.norm(a - s, axis=1)
        i = int(np.argmax(dist))
        if dist[i] > eps:
            return np.vstack([dp(a[:i + 1])[:-1], dp(a[i:])])
        return np.vstack([s, e])
    far = int(np.argmax(np.linalg.norm(p - p[0], axis=1)))
    return np.vstack([dp(p[:far + 1])[:-1], dp(np.vstack([p[far:], p[:1]]))[:-1]])


def wings(spec, body, arm, rig):
    """Bat wings as cut-out cards from the art (see the module doc). spec: art (the turnaround), box [x0, y0, x1, y1]
    of one wing on the sheet (the back view: her LEFT wing, the one the spear doesn't cross; the right card is its
    mirror image, a symmetric piece), cut_x (sheet column where her hair starts covering it: the card's inner
    edge, tucked under the hair), sole_y and crown_y (the back view's sole and head-top rows) with crown_z (the
    fitted model's head top, m): pixels -> metres, root [x, y, z] (fitted frame, the left
    root; the right one mirrored), sweep (degrees the tips are turned back), gap (m between the two layers)."""
    sheet = _load_png(os.path.expanduser(spec["art"]))
    x0, y0, x1, y1 = spec["box"]
    crop = sheet[y0:y1, x0:x1]
    bg = np.median(sheet[5:30, 5:30].reshape(-1, 3), axis=0)
    diff = np.abs(crop - bg).sum(axis=2)
    lum = crop.mean(axis=2)
    mask = (diff > 0.16) & (lum < 0.62)
    mask[:, int(spec["cut_x"]) - x0:] = False
    # (close small holes: the membrane's light drips)
    from_pad = np.pad(mask, 2)
    for _i in range(2):
        grow = from_pad.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                grow |= np.roll(np.roll(from_pad, dy, 0), dx, 1)
        from_pad = grow
    for _i in range(2):
        shrink = from_pad.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                shrink &= np.roll(np.roll(from_pad, dy, 0), dx, 1)
        from_pad = shrink
    mask = from_pad[2:-2, 2:-2] | mask
    outline, blob = _trace(mask)
    outline = _simplify(outline, float(spec.get("eps", 1.6)))
    # the wing's texture: the art's pixels, the membrane's own colour bled past its edge
    th, tw = crop.shape[:2]
    tex = crop.copy()
    keep = blob.copy()
    for _i in range(6):
        grow = keep.copy()
        acc = np.zeros_like(tex)
        cnt = np.zeros(keep.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(keep, dy, 0), dx, 1)
            acc += np.roll(np.roll(tex, dy, 0), dx, 1) * sh[..., None]
            cnt += sh
        new = (~keep) & (cnt > 0)
        tex[new] = acc[new] / cnt[new][:, None]
        grow |= new
        keep = grow
    img = bpy.data.images.new("wing_atlas", tw, th, alpha=False)
    rgba = np.ones((th, tw, 4), np.float32)
    rgba[..., :3] = tex[::-1]
    img.pixels = rgba.ravel()
    img.pack()
    k = float(spec["crown_z"]) / (float(spec["sole_y"]) - float(spec["crown_y"]))       # metres per art pixel
    root_l = np.array(spec["root"], np.float64)
    sweep = math.radians(float(spec.get("sweep", 25.0)))
    gap = float(spec.get("gap", 0.006))
    cut = float(spec["cut_x"])
    objs = []
    for side in ("L", "R"):
        sx = -1.0 if side == "L" else 1.0
        root = np.array([abs(root_l[0]) * sx, root_l[1], root_l[2]])
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")

        def place(px, py, layer):
            # the card's plane: the art's column (from the hair edge outward) along her side, its row up; the
            # inner edge on the root, the whole card turned `sweep` back about the vertical through the root
            d = (cut - (x0 + px)) * k                            # m out from the root (the left wing: -X)
            z = (float(spec["sole_y"]) - (y0 + py)) * k
            local = np.array([sx * d * math.cos(sweep), -d * math.sin(sweep) - layer * gap, z - root[2]])
            return root + local

        for layer in (0, 1):
            vs = [bm.verts.new(place(px, py, layer)) for px, py in outline]
            f = bm.faces.new(vs)
            for lp, (px, py) in zip(f.loops, outline):
                lp[uvl].uv = ((px + 0.5) / tw, 1.0 - (py + 0.5) / th)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
        bm.normal_update()
        m = len(outline)
        for f in bm.faces:          # the layer nearer her back faces her, the outer one faces away
            want = -1.0 if f.verts[0].index >= m else 1.0
            if f.normal.y * want < 0:
                f.normal_flip()
        me = bpy.data.meshes.new("Wing" + side)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("Wing" + side, me)
        bpy.context.scene.collection.objects.link(ob)
        # every face facing away from the other layer (the two sides of the card)
        ob.data.materials.append(bpy.data.materials.get("leather-wings") or _mat_img("leather", "wings", img))
        for p in ob.data.polygons:
            p.use_smooth = False
        # the chain: from the root up the wing's leading edge to the highest point of the outline (the claw)
        top = outline[int(np.argmin(outline[:, 1]))]
        tip = place(top[0], top[1], 0)
        path = np.array([root + (tip - root) * t for t in np.linspace(0.0, 1.0, 4)])
        nb = int(spec.get("bones", 3))
        names, spans = WP.chain_bones(arm, "wing" + side, spec.get("parent", "hips"), path, float(np.linalg.norm(
            tip - root)), nb, tip)
        dirn = (tip - root) / np.linalg.norm(tip - root)
        sel = []
        for v in ob.data.vertices:
            q = np.array(v.co[:]) - root
            sel.append((v.index, max(0.0, min(float(q @ dirn), float(np.linalg.norm(tip - root))))))
        WP.weights(ob, sel, names, spans)
        ob.parent = arm
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        objs.append(ob)
    log("wings: outline %d points, %.3f m per art px, %d tris each" % (len(outline), k,
                                                                       sum(len(p.vertices) - 2 for p in objs[0].data.polygons)))
    return objs


def _mat_img(slot, tag, img):
    m = bpy.data.materials.new("%s-%s" % (slot, tag))
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    return m


# ------------------------------------------------------------------------------------------------ tail
def tail(spec, body, arm):
    """The spaded tail: a tube down a path draped clear of the body, ending in a flat spade, on a spring chain."""
    bvh = WP.body_bvh([body])
    n = 36
    p = WP.drape(bvh, spec["path"], n, float(spec.get("clear", 0.03)), length=spec.get("length"))
    s = WP.arclen(p)
    L = s[-1]
    r0, r1 = (float(x) for x in spec.get("radius", [0.026, 0.009]))
    at = Atlas(2, 64)
    cells = {"tail": at.cell("tail", lambda u, v: (hexcol("2f3346")[None, None] * (1 - v[..., None] * 0.0) +
                                                   hexcol("4d5470")[None, None] * (np.sin(u * math.pi) ** 4)[..., None] * 0.5)),
             "spade": at.cell("spade", flat("2b2f42", 0.05, 3))}
    bld = WP.Builder()
    radii = [r0 + (r1 - r0) * (si / L) ** 0.8 for si in s]
    bld.tube(p, radii, 10, *cells["tail"][0::2], *cells["tail"][1::2], "tail", list(s), cap_start=True)
    # the spade: an arrowhead, flat across the tail's side, thickened to a slim slab
    t = p[-1] - p[-2]
    t /= np.linalg.norm(t)
    side = np.cross(t, np.array(spec.get("spade_up", [0.0, -1.0, 0.0])))
    side /= np.linalg.norm(side)
    up = np.cross(side, t)
    sz = float(spec.get("spade", 0.075))
    shape = [(1.0, 0.0), (0.05, 0.62), (-0.2, 0.5), (-0.05, 0.12), (-0.12, 0.0), (-0.05, -0.12), (-0.2, -0.5),
             (0.05, -0.62)]
    base = len(bld.v)
    u0, v0, u1, v1 = cells["spade"]
    for layer in (-1, 1):
        for a, b in shape:
            bld.v.append(p[-1] + t * (a * sz + sz * 0.15) + side * b * sz + up * layer * 0.006)
            bld.uv.append((u0 + (u1 - u0) * (b + 1) / 2, v0 + (v1 - v0) * (a + 1) / 2))
            bld.part.append("spade")
            bld.s.append(L)
    m = len(shape)
    bld.f.append(tuple(base + i for i in range(m)))
    bld.f.append(tuple(base + m + i for i in range(m))[::-1])
    for i in range(m):
        a, b = base + i, base + (i + 1) % m
        bld.f.append((b, a, a + m, b + m))
    ob = finish(bld, "Tail")
    # (an n-gon spade: triangulated for the exporter's sake)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4], ngon_method="EAR_CLIP")
    bm.to_mesh(ob.data)
    bm.free()
    img = at.image("tail_atlas")
    material(ob, "leather", "tail", img)
    names, spans = WP.chain_bones(arm, "tail", spec.get("parent", "hips"), p, L + sz, int(spec.get("bones", 6)),
                                  p[-1] + t * sz * 1.15)
    WP.weights(ob, [(vi, bld.s[vi] if vi < len(bld.s) else L) for vi in range(len(ob.data.vertices))], names, spans)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("tail: %.2f m, %d tris" % (L, sum(len(q.vertices) - 2 for q in ob.data.polygons)))
    return ob


# ------------------------------------------------------------------------------------------------ split, feet
def split(ob, arm, sp):
    """The faces of the slots in sp["slots"] (whose centre is above sp["z_min"]) as their own mesh `sp["name"]`,
    riding sp["bone"] rigidly (Claire's ice horns)."""
    names = [m.name.split("-")[0] for m in ob.data.materials]
    want = set(i for i, nm in enumerate(names) if nm in sp["slots"])
    zmin = float(sp.get("z_min", -1e9))
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    pick = [f for f in bm.faces if f.material_index in want and f.calc_center_median().z > zmin]
    keep = set(f.index for f in pick)
    other = bmesh.new()
    other.from_mesh(ob.data)
    bmesh.ops.delete(other, geom=[f for f in other.faces if f.index not in keep], context="FACES")
    bmesh.ops.delete(other, geom=[v for v in other.verts if not v.link_faces], context="VERTS")
    bmesh.ops.delete(bm, geom=pick, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    me = bpy.data.meshes.new(sp["name"])
    other.to_mesh(me)
    other.free()
    for m in ob.data.materials:
        me.materials.append(m)
    out = bpy.data.objects.new(sp["name"], me)
    bpy.context.scene.collection.objects.link(out)
    g = out.vertex_groups.new(name=sp["bone"])
    g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    out.parent = arm
    mod = out.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("split %s: %d tris (slots %s)" % (sp["name"], sum(len(p.vertices) - 2 for p in me.polygons), sp["slots"]))
    return out


def feet_forward(ob, rig, min_dot=0.8):
    """Each foot points the way the body faces (+Y in the fitted frame): the sole's centre lies ahead of the
    ankle shaft's. Raises when a foot (a skate) points back or sideways: the owner's backwards-foot catch."""
    co = np.array([v.co[:] for v in ob.data.vertices])
    out = {}
    for side, sx in (("L", -1.0), ("R", 1.0)):
        x = co[:, 0] * sx
        foot = co[(x > 0.0) & (co[:, 2] < 0.05)]
        shaft = co[(x > 0.0) & (co[:, 2] > 0.13) & (co[:, 2] < 0.2)]
        d = foot[:, :2].mean(axis=0) - shaft[:, :2].mean(axis=0)
        # the long axis of the sole, signed toward the side the sole's mass leans
        pc = np.linalg.svd(foot[:, :2] - foot[:, :2].mean(axis=0), full_matrices=False)[2][0]
        fwd = pc if pc @ d >= 0 else -pc
        dot = float(fwd @ np.array([0.0, 1.0]))
        out[side] = (round(float(fwd[0]), 3), round(float(fwd[1]), 3), round(dot, 3))
        if dot < min_dot:
            raise SystemExit("FEET FAIL: the %s foot points %s, not the body's forward (dot %.2f < %.2f): turn it "
                             "180 degrees about the ankle" % (side, out[side][:2], dot, min_dot))
    log("feet forward ok:", out)
    return out


# ------------------------------------------------------------------------------------------------ entry
def build(spec, body, arm, rig):
    """fit_warden.py's hook (spec["parts"]): returns {"weapon": ob or None, "extra": [held or skinned pieces]}."""
    out = {"weapon": None, "extra": []}
    ps = spec["parts"]
    if ps.get("feet_forward"):
        feet_forward(body, rig, float(ps.get("feet_min_dot", 0.8)))
    if "hammer" in ps:
        out["weapon"] = hammer(ps["hammer"])
    if "spear" in ps:
        out["weapon"] = spear(ps["spear"])
    if "prow" in ps:
        out["extra"].append(prow(ps["prow"]))
    if "shield_card" in ps:
        out["extra"].append(shield_card(ps["shield_card"]))
    if "wings" in ps:
        out["extra"].extend(wings(ps["wings"], body, arm, rig))
    if "tail" in ps:
        out["extra"].append(tail(ps["tail"], body, arm))
    return out

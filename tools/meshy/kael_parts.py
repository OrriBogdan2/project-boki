"""Kael's (juggernaut; was Zedran) hard-surface and hair pieces, built in Blender by script on the fitted Meshy body
(tools/meshy/fit_warden.py `kael`; docs/art/wardens/PIPELINE.md), from the final art (ext/imagegen
docs/art/gen/wardens_r3/kael_* + ZEDRAN_KIT.md):

- sword(): the greatsword as the Warden's `weapon` (RIG_CONTRACT: unskinned, in the Gun node's space, Blender
  +Y forward along the blade, as the procedural greatsword: the grip about the origin, the blade from 0.14 to
  1.36 m, its flat in the YZ plane). A broad slab with chipped edges and the jagged broken tip of the front and
  3/4 views, a bevel to the edges, two iron bands, a heavy bar guard, a wrapped grip with the Warchain's links
  round it, and the cracks down both faces as glowing ribbons (`glow-sword` core over `glow-sword_edge`).
- warchain(): his RIGHT arm's chain: links wrapped round the forearm (rigid on forearm.R), then hanging from the
  wrist by the hilt to ONE heavy hook with a hot tip (`glow-hook`), on a chain of `spring_hangwarchain_<i>` bones
  under hand.R (WardenGlb.Springs hangs it under gravity: a `hang` chain).
- cuff_chain(): the LEFT wrist's short broken chain (three links and a split one) on `spring_hangcuff_<i>` under
  hand.L. No hook there.
- mane(): the long white mane as chunky tapered locks rooted in the scan's short hair, draped down his back and
  over his shoulders (never through the body), in groups that each ride a `spring_mane<k>_<i>` chain under head.

The glow pieces carry the white-hot colour as their painted colour; the game takes the archetype's model_glow
colours over it (WardenGlb._glow_colours), so the glow can change without a rebake.
All in the fitted frame: Blender, +Z up, his front +Y, his right +X, soles on Z = 0.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import warden_parts as WP

COL = {  # name: (slot, hex)
    "blade": ("metal", "6e6a66"), "blade_dk": ("metal", "4a4744"), "band": ("metal", "4c4c52"),
    "guard": ("metal", "6c6a65"), "grip": ("leather", "5e2c25"), "pommel": ("metal", "6c6a65"),
    "chain": ("metal", "6e7075"), "hook": ("metal", "616368"),
    "sword": ("glow", "fffaf0"), "sword_edge": ("glow", "f2d48a"),
    "sword_halo": ("glow", "8a7448"), "sword_halo2": ("glow", "4a3e2a"), "hook_tip": ("glow", "fffaf0"),
    "mane": ("hair", "e9e7e3"), "mane_dk": ("hair", "bdb9b4"),
    "spike": ("hair", "e4dfe0"), "spike_dk": ("hair", "b8afb2"), "mane_vol": ("hair", "cfc7c9"),
    "gold": ("metal", "d9a94e"), "gold_dk": ("metal", "8a6424"),
}


def log(*a):
    print("KAELPARTS", *a, flush=True)


def mat(name):
    slot, hexc = COL[name]
    tag = {"hook_tip": "hook", "mane_dk": "mane_dk"}.get(name, name)
    full = "%s-%s" % (slot, tag)
    m = bpy.data.materials.get(full)
    if m is None:
        m = bpy.data.materials.new(full)
        m.use_nodes = True
        c = tuple(int(hexc[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        lin = tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin + (1.0,)
        m.diffuse_color = lin + (1.0,)
    return m


ATLAS = 256         # the pieces' small atlas: one flat 32 px cell per colour (the loader wants every surface on a texture)
_atlas = None


def atlas():
    global _atlas
    if _atlas is None:
        _atlas = bpy.data.images.new("kael_parts_atlas", ATLAS, ATLAS, alpha=False)
        px = np.ones((ATLAS, ATLAS, 4), np.float32)
        for i, (name, (slot, hexc)) in enumerate(COL.items()):
            # (the image is sRGB: its pixels are the hex colours as they are, not linear)
            c = np.array([int(hexc[k:k + 2], 16) / 255.0 for k in (0, 2, 4)], np.float32)
            r, q = divmod(i, 8)
            px[r * 32:(r + 1) * 32, q * 32:(q + 1) * 32, :3] = c
        _atlas.pixels = px.ravel()
        _atlas.pack()
    return _atlas


def cell_uv(name):
    r, q = divmod(list(COL).index(name), 8)
    return ((q * 32 + 16) / ATLAS, (r * 32 + 16) / ATLAS)


def paint_flat(ob):
    """Every face onto its colour's atlas cell, and each material onto the atlas texture."""
    full_to = {}
    for name in COL:
        slot, _h = COL[name]
        full_to["%s-%s" % (slot, {"hook_tip": "hook", "mane_dk": "mane_dk"}.get(name, name))] = name
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    names = [full_to[m.name] for m in me.materials]
    for p in me.polygons:
        c = cell_uv(names[p.material_index])
        for li in p.loop_indices:
            uv[li].uv = c
    img = atlas()
    for m in me.materials:
        nt = m.node_tree
        if any(n.type == "TEX_IMAGE" for n in nt.nodes):
            continue
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.links.new(tex.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])


def finish(bld, name, mats_of_part):
    """A WP.Builder into an object, each face on its part's material."""
    ob = bld.object(name)
    names = []
    for part in bld.part:
        mn = mats_of_part[part]
        if mn not in names:
            names.append(mn)
    for mn in names:
        ob.data.materials.append(mat(mn))
    for p in ob.data.polygons:
        p.material_index = names.index(mats_of_part[bld.part[p.vertices[0]]])
    paint_flat(ob)
    return ob


# ------------------------------------------------------------------------------------------------ the sword
def _outline(L0, L1, hw, seed=3, chip=0.012, teeth=0):
    """The blade's outline (y along the blade, z across), base to tip and back (kael_blade_sheet): a long slab of
    broken iron, its edges chipped (and with `teeth`, notched: a sharp step in and out every few cm, the sheet's
    jagged rock-like edge), its end broken into a stepped point: a shoulder each side, a notch, the ridge."""
    rng = np.random.default_rng(seed)
    n = 14 if not teeth else int(teeth)
    yt = L1 - 0.14 * (L1 - L0) / 1.22
    q = (L1 - yt) / 0.14

    def edge(sgn):
        pts = []
        for i in range(n + 1):
            y = L0 + (yt - L0) * i / n
            d = rng.uniform(-chip, 0.0) if 0 < i < n else 0.0
            pts.append((y, sgn * (hw + d)))
            if teeth and 0 < i < n and rng.random() < 0.45:
                # a broken-off chip: straight in, then out again a little further up, of uneven depth and length
                dy = (yt - L0) / n * rng.uniform(0.3, 0.8)
                pts.append((y + dy, sgn * (hw - chip * rng.uniform(0.7, 2.0))))
        return pts
    top, bot = edge(1), edge(-1)
    tip = [(yt + 0.03 * q, hw * 1.08), (yt + 0.07 * q, hw * 1.02), (yt + 0.08 * q, hw * 0.74), (yt + 0.115 * q, hw * 0.8),
           (L1 - 0.025 * q, hw * 0.42), (L1, hw * 0.08), (L1 - 0.012 * q, -hw * 0.12), (L1 - 0.04 * q, -hw * 0.4),
           (L1 - 0.02 * q, -hw * 0.62), (yt + 0.1 * q, -hw * 0.82), (yt + 0.085 * q, -hw * 1.04), (yt + 0.04 * q, -hw * 1.08)]
    return top + tip + bot[::-1]


def _slab(bm, outline, t_edge, t_mid, inner_k, mi_face, mi_edge):
    """A blade slab: the outline at +-t_edge, an inner outline (inner_k toward the centre line) at +-t_mid."""
    cy = sum(p[0] for p in outline) / len(outline)
    vo = {s: [bm.verts.new((s * t_edge, y, z)) for y, z in outline] for s in (-1, 1)}
    vi = {s: [bm.verts.new((s * t_mid, cy + (y - cy) * (0.93 + 0.07 * inner_k), z * inner_k)) for y, z in outline]
          for s in (-1, 1)}
    n = len(outline)
    for s in (-1, 1):
        f = bm.faces.new(vi[s] if s > 0 else vi[s][::-1])
        f.material_index = mi_face
        for k in range(n):
            a, b = k, (k + 1) % n
            q = (vo[s][a], vo[s][b], vi[s][b], vi[s][a]) if s > 0 else (vi[s][a], vi[s][b], vo[s][b], vo[s][a])
            bm.faces.new(q).material_index = mi_edge
    for k in range(n):
        a, b = k, (k + 1) % n
        bm.faces.new((vo[-1][a], vo[-1][b], vo[1][b], vo[1][a])).material_index = mi_edge


def _ribbon(bm, pts, w, x, mi, taper=True):
    """A flat ribbon on the plane x (a crack), through pts (y, z), w wide (tapered at both ends, or squared)."""
    pts = [Vector((0, p[0], p[1])) for p in pts]
    left, right = [], []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        nrm = Vector((0, -t.z, t.y))
        ww = w * (0.35 + 0.65 * math.sin(math.pi * (0.15 + 0.7 * i / max(len(pts) - 1, 1)))) if taper else w
        left.append(bm.verts.new((x, p.y + nrm.y * ww / 2, p.z + nrm.z * ww / 2)))
        right.append(bm.verts.new((x, p.y - nrm.y * ww / 2, p.z - nrm.z * ww / 2)))
    for i in range(len(pts) - 1):
        q = (left[i], left[i + 1], right[i + 1], right[i])
        f = bm.faces.new(q if x > 0 else q[::-1])
        f.material_index = mi


def _box(bm, c, h, mi):
    vs = [bm.verts.new((c[0] + sx * h[0], c[1] + sy * h[1], c[2] + sz * h[2]))
          for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[i] for i in q]).material_index = mi


def _cyl(bm, a, b, r, n, mi):
    a, b = Vector(a), Vector(b)
    ax = (b - a).normalized()
    e1 = ax.orthogonal().normalized()
    e2 = ax.cross(e1)
    ra = [bm.verts.new(a + (e1 * math.cos(2 * math.pi * k / n) + e2 * math.sin(2 * math.pi * k / n)) * r) for k in range(n)]
    rb = [bm.verts.new(b + (e1 * math.cos(2 * math.pi * k / n) + e2 * math.sin(2 * math.pi * k / n)) * r) for k in range(n)]
    for k in range(n):
        bm.faces.new((ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k])).material_index = mi
    bm.faces.new(ra[::-1]).material_index = mi
    bm.faces.new(rb).material_index = mi


def sword(sp):
    L0, L1, hw = float(sp.get("from", 0.14)), float(sp.get("to", 1.36)), float(sp.get("half_width", 0.155))
    names = ["blade", "blade_dk", "band", "guard", "grip", "pommel", "chain", "sword_halo2", "sword_halo", "sword_edge",
             "sword"]
    mi = {n: i for i, n in enumerate(names)}
    bm = bmesh.new()
    out = _outline(L0, L1, hw, chip=float(sp.get("chip", 0.012)), teeth=int(sp.get("teeth", 0)))
    _slab(bm, out, 0.011, 0.03, 0.72, mi["blade"], mi["blade_dk"])
    # the white-hot core: one broad channel the blade's whole length (kael_blade_sheet), its rim pale gold, a few
    # thin cracks breaking off it toward the edges; on both faces
    rng = np.random.default_rng(11)
    cw = float(sp.get("crack_w", 0.5)) * hw * 2
    main = [(L0 + 0.05 + (L1 - 0.1 - L0) * i / 18, rng.uniform(-0.006, 0.006)) for i in range(19)]
    branches = []
    for k in range(int(sp.get("branches", 8))):
        i0 = 2 + int(k * 14 / max(int(sp.get("branches", 8)), 1)) + int(rng.integers(0, 2))
        y0, z0 = main[i0]
        sgn = 1 if k % 2 == 0 else -1
        z0 += sgn * cw * 0.4
        br = [(y0, z0)]
        for j in range(2):
            y0 += rng.uniform(0.02, 0.05)
            z0 += sgn * rng.uniform(0.012, 0.022)
            br.append((y0, z0))
        branches.append(br)
    for s in (-1, 1):
        x = s * 0.0312
        # (a soft bloom: two wider, dimmer glow layers under the rim, the glow falling off toward the edges)
        hk = sp.get("halo_k", [2.1, 1.6, 1.25])
        _ribbon(bm, main, min(cw * hk[0], hw * 1.85), s * 0.0306, mi["sword_halo2"], taper=False)
        _ribbon(bm, main, cw * hk[1], s * 0.0309, mi["sword_halo"], taper=False)
        _ribbon(bm, main, cw * hk[2], x, mi["sword_edge"], taper=False)
        _ribbon(bm, main, cw, s * 0.0318, mi["sword"], taper=False)
        for br in branches:
            _ribbon(bm, br, 0.016, x, mi["sword_edge"])
            _ribbon(bm, br, 0.008, s * 0.0318, mi["sword"])
        # the faint crack texture inside the white-hot core (kael_blade_sheet): thin zigzags of the gold edge
        crng = np.random.default_rng(23)
        for c in range(int(sp.get("core_cracks", 9))):
            y0 = L0 + 0.08 + (L1 - 0.2 - L0) * c / max(int(sp.get("core_cracks", 9)) - 1, 1)
            z0 = crng.uniform(-0.3, 0.3) * cw
            line = [(y0, z0)]
            for j in range(4):
                y0 += crng.uniform(0.012, 0.03)
                z0 = float(np.clip(z0 + crng.uniform(-0.45, 0.45) * cw * 0.5, -cw * 0.42, cw * 0.42))
                line.append((y0, z0))
            _ribbon(bm, line, 0.0035, s * 0.0324, mi["sword_edge"])
    if sp.get("bands"):
        # two iron bands round the blade above the guard (the turnaround)
        for y in sp.get("band_at", [0.1, 0.2]):
            _box(bm, (0, L0 + y, 0), (0.036, 0.016, hw * 1.08), mi["band"])
    # the bar guard, the wrapped grip, the pommel (the sheet's pommel hook is NOT his: the one hook is the chain's)
    _box(bm, (0, L0 - 0.03, 0), (0.05, 0.04, hw * float(sp.get("guard_k", 1.55))), mi["guard"])
    _cyl(bm, (0, L0 - 0.075, 0), (0, -0.25, 0), 0.034, 10, mi["grip"])
    for k in range(5):
        y = -0.2 + k * 0.07
        _cyl(bm, (0, y - 0.01, 0), (0, y + 0.01, 0), 0.038, 10, mi["band"])
    _cyl(bm, (0, -0.25, 0), (0, -0.31, 0), 0.052, 8, mi["pommel"])
    me = bpy.data.meshes.new("weapon")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("weapon", me)
    bpy.context.scene.collection.objects.link(ob)
    for n in names:
        me.materials.append(mat(n))
    # the Warchain's links round the grip (the chain off the forearm runs down the hilt)
    bld = WP.Builder()
    hilt = np.array([[0.0, -0.22 + 0.05 * i, 0.0] for i in range(6)])
    rows = sp.get("wrap_rows")
    if rows:
        # the chain wound round the blade's base above the guard in tight rows (kael_blade_sheet): links laid
        # along the slab's perimeter, every other one turned on edge
        hx, hz = 0.034, hw + 0.012
        per = 4 * (hx + hz)
        nl = int(per / 0.042)
        for r_i, y in enumerate(rows):
            for k in range(nl):
                u = (k + 0.5 * (r_i % 2)) / nl * per
                # the rectangle's perimeter: +z edge, +x side, -z edge, -x side
                if u < 2 * hz:
                    c, t = (hx, -hz + u), (0.0, 1.0)
                elif u < 2 * hz + 2 * hx:
                    c, t = (hx - (u - 2 * hz), hz), (-1.0, 0.0)
                elif u < 4 * hz + 2 * hx:
                    c, t = (-hx, hz - (u - 2 * hz - 2 * hx)), (0.0, -1.0)
                else:
                    c, t = (-hx + (u - 4 * hz - 2 * hx), -hz), (1.0, 0.0)
                tv = np.array([t[0], 0.0, t[1]])
                side = np.array([0.0, 1.0, 0.0]) if k % 2 == 0 else np.array([t[1], 0.0, -t[0]])
                _link(bld, np.array([c[0], L0 + y, c[1]]), tv, side, 0.05, 0.032, 0.0068, "chain", 0.0)
    for i in range(0 if rows else 6):
        # round the blade's base above the guard: links standing round its flat
        y = L0 + 0.02 + 0.035 * i
        ang = i * 1.9
        off = np.array([0.03 * math.cos(ang), 0.0, (hw + 0.01) * math.sin(ang)])
        _link(bld, np.array([0.0, y, 0.0]) + off, [0.0, 0.25, 0.0] + np.array([-math.sin(ang), 0.0, math.cos(ang)]),
              [0.0, 1.0, 0.0], 0.05, 0.032, 0.0065, "chain", 0.0)
    for i in range(5):
        c = (hilt[i] + hilt[i + 1]) * 0.5
        ang = i * 1.1
        off = np.array([math.cos(ang), 0.0, math.sin(ang)]) * 0.04
        _link(bld, c + off, np.array([0.0, 1.0, 0.0]) + 0.6 * off / 0.04, off / 0.04, 0.05, 0.032, 0.0065, "chain", 0.0)
    links = finish(bld, "weapon_links", {"chain": "chain"})
    bpy.ops.object.select_all(action="DESELECT")
    links.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    paint_flat(ob)
    k = float(sp.get("scale", 1.0))
    if k != 1.0:
        # (the heavy class's Gun scale, 1.42, sits on top: the art's blade is about half his height in game)
        from mathutils import Matrix
        ob.data.transform(Matrix.Scale(k, 4))
        ob.data.update()
    log("sword: %d tris, scale %.2f" % (sum(len(p.vertices) - 2 for p in ob.data.polygons), k))
    return ob


# ------------------------------------------------------------------------------------------------ chains
def _link(bld, c, t, side, lk, wk, r, part, s, open_frac=0.0):
    """One oval link at c, its long axis along t, its ring in the plane of t and side."""
    t = np.asarray(t, float)
    t /= np.linalg.norm(t)
    side = np.asarray(side, float)
    side = side - t * side.dot(t)
    side /= max(np.linalg.norm(side), 1e-9)
    pts = []
    m = 10
    for k in range(m + 1):
        a = 2 * math.pi * k / m
        if open_frac and a > 2 * math.pi * (1 - open_frac):
            break
        pts.append(c + t * (lk / 2) * math.cos(a) + side * (wk / 2) * math.sin(a))
    rings = np.array(pts)
    bld.tube(rings, [r] * len(rings), 5, 0.0, 1.0, 0.0, 1.0, part, [s] * len(rings),
             cap_start=bool(open_frac), cap_end=bool(open_frac))


def _chain_along(bld, p, lk, wk, r, part, s0=0.0, open_last=False):
    """Links along the path p (n x 3), each at its arc length, turned 90 degrees from the last."""
    s_arr = WP.arclen(p)
    L = s_arr[-1]
    step = lk - 2 * r - 0.004
    n = max(1, int(L / step))
    for i in range(n):
        s = (i + 0.5) * L / n
        c = WP.at(p, s_arr, s)
        j = int(np.clip(np.searchsorted(s_arr, s), 1, len(p) - 1))
        t = p[j] - p[j - 1]
        t /= max(np.linalg.norm(t), 1e-9)
        ref = np.array([1.0, 0.0, 0.0]) if abs(t[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
        a = np.cross(t, ref)
        a /= np.linalg.norm(a)
        side = a if i % 2 == 0 else np.cross(t, a)
        _link(bld, c, t, side, lk, wk, r, part, s0 + s, 0.3 if (open_last and i == n - 1) else 0.0)
    return L


def _hook(bld, top, s0, size=0.075, r=0.014):
    """A heavy J hook hanging from `top`: an eye, the shank down, the curve up to a pointed hot tip."""
    top = np.asarray(top, float)
    _link(bld, top + np.array([0, 0, -0.02]), [0, 0, 1], [1, 0, 0], 0.045, 0.034, 0.008, "hook", s0)
    shank = [top + np.array([0, 0, -0.04 - 0.1 * k / 4]) for k in range(5)]
    c = shank[-1] + np.array([0, -size, 0])        # the curve opens toward his front
    arc = []
    for k in range(1, 13):
        a = math.pi * 1.25 * k / 12
        arc.append(c + np.array([0, size * math.cos(a), -size * math.sin(a)]))
    body = np.array(shank + arc[:9])
    radii = [r] * len(shank) + [r * (1.0 - 0.1 * k / 9) for k in range(9)]
    bld.tube(body, radii, 8, 0.0, 1.0, 0.0, 1.0, "hook", [s0 + 0.1] * len(body), cap_start=True)
    tip = np.array(arc[8:])
    bld.tube(tip, [r * 0.9 * (1 - k / (len(tip) - 1)) + 0.001 for k in range(len(tip))], 8, 0.0, 1.0, 0.0, 1.0,
             "hook_tip", [s0 + 0.12] * len(tip), cap_end=True)


def _arm_r(body, a, b):
    """The forearm's radius between joints a and b (body vertices near the segment)."""
    co = np.array([v.co[:] for v in body.data.vertices])
    a, b = np.asarray(a), np.asarray(b)
    ab = b - a
    t = np.clip(((co - a) @ ab) / ab.dot(ab), 0, 1)
    d = np.linalg.norm(co - (a + np.outer(t, ab)), axis=1)
    sel = (t > 0.2) & (t < 0.8) & (d < 0.09)
    return float(np.percentile(d[sel], 60)) if sel.sum() > 20 else 0.05


def chains(body, arm, rig, K, sp):
    """The Warchain (forearm wrap + hanging chain + hook) and the left cuff's broken chain, one skinned mesh."""
    elbow = np.array(K.bone_head(rig, "forearm.R")[:])
    wrist = np.array(K.bone_head(rig, "hand.R")[:])
    r_arm = _arm_r(body, elbow, wrist) + float(sp.get("wrap_gap", 0.012))
    ax = wrist - elbow
    L_arm = np.linalg.norm(ax)
    ax /= L_arm
    e1 = np.cross(ax, [0, 1, 0])
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(ax, e1)
    bld = WP.Builder()
    # the wrap: a spiral round the forearm from below the elbow to the wrist
    turns = float(sp.get("turns", 3.2))
    sp_pts = []
    for k in range(120):
        u0 = float(sp.get("wrap_from", 0.12))
        u = u0 + (0.92 - u0) * k / 119
        a = 2 * math.pi * turns * u
        sp_pts.append(elbow + ax * (u * L_arm) + (e1 * math.cos(a) + e2 * math.sin(a)) * r_arm)
    v0 = len(bld.v)
    _chain_along(bld, np.array(sp_pts), 0.056, 0.034, 0.0068, "chain")
    v_wrap = (v0, len(bld.v))
    # the hanging chain: from the wrist's outer side down beside the leg to the hook
    start = wrist + np.array([0.05, 0.0, -0.02])
    drop = float(sp.get("drop", 0.62))
    bvh = WP.body_bvh([body])
    p = WP.drape(bvh, [tuple(start), tuple(start + [0.03, 0.0, -drop * 0.5]), tuple(start + [0.035, 0.0, -drop])],
                 60, 0.03, length=drop)
    v1 = len(bld.v)
    L = _chain_along(bld, p, 0.06, 0.04, 0.0078, "chain")
    _hook(bld, p[-1] + np.array([0, 0, -0.01]), L)
    v_hang = (v1, len(bld.v))
    # the left cuff's short broken chain: three links and a split one, no hook
    wl = np.array(K.bone_head(rig, "hand.L")[:]) + np.array([-0.05, 0.0, 0.01])
    pl = WP.drape(bvh, [tuple(wl), tuple(wl + [-0.02, 0.0, -0.2])], 30, 0.025, length=0.2)
    v2 = len(bld.v)
    Ll = _chain_along(bld, pl, 0.055, 0.036, 0.0072, "chain", open_last=True)
    v_left = (v2, len(bld.v))
    ob = finish(bld, "Chains", {"chain": "chain", "hook": "hook", "hook_tip": "hook_tip"})
    g = ob.vertex_groups.new(name="forearm.R")
    g.add(list(range(*v_wrap)), 1.0, "REPLACE")
    tip_hang = bld.v[v_hang[1] - 1]
    names, spans = WP.chain_bones(arm, "hangwarchain", "hand.R", p, L + 0.2, int(sp.get("bones", 5)), p[-1] + np.array([0, 0, -0.2]))
    WP.weights(ob, [(vi, bld.s[vi]) for vi in range(*v_hang)], names, spans)
    names, spans = WP.chain_bones(arm, "hangcuff", "hand.L", pl, Ll, 2, pl[-1] + np.array([0, 0, -0.03]))
    WP.weights(ob, [(vi, bld.s[vi]) for vi in range(*v_left)], names, spans)
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("chains: wrap r %.3f, hanging %.2f m to the hook (tip %s), left %.2f m; %d tris" % (
        r_arm, L, tuple(round(float(x), 3) for x in tip_hang), Ll, sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ the mane
def _lock(bld, p, w0, th0, out_dir, part, s_off=0.0):
    """A chunky lock: a flattened tapered tube along p, wide across (perpendicular to out_dir), thin along it."""
    s_arr = WP.arclen(p)
    L = s_arr[-1]
    base = len(bld.v)
    sides = 5
    n = len(p)
    for i in range(n):
        t = p[min(i + 1, n - 1)] - p[max(i - 1, 0)]
        t /= max(np.linalg.norm(t), 1e-9)
        o = np.asarray(out_dir[i] if np.ndim(out_dir) == 2 else out_dir, float)
        o = o - t * o.dot(t)
        o /= max(np.linalg.norm(o), 1e-9)
        b = np.cross(t, o)
        u = s_arr[i] / L
        k = (1.0 - u) ** 0.7 * (0.75 + 0.25 * math.sin(math.pi * min(1.0, u * 2.5)))
        w = max(w0 * k, 0.0025)
        th = max(th0 * k, 0.002)
        for j in range(sides + 1):
            a = 2 * math.pi * j / sides
            bld.v.append(p[i] + b * w * math.cos(a) + o * th * math.sin(a))
            bld.uv.append((j / sides, u))
            bld.part.append(part)
            bld.s.append(s_off + s_arr[i])
    row = sides + 1
    for i in range(n - 1):
        for j in range(sides):
            a = base + i * row + j
            bld.f.append((a, a + 1, a + row + 1, a + row))
    return L


def mane(body, arm, rig, K, sp):
    """The long white mane: locks rooted in the scan's short hair, draped over the back and shoulders, each group
    on its own spring chain under the head."""
    neck = np.array(K.bone_head(rig, "head")[:])
    crown_z = float(rig["land"]["crown"])
    hc = np.array([neck[0], neck[1] + float(sp.get("centre_y", -0.01)), neck[2] + 0.55 * (crown_z - neck[2])])
    hr = float(sp.get("head_r", 0.5 * (crown_z - neck[2]) * 0.95))
    bvh = WP.body_bvh([body])
    rng = np.random.default_rng(5)
    bld = WP.Builder()
    groups = {}
    for g in sp["groups"]:
        locks = []
        for k in range(int(g["locks"])):
            az = math.radians(g["az"][0] + (g["az"][1] - g["az"][0]) * (k + 0.5) / int(g["locks"]) + rng.uniform(-4, 4))
            el = math.radians(rng.uniform(*g.get("el", [5, 35])))
            d = np.array([math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)])
            # (azimuth 0: his front, +Y; 90: his right, +X; 180: behind)
            hit = bvh.ray_cast(tuple(hc + d * hr * 2.2), tuple(-d))
            root = (np.array(hit[0][:]) if hit[0] is not None else hc + d * hr) - d * 0.012
            ln = float(g["length"]) * rng.uniform(0.82, 1.08)
            horiz = np.array([d[0], d[1], 0.0])
            horiz /= max(np.linalg.norm(horiz), 1e-6)
            ctrl = [root, root + d * 0.025 + np.array([0, 0, -0.03]),
                    root + horiz * (0.05 + float(g.get("spread", 0.05))) + np.array([0, 0, -0.12]),
                    root + horiz * (0.1 + float(g.get("spread", 0.05))) + np.array([0, 0, -ln * 0.55]),
                    root + horiz * (0.1 + float(g.get("spread", 0.05)) * 1.3) + np.array([0, 0, -ln])]
            p = WP.drape(bvh, [tuple(c) for c in ctrl], 12, float(g.get("clear", 0.03)), length=ln)
            # (a loose wave across the lock, growing toward the tip: hair, not a strap)
            side = np.cross(horiz, [0.0, 0.0, 1.0])
            u = np.linspace(0.0, 1.0, len(p))
            ph = rng.uniform(0, 2 * math.pi)
            p = p + np.outer(np.sin(u * math.pi * 2.2 + ph) * u * float(g.get("wave", 0.025)), side)
            w0 = float(g.get("width", 0.05)) * rng.uniform(0.8, 1.15)
            part = "mane" if k % 3 else "mane_dk"
            v0 = len(bld.v)
            # (flat to the head at the root, to the back further down: a root lying on the scalp, not a fin)
            u = np.linspace(0.0, 1.0, len(p))[:, None]
            k_root = np.clip(u * 4.0, 0.0, 1.0)
            outs = d[None, :] * (1 - k_root) + horiz[None, :] * k_root
            _lock(bld, p, w0, w0 * float(g.get("thick", 0.28)), outs, part)
            locks.append((p, v0, len(bld.v)))
        groups[g["name"]] = locks
    ob = finish(bld, "Mane", {"mane": "mane", "mane_dk": "mane_dk"})
    nb = int(sp.get("bones", 4))
    for name, locks in groups.items():
        # the group's chain: its locks' mean path
        m = min(len(lk[0]) for lk in locks)
        path = np.mean([WP.resample(lk[0], m)[0] for lk in locks], axis=0)
        Lg = WP.arclen(path)[-1]
        names, spans = WP.chain_bones(arm, name, "head", path, Lg, nb, path[-1] + (path[-1] - path[-2]) * 0.5)
        for p, v0, v1 in locks:
            WP.weights(ob, [(vi, bld.s[vi] * Lg / max(WP.arclen(p)[-1], 1e-6)) for vi in range(v0, v1)], names, spans)
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("mane: %d locks in %d chains, %d tris" % (sum(len(v) for v in groups.values()), len(groups),
                                                   sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ the hair cap
def cap(body, arm, rig, K, sp):
    """A smooth shell over the scan's own hair (its stringy spikes go under it): a sphere shrunk onto the body round
    the head, kept only where the nearest body vertex is painted hair, lifted `lift` m off it and smoothed. On head."""
    me = body.data
    hair_mats = {i for i, m in enumerate(me.materials) if m and m.name.startswith("hair")}
    is_hair = np.zeros(len(me.vertices), bool)
    for p in me.polygons:
        if p.material_index in hair_mats:
            is_hair[list(p.vertices)] = True
    co = np.array([v.co[:] for v in me.vertices])
    hv = co[is_hair & (co[:, 2] > float(K.bone_head(rig, "head").z) - 0.02)]
    c = (hv.min(axis=0) + hv.max(axis=0)) * 0.5
    rad = (hv.max(axis=0) - hv.min(axis=0)) * 0.5 + 0.03
    from mathutils.kdtree import KDTree
    kd = KDTree(len(co))
    for i, x in enumerate(co):
        kd.insert(x, i)
    kd.balance()
    bvh = WP.body_bvh([body])
    nu, nv = 32, 20
    verts, faces = [], []
    for j in range(nv + 1):
        th = math.pi * j / nv
        for i in range(nu):
            ph = 2 * math.pi * i / nu
            d = np.array([math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)])
            verts.append(c + d * rad)
    for j in range(nv):
        for i in range(nu):
            a, b = j * nu + i, j * nu + (i + 1) % nu
            faces.append((a, b, b + nu, a + nu))
    lift = float(sp.get("lift", 0.012))
    keep_v = np.zeros(len(verts), bool)
    out = []
    for k, v in enumerate(verts):
        loc, nrm, _i, _d = bvh.find_nearest(Vector(v))
        _p, vi, _dd = kd.find(loc)
        keep_v[k] = is_hair[vi]
        n = Vector(v) - loc
        n = n.normalized() if n.length > 1e-6 else nrm
        out.append(np.array(loc + n * lift))
    out = np.array(out)
    brow = float(sp.get("front_z", -1.0))
    if brow > 0:
        # (the face's front below the hairline stays open: the fringe locks fall there, not a helmet's brim)
        keep_v &= ~((np.array(verts)[:, 1] > c[1] + rad[1] * 0.2) & (out[:, 2] < brow))
    keep_f = [f for f in faces if sum(keep_v[list(f)]) >= 3]
    # Laplacian smoothing on the kept shell (the scan's spikes made it lumpy)
    nb = {}
    for f in keep_f:
        for a in f:
            nb.setdefault(a, set()).update(x for x in f if x != a)
    for _it in range(int(sp.get("smooth", 4))):
        new = out.copy()
        for a, ns in nb.items():
            new[a] = out[a] * 0.5 + np.mean([out[x] for x in ns], axis=0) * 0.5
        out = new
    used = sorted(nb)
    remap = {a: i for i, a in enumerate(used)}
    bld = WP.Builder()
    for a in used:
        bld.v.append(out[a]); bld.uv.append((0.5, 0.5)); bld.part.append("mane"); bld.s.append(0.0)
    for f in keep_f:
        bld.f.append(tuple(remap[a] for a in f))
    ob = finish(bld, "HairCap", {"mane": "mane"})
    g = ob.vertex_groups.new(name="head")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("hair cap: %d faces" % len(keep_f))
    return ob


# ------------------------------------------------------------------------------------------------ the collar
def collar(body, arm, rig, K, sp):
    """The broken gold champion's collar (kael_collar_sheet, his relic): a heavy band round the base of his neck,
    over the scarf, split open at the front with a chipped gap, a darker rim top and bottom and a raised plate at
    the back. Rigid on the hips."""
    neck = np.array(K.bone_head(rig, "head")[:])
    zc = neck[2] - float(sp.get("drop", 0.05))
    co = np.array([v.co[:] for v in body.data.vertices])
    band = co[np.abs(co[:, 2] - zc) < 0.012]
    d = np.hypot(band[:, 0] - neck[0], band[:, 1] - neck[1])
    d = d[d < 0.3]
    r = float(np.percentile(d, float(sp.get("pct", 85)))) + float(sp.get("gap_out", 0.012))
    tilt = float(sp.get("tilt", 0.0))       # (a torc sits lower at the front, on the chest, than at the nape)
    h, t = float(sp.get("height", 0.05)), float(sp.get("thick", 0.016))
    gap_c, gap_w = math.radians(float(sp.get("gap_at", 20.0))), math.radians(float(sp.get("gap", 34.0)))
    bld = WP.Builder()
    n = 48
    segs = []
    for i in range(n + 1):
        a = gap_c + gap_w / 2 + (2 * math.pi - gap_w) * i / n
        segs.append(a)
    rng = np.random.default_rng(9)

    def ring(a, rr, z):
        return np.array([neck[0] + math.sin(a) * rr, neck[1] + math.cos(a) * rr, z - tilt * math.cos(a)])
    for part, z0, z1, ro in (("gold", zc - h / 2 + 0.008, zc + h / 2 - 0.008, r + t), ("gold_dk", zc - h / 2, zc - h / 2 + 0.008, r + t * 1.15),
                              ("gold_dk", zc + h / 2 - 0.008, zc + h / 2, r + t * 1.15)):
        base = len(bld.v)
        for i, a in enumerate(segs):
            chip = rng.uniform(-0.004, 0.0) if i in (0, n) else 0.0
            for rr, z in ((r, z0), (ro, z0), (ro, z1 + chip), (r, z1 + chip)):
                bld.v.append(ring(a, rr, z)); bld.uv.append((0.5, 0.5)); bld.part.append(part); bld.s.append(0.0)
        for i in range(n):
            q0, q1 = base + i * 4, base + (i + 1) * 4
            for k in range(4):
                bld.f.append((q0 + k, q0 + (k + 1) % 4, q1 + (k + 1) % 4, q1 + k))
        for q in (base, base + n * 4):
            bld.f.append((q, q + 1, q + 2, q + 3))
    ob = finish(bld, "Collar", {"gold": "gold", "gold_dk": "gold_dk"})
    g = ob.vertex_groups.new(name=sp.get("bone", "hips"))
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("collar: r %.3f at z %.3f, %d tris" % (r, zc, sum(len(f) - 2 for f in bld.f)))
    return ob


def shards(body, arm, rig, K, sp):
    """The broken gold champion's collar as the turnaround and head sheet draw it on him: not a whole ring but
    chunky gold shards lying on the scarf's lower edge, one pair each side of his chest with the gap in the middle
    where it broke (kael_collar_sheet: the band, its rims, the jagged broken ends). Each piece is a curved band
    segment on a cone round the neck (`flare`: the radius grows as it drops onto the chest), its outline jagged at
    the broken ends, extruded `thick`; the face gold, the rims and broken faces darker. Rigid on `bone` (chest)."""
    neck = np.array(K.bone_head(rig, "head")[:])
    co = np.array([v.co[:] for v in body.data.vertices])
    rng = np.random.default_rng(int(sp.get("seed", 5)))
    bm = bmesh.new()
    names = ["gold", "gold_dk"]
    flare = float(sp.get("flare", 0.9))
    t = float(sp.get("thick", 0.016))
    log_r = []
    for pc in sp["pieces"]:
        a0, a1 = math.radians(pc["az"][0]), math.radians(pc["az"][1])
        zt = neck[2] - float(pc.get("drop", 0.06))
        h = float(pc.get("h", 0.045))
        # the body's radius at the piece's middle, round the neck's axis, in its direction
        am = (a0 + a1) / 2
        d2 = np.array([math.sin(am), math.cos(am)])
        rel = co[:, :2] - neck[:2]
        sel = (np.abs(co[:, 2] - (zt - h / 2)) < 0.02) & (rel @ d2 > 0) & (np.abs(rel @ np.array([d2[1], -d2[0]])) < 0.04)
        r0 = float(np.percentile(rel[sel] @ d2, 90)) if sel.sum() > 5 else 0.12
        r0 += float(pc.get("out", sp.get("out", 0.008)))
        log_r.append(round(r0, 3))
        # the outline in (u across 0..1 from a0 to a1, w down 0..1): straight-ish top and bottom, jagged ends
        n = 8
        top = [(i / n, rng.uniform(-0.06, 0.04) if 0 < i < n else 0.0) for i in range(n + 1)]
        bot = [(1 - i / n, 1.0 + rng.uniform(-0.05, 0.05) if 0 < i < n else 1.0) for i in range(n + 1)]
        jag = int(pc.get("jag", 3))
        right = [(1.0 + rng.uniform(-0.12, 0.08) * (pc.get("broken", [1, 1])[1]), (k + 1) / (jag + 1)) for k in range(jag)]
        left = [(rng.uniform(-0.08, 0.12) * (pc.get("broken", [1, 1])[0]), 1 - (k + 1) / (jag + 1)) for k in range(jag)]
        outline = top + right + bot + left

        dz0, dz1 = pc.get("dz", [0.0, 0.0])

        def at(u, w, rr):
            a = a0 + (a1 - a0) * u
            z = zt - h * w - (dz0 + (dz1 - dz0) * u)
            r = rr + flare * h * w
            return Vector((neck[0] + math.sin(a) * r, neck[1] + math.cos(a) * r, z))
        fo = [bm.verts.new(at(u, w, r0 + t)) for u, w in outline]
        fi = [bm.verts.new(at(u, w, r0)) for u, w in outline]
        f = bm.faces.new(fo)
        f.material_index = 0
        bm.faces.new(fi[::-1]).material_index = 1
        m = len(outline)
        for k in range(m):
            q = (fi[k], fi[(k + 1) % m], fo[(k + 1) % m], fo[k])
            bm.faces.new(q).material_index = 1
        # a raised rim along the top and the bottom (the collar sheet's band edges), in the darker gold
        for w0, w1 in ((0.0, 0.16), (0.84, 1.0)):
            ra = [bm.verts.new(at(u, w, r0 + t * 1.6)) for u, w in ((0.03, w0), (0.97, w0), (0.97, w1), (0.03, w1))]
            bm.faces.new(ra).material_index = 1 if pc.get("rim_dark", True) else 0
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Collar")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Collar", me)
    bpy.context.scene.collection.objects.link(ob)
    for nm in names:
        me.materials.append(mat(nm))
    paint_flat(ob)
    g = ob.vertex_groups.new(name=sp.get("bone", "hips"))
    g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("collar shards: %d pieces at r %s, %d tris" % (len(sp["pieces"]), log_r, sum(len(p.vertices) - 2 for p in me.polygons)))
    return ob


def spikes(body, arm, rig, K, sp, mane=None):
    """The crown's volume and spikes (kael_head_sheet: the white mane swept up and back off the forehead into
    jagged points): `n` chunky tapered locks rooted on the top of the head (on the mane's own surface when there is
    one, else the scan's), each rising `rise` up and sweeping back `back` m from a spread of azimuths behind the
    hairline, rigid on the head (no spring: a crown that swung would cross the face). Their own material
    (hair-spike), so they never take the head run's texture."""
    neck = np.array(K.bone_head(rig, "head")[:])
    crown_z = float(rig["land"]["crown"])
    hc = np.array([neck[0], neck[1] - 0.01, neck[2] + 0.55 * (crown_z - neck[2])])
    hr = 0.5 * (crown_z - neck[2])
    bvh = WP.body_bvh([mane] if mane is not None else [body])
    rng = np.random.default_rng(int(sp.get("seed", 7)))
    bld = WP.Builder()
    n = int(sp.get("n", 14))
    az0, az1 = sp.get("az", [100, 260])
    for k in range(n):
        az = math.radians(az0 + (az1 - az0) * (k + 0.5) / n + rng.uniform(-6, 6))
        el = math.radians(rng.uniform(*sp.get("el", [35, 75])))
        d = np.array([math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)])
        hit = bvh.ray_cast(tuple(hc + d * hr * 2.5), tuple(-d))
        root = (np.array(hit[0][:]) if hit[0] is not None else hc + d * hr) - d * float(sp.get("sink", 0.015))
        horiz = np.array([d[0], d[1], 0.0])
        horiz /= max(np.linalg.norm(horiz), 1e-6)
        ln = float(sp.get("length", 0.13)) * rng.uniform(0.7, 1.15)
        up = float(sp.get("rise", 0.5))
        tip_dir = horiz * (1.0 - up) + np.array([0, 0, up]) + d * 0.3
        tip_dir /= np.linalg.norm(tip_dir)
        p = np.array([root + d * 0.01 * t + tip_dir * ln * t + np.array([0, 0, -0.02 * t * t]) for t in np.linspace(0, 1, 7)])
        w0 = float(sp.get("width", 0.05)) * rng.uniform(0.8, 1.2)
        _lock(bld, p, w0, w0 * float(sp.get("thick", 0.35)), d, "spike" if k % 3 else "spike_dk")
    ob = finish(bld, "ManeCrown", {"spike": "spike", "spike_dk": "spike_dk"})
    g = ob.vertex_groups.new(name="head")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("crown spikes: %d, %d tris" % (n, sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ the Meshy mane
def _hsv_np(rgb):
    mx, mn = rgb.max(axis=1), rgb.min(axis=1)
    s = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)
    return s, mx


def meshy_mane(body, arm, rig, K, sp, import_glb, decimate, log_fn=log):
    """The mane from a Meshy head run (kael_head_sheet front + side): its hair faces (light, unsaturated texels)
    cut out, lined up on Kael's head by the non-hair face and scarf (width scales it, the centre and the top of
    the forehead place it), decimated to `tris`, its texture shrunk; the scalp rides the head, the rest hangs on
    spring chains per sector round the head (back, sides, the front locks), so it trails and settles. The scan's
    own stringy hair above `cut_above` (m over the head bone) is cut from the body under it."""
    import os
    src = import_glb(os.path.expanduser(sp["glb"]))
    me = src.data
    img = next(n.image for m in me.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)[..., :3]
    uv = me.uv_layers.active.data
    nf = len(me.polygons)
    cols = np.zeros((nf, 3), np.float32)
    for p in me.polygons:
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        cols[p.index] = px[min(h - 1, int(v * h)), min(w - 1, int(u * w))]
    sat, val = _hsv_np(cols)
    hair = (sat < float(sp.get("sat_max", 0.16))) & (val > float(sp.get("val_min", 0.55)))
    cen = np.array([p.center[:] for p in me.polygons])
    # the registration set: non-hair faces of the head (face and scarf), in a z band of the Meshy frame
    z0, z1 = sp.get("meshy_face_z", [0.42, 0.78])
    reg = ~hair & (cen[:, 2] > z0) & (cen[:, 2] < z1) & (np.abs(cen[:, 0]) < 0.3)
    m_pts = cen[reg]
    # Kael's: the body's non-hair vertices round the head
    hz = float(K.bone_head(rig, "head").z)
    bme = body.data
    hair_m = {i for i, m in enumerate(bme.materials) if m and m.name.startswith("hair")}
    bco = np.array([v.co[:] for v in bme.vertices])
    bhair = np.zeros(len(bco), bool)
    for p in bme.polygons:
        if p.material_index in hair_m:
            bhair[list(p.vertices)] = True
    kz0, kz1 = sp.get("kael_face_dz", [0.03, 0.2])
    kreg = ~bhair & (bco[:, 2] > hz + kz0) & (bco[:, 2] < hz + kz1) & (np.abs(bco[:, 0]) < 0.16)
    k_pts = bco[kreg]
    # Meshy faces -Y; Kael +Y: turn 180 about Z
    m_pts = m_pts * np.array([-1.0, -1.0, 1.0])
    k = float(sp.get("scale_k", 1.0)) * np.ptp(k_pts[:, 0]) / max(np.ptp(m_pts[:, 0]), 1e-6)
    mc = np.array([m_pts[:, 0].mean(), np.percentile(m_pts[:, 1], 90), m_pts[:, 2].max()])
    kc = np.array([k_pts[:, 0].mean(), np.percentile(k_pts[:, 1], 90), k_pts[:, 2].max()])
    off = kc - mc * k + np.array(sp.get("nudge", [0.0, 0.0, 0.0]))
    log_fn("meshy mane: scale %.3f, offset %s (face %d / %d points)" % (k, tuple(np.round(off, 3)), len(m_pts), len(k_pts)))
    # keep the hair faces only
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not hair[f.index]], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        x, y, z = v.co
        v.co = Vector((-x * k + off[0], -y * k + off[1], z * k + off[2]))
    fc = sp.get("face_cut")
    if fc:
        # (the head run's bangs hang over his eyes and scarf; the art keeps the face clear: hair faces in front of
        # the face, within half_x of its centre and below z_top over the head bone, go)
        hb = K.bone_head(rig, "head")
        hx, hy, hzz = float(hb.x), float(hb.y), float(hb.z)
        gone = [f for f in bm.faces if abs(f.calc_center_median().x - hx) < fc[0]
                and f.calc_center_median().y > hy + fc[1] and f.calc_center_median().z < hzz + fc[2]]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        log_fn("meshy mane: cut %d faces in front of the face" % len(gone))
    bm.to_mesh(me)
    bm.free()
    me.update()
    src.name = me.name = "Mane"
    decimate(src, int(sp.get("tris", 9000)))
    if sp.get("double_sided"):
        # (the run's hair is a single shell: from behind or through a gap the culled back faces read as holes;
        # a flipped copy of every face makes it opaque from both sides)
        bm = bmesh.new()
        bm.from_mesh(me)
        dup = bmesh.ops.duplicate(bm, geom=list(bm.faces))
        nf_ = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=nf_)
        for v in [g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)]:
            v.co -= v.normal * 0.0015
        bm.to_mesh(me)
        bm.free()
        me.update()
    # shrink its texture
    sz = int(sp.get("tex", 1024))
    img.scale(sz, sz)
    if sp.get("ramp"):
        # (the head run's hair is cream; the art's is silver-white with a faint mauve: its luminance onto the
        # art's hair ramp, p5..p95 of the hair texels dark to light, `ramp_gamma` > 1 keeps more of it light)
        q = np.array(img.pixels[:], np.float32).reshape(sz, sz, 4)
        lum = q[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
        s_, v_ = _hsv_np(q[..., :3].reshape(-1, 3))
        hm = ((s_ < 0.25) & (v_ > 0.3)).reshape(sz, sz)
        lo, hi = np.percentile(lum[hm], 5), np.percentile(lum[hm], 95)
        u = np.clip((lum - lo) / max(hi - lo, 1e-4), 0, 1) ** (1.0 / float(sp.get("ramp_gamma", 1.0)))
        ramp = np.array([[int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] for c in sp["ramp"]], np.float32)
        x = u * (len(ramp) - 1)
        i0 = np.clip(np.floor(x).astype(int), 0, len(ramp) - 2)
        f = (x - i0)[..., None]
        q[..., :3] = ramp[i0] * (1 - f) + ramp[i0 + 1] * f
        img.pixels = q.ravel()
        log_fn("meshy mane: texture onto the hair ramp (lum %.2f..%.2f)" % (lo, hi))
    img.pack()
    for m in me.materials:
        m.name = "hair-mane"
    # the scan's own hair under it: faces of the hair slot well above the head bone go
    cut = hz + float(sp.get("cut_above", 0.12))
    bm = bmesh.new()
    bm.from_mesh(bme)
    bm.faces.ensure_lookup_table()
    gone = [f for f in bm.faces if f.material_index in hair_m and f.calc_center_median().z > cut]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(bme)
    bm.free()
    log_fn("meshy mane: cut %d scan hair faces above z %.3f" % (len(gone), cut))
    # weights: the scalp on the head, each sector's hanging hair on its spring chain
    co = np.array([v.co[:] for v in me.vertices])
    hc = np.array([float(K.bone_head(rig, "head").x), float(K.bone_head(rig, "head").y) - 0.01])
    az = (np.degrees(np.arctan2(co[:, 0] - hc[0], co[:, 1] - hc[1])) + 360.0) % 360.0
    root_z = hz + float(sp.get("root_dz", 0.1))
    for g in list(src.vertex_groups):
        src.vertex_groups.remove(g)
    gh = src.vertex_groups.new(name="head")
    nb = int(sp.get("bones", 4))
    for sec in sp["sectors"]:
        a0, a1 = sec["az"]
        insec = ((az >= a0) & (az < a1)) if a0 < a1 else ((az >= a0) | (az < a1))
        below = insec & (co[:, 2] < root_z)
        if below.sum() < 30:
            continue
        zs = np.linspace(root_z, co[below, 2].min(), 8)
        path = []
        for zz in zs:
            sl = below & (np.abs(co[:, 2] - zz) < 0.03)
            if sl.sum() < 3:
                sl = below & (np.abs(co[:, 2] - zz) < 0.08)
            path.append(co[sl].mean(axis=0) if sl.sum() else co[below].mean(axis=0))
        path[0] = np.array([path[1][0], path[1][1], root_z])
        path = np.array(path)
        Lg = WP.arclen(path)[-1]
        names, spans = WP.chain_bones(arm, sec["name"], "head", path, Lg, nb, path[-1] + np.array([0, 0, -0.04]))
        idx = np.nonzero(below)[0]
        # (arc length along the chain ~ the drop below the root)
        WP.weights(src, [(int(i), float((root_z - co[i, 2]) * Lg / max(root_z - path[-1][2], 1e-6))) for i in idx],
                   names, spans)
    rest = [int(i) for i in range(len(co)) if not any(x.weight > 0 for x in me.vertices[i].groups)]
    gh.add(rest, 1.0, "REPLACE")
    src.parent = arm
    src.modifiers.new("Armature", "ARMATURE").object = arm
    log_fn("meshy mane: %d tris, %d on the head only" % (sum(len(p.vertices) - 2 for p in me.polygons), len(rest)))
    vol = sp.get("volume")
    if vol:
        src["volume"] = mane_volume(src, arm, vol, decimate, log_fn)
    return src


def mane_volume(src, arm, vp, decimate, log_fn=log):
    """A solid body for the head run's stringy hair: the mane voxel-remeshed (`voxel` m: strands closer than that
    merge into one mass), decimated to `tris`, pulled `inset` m in along its normals so the strands lie on top, in a
    flat silver (its own material, hair-mane_vol), and weighted like the strands (each vertex the nearest strand
    vertex's groups), so it swings with them and its gaps show hair, not the back."""
    from mathutils.kdtree import KDTree
    bpy.ops.object.select_all(action="DESELECT")
    ob = bpy.data.objects.new("ManeVolume", src.data.copy())
    bpy.context.scene.collection.objects.link(ob)
    me = ob.data
    me.materials.clear()
    r = ob.modifiers.new("remesh", "REMESH")
    r.mode = "VOXEL"
    r.voxel_size = float(vp.get("voxel", 0.012))
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=r.name)
    decimate(ob, int(vp.get("tris", 4000)))
    me = ob.data
    me.update()
    inset = float(vp.get("inset", 0.004))
    for v in me.vertices:
        v.co -= v.normal * inset
    # the strands' weights onto it
    sme = src.data
    kd = KDTree(len(sme.vertices))
    for v in sme.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    names = [g.name for g in src.vertex_groups]
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    groups = {n: ob.vertex_groups.new(name=n) for n in names}
    for v in me.vertices:
        _co, idx, _d = kd.find(v.co)
        for ge in sme.vertices[idx].groups:
            groups[names[ge.group]].add([v.index], ge.weight, "REPLACE")
    me.materials.append(mat("mane_vol"))
    for p in me.polygons:
        p.material_index = 0
    paint_flat(ob)
    ob.parent = arm
    for m in list(ob.modifiers):
        ob.modifiers.remove(m)
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log_fn("mane volume: %d tris (voxel %.3f, inset %.3f)" % (sum(len(p.vertices) - 2 for p in me.polygons), r.voxel_size if False else float(vp.get("voxel", 0.012)), inset))
    return ob.name

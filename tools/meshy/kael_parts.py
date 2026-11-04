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
    "blade": ("metal", "5f5c58"), "blade_dk": ("metal", "3e3c3a"), "band": ("metal", "4c4c52"),
    "guard": ("metal", "6c6a65"), "grip": ("leather", "5e2c25"), "pommel": ("metal", "6c6a65"),
    "chain": ("metal", "6e7075"), "hook": ("metal", "616368"),
    "sword": ("glow", "fffaf0"), "sword_edge": ("glow", "f2d48a"), "hook_tip": ("glow", "fffaf0"),
    "mane": ("hair", "e9e7e3"), "mane_dk": ("hair", "bdb9b4"),
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
def _outline(L0, L1, hw, seed=3):
    """The blade's outline (y along the blade, z across), base to tip and back (kael_blade_sheet): a long straight
    slab, faintly chipped along both edges, its end broken square into crenels with a notch on each side."""
    rng = np.random.default_rng(seed)
    n = 14
    yt = L1 - 0.14
    top, bot = [], []
    for i in range(n + 1):
        y = L0 + (yt - L0) * i / n
        top.append((y, hw + (rng.uniform(-0.012, 0.0) if 0 < i < n else 0.0)))
        bot.append((y, -hw - (rng.uniform(-0.012, 0.0) if 0 < i < n else 0.0)))
    # the broken end: out to a shoulder, a notch in, the crenellated top, the other notch and shoulder
    tip = [(yt + 0.03, hw * 1.12), (yt + 0.07, hw * 1.05), (yt + 0.08, hw * 0.78), (yt + 0.115, hw * 0.82),
           (L1, hw * 0.55), (L1 - 0.02, hw * 0.25), (L1 - 0.005, -hw * 0.05), (L1 - 0.03, -hw * 0.35),
           (L1 - 0.01, -hw * 0.6), (yt + 0.1, -hw * 0.85), (yt + 0.085, -hw * 1.06), (yt + 0.04, -hw * 1.1)]
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
    names = ["blade", "blade_dk", "band", "guard", "grip", "pommel", "chain", "sword_edge", "sword"]
    mi = {n: i for i, n in enumerate(names)}
    bm = bmesh.new()
    out = _outline(L0, L1, hw)
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
        _ribbon(bm, main, cw * 1.25, x, mi["sword_edge"], taper=False)
        _ribbon(bm, main, cw, s * 0.0318, mi["sword"], taper=False)
        for br in branches:
            _ribbon(bm, br, 0.016, x, mi["sword_edge"])
            _ribbon(bm, br, 0.008, s * 0.0318, mi["sword"])
    # the bar guard, the wrapped grip, the pommel (the sheet's pommel hook is NOT his: the one hook is the chain's)
    _box(bm, (0, L0 - 0.03, 0), (0.055, 0.045, hw * 1.55), mi["guard"])
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
    for i in range(6):
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
        u = 0.12 + 0.8 * k / 119
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
            _lock(bld, p, w0, w0 * 0.38, horiz, part)
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

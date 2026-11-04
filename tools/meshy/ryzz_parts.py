"""Ryzz's (mage) pieces built in Blender by script on the fitted Meshy body (tools/meshy/fit_warden.py `scripted`;
docs/art/wardens/PIPELINE.md "Ryzz"), from the locked art (ext/imagegen docs/art/gen/wardens_r3/ryzz_* + RYZZ_KIT.md):

- pigtails(): the SHORT twin pigtails (owner: long twin tails read as a famous existing character): one copper-coil
  tie on each of the scan's hair knots, then a bunch of chunky tapered locks that flick up and out and fall in a
  short wave, blue at the root to hot pink at the zigzag tips. Each rides a short `spring_pigtail_<L|R>_<i>` chain
  under the head that WardenGlb.Springs swings.
- rods(): exactly three copper lightning rods on her back in a riveted copper mount, rigid on the hips (the torso):
  the outer two fan up past her shoulders, the middle one (her relic, the first rod she climbed) scorched black
  and bent where the storm struck it.

Each set has its own small atlas: flat colour cells (the loader wants every surface on a texture) and, for the
hair, a root-to-tip gradient. All in the fitted frame: Blender, +Z up, her front +Y, her right +X, soles on Z = 0.
"""
import math

import bpy
import numpy as np

import warden_parts as WP


def log(*a):
    print("RYZZPARTS", *a, flush=True)


def _lin(hexc):
    # (the atlas is a byte image in sRGB: Blender stores its pixels as given, so the art's hex goes in as is)
    return WP.hexcol(hexc)


ATLAS = 256


def _atlas(name, cells, gradients=()):
    """A 256 atlas: flat 32 px cells (row-major from the bottom, 8 a row, the first four rows) and, in the top half,
    vertical gradients (one 32 px column each: [(v, hex), ...] from v 0 at y 128 to v 1 at the top)."""
    img = bpy.data.images.new(name, ATLAS, ATLAS, alpha=False)
    px = np.ones((ATLAS, ATLAS, 4), np.float32)
    for i, hexc in enumerate(cells):
        r, q = divmod(i, 8)
        px[r * 32:(r + 1) * 32, q * 32:(q + 1) * 32, :3] = _lin(hexc)
    for gi, stops in enumerate(gradients):
        vs = np.array([s[0] for s in stops])
        cs = np.array([_lin(s[1]) for s in stops])
        for y in range(128, ATLAS):
            v = (y - 128) / 127.0
            col = np.array([np.interp(v, vs, cs[:, k]) for k in range(3)])
            px[y, gi * 32:(gi + 1) * 32, :3] = col
            # (fine hair lines across the column)
            px[y, gi * 32:(gi + 1) * 32, :3] *= (0.93 + 0.07 * np.sin(np.arange(32) * 1.9))[:, None]
    img.pixels = px.ravel()
    img.pack()
    return img


def _cell_uv(i):
    r, q = divmod(i, 8)
    return ((q * 32 + 16) / ATLAS, (r * 32 + 16) / ATLAS)


def _grad_uv(gi, u, v):
    """A point in gradient column gi: u across (0..1), v along (0 root .. 1 tip)."""
    return ((gi * 32 + 2 + 28 * u) / ATLAS, (129 + 125 * v) / ATLAS)


def _material(ob, name, img):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    ob.data.materials.append(m)
    return len(ob.data.materials) - 1


def _uv_flat(ob, bld, cell_of_part, grad_of_part=None):
    """Faces on their part's flat cell; gradient parts keep the builder's (u, v) mapped into their column."""
    me = ob.data
    uv = me.uv_layers.active.data
    for p in me.polygons:
        part = bld.part[p.vertices[0]]
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            if grad_of_part and part in grad_of_part:
                u, v = bld.uv[vi]
                uv[li].uv = _grad_uv(grad_of_part[part], u % 1.0, min(max(v, 0.0), 1.0))
            else:
                uv[li].uv = _cell_uv(cell_of_part[part])


def _head_centre(rig, K, sp):
    neck = np.array(K.bone_head(rig, "head")[:])
    crown = float(rig["land"]["crown"])
    return neck, crown


# ------------------------------------------------------------------------------------------------ pigtails
def _lock(bld, p, w0, th0, out_dir, part, s_off=0.0, flat_k=1.0):
    """A chunky lock: a flattened tapered tube along p, wide across (perpendicular to out_dir), thin along it;
    UV u around, v root (0) to tip (1)."""
    s_arr = WP.arclen(p)
    L = s_arr[-1]
    base = len(bld.v)
    sides = 6
    n = len(p)
    for i in range(n):
        t = p[min(i + 1, n - 1)] - p[max(i - 1, 0)]
        t /= max(np.linalg.norm(t), 1e-9)
        o = np.asarray(out_dir, float)
        o = o - t * o.dot(t)
        o /= max(np.linalg.norm(o), 1e-9)
        b = np.cross(t, o)
        u = s_arr[i] / L
        # (chunky to the end: the zigzag tips stay a lock's width, not a thread, and close in a point)
        k = max((1.0 - u) ** 0.6, 0.35 * (1.0 - u) / 0.15 if u > 0.85 else 0.35) * (0.8 + 0.35 * math.sin(math.pi * min(1.0, u * 1.6)))
        w = max(w0 * k, 0.0015)
        th = max(th0 * k * flat_k, 0.0012)
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
    tip = len(bld.v)                 # (a point at the tip, so the lock ends sharp)
    bld.v.append(p[-1] + (p[-1] - p[-2]) * 0.6)
    bld.uv.append((0.5, 1.0))
    bld.part.append(part)
    bld.s.append(s_off + L)
    for j in range(sides):
        a = base + (n - 1) * row + j
        bld.f.append((a, a + 1, tip))
    return L


def _frame(d):
    d = np.asarray(d, float)
    d /= np.linalg.norm(d)
    ref = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    e1 = np.cross(d, ref)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(d, e1)
    return d, e1, e2


def _coil(bld, c, d, r, length, turns, wire, part):
    """A copper coil tie: a helix tube of `turns` turns round axis d, centred on c, with end rings."""
    d, e1, e2 = _frame(d)
    n = int(24 * turns)
    pts = []
    for k in range(n + 1):
        f = k / n
        a = 2 * math.pi * turns * f
        pts.append(c + d * (length * (f - 0.5)) + (e1 * math.cos(a) + e2 * math.sin(a)) * r)
    bld.tube(pts, [wire] * len(pts), 5, 0, 1, 0, 1, part, [0.0] * len(pts), cap_start=True, cap_end=True)
    for end in (-0.5, 0.5):
        bld.torus(c + d * length * end, d, r, wire * 1.25, 18, 5, (0, 0, 1, 1), part, 0.0)


def pigtails(body, arm, rig, K, sp):
    neck, crown = _head_centre(rig, K, sp)
    bvh = WP.body_bvh([body])
    rng = np.random.default_rng(11)
    bld = WP.Builder()
    chains = []
    L = float(sp.get("length", 0.2))
    for side in ("L", "R"):
        ss = sp[side]
        sx = 1.0 if side == "R" else -1.0           # (her right +X)
        root = neck + np.asarray(ss["root"], float)
        d, e1, e2 = _frame(ss.get("dir", [0.6 * sx, -0.1, 0.8]))
        cr = float(sp.get("coil_r", 0.026))
        cl = float(sp.get("coil_len", 0.028))
        _coil(bld, root + d * cl * 0.5, d, cr, cl, float(sp.get("coil_turns", 4.0)), float(sp.get("wire", 0.0042)),
              "copper")
        start = root + d * cl * 0.85
        out = np.array([sx, 0.0, 0.0])
        locks = []
        nl = int(sp.get("locks", 14))
        for k in range(nl):
            ang = 2 * math.pi * k / nl + rng.uniform(-0.25, 0.25)
            rad = cr * rng.uniform(0.15, 0.75)
            off = (e1 * math.cos(ang) + e2 * math.sin(ang))
            s0 = start + off * rad
            flick = k % 4 == 0                         # (the art's upper tips that spike up and out)
            ln = L * (rng.uniform(0.45, 0.6) if flick else rng.uniform(0.85, 1.1))
            spread = off * float(sp.get("spread", 0.03))
            if flick:
                ctrl = [s0, s0 + d * ln * 0.45 + spread, s0 + d * ln * 0.75 + out * ln * 0.25 + spread * 1.6,
                        s0 + d * ln * 0.8 + out * ln * 0.55 + spread * 2 + np.array([0, 0, 0.01])]
            else:
                # up and out off the knot, then over and down in a short wave
                ctrl = [s0, s0 + d * 0.05 + spread, s0 + d * 0.07 + out * 0.06 + spread * 1.5 + np.array([0, 0, -0.01]),
                        s0 + out * 0.09 + spread * 1.8 + np.array([0, 0, -ln * 0.45]),
                        s0 + out * 0.075 + spread * 2.0 + np.array([0, 0, -ln * 0.8])]
            p, _ = WP.resample(ctrl, int(sp.get("samples", 14)))
            # smooth the control polyline into a curve
            for _it in range(6):
                p[1:-1] = p[1:-1] * 0.5 + (p[:-2] + p[2:]) * 0.25
            p = WP.drape(bvh, [tuple(c) for c in p], len(p), float(sp.get("clear", 0.02)), iters=20, length=None)
            # the zigzag ends: a sawtooth across the lock over its last third
            s_arr = WP.arclen(p)
            Lp = s_arr[-1]
            zz = float(sp.get("zigzag", 0.011))
            side_v = np.cross(p[-1] - p[-4], [0, 1, 0])
            side_v /= max(np.linalg.norm(side_v), 1e-9)
            for i in range(len(p)):
                f = s_arr[i] / Lp
                if f > 0.62:
                    tri = 2.0 * abs(((f - 0.62) / 0.38 * 2.5) % 1.0 - 0.5) - 0.5
                    p[i] = p[i] + side_v * tri * zz * 2 * min(1.0, (f - 0.62) * 6)
            w0 = float(sp.get("width", 0.024)) * rng.uniform(0.8, 1.2)
            part = "lock" if k % 4 else "lock_dk"
            v0 = len(bld.v)
            _lock(bld, p, w0, w0 * float(sp.get("thick", 0.5)), off if flick else out, part)
            locks.append((p, v0, len(bld.v), flick))
        chains.append((side, locks))
    ob = bld.object("Pigtails")
    img = _atlas("pigtail_atlas", ["b87333", "8a5228"],
                 [[(0.0, "5a8fdc"), (0.45, "79aef0"), (0.72, "d070d0"), (1.0, "ff5fb8")],
                  [(0.0, "4a7cc8"), (0.45, "6698dc"), (0.72, "bc5cbc"), (1.0, "f04ca6")]])
    mh = _material(ob, "hair-pigtail", img)
    mm = _material(ob, "metal-pigtail", img)
    for p in ob.data.polygons:
        p.material_index = mm if bld.part[p.vertices[0]] == "copper" else mh
    _uv_flat(ob, bld, {"copper": 0}, {"lock": 0, "lock_dk": 1})
    nb = int(sp.get("bones", 3))
    for side, locks in chains:
        falls = [lk for lk in locks if not lk[3]]
        m = int(sp.get("samples", 14))
        path = np.mean([WP.resample(lk[0], m)[0] for lk in falls], axis=0)
        Lg = WP.arclen(path)[-1]
        names, spans = WP.chain_bones(arm, "pigtail_" + side, "head", path, Lg, nb, path[-1] + (path[-1] - path[-2]))
        for p, v0, v1, _f in locks:
            Lp = max(WP.arclen(p)[-1], 1e-6)
            WP.weights(ob, [(vi, bld.s[vi] * Lg / Lp) for vi in range(v0, v1)], names, spans)
    # the coils ride the head rigidly
    g = ob.vertex_groups.get("head") or ob.vertex_groups.new(name="head")
    coil = [i for i, pt in enumerate(bld.part) if pt == "copper"]
    g.add(coil, 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("pigtails: %d locks, %.2f m, %d tris" % (sum(len(l) for _s, l in chains), L, sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ the rods
ROD_COL = ["c07a45", "8f5530", "2f2a30", "1c1816", "4a3a30", "d08c55", "6b4a3a"]
# copper, copper_dk, sleeve, scorch, scorch_mid, tip, plate (the riveted mount)
ROD_CELL = {"copper": 0, "copper_dk": 1, "sleeve": 2, "scorch": 3, "scorch_mid": 4, "tip": 5, "plate": 6}


def _back_point(bvh, x, z, y_front=0.3):
    """Her back's surface at (x, z): a ray from behind toward +Y."""
    hit = bvh.ray_cast((x, -1.0, z), (0.0, 1.0, 0.0))
    return np.array(hit[0][:]) if hit[0] is not None else np.array([x, -0.08, z])


def _rod(bld, p, r, parts_along, s0=0.0):
    """A rod along path p: tube segments coloured by parts_along [(f0, f1, part)], collars, and a spear tip."""
    s_arr = WP.arclen(p)
    L = s_arr[-1]
    for f0, f1, part in parts_along:
        sel = [i for i in range(len(p)) if f0 * L - 1e-6 <= s_arr[i] <= f1 * L + 1e-6]
        if len(sel) < 2:
            continue
        seg = p[sel[0]:sel[-1] + 1]
        rr = r * (1.35 if part == "sleeve" else 1.0)
        bld.tube(seg, [rr] * len(seg), 8, 0, 1, 0, 1, part, list(s_arr[sel[0]:sel[-1] + 1]), cap_start=True,
                 cap_end=True)
    return L


def rods(body, arm, rig, K, sp):
    bvh = WP.body_bvh([body])
    bld = WP.Builder()
    sh_z = float(K.bone_head(rig, "upper_arm.L").z)
    neck, crown = _head_centre(rig, K, sp)
    gap = float(sp.get("gap", 0.035))
    # the mount: a riveted copper plate on the upper back
    pz = sh_z + float(sp.get("plate_dz", -0.15))
    pc = _back_point(bvh, 0.0, pz)
    pc[1] = min(float(_back_point(bvh, x, z)[1]) for x in (-0.06, 0.0, 0.06) for z in (pz - 0.035, pz, pz + 0.035))
    pw, ph, pt = float(sp.get("plate_w", 0.13)), float(sp.get("plate_h", 0.07)), 0.012
    py = pc[1] - pt * 0.5 - 0.004
    bld.prism([0, py + pt * 0.5, pz], [0, py - pt * 0.5, pz], 1.0, 4, (0, 0, 1, 1), "plate", 0.0, rot=math.pi / 4)
    # (a prism of radius 1 is rescaled below into the plate's box)
    plate_v = list(range(len(bld.v) - 12, len(bld.v)))
    for vi in plate_v:
        v = np.asarray(bld.v[vi], float)
        bld.v[vi] = np.array([np.sign(v[0]) * pw * 0.5 if abs(v[0]) > 1e-6 else 0.0, v[1],
                              pz + (np.sign(v[2] - pz) * ph * 0.5 if abs(v[2] - pz) > 1e-6 else 0.0)])
    for rx in (-0.8, 0.8):
        for rz in (-0.7, 0.7):
            c = np.array([rx * pw * 0.5, py - pt * 0.5, pz + rz * ph * 0.5])
            bld.prism(c, c + [0, -0.006, 0], 0.0055, 6, (0, 0, 1, 1), "copper", 0.0)
    r = float(sp.get("r", 0.0095))
    bottom_z = pz - float(sp.get("below", 0.2))
    # (the rods stand clear of the furthest point of her back and the jacket over their span, not just the mount's)
    back_y = min(float(_back_point(bvh, x, z)[1]) for x in (-0.1, -0.05, 0.0, 0.05, 0.1)
                 for z in np.linspace(bottom_z, sh_z + 0.1, 14))
    rod_y = min(py - pt, back_y) - r - gap * 0.3
    top_z = crown + float(sp.get("mid_top", 0.02))
    side_top = sh_z + float(sp.get("side_top", 0.32))
    side_x = float(sp.get("side_x", 0.17))
    # the outer rods: from low on the back, through the mount, up past each shoulder
    for sx in (-1.0, 1.0):
        a = np.array([sx * 0.025, rod_y, bottom_z])
        b = np.array([sx * side_x, rod_y - 0.03, side_top])
        p, _ = WP.resample([a, b], 30)
        _rod(bld, p, r, [(0.0, 0.08, "copper"), (0.08, 0.36, "sleeve"), (0.36, 0.4, "copper_dk"),
                         (0.4, 0.62, "copper"), (0.62, 0.66, "copper_dk"), (0.66, 1.0, "copper")])
        t = (b - a) / np.linalg.norm(b - a)
        for f in (0.36, 0.62):          # collars
            c = a + (b - a) * f
            bld.torus(c, t, r * 1.25, r * 0.55, 14, 5, (0, 0, 1, 1), "copper_dk", 0.0)
        _spear(bld, b, t, r, "tip")
    # the middle rod, the relic: straight through the mount, then bent where the bolt struck and scorched black
    a = np.array([0.0, rod_y - 0.005, bottom_z - 0.02])
    ctrl = [a, a + [0, 0, 0.3], a + [0.03, -0.01, 0.38], a + [-0.03, -0.02, 0.46], a + [0.025, -0.03, 0.55],
            np.array([-0.01, rod_y - 0.04, top_z])]
    p, _ = WP.resample(ctrl, 60)
    for _it in range(4):
        p[1:-1] = p[1:-1] * 0.5 + (p[:-2] + p[2:]) * 0.25
    _rod(bld, p, r * 0.95, [(0.0, 0.08, "copper_dk"), (0.08, 0.36, "sleeve"), (0.36, 0.5, "scorch_mid"),
                            (0.5, 1.0, "scorch")])
    t = (p[-1] - p[-3]) / np.linalg.norm(p[-1] - p[-3])
    _spear(bld, p[-1], t, r * 0.95, "scorch", bent=True)
    ob = bld.object("Rods")
    img = _atlas("rods_atlas", ROD_COL)
    _material(ob, "metal-rods", img)
    _uv_flat(ob, bld, ROD_CELL)
    g = ob.vertex_groups.new(name="hips")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("rods: %.3f m behind the hips' plane;" % -rod_y, "mount at z %.3f (back y %.3f), outer tips z %.3f, the relic's tip z %.3f; %d tris" % (
        pz, float(pc[1]), side_top, top_z, sum(len(f) - 2 for f in bld.f)))
    return ob


def _spear(bld, base, t, r, part, bent=False):
    """A spear tip: a short collar and a four-sided point (the scorched one blunted and kinked)."""
    t = np.asarray(t, float)
    bld.prism(base - t * 0.004, base + t * 0.01, r * 1.5, 6, (0, 0, 1, 1), part, 0.0)
    ln = 0.03 if bent else 0.05
    d, e1, e2 = _frame(t)
    if bent:
        d = (d + e1 * 0.5) / np.linalg.norm(d + e1 * 0.5)
    b0 = base + t * 0.01
    base_i = len(bld.v)
    for j in range(4):
        a = math.pi / 4 + j * math.pi / 2
        bld.v.append(b0 + (e1 * math.cos(a) + e2 * math.sin(a)) * r * 1.7)
        bld.uv.append((0.5, 0.5))
        bld.part.append(part)
        bld.s.append(0.0)
    tip = len(bld.v)
    bld.v.append(b0 + d * ln)
    bld.uv.append((0.5, 0.5))
    bld.part.append(part)
    bld.s.append(0.0)
    for j in range(4):
        bld.f.append((base_i + j, base_i + (j + 1) % 4, tip))
    bld.f.append(tuple(base_i + j for j in (3, 2, 1, 0)))


def build(body, arm, rig, K, spec):
    """fit_warden's `scripted` hook: every piece in spec, as skinned meshes."""
    out = []
    if spec.get("pigtails"):
        out.append(pigtails(body, arm, rig, K, spec["pigtails"]))
    if spec.get("rods"):
        out.append(rods(body, arm, rig, K, spec["rods"]))
    return out

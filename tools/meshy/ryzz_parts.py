"""Sparkle's (mage) pieces built in Blender by script on the fitted Meshy body (tools/meshy/fit_warden.py `scripted`;
docs/art/wardens/PIPELINE.md "Sparkle"), from the locked art (ext/imagegen docs/art/gen/wardens_r3/ryzz_* + RYZZ_KIT.md):

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
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

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
def _lock(bld, p, w0, th0, out_dir, part, s_off=0.0, flat_k=1.0, sides=6, vk=1.0, root=0.0):
    """A chunky lock: a flattened tapered tube along p, wide across (perpendicular to out_dir), thin along it;
    UV u around, v root (0) to tip (1)."""
    s_arr = WP.arclen(p)
    L = s_arr[-1]
    base = len(bld.v)
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
        if root > 0.0:              # (narrow into the tie: no open rings stacked at the root)
            k *= min(1.0, 0.35 + 0.65 * u / root)
        w = max(w0 * k, 0.0015)
        th = max(th0 * k * flat_k, 0.0012)
        for j in range(sides + 1):
            a = 2 * math.pi * j / sides
            bld.v.append(p[i] + b * w * math.cos(a) + o * th * math.sin(a))
            bld.uv.append((j / sides, u * vk))
            bld.part.append(part)
            bld.s.append(s_off + s_arr[i])
    row = sides + 1
    for i in range(n - 1):
        for j in range(sides):
            a = base + i * row + j
            bld.f.append((a, a + 1, a + row + 1, a + row))
    tip = len(bld.v)                 # (a point at the tip, so the lock ends sharp)
    bld.v.append(p[-1] + (p[-1] - p[-2]) * 0.6)
    bld.uv.append((0.5, vk))
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


def _squash_knot(body, c, R, k):
    """The scan's hair knot pulled in toward its centre (the tie and the locks' roots hide what is left)."""
    n = 0
    for v in body.data.vertices:
        d = (np.asarray(v.co[:]) - c)
        r = float(np.linalg.norm(d))
        if r < R:
            f = k + (1.0 - k) * (r / R) ** 2
            v.co = tuple(c + d * f)
            n += 1
    body.data.update()
    return n


def pigtails(body, arm, rig, K, sp):
    neck, crown = _head_centre(rig, K, sp)
    for side in ("L", "R"):
        if sp.get("knot_r"):
            log("pigtail %s: knot squashed (%d verts)" % (side, _squash_knot(
                body, neck + np.asarray(sp[side]["root"], float), float(sp["knot_r"]), float(sp.get("knot_k", 0.5)))))
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
        # (the tie sits round the scan's hair knot, which it and the locks' roots hide)
        _coil(bld, root + d * cl * 0.5, d, cr, cl, float(sp.get("coil_turns", 4.0)), float(sp.get("wire", 0.0042)),
              "copper")
        start = root + d * cl * 0.7
        out = np.array([sx, 0.0, 0.0])
        up = np.array([0.0, 0.0, 1.0])
        locks = []
        # two tiers: the smooth blue body of the bunch (many locks, ending inside the curls, mostly blue) and the
        # few thick S-curl ends swooping outward with the pink (`ends`)
        tiers = [dict(sp, tier="body")] + ([dict(sp, **sp["ends"], tier="ends")] if sp.get("ends") else [])
        for T in tiers:
            nl = int(T.get("locks", 14))
            S = np.asarray(T.get("curl", [[0.04, 0.0, 0.0], [0.07, 0.0, 0.045], [0.105, 0.0, -0.02],
                                        [0.085, 0.0, -0.1], [0.115, 0.0, -0.155], [0.09, 0.0, -0.19]]), float)
            for k in range(nl):
                ang = 2 * math.pi * k / nl + rng.uniform(-0.25, 0.25)
                rad = cr * rng.uniform(0.2, 0.8)
                off = (e1 * math.cos(ang) + e2 * math.sin(ang))
                s0 = start + off * rad
                fe = int(T.get("flick_every", 5))
                flick = fe > 0 and k % fe == 0             # (the art's few tips that spike up out of the puff)
                spread = off * float(T.get("spread", 0.03))
                yk = rng.uniform(-1.0, 1.0) * float(T.get("depth", 0.025))     # (front to back across the mass)
                sk = rng.uniform(0.85, 1.1)
                if flick:
                    ln = L * rng.uniform(0.4, 0.55)
                    ctrl = [s0, s0 + d * ln * 0.4 + spread, s0 + d * ln * 0.75 + out * ln * 0.3 + spread * 1.6,
                            s0 + d * ln * 0.85 + out * ln * 0.65 + spread * 2 + up * 0.01]
                else:
                    # the S-curl: up and out off the tie into a puff, over and down outside, in, out, and in at the jaw
                    ctrl = [s0, s0 + d * S[0][0] + spread * 0.5]
                    for q in S[1:]:
                        ctrl.append(s0 + out * q[0] * sk + up * q[2] * sk + np.array([0.0, yk + q[1], 0.0]) + spread * 1.4)
                p, _ = WP.resample(ctrl, int(T.get("samples", 14)))
                # smooth the control polyline into a curve
                for _it in range(int(T.get("smooth", 2))):
                    p[1:-1] = p[1:-1] * 0.5 + (p[:-2] + p[2:]) * 0.25
                p = WP.drape(bvh, [tuple(c) for c in p], len(p), float(T.get("clear", 0.02)), iters=6, smooth=0.05, length=None)
                # soft curls: each lock coils round its own path over its lower half, its own phase (a curly mass)
                cr_ = float(T.get("curl_r", 0.0))
                if cr_ > 0 and not flick:
                    s_c = WP.arclen(p)
                    tt, nn, bb = WP.frames(p, [0.0, 1.0, 0.0])
                    ph = rng.uniform(0, 2 * math.pi)
                    per = float(T.get("curl_period", 0.07))
                    for i in range(len(p)):
                        f = s_c[i] / s_c[-1]
                        f0 = float(T.get("curl_from", 0.45))
                        g = max(0.0, (f - f0) / (1.0 - f0)) ** float(T.get("curl_pow", 1.0))
                        a = 2 * math.pi * s_c[i] / per + ph
                        p[i] = p[i] + (nn[i] * math.cos(a) + bb[i] * math.sin(a)) * cr_ * g
                # the zigzag ends: a sawtooth across the lock over its last third
                s_arr = WP.arclen(p)
                Lp = s_arr[-1]
                zz = float(T.get("zigzag", 0.011))
                side_v = np.cross(p[-1] - p[-4], [0, 1, 0])
                side_v /= max(np.linalg.norm(side_v), 1e-9)
                for i in range(len(p)):
                    f = s_arr[i] / Lp
                    if f > 0.75:
                        tri = 2.0 * abs(((f - 0.75) / 0.25 * 1.5) % 1.0 - 0.5) - 0.5
                        p[i] = p[i] + side_v * tri * zz * 2 * min(1.0, (f - 0.75) * 8)
                bl = float(T.get("body_len", 1.0))
                if bl < 1.0 and not flick:
                    s_b = WP.arclen(p)
                    tq = np.linspace(0.0, s_b[-1] * bl, len(p))
                    p = np.stack([np.interp(tq, s_b, p[:, i]) for i in range(3)], axis=1)
                w0 = float(T.get("width", 0.024)) * rng.uniform(0.8, 1.2)
                se = int(T.get("streak_every", 0))
                part = "lock_pk" if (se and k % se == 2) or flick else ("lock" if k % 4 else "lock_dk")
                v0 = len(bld.v)
                if part == "lock_pk":
                    w0 *= float(T.get("streak_w", 1.0))       # (the streaks: thinner pink locks among the blue)
                _lock(bld, p, w0, w0 * float(T.get("thick", 0.5)), off if flick else out, part, sides=int(T.get("sides", 6)),
                      vk=float(T.get("v_k", 1.0)), root=float(T.get("root_taper", 0.0)))
                locks.append((p, v0, len(bld.v), flick))
        chains.append((side, locks))
    ob = bld.object("Pigtails")
    img = _atlas("pigtail_atlas", ["b87333", "8a5228"],
                 [[(0.0, "5f8fd4"), (0.5, "84b4ee"), (0.68, "c878d0"), (0.85, "f060b0"), (1.0, "ff7ec4")],
                  [(0.0, "4c78bc"), (0.5, "6c9cdc"), (0.68, "b464bc"), (0.85, "e04c9e"), (1.0, "f46ab4")],
                  [(0.0, "e45aa8"), (0.35, "f078bc"), (0.6, "c870cc"), (0.85, "f060b0"), (1.0, "ff7ec4")]])
    mh = _material(ob, "hair-pigtail", img)
    mm = _material(ob, "metal-pigtail", img)
    for p in ob.data.polygons:
        p.material_index = mm if bld.part[p.vertices[0]] == "copper" else mh
    _uv_flat(ob, bld, {"copper": 0}, {"lock": 0, "lock_dk": 1, "lock_pk": 2})
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
ROD_COL = ["a86a48", "7a4a32", "2f2a30", "1c1816", "4a3a30", "b87a58", "8a5a3e", "2a2226"]
# copper, copper_dk, sleeve, scorch, scorch_mid, tip, plate (the riveted mount), strap
ROD_CELL = {"copper": 0, "copper_dk": 1, "sleeve": 2, "scorch": 3, "scorch_mid": 4, "tip": 5, "plate": 6, "strap": 7}


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
    seat = float(sp.get("seat", 0.004))
    # (the relic seated in the V below her shoulder line, as ryzz_back draws it, or up to the crown)
    top_z = sh_z + float(sp["mid_top_abs"]) if "mid_top_abs" in sp else crown + float(sp.get("mid_top", 0.02))
    side_top = sh_z + float(sp.get("side_top", 0.32))
    side_x = float(sp.get("side_x", 0.17))

    def seated(x0, x1, z0, z1, n=30):
        """A straight rod from (x0, z0) to (x1, z1) seated on her back: its depth follows the back's slope and is
        pushed out just enough that it clears the back, the jacket and the mount everywhere along it."""
        zs = np.linspace(z0, z1, n)
        xs = np.linspace(x0, x1, n)
        lim = []
        for x, z in zip(xs, zs):
            y = float(_back_point(bvh, x, z)[1]) if z < sh_z + 0.12 else 1.0      # (above her shoulders: free)
            if abs(x) <= pw * 0.5 + r and abs(z - pz) <= ph * 0.5 + r:
                y = min(y, py - pt * 0.5)
            if "seat_top" in sp and z > pz + float(sp["seat_top"]):
                y = 1.0                 # (flush between the shoulder blades: the jacket's collar above doesn't push it off)
            lim.append(y - r - seat)
        lim = np.array(lim)
        z_hi_cap = pz + float(sp["seat_top"]) if "seat_top" in sp else sh_z + 0.05
        z_lo, z_hi = z0, min(z1, z_hi_cap)
        y_lo = float(np.interp(z_lo, zs, lim))
        y_hi = float(np.interp(z_hi, zs, lim))
        # (leaning back with her back's slope, never forward over her head)
        slope = float(np.clip((y_hi - y_lo) / max(z_hi - z_lo, 1e-3), -0.35, -0.05))
        line = y_lo + (zs - z_lo) * slope
        seat_m = zs <= z_hi_cap
        line -= max(0.0, float((line - lim)[seat_m].max()))
        return np.stack([xs, line, zs], axis=1)

    rod_ys = []
    # the outer rods: from low on the back, through the mount, up past each shoulder
    for sx in (-1.0, 1.0):
        p = seated(sx * 0.025, sx * side_x, bottom_z, side_top)
        a, b = p[0], p[-1]
        rod_ys.append(float(np.interp(pz, p[:, 2], p[:, 1])))
        _rod(bld, p, r, [(0.0, 0.08, "copper"), (0.08, 0.36, "sleeve"), (0.36, 0.4, "copper_dk"),
                         (0.4, 0.62, "copper"), (0.62, 0.66, "copper_dk"), (0.66, 1.0, "copper")])
        t = (b - a) / np.linalg.norm(b - a)
        for f in (0.36, 0.62):          # collars
            c = a + (b - a) * f
            bld.torus(c, t, r * 1.25, r * 0.55, 14, 5, (0, 0, 1, 1), "copper_dk", 0.0)
        _spear(bld, b, t, r, "tip")
    # the middle rod, the relic: straight through the mount, then bent where the bolt struck and scorched black
    base = seated(0.0, -0.01, bottom_z - 0.02, top_z, 60)
    rod_ys.append(float(np.interp(pz, base[:, 2], base[:, 1])))
    L0 = top_z - (bottom_z - 0.02)
    bend = np.zeros_like(base)
    for i, z in enumerate(base[:, 2]):
        f = (z - (bottom_z - 0.02)) / L0
        if f > 0.5:       # (a kinked S over its upper half, bent back a little)
            g = (f - 0.5) / 0.5
            bend[i] = [0.03 * math.sin(g * math.pi * 2.2), -0.025 * g, 0.0]
    p = base + bend
    for _it in range(3):
        p[1:-1] = p[1:-1] * 0.5 + (p[:-2] + p[2:]) * 0.25
    _rod(bld, p, r * 0.95, [(0.0, 0.08, "copper_dk"), (0.08, 0.36, "sleeve"), (0.36, 0.5, "scorch_mid"),
                            (0.5, 1.0, "scorch")])
    t = (p[-1] - p[-3]) / np.linalg.norm(p[-1] - p[-3])
    _spear(bld, p[-1], t, r * 0.95, "scorch", bent=True)
    # two leather straps across the mount, over the rods, riveted at their ends
    sy = min(rod_ys) - r * 1.4 - 0.004
    for dz in (-0.3, 0.3):
        z = pz + dz * ph
        a_, b_ = np.array([-pw * 0.55, sy, z]), np.array([pw * 0.55, sy, z])
        bld.prism(a_, b_, float(sp.get("strap_w", 0.012)), 4, (0, 0, 1, 1), "strap", 0.0, rot=math.pi / 4)
        for sx in (-1.0, 1.0):
            c = np.array([sx * pw * 0.5, sy - 0.008, z])
            bld.prism(c, c + [0, -0.004, 0], 0.005, 6, (0, 0, 1, 1), "copper", 0.0)
    rod_y = min(rod_ys)
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


def nose_ring(body, arm, rig, K, sp):
    """The septum ring (a small copper hoop under the nose tip, rigid on the head): the scan smeared its own into a
    checker, which the fit paints over as skin."""
    bvh = WP.body_bvh([body])
    x, z = float(sp.get("x", 0.012)), float(sp.get("z", 1.62))
    best = None
    for dz in np.linspace(-0.03, 0.03, 25):           # (the nose tip: the face's frontmost point near there)
        hit = bvh.ray_cast((x, 1.0, z + dz), (0.0, -1.0, 0.0))
        if hit[0] is not None and (best is None or hit[0].y > best[1]):
            best = np.array(hit[0][:])
    c = best + np.array([0.0, -float(sp.get("back", 0.006)), -float(sp.get("below", 0.011))])
    bld = WP.Builder()
    bld.torus(c, [1.0, 0.0, 0.0], float(sp.get("r", 0.0075)), float(sp.get("wire", 0.0016)), 20, 6, (0, 0, 1, 1),
              "copper", 0.0)
    ob = bld.object("NoseRing")
    img = _atlas("ring_atlas", ["d08c55"])
    _material(ob, "metal-ring", img)
    _uv_flat(ob, bld, {"copper": 0})
    g = ob.vertex_groups.new(name="head")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("nose ring at %s (tip %s)" % (tuple(round(float(v), 3) for v in c), tuple(round(float(v), 3) for v in best)))
    return ob


def gum(body, arm, rig, K, sp):
    """The pink gum bubble at her mouth (RYZZ_KIT "pink gum bubble"; her idle fidget in the art), rigid on the head:
    a sphere just off her lips, a little to her left."""
    bvh = WP.body_bvh([body])
    nr = sp.get("nose", [0.012, 1.62])
    best = None
    for dz in np.linspace(-0.03, 0.03, 25):
        hit = bvh.ray_cast((nr[0], 1.0, nr[1] + dz), (0.0, -1.0, 0.0))
        if hit[0] is not None and (best is None or hit[0].y > best[1]):
            best = np.array(hit[0][:])
    r = float(sp.get("r", 0.026))
    mz = best[2] - float(sp.get("below", 0.023)) - 0.011
    hit = bvh.ray_cast((best[0] + float(sp.get("side", -0.012)), 1.0, mz), (0.0, -1.0, 0.0))
    lip = np.array(hit[0][:]) if hit[0] is not None else best
    c = lip + np.array([0.0, r * 0.8, 0.0])
    bld = WP.Builder()
    n = 12
    rings = [c + np.array([0.0, 0.0, -r * math.cos(math.pi * i / n)]) for i in range(n + 1)]
    radii = [max(r * math.sin(math.pi * i / n), 1e-4) for i in range(n + 1)]
    bld.tube(rings, radii, 16, 0, 1, 0, 1, "gum", [0.0] * (n + 1), cap_start=True, cap_end=True)
    ob = bld.object("Gum")
    # (glossy: darker at the bottom, a pale highlight toward the top)
    img = _atlas("gum_atlas", ["ff8ac6"], [[(0.0, "e0549e"), (0.55, "ff86c4"), (0.82, "ffbadf"), (1.0, "fff0f8")]])
    _material(ob, "cloth-gum", img)
    _uv_flat(ob, bld, {}, {"gum": 0})
    g = ob.vertex_groups.new(name="head")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("gum bubble at %s, r %.3f" % (tuple(round(float(v), 3) for v in c), r))
    return ob


def bands(body, arm, rig, K, sp):
    """The hazard bands as their own short striped sleeves round the scan's (wrists and boot tops): diagonal
    yellow-and-black stripes the match camera can read, each rigid on its bone a fraction `t` down it."""
    co = np.array([v.co[:] for v in body.data.vertices])
    img = bpy.data.images.new("bands_atlas", ATLAS, ATLAS, alpha=False)
    px = np.ones((ATLAS, ATLAS, 4), np.float32)
    yy, xx = np.mgrid[0:ATLAS, 0:ATLAS]
    n = int(sp.get("stripes", 10))
    st = ((xx / ATLAS * n + yy / ATLAS * float(sp.get("slant", 1.2))) % 1.0) < float(sp.get("yellow_k", 0.45))
    px[..., :3] = np.where(st[..., None], WP.hexcol(sp.get("yellow", "ffd21e"))[None, None],
                           WP.hexcol(sp.get("black", "151214"))[None, None])
    img.pixels = px.ravel()
    img.pack()
    bld = WP.Builder()
    groups = []
    for b in sp["at"]:
        a = np.array(K.bone_head(rig, b["bone"])[:])
        e = np.array(K.bone_head(rig, b["to"])[:])
        ax = (e - a) / np.linalg.norm(e - a)
        c = a + (e - a) * float(b["t"])
        h = float(b.get("h", sp.get("h", 0.04)))
        rel = co - c
        along = rel @ ax
        radial = np.linalg.norm(rel - np.outer(along, ax), axis=1)
        sel = (np.abs(along) < h * 0.6) & (radial < float(b.get("max_r", 0.12)))
        r = (float(np.percentile(radial[sel], 96)) if sel.sum() > 10 else 0.05) + float(sp.get("gap", 0.004))
        v0 = len(bld.v)
        rings = [c - ax * h * 0.5, c - ax * h * 0.45, c + ax * h * 0.45, c + ax * h * 0.5]
        bld.tube(rings, [r * 0.97, r, r, r * 0.97], 28, 0.0, 1.0, 0.0, 1.0, "band", [0.0] * 4)
        groups.append((b.get("rigid", b["bone"]), v0, len(bld.v)))
        log("band on %s: r %.3f at %s" % (b["bone"], r, tuple(round(float(x), 3) for x in c)))
    ob = bld.object("Bands")
    _material(ob, "metal-bands", img)
    for bone, v0, v1 in groups:
        g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
        g.add(list(range(v0, v1)), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    return ob


def keyhole(body, arm, rig, K, sp):
    """The corset's neon piping as thin glowing geometry (crisper than the atlas at every distance): the art's neon
    pixels in `box` (Meshy frame, the front view's registration as emit_art) sampled on a `cell` grid, each cell a
    small flat disc on the body's surface just off it, on the glow slot (the archetype's model_glow colour), rigid
    on the hips."""
    sys_path = os.path.dirname(os.path.abspath(__file__))
    if sys_path not in sys.path:
        sys.path.insert(0, sys_path)
    import imgio
    art = imgio.load(os.path.expanduser(sp["image"]))
    ah, aw = art.shape[:2]
    M = Matrix([body["meshy_to_fit"][i * 4:(i + 1) * 4] for i in range(4)])
    k_px, c0, r0 = float(sp["px_per_m"]), float(sp["col_at"]), float(sp["row_at"])
    x0, x1, z0, z1 = sp["box"]
    cell = float(sp.get("cell", 0.005))
    rgb = art
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    d = np.maximum(mx - mn, 1e-6)
    r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hh = np.where(mx == r_, ((g_ - b_) / d) % 6.0, np.where(mx == g_, (b_ - r_) / d + 2.0, (r_ - g_) / d + 4.0)) / 6.0
    ss = (mx - mn) / np.maximum(mx, 1e-4)
    neon = np.zeros(mx.shape, bool)
    for q in sp["hsv"]:
        neon |= (hh >= q[0]) & (hh <= q[1]) & (ss >= q[2]) & (ss <= q[3]) & (mx >= q[4]) & (mx <= q[5])
    bvh = WP.body_bvh([body])
    bld = WP.Builder()
    n = 0
    r = float(sp.get("r", 0.0035))
    if sp.get("path_px"):
        # (the outline traced on the front view as one polyline, [col, row] px: one clean neon tube along the
        # sweetheart edge and down the bolt, where sampling the art's neon pixels by cell gave scattered specks)
        q = np.array([[(c - c0) / k_px, (r0 - rw) / k_px] for c, rw in sp["path_px"]], float)
        s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(q, axis=0), axis=1))])
        ts = np.linspace(0.0, s[-1], max(2, int(s[-1] / float(sp.get("step", 0.003)))))
        q = np.stack([np.interp(ts, s, q[:, 0]), np.interp(ts, s, q[:, 1])], axis=1)
        pts = []
        # (`offset` [dx, dz] m in the fitted frame: the body's pose fit moves the torso off the plain transform)
        ox, oz = sp.get("offset", [0.0, 0.0])
        for x, z in q:
            p = M @ Vector((float(x), 0.0, float(z)))
            hit = bvh.ray_cast((p.x + ox, 1.0, p.z + oz), (0.0, -1.0, 0.0))
            if hit[0] is not None:
                pts.append(np.array(hit[0][:]) + np.array(hit[1][:]) * float(sp.get("lift", 0.0015)))
        pts = np.array(pts)
        for _it in range(2):
            pts[1:-1] = pts[1:-1] * 0.5 + (pts[:-2] + pts[2:]) * 0.25
        bld.tube(pts, [r] * len(pts), int(sp.get("sides", 6)), 0, 1, 0, 1, "neon", [0.0] * len(pts),
                 cap_start=True, cap_end=True)
        n = len(pts)
        x1 = x0           # (no cells)
    for x in np.arange(x0, x1, cell):
        for z in np.arange(z0, z1, cell):
            ca, cb = int(c0 + x * k_px), int(c0 + (x + cell) * k_px)
            ra, rb = int(r0 - (z + cell) * k_px), int(r0 - z * k_px)
            win = neon[max(ra, 0):min(rb + 1, ah), max(ca, 0):min(cb + 1, aw)]
            if win.size == 0 or win.mean() < float(sp.get("fill", 0.25)):
                continue
            p = M @ Vector((x + cell * 0.5, 0.0, z + cell * 0.5))      # (the front view: her front is +Y fitted)
            hit = bvh.ray_cast((p.x, 1.0, p.z), (0.0, -1.0, 0.0))
            if hit[0] is None:
                continue
            nrm = np.array(hit[1][:])
            c = np.array(hit[0][:]) + nrm * float(sp.get("lift", 0.0015))
            WP._disc(bld, c, nrm, r, "neon", (0, 0, 1, 1), sides=6, dome=0.1)
            n += 1
    ob = bld.object("Keyhole")
    img = _atlas("keyhole_atlas", [sp.get("colour", "ff4fb4")])
    _material(ob, "glow-keyhole", img)
    _uv_flat(ob, bld, {"neon": 0})
    g = ob.vertex_groups.new(name="hips")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    log("keyhole piping: %d discs, %d tris" % (n, sum(len(f) - 2 for f in bld.f)))
    return ob


def build(body, arm, rig, K, spec):
    """fit_warden's `scripted` hook: every piece in spec, as skinned meshes."""
    out = []
    if spec.get("pigtails"):
        out.append(pigtails(body, arm, rig, K, spec["pigtails"]))
    if spec.get("rods"):
        out.append(rods(body, arm, rig, K, spec["rods"]))
    if spec.get("bands"):
        out.append(bands(body, arm, rig, K, spec["bands"]))
    if spec.get("keyhole"):
        out.append(keyhole(body, arm, rig, K, spec["keyhole"]))
    if spec.get("gum"):
        out.append(gum(body, arm, rig, K, spec["gum"]))
    if spec.get("nose_ring"):
        out.append(nose_ring(body, arm, rig, K, spec["nose_ring"]))
    return out

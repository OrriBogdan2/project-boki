"""Pip's atlas (ART-1): every texel is painted from its rest-pose position, normal and piece, so seams never show and the colour stays broad
for the match camera. albedo + emission (the gold constellations, the tail tip and the flower's light; the emission's strength is the look's
`emit`, and PipStars brightens it while she heals)."""
import numpy as np

import hem_sdf as S
from meshkit import smooth
import pip_sculpt as K

F = np.float32


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], F)


PINK, PINK_HI, ROSE, PLUM = rgb("df949c"), rgb("efb4ae"), rgb("cf8390"), rgb("9e5f74")
CREAM, CREAM_T = rgb("f7dabf"), rgb("fff0cc")
INNER = rgb("f6c3c6")
GOLD = rgb("ffd98a")
APRON, APRON_DK = rgb("efe2cc"), rgb("c8ab7c")
LEAF, LEAF_DK, LEAF_HI = rgb("6a9140"), rgb("3f6a35"), rgb("a8bf62")
PET_C, PET_E = rgb("d0768f"), rgb("f0b0b4")
BRASS, BRASS_HI, BRASS_DK = rgb("b0833f"), rgb("e4c078"), rgb("654120")
LEATHER, LEATHER_DK, LEATHER_HI = rgb("8c5a2c"), rgb("53321a"), rgb("b98a4c")
INK = rgb("3a1f35")


def mix(a, b, t):
    t = np.asarray(t, F)
    return a * (1 - t[..., None]) + b * t[..., None]


def strokes(p, n):
    """A soft fur grain: broad, low contrast, so the match camera sees clean colour."""
    return S.fbm(p[:, 0] * 1.1, p[:, 1] * 1.1, p[:, 2] * 0.45, f=28.0, oct=3)


def fur(p, n, ao, base=None):
    c = np.broadcast_to(PINK, p.shape).astype(F) if base is None else base
    c = mix(c, PINK_HI, 0.45 * smooth(0.25, 0.95, n[:, 2]))
    g = strokes(p, n)
    c = c * (0.93 + 0.14 * g)[:, None]
    return c


def limb_ramp(c, k):
    return mix(c, PLUM, k)


# ---- constellations: (part prefixes, view, [(a, b)...]): drawn in a projection onto that side
# view F: seen from the front, a = x, b = z. B the back. R: from her right, a = y, b = z. L from her left. T: from above, a = x, b = y.
_S = K.SH
CONST = [
    (("body",), "F", [(0.135, 0.34), (0.118, 0.26), (0.095, 0.20), (0.135, 0.13)]),
    (("body",), "F", [(-0.14, 0.33), (-0.10, 0.27), (-0.125, 0.19), (-0.09, 0.12)]),
    (("body",), "R", [(0.03, 0.33), (-0.03, 0.24), (0.02, 0.16)]),
    (("body",), "L", [(-0.04, 0.31), (0.03, 0.22), (-0.01, 0.14)]),
    (("body",), "B", [(0.07, 0.72), (0.12, 0.60), (0.03, 0.52), (0.09, 0.42)]),
    (("body",), "B", [(-0.06, 0.70), (-0.13, 0.62), (-0.08, 0.50)]),
    (("armR",), "F", [(_S + 0.02, 0.98), (_S - 0.012, 0.89), (_S + 0.018, 0.80), (_S - 0.014, 0.72)]),
    (("armL",), "F", [(-_S - 0.022, 0.97), (-_S + 0.01, 0.88), (-_S - 0.014, 0.78), (-_S + 0.016, 0.70)]),
    (("armR",), "B", [(_S - 0.02, 0.95), (_S + 0.018, 0.84), (_S - 0.01, 0.74)]),
    (("armL",), "B", [(-_S + 0.016, 0.92), (-_S - 0.02, 0.82), (-_S + 0.01, 0.73)]),
            ]
VIEW = {"F": (0, 2, 1, 1), "B": (0, 2, 1, -1), "R": (1, 2, 0, 1), "L": (1, 2, 0, -1), "T": (0, 1, 2, 1)}


def constellation(p, n, names, name_of):
    """-> lines, stars (0..1 per texel)."""
    line, star = np.zeros(len(p), F), np.zeros(len(p), F)
    for parts, view, pts in CONST:
        pick = np.array([name_of[i].startswith(parts) for i in range(len(name_of))])
        m = pick[names]
        a, b, axis, sgn = VIEW[view]
        m = m & (n[:, axis] * sgn > 0.12)
        if not m.any():
            continue
        q = p[m][:, [a, b]]
        P = np.array(pts, F)
        d = np.full(len(q), 9.0, F)
        for i in range(len(P) - 1):
            ab = P[i + 1] - P[i]
            t = np.clip(((q - P[i]) @ ab) / (ab @ ab), 0, 1)
            d = np.minimum(d, np.linalg.norm(q - (P[i] + np.outer(t, ab)), axis=1))
        line[m] = np.maximum(line[m], smooth(0.0042, 0.0018, d))
        s_ = np.zeros(len(q), F)
        for i, pt in enumerate(P):
            r = 0.0145 if i % 2 == 0 else 0.0105
            da, db = np.abs(q - pt).T
            s_ = np.maximum(s_, smooth(1.0, 0.55, (da / r) ** 0.62 + (db / r) ** 0.62))
        star[m] = np.maximum(star[m], s_)
    return line, star


def tail_stars(p, n, path):
    """Two gold lines along the top of the tail, from its own path (the fitted tail, swung up)."""
    pts = path.astype(F)
    cs = [(0.22, 0.03), (0.34, -0.04), (0.46, 0.04), (0.58, -0.03), (0.34, 0.09), (0.5, 0.12)]
    side = np.array((1.0, 0.0, 0.0), F)
    P_ = [pts[int(t * (len(pts) - 1))] + side * o * 2.4 for t, o in cs]
    q = p[:, :2]
    m = n[:, 2] > 0.15
    line, star = np.zeros(len(p), F), np.zeros(len(p), F)
    qm = q[m]
    Q = np.array(P_, F)[:, :2]
    d = np.full(len(qm), 9.0, F)
    for a, b in ((0, 1), (1, 2), (2, 3), (1, 4), (4, 5)):
        ab = Q[b] - Q[a]
        t = np.clip(((qm - Q[a]) @ ab) / (ab @ ab), 0, 1)
        d = np.minimum(d, np.linalg.norm(qm - (Q[a] + np.outer(t, ab)), axis=1))
    line[m] = smooth(0.0042, 0.0018, d)
    s_ = np.zeros(len(qm), F)
    for pt in Q:
        da, db = np.abs(qm - pt).T
        s_ = np.maximum(s_, smooth(1.0, 0.55, (da / 0.0145) ** 0.62 + (db / 0.0145) ** 0.62))
    star[m] = s_
    m2 = p[:, 1] < -0.2
    return line * m2, star * m2


def stack(col, em, line, star):
    k = np.clip(np.maximum(line * 0.5, star), 0, 1)
    col = mix(col, GOLD, k)
    em = np.maximum(em, (GOLD * 0.95)[None, :] * np.maximum(line * 0.38, star)[:, None])
    return col, em


def body(p, n, ao):
    c = fur(p, n, ao)
    x, y, z = p.T
    knee = K.J["shin.R"][2]
    c = limb_ramp(c, smooth(knee + 0.03, knee - 0.10, z) * 0.82)
    # pale toes
    toe = smooth(0.1, 0.19, y) * smooth(0.09, 0.04, z)
    c = mix(c, ROSE, 0.2 * toe)
    # toe lines
    for sx in (1, -1):
        for t in (-0.5, 0.5):
            c = mix(c, INK, 0.55 * smooth(0.0045, 0.0015, np.abs(x - sx * (0.126 + t * 0.052))) * smooth(0.14, 0.17, y) * smooth(0.075, 0.05, z))
    return c


def arm(p, n, ao):
    c = fur(p, n, ao)
    el = K.J["forearm.R"][2]
    c = limb_ramp(c, smooth(el - 0.02, el - 0.17, p[:, 2]) * 0.86)
    return c


def head(p, n, ao, mouth_d):
    q = p - K.HC
    x, y, z = q.T
    ax = np.abs(x)
    c = fur(p, n, ao)
    zb = np.interp(ax, (0.0, 0.03, 0.095, 0.16, 0.22, 0.30), (-0.078, -0.072, -0.040, -0.058, -0.112, -0.17))
    cream = smooth(0.012, -0.012, z - zb) * smooth(-0.04, 0.03, y)
    c = mix(c, CREAM, cream)
    # rosy cheeks, a darker bridge, the ears' root
    c = mix(c, ROSE, 0.5 * smooth(0.075, 0.02, np.hypot(x * 0.7, z - 0.13)) * 0 + 0.28 * smooth(0.2, 0.09, ax) * smooth(-0.02, 0.06, z) * smooth(0.14, 0.05, z) * (y > 0.03))
    # eye rims
    for s in (1.0, -1.0):
        e = K.EYE * (s, 1, 1)
        rr = np.hypot((x - e[0]) / K.EYE_R, (z - e[2]) / K.EYE_R)
        front = smooth(0.02, 0.06, y)
        # the small pale pad under the eye
    # mouth
    c = mix(c, INK, smooth(0.0052, 0.0022, mouth_d))
    c = mix(c, rgb("5c2438"), smooth(-0.002, -0.009, mouth_d - 0.0) * 0)
    # the philtrum, from the nose down
    c = mix(c, INK, 0.75 * smooth(0.0032, 0.0014, ax) * (z < -0.068) * (z > -0.1) * (y > 0.17))
    return c


def eyeball_art(path, n):
    """The sheet's eye as the ball's tile: pip_head.png front view, her right eye."""
    im = head_views(path)[0]
    cx, cy, r = 271.0, 745.0, 50.0        # the eye's centre and half size, pixels
    v, u = np.mgrid[0:n, 0:n]
    x = (u + 0.5) / n * 2 - 1
    y = (v + 0.5) / n * 2 - 1
    # (tile radius sin(b): 0.66 at the eye's rim on a 52 mm ball)
    px = cx + x.ravel() / 0.66 * r
    py = cy - y.ravel() / 0.66 * r
    return sample2(im, px.astype(F), py.astype(F)).reshape(n, n, 3)


def eyeball_tile(n=256):
    v, u = np.mgrid[0:n, 0:n]
    x = (u + 0.5) / n * 2 - 1
    y = (v + 0.5) / n * 2 - 1
    r = np.hypot(x, y)
    c = np.ones((n, n, 3), F) * rgb("f3e2cd")
    iris = smooth(0.78, 0.73, r)
    t = np.clip((y + 0.72) / 1.44, 0, 1)        # (image v runs up in Blender)
    col = mix(mix(np.broadcast_to(rgb("6e3010"), (n, n, 3)).astype(F), rgb("a8642a"), smooth(0.66, 0.34, r)), rgb("d99a45"), smooth(0.2, -0.6, y) * 0.9)
    c = mix(c, col, iris)
    a = np.arctan2(y, x)
    c = mix(c, rgb("4a2412"), smooth(0.66, 0.72, r) * smooth(0.82, 0.74, r))
    c = mix(c, rgb("1c0d0e"), smooth(0.40, 0.36, np.hypot(x * 0.98, y * 0.9)))
    c = mix(c, np.ones(3, F), smooth(0.15, 0.12, np.hypot(x + 0.2, y - 0.24)))
    c = mix(c, np.ones(3, F), 0.75 * smooth(0.06, 0.045, np.hypot(x - 0.16, y + 0.16)))
    return np.clip(c, 0, 1)


def ear_paint(p, n, ao, pc, name):
    q = p - pc.c0
    t = (q @ pc.ax) / pc.L
    sx = (q @ pc.sd)
    fr = q @ pc.fr
    c = fur(p, n, ao)
    wide = 0.098 * np.maximum(1 - t, 0.0) ** 0.62
    inside = smooth(0.0, 0.25, n @ pc.fr.astype(F)) * smooth(0.98, 0.72, np.abs(sx) / np.maximum(wide, 0.004))
    c = mix(c, INNER, inside)
    c = mix(c, ROSE, inside * 0.45 * smooth(0.45, 0.0, t) * smooth(0.5, 0.0, np.abs(sx) / np.maximum(wide, 0.004)))
    # tuft strokes, the dark tip
    c = mix(c, PLUM, smooth(0.70, 0.86, t) * 0.7)
    return c


def bandage(p, n, ao, pc):
    q = p - pc.c0
    t = (q @ pc.ax) / pc.L
    sx = q @ pc.sd
    c = np.broadcast_to(rgb("efdcc0"), p.shape).astype(F).copy()
    w = np.mod(t * 7.5 + sx * 7.0, 1.0)
    c = mix(c, rgb("b89b78"), smooth(0.14, 0.03, w) * 0.85)
    c = mix(c, rgb("fff4de"), smooth(0.3, 0.55, w) * smooth(0.8, 0.55, w) * 0.5)
    return c


def leaf_paint(p, n, ao, pc, kind):
    q = p - pc.vein_o
    u = (q @ pc.vein_a.astype(F)) / pc.vein_L
    s = (q @ pc.vein_s.astype(F)) / (pc.vein_W * 0.5)
    a = np.abs(s)
    if kind == "green":
        c = mix(np.broadcast_to(LEAF, p.shape).astype(F), LEAF_HI, smooth(0.45, 1.0, u) * 0.55)
        c = mix(c, LEAF_DK, smooth(0.45, 1.0, a) * 0.38)
        # veins
        c = mix(c, LEAF_HI, 0.85 * smooth(0.05, 0.015, a))
        side = np.abs(np.mod(u * 5.5 - a * 1.4, 1.0) - 0.5)
        c = mix(c, LEAF_DK, 0.6 * smooth(0.075, 0.03, side) * smooth(0.04, 0.08, a) * smooth(0.97, 0.75, a))
    else:
        c = mix(np.broadcast_to(PET_C, p.shape).astype(F), PET_E, smooth(0.1, 0.92, a) * 0.8 + 0.2 * smooth(0.3, 1.0, u))
        c = mix(c, rgb("8fb24f"), smooth(0.2, 0.0, u) * 0.75)
        c = mix(c, PET_C, 0.5 * smooth(0.035, 0.012, a) * smooth(0.95, 0.5, u))
    # the underside is duller
    return c


def flower_paint(p, n, ao, pc, big):
    r = np.linalg.norm(p - pc.flower_c, axis=1) / (0.105 if big else 0.052)
    c = mix(np.broadcast_to(rgb("ffe9c0"), p.shape).astype(F), rgb("ffd7cf"), smooth(0.15, 0.7, r))
    c = mix(c, rgb("f6a7b8"), smooth(0.6, 1.0, r) * 0.7)
    e = rgb("ffdf9a")[None, :] * (smooth(0.75, 0.1, r) * (1.0 if big else 0.8))[:, None]
    return c, e


def apron(p, n, ao):
    x, y, z = p.T
    c = mix(np.broadcast_to(APRON, p.shape).astype(F), rgb("fbf1e0"), 0.5 * S.fbm(x, z, y, f=9.0, oct=3))
    front = n[:, 1] > -0.2
    # stitching: dashes above the hem and down the sides
    half = 0.10 + 0.112 * smooth(0.0, 0.62, (K.APRON_TOP - z) / (K.APRON_TOP - K.APRON_HEM)) + 0.012
    dash = (np.mod(x * 42.0, 1.0) < 0.6) & (np.abs(z - (K.APRON_HEM + 0.052)) < 0.0035) & (np.abs(x) < half - 0.03)
    c[dash & front] = APRON_DK
    # the sewn patch, her right
    px, pz = x - 0.092, z - 0.635
    a = 0.14
    u, v = px * np.cos(a) - pz * np.sin(a), px * np.sin(a) + pz * np.cos(a)
    pat = (np.maximum(np.abs(u), np.abs(v)) < 0.078) & front
    c[pat] = mix(np.broadcast_to(rgb("e3a0a6"), p.shape).astype(F), rgb("cf8590"), S.fbm(x, z, y, f=30.0, oct=2))[pat]
    edge = pat & (np.maximum(np.abs(u), np.abs(v)) > 0.072)
    c[edge] = rgb("a55f6e")
    st = ((np.abs(np.maximum(np.abs(u), np.abs(v)) - 0.082) < 0.0085) & (np.mod((u + v) * 34.0, 1.0) < 0.36)) & front
    c[st] = APRON_DK * 0.8
    # the flower-cross: two crossed pink plasters and a cream flower heart
    fx, fz = x + 0.075, z - 0.50
    for ang in (0.72, -0.72):
        u, v = fx * np.cos(ang) - fz * np.sin(ang), fx * np.sin(ang) + fz * np.cos(ang)
        b = (np.abs(u) < 0.062) & (np.abs(v) < 0.022) & front
        c[b] = rgb("ef97ae")
        hole = (np.mod(u * 42.0, 1.0) < 0.3) & (np.abs(v) < 0.012) & (np.abs(u) > 0.03) & b
        c[hole] = rgb("d9708f")
    r = np.hypot(fx, fz)
    th = np.arctan2(fz, fx)
    c[(r < 0.024 + 0.008 * np.cos(th * 5.0)) & front] = rgb("fff0d8")
    c[(r < 0.0085) & front] = rgb("ffc95e")
    return c


def pouch(p, n, ao):
    q = p - K.POUCH
    x, z = q[:, 0], q[:, 2]
    # basket weave: over and under
    cx, cz = np.floor(x * 30.0), np.floor(z * 30.0)
    chk = np.mod(cx + cz, 2.0)
    fx, fz = np.mod(x * 30.0, 1.0) - 0.5, np.mod(z * 30.0, 1.0) - 0.5
    bump = np.where(chk > 0.5, 1 - (fx * 2) ** 2, 1 - (fz * 2) ** 2)
    c = mix(np.broadcast_to(LEATHER_DK, p.shape).astype(F), rgb("b4823f"), np.clip(bump, 0, 1) * 0.92)
    return c


def flap(p, n, ao):
    q = p - K.POUCH
    c = pouch(p, n, ao)
    r = np.abs(q[:, 0]) / 0.125
    return mix(c, LEATHER_DK, smooth(0.9, 1.0, r) * 0.7)


def leather(p, n, ao):
    c = mix(np.broadcast_to(LEATHER, p.shape).astype(F), LEATHER_HI, smooth(0.2, 0.9, n[:, 2]) * 0.5)
    return c


def brass(p, n, ao):
    g = S.fbm(p[:, 0], p[:, 1], p[:, 2], f=14.0, oct=3)
    c = mix(np.broadcast_to(BRASS, p.shape).astype(F), BRASS_DK, smooth(0.62, 0.36, g) * 0.42)
    return mix(c, BRASS_HI, smooth(0.35, 0.95, n[:, 2]) * 0.6)


def roof(p, n, ao):
    """Scrolled brass: dark swirls cut into the roof's four faces."""
    c = brass(p, n, ao)
    q = p - (K.GRIP[0], K.GRIP[1], K.LZ["eave"])
    a = np.arctan2(q[:, 1], q[:, 0]) * 4.0
    r = np.hypot(q[:, 0], q[:, 1])
    sw = np.sin(r * 90.0 + np.sin(a) * 2.6)
    return mix(c, BRASS_DK, smooth(0.45, 0.8, sw) * smooth(0.03, 0.05, r) * 0.75)


def pane(p, pc):
    q = p - pc.pane_c.astype(F)
    u, v = q @ pc.pane_t.astype(F) / pc.pane_w, q[:, 2] / pc.pane_h
    a = np.arctan2(v, u) + np.pi / 2
    r = np.hypot(u, v)
    sa = np.mod(a * 5 / (2 * np.pi), 1.0) - 0.5
    star = r < (0.26 + 0.34 * (1 - 2 * np.abs(sa)) ** 1.6) * 0.92
    c = mix(np.broadcast_to(rgb("e88a24"), p.shape).astype(F), rgb("ffc45c"), smooth(1.1, 0.3, r))
    c[star] = rgb("fff2c0")
    return c


def lens(p, n, ao):
    r = p - p.mean(0)
    c = mix(np.broadcast_to(rgb("6c7350"), p.shape).astype(F), rgb("a9ad7c"), smooth(-0.05, 0.05, r[:, 0] * 0.6 - r[:, 1] + r[:, 2]))
    arc = smooth(0.006, 0.0, np.abs(np.hypot(r[:, 0] + 0.012, r[:, 2] - 0.012) - 0.034))
    return mix(c, rgb("eef0cf"), arc * 0.8)


# ---------------------------------------------------------------- the wing cards, an RGBA atlas
def wing_atlas(w=1024, h=1024):
    """Upper half: the big wing, u root -> tip along x; lower half: the small one. Membrane pale peach-pink, veins and edge gold."""
    out = np.zeros((h, w, 4), F)
    for row0, row1, big in ((h // 2, h, True), (0, h // 2, False)):
        hh = row1 - row0
        v_, u_ = np.mgrid[0:hh, 0:w]
        u = (u_ + 0.5) / w
        v = (v_ + 0.5) / hh * 2 - 1           # -1 .. 1 across
        # the outline: a long teardrop, widest past the middle, the leading edge straighter
        if big:
            top = 0.92 * np.sin(np.pi * u ** 1.35) ** 0.72
            bot = 0.70 * np.sin(np.pi * u ** 1.15) ** 0.85
        else:
            top = 0.85 * np.sin(np.pi * u ** 1.2) ** 0.8
            bot = 0.85 * np.sin(np.pi * u ** 0.95) ** 0.8
        sd = np.where(v > 0, v / np.maximum(top, 1e-3), -v / np.maximum(bot, 1e-3))
        inside = smooth(1.0, 0.965, sd) * smooth(0.0, 0.015, u) * smooth(1.0, 0.985, u)
        c = mix(np.broadcast_to(rgb("ffc4d0"), (hh, w, 3)).astype(F), rgb("ffe6c8"), smooth(0.1, 0.9, u))
        a = 0.40 + 0.12 * (1 - u)
        # veins fan from the root, forking
        vein = np.zeros((hh, w), F)
        ang = np.arctan2(v * (0.42 if big else 0.5), u + 0.02)
        for i, k in enumerate(np.linspace(-0.95, 0.95, 7)):
            cen = k * 0.62 + 0.10 * np.sin(u * 5.0 + i)
            vein = np.maximum(vein, smooth(0.015, 0.004, np.abs(ang - cen * (0.45 + 0.75 * u) * 0.8)) * smooth(0.02, 0.12, u))
            if i % 2 == 0:
                vein = np.maximum(vein, smooth(0.012, 0.003, np.abs(ang - (cen + 0.14 * (u - 0.45)) * (0.45 + 0.75 * u) * 0.8)) * smooth(0.42, 0.5, u))
        rim = smooth(0.90, 0.985, sd) * inside
        gold = np.maximum(vein, rim)
        c = mix(c, rgb("ffcc66"), gold)
        a = a + (0.98 - a) * gold
        # stars in the membrane
        for (su, sv, r) in ((0.42, 0.32, 0.016), (0.62, -0.18, 0.012), (0.75, 0.3, 0.014), (0.3, -0.2, 0.01), (0.86, 0.05, 0.012), (0.54, 0.55, 0.011)):
            q = (np.abs(u - su) / r) ** 0.62 + (np.abs(v - sv) * 0.5 / r) ** 0.62
            st = smooth(1.0, 0.6, q)
            c = mix(c, rgb("fff6c8"), st)
            a = a + (1.0 - a) * st
        out[row0:row1, :, :3] = c
        out[row0:row1, :, 3] = a * inside
    return out


# ---------------------------------------------------------------- the head's own texture: pip_head.png's views, projected
HEAD_K = 0.000807            # m a pixel of pip_head.png
FRONT_C = 396.0              # the front view's x = 0, pixels
SIDE_NOSE = 1424.0           # the side view's nose tip
BACK_C = 2349.0
NOSE_ROW = 842.0             # the row of the nose, all views
_views = {}


def blur(a, n=2):
    for _ in range(n):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5
    return a


def sample2(img, x, y):
    h, w = img.shape[:2]
    x = np.clip(x, 0, w - 1.001)
    y = np.clip(y, 0, h - 1.001)
    i, j = x.astype(int), y.astype(int)
    fx, fy = (x - i).astype(F), (y - j).astype(F)
    if img.ndim == 3:
        fx, fy = fx[:, None], fy[:, None]
    return (img[j, i] * (1 - fx) + img[j, i + 1] * fx) * (1 - fy) + (img[j + 1, i] * (1 - fx) + img[j + 1, i + 1] * fx) * fy


def head_views(path):
    if path in _views:
        return _views[path]
    import imgio
    im = imgio.load(path)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    sat = im.max(2) - im.min(2)
    gold = smooth(0.12, 0.3, np.minimum(r, g) - b) * smooth(0.75, 0.92, r)
    # her fur, cream and marks; not the bronze, leather, iris or the grey behind
    fur = smooth(0.5, 0.6, b / np.maximum(r, 0.01)) * smooth(0.05, 0.12, sat) * smooth(0.25, 0.38, r)
    keep = blur(np.maximum(fur, gold), 2)
    _views[path] = (im, blur((keep > 0.7).astype(F), 4), gold)
    return _views[path]


def head_project(p, n, base, ref, mirror=False):
    """Front, side and back views by the normal over `base`; -> colour, emission. mirror: both sides read her right side of the front view."""
    im, keep, gold = ref
    q = p - K.HC.astype(F)
    z_px = NOSE_ROW - (q[:, 2] - K.NOSE[2]) / HEAD_K
    xf = FRONT_C - (np.abs(q[:, 0]) if mirror else q[:, 0]) / HEAD_K
    xb = BACK_C + (-np.abs(q[:, 0]) if mirror else q[:, 0]) / HEAD_K
    xs = SIDE_NOSE + (K.NOSE[1] + 0.02 - q[:, 1]) / HEAD_K
    wf = smooth(0.05, 0.5, n[:, 1])
    # (the face reads off the front view alone, or the eyes ghost)
    wf = wf * (1.0 + 8.0 * smooth(0.16, 0.08, np.hypot(np.abs(q[:, 0]) - 0.09, q[:, 2] - 0.02)))
    wb = smooth(0.05, 0.5, -n[:, 1])
    ws = smooth(0.25, 0.7, np.abs(n[:, 0])) * (0.0 if mirror else 1.0)
    tot = np.maximum(wf + wb + ws, 1e-4)
    c = np.zeros_like(base)
    k = np.zeros(len(p), F)
    g = np.zeros(len(p), F)
    for x, w in ((xf, wf), (xb, wb), (xs, ws)):
        kk = sample2(keep, x, z_px)
        ww = (w * w) / np.maximum(wf * wf + wb * wb + ws * ws, 1e-4)
        c += sample2(im, x, z_px) * (ww * kk)[:, None]
        k += ww * kk
        g += ww * sample2(gold, x, z_px)
    c = c + base * (1 - np.clip(k, 0, 1))[:, None]
    return np.clip(c, 0, 1), GOLD[None, :] * g[:, None]


# ---------------------------------------------------------------- the apron: the turnaround's painted cloth, projected from the front
APRON_K = 0.0016            # m a pixel of pip_turnaround.png
APRON_C = (464.0, 1060.0)    # its pixel at x = 0 on the hem


def apron_ref(path):
    import imgio
    im = imgio.load(path)
    return im


def apron_project(p, n, base, im):
    x = APRON_C[0] - p[:, 0] / APRON_K
    y = APRON_C[1] - (p[:, 2] - K.APRON_HEM) / APRON_K
    a = sample2(im, x, y)
    # cloth, patch and cross, not the strap, the pouch or the grey behind her
    sat = a.max(1) - a.min(1)
    brown = smooth(0.62, 0.5, a[:, 2] / np.maximum(a[:, 0], 0.01)) * smooth(0.75, 0.55, a[:, 1] / np.maximum(a[:, 0], 0.01))
    grey = smooth(0.06, 0.02, sat)
    w = (1 - brown) * (1 - grey) * smooth(-0.3, 0.1, n[:, 1])
    return mix(base, a, w)


RELIEF = 2.4                 # the relief map's slope per unit of painted height


def relief_map(col, mask):
    """A normal map from the paint, atlas space: weave, stitches, veins stand up, dark seams sink."""
    lum = col @ np.array((0.3, 0.55, 0.15), F)
    hgt = blur(lum * mask, 1)
    du = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * RELIEF
    dv = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * RELIEF
    nm = np.stack((-du, -dv, np.ones(du.shape, F)), 2)
    return nm / np.linalg.norm(nm, axis=2, keepdims=True)

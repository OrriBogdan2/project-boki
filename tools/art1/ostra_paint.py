"""Ostra's textures, painted with numpy from the same functions that shaped him (ART-1): the mask's light, cracks and teeth come
from the sculpt's own height field; the cloth from fold fields. All colours sRGB 0..1; images run top to bottom, t down."""
import numpy as np
import ostra_mask as M


def hx(s):
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


BLACK, PLUM, DUSK, VIOLET, VIOLET_HI, TRIM, HOT = map(hx, ("150f1c", "261b30", "3d2650", "62308a", "8a46bc", "bb66f2", "e0aaff"))
RUFF_D, RUFF_M, RUFF_L = map(hx, ("3e3a48", "7b7686", "b4afbb"))
BLUE = hx("3a2f7c")


def mix(a, b, k):
    k = np.asarray(k)[..., None] if np.ndim(k) else k
    return a * (1 - k) + b * k


def ramp(x, cols, xs=None):
    x = np.clip(x, 0, 1)
    xs = np.linspace(0, 1, len(cols)) if xs is None else xs
    return np.stack([np.interp(x, xs, [c[i] for c in cols]) for i in range(3)], axis=-1).astype(np.float32)


def vnoise(S, T, cx, cy, seed):
    """smooth value noise over (S, T) in 0..1, cx by cy cells, tiling in S"""
    rng = np.random.RandomState(seed)
    g = rng.rand(cy + 2, cx + 1)
    g[:, -1] = g[:, 0]
    x, y = S * cx, T * cy
    xi = np.clip(x.astype(int), 0, cx - 1)
    yi = np.clip(y.astype(int), 0, cy)
    fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[yi, xi] * (1 - fx) + g[yi, xi + 1] * fx
    b = g[yi + 1, xi] * (1 - fx) + g[yi + 1, xi + 1] * fx
    return a * (1 - fy) + b * fy


def fbm(S, T, cx, cy, seed, oct=4):
    v, a, tot = 0, 1.0, 0
    for i in range(oct):
        v = v + a * vnoise(S, T, cx << i, cy << i, seed + i)
        tot += a
        a *= 0.5
    return v / tot


def folds(S, T, n, seed, sway=0.03):
    """a shade -1..1 from long cloth folds running down the t axis"""
    S2 = (S + sway * np.sin(T * 7 + seed)) % 1.0
    f = fbm(S2, T * 0.3, n, 2, seed, 3)
    d = np.gradient(f, axis=1) * S.shape[1] / n
    return np.clip(d * 3.0 + (f - 0.5) * 1.1, -1, 1)


def stars(S, T, seed, dens=0.0035, sz=1.2):
    rng = np.random.RandomState(seed)
    h, w = S.shape
    out = np.zeros((h, w), np.float32)
    n = int(h * w * dens * 0.05)
    ys, xs, b = rng.randint(1, max(h - 1, 2), n), rng.randint(1, max(w - 1, 2), n), rng.rand(n)
    out[ys, xs] = b
    out[ys, np.minimum(xs + 1, w - 1)] = np.maximum(out[ys, np.minimum(xs + 1, w - 1)], b * 0.5)
    out[np.minimum(ys + 1, h - 1), xs] = np.maximum(out[np.minimum(ys + 1, h - 1), xs], b * 0.5)
    return out


def galaxy(S, T, seed):
    """the Void in the cloth: blue-violet nebula with stars"""
    n = fbm(S, T, 6, 5, seed)
    n2 = fbm(S, T, 9, 7, seed + 9)
    c = ramp(n * 1.5 - 0.25, [hx("140a2a"), hx("2b1a63"), hx("4b2aa0"), hx("7a48c8")])
    c = mix(c, hx("20368a"), np.clip(n2 * 2.0 - 1.0, 0, 1) * 0.7)
    s = stars(S, T, seed)
    return c + (hx("f0e6ff") - c) * s[..., None]


def shade(c, f, k=0.5):
    """darken/lighten paint by a fold field"""
    return np.clip(c * (1 + f[..., None] * k), 0, 1)


def edges(S, T, w=0.02):
    return np.maximum(M.sm(w, 0, S), M.sm(1 - w, 1, S))


# ---------------------------------------------------------------------------- pieces
def p_torso(S, T):
    f = folds(S, T, 11, 3)
    base = ramp(0.5 + f * 0.25, [PLUM, VIOLET, VIOLET_HI], [0, 0.6, 1])
    # the back half is the darker
    back = np.abs(S - 0.75) < 0.25
    base = mix(base, shade(mix(DUSK, BLACK, 0.3) * np.ones_like(base), f, 0.4), M.sm(0.28, 0.22, np.abs(S - 0.75)))
    # the Void panels on the chest, either side of the placket
    pan = M.sm(0.145, 0.13, np.abs(S - 0.25)) * M.sm(0.032, 0.04, np.abs(S - 0.25)) * M.sm(0.28, 0.33, T) * M.sm(0.97, 0.9, T)
    g = galaxy(S, T, 5)
    base = mix(base, g, pan)
    rim = np.clip(np.exp(-((np.abs(S - 0.25) - 0.145) / 0.0045) ** 2) + np.exp(-((np.abs(S - 0.25) - 0.036) / 0.003) ** 2), 0, 1) * M.sm(0.28, 0.33, T)
    base = mix(base, TRIM, rim * 0.9)
    # the placket
    pl = M.sm(0.034, 0.03, np.abs(S - 0.25))
    base = mix(base, shade(PLUM * np.ones_like(base), f, 0.3), pl)
    # under the ruff and collar the coat falls into shadow
    base = base * (0.45 + 0.55 * M.sm(0.1, 0.45, T))[..., None]
    return base


def p_skirt(S, T):
    f = folds(S, T, 19, 7)
    n = 7
    q = S * n
    idx = q.astype(int)
    col = (idx % 2 == 0)
    violet = shade(ramp(0.55 + f * 0.3, [DUSK, VIOLET, VIOLET_HI]), f, 0.25)
    dark = shade(PLUM * np.ones_like(violet) * 1.1, f, 0.45)
    g = galaxy(S, T, 11)
    # a rent of Void in each violet panel, widening to the hem
    p = np.abs((q % 1.0) - 0.5)
    pan = M.sm(0.27, 0.2, p + 0.14 * np.sin(T * 9 + idx)) * M.sm(0.1, 0.35, T)
    base = np.where(col[..., None], mix(violet, g, pan * 0.9), dark)
    # seams between panels, and the bright edge he reads by at the match camera
    seam = np.exp(-(((q % 1.0) - 0.0) / 0.03) ** 2) + np.exp(-(((q % 1.0) - 1.0) / 0.03) ** 2)
    base = mix(base, BLACK, np.clip(seam, 0, 1) * 0.7)
    edge = np.maximum(M.sm(0.93, 0.985, T), edges(S, T, 0.012))
    base = mix(base, TRIM, edge * 0.95)
    base = base * (0.6 + 0.4 * M.sm(0.0, 0.3, T))[..., None]
    return base


def p_lining(S, T):
    return ramp(fbm(S, T, 5, 5, 2), [hx("120830"), hx("2c1668"), hx("4a2a9a")])


def p_sleeve(S, T):
    f = folds(T.T if False else S, T, 7, 13)
    g = galaxy(S, T, 17)
    base = mix(shade(ramp(0.45 + f * 0.3, [PLUM, VIOLET, VIOLET_HI]), f, 0.25), g, 0.75 * M.sm(0.42, 0.5, fbm(S, T, 4, 5, 3)))
    base = mix(base, shade(PLUM * np.ones_like(base), f, 0.3), M.sm(0.72, 0.78, T))
    return base * (0.7 + 0.3 * M.sm(0.0, 0.2, T))[..., None]


def p_cuff(S, T):
    f = folds(S, T, 12, 21, 0.0)
    base = shade(ramp(0.3 + 0.5 * T, [BLACK, PLUM, DUSK]), f, 0.5)
    return mix(base, TRIM, M.sm(0.86, 0.97, T) * 0.9)


def p_glove(S, T):
    base = ramp(0.5 + 0.5 * np.sin(S * 6.283 * 2), [PLUM, DUSK])
    return base * (0.8 + 0.2 * fbm(S, T, 8, 8, 4))[..., None] * 1.15


def p_finger(S, T):
    base = ramp(T * 0.3 + 0.35 + 0.2 * np.cos(S * 6.283), [BLACK, PLUM, hx("4a3a5a")])
    # creases at the joints; the claw is a shade colder and bright at the tip
    cr = np.exp(-((T - 0.45) / 0.02) ** 2) + np.exp(-((T - 0.72) / 0.02) ** 2)
    base = mix(base, BLACK, np.clip(cr, 0, 1) * 0.7)
    return mix(base, hx("8a6fb0"), M.sm(0.84, 1.0, T))


def p_hood(S, T):
    f = folds(S, T, 9, 31, 0.0)
    cv = shade(ramp(0.55 + f * 0.3, [DUSK, VIOLET, VIOLET_HI, TRIM], [0, 0.45, 0.85, 1]), f, 0.25)
    ck = shade(hx("1d1426") * np.ones_like(cv), f, 0.5)
    right = M.sm(0.0, 0.004, S) * M.sm(0.5, 0.496, S)       # his right half, violet
    base = mix(ck, cv, right)
    # the rim on the mask, dark, and a thin line down the middle
    base = base * (0.6 + 0.4 * M.sm(0.0, 0.14, T))[..., None]
    return base


def horn_paint(s0):
    def fn(S, T):
        f = folds(S, T, 7, 37, 0.01)
        d = np.abs(((S - s0 + 0.5) % 1.0) - 0.5)
        ck = shade(ramp(0.4 + f * 0.3, [BLACK, hx("1d1426"), DUSK]), f, 0.5)
        cv = shade(ramp(0.55 + f * 0.3, [DUSK, VIOLET, VIOLET_HI]), f, 0.3)
        pan = M.sm(0.24, 0.2, d) * M.sm(0.92, 0.8, T)
        base = mix(ck, cv, pan)
        base = mix(base, TRIM, np.exp(-((d - 0.225) / 0.008) ** 2) * M.sm(0.92, 0.8, T) * 0.8)
        return mix(base, hx("6d6a78"), M.sm(0.965, 0.99, T))
    return fn


def p_ruff(S, T):
    ph = S * 19 * 6.283
    q = 1 - np.abs(T * 2 - 1)
    light = 0.5 + 0.5 * np.cos(ph + 1.0)
    c = ramp(light * (0.45 + 0.55 * q), [RUFF_D, RUFF_M, RUFF_L], [0, 0.55, 1])
    c = c * (0.55 + 0.45 * M.sm(0.1, 0.42, T))[..., None]
    # the line along the scalloped edge
    c = mix(c, hx("35303f"), np.exp(-((T - 0.5) / 0.018) ** 2) * 0.8)
    return c * (0.9 + 0.2 * fbm(S, T, 40, 4, 2))[..., None]


def collar_paint(col_a, col_b, seed):
    def fn(S, T):
        f = folds(S, T, 4, seed, 0.02)
        base = shade(ramp(0.3 + 0.5 * T + f * 0.2, [col_a, col_b]), f, 0.35)
        mk = np.maximum(edges(S, T, 0.09), M.sm(0.9, 1.0, T))
        return mix(base, TRIM, mk * 0.85)
    return fn


def p_ribbon(S, T):
    f = folds(S, T, 3, 41, 0.0)
    return shade(ramp(0.5 + f * 0.3, [hx("241c52"), BLUE, hx("5a4cb0")]), f, 0.3)


def p_button(S, T):
    return ramp(T, [hx("6a5a7a"), hx("2a2230")])


def p_bell(S, T):
    c = ramp(0.55 + 0.45 * np.sin(S * 6.283 + 0.8), [hx("55505e"), hx("9a95a4"), hx("e6e2ec")])
    c = c * (0.65 + 0.35 * np.sin(np.clip(T, 0, 1) * 3.1))[..., None] + 0.15
    return mix(c, hx("17121c"), M.sm(0.7, 0.74, T) * M.sm(0.86, 0.82, T))


def p_halo(S, T):
    # S along the crescent, T round its plate's section (front face in the middle of rows 0..0.6)
    n = fbm(S, T, 16, 3, 51)
    base = ramp(n * 1.2 - 0.1, [hx("5a2ac8"), hx("7a44e8"), hx("b08cf8")])
    # cracks: each a jagged walk across the plate, some forking
    cr = np.zeros(S.shape)
    rng = np.random.RandomState(8)
    for i in range(9):
        s0 = rng.uniform(0.04, 0.96)
        pts = [(s0 + 0.03 * x, y) for x, y in zip(np.cumsum(rng.uniform(-1, 1, 6)), np.linspace(-0.02, 0.62, 6))]
        d, _ = M.seg_dist(S, T * 0.32, [(p[0], p[1] * 0.32) for p in pts])
        cr = np.maximum(cr, M.sm(0.0042, 0.0012, d))
        m = pts[rng.randint(2, 4)]
        d, _ = M.seg_dist(S, T * 0.32, [(m[0], m[1] * 0.32), (m[0] + rng.uniform(-0.07, 0.07), (m[1] + 0.2) * 0.32)])
        cr = np.maximum(cr, M.sm(0.003, 0.001, d))
    base = mix(base, hx("1e0640"), cr)
    edge = np.maximum(M.sm(0.08, 0.0, T), M.sm(0.5, 0.62, T) * M.sm(0.72, 0.62, T))
    return mix(base, hx("d0b4ff"), edge * 0.7)


def p_orbcore(S, T):
    return ramp(fbm(S, T, 4, 4, 9), [hx("04020a"), hx("120828"), hx("2a1460")])


def p_swirl(S, T):
    return ramp((1 - T) * (0.4 + 0.6 * (1 - np.abs(S - 0.5) * 2)), [hx("3a12a0"), hx("6a2ae0"), hx("a868ff"), hx("e8c8ff")], [0, 0.45, 0.8, 1])


def p_eye(S, T):
    # (the ball's front is at s = 0.25: a pinpoint in a violet iris)
    d = np.hypot((S - 0.25) * 2.2, T - 0.5)
    return ramp(d, [hx("ffffff"), hx("d0a0ff"), hx("7a28f0"), hx("5a14d0")], [0, 0.1, 0.22, 0.5])


def p_card(S, T):
    d = np.abs(S - 0.5) / 0.26 + np.abs(T - 0.5) / 0.3
    c = ramp(T, [hx("1a1224"), hx("2a1c38")])
    c = mix(c, hx("b070ff"), M.sm(1.05, 0.9, d))
    return mix(c, hx("e0c8ff"), np.maximum(edges(S, T, 0.06), np.maximum(M.sm(0.06, 0.0, T), M.sm(0.94, 1.0, T))))


def p_wisp(S, T):
    # the strands of smoke running along the rope
    ang = (S + T * 1.7) % 1.0
    st = fbm(ang, T * 0.2, 14, 2, 61, 3)
    c = ramp(0.15 + 0.6 * T + (st - 0.5) * 1.2, [hx("160a26"), hx("361a5c"), hx("5e3296"), hx("8a5cc4")])
    return c


PAINTERS = {"torso": p_torso, "skirt": p_skirt, "lining": p_lining, "sleeve": p_sleeve, "cuff": p_cuff, "glove": p_glove,
            "finger": p_finger, "hood": p_hood, "hornR": horn_paint(0.75), "hornL": horn_paint(0.25), "ruff": p_ruff,
            "collar_v": collar_paint(VIOLET, VIOLET_HI, 71), "collar_k": collar_paint(BLACK, PLUM, 73), "ribbon": p_ribbon,
            "button": p_button, "bell": p_bell, "halo": p_halo, "orbcore": p_orbcore, "orbswirl": p_swirl, "eye": p_eye, "card": p_card, "wisp": p_wisp}


class Atlas:
    """a shelf packer: key -> rect; paints each key once"""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = np.zeros((h, w, 3), np.float32) + hx("1a1320")
        self.x = self.y = 2
        self.shelf = 0
        self.rect = {}

    def put(self, key, px):
        if key in self.rect:
            return self.rect[key]
        w, h = px
        if (w, h) == (self.w, self.h):          # (the whole image: the wisp's v is its fade in hero_void)
            self.x = self.y = 0
        elif self.x + w + 6 > self.w:
            self.x = 2
            self.y += self.shelf + 8
            self.shelf = 0
        if self.y + h + 2 > self.h and (w, h) != (self.w, self.h):
            raise RuntimeError("atlas full at " + key)
        x, y = self.x, self.y
        self.x += w + 8
        self.shelf = max(self.shelf, h)
        ss, tt = np.meshgrid((np.arange(w) + 0.5) / w, (np.arange(h) + 0.5) / h)
        c = PAINTERS[key](ss.astype(np.float32), tt.astype(np.float32))
        self.img[y:y + h, x:x + w] = c
        if (w, h) == (self.w, self.h):
            self.rect[key] = (0, 0, w, h)
            return self.rect[key]
        # bleed the edges into the gutter
        self.img[max(y - 3, 0):y, x:x + w] = c[0]
        self.img[y + h:y + h + 3, x:x + w] = c[-1]
        self.img[y - 3 if y >= 3 else 0:y + h + 3, max(x - 3, 0):x] = self.img[y - 3 if y >= 3 else 0:y + h + 3, x:x + 1]
        self.img[y - 3 if y >= 3 else 0:y + h + 3, x + w:x + w + 3] = self.img[y - 3 if y >= 3 else 0:y + h + 3, x + w - 1:x + w]
        self.rect[key] = (x, y, w, h)
        return self.rect[key]

    def uv(self, key, s, t):
        x, y, w, h = self.rect[key]
        return (x + 0.5 + s * (w - 1)) / self.w, 1.0 - (y + 0.5 + t * (h - 1)) / self.h


def blur(a, r):
    k = 2 * r + 1
    for ax in (0, 1):
        c = np.cumsum(a, axis=ax)
        c = np.concatenate((np.zeros_like(np.take(c, [0], ax)), c), axis=ax)
        n = a.shape[ax]
        hi = np.take(c, np.minimum(np.arange(n) + r + 1, n), ax)
        lo = np.take(c, np.maximum(np.arange(n) - r, 0), ax)
        span = (np.minimum(np.arange(n) + r + 1, n) - np.maximum(np.arange(n) - r, 0)).astype(np.float32)
        a = (hi - lo) / (span[:, None] if ax == 0 else span[None, :])
    return a


CRACK_ART = [
    [(355, 375), (385, 440), (375, 490), (402, 560), (392, 610), (412, 655), (455, 695)],
    [(455, 695), (476, 640)],
    [(455, 695), (428, 745), (392, 830), (362, 930)],
    [(455, 695), (470, 740), (470, 790)],
    [(412, 655), (440, 640)],
]
SHEET_C = (265.0, 685.0, 215.0, 320.0)


def to_plane(p):
    return ((p[0] - SHEET_C[0]) / -SHEET_C[2], (SHEET_C[1] - p[1]) / SHEET_C[3])


def mask_textures(size=1024):
    """-> albedo, emission (size, size, 3): u across, v up on the sheet; his right (+x) is image left... u = pu * 0.5 + 0.5, row 0 at v = 1"""
    xs = (np.arange(size) + 0.5) / size * 2 - 1
    ys = 1 - (np.arange(size) + 0.5) / size * 2
    U, V = np.meshgrid(xs, ys)
    U = U.astype(np.float64)
    V = V.astype(np.float64)
    h = M.height(U, V)
    du = np.gradient(h, axis=1) * size / 2
    dv = np.gradient(h, axis=0) * -size / 2
    k = 0.42
    nx = -du * k + U * 0.75
    ny = -dv * k + V * 0.55
    nz = np.ones_like(U)
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / L, ny / L, nz / L
    l = np.array((-0.28, 0.62, 0.73))
    l = l / np.linalg.norm(l)
    diff = nx * l[0] + ny * l[1] + nz * l[2]
    occ = np.clip((blur(h, 16) - h) * 7.0, 0, 1)
    occ2 = np.clip((blur(h, 5) - h) * 16.0, 0, 1)
    c = ramp(diff * 0.8 + 0.3 - 0.35 * occ - 0.22 * occ2, [hx("3a3648"), hx("817c98"), hx("c4c0d2"), hx("f0edf5"), hx("ffffff")], [0, 0.3, 0.5, 0.72, 1])
    hv = l + np.array((0, 0, 1.0))
    hv = hv / np.linalg.norm(hv)
    spec = np.clip(nx * hv[0] + ny * hv[1] + nz * hv[2], 0, 1) ** 70
    c = c + (1 - c) * np.clip(spec * 0.85, 0, 1)[..., None]
    # a violet cast in the folds and under the brows, as the sheet has
    c = mix(c, hx("7a60b4"), np.clip(occ * 1.2, 0, 0.45))
    # the eye sockets: black, ringed with violet
    s = M.eye_socket(U, V)
    c = mix(c, hx("0a0610"), M.sm(0.1, 0.8, s))
    ring = np.clip(1 - np.abs(s - 0.12) / 0.14, 0, 1)
    c = mix(c, hx("5a2aa8"), ring * 0.55)
    # the mouth
    m = M.mouth_mask(U, V, 0.008)
    t, seam, rows = M.teeth(U, V)
    tooth = M.sm(0.42, 0.72, t)
    mc = ramp(tooth, [hx("1c0650"), hx("5a30b8"), hx("a184e0")], [0, 0.45, 1])
    c = mix(c, mc, m)
    top, bot = M.lips(U)
    ink = (np.exp(-((V - top) / 0.012) ** 2) + np.exp(-((V - bot) / 0.012) ** 2)) * (np.abs(U) < 0.82)
    c = mix(c, hx("1a1024"), np.clip(ink, 0, 1) * 0.85)
    # the corners of the grin bite hard
    em = np.zeros(U.shape + (3,), np.float32)
    em = em + (hx("7a30ff") - em) * (m * (0.55 + 0.45 * tooth))[..., None]
    em = em + (hx("c8a0ff") - em) * (m * tooth * 0.6)[..., None]
    # the tear under his right eye
    tu, tv = 0.43, -0.03
    du2 = (U - tu) / 0.06
    dv2 = (V - tv) / 0.095
    drop = np.sqrt(du2 ** 2 / np.maximum(0.15 + 0.85 * M.sm(0.9, -0.5, dv2), 0.05) + dv2 ** 2)
    td = M.sm(1.0, 0.82, drop) * (U > 0)
    c = mix(c, hx("6a35d8"), td)
    d, _ = M.seg_dist(U, V, [(0.43, 0.14), (0.43, 0.06)])
    tl = M.sm(0.016, 0.006, d)
    c = mix(c, hx("6a35d8"), tl)
    em = em + (hx("7a3aff") - em) * (np.maximum(td, tl) * 0.75)[..., None]
    # the crack: dark hairlines with the void's light in the wide ones near the cheek
    cr = np.zeros(U.shape)
    wob_u = U + 0.012 * np.sin(V * 41) + 0.007 * np.sin(V * 93 + 1)
    wob_v = V + 0.01 * np.sin(U * 57)
    for i, poly in enumerate(CRACK_ART):
        pl = np.array([to_plane(p) for p in poly])
        d, a = M.seg_dist(wob_u, wob_v, pl)
        w = (0.006 + 0.012 * (i in (0, 2)) * (a if i == 0 else 1 - a) + 0.002)
        cr = np.maximum(cr, M.sm(w * 1.1, w * 0.4, d))
    c = mix(c, hx("2a1450"), cr)
    hub = gaussish = np.exp(-(((U + 0.885) / 0.2) ** 2 + ((V - 0.0) / 0.28) ** 2))
    em = em + (hx("c45cff") - em) * (cr * np.clip(0.25 + hub * 1.4, 0, 1))[..., None]
    em = em + (hx("f4d0ff") - em) * (M.sm(0.5, 1.0, cr) * np.clip(hub * 1.4 - 0.3, 0, 1))[..., None]
    c = mix(c, hx("d090ff"), M.sm(0.3, 1.0, cr) * np.clip(hub * 1.5 - 0.2, 0, 1))
    # a soft violet bloom painted round the crack's heart and the mouth
    glow = blur(cr.astype(np.float32) * hub, 14) * 2.5
    c = c + (hx("a050f0") - c) * np.clip(glow, 0, 0.5)[..., None]
    return np.clip(c, 0, 1).astype(np.float32), np.clip(em, 0, 1).astype(np.float32)

"""Motley's textures (ART-1), painted with numpy: wood, brass, cloth folds, card faces. All colours sRGB 0..1; images run top to bottom,
t down. The face is ostra_mask.textures."""
import numpy as np
import ostra_mask as M


def hx(s):
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


# (v2 sheet, sampled from motley_v2_turnaround.jpg: a magenta-violet light side, a plum dark side, a lilac ruff)
BLACK, PLUM, DUSK, VIOLET, VIOLET_HI, TRIM, HOT = map(hx, ("1e1224", "3a2440", "5b2e6d", "6d3b82", "9b65b3", "b58ad0", "e0aaff"))
RUFF_D, RUFF_M, RUFF_L = map(hx, ("6a4c7a", "a98cb9", "d7bedf"))
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
# (v2 sheet: dusty mauve panels in plum-brown frames, muted bronze brass, plum spades, wine diamonds)
WOOD_D, WOOD_M, WOOD_L = map(hx, ("6a5468", "8c7488", "a8929f"))
IRON = hx("6a3a4c")
GOLD_D, GOLD_M, GOLD_L = map(hx, ("6e4a3a", "b08868", "e8c49a"))
RED, SLATE = hx("7f3d49"), hx("543756")
BLACK2 = hx("4e3053")


def suit(kind, x, y):
    """a card suit's mask at (x, y), centred, about 1 tall (y up)"""
    x = np.abs(x) if kind in ("spade", "heart", "club") else x
    if kind == "diamond":
        return M.sm(1.0, 0.94, (np.abs(x) / 0.36 + np.abs(y) / 0.5))
    if kind == "heart":
        a = np.hypot(x - 0.2, y - 0.17) < 0.25
        tri = (y < 0.2) & (y > -0.5) & (x < (y + 0.5) * 0.63)
        return (a | tri).astype(np.float32)
    if kind == "spade":
        a = np.hypot(x - 0.19, y + 0.08) < 0.22
        tri = (y > -0.14) & (y < 0.5) & (x < (0.5 - y) * 0.68)
        stem = (y < 0.0) & (y > -0.5) & (x < 0.03 + (0.0 - y) * 0.2)
        return (a | tri | stem).astype(np.float32)
    a = np.hypot(x, y - 0.22) < 0.21
    b = np.hypot(x - 0.22, y + 0.1) < 0.21
    stem = (y < 0.0) & (y > -0.5) & (x < 0.03 + (0.0 - y) * 0.2)
    return (a | b | stem).astype(np.float32)


def wood(S, T, seed):
    planks = (S * 4.0 + 0.1 * np.sin(T * 5 + seed)) % 1.0
    grain = fbm(S * 0.6, T, 26, 3, seed, 3)
    c = ramp(grain * 1.5 - 0.2, [WOOD_D, WOOD_M, WOOD_L])
    c = c * (1 - 0.6 * np.exp(-(planks / 0.03) ** 2))[..., None]
    return c


def wall(kind, col, seed):
    def fn(S, T):
        c = wood(S, T, seed)
        pan = M.sm(0.09, 0.12, S) * M.sm(0.91, 0.88, S) * M.sm(0.09, 0.12, T) * M.sm(0.91, 0.88, T)
        c = c * (0.62 + 0.38 * (1 - pan))[..., None] + mix(c, hx("b89aae"), 0.5) * 0.38 * pan[..., None]
        sm_ = suit(kind, (S - 0.5) * 1.5, (0.5 - T) * 1.5)
        wear = 0.82 + 0.18 * fbm(S, T, 18, 18, seed + 3, 3)
        c = mix(c, col * wear[..., None], np.clip(sm_, 0, 1))
        return c
    return fn


def p_rail(S, T):
    return ramp(0.45 + 0.4 * np.cos(S * 6.283) + 0.2 * (fbm(S, T, 8, 8, 5) - 0.5), [hx("2e1826"), IRON, hx("7a4a60")])


def p_lid(S, T):
    c = wood(S, T, 91)
    return c * (0.7 + 0.3 * M.sm(0.02, 0.12, T))[..., None]


def p_brass(S, T):
    return ramp(0.5 + 0.48 * np.cos(S * 6.283 * 2 + 0.6), [GOLD_D, GOLD_M, GOLD_L])


def p_bell(S, T):
    c = ramp(0.5 + 0.48 * np.cos(S * 6.283 + 0.9), [hx("5e403c"), hx("a07870"), hx("e2bfa8")])
    return mix(c * (0.75 + 0.35 * np.sin(np.clip(T, 0, 1) * 3.1))[..., None], hx("20140c"), M.sm(0.72, 0.76, T) * M.sm(0.92, 0.88, T))


def harlequin(S, T, a, b, seed):
    f = folds(S, T, 9, seed, 0.01)
    return mix(shade(ramp(0.5 + f * 0.3, [DUSK, VIOLET, VIOLET_HI]), f, 0.1), shade(BLACK2 * np.ones(S.shape + (3,)), f, 0.14), np.clip(a, 0, 1))


def p_torso(S, T):
    # (s 0 at his right, 0.25 front, 0.5 his left, 0.75 back) front: his right black, his left violet; back: the other way round
    q = (S % 1.0)
    dark = ((q >= 0.0) & (q < 0.25)) | ((q >= 0.5) & (q < 0.75))
    c = harlequin(S, T, dark.astype(np.float32), None, 3)
    c = c * (1 - 0.25 * np.exp(-((T - 0.8) / 0.012) ** 2))[..., None]      # (v2 sheet: a waist seam, no belt)
    return c * (0.72 + 0.28 * M.sm(0.05, 0.3, T))[..., None]


def p_peplum(S, T):
    dark = (S >= 0.5).astype(np.float32)      # (s 0 his right front... round the back to his left front)
    dark = 1.0 - dark
    c = harlequin(S, T, dark, None, 7)
    return mix(c, TRIM, edges(S, T, 0.012) * 0.8)


def p_lining(S, T):
    return ramp(fbm(S, T, 5, 5, 2), [hx("120830"), hx("2c1668"), hx("4a2a9a")])


def tail_paint(dark, seed):
    def fn(S, T):
        f = folds(S, T, 3, seed, 0.02)
        c = shade(ramp(0.5 + f * 0.1, [DUSK, VIOLET, VIOLET_HI]), f, 0.1) if not dark else shade(BLACK2 * np.ones(S.shape + (3,)), f, 0.14)
        return mix(c, TRIM, edges(S, T, 0.05) * (0.9 if dark else 0.6))
    return fn


def sleeve_paint(dark, seed):
    def fn(S, T):
        f = folds(S, T, 6, seed)
        c = shade(ramp(0.5 + f * 0.1, [DUSK, VIOLET, VIOLET_HI]), f, 0.1) if not dark else shade(BLACK2 * np.ones(S.shape + (3,)), f, 0.14)
        return c * (0.75 + 0.25 * M.sm(0.0, 0.2, T))[..., None]
    return fn


def p_glove(S, T):
    return ramp(0.62 + 0.3 * np.cos(S * 6.283) + 0.1 * (fbm(S, T, 5, 5, 8) - 0.5), [hx("9072a0"), hx("c4abd2"), hx("e2d2ea")])     # (v2 sheet: lilac gloves)


def p_hood(S, T):
    # (ostra_head: his right dark and his left violet in front, the other way behind, each opposite its horn. s < 0.5 is his right; t from the face back)
    f = folds(S, T, 8, 31, 0.0)
    cv = shade(ramp(0.5 + f * 0.1, [DUSK, VIOLET, VIOLET_HI]), f, 0.1)
    ck = shade(BLACK2 * np.ones_like(cv), f, 0.14)
    violet = (S < 0.5) == (T > 0.6)
    c = mix(ck, cv, violet.astype(np.float32))
    # the broad rim stands proud of the hood: a soft shadow behind it, and its inner edge falling into the void
    c = c * (1 - 0.4 * np.exp(-((T - 0.27) / 0.035) ** 2))[..., None]
    return c * (0.55 + 0.45 * M.sm(0.0, 0.06, T))[..., None]


def horn_paint(dark):
    def fn(S, T):
        f = folds(S, T, 6, 37, 0.01)
        c = shade(BLACK2 * np.ones(S.shape + (3,)), f, 0.14) if dark else shade(ramp(0.5 + f * 0.1, [DUSK, VIOLET, VIOLET_HI]), f, 0.1)
        return mix(c, GOLD_M, M.sm(0.965, 0.99, T))
    return fn


def p_ruff(S, T):
    # (T 0..1 from the neck over the top, down the wall at 0.4..0.6, back under; the pleats snake on the wall, each with its dark outline)
    wall = M.sm(0.32, 0.42, T) * M.sm(0.68, 0.58, T)
    ph = S * 29 * 6.283 + 2.2 * np.cos((T - 0.5) * 3.14 * 3.0) * 0 + 7.0 * (T - 0.5) * wall
    fold = 0.5 + 0.5 * np.cos(ph + 1.0)
    c = ramp(fold * 0.7 + 0.32, [RUFF_D, RUFF_M, RUFF_L], [0, 0.5, 1])     # (v2 sheet: a lilac ruff)
    line = np.exp(-((np.abs(((ph + 1.0) / 6.283) % 1.0 - 0.5)) / 0.06) ** 2)
    c = mix(c, hx("6a4c7a"), line * (0.2 + 0.45 * wall))
    return c * (0.66 + 0.34 * M.sm(0.03, 0.22, T) * M.sm(0.97, 0.78, T))[..., None]


def collar_paint(col_a, col_b, seed):
    def fn(S, T):
        f = folds(S, T, 3, seed, 0.02)
        c = shade(ramp(0.3 + 0.5 * T + f * 0.2, [col_a, col_b]), f, 0.35)
        return mix(c, TRIM, np.maximum(edges(S, T, 0.07), M.sm(0.92, 1.0, T)) * 0.75)
    return fn


def p_wisp(S, T):
    ang = (S + T * 1.7) % 1.0
    st = fbm(ang, T * 0.2, 14, 2, 61, 3)
    return ramp(0.25 + 0.4 * T + (st - 0.5) * 1.2, [hx("120826"), hx("2a1458"), hx("4e2a96"), hx("7a50c4")])


def glow_rim(S, T, c):
    """a card lit from within: its edge burns violet, its heart stays pale"""
    d = np.minimum(np.minimum(S, 1 - S) * 1.4, np.minimum(T, 1 - T))
    c = mix(c, hx("9a58ff"), M.sm(0.16, 0.0, d))
    return mix(c, hx("e4d0ff"), M.sm(0.03, 0.0, d))


def p_card(S, T):
    """a card's face: lilac, lit from within, its pip deep violet"""
    c = ramp(T, [hx("8f7cea"), hx("7a62e0")])
    c = mix(c, hx("4e14c0"), suit("diamond", (S - 0.5) * 2.0, (0.5 - T) * 2.0))
    return glow_rim(S, T, c)


def p_voidcard(S, T):
    """item 136: the flurry's card: void violet, a teal rim, a suit-diamond eye; bright enough to read as it flies"""
    n = fbm(S, T, 5, 7, 23)
    c = ramp(n * 1.3 - 0.1, [hx("1a0a3e"), hx("3a1a90"), hx("6a34d8")])
    c = mix(c, hx("c8a0ff"), suit("diamond", (S - 0.5) * 2.0, (0.5 - T) * 2.0))
    c = mix(c, hx("1a0a3e"), suit("diamond", (S - 0.5) * 3.4, (0.5 - T) * 3.4))
    d = np.minimum(np.minimum(S, 1 - S) * 1.4, np.minimum(T, 1 - T))
    c = mix(c, hx("3cf0d8"), M.sm(0.075, 0.02, d))
    return np.clip(mix(c, hx("c8fff4"), M.sm(0.026, 0.0, d)), 0, 1)


def p_cardback(S, T):
    c = ramp(0.5 + 0.5 * np.sin((S + T) * 40) * np.sin((S - T) * 40), [hx("3a1a90"), hx("6a3ae0")])
    d = np.abs(S - 0.5) * 1.5 + np.abs(T - 0.5)
    c = mix(c, hx("c8a0ff"), np.exp(-((d - 0.3) / 0.015) ** 2))
    return glow_rim(S, T, c)


def p_cardburn(S, T):
    """a burnt card: charred from one corner, the burn's edge an ember, soft, not a stroke"""
    c = p_card(S, T)
    d = np.hypot(S - 1.0, T) + 0.14 * (fbm(S, T, 7, 7, 15, 3) - 0.5)
    c = mix(c, hx("4a2418"), M.sm(0.78, 0.62, d) * 0.8)
    c = mix(c, hx("ff8a3a"), np.exp(-((d - 0.6) / 0.05) ** 2) * 0.85)
    return mix(c, hx("1c0e0c"), M.sm(0.58, 0.5, d))


def p_flame(S, T):
    return ramp(T, [hx("7a2a60"), hx("e0622a"), hx("ffb060")])


PAINTERS = {"flame": p_flame, "wall_s": wall("spade", SLATE, 11), "wall_d": wall("diamond", RED, 12), "wall_sb": wall("spade", SLATE, 13), "wall_db": wall("diamond", RED, 14), "rail": p_rail,
            "lid": p_lid, "brass": p_brass, "bell": p_bell, "torso": p_torso, "peplum": p_peplum, "lining": p_lining,
            "tail_v": tail_paint(False, 41), "tail_k": tail_paint(True, 43), "sleeve_k": sleeve_paint(True, 13), "sleeve_v": sleeve_paint(False, 15), "glove": p_glove,
            "hood": p_hood, "hornR": horn_paint(False), "hornL": horn_paint(True), "ruff": p_ruff, "collar_v": collar_paint(VIOLET, VIOLET_HI, 71), "collar_k": collar_paint(BLACK, PLUM, 73),
            "wisp": p_wisp, "card": p_card, "cardback": p_cardback, "cardburn": p_cardburn}


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


RELIEF = {"wall_s": 1.3, "wall_d": 1.3, "wall_sb": 1.3, "wall_db": 1.3, "lid": 1.3, "rail": 1.0, "brass": 0.7, "bell": 0.7, "torso": 0.8, "peplum": 0.9,
          "tail_v": 0.9, "tail_k": 0.9, "sleeve_k": 0.8, "sleeve_v": 0.8, "glove": 0.5, "hood": 0.8, "hornR": 0.9, "hornL": 0.9, "ruff": 0.8, "collar_v": 0.9, "collar_k": 0.9}


def normal_map(at):
    """the atlas's relief as a tangent-space normal map (OpenGL green): each patch's own painted light and shade taken as height, so plank
    gaps, grain, cloth folds and ruff pleats catch the real light in the close view"""
    h, w = at.img.shape[:2]
    out = np.zeros((h, w, 3), np.float32)
    out[..., 0] = out[..., 1] = 0.5
    out[..., 2] = 1.0
    for key, (x, y, rw, rh) in at.rect.items():
        k = RELIEF.get(key, 0.0)
        if k <= 0.0:
            continue
        lum = at.img[y:y + rh, x:x + rw].mean(axis=2).astype(np.float32)
        lum = lum - blur(lum, 18) * 0.6
        dx = np.gradient(lum, axis=1) * 6.0 * k
        dy = np.gradient(lum, axis=0) * 6.0 * k
        n = np.dstack((-dx, dy, np.ones_like(dx)))
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        out[y:y + rh, x:x + rw] = n * 0.5 + 0.5
    return out

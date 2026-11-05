"""ART-1 Kael: the texel-space paint. Every function works on arrays of texels (world position, normal, ambient
occlusion) and returns linear-free sRGB colours in 0..1, so a piece is painted as a shader, then baked in the atlas."""
import numpy as np
from meshkit import norm, smooth
import kael_pieces as K


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


def hash3(ix, iy, iz):
    v = (ix * 127 + iy * 311 + iz * 74) & 0xffff
    v = (v * (v * v * 15731 + 789221) + 1376312589) & 0x7fffffff
    return (v % 100003) / 100003.0


def vnoise(p):
    p = np.asarray(p, dtype=np.float64)
    i = np.floor(p).astype(np.int64)
    f = p - i
    u = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[..., 0] if dx else 1 - u[..., 0]) * (u[..., 1] if dy else 1 - u[..., 1]) * \
                    (u[..., 2] if dz else 1 - u[..., 2])
                out = out + w * hash3(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz)
    return out


def fbm(p, oct=4):
    s, a, t = 0.0, 0.5, 0.0
    for k in range(oct):
        s = s + a * vnoise(p * (2 ** k))
        t += a
        a *= 0.5
    return s / t


L = norm(np.array([-0.35, 0.55, 0.78]))


def lit(n, ao, rim_k=0.25):
    """A painted light: broad top-front key, a hint of bounce, the occlusion multiplied in."""
    d = np.clip(np.sum(n * L, -1), -1, 1)
    key = smooth(-0.35, 0.75, d)
    top = np.clip(n[..., 2], 0, 1)
    return np.clip(ao, 0, 1) ** 1.15 * (0.42 + 0.46 * key + 0.16 * top)


def ramp(t, cols):
    """Colour ramp over 0..1 through evenly spaced stops."""
    c = np.array(cols)
    x = np.clip(t, 0, 0.9999) * (len(c) - 1)
    i = x.astype(int)
    f = (x - i)[..., None]
    return c[i] * (1 - f) + c[i + 1] * f


SKIN = [hexc("#2d1c22"), hexc("#4a2f31"), hexc("#694744"), hexc("#88625a"), hexc("#a98370")]
CLOTH = [hexc("#1c070d"), hexc("#340d16"), hexc("#4e1520"), hexc("#68202b"), hexc("#84333a")]
GOLD = [hexc("#6e4410"), hexc("#b57a1c"), hexc("#e6ab34"), hexc("#ffd468"), hexc("#fff0b0")]
IRON = [hexc("#1e1b1f"), hexc("#3a363a"), hexc("#5b5659"), hexc("#7f7a7b"), hexc("#b0abaa")]
RUST = hexc("#6a3a24")


def skin(p, n, ao):
    t = lit(n, ao) + (fbm(p * 60) - 0.5) * 0.06
    return ramp(t * 1.05, SKIN)


def face(p, ao):
    """The sculpt lives in the SDF: a dense normal from it, so a low patch still shows brow, furrow and bags."""
    q = (p - K.C) / K.HS
    e = 0.0012
    d0 = K.head_sdf(q)
    gx = K.head_sdf(q + [e, 0, 0]) - d0
    gy = K.head_sdf(q + [0, e, 0]) - d0
    gz = K.head_sdf(q + [0, 0, e]) - d0
    n = norm(np.stack([gx, gy, gz], -1))
    # curvature: a wider sample minus this one lights the ridges and sinks the creases
    w = 0.006
    avg = sum(K.head_sdf(q + np.array(o) * w) for o in ([1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1])) / 4 - d0
    cav = smooth(0.0, 0.0028, avg)
    ridge = smooth(0.0, 0.0022, -avg)
    t = (lit(n, np.maximum(ao, 0.9)) + 0.12) * (1 - 0.5 * cav) + 0.16 * ridge
    # the socket's deep shadow, and a scowl's line from the nose wing up to the brow
    for s in (-1.0, 1.0):
        r = np.linalg.norm((q - [s * 0.037, 0.08, 0.008]) / [0.03, 1, 0.024] * [1, 0, 1], axis=-1)
        t = t * (0.72 + 0.28 * smooth(0.65, 1.2, r))
    return ramp(t * 0.78, SKIN)


def eye(a, b):
    """a, b: the eye's flat view. Pale cold gold iris, small pupil, shaded under the lid."""
    r = np.sqrt(a * a + b * b)
    scl = mix(hexc("#b6a688"), hexc("#ded2b4"), smooth(0.0, 0.55, -b + 0.2))
    ir = ramp(smooth(0.1, 0.31, r), [hexc("#6b4c1e"), hexc("#b98f3e"), hexc("#d9b768"), hexc("#a9823a"), hexc("#4f3a1a")])
    c = mix(ir, scl, smooth(0.30, 0.335, r))
    c = mix(hexc("#0d0808"), c, smooth(0.075, 0.1, r))
    c = mix(c, hexc("#2a1a18"), smooth(0.05, 0.42, b) * 0.65)
    # the catch light
    g = np.sqrt((a + 0.07) ** 2 + (b - 0.09) ** 2)
    c = mix(c, hexc("#fff8e6"), 1 - smooth(0.022, 0.05, g))
    return c


def lid(p, n, ao):
    return ramp(np.clip(lit(n, np.maximum(ao, 0.85)) * 0.85, 0, 1), SKIN)


def cloth(p, n, ao, fold_axis=(0, 0, 1)):
    wob = fbm(p * [18, 18, 7]) - 0.5
    fold = np.sin((p[..., 0] * 26 + p[..., 1] * 26 + wob * 9.0)) * 0.5 + 0.5
    t = lit(n, ao) * 0.95 + (fold - 0.5) * 0.13 + (fbm(p * 160, 3) - 0.5) * 0.05
    return ramp(t, CLOTH)


def mask_cloth(p, n, ao):
    return cloth(p, n, np.maximum(ao, 0.8))


def cowl_cloth(p, n, ao):
    """The rolled folds: deep arcs dipping at the front, the art's heavy drape, drawn as crease and lit lip."""
    a = np.arctan2(p[..., 0], p[..., 1] - 0.01)
    fr = (0.5 + 0.5 * np.cos(a)) ** 1.4
    wob = (fbm(p * [9, 9, 3]) - 0.5) * 0.03
    t = lit(n, np.maximum(ao, 0.7)) * 0.86
    a2 = np.sin(a * 3 + 1.0) * 0.012
    for z0, dip, k in ((1.30, 0.03, 0.6), (1.262, 0.05, 1.0), (1.222, 0.09, 0.9)):
        k = k * (0.6 + 0.8 * (fbm(np.stack([a * 2, 0 * a + z0 * 9, 0 * a], -1)) ))
        d = p[..., 2] - (z0 - dip * fr + wob + a2)
        t = t - k * 0.34 * np.exp(-((d + 0.004) / 0.0065) ** 2) + k * 0.13 * np.exp(-((d - 0.01) / 0.011) ** 2)
    t = t + (fbm(p * 150, 3) - 0.5) * 0.05
    return ramp(np.clip(t, 0, 1), CLOTH)


def gold(p, n, ao):
    t = lit(n, ao) * 0.86 + (fbm(p * 34) - 0.5) * 0.3
    c = ramp(t, GOLD)
    cr = np.abs(fbm(p * 42 + 3.3) - 0.5)
    c = mix(c, hexc("#5b360c"), 1 - smooth(0.006, 0.02, cr))
    return c


def iron(p, n, ao, rusty=0.4):
    t = lit(n, ao) * 0.95 + (fbm(p * 50) - 0.5) * 0.2
    c = ramp(t, IRON)
    return mix(c, RUST, smooth(0.52, 0.7, fbm(p * 28 + 7.7)) * rusty)


def leather(p, n, ao):
    t = lit(n, ao)
    return ramp(t * 0.9, [hexc("#150b0a"), hexc("#2e1a14"), hexc("#4b2e22"), hexc("#684434"), hexc("#886150")])


def bandage(p, n, ao, axis, along):
    """Wound linen: diagonal bands across `along`."""
    band = np.sin(along * 190 + np.arctan2(p[..., 1], p[..., 0] - K.SH) * 2.0)
    edge = smooth(0.72, 0.98, band)
    t = lit(n, ao) * 1.08 - edge * 0.2 + (fbm(p * 70) - 0.5) * 0.12
    c = ramp(t, [hexc("#3d3226"), hexc("#7b6a52"), hexc("#a8977a"), hexc("#c5b698"), hexc("#ddd0b4")])
    stain = smooth(0.55, 0.72, fbm(p * 40 + 11.0))
    return mix(c, hexc("#6d3f2e"), stain * 0.5)


def hair_tile(h, w, seed=3):
    """White hair: fine strand gaps in lilac grey, darker at the root, a soft band of light. v along the lock."""
    v, u = np.mgrid[0:h, 0:w]
    u = (u + 0.5) / w
    v = (v + 0.5) / h
    q = np.stack([u * 34, v * 3.0, u * 0 + seed], -1)
    warp = (fbm(np.stack([u * 5, v * 2.0, u * 0 + 2.0], -1)) - 0.5) * 0.09
    st = np.abs(np.sin((u + warp) * np.pi * 15))
    fine = np.abs(np.sin((u + warp * 1.4) * np.pi * 43))
    t = 0.42 + 0.46 * smooth(0.05, 0.75, st) + 0.18 * (fine - 0.5)
    t -= 0.4 * (1 - smooth(0.0, 0.16, v))                  # the root in shadow
    t += 0.13 * np.exp(-((v - 0.42 - warp) / 0.11) ** 2)   # the band of light
    t *= 1 - 0.28 * (np.abs(((u * 4) % 1) * 2 - 1) ** 5)   # each sub-tile darkens to its long edges
    return ramp(np.clip(t, 0, 1), [hexc("#4f4a60"), hexc("#7f7a91"), hexc("#adaabc"), hexc("#dcdbe4"), hexc("#fbfbfd")])


def chain_tile(h, w):
    v, u = np.mgrid[0:h, 0:w]
    u = (u + 0.5) / w
    v = (v + 0.5) / h
    t = 0.32 + 0.45 * np.exp(-((u - 0.2) / 0.16) ** 2) + (fbm(np.stack([u * 9, v * 9, u * 0], -1)) - 0.5) * 0.4
    c = ramp(np.clip(t, 0, 1), IRON)
    return mix(c, RUST, smooth(0.5, 0.66, fbm(np.stack([u * 7, v * 7, u * 0 + 5], -1))) * 0.75)


def hook_tile(h, w):
    v, u = np.mgrid[0:h, 0:w]
    v = (v + 0.5) / h
    c = chain_tile(h, w)
    # red-hot toward the tip: keyed as heat by the shader (white-hot glow)
    k = smooth(0.62, 0.8, v)[..., None]
    return c * (1 - k) + np.array([1.0, 0.76, 0.44]) * k


# ---- the cracks, drawn in (theta, z) round the sword arm
def jitter_line(rng, pts, depth=4, amp=4.0):
    pts = [np.array(p, dtype=float) for p in pts]
    for d in range(depth):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            m = (a + b) / 2
            dd = b - a
            nrm = np.array([-dd[1] / 0.022, dd[0] * 0.022])
            out.append(m + nrm * rng.uniform(-0.2, 0.2) * (amp / 4.0))
            out.append(b)
        pts = out
    return np.array(pts)


# theta in degrees round the arm: 0 out, 90 front, 180 in, 270 back; z in metres. (main, width)
CRACKS = [
    ([(100, 1.20), (70, 1.14), (88, 1.07), (60, 0.99), (84, 0.93), (70, 0.87), (92, 0.825)], 1.0),
    ([(88, 1.07), (130, 1.03), (138, 0.97), (120, 0.92), (136, 0.86)], 0.8),
    ([(70, 1.14), (20, 1.11), (-20, 1.13), (-55, 1.09)], 0.9),
    ([(20, 1.11), (10, 1.03), (34, 0.97), (24, 0.90), (44, 0.83)], 0.85),
    ([(-20, 1.13), (-34, 1.05), (-14, 0.98), (-40, 0.91), (-24, 0.84)], 0.75),
    ([(60, 0.99), (34, 0.97)], 0.6),
    ([(130, 1.03), (170, 1.08), (175, 1.15)], 0.55),
    ([(84, 0.93), (120, 0.92)], 0.5),
    ([(-55, 1.09), (-100, 1.05), (-130, 0.98)], 0.55),
    ([(-14, 0.98), (24, 0.90)], 0.45),
]


def crack_map(W=1400, H=1000):
    """canvas (rows z, cols theta): 1 on a crack's heart, falling to 0 over its rim."""
    rng = np.random.RandomState(11)
    cv = np.zeros((H, W))
    z0, z1 = 0.80, 1.24
    for pts, wd in CRACKS:
        ln = jitter_line(rng, pts)
        rows = (ln[:, 1] - z0) / (z1 - z0) * (H - 1)
        cols = ((ln[:, 0] % 360) / 360.0) * W
        for i in range(len(ln) - 1):
            n = max(2, int(np.hypot(rows[i + 1] - rows[i], (cols[i + 1] - cols[i] + W / 2) % W - W / 2)))
            k = i / (len(ln) - 1)
            r = (5.0 + 8.0 * wd) * (1.0 - 0.45 * k)
            for q in np.linspace(0, 1, n):
                rr = rows[i] * (1 - q) + rows[i + 1] * q
                dc = (cols[i + 1] - cols[i] + W / 2) % W - W / 2
                cc = cols[i] + dc * q
                ir, ic = int(rr), int(cc)
                m = int(r) + 2
                for y in range(max(0, ir - m), min(H, ir + m + 1)):
                    xs = np.arange(ic - m, ic + m + 1)
                    d = np.hypot(xs - cc, y - rr) / r
                    val = np.clip(1.25 - d, 0, 1)
                    idx = xs % W
                    cv[y, idx] = np.maximum(cv[y, idx], val)
    return cv, z0, z1


def cracks(p, canvas):
    cv, z0, z1 = canvas
    H, W = cv.shape
    th = (np.degrees(np.arctan2(p[..., 1], p[..., 0] - K.SH)) % 360) / 360.0
    r = np.clip((p[..., 2] - z0) / (z1 - z0), 0, 1) * (H - 1)
    return cv[r.astype(int), (th * W).astype(int) % W]


HOT = np.array([1.0, 0.76, 0.44])        # keyed fully hot by hero_toon's glow_key
HOT_RIM = np.array([0.72, 0.42, 0.26])   # keyed partly: the edge colour


def blade_paint(a, c, h, n, ao, ol_w):
    """a along the blade from the guard, c across it: dark stone-iron facets, chipped pale edges, heat in the cracks."""
    L, W = K.BLADE_LEN, K.BLADE_W
    p = np.stack([a * 26, c * 26, h * 8 + 1.0], -1)
    # facets: nearest of a jittered lattice
    cell = np.floor(p[..., :2])
    best, sec, bid = np.full(a.shape, 9.0), np.full(a.shape, 9.0), np.zeros(a.shape)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            gx, gy = cell[..., 0] + dx, cell[..., 1] + dy
            ix, iy = gx.astype(np.int64), gy.astype(np.int64)
            jx, jy = hash3(ix, iy, 3 + 0 * ix), hash3(ix, iy, 7 + 0 * ix)
            d = np.hypot(gx + jx - p[..., 0], (gy + jy - p[..., 1]) * 0.55)
            nb = d < best
            sec = np.where(nb, best, np.minimum(sec, d))
            bid = np.where(nb, jx, bid)
            best = np.where(nb, d, best)
    t = lit(n, ao) * 0.92 + (bid - 0.5) * 0.22 + (fbm(p * 2.7) - 0.5) * 0.18
    c0 = ramp(np.clip(t, 0, 1), [hexc("#2a272c"), hexc("#494549"), hexc("#6b6668"), hexc("#918c8b"), hexc("#c0bab6")])
    seam = 1 - smooth(0.0, 0.1, sec - best)
    c0 = mix(c0, hexc("#100d10"), seam * 0.8)
    return c0

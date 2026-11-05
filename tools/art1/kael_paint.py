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


SKIN = [hexc("#2e1a1c"), hexc("#4f2e28"), hexc("#74463a"), hexc("#99654f"), hexc("#bf8a6a")]
CLOTH = [hexc("#1c070d"), hexc("#340d16"), hexc("#4e1520"), hexc("#68202b"), hexc("#84333a")]
GOLD = [hexc("#5c360c"), hexc("#99621a"), hexc("#c98a2a"), hexc("#e8b24c"), hexc("#ffe08c")]
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
    t = (lit(n, np.maximum(ao, 0.9)) + 0.12) * (1 - 0.22 * cav) + 0.14 * ridge
    # the socket's deep shadow, and a scowl's line from the nose wing up to the brow
    for s in (-1.0, 1.0):
        r = np.linalg.norm((q - [s * 0.037, 0.08, 0.008]) / [0.03, 1, 0.024] * [1, 0, 1], axis=-1)
        t = t * (0.72 + 0.28 * smooth(0.65, 1.2, r))
    c = ramp(t * 0.72, SKIN)
    # the scar: a raking cut over the left eye, brow to cheek (his left, x < 0)
    a0, b0 = np.array([-0.058, 0.082]), np.array([-0.018, -0.026])
    ab = b0 - a0
    pq = np.stack([q[..., 0], q[..., 2]], -1) - a0
    h = np.clip(pq @ ab / (ab @ ab), 0, 1)
    d = np.linalg.norm(pq - h[..., None] * ab, axis=-1)
    c = mix(c, hexc("#1a0c10"), 1 - smooth(0.0022, 0.0042, d))
    c = mix(c, hexc("#a56f64"), (1 - smooth(0.0, 0.0016, d)) * 0.8)
    return c


def eye_glow(a, b):
    """The glowing eye: a keyed-hot iris with no pupil, bleeding pale rose into the white, darker at the corners."""
    r = np.sqrt(a * a + (b * 1.1) ** 2)
    c = mix(hexc("#3b2426"), hexc("#d79c94"), 1 - smooth(0.28, 0.9, r))
    return mix(c, np.array([1.0, 0.76, 0.44]), 1 - smooth(0.2, 0.36, r))


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


def lid(p, n, ao, side, upper):
    """Lids: skin, with the dark lash line along the opening's edge and a crease above it."""
    c0 = K.hl(K.EYE * [side, 1, 1])
    q = norm(p - c0)
    az = np.arctan2(q[..., 0] * side, q[..., 1])
    el = np.arcsin(np.clip(q[..., 2], -1, 1))
    d = el - K.lid_up(az) if upper else K.lid_down(az) - el
    t = np.clip(lit(n, np.maximum(ao, 0.85)) * 0.82, 0, 1) - 0.14 * np.exp(-((d - 0.42) / 0.09) ** 2)
    c = ramp(t, SKIN)
    return mix(c, hexc("#120809"), 1 - smooth(0.05, 0.16 if upper else 0.1, d))


def cloth(p, n, ao, fold_axis=(0, 0, 1)):
    wob = fbm(p * [18, 18, 7]) - 0.5
    fold = np.sin((p[..., 0] * 26 + p[..., 1] * 26 + wob * 9.0)) * 0.5 + 0.5
    t = lit(n, ao) * 0.95 + (fold - 0.5) * 0.13 + (fbm(p * 160, 3) - 0.5) * 0.05
    return ramp(t, CLOTH)


def mask_cloth(p, n, ao):
    return cloth(p, n, np.maximum(ao, 0.8))


def embers(p, spots):
    """Burn holes: the charred lip round each spot, the keyed ember inside. spots: [(x, y, z, r)]."""
    out_k, out_h = np.zeros(p.shape[:-1]), np.zeros(p.shape[:-1])
    for x, y, z, r in spots:
        d = np.linalg.norm((p - [x, y, z]) * [1, 1, 1.5], axis=-1) / r
        w = d + (fbm(p * 90 + x * 9) - 0.5) * 0.9
        out_k = np.maximum(out_k, 1 - smooth(0.95, 1.5, w))
        out_h = np.maximum(out_h, 1 - smooth(0.7, 1.02, w))
    return out_k, out_h


EMBER = np.array([1.0, 0.76, 0.44])


def burnt(c, p, spots):
    """Char round each hole, then the ember's keyed ring right at its lip; the ring breaks up."""
    k, h = embers(p, spots)
    h = h * smooth(0.36, 0.56, fbm(p * 70 + 3.0))
    return mix(mix(c, hexc("#0d0406"), k), EMBER, h)


SILVER = [hexc("#30323a"), hexc("#5e626c"), hexc("#8f94a0"), hexc("#bfc4cc"), hexc("#e8ebef")]


def wrap_cloth(p, n, ao):
    """A wrap of the scarf: its shape is real now, so the light and occlusion do the work; a little weave."""
    t = (lit(n, ao) * 0.98) ** 1.6
    return ramp(np.clip(t, 0, 1), CLOTH)


def cowl_cloth(p, n, ao):
    """The rolled folds: deep arcs dipping at the front, the art's heavy drape, drawn as crease and lit lip."""
    a = np.arctan2(p[..., 0], p[..., 1] - 0.01)
    fr = (0.5 + 0.5 * np.cos(a)) ** 1.4
    wob = (fbm(p * [9, 9, 3]) - 0.5) * 0.03
    t = lit(n, np.maximum(ao, 0.7)) * 0.86
    a2 = np.sin(a * 3 + 1.0) * 0.012
    zc = K.C[2]
    for z0, dip, k in ((zc - 0.066, 0.008, 0.9), (zc - 0.09, 0.012, 1.0), (zc - 0.132, 0.02, 1.0), (zc - 0.17, 0.04, 0.9), (zc - 0.205, 0.05, 0.8)):
        k = k * np.clip(1.5 * fbm(np.stack([a * 2.2, 0 * a + z0 * 9, 0 * a], -1)) - 0.15, 0, 1.2)
        d = p[..., 2] - (z0 - dip * fr + wob + a2)
        t = t - k * 0.42 * np.exp(-((d + 0.003) / 0.0042) ** 2) + k * 0.16 * np.exp(-((d - 0.008) / 0.009) ** 2)
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


def grip(p, n, ao):
    """The maroon leather wrap: a diagonal band with dark seams."""
    return leather(p, n, ao) * (0.78 + 0.22 * np.sign(np.sin((p[..., 0] + p[..., 1] * 1.5 + p[..., 2]) * 120)))[..., None] * [1.25, 0.8, 0.8]


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


# ---- the cracks: a net of cells round the sword arm (the master sheet's giraffe pattern), edges of a stretched Voronoi
def crack_map(z0, z1, W=1100, H=900, cells=46):
    """canvas (rows z, cols theta): 1 on a fissure's heart, falling to 0 over its rim. Seeds on the arm's cylinder, finer toward the wrist."""
    rng = np.random.RandomState(21)
    seeds = rng.uniform(0, 1, (cells, 2))
    seeds[:, 1] = seeds[:, 1] ** 1.15
    ys, xs = np.mgrid[0:H, 0:W]
    u, v = xs / W, ys / H
    wob = (fbm(np.stack([u * 7, v * 7, u * 0 + 1], -1)) - 0.5) * 0.05
    wob2 = (fbm(np.stack([u * 7, v * 7, u * 0 + 9], -1)) - 0.5) * 0.05
    uu, vv = u + wob, v + wob2
    d1, d2 = np.full(u.shape, 9.0), np.full(u.shape, 9.0)
    for sx, sy in seeds:
        for off in (-1, 0, 1):
            d = np.hypot((uu - sx - off) * 1.0, (vv - sy) * 0.8)
            d2 = np.where(d < d1, d1, np.minimum(d2, d))
            d1 = np.minimum(d1, d)
    edge = (d2 - d1)
    fade = 0.55 + 0.45 * np.sin(u * 37 + v * 23)          # the width swells and pinches along a fissure
    wd = 0.0066 * (0.55 + 0.45 * fade)
    return np.clip(1.25 - edge / wd, 0, 1), z0, z1


def cracks(p, canvas, cx):
    cv, z0, z1 = canvas
    H, W = cv.shape
    th = (np.degrees(np.arctan2(p[..., 1], p[..., 0] - cx)) % 360) / 360.0
    r = np.clip((p[..., 2] - z0) / (z1 - z0), 0, 1) * (H - 1)
    return cv[r.astype(int), (th * W).astype(int) % W]


HOT = np.array([1.0, 0.76, 0.44])        # keyed fully hot by hero_toon's glow_key
HOT_RIM = np.array([0.72, 0.42, 0.26])   # keyed partly: the edge colour


def blade_paint(a, c, h, n, ao, ol_w):
    """Pale chipped stone in big facets, light on the chipped rims, warm toward the core: stone lit from inside, no stripes."""
    L, W = K.BLADE_LEN, K.BLADE_W
    p = np.stack([a * 13, c * 13, h * 4 + 1.0], -1)
    cell = np.floor(p[..., :2])
    best, sec, bid = np.full(a.shape, 9.0), np.full(a.shape, 9.0), np.zeros(a.shape)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            gx, gy = cell[..., 0] + dx, cell[..., 1] + dy
            ix, iy = gx.astype(np.int64), gy.astype(np.int64)
            jx, jy = hash3(ix, iy, 3 + 0 * ix), hash3(ix, iy, 7 + 0 * ix)
            d = np.hypot(gx + jx - p[..., 0], gy + jy - p[..., 1])
            nb = d < best
            sec = np.where(nb, best, np.minimum(sec, d))
            bid = np.where(nb, jx, bid)
            best = np.where(nb, d, best)
    u = np.abs(c) / W
    t = 0.46 + (bid - 0.5) * 0.3 + (lit(n, ao) - 0.5) * 0.5 + 0.24 * smooth(0.72, 1.0, u)
    c0 = ramp(np.clip(t, 0, 1), [hexc("#2e282a"), hexc("#544c4c"), hexc("#7a716e"), hexc("#a59b95"), hexc("#ddd4ca")])
    c0 = mix(c0, hexc("#2a2224"), (1 - smooth(0.0, 0.07, sec - best)) * 0.65)
    return mix(c0, hexc("#d98a4a"), smooth(0.62, 0.34, u) * 0.8 * smooth(0.97, 0.8, a / L))

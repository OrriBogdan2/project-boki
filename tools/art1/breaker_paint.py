"""Breaker's paint (ART-1): colour per texel on the sculpt's own surface. The toon shader adds soft light on top, so
the sculpt's form, cavities and frost are painted in, the way the concept art is."""
import numpy as np

import breaker_sculpt as B
import sculpt_kit as S
from sculpt_kit import fbm, smooth, vnoise, worley

C = lambda h: np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def raster_aux(uv, pos, nrm, aux, size):
    out = {"p": np.zeros((size, size, 3), np.float32), "n": np.zeros((size, size, 3), np.float32),
           "id": np.full((size, size), -1, np.int16), "a": np.zeros((size, size, 2), np.float32)}
    uvp = uv * size - 0.5
    for t in range(len(uvp)):
        a, b, c = uvp[t]
        lo = np.floor(np.minimum(np.minimum(a, b), c) - 1).astype(int)
        hi = np.ceil(np.maximum(np.maximum(a, b), c) + 1).astype(int)
        x0, y0, x1, y1 = max(lo[0], 0), max(lo[1], 0), min(hi[0], size - 1), min(hi[1], size - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1, dtype=np.float32), np.arange(y0, y1 + 1, dtype=np.float32))
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9:
            continue
        w0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        w1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        iy, ix = gy[m].astype(int), gx[m].astype(int)
        W = np.stack([w0[m], w1[m], w2[m]], 1)
        out["p"][iy, ix] = W @ pos[t]
        out["n"][iy, ix] = W @ nrm[t]
        out["a"][iy, ix] = W @ aux[t]
        out["id"][iy, ix] = 1
    return out


def form(f, p, n, steps=(0.012, 0.035, 0.09), wide=5.0):
    """(ao 0..1, curvature): the sculpt's occlusion along the normal, and how convex it is here."""
    ao = np.ones(len(p), np.float32)
    w = 1.0
    occ = np.zeros(len(p), np.float32)
    for s in steps:
        d = f.sample(p + n * s)
        occ += w * np.clip(1.0 - d / s, 0, 1)
        w *= 0.7
    ao = 1.0 - occ / (1 + 0.7 + 0.49)
    e = f.vox * 2.5
    lap = -6.0 * f.sample(p)
    for i in range(3):
        o = np.zeros(3, np.float32)
        o[i] = e
        lap += f.sample(p + o) + f.sample(p - o)
    e2 = e * wide
    lap2 = -6.0 * f.sample(p)
    for i in range(3):
        o = np.zeros(3, np.float32)
        o[i] = e2
        lap2 += f.sample(p + o) + f.sample(p - o)
    return ao, np.clip(lap / e, -1.5, 1.0) + 0.6 * np.clip(lap2 / e2, -1.0, 0.7) * (wide > 1.5)


def shade(col, ao, curv, n, cav=0.55, hi=0.28, tint=(0.62, 0.68, 0.92)):
    """Painted light: cool occlusion in the creases, a lit top, a pale edge on what bulges."""
    t = np.array(tint, np.float32)
    k = smooth(0.25, 0.86, ao)[:, None]
    out = col * (t * 0.55 + (1 - (t * 0.55)) * k)
    top = 0.5 + 0.5 * n[:, 2:3]
    out = out * (0.86 + 0.26 * top)
    out = out * (1.0 - cav * smooth(-0.1, -0.6, curv))[:, None] if False else out
    c = curv[:, None]
    out = out * (1.0 - cav * np.clip(c * 1.3, 0, 1))        # (positive laplacian: a crease)
    out = out + (out * 0.5 + 0.06) * hi * np.clip(-c * 1.0, 0, 1)
    return out


def mix(a, b, m):
    m = np.asarray(m, np.float32)
    if m.ndim == 1:
        m = m[:, None]
    return a * (1 - m) + b * m


def cracks(p, f=6.5, w=0.03):
    """Frost cracks: a dark line between plates, patchy."""
    d1, e = worley(p[:, 0] + 0.6 * (vnoise(p[:, 0], p[:, 1], p[:, 2], 9.0) - 0.5) * 0.3, p[:, 1], p[:, 2], f)
    line = smooth(w, w * 0.25, e)
    patch = smooth(0.42, 0.62, fbm(p[:, 0] + 3, p[:, 1], p[:, 2], 2.6, 2))
    return line * patch


def skin_col(p, n, c0=None):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    base = C("6f9cc4")[None, :] * np.ones((len(p), 1), np.float32)
    # the big colour moves: paler toward light, deeper on the sides, mauve on the joints
    big = fbm(x, y, z, 3.1, 3)[:, None]
    base = mix(base, C("4f7cb0"), np.clip((big - 0.42) * 2.6, 0, 1) * 0.6)
    base = mix(base, C("9ec6e2"), smooth(0.45, 0.68, fbm(x + 7, y, z, 5.0, 3)) * 0.4)
    # frost dust
    dust = smooth(0.62, 0.8, fbm(x, y, z + 3, 22.0, 3)) * smooth(0.45, 0.62, fbm(x, y - 4, z, 3.0, 2))
    base = mix(base, C("dcecf6"), dust * 0.6)
    return base


def p_skin(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n)
    lab = f.label(p)
    col = skin_col(p, n)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    # mauve flush at the knuckles, elbows, knees, toes
    fl = np.maximum.reduce([smooth(0.06, 0.0, np.abs(z - 0.46)) * (np.abs(x) > 0.3), smooth(0.11, 0.03, np.abs(z - 0.32)) * (np.abs(x) < 0.3),
                            smooth(0.16, 0.08, z) * (y > 0.12)])
    col = mix(col, C("8a7fb2"), fl * 0.5)
    # the belly a shade paler
    col = mix(col, C("7fb0d6"), (lab == B.BELLY) * 0.3)
    crk = cracks(p, 5.0, 0.022)
    col = mix(col, C("2a4a7a"), crk * 0.8)
    edge = cracks(p + n * 0.0, 6.5, 0.07) - crk
    col = mix(col, C("a8d0ea"), np.clip(edge, 0, 1) * 0.35)
    col = shade(col, ao, cv, n)
    col = mix(col, C("c9c6cf"), (lab == B.NAIL) * 0.9)
    bl = (lab == B.BARN)
    if bl.any():
        col = np.where(bl[:, None], shade(C("c8bfa8") * np.ones((len(p), 1), np.float32) * (0.8 + 0.4 * fbm(x, y, z, 80.0, 2))[:, None], ao, cv * 1.5, n, 0.8), col)
    return col


def p_head(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.004, 0.012, 0.03), 3.5)
    cv = cv * 0.9
    lab = f.label(p)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = skin_col(p, n)
    ax = np.abs(x)
    # the face's warmth: mauve round the eyes, cheeks and ears, a rosy nose
    socket = np.exp(-(((ax - 0.056) / 0.05) ** 2 + ((z - 1.45) / 0.03) ** 2)) * (y > 0.08)
    col = mix(col, C("56609a"), socket * 0.55)
    cheek = np.exp(-(((ax - 0.085) / 0.04) ** 2 + ((z - 1.4) / 0.028) ** 2)) * (y > 0.08)
    col = mix(col, C("9c82b4"), cheek * 0.4)
    # crow's feet and forehead lines
    fore = smooth(1.5, 1.49, z) * smooth(1.482, 1.495, z) * (y > 0.06)
    wr = np.sin(z * 620.0 + (x * 22.0) ** 2) * 0.5 + 0.5
    col = mix(col, C("2f4a80"), (smooth(0.75, 1.0, wr) * smooth(1.53, 1.51, z) * smooth(1.488, 1.5, z) * (y > 0.05) * smooth(0.11, 0.05, ax)) * 0.5)
    crk = cracks(p, 9.0, 0.03) * smooth(1.45, 1.5, z)
    col = mix(col, C("2a4a7a"), crk * 0.85)
    col = shade(col, ao, cv, n, 0.6, 0.42)
    # lips, gums, teeth, tusks, nose, inner ears, lids
    ones = np.ones((len(p), 1), np.float32)
    col = np.where((lab == B.LIP)[:, None], shade(C("7c5f9c") * ones, ao, cv, n, 0.5, 0.5), col)
    col = np.where((lab == B.GUM)[:, None], shade(C("6a1c28") * ones, ao * 0.6, cv * 0.3, n, 0.2, 0.1), col)
    tt = C("ecdcb2") * ones * (0.9 + 0.2 * vnoise(x, y, z, 120.0))[:, None]
    tt = mix(tt, C("a8855a"), smooth(0.4, 0.15, ao) * 0.5)
    col = np.where((lab == B.TOOTH)[:, None], shade(tt, 0.55 + 0.45 * ao, cv * 0.5, n, 0.6, 0.5), col)
    tu = mix(C("f0e3bf") * ones, C("b89a6e"), smooth(1.4, 1.34, z))
    col = np.where((lab == B.TUSK)[:, None], shade(tu, ao, cv * 0.4, n, 0.3, 0.6), col)
    nose = mix(C("b18aa8") * ones, C("6e7fb8"), smooth(1.4, 1.46, z))
    col = np.where((lab == B.NOSE)[:, None], shade(nose, ao, cv, n, 0.55, 0.4), col)
    col = np.where((lab == B.EAR_IN)[:, None], shade(C("8d5f8c") * ones, ao, cv, n), col)
    lid = C("6e8ec2") * ones
    col = np.where((lab == B.LID)[:, None], shade(lid, ao, cv, n, 0.5, 0.4), col)
    barn = C("c8bfa8") * ones * (0.85 + 0.4 * fbm(x, y, z, 160.0, 2))[:, None]
    col = np.where((lab == B.BARN)[:, None], shade(barn, ao, cv * 1.2, n, 0.8, 0.3), col)
    return col


def p_mantle(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.01, 0.025), 1.0)
    a2, _ = form(c["f2"], p, n, (0.05, 0.1), 1.0)
    lab = f.label(p)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    base = mix(C("cfbf9a"), C("a8987a"), fbm(x, y, z, 9.0, 3)[:, None] * 1.1)
    stain = smooth(0.5, 0.66, fbm(x + 2, y, z, 4.0, 3))
    base = mix(base, C("84745e"), stain * 0.65)
    weave = 0.96 + 0.08 * np.sin(x * 900.0) * np.sin(z * 900.0)
    base = base * weave[:, None]
    # stitches, a few: short dark bars
    st = smooth(0.0035, 0.0015, np.abs(((z * 30.0 + 0.5) % 1.0 - 0.5) / 30.0)) * smooth(0.012, 0.009, np.abs(x + 0.28 + 0.2 * (z - 1.05))) * (y > 0) * (np.abs(z - 1.04) < 0.09)
    base = mix(base, C("3a2c20"), st * 0.9)
    frost = smooth(0.55, 0.75, fbm(x, y, z, 15.0, 3)) * smooth(1.05, 1.2, z + 0.2 * (fbm(x, y, z, 5.0, 2) - 0.5))
    base = mix(base, C("eef6fb"), frost * 0.45)
    fur = C("8a7458") * (0.7 + 0.8 * vnoise(x * 2.4, y * 2.4, z * 0.5, 64.0))[:, None]
    fur = mix(fur, C("cfd8dc"), smooth(0.55, 0.8, fbm(x, y, z, 30.0, 2)) * 0.35)
    col = np.where((lab == 2)[:, None], fur, base)
    return shade(col, ao * (0.6 + 0.4 * a2), cv * 0.5, n, 0.5, 0.3, (0.7, 0.68, 0.8))


def p_shorts(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.01, 0.025), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("6a7050"), C("454a38"), fbm(x, y, z, 7.0, 3)[:, None] * 1.2)
    col = mix(col, C("9aa08a"), smooth(0.56, 0.75, fbm(x, y, z, 20.0, 3)) * 0.4)
    return shade(col, ao, cv * 0.5, n, 0.4, 0.2, (0.7, 0.7, 0.8))


def p_rag(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.01, 0.025), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("9a8a68"), C("6a5a44"), fbm(x, y, z, 7.0, 3)[:, None] * 1.1)
    col = mix(col, C("4a3e30"), smooth(0.4, 0.3, z) * 0.45)
    return shade(col, ao, cv * 0.5, n, 0.45, 0.22, (0.7, 0.68, 0.8))


def p_beard(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.004, 0.012, 0.03), 3.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    st = vnoise(x * 3.0, y * 3.0, z * 0.3, 200.0)
    col = mix(C("d8552a"), C("8c2b18"), st[:, None] * 1.2)
    col = mix(col, C("f08a4e"), smooth(0.6, 0.85, vnoise(x * 3.0, y * 3.0, z * 0.5, 90.0)) * 0.55)
    # frost glints along the locks
    g = smooth(0.73, 0.82, fbm(x, y, z * 0.35, 46.0, 2))
    col = mix(col, C("dff4ff"), g * 0.8)
    lab = f.label(p)
    tuft = (lab == 2)
    col = np.where(tuft[:, None], mix(col, C("cdeeff"), smooth(1.07, 0.99, z) * 0.0 + smooth(0.05, 0.0, z - np.minimum(z, 1.03)) * 0.7), col)
    return shade(col, ao, cv * 0.8, n, 0.7, 0.5, (0.6, 0.35, 0.45))


def p_ice(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.004, 0.012))
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    fac = 0.5 + 0.5 * n[:, 2:3]
    col = mix(C("9fd8f2"), C("e8fbff"), fac * 0.9)
    col = mix(col, C("ffffff"), smooth(0.4, 0.8, 1 - np.abs(n[:, 1:2])) * 0.2)
    return col * (0.82 + 0.2 * ao[:, None])


def p_hammer_ice(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.006, 0.016, 0.04))
    lab = f.label(p)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    # deep blue inside, pale at the edges and in the white fracture planes
    deep = fbm(x, y, z, 5.0, 3)[:, None]
    col = mix(C("9fd2ea"), C("5aa6d2"), np.clip((deep - 0.3) * 2.2, 0, 1))
    d1, e = worley(x * 0.7, y, z, 7.0)
    col = mix(col, C("f0fbff"), smooth(0.05, 0.012, e) * 0.9)
    d2, e2 = worley(x + 2, y * 0.8, z, 15.0)
    col = mix(col, C("d6f2fb"), smooth(0.04, 0.01, e2) * 0.45)
    # the worn pale bevels
    bev = np.clip(-cv * 0.5, 0, 1)
    col = mix(col, C("f6feff"), bev * 0.85)
    snow = (lab == 3)
    col = np.where(snow[:, None], mix(C("ffffff"), C("d9eef7"), vnoise(x, y, z, 60.0)[:, None]), col)
    col = np.where((lab == 2)[:, None], mix(C("b6e6f8"), C("f2fdff"), 0.5 + 0.5 * n[:, 2:3]), col)
    return col * (0.84 + 0.18 * ao[:, None])


def p_iron(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.005, 0.014, 0.03), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    lab = f.label(p)
    col = mix(C("6a6a72"), C("3e3f48"), fbm(x, y, z, 14.0, 3)[:, None] * 1.1)
    rust = smooth(0.46, 0.62, fbm(x + 5, y, z, 11.0, 4))
    col = mix(col, C("8a4526"), rust * 0.85)
    col = mix(col, C("b4693a"), smooth(0.6, 0.72, fbm(x, y + 3, z, 26.0, 2)) * rust * 0.6)
    col = mix(col, C("aab0ba"), (lab == 2) * 0.55)
    return shade(col, ao, cv * 0.8, n, 0.6, 0.9, (0.65, 0.6, 0.7))


def p_wood(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.01, 0.025), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    g = vnoise(x * 3.5, y * 3.5, z * 0.22, 60.0)[:, None]
    col = mix(C("9a7a50"), C("4e3a26"), g * 1.2)
    lab = f.label(p)
    rope = mix(C("d8c08e"), C("8a7048"), (0.5 + 0.5 * np.sin((z + np.arctan2(y, x) * 0.012) * 520.0))[:, None])
    col = np.where((lab == 2)[:, None], rope, col)
    return shade(col, ao, cv * 0.5, n, 0.5, 0.3, (0.7, 0.6, 0.65))


def p_shield(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.006, 0.018, 0.045), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    lab = f.label(p)
    # planks: vertical, each its own tone, dark seams
    pw = 0.092
    px = (x + 0.46 + 0.012 * np.sin(z * 4.0)) / pw
    pid = np.floor(px)
    seam = smooth(0.06, 0.02, np.abs(px - np.round(px)))
    tone = vnoise(pid * 7.3, pid * 2.1, pid * 0.7, 1.0)
    g = vnoise(x * 4.0 + pid, y * 3.0, z * 0.32, 52.0)
    col = mix(C("8a5e3a"), C("53361f"), (0.35 * tone + 0.8 * g)[:, None])
    col = mix(col, C("2a1a10"), seam * 0.9)
    frost = smooth(0.55, 0.72, fbm(x, y, z, 12.0, 3))
    col = mix(col, C("cfe0ea"), frost * 0.4)
    # the carved head is paler, weathered driftwood grey
    st = C("a29c92") * (0.8 + 0.4 * vnoise(x * 3.0, y, z * 0.6, 120.0))[:, None]
    col = np.where((lab == 2)[:, None], st, col)
    # snow on the broken planks' tops
    top = z > 0.3
    col = np.where((top & (n[:, 2] > 0.3))[:, None], C("f4fbff") * np.ones((len(p), 1), np.float32), col)
    return shade(col, ao, cv * 0.8, n, 0.7, 0.6, (0.7, 0.62, 0.66))


def p_rope(p, n, c):
    a = c["aux"]
    col = mix(C("cdb486"), C("7e6640"), (0.5 + 0.5 * np.sin((a[:, 0] * 210.0 + a[:, 1] * 6.283 * 2.0)))[:, None] ** 3)
    dk = (0.5 + 0.5 * np.sin(a[:, 1] * 6.283 + 1.0))[:, None]
    col = col * (0.72 + 0.4 * dk)
    return col


def p_kelp(p, n, c):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    return mix(C("8c8a30"), C("4e5420"), fbm(x, y, z, 25.0, 2)[:, None] * 1.2)


def p_teddy(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.003, 0.009, 0.02))
    lab = f.label(p)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("b87a3e"), C("8a5426"), vnoise(x, y, z, 220.0)[:, None] * 1.1)
    col = np.where((lab == 2)[:, None], C("d9b07a") * np.ones((len(p), 1), np.float32), col)
    col = np.where((lab == 3)[:, None], C("1c120e") * np.ones((len(p), 1), np.float32), col)
    return shade(col, ao, cv * 0.5, n, 0.5, 0.3, (0.7, 0.55, 0.5))


def p_compass(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.002, 0.006))
    lab = f.label(p)
    q = p - c["part"]["centre"]
    nn = c["part"]["normal"]
    up = np.array((0, 0, 1), np.float32)
    up = up - nn * (up @ nn)
    up /= np.linalg.norm(up)
    rt = np.cross(up, nn)
    u, v = q @ rt, q @ up
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(u, v)
    ones = np.ones((len(p), 1), np.float32)
    col = mix(C("d8b45a"), C("8e6a2a"), vnoise(p[:, 0], p[:, 1], p[:, 2], 90.0)[:, None] * 1.1)
    col = shade(col, ao, cv * 0.5, n, 0.7, 1.2, (0.8, 0.6, 0.45))
    face = C("c9bea0") * ones
    # the rose: a four-point star, the north half red
    st = r - (0.008 + 0.034 * np.abs(np.cos(ang * 2.0)) ** 6)
    star = smooth(0.0015, -0.0015, st)
    tint = np.where((v > 0)[:, None], C("c23a2a") * ones, C("2c3c60") * ones)
    face = mix(face, tint, star)
    ringm = smooth(0.0015, 0.0, np.abs(r - 0.04))
    face = mix(face, C("6a5030"), ringm)
    return np.where((lab == 2)[:, None] & (r < 0.047)[:, None], face, col)


def p_ring(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.002, 0.006))
    col = mix(C("e8eef2"), C("7a8894"), 0.5 - 0.5 * n[:, 2:3] + (0.4 * vnoise(p[:, 0], p[:, 1], p[:, 2], 70.0))[:, None])
    return shade(col, ao, cv * 0.3, n, 0.4, 0.8, (0.7, 0.75, 0.85))


def p_eyes(p, n, c):
    return C("f4fbff") * np.ones((len(p), 1), np.float32)


TABLE = {"skin": p_skin, "head": p_head, "mantle": p_mantle, "shorts": p_shorts, "rag": p_rag, "beard": p_beard, "ice": p_ice,
         "kelp": p_kelp, "teddy": p_teddy, "compass": p_compass, "hammer_ice": p_hammer_ice, "iron": p_iron, "wood": p_wood,
         "shield": p_shield, "ring": p_ring, "eyes": p_eyes, "rope": p_rope}


def paint(name, p, n, ctx):
    return np.clip(TABLE[name](p, n, ctx), 0, 1)

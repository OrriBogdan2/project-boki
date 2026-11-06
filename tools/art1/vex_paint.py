"""ART-1 Vex: the texel-space paint of the rebuilt pieces (see kael_paint.py): arrays of texels in, sRGB out."""
import os, sys
import numpy as np
from meshkit import norm, smooth
from paintkit import hexc, mix, fbm, lit, ramp, vnoise
import vex_cannon as VC
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import imgio

DEC = os.path.expanduser("~/meshy/vex_f/decals/")
OLIVE = [hexc("#23261c"), hexc("#3c4232"), hexc("#5b6249"), hexc("#7f8668"), hexc("#a7ab8c")]
STEEL = [hexc("#222329"), hexc("#3f4148"), hexc("#61636c"), hexc("#868992"), hexc("#b0b3ba")]
CHROME = [hexc("#30333a"), hexc("#5f646f"), hexc("#8f95a1"), hexc("#bfc4ce"), hexc("#e8ebf0")]
BLACKM = [hexc("#141417"), hexc("#26262b"), hexc("#3b3b42"), hexc("#585862"), hexc("#7a7a86")]
BRASS = [hexc("#4a3512"), hexc("#7d5c1e"), hexc("#b4892f"), hexc("#dcb654"), hexc("#f7e29a")]
KEY = np.array([1.0, 0.76, 0.44])        # the shader's glow key
CIRCUIT = np.array([0.298, 0.765, 0.369])  # warden_look skin paint_glow_color


def _decal(name):
    return imgio.load(DEC + name + ".png")


def sample(img, u, v):
    h, w = img.shape[:2]
    x = np.clip((u * (w - 1)).astype(int), 0, w - 1)
    y = np.clip(((1 - v) * (h - 1)).astype(int), 0, h - 1)
    return img[y, x]


def scs(p):
    """World rest -> cannon space (s, u, f)."""
    E = VC.E
    return -(p[..., 2] - E[2]), p[..., 0] - E[0] - VC.OUT, p[..., 1] - E[1]


def scuff(p, c):
    n = fbm(p * 55 + 3.0)
    edge = smooth(0.58, 0.72, n)
    return c * (1 - 0.18 * edge[..., None])


def steel(p, n, ao, cols=STEEL):
    return scuff(p, ramp(np.clip(lit(n, ao) * 1.05 + (fbm(p * 30) - .5) * .18, 0, 1), cols))


def chrome(p, n, ao):
    # a hard band of sky reflected: reads polished
    h = 0.5 + 0.5 * n[..., 2]
    t = lit(n, ao) * 0.9 + 0.22 * np.sin(h * 9.0 + n[..., 1] * 3) * smooth(.1, .5, h)
    return ramp(np.clip(t, 0, 1), CHROME)


def brass(p, n, ao):
    return scuff(p, ramp(np.clip(lit(n, ao) * 1.08 + (fbm(p * 24) - .5) * .16, 0, 1), BRASS))


def sleeve(p, n, ao):
    s, u, f = scs(p)
    c = steel(p, n, ao, OLIVE)
    rd = np.sqrt(u ** 2 + (f - VC.SLEEVE_F) ** 2)
    outer = rd > 0.071
    bandb = ((s > -0.262) & (s < -0.13) & (rd > .074) & ~((s > -0.25) & (s < -0.165))) | ((s > 0.1) & (s < 0.14) & (rd > .074))
    c = np.where(bandb[..., None], brass(p, n, ao), c)
    capm = (s < -0.26) | (s > 0.175)
    c = np.where(capm[..., None], steel(p, n, ao), c)
    # hazard tape round the sleeve, near the mouth
    haz = (s > 0.145) & (s < 0.175) & (rd > 0.06)
    th = np.arctan2(u, f - VC.SLEEVE_F)
    st = np.sin((s * 90 + th * 5)) > 0
    hz = np.where(st[..., None], hexc("#e7b61c") * (0.55 + 0.6 * lit(n, ao))[..., None], hexc("#171512") + 0 * c)
    c = np.where(haz[..., None], hz, c)
    # the skull and the kill tallies on the outer face
    T = _decal("skulltally")
    tv = (s - (-0.13)) / 0.232
    tu = 0.5 + (f - VC.SLEEVE_F) / 0.115
    m2 = (tu > 0) & (tu < 1) & (tv > 0) & (tv < 1) & (u > 0.03)
    tc = sample(T, tu, 1 - tv)
    grn = (tc[..., 1] > tc[..., 0] * 1.3) & (tc[..., 1] > 0.42)
    wht = tc.min(-1) > 0.62
    dark = tc.max(-1) < 0.16
    c = np.where((m2 & grn)[..., None], np.array([0.45, 1.0, 0.28]) * (0.72 + 0.4 * lit(n, ao))[..., None], c)
    c = np.where((m2 & wht)[..., None], np.array([0.96, 0.96, 0.92]) * (0.8 + 0.3 * lit(n, ao))[..., None], c)
    c = np.where((m2 & dark & (tv < 0.32))[..., None], np.array([0.04, 0.09, 0.04]), c)
    return c


def tube(p, n, ao):
    s, u, f = scs(p)
    c = steel(p, n, ao, OLIVE)
    # duct tape: grey wraps; hazard tape in the middle
    w1 = (s > -0.46) & (s < -0.425)
    w2 = (s > -0.185) & (s < -0.15)
    w3 = (s > -0.37) & (s < -0.335)
    wave = np.sin((s + f * .4) * 240) > 0
    tp = ramp(np.clip(lit(n, ao) * 1.2, 0, 1), [hexc("#5a574e"), hexc("#7a776d"), hexc("#98958a"), hexc("#b3b0a5"), hexc("#c9c6bb")]) * (0.9 + 0.1 * wave[..., None])
    c = np.where((w1 | w3)[..., None], tp, c)
    hz = np.where((np.sin((s + u * 1.5) * 120) > 0)[..., None], hexc("#e7b61c") * (0.55 + 0.6 * lit(n, ao))[..., None], hexc("#171512") + 0 * c)
    return np.where(w2[..., None], hz, c)


def rivets(p, n, ao, c, sp=0.032, r=0.0065):
    q = p * [0, 1, 1] + p[..., [0]] * [[0, 1, 0]]
    gy, gz = q[..., 1] / sp, q[..., 2] / sp
    fy, fz = gy - np.round(gy), gz - np.round(gz)
    d = np.sqrt(fy ** 2 + fz ** 2) * sp
    dots = 1 - smooth(r * .7, r, d)
    return mix(c, ramp(np.clip(lit(n, ao) * 1.25, 0, 1), STEEL), dots) * (1 - 0.3 * (smooth(r, r * 1.5, d) * (1 - smooth(r * 1.5, r * 2.1, d)))[..., None])


def plate(p, n, ao):
    return rivets(p, n, ao, steel(p, n, ao))


def poster_paint(pos, nor, ao):
    """The poster's art by its place on the sleeve."""
    img = _decal("poster")
    s, u, f = scs(pos)
    pv = (s + 0.125) / 0.217
    pu = 0.5 - np.arcsin(np.clip(u / (VC.SLEEVE_R + 0.0035), -1, 1)) / (2 * 0.78)
    c = sample(img, np.clip(pu, 0.02, 0.98), np.clip(1 - pv, 0.02, 0.98))
    return c * (0.82 + 0.3 * lit(nor, ao))[..., None]


def plate_paint(p, n, ao):
    c = chrome(p, n, ao)
    w = 0.092 - 0.05 * smooth(0.45, 0.8, (VC.J("upper_arm.R")[2] - 0.03 - p[..., 2]) / 0.13)
    e = np.abs(p[..., 0]) / w
    c = np.where((e > 0.9)[..., None], brass(p, n, ao), c)
    return np.where((np.abs(p[..., 0]) < 0.0022)[..., None], CIRCUIT + 0 * c, c)


def belt_tile(h, w):
    """u round the cartridge (1 lit crest .. 0 edge), v along it: the link strip at the base, brass case, copper nose."""
    v, u = np.mgrid[0:h, 0:w]
    u, v = (u + .5) / w, (v + .5) / h
    shade = np.clip(0.2 + 0.85 * u ** 1.2, 0, 1)
    c = ramp(shade, BRASS)
    nose = v > 0.76
    c = np.where(nose[..., None], ramp(shade, [hexc("#3a1f0d"), hexc("#73401c"), hexc("#a96533"), hexc("#d49358"), hexc("#f0c79a")]), c)
    c = np.where((v < 0.21)[..., None], ramp(shade * .6, BLACKM), c)
    return c


def hair_tile(h, w):
    v, u = np.mgrid[0:h, 0:w]
    u, v = (u + 0.5) / w, (v + 0.5) / h
    warp = (fbm(np.stack([u * 5, v * 2.0, u * 0 + 2.0], -1)) - 0.5) * 0.09
    st = np.abs(np.sin((u + warp) * np.pi * 15))
    fine = np.abs(np.sin((u + warp * 1.4) * np.pi * 43))
    t = 0.40 + 0.44 * smooth(0.05, 0.75, st) + 0.16 * (fine - 0.5)
    t -= 0.34 * (1 - smooth(0.0, 0.2, v))
    t += 0.2 * np.exp(-((v - 0.38 - warp) / 0.12) ** 2)
    t *= 1 - 0.26 * (np.abs(((u * 4) % 1) * 2 - 1) ** 5)
    return ramp(np.clip(t, 0, 1), [hexc("#0c3a1a"), hexc("#10652c"), hexc("#1a913f"), hexc("#46c464"), hexc("#b4f2a0")])


def eye_tile(h, w):
    """The natural green eye."""
    v, u = np.mgrid[0:h, 0:w]
    a, b = (u + .5) / w * 2 - 1, ((v + .5) / h - .5) * 1.5
    c = ramp(np.clip(0.8 - 0.3 * b, 0, 1), [hexc("#b9b4ae"), hexc("#e4dfd8"), hexc("#f6f2ec")])
    r = np.sqrt((a * 1.0) ** 2 + (b * 1.05) ** 2)
    iris = ramp(np.clip(r / 0.46 + 0.1 * np.sin(np.arctan2(b, a) * 24), 0, 1), [hexc("#e6e8a0"), hexc("#c0cf78"), hexc("#7f9a48"), hexc("#34482a")])
    c = np.where((r < .48)[..., None], iris, c)
    c = np.where((r < .2)[..., None], hexc("#0c0f0c") + 0 * c, c)
    c = np.where((np.hypot(a + .1, b - .12) < .075)[..., None], np.ones(3) + 0 * c, c)
    return c


def lid_paint(p, n, ao, skin, up, k):
    """Skin with smoky shadow toward the lash, the liner on the edge."""
    c = skin
    t = k
    dark = hexc("#1b1518")
    shadow = hexc("#5a3f4c")
    c = mix(c, shadow, smooth(0.65, 0.2, t) * 0.75)
    return mix(c, dark, smooth(0.3, 0.05, t))


def apply_face(pos, col, H):
    """Over the scan's face paint: the dark eye plate round her right eye with panel lines, the left eye's smoky liner and wing, stronger lips, the cheek circuit."""
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]
    ex, ez = H.EYE_X * H.SK * 0.95, H.EYE_Z
    front = y > H.HC[1]
    # the plate: a rounded shield from the brow to the cheek, out to the temple
    r = np.sqrt(((x - ex - 0.012) / 0.066) ** 2 + ((z - ez + 0.006) / 0.056) ** 2)
    plate = (r < 1.0) & front
    pc = ramp(np.clip(0.3 + 0.25 * fbm(pos * 60), 0, 1), BLACKM)
    edge = (r > 0.9) & (r < 1.0)
    col = np.where(plate[..., None], pc, col)
    col = np.where((edge & front)[..., None], ramp(np.full(x.shape, .55), BRASS), col)
    # (a cheek seam, a circuit line)
    seam = (np.abs((z - (ez - 0.06)) + (x - ex) * 0.5) < 0.0016) & (x > ex - 0.03) & (x < ex + 0.05) & front
    col = np.where(seam[..., None], CIRCUIT + 0 * col, col)
    return col
    # left eye: smoky shadow, the wing out past the corner
    lx = -ex
    dx, dz = (x - lx) * -1, z - ez                   # dx > 0 is outward
    sm = np.exp(-((dx / 0.05) ** 2 + ((dz - 0.006) / 0.03) ** 2)) * front * (x < 0)
    col = mix(col, hexc("#46303c"), np.clip(sm * 0.9, 0, 0.8))
    ly = 0.32 * dx + 0.016
    wing = (dx > 0.016) & (dx < 0.052) & (np.abs(dz - ly * 0.62 - 0.003) < 0.0042 * (1.0 - (dx - .016) / .038) + .0006) & front & (x < 0)
    col = np.where(wing[..., None], hexc("#120d10") + 0 * col, col)
    return col


SKIN_R = [hexc("#8a5560"), hexc("#b87a7c"), hexc("#d69a96"), hexc("#ebbcae"), hexc("#fad8c8")]


def goggle_lens(p, n, ao):
    t = np.clip(0.5 + 0.5 * n[..., 0] + 0.3 * n[..., 2], 0, 1)
    c = ramp(t, [hexc("#1f7a3a"), hexc("#2fbf63"), hexc("#7be08a"), hexc("#9a6ad8")])
    return c


def clean_skin(col, m, blur):
    """The scan's skin rebuilt on a warm ramp from a band-pass of its light: baked highlights and mottling off, forms kept."""
    l = col.mean(-1)
    mf = m.astype(np.float32)
    l1, l2 = blur(l, mf, 4), blur(l, mf, 34)
    t = np.clip(0.48 + (l1 - l2) * 2.8, 0.06, 0.92)
    new = ramp(t, SKIN_R)
    return np.where(m[..., None], new.astype(np.float32), col)


def project_portrait(pos, col, H):
    """The face pass: the portrait's painted face on the head by an affine through her eyes and mouth (front view), soft at its edge; its hair stays out, tone matched to the body."""
    img = _decal("portrait")
    ex, ez = H.EYE_X * H.SK * 0.95, H.EYE_Z
    zm = ez - 0.062
    A = np.array([[ex, ez, 1], [-ex, ez, 1], [0, zm, 1]])
    B = np.array([[790, 641], [980, 583], [933, 800.0]])
    M_ = np.linalg.solve(A, B)
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]
    q = np.stack([x, z, np.ones_like(x)], -1) @ M_
    px_ = img[np.clip(q[..., 1].astype(int), 0, 2047), np.clip(q[..., 0].astype(int), 0, 2047)]
    r = np.sqrt((x / 0.098) ** 2 + ((z - (ez - 0.022)) / 0.092) ** 2)
    w = (1 - smooth(0.74, 1.0, r)) * (y > H.HC[1] + 0.02)
    green = (px_[..., 1] > px_[..., 0] * 1.02)
    w = w * (1 - green)
    return col * (1 - w[..., None]) + np.clip(px_ * np.array([1.1, 1.0, 0.94]) * 1.06, 0, 1) * w[..., None]


def _seg_dist(x, z, a, b):
    ax, az, bx, bz = a[0], a[1], b[0], b[1]
    dx, dz = bx - ax, bz - az
    t = np.clip(((x - ax) * dx + (z - az) * dz) / max(dx * dx + dz * dz, 1e-9), 0, 1)
    return np.hypot(x - ax - t * dx, z - az - t * dz)


def circuit_lines(Zb, Zs):
    """The master's thin angular circuits, in (x, z), rig metres: Zb the belt line, Zs the shoulders. -> [(side, polyline, end dot)], side +1 front, -1 back."""
    out = []
    for s in (1.0, -1.0):
        # the stomach, from under the top to the belt
        out.append((1, [(s * .036, Zb + .185), (s * .036, Zb + .13), (s * .06, Zb + .1), (s * .06, Zb + .02)], True))
        out.append((1, [(s * .074, Zb + .16), (s * .074, Zb + .125), (s * .092, Zb + .1)], True))
        # the thighs
        for x0, sg in ((s * .12, 1.0),):
            out.append((1, [(x0 - s * .04, Zb - .17), (x0 - s * .04, Zb - .225), (x0 - s * .06, Zb - .25)], True))
            out.append((1, [(x0 + s * .03, Zb - .17), (x0 + s * .03, Zb - .21), (x0 + s * .05, Zb - .235), (x0 + s * .05, Zb - .262)], False))
            out.append((-1, [(x0 + s * .02, Zb - .19), (x0 + s * .02, Zb - .24), (x0 + s * .045, Zb - .26)], True))
        # the back: branches off the spine, the sheet's ribs of light
        for i, dz in enumerate((.07, .12, .17, .225)):
            out.append((-1, [(s * .03, Zb + dz), (s * (.06 + .008 * i), Zb + dz), (s * (.075 + .008 * i), Zb + dz + .025)], i % 2 == 0))
    # the chest: one line from the collar
    out.append((1, [(-.03, Zs - .0), (-.02, Zs - .06), (-.045, Zs - .12), (-.045, Zs - .15)], False))
    return out


def draw_circuits(x, z, front, Zb, Zs, wd=0.0023):
    """-> a mask over texels."""
    m = np.zeros(x.shape, bool)
    for side, pl, dot in circuit_lines(Zb, Zs):
        k = front if side > 0 else ~front
        for a, b in zip(pl[:-1], pl[1:]):
            m |= k & (_seg_dist(x, z, a, b) < wd)
        if dot:
            m |= k & (np.hypot(x - pl[-1][0], z - pl[-1][1]) < 0.0052)
    return m

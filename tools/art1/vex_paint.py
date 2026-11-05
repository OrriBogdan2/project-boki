"""ART-1 Vex: the texel-space paint of the rebuilt pieces (see kael_paint.py): arrays of texels in, sRGB out."""
import os, sys
import numpy as np
from meshkit import norm, smooth
from kael_paint import hexc, mix, fbm, lit, ramp, vnoise
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
    # the wanted poster on the top (forward at rest): it faces the match camera when she aims
    P = _decal("poster")
    pv = (s - (-0.135)) / 0.225
    pu = 0.5 + (u + 0.0) / 0.13
    m = (pu > 0) & (pu < 1) & (pv > 0) & (pv < 1) & (f > VC.SLEEVE_F + 0.02)
    sm = sample(P, pu, 1 - pv)
    c = np.where(m[..., None], sm * (0.6 + 0.62 * lit(n, ao))[..., None], c)
    # the skull and the kill tallies on the outer face
    T = _decal("skulltally")
    tv = (s - (-0.13)) / 0.235
    tu = 0.5 + (f - VC.SLEEVE_F) / 0.105
    m2 = (tu > 0) & (tu < 1) & (tv > 0) & (tv < 1) & (u > 0.03)
    tc = sample(T, tu, 1 - tv)
    light = (tc.min(-1) > 0.72) | ((tc[..., 1] > tc[..., 0] * 1.35) & (tc[..., 1] > 0.5))
    c = np.where((m2 & light)[..., None], tc * (0.75 + 0.45 * lit(n, ao))[..., None], c)
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


def belt_tile(h, w):
    """Cartridges across the ribbon: u along each tooth; brass case, copper tip side to side."""
    v, u = np.mgrid[0:h, 0:w]
    u, v = (u + .5) / w, (v + .5) / h
    across = np.abs(v * 2 - 1)
    shade = 0.12 + 1.0 * np.sin(u * np.pi) ** 0.7
    c = ramp(np.clip(shade * 0.85, 0, 1), BRASS)
    c = np.where((v > 0.76)[..., None], ramp(np.clip(shade, 0, 1), [hexc("#3a1f0d"), hexc("#73401c"), hexc("#a96533"), hexc("#d49358"), hexc("#f0c79a")]), c)
    c = np.where((np.abs(v - 0.12) < 0.11)[..., None], ramp(np.clip(shade * .7, 0, 1), BLACKM), c)
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


SKIN_R = [hexc("#9a5f60"), hexc("#c98680"), hexc("#e3a596"), hexc("#f2c2b2"), hexc("#fcdccd")]


def goggle_lens(p, n, ao):
    t = np.clip(0.5 + 0.5 * n[..., 0] + 0.3 * n[..., 2], 0, 1)
    c = ramp(t, [hexc("#1f7a3a"), hexc("#2fbf63"), hexc("#7be08a"), hexc("#9a6ad8")])
    return c


def clean_skin(col, m, blur):
    """The scan's skin rebuilt on a warm ramp from a band-pass of its light: baked highlights and mottling off, forms kept."""
    l = col.mean(-1)
    mf = m.astype(np.float32)
    l1, l2 = blur(l, mf, 2), blur(l, mf, 20)
    t = np.clip(0.42 + (l1 - l2) * 3.0, 0, 1)
    new = ramp(t, SKIN_R) + (l - l1)[..., None] * 0.5
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

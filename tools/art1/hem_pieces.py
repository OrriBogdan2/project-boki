"""ART-1 Ravel v2 (ids stay `hem`): the pieces the scan leaves out, as data. Blender frame: Z up, she faces +Y, her right hand
is +X. The bow keeps Hem's frame (grip_frame, so longbow.json and hem_clips.py stay): x side, y away from the string, z
its long axis, the grip at 0. Measured off ravel_v2_turnaround.jpg: 708 px is the rig's 1.81 m."""
import json
import math

import numpy as np

from meshkit import Piece, catmull, norm, smooth, sweep

F = np.float64
SKIN, THREAD, BOW, BOW_HI, STEEL, STEEL_DK, PIN = "skin-doll", "cloth-thread", "leather-bow", "leather-bow_hi", "metal-needle", "metal-needle_dk", "metal-pin"
HEX = [(math.cos(t), math.sin(t)) for t in np.linspace(0, math.tau, 6, endpoint=False)]
SQ = [(math.cos(t), math.sin(t)) for t in (0.8, 2.4, 3.9, 5.5)]
LENS = [(-1, 0), (-0.4, 0.5), (0.4, 0.5), (1, 0), (0.4, -0.5), (-0.4, -0.5)]
ROOM_THIN = 0.3
# the bow: half length 0.8 (1.6 m, the sheet's 0.88 of her height), the old bow's curve drawn long
BOW_K = 0.8 / 0.625
STRING_Y = -0.200
STRING_Z = 0.566 * BOW_K
BOW_Z = np.array((0, .06, .13, .23, .317, .447, .523, .566, .6, .625), F) * BOW_K
BOW_Y = np.array((0, .006, .027, .005, -.044, -.131, -.18, -.198, -.204, -.204), F)
BOW_T = np.array((.0165, .018, .034, .025, .0175, .0135, .0115, .016, .015, .0018), F)
BOW_W = np.array((.0165, .015, .01, .009, .0078, .0066, .006, .0056, .005, .002), F)
GRIP_R = 0.0172
GRIP_Z = 0.1                         # the red grip wrap's half length
ARROW_LEN = 0.78
# the crossed back needles (model x, z): eye top, tip; y behind the hair
NEEDLE_TOP, NEEDLE_TIP, NEEDLE_Y = (-0.243, 1.8), (0.358, 0.75), -0.185
EYE_LEN, EYE_W = 0.19, 0.044         # the eye's loop, length and half width
NEEDLE_WRAPS = ((0.17, 0.33), (0.49, 0.61), (0.905, 0.925))      # along the needle, 0 eye .. 1 tip
LASH_S = 0.405                       # where the two cross
# the porcelain mask on her left shoulder (sheet: shoulder top to mid upper arm, turned out and forward)
MASK_H, MASK_W, MASK_D = 0.105, 0.07, 0.036      # half height, half width, the dome's depth (m)
MASK_OUT = np.array((-0.054, 0.024, -0.07), F)    # its centre from the upper_arm.L joint
MASK_N = (-0.75, 0.62, 0.1)                     # the way it faces
MASK_TILT = 0.22                                  # rad, its chin turned toward her back


def joints(rig_path):
    rig = json.load(open(rig_path))
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]], F) for k, v in rig["bones"].items()}


def grip_frame(J):
    sx, wz = float(J["hand.L"][0]), float(J["hand.L"][2])
    c = np.array((sx, 0.002, wz - 0.066), F)
    A = np.array((0.0, 0.72, 0.694), F)
    A = A / np.linalg.norm(A)
    S = np.array((0.0, -A[2], A[1]), F)
    return c, A, S


def bow_to_model(p, J):
    c, A, Sd = grip_frame(J)
    p = np.asarray(p, F)
    return c + p[..., 0:1] * np.array((1.0, 0, 0)) + p[..., 1:2] * (-Sd) + p[..., 2:3] * A


def rigid(pcs, bone):
    return [p.rigid(bone) for p in pcs]


def cone_sph(name, mat, c, r, n=6, room=1.0):
    """A small closed blob (rings of `n`), radii r (x, y, z)."""
    c, r = np.asarray(c, F), np.asarray(r, F)
    path = c + np.outer(np.linspace(-1, 1, 5), (0, 0, r[2]))
    w = np.sqrt(np.maximum(1 - np.linspace(-1, 1, 5) ** 2, 0.02))
    sec = [(math.cos(t), math.sin(t)) for t in np.linspace(0, math.tau, n, endpoint=False)]
    return sweep(name, mat, path, sec, w * r[0], side_hint=(1, 0, 0), depth=w * r[1], room=room)


def fist(J):
    """Her bow hand, closed for good round the grip: palm, four wrapped fingers, the thumb over."""
    sx, wz = float(J["hand.L"][0]), float(J["hand.L"][2])
    c, A, S = grip_frame(J)
    X = np.array((1.0, 0, 0), F)
    out = [sweep("wrist", SKIN, [(sx, 0, wz + 0.06), (sx, 0, wz + 0.02), (sx, 0.002, wz - 0.015)], HEX, [0.03, 0.027, 0.026], side_hint=(1, 0, 0)),
           cone_sph("palm", SKIN, (sx - 0.0125, 0.003, wz - 0.052), (0.021, 0.04, 0.047)),
           cone_sph("heel", SKIN, (sx + 0.010, 0.012, wz - 0.040), (0.016, 0.026, 0.028))]
    for i, (off, rr) in enumerate(((0.030, 0.0088), (0.0115, 0.0092), (-0.007, 0.0086), (-0.0245, 0.0075))):
        at = c + A * off
        pts = [at + (GRIP_R + rr * 0.92) * (-X * math.cos(t) + (-S) * math.sin(t)) for t in np.linspace(-1.75, 1.55, 6)]
        out.append(sweep("finger%d" % i, SKIN, pts, HEX, np.array([1.04, 1.04, 1, 1, .95, .82]) * rr, side_hint=A))
    a = c + A * 0.012
    pts = [a + (0.021 * X + 0.016 * S - A * 0.016), a + (0.0255 * X + 0.0005 * S + A * 0.012), a + (0.0245 * X - 0.0115 * S + A * 0.035),
           a + (0.0185 * X - 0.0185 * S + A * 0.047)]
    out.append(sweep("thumb", SKIN, pts, HEX, [0.0118, 0.0102, 0.0095, 0.0078], side_hint=X))
    return rigid(out, "hand.L")


def _bow_limb(sign, J):
    """One limb, grip to tip, sign +1 the top."""
    n = 26
    zs = np.linspace(GRIP_Z * 0.8, BOW_Z[-1], n)
    y, t, w = np.interp(zs, BOW_Z, BOW_Y), np.interp(zs, BOW_Z, BOW_T), np.interp(zs, BOW_Z, BOW_W)
    path = np.stack([0 * zs, y, sign * zs], 1)
    return sweep("limb", BOW, bow_to_model(path, J), LENS, w * 1.25, side_hint=(1, 0, 0), depth=t)


def bow(J):
    """The black recurve: limbs, a red-wrapped grip between silver collars, silver tips with red wraps, the red string."""
    z_w = BOW_Z[-1]
    parts = []
    for sg in (1, -1):
        parts.append(_bow_limb(sg, J))
        for nm, z0, z1, r, mat in (("collar", GRIP_Z - 0.008, GRIP_Z + 0.022, 0.0205, STEEL),
                                   ("tip_wrap", z_w - 0.13, z_w - 0.075, 0.0125, THREAD)):
            y0, y1 = np.interp((z0, z1), BOW_Z, BOW_Y)
            parts.append(sweep(nm, mat, bow_to_model(np.array([(0, y0, sg * z0), (0, y1, sg * z1)], F), J), HEX, [r, r * 0.92], side_hint=(1, 0, 0), tip=False))
        tip = np.array([(0, -0.204, sg * (z_w - 0.075)), (0, -0.21, sg * (z_w - 0.03)), (0, -0.225, sg * (z_w + 0.05))], F)
        parts.append(sweep("tip", STEEL, bow_to_model(tip, J), HEX, [0.0105, 0.009, 0.0012], side_hint=(1, 0, 0)))
    grip = np.array([(0, 0, -GRIP_Z), (0, 0, 0), (0, 0, GRIP_Z)], F)
    parts.append(sweep("grip", THREAD, bow_to_model(grip, J), HEX, [GRIP_R * 1.02] * 3, side_hint=(1, 0, 0), tip=False))
    for p in parts:
        zz = (p.v - grip_frame(J)[0]) @ grip_frame(J)[1]
        k = np.abs(zz)
        p.w = {"bow": smooth(0.14, 0.08, k), "bow_t": smooth(0.08, 0.14, zz), "bow_b": smooth(-0.08, -0.14, zz)}
    s = np.array([(0, STRING_Y, z) for z in (STRING_Z, 0.1, 0.0, -0.1, -STRING_Z)], F)
    st = sweep("string", THREAD, bow_to_model(s, J), SQ, [0.0028] * 5, side_hint=(1, 0, 0), room=0.0, tip=False)
    zz = (st.v - grip_frame(J)[0]) @ grip_frame(J)[1]
    st.w = {"bow_s": (np.abs(zz) < 0.1 + 1e-3) * 1.0 * (np.abs(zz) < 0.11), "bow_t": (zz >= 0.11) * 1.0, "bow_b": (zz <= -0.11) * 1.0}
    parts.append(st)
    return parts


def shaft_r(s):
    """The needle's radius along it, 0 eye .. 1 tip: stout under the eye, a steady taper, a fine point."""
    return float(np.interp(s, (0.0, 0.33, 0.61, 0.86, 0.97, 1.0), (0.026, 0.0235, 0.0175, 0.0125, 0.0055, 0.0007)))


def _needle_frame():
    a = np.array((NEEDLE_TOP[0], NEEDLE_Y, NEEDLE_TOP[1]), F)
    b = np.array((NEEDLE_TIP[0], NEEDLE_Y, NEEDLE_TIP[1]), F)
    return a, b


def back_needle(sign):
    """One of the two giant needles on her back (hips bone). sign flips it left-right; the two pass 1 cm apart at the lash."""
    a, b = _needle_frame()
    a, b = a * (sign, 1, 1), b * (sign, 1, 1)
    a[1] += sign * 0.009
    b[1] += sign * 0.009
    ln = np.linalg.norm(b - a)
    d = (b - a) / ln
    side = norm(np.cross(d, (0, 1, 0)))
    at = lambda s: a + d * s * ln
    e = EYE_LEN
    ts = np.linspace(0, math.tau, 15)
    ring = [a + d * (e * (0.5 - 0.5 * math.cos(t))) + side * (EYE_W * math.sin(t) * (1 - 0.32 * (0.5 - 0.5 * math.cos(t)))) for t in ts]
    out = [sweep("eye", STEEL, ring, HEX, [0.0135] * 15, side_hint=(0, 1, 0), tip=False, depth=[0.0095] * 15)]
    s0 = e * 0.93 / ln
    ss = (s0, s0 + 0.04, 0.33, 0.61, 0.86, 0.97, 1.0)
    out.append(sweep("shaft", STEEL, [at(s) for s in ss], HEX, [shaft_r(s) for s in ss], side_hint=(0, 1, 0)))
    groove = [at(s0 + 0.012) + (0, -0.0225, 0), at(s0 + 0.13) + (0, -0.0225, 0)]
    out.append(sweep("groove", STEEL_DK, groove, SQ, [0.0045, 0.0035], side_hint=side, depth=[0.0012, 0.0012], tip=True, room=0.0))
    for s1, s2 in NEEDLE_WRAPS:
        out.append(sweep("wrap", THREAD, [at(s) for s in np.linspace(s1, s2, 3)], HEX, [shaft_r(s) + 0.0045 for s in np.linspace(s1, s2, 3)], side_hint=(0, 1, 0), tip=False))
    return out


def lash():
    """The red thread lashing the X, a small knot."""
    a, b = _needle_frame()
    c = a + (b - a) * LASH_S
    c[0] = 0.0
    return [cone_sph("lash", THREAD, c, (0.036, 0.03, 0.044))]


def strings():
    """The severed strings: short red threads hanging from the needles' eyes and tip wraps, a slight curl, rigid (hips)."""
    out = []
    a, b = _needle_frame()
    d = b - a
    for sg, s, ln in ((-1, 0.22, 0.16), (1, 0.24, 0.22), (-1, 0.915, 0.26), (1, 0.915, 0.2)):
        p = (a + d * s) * (sg, 1, 1)
        path = [p + (sg * 0.012 * math.sin(t * 2.4), -0.006 * t, -ln * t) for t in np.linspace(0, 1, 5)]
        out.append(sweep("string", THREAD, path, SQ, [0.0032, 0.003, 0.0028, 0.0025, 0.0014], side_hint=(1, 0, 0), room=0.0))
    return out


def spools(belt, xs):
    """The red thread spools on her belt, a pin through each: (x, y) on the belt from `belt(x)`, z the belt's height."""
    out = []
    for x in xs:
        p, nrm = belt(x)
        p = p + nrm * 0.024
        top, bot = p + np.array((0, 0, 0.034)), p - np.array((0, 0, 0.034))
        out.append(sweep("spool", THREAD, [top, p, bot], HEX, [0.0205, 0.0215, 0.0205], side_hint=(1, 0, 0), tip=False))
        for nm, q in (("flange", top), ("flange", bot)):
            out.append(sweep(nm, STEEL_DK, [q + (0, 0, 0.005), q - (0, 0, 0.005)], HEX, [0.0245, 0.0245], side_hint=(1, 0, 0)))
        out.append(sweep("pin", PIN, [bot, bot - (0, 0, 0.05), bot - (0, 0, 0.095)], HEX, [0.0048, 0.0036, 0.0005], side_hint=(1, 0, 0), room=ROOM_THIN))
    return out


def bun_pins(c):
    """The silver needles through the bun (on the head bone): four, crossing, an eye-flat at the outer end."""
    out = []
    for i, (sg, up, ln0, ln1) in enumerate(((1, 0.24, 0.14, 0.15), (-1, 0.24, 0.14, 0.15), (1, -0.2, 0.13, 0.14), (-1, -0.2, 0.13, 0.14))):
        d = norm(np.array((sg, 0.12, up), F))
        p0, p1 = c - d * ln0, c + d * ln1
        out.append(sweep("pin", PIN, [p0, c, p1], HEX, [0.0009, 0.0045, 0.0052], side_hint=(0, 1, 0), room=ROOM_THIN))
    return out


def arrow(at, ax, ay, az):
    """The needle arrow: nock at `at`, flying along ay: silver shaft, spear head, red thread binds, two tan vanes."""
    L = ARROW_LEN
    xf = lambda x, y, z=0.0: at + ax * x + ay * y + az * z
    out = [sweep("shaft", PIN, [xf(0, 0), xf(0, L * 0.5), xf(0, L - 0.12)], HEX, [0.0042] * 3, side_hint=az, tip=False, room=ROOM_THIN),
           sweep("head", PIN, [xf(0, L - 0.13), xf(0, L - 0.1), xf(0, L - 0.075), xf(0, L)], LENS, [0.0042, 0.0105, 0.012, 0.0007], side_hint=ax, depth=[0.004, 0.004, 0.0032, 0.0005], room=ROOM_THIN)]
    for yy in (0.016, 0.142, L - 0.145):
        out.append(sweep("bind", THREAD, [xf(0, yy - 0.007), xf(0, yy + 0.007)], HEX, [0.0062, 0.0062], side_hint=az, tip=False, room=0.0))
    for sg in (-1, 1):
        out.append(sweep("vane", "leather-vane", [xf(sg * 0.003, 0.03), xf(sg * 0.017, 0.07), xf(sg * 0.02, 0.1), xf(sg * 0.003, 0.127)], SQ, [0.0012, 0.0024, 0.0024, 0.0012], side_hint=ay, depth=[0.0024, 0.012, 0.012, 0.0024], room=0.0))
    return out


def _mask_frame(J):
    n = norm(np.array(MASK_N, F))
    up = norm(np.array((0, 0, 1.0)) - n * n[2])
    side = np.cross(up, n)
    c, s_ = math.cos(MASK_TILT), math.sin(MASK_TILT)
    up, side = up * c + side * s_, side * c - up * s_
    return J["upper_arm.L"] + MASK_OUT, side, up, n


def _mask_depth(x, y):
    """The face's relief over the unit oval: dome, brow, nose, cheeks, chin."""
    r2 = x * x + y * y
    d = np.sqrt(np.maximum(1.0 - r2, 0.0)) * 0.75 + 0.25 * (1.0 - r2)
    d += 0.22 * np.exp(-(x / 0.13) ** 2 - ((y + 0.02) / 0.3) ** 2)          # nose
    d += 0.08 * np.exp(-((y - 0.3) / 0.12) ** 2) * (1 - x * x)              # brow
    d -= 0.1 * np.exp(-((np.abs(x) - 0.36) / 0.16) ** 2 - ((y - 0.17) / 0.11) ** 2)    # sockets
    return d


def shoulder_mask(J):
    """The porcelain half-mask on her left shoulder: a closed relief oval, hollow black eyes, a red seam of stitches."""
    c, sd, up, n = _mask_frame(J)
    ang = np.linspace(0, math.tau, 18, endpoint=False)
    rings = (0.0, 0.2, 0.4, 0.58, 0.74, 0.88, 1.0)
    at = lambda x, y, k=1.0: c + sd * x * MASK_W + up * y * MASK_H + n * _mask_depth(x, y) * MASK_D * k
    verts, faces = [at(0, 0)], []
    for r in rings[1:]:
        verts += [at(r * math.cos(t) * 0.999, r * math.sin(t) * 0.999) for t in ang]
    m = len(ang)
    for j in range(m):
        faces.append([0, 1 + j, 1 + (j + 1) % m])
    for i in range(len(rings) - 2):
        b = 1 + i * m
        for j in range(m):
            faces.append([b + j, b + m + j, b + m + (j + 1) % m, b + (j + 1) % m])
    back = len(verts)
    verts.append(c - n * MASK_D * 0.15)
    rim = 1 + (len(rings) - 2) * m
    for j in range(m):
        faces.append([back, rim + (j + 1) % m, rim + j])
    out = [Piece("mask", SKIN, verts, faces)]
    for sg in (-1, 1):                 # the hollow eyes: thin closed lenses lying in the sockets
        ex, ey = sg * 0.36, 0.17
        ring = [at(ex + 0.21 * math.cos(t), ey + 0.1 * math.sin(t) - sg * 0.04 * math.cos(t), 1.02) for t in np.linspace(0, math.tau, 8, endpoint=False)]
        lens = [at(ex, ey, 1.04)] + ring + [at(ex, ey, 0.9)]
        out.append(Piece("mask_eye", BOW, lens, [[0, 1 + k, 1 + (k + 1) % 8] for k in range(8)] + [[9, 1 + (k + 1) % 8, 1 + k] for k in range(8)]))
    seam = [at(0.62 + 0.08 * math.sin(y * 3), y, 1.08) for y in np.linspace(0.62, -0.7, 6)]
    out.append(sweep("mask_seam", THREAD, seam, SQ, [0.003] * 6, side_hint=up, tip=False, room=0.0))
    for k, y in enumerate(np.linspace(0.5, -0.55, 5)):
        x0 = 0.62 + 0.08 * math.sin(y * 3)
        out.append(sweep("mask_stitch", THREAD, [at(x0 - 0.16, y + 0.04, 1.08), at(x0 + 0.16, y - 0.04, 1.08)], SQ, [0.0028, 0.0028], side_hint=n, tip=False, room=0.0))
    return out

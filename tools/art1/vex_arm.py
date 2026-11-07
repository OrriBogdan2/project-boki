"""ART-1 Vex: the robotic left forearm and hand (rigid per bone: a machine has no skin to slide), the gold coin. Upper arm and sleeve stay the scan's."""
import numpy as np
from meshkit import Piece, norm, smooth, sweep, frames
from vex_cannon import J, ring, box

EL, WR = J("forearm.L"), J("hand.L")
FA = norm(WR - EL)
HAND_LEN = 0.135


def _lat(name, mat, c, d, prof, n, bone, phase=0.0, flat=1.0):
    """Lathe along direction d from c. flat: squash along Y."""
    d = norm(np.asarray(d, float))
    a = norm(np.cross(d, (0, 1.0, 0)))
    b = np.cross(d, a)
    v, f = [], []
    for s, r in prof:
        for t in np.linspace(0, 2 * np.pi, n, endpoint=False) + phase:
            v.append(c + d * s + a * np.cos(t) * r + b * np.sin(t) * r * flat)
    for i in range(len(prof) - 1):
        for j in range(n):
            p, q = i * n + j, i * n + (j + 1) % n
            f.append([p, q, q + n, p + n])
    return Piece(name, mat, np.array(v), f).rigid(bone)


def forearm():
    L = np.linalg.norm(WR - EL)
    ps = []
    ps.append(_lat("elbowball", "metal-vex", EL, (1.0, 0, 0), [(-0.042, 0.0), (-0.042, 0.022), (-0.03, 0.04), (0.03, 0.04), (0.042, 0.022), (0.042, 0.0)], 9, "forearm.L"))
    ps.append(_lat("elbowglow", "glow-vex", EL, (-1.0, 0, 0), [(0.043, 0.0), (0.043, 0.024)], 8, "forearm.L"))
    prof = [(0.02, 0.03), (0.045, 0.043), (L * 0.32, 0.05), (L * 0.55, 0.046), (L * 0.8, 0.036), (L * 0.97, 0.03)]
    ps.append(_lat("robofore", "metal-vex", EL, FA, prof, 9, "forearm.L", flat=0.9))
    ps.append(_lat("wristband", "brass-vex", EL, FA, [(L * 0.82, 0.037), (L * 0.84, 0.042), (L * 1.0, 0.038), (L * 1.02, 0.03)], 9, "forearm.L", flat=0.92))
    return ps


def panel():
    """The forearm's long brass panel, on its outer face, as the sheet: a raised curved plate from below the elbow to the wrist."""
    L = np.linalg.norm(WR - EL)
    rows, arc = 6, 6
    v = []
    for i in range(rows):
        k = i / (rows - 1)
        al = L * (0.2 + 0.68 * k)
        r = np.interp(al, (0.045, L * 0.32, L * 0.55, L * 0.8), (0.043, 0.05, 0.046, 0.036)) + 0.004
        half = 1.25 - 0.45 * k
        for j in range(arc):
            t = -np.pi * 0.9 + (j / (arc - 1) - 0.5) * 2 * half
            v.append(EL + FA * al + np.array([np.cos(t) * r, np.sin(t) * r * 0.9 * -1.0 * -1.0, 0]))
    f = []
    for i in range(rows - 1):
        for j in range(arc - 1):
            a = i * arc + j
            f.append([a, a + 1, a + 1 + arc, a + arc])
    p = Piece("robopanel", "brass-vex", np.array(v), f).rigid("forearm.L")
    p.orient(tuple(EL + FA * L * 0.5))
    return [p]


def hand():
    """Palm block, three-joint metal fingers with glowing pads, the thumb. Rest: relaxed open. k along the knuckles (first finger first), a wrist to knuckles, o out of its back."""
    wrist = WR.copy()
    a = np.array([0, 0, -1.0])
    k = np.array([0.0, 1.0, 0.0])          # the first finger forward
    o = np.array([-1.0, 0, 0.0])           # the back of the hand outward
    out = []
    centre = [wrist + a * 0.0, wrist + a * 0.03, wrist + a * 0.062, wrist + a * 0.082]
    wd = np.array([0.026, 0.038, 0.042, 0.04])
    dp = np.array([0.021, 0.021, 0.019, 0.016])
    palm = sweep("palm", "metal-vex", centre, [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)], wd, side_hint=k, depth=dp, tip=False)
    t_, s_, n_ = frames(np.asarray(centre), k)
    for i in range(4):
        for j in range(8):
            d = palm.v[i * 8 + j] - centre[i]
            x, y = np.dot(d, s_[i]) / wd[i], np.dot(d, n_[i]) / dp[i]
            palm.v[i * 8 + j] = centre[i] + k * x * wd[i] + o * y * dp[i]
    out.append(palm.rigid("hand.L"))
    knuck = wrist + a * 0.082
    lens = [(0.03, 0.022, 0.02), (0.033, 0.024, 0.021), (0.031, 0.022, 0.02), (0.025, 0.018, 0.017)]
    curl = (0.25, 0.3, 0.2)
    for f in range(4):
        base = knuck + k * (0.03 - f * 0.02)
        cur = base.copy()
        pts = [base]
        ang = 0.0
        d0 = a
        for jn in range(3):
            ang += curl[jn]
            dd = norm(a * np.cos(ang) - o * np.sin(ang))
            cur = cur + dd * lens[f][jn]
            pts.append(cur.copy())
        pts = np.array(pts)
        rd = 0.0095 - 0.0004 * f
        body = sweep("finger%dL" % f, "metal-vex", pts[:3], [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 5, endpoint=False)], np.array([rd, rd * 0.86, rd * 0.86]), side_hint=k, tip=False)
        q = smooth(0.006, 0.014, np.linalg.norm(body.v - base, axis=1))
        body.w = {"hand.L": 1 - q, "fingers.L": q}
        pad = sweep("fpad%dL" % f, "glow-vex", pts[2:4] * 1, [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 5, endpoint=False)], np.array([rd * 0.98, rd * 0.72]), side_hint=k)
        pad.rigid("fingers.L")
        out += [body, pad]
    base = wrist + a * 0.024 + k * 0.04 - o * 0.006
    t1 = base + norm(a * 0.72 + k * 0.42 - o * 0.5) * 0.034
    t2 = t1 + norm(a * 0.9 + k * 0.05 - o * 0.45) * 0.026
    t3 = t2 + norm(a * 0.9 - k * 0.3 - o * 0.2) * 0.02
    tp = sweep("thumbL", "metal-vex", [base, t1, t2], [(np.cos(x), np.sin(x)) for x in np.linspace(0, 2 * np.pi, 5, endpoint=False)], np.array([0.0145, 0.0115, 0.01]), side_hint=o, tip=False)
    q = smooth(0.006, 0.024, np.linalg.norm(tp.v - base, axis=1))
    tp.w = {"hand.L": 1 - q, "thumb.L": q}
    tip = sweep("thumbpad", "glow-vex", [t2, t3], [(np.cos(x), np.sin(x)) for x in np.linspace(0, 2 * np.pi, 5, endpoint=False)], np.array([0.0102, 0.0072]), side_hint=o)
    tip.rigid("thumb.L")
    return out + [tp, tip], knuck, a, k, o


COIN_R, COIN_T = 0.036, 0.0045


def coin(knuck, a, k, o):
    """The gold coin, resting on the curled first finger; its own bone flips it. Faces toward the palm side."""
    c = knuck + a * 0.022 + k * 0.012 - o * 0.03
    d = norm(np.array([0, 0.25, 1.0]))
    p = _lat("coin", "brass-vex", c, d, [(-COIN_T, 0.0), (-COIN_T, COIN_R), (COIN_T, COIN_R), (COIN_T, 0.0)], 10, "coin")
    return p, c

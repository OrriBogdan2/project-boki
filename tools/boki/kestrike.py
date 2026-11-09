"""Kestrike, an upright little kestrel with a copper lightning rod for a crest: shapes and coat. Game axes as
vespyx.py. NEW design (roster 50, #14), owner approval pending."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
BODY_C = v3(0, 0.2, 0.045)
BODY_R = v3(0.148, 0.15, 0.15)
CHEST_C = v3(0, 0.29, -0.035)
CHEST_R = v3(0.142, 0.14, 0.125)
HEAD_C = v3(0, 0.465, -0.06)
HEAD_R = v3(0.175, 0.152, 0.162)
EYE_C = v3(0.074, 0.482, -0.19)
EYE_R = v3(0.045, 0.049, 0.028)
EYE_YAW = 0.32
GLOW_PIECES = ("spark", "charge", "bolt")
BERRY_C = v3(0, 0.05, -0.26)
FACE = {"mouth_w": 0.03, "mouth_y": 0.405, "mouth_z": -0.24, "cat_mouth": False, "brow_x": 0.08, "brow_up": 0.012,
        "brow_k": 0.8, "fang_k": 0.0}
BEAK = (v3(0, 0.448, -0.2), v3(0, 0.442, -0.262), v3(0, 0.405, -0.278))
SHOULDER = v3(0.135, 0.37, 0.0)
TAIL_PTS = [v3(0, 0.2, 0.15), v3(0, 0.125, 0.265), v3(0, 0.06, 0.36)]
ROD = (v3(0, 0.595, -0.06), v3(0, 0.67, -0.04), v3(0, 0.74, -0.012))
SPARK_C = ROD[2] + v3(0, 0.022, 0.003)
# swept-back feather points behind the eyes, bolt-shaped: base, kink, tip
EAR_PTS = ((0.1, 0.555, 0.0), (0.14, 0.585, 0.06), (0.155, 0.6, 0.13))
TOES = ((0.03, -0.05), (0.0, -0.06), (-0.028, -0.046), (0.004, 0.04))    # dx, dz from the ankle: three on, one back


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.08, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def wing_frame(sx):
    """Rows: along the folded wing (down its back, the tips toward the tail), up to its leading edge, out of it."""
    span = v3(-sx * 0.16, -0.55, 0.8)
    span /= np.linalg.norm(span)
    out = v3(sx, 0.15, 0.25)
    out -= span * (out @ span)
    out /= np.linalg.norm(out)
    return np.stack([span, np.cross(span, out) * sx, out])


def on_wing(sx, s, c):
    """A point of the folded wing: s along it from the shoulder, c down its chord, a little out of the body."""
    fr = wing_frame(sx)
    return SHOULDER * v3(sx, 1, 1) + fr[0] * s - fr[1] * c


def ankle(sx):
    return v3(sx * 0.072, 0.026, -0.0)


def body_prims():
    p = [
        Ellipsoid("body", "hips", BODY_C, BODY_R, k=0.03),
        Ellipsoid("chest", "spine", CHEST_C, CHEST_R, k=0.06),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.05),
        Ellipsoid("brows", "head", v3(0, 0.52, -0.13), v3(0.13, 0.05, 0.08), k=0.04),
    ]
    for sd, sx in SIDES:
        p.append(Ellipsoid("cheek" + sd, "head", v3(sx * 0.1, 0.43, -0.12), v3(0.075, 0.06, 0.075), k=0.04))
        a, b, c = (v3(sx * x, y, z) for x, y, z in EAR_PTS)
        n = v3(0, 1, 0.2)
        p.append(Cone("ear" + sd, "ear1." + sd, a, b, 0.032, 0.018, k=0.02, flat=0.4, flat_axis=n))
        p.append(Cone("eartip" + sd, "ear1." + sd, b - v3(0, 0.012, 0.0), c, 0.022, 0.003, k=0.01, flat=0.4,
                      flat_axis=n))
        # feathered trousers, a bare yellow shank, three toes forward and one back
        hip = v3(sx * 0.068, 0.12, 0.03)
        knee = v3(sx * 0.072, 0.07, 0.01)
        p.append(Cone("thigh" + sd, "hleg1." + sd, hip, knee, 0.046, 0.03, k=0.03))
        p.append(Cone("shank" + sd, "hleg2." + sd, knee, ankle(sx), 0.016, 0.014, k=0.01))
        for j, (dx, dz) in enumerate(TOES):
            tip = ankle(sx) + v3(sx * dx, -0.013, dz)
            p.append(Cone("toe%s%d" % (sd, j), "hpaw." + sd, ankle(sx) + v3(0, -0.006, 0), tip, 0.012, 0.006,
                          k=0.007))
    return p


def wing_prims():
    out = []
    for sd, sx in SIDES:
        fr = wing_frame(sx)
        out += [Ellipsoid("cov" + sd, "wing1." + sd, on_wing(sx, 0.08, 0.05), v3(0.1, 0.075, 0.016), rot=fr, k=0.02),
                Cone("prim" + sd, "wing2." + sd, on_wing(sx, 0.14, 0.05), on_wing(sx, 0.34, 0.03), 0.05, 0.008,
                     k=0.03, flat=0.22, flat_axis=fr[2])]
    out += [Ellipsoid("cut" + nm, "spine", c, r - 0.016, k=0.004, sub=True)
            for nm, c, r in (("body", BODY_C, BODY_R), ("chest", CHEST_C, CHEST_R))]
    return out


def tail_prims():
    out = []
    a, b, c = TAIL_PTS
    n0 = np.cross(b - a, v3(1, 0, 0))
    out.append(Cone("tail0", "tail1", a, b, 0.045, 0.05, k=0.02, flat=0.35, flat_axis=n0))
    # the fan: a centre feather and one either side, that spread when it hovers
    n1 = np.cross(c - b, v3(1, 0, 0))
    for bone, dx in (("tail2", 0.0), ("tfan.L", -0.03), ("tfan.R", 0.03)):
        out.append(Cone("fan" + bone, bone, b + v3(dx * 0.3, 0, 0), c + v3(dx, 0.004, 0), 0.04, 0.034, k=0.015,
                        flat=0.32, flat_axis=n1))
    return out


def beak_prims():
    a, b, c = BEAK
    return [Cone("beak0", "head", a, b, 0.03, 0.017, k=0.008), Cone("beak1", "head", b, c, 0.017, 0.004, k=0.008)]


def rod_prims():
    a, b, c = ROD
    return [Ellipsoid("collar", "crest", a + v3(0, 0.005, 0), v3(0.034, 0.016, 0.034), k=0.006),
            Cone("rod0", "crest", a, b, 0.016, 0.014, k=0.004),
            Ellipsoid("ring", "crest", b, v3(0.026, 0.01, 0.026), k=0.004),
            Cone("rod1", "crest", b, c, 0.014, 0.011, k=0.004),
            Ellipsoid("knob", "crest", c, v3(0.019, 0.017, 0.019), k=0.004)]


def star(name, bone, c, r, arms):
    """A little starburst of light: crossed thin spikes."""
    out = [Ellipsoid(name, bone, c, v3(r, r, r), k=0)]
    for i, d in enumerate(arms):
        d = np.asarray(d, float) / np.linalg.norm(d)
        out.append(Cone("%s%d" % (name, i), bone, c - d * r * 2.2, c + d * r * 2.2, r * 0.32, 0.002, k=0.004))
    return out


def bolt_pts():
    """A zigzag bolt flung forward from the rod's tip."""
    o = SPARK_C
    return [o, o + v3(0.03, 0.03, -0.12), o + v3(-0.03, 0.0, -0.22), o + v3(0.025, 0.02, -0.36),
            o + v3(-0.02, -0.02, -0.46), o + v3(0.01, 0.0, -0.6)]


def parts():
    return {
        "body": (Shape(body_prims()), 0.0032, 2300),
        "wings": (Shape(wing_prims()), 0.003, 420),
        "tail": (Shape(tail_prims()), 0.003, 200),
        "beak": (Shape(beak_prims()), 0.0022, 50),
        "rod": (Shape(rod_prims()), 0.0018, 80),
        "spark": (Shape(star("spark", "crest", SPARK_C, 0.017, ((1, 1, 0), (-1, 1, 0), (0, 1, 0.2)))), 0.0016,
                  50),
    }


AXIS = np.array((0.0, 0.42, -0.907))
GRIP = v3(0, 0.43, -0.265)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    out["charge"] = (Shape(star("charge", "prop_charge", SPARK_C, 0.038,
                                ((1, 0.4, 0), (-1, 0.4, 0), (0.3, 1, 0), (-0.3, 1, 0), (0, 0.3, 1), (0, 0.3, -1)))),
                     0.003, 90)
    pts = bolt_pts()
    out["bolt"] = (Shape([Cone("bolt%d" % i, "prop_bolt", pts[i], pts[i + 1], 0.024 - i * 0.003, 0.02 - i * 0.003,
                               k=0.01) for i in range(len(pts) - 1)]), 0.003, 100)
    return out


GROWN = {
    "horn": ((0.075, 0.58, -0.12), (0.135, 0.7, -0.17), 0.03),
    "fang": ((0.012, 0.404, -0.232), (0.014, 0.374, -0.234), 0.011),
    "antenna": ((0.06, 0.6, -0.06), (0.12, 0.74, -0.04), 0.012),
    "brow": ((0.015, 0.545, -0.19), (0.12, 0.555, -0.15), 0.018),
    "head_top": (0, 0.615, -0.06), "fang_at": (0, 0.41, -0.225), "brow_at": (0, 0.545, -0.18),
    "third_eye": (0, 0.57, -0.17),
    "back": ((0, 0.52, 0.08), (0, 0.44, 0.1), (0, 0.36, 0.12)), "back_at": (0, 0.44, 0.08), "plates": (0, 0.4, 0.1),
    "plate_r": (0.11, 0.05, 0.07), "shell_c": (0, 0.28, 0.1), "shell_r": (0.16, 0.15, 0.08), "tail_bone": "tail2",
    "club_at": tuple(TAIL_PTS[2]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[1]), "club_r": 0.05,
    "spots": ((0.15, 0.24, -0.04, 0.02), (0.15, 0.19, 0.02, 0.02), (0.13, 0.13, 0.06, 0.018)),
    "spots_at": (0, 0.2, 0.03),
    "wing": ((0.14, 0.36, 0.06), (0.25, 0.44, 0.16), (0.23, 0.38, 0.2)), "wing_at": (0, 0.36, 0.06),
    "fin": ((0.14, 0.15, 0.1), (0.19, 0.25, 0.2)), "fin_at": (0, 0.16, 0.1), "crest": (0.6, -0.14, 0.06, 0.07),
    "crest_at": (0, 0.6, -0.1),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
RUST = hexc("b5653a")
RUST_LIGHT = hexc("d08a55")
RUST_DARK = hexc("8a4426")
SLATE = hexc("6a7a96")
SLATE_LIGHT = hexc("8e9db6")
SLATE_DARK = hexc("46526a")
FLIGHT = hexc("3a3a48")
SPOT = hexc("2e2226")
CREAM = hexc("f1e0c4")
CREAM_LIGHT = hexc("fbf0dc")
BUFF = hexc("e2b98a")
CERE = hexc("ffd23a")
BILL = hexc("5a6478")
BILL_TIP = hexc("2a2e3a")
FOOT = hexc("f2c23a")
TALON = hexc("2a2228")
COPPER = hexc("de8446")
COPPER_LIGHT = hexc("ffd0a0")
COPPER_DARK = hexc("7a3a1e")
SPARK = hexc("ffe86a")
BLUSH = hexc("ff9a7a")
LILAC = hexc("2e3244")     # brows: dark slate, stern
LID = CREAM / 1.13
INK = hexc("262a36")
MOUTH_DARK = hexc("5a2a2a")
TONGUE = hexc("f08a7a")
IRIS = hexc("b06a2a")
IRIS_DEEP = hexc("3a1c0c")
SHELL_A = hexc("e8b080")
SHELL_B = hexc("a85a32")
SHELL_C = hexc("5a2c18")


def spots(p, scale, size, seed):
    """Dark arrowhead spots scattered over the rust."""
    cell = p * scale
    base = np.floor(cell)
    best = np.full(len(p), 9.0)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                c = base + np.array([dx, dy, dz])
                jit = np.stack([value_noise(c * 7.1 + k, seed=seed + k) for k in range(3)], -1)
                best = np.minimum(best, np.linalg.norm(cell - c - jit, axis=1))
    return edge(size - best, 0.05)


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    fluff = (value_noise(p * np.array([70, 40, 70])) - 0.5) * 0.02
    col = mixc(RUST_DARK, RUST, sat(n[:, 1] * 0.7 + 0.75 + fluff * 10))
    col = mixc(col, RUST_LIGHT, sat(n[:, 1] * 1.4 - 0.75) * 0.6)
    col = mixc(col, SPOT, spots(p, 30, 0.22, 5) * sat(n[:, 2] * 2 + 0.6) * (y < 0.4) * 0.85)
    # the cream breast, streaked with small dark drops
    front = sat(-n[:, 2] * 2.5 + 0.2)
    breast = edge(1.0 - (x / 0.12) ** 2 - ((y - 0.25) / 0.2) ** 2 + fluff * 8, 0.05) * front * (y < 0.4)
    col = mixc(col, BUFF, edge(1.0 - (x / 0.15) ** 2 - ((y - 0.22) / 0.22) ** 2 + fluff * 6, 0.06) * front * 0.7)
    col = mixc(col, CREAM, breast)
    drops = spots(p * np.array([1.6, 0.8, 1.6]), 34, 0.16, 9) * breast * (y < 0.36) * (y > 0.12)
    col = mixc(col, RUST_DARK * 0.6, drops * 0.8)
    # the slate cap and nape over a cream face, the dark tear-stripe under each eye
    capline = 0.53 - (z + 0.2) * 0.45 - 0.045 * sat(1 - ax / 0.05) + fluff * 0.5     # a stern peak to the cere
    col = mixc(col, mixc(SLATE_DARK, SLATE_LIGHT, sat(n[:, 1] * 0.8 + 0.4)), edge(y - capline, 0.018) * (y > 0.36))
    col = mixc(col, CREAM_LIGHT, edge(-z - 0.1, 0.02) * edge(capline - y, 0.008) * (y > 0.37))
    for sx in (-1.0, 1.0):
        tear = edge(0.012 - np.abs(sx * x - 0.092 - (0.47 - y) * 0.15), 0.004) * edge(0.465 - y, 0.005)
        tear = tear * edge(y - 0.4, 0.008) * (z < -0.08)
        col = mixc(col, SLATE_DARK * 0.8, tear)
        q = (p - np.array([sx * 0.125, 0.42, 0])) / np.array([0.035, 0.022, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.4) * (z < -0.1) * 0.4)
    # bolt-shaped ear points: slate, yellow at the tip
    ear = np.minimum(prim["eartipL"].d(p), prim["eartipR"].d(p)) < 0.008
    col = mixc(col, mixc(SLATE, SPARK, sat((ax - 0.14) / 0.02)), ear)
    # yellow legs and toes, dark talons, rust trousers
    shank = np.minimum(prim["shankL"].d(p), prim["shankR"].d(p))
    toes = np.min([prim["toe%s%d" % (sd, j)].d(p) for sd in "LR" for j in range(4)], axis=0)
    leg = edge(0.004 - np.minimum(shank, toes), 0.003) * (y < 0.07)
    col = mixc(col, mixc(FOOT * 0.8, FOOT, sat(n[:, 1] * 0.5 + 0.6)), leg)
    tips = np.zeros(len(p))
    for sd, sx in SIDES:
        for dx, dz in TOES:
            tip = ankle(sx) + v3(sx * dx, -0.013, dz)
            tips = np.maximum(tips, edge(0.011 - np.linalg.norm(p - tip, axis=1), 0.003))
    return mixc(col, TALON, tips)


def paint_wings(q, n):
    col = np.zeros((len(q), 3))
    for sd, sx in SIDES:
        m = q[:, 0] * sx > 0
        if not m.any():
            continue
        fr = wing_frame(sx)
        rel = q[m] - SHOULDER * v3(sx, 1, 1)
        s, c = rel @ fr[0], -(rel @ fr[1])
        k = mixc(np.tile(RUST, (len(s), 1)), RUST_DARK, sat(c / 0.12) * 0.5)
        k = mixc(k, SPOT, spots(q[m], 28, 0.2, 3) * (s < 0.15) * 0.85)
        # slate flight feathers with dark edges, pale bars near the tips
        flight = sat((s - 0.13) / 0.03)
        k = mixc(k, mixc(SLATE, FLIGHT, sat((s - 0.2) / 0.1)), flight)
        k = mixc(k, FLIGHT * 0.7, edge(np.sin(s * 120 + c * 40) - 0.7, 0.1) * flight * 0.6)
        col[m] = mixc(k, SLATE_LIGHT, sat(1 - c / 0.02) * 0.4 * (s < 0.14))
    return col


def paint_tail(q, n):
    t = (TAIL_PTS[0][1] - q[:, 1]) / (TAIL_PTS[0][1] - TAIL_PTS[2][1])
    col = mixc(np.tile(SLATE, (len(q), 1)), SLATE_LIGHT, sat(n[:, 1] * 0.6 + 0.3) * 0.5)
    col = mixc(col, SPOT, edge(0.06 - np.abs(t - 0.82), 0.02))     # the kestrel's black band
    return mixc(col, CREAM_LIGHT, sat((t - 0.92) / 0.04))


def paint_rod(q, n):
    h = np.array([-0.35, 0.8, -0.48])
    spec = sat((n @ (h / np.linalg.norm(h)) - 0.75) / 0.2)
    col = mixc(np.tile(COPPER_DARK, (len(q), 1)), COPPER, sat(n[:, 1] * 0.5 + 0.7))
    col = mixc(col, COPPER_LIGHT, spec)
    # a verdigris tarnish at the collar
    return mixc(col, hexc("5aa08a"), edge(ROD[0][1] + 0.012 - q[:, 1], 0.004) * 0.6)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "wings":
        return paint_wings(q, nn)
    if pc.name == "tail":
        return paint_tail(q, nn)
    if pc.name == "rod":
        return paint_rod(q, nn)
    if pc.name == "beak":
        col = mixc(np.tile(CERE, (len(q), 1)), BILL, edge(BEAK[0][2] - 0.022 - q[:, 2], 0.004))
        return mixc(col, BILL_TIP, sat((-q[:, 2] - 0.255) / 0.015))
    if pc.name in GLOW_PIECES:
        return np.tile(SPARK, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(SPARK, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)

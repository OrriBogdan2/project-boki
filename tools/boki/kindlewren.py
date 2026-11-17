"""Kindlewren, a round little wren with a live coal on its cocked-up tail: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #10), owner approval pending."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
BODY_C = v3(0, 0.205, 0.035)
BODY_R = v3(0.178, 0.148, 0.182)
CHEST_C = v3(0, 0.24, -0.045)
CHEST_R = v3(0.158, 0.13, 0.14)
HEAD_C = v3(0, 0.41, -0.065)
HEAD_R = v3(0.19, 0.165, 0.17)
EYE_C = v3(0.08, 0.43, -0.192)
EYE_R = v3(0.052, 0.056, 0.032)
EYE_YAW = 0.36
GLOW_PIECES = ("blaze",)
LIT_PIECES = ("coal",)
BERRY_C = v3(0, 0.05, -0.28)
FACE = {"mouth_w": 0.03, "mouth_y": 0.35, "mouth_z": -0.24, "cat_mouth": False, "brow_x": 0.082, "brow_up": 0.013,
        "brow_k": 0.78, "fang_k": 0.0}
BEAK = (v3(0, 0.385, -0.21), v3(0, 0.372, -0.28), v3(0, 0.357, -0.312))
SHOULDER = v3(0.165, 0.3, -0.035)
TAIL_PTS = [v3(0, 0.26, 0.17), v3(0, 0.4, 0.25), v3(0, 0.54, 0.272)]
COAL_C = v3(0, 0.585, 0.268)
COAL_R = v3(0.06, 0.056, 0.054)
# the cowlick: two licks of flame off the crown, one behind the other
TUFTS = {"L": ((-0.01, 0.55, -0.1), (-0.024, 0.668, -0.13)), "R": ((0.012, 0.555, -0.045), (0.028, 0.648, -0.07))}
TOES = ((0.03, -0.05), (0.0, -0.06), (-0.028, -0.046), (0.004, 0.038))    # dx, dz from the ankle: three on, one back


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.08, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def wing_frame(sx):
    """Rows: along the folded wing (back and a little down), up to its leading edge, out of it."""
    span = v3(sx * 0.12, -0.3, 1.0)
    span /= np.linalg.norm(span)
    out = v3(sx, 0.25, 0.0)
    out -= span * (out @ span)
    out /= np.linalg.norm(out)
    return np.stack([span, np.cross(span, out) * sx, out])


def on_wing(sx, s, c):
    """A point of the folded wing: s back along it from the shoulder, c down its chord."""
    fr = wing_frame(sx)
    return SHOULDER * v3(sx, 1, 1) + fr[0] * s - fr[1] * c


def ankle(sx):
    return v3(sx * 0.082, 0.026, -0.012)


def body_prims():
    p = [
        Ellipsoid("body", "hips", BODY_C, BODY_R, k=0.03),
        Ellipsoid("chest", "spine", CHEST_C, CHEST_R, k=0.06),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.045),
    ]
    for sd, sx in SIDES:
        p.append(Ellipsoid("cheek" + sd, "head", v3(sx * 0.105, 0.37, -0.13), v3(0.08, 0.065, 0.075), k=0.04))
        # a cheeky cowlick: two little feathers flicked up off the crown
        a, b = TUFTS[sd]
        p.append(Cone("tuft" + sd, "ear1." + sd, v3(*a), v3(*b), 0.036, 0.004, k=0.03, flat=0.45,
                      flat_axis=v3(1, 0, 0)))
        hip = v3(sx * 0.076, 0.13, 0.015)
        knee = v3(sx * 0.08, 0.075, -0.004)
        p.append(Cone("thigh" + sd, "hleg1." + sd, hip, knee, 0.045, 0.026, k=0.03))
        p.append(Cone("shank" + sd, "hleg2." + sd, knee, ankle(sx), 0.016, 0.014, k=0.01))
        for j, (dx, dz) in enumerate(TOES):
            tip = ankle(sx) + v3(sx * dx, -0.013, dz)
            p.append(Cone("toe%s%d" % (sd, j), "hpaw." + sd, ankle(sx) + v3(0, -0.006, 0), tip, 0.012, 0.007,
                          k=0.007))
    return p


def wing_prims():
    out = []
    for sd, sx in SIDES:
        fr = wing_frame(sx)
        out += [Ellipsoid("cov" + sd, "wing1." + sd, on_wing(sx, 0.07, 0.045), v3(0.095, 0.075, 0.014), rot=fr,
                          k=0.02),
                Ellipsoid("prim" + sd, "wing2." + sd, on_wing(sx, 0.15, 0.055), v3(0.085, 0.056, 0.011), rot=fr,
                          k=0.03)]
    # the wings stop under the skin, so none of their ink shows through the body
    out += [Ellipsoid("cut" + nm, "spine", c, r - 0.016, k=0.004, sub=True)
            for nm, c, r in (("body", BODY_C, BODY_R), ("chest", CHEST_C, CHEST_R))]
    return out


def tail_prims():
    out = []
    for i in range(2):
        a, b = TAIL_PTS[i], TAIL_PTS[i + 1]
        d = b - a
        n = v3(0, -d[2], d[1])
        out.append(Cone("tail%d" % i, "tail%d" % (i + 1), a, b, (0.045, 0.066)[i], (0.066, 0.06)[i], k=0.02, flat=0.55,
                        flat_axis=n))
    return out


def beak_prims():
    a, b, c = BEAK
    return [Cone("beak0", "head", a, b, 0.024, 0.012, k=0.006), Cone("beak1", "head", b, c, 0.012, 0.003, k=0.006)]


def blaze_prims():
    """Flames off the coal while it dashes: tongues running on along the tail, streaming back as it lays it flat."""
    out = [Ellipsoid("bz", "prop_blaze", COAL_C + v3(0, 0.01, 0.01), COAL_R * 1.45, k=0)]
    for i, (dx, up, back, r) in enumerate(((0.0, 0.19, 0.03, 0.045), (-0.045, 0.12, 0.0, 0.032),
                                           (0.045, 0.13, 0.04, 0.032))):
        out.append(Cone("bt%d" % i, "prop_blaze", COAL_C + v3(dx * 0.4, 0.02, 0.0),
                        COAL_C + v3(dx, up, back), r, 0.004, k=0.02))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0032, 4600),
        "wings": (Shape(wing_prims()), 0.003, 900),
        "tail": (Shape(tail_prims()), 0.003, 520),
        "coal": (Shape([Ellipsoid("coal", "tail2", COAL_C, COAL_R, k=0)]), 0.003, 300),
        "beak": (Shape(beak_prims()), 0.0022, 140),
    }


AXIS = np.array((0.0, 0.42, -0.907))
GRIP = v3(0, 0.355, -0.27)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 90)
    out["blaze"] = (Shape(blaze_prims()), 0.003, 260)
    return out


GROWN = {
    "horn": ((0.08, 0.53, -0.13), (0.14, 0.65, -0.18), 0.032),
    "fang": ((0.012, 0.348, -0.226), (0.014, 0.318, -0.228), 0.011),
    "antenna": ((0.05, 0.55, -0.08), (0.11, 0.69, -0.05), 0.012),
    "brow": ((0.015, 0.488, -0.2), (0.12, 0.5, -0.157), 0.018),
    "head_top": (0, 0.575, -0.065), "fang_at": (0, 0.35, -0.22), "brow_at": (0, 0.49, -0.2),
    "third_eye": (0, 0.52, -0.188),
    "back": ((0, 0.47, 0.08), (0, 0.41, 0.12), (0, 0.36, 0.14)), "back_at": (0, 0.41, 0.1), "plates": (0, 0.39, 0.1),
    "plate_r": (0.12, 0.05, 0.07), "shell_c": (0, 0.25, 0.08), "shell_r": (0.18, 0.15, 0.08), "tail_bone": "tail2",
    "club_at": tuple(COAL_C), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[1]), "club_r": 0.07,
    "spots": ((0.17, 0.2, 0.0, 0.022), (0.162, 0.15, 0.06, 0.02), (0.125, 0.11, 0.1, 0.018)),
    "spots_at": (0, 0.2, 0.03),
    "wing": ((0.15, 0.3, 0.04), (0.26, 0.37, 0.14), (0.24, 0.31, 0.18)), "wing_at": (0, 0.3, 0.04),
    "fin": ((0.15, 0.15, 0.1), (0.2, 0.25, 0.2)), "fin_at": (0, 0.16, 0.1), "crest": (0.56, -0.12, 0.06, 0.07),
    "crest_at": (0, 0.56, -0.1),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
BROWN = hexc("7a4a32")
BROWN_LIGHT = hexc("a06a44")
BROWN_DARK = hexc("54301e")
BAR = hexc("3e2216")
BUFF = hexc("d7a978")
CREAM = hexc("f2d3a8")
CREAM_LIGHT = hexc("fbe8cc")
WING = hexc("5a3a2a")
WING_BAR = hexc("c8925e")
EMBER = hexc("ff8a2a")
EMBER_HOT = hexc("ffd25a")
COAL = hexc("3a1a14")
COAL_RED = hexc("b8321a")
CHAR = hexc("2e1a14")
BEAK_DARK = hexc("3a2a24")
BEAK_LIGHT = hexc("8a6a58")
LEG = hexc("c88a72")
BLUSH = hexc("ff8a6a")
LILAC = hexc("fbe2b8")     # brows: pale, the wren's eyebrow stripe, to read on the dark head
LID = BROWN_LIGHT / 1.13
INK = hexc("2e1a12")
MOUTH_DARK = hexc("5a2218")
TONGUE = hexc("f0806a")
IRIS = hexc("e08a2e")
IRIS_DEEP = hexc("5a2810")
SHELL_A = hexc("d7a978")
SHELL_B = hexc("8a5634")
SHELL_C = hexc("4a2a1c")


def bars(t, freq, width=0.3):
    """Thin dark bars across a feather run, the wren's fine barring."""
    return edge(np.sin(t * freq) - (1 - width * 2), 0.12)


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    fluff = (value_noise(p * np.array([70, 40, 70])) - 0.5) * 0.02
    col = mixc(BROWN_DARK, BROWN, sat(n[:, 1] * 0.7 + 0.75 + fluff * 10))
    col = mixc(col, BROWN_LIGHT, sat(n[:, 1] * 1.4 - 0.75) * 0.7)
    front = sat(-n[:, 2] * 2.5 + 0.2)
    # the cream breast and belly, buff where it meets the brown flanks
    belly = edge(1.0 - (x / 0.115) ** 2 - ((y - 0.2) / 0.16) ** 2 + fluff * 8, 0.05) * front * (y < 0.33)
    col = mixc(col, BUFF, edge(1.0 - (x / 0.17) ** 2 - ((y - 0.18) / 0.19) ** 2 + fluff * 6, 0.06) * front * 0.8)
    col = mixc(col, CREAM, belly)
    col = mixc(col, CREAM_LIGHT, belly * sat((0.24 - np.abs(y - 0.22)) * 3) * 0.4)
    # fine dark barring on the back and the flanks
    back = sat(n[:, 2] * 2 + 0.3) * (y < 0.5) * (1 - belly)
    col = mixc(col, BAR, bars(y * 1.0 + z * 0.3 + fluff, 230, 0.15) * back * 0.35)
    # the face: a pale eyebrow stripe sweeping back over each eye, a dark line through it, a cream throat
    head = (y > 0.3) & (z < 0.06)
    for sx in (-1.0, 1.0):
        u = (z + 0.19) / 0.2
        stripe_y = 0.478 + u * 0.012
        taper = 0.009 * sat(1.2 - u)
        stripe = edge(taper - np.abs(y - stripe_y + fluff * 0.3), 0.003) * edge(sx * x - 0.1, 0.01) * (u < 1.2)
        col = mixc(col, CREAM_LIGHT, stripe * head)
        line = edge(0.008 - np.abs(y - (0.418 + u * 0.012)), 0.004) * (sx * x > 0.12) * (u > 0.25) * (u < 1.1)
        col = mixc(col, BROWN_DARK, line * head * 0.85)
        q = (p - np.array([sx * 0.122, 0.355, 0])) / np.array([0.038, 0.024, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.4) * (z < -0.1) * 0.55)
    throat = edge(1.0 - (x / 0.07) ** 2 - ((y - 0.31) / 0.05) ** 2, 0.1) * (z < -0.12)
    col = mixc(col, CREAM, throat)
    # the cowlick: brown with a flame of ember at its tips
    tuft = np.minimum(prim["tuftL"].d(p), prim["tuftR"].d(p)) < 0.01
    col = mixc(col, mixc(BROWN_LIGHT, EMBER, sat((y - 0.57) / 0.05)), tuft * sat((y - 0.54) / 0.02))
    # pinkish-brown legs and toes, the thighs fluffed buff
    shank = np.minimum(prim["shankL"].d(p), prim["shankR"].d(p))
    toes = np.min([prim["toe%s%d" % (sd, j)].d(p) for sd in "LR" for j in range(4)], axis=0)
    leg = edge(0.004 - np.minimum(shank, toes), 0.003) * (y < 0.075)
    col = mixc(col, mixc(LEG * 0.75, LEG, sat(n[:, 1] * 0.5 + 0.6)), leg)
    thigh = np.minimum(prim["thighL"].d(p), prim["thighR"].d(p))
    return mixc(col, BUFF, edge(0.004 - thigh, 0.004) * (y < 0.12) * (y > 0.06) * 0.8)


def paint_wings(q, n):
    col = np.zeros((len(q), 3))
    for sd, sx in SIDES:
        m = q[:, 0] * sx > 0
        if not m.any():
            continue
        fr = wing_frame(sx)
        rel = q[m] - SHOULDER * v3(sx, 1, 1)
        s, c = rel @ fr[0], -(rel @ fr[1])
        k = mixc(np.tile(BROWN, (len(s), 1)), WING, sat((s - 0.04) / 0.08))
        k = mixc(k, BROWN_LIGHT, sat(1 - c / 0.03) * 0.5 * (s < 0.12))
        # buff bars across the flight feathers, a dark edge on each
        k = mixc(k, WING_BAR, bars(s + c * 0.25, 210, 0.16) * sat((s - 0.05) / 0.03) * 0.65)
        col[m] = mixc(k, BAR, sat((s - 0.2) / 0.04) * 0.6)
    return col


def paint_tail(q, n):
    t = (q[:, 1] - TAIL_PTS[0][1]) / (TAIL_PTS[2][1] - TAIL_PTS[0][1])
    col = mixc(np.tile(BROWN, (len(q), 1)), WING, sat(t))
    col = mixc(col, BAR, bars(q[:, 1] - np.abs(q[:, 0]) * 0.4, 150, 0.22) * 0.75 * (t < 0.82))
    col = mixc(col, BROWN_LIGHT, edge(0.006 - np.abs(np.abs(q[:, 0]) - 0.018), 0.003) * 0.3)    # the feather shafts
    # singed toward the coal: charred, then a rim of ember where it holds it
    col = mixc(col, CHAR, sat((t - 0.78) / 0.12))
    return mixc(col, COAL_RED, sat((t - 0.93) / 0.06) * 0.7)


def paint_coal(q, n):
    """A live coal: glowing ember in the cracks between dark crusted plates, hottest on top."""
    rel = q - COAL_C
    cells = value_noise(q * 80, seed=11)
    crack = edge(0.12 - np.abs(cells - 0.5), 0.04)
    hot = mixc(np.tile(EMBER, (len(q), 1)), EMBER_HOT, sat(rel[:, 1] / 0.04 + 0.3))
    crust = mixc(np.tile(COAL, (len(q), 1)), COAL_RED, sat(cells * 1.3 - 0.4))
    plate = edge(cells - 0.66, 0.03) * sat(0.6 - rel[:, 1] / 0.08)
    return mixc(mixc(hot, crust, plate * 0.9), EMBER_HOT, crack * 0.6)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "wings":
        return paint_wings(q, nn)
    if pc.name == "tail":
        return paint_tail(q, nn)
    if pc.name == "coal":
        return paint_coal(q, nn)
    if pc.name == "beak":
        return mixc(np.tile(BEAK_DARK, (len(q), 1)), BEAK_LIGHT, sat((-q[:, 1] + 0.37) / 0.03) * 0.6)
    if pc.name == "blaze":
        return np.tile(EMBER_HOT, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(EMBER, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)

"""Lunowl (wisplet), a round moonlit owl with luna-moth wings: shapes and coat. Game axes as vespyx.py."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
BODY_C = v3(0, 0.235, 0.02)
BODY_R = v3(0.195, 0.185, 0.18)
CHEST_C = v3(0, 0.315, -0.03)
CHEST_R = v3(0.185, 0.15, 0.165)
HEAD_C = v3(0, 0.445, -0.035)
HEAD_R = v3(0.225, 0.175, 0.185)
EYE_C = v3(0.088, 0.462, -0.178)
EYE_R = v3(0.05, 0.055, 0.032)
EYE_YAW = 0.3
GLOW_PIECES = ("dazzle",)
BERRY_C = v3(0, 0.05, -0.36)
FACE = {"mouth_w": 0.03, "mouth_y": 0.398, "mouth_z": -0.24, "cat_mouth": False, "brow_x": 0.09, "brow_up": 0.02,
        "brow_k": 1.0, "fang_k": 0.0}
SHOULDER = v3(0.11, 0.41, 0.12)
ANTENNA_ROOT = v3(0.045, 0.6, -0.09)
WING_N = (0.3, 0.55, -0.78)      # the wing's facing, right side
WING_SPAN = (0.62, 0.75, 0.25)   # its leading edge, out and up
TAIL_PTS = [v3(0, 0.19, 0.16), v3(0, 0.12, 0.27)]
EYESPOTS = (("prop_dazzle.", 0.2, 0.03, 0.034), ("prop_dazzleh.", 0.075, 0.15, 0.036))   # bone, s, c, radius
DISC_C = (0.088, 0.452)     # the facial disc: one round of pale feathers about each eye
DISC_R = (0.108, 0.1)


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.08, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def wing_frame(sx):
    """Rows: along the leading edge, along the chord (down the wing), through it. The wings lean back over the
    shoulders like a little cape, so both the close cameras and the high match camera see their faces."""
    through = v3(sx * WING_N[0], WING_N[1], WING_N[2])
    through /= np.linalg.norm(through)
    span = v3(sx * WING_SPAN[0], WING_SPAN[1], WING_SPAN[2])
    span -= through * (span @ through)
    span /= np.linalg.norm(span)
    chord = np.cross(through, span)
    if chord[1] > 0:
        chord = -chord
    return np.stack([span, chord, through])


def on_wing(sx, s, c, at=SHOULDER, k=1.0):
    """A point of the wing's plane: s along the leading edge, c back along the chord from the shoulder `at`; the
    Fusion wears the same wings `k` times as big."""
    fr = wing_frame(sx)
    return at * v3(sx, 1, 1) + (fr[0] * s + fr[1] * c) * k


def streamer_pts(sx, at=SHOULDER, k=1.0):
    """The luna moth's long hind-wing tail: off the hind wing, trailing back and down behind its flank."""
    a = on_wing(sx, 0.065, 0.22, at, k)
    b = a + v3(sx * 0.022, -0.055, 0.075) * k
    c = b + v3(sx * 0.012, -0.05, 0.075) * k
    d = c + v3(sx * -0.004, -0.04, 0.06) * k
    return [a, b, c, d]


def body_prims():
    p = [
        Ellipsoid("body", "hips", BODY_C, BODY_R, k=0.03),
        Ellipsoid("chest", "spine", CHEST_C, CHEST_R, k=0.06),
        Ellipsoid("ruff", "neck", v3(0, 0.385, -0.01), v3(0.2, 0.08, 0.17), k=0.06),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.07),
    ]
    for sd, sx in SIDES:
        n = v3(sx * 0.25, 0, -1.0)
        bone = "ear1." + sd
        p.append(Cone("tuft" + sd, bone, v3(sx * 0.125, 0.565, -0.075), v3(sx * 0.215, 0.70, -0.04), 0.052, 0.004,
                      k=0.03, flat=0.45, flat_axis=n))
        p.append(Cone("tuftb" + sd, bone, v3(sx * 0.10, 0.57, -0.07), v3(sx * 0.14, 0.665, -0.035), 0.036, 0.003,
                      k=0.02, flat=0.45, flat_axis=n))
        # feathered legs, short: a fluffy thigh, a bare shank, three toes forward and one back
        hip = v3(sx * 0.085, 0.15, 0.0)
        knee = v3(sx * 0.09, 0.075, -0.015)
        ankle = v3(sx * 0.092, 0.026, -0.02)
        p.append(Cone("thigh" + sd, "hleg1." + sd, hip, knee, 0.052, 0.036, k=0.03))
        p.append(Cone("shank" + sd, "hleg2." + sd, knee, ankle, 0.022, 0.019, k=0.012))
        for j, (dx, dz) in enumerate(((0.032, -0.05), (0.0, -0.062), (-0.03, -0.048), (0.004, 0.04))):
            tip = ankle + v3(sx * dx, -0.012, dz)
            p.append(Cone("toe%s%d" % (sd, j), "hpaw." + sd, ankle + v3(0, -0.006, 0), tip, 0.016, 0.009, k=0.008))
    for i, dx in enumerate((-0.045, 0.0, 0.045)):
        a, b = TAIL_PTS
        p.append(Cone("tail%d" % i, "tail1", a + v3(dx * 0.3, 0, 0), b + v3(dx, 0.0, 0.012 * (i == 1)), 0.034, 0.02,
                      k=0.008, flat=0.4, flat_axis=v3(0, 1, 0.4)))
    return p


def flat_ellipse(name, bone, sx, s, c, size, tilt, at, k):
    """An ellipse (semi-axes `size`) lying in the wing's plane, `tilt` turning it from the leading edge toward the
    chord."""
    fr = wing_frame(sx)
    ct, st = math.cos(tilt), math.sin(tilt)
    rot = np.stack([fr[0] * ct + fr[1] * st, -fr[0] * st + fr[1] * ct, fr[2]])
    return Ellipsoid(name, bone, on_wing(sx, s, c, at, k), v3(size[0], size[1], 0.009) * k, rot=rot, k=0.02 * k)


def wing_prims(at=SHOULDER, k=1.0):
    out = []
    for sd, sx in SIDES:
        out += [flat_ellipse("fore" + sd, "fwing." + sd, sx, 0.17, 0.03, (0.17, 0.08), 0.1, at, k),
                flat_ellipse("apex" + sd, "fwing." + sd, sx, 0.3, -0.005, (0.065, 0.04), -0.2, at, k),
                flat_ellipse("hind" + sd, "hwing." + sd, sx, 0.07, 0.15, (0.095, 0.085), 0.9, at, k)]
        pts = streamer_pts(sx, at, k)
        fr = wing_frame(sx)
        for i in range(3):
            a, b = pts[i], pts[i + 1]
            d = b - a
            w = (0.024, 0.016, 0.013)[i] * k
            out.append(Ellipsoid("strm%s%d" % (sd, i), ("strm1." if i < 1 else "strm2.") + sd, (a + b) * 0.5,
                                 v3(w, 0.008 * k, np.linalg.norm(d) * 0.62), rot=frame(d, fr[2]), k=0.02 * k))
        out.append(Ellipsoid("paddle" + sd, "strm2." + sd, pts[3], v3(0.03, 0.008, 0.042) * k,
                             rot=frame(pts[3] - pts[2], fr[2]), k=0.02 * k))
    return out


def body_cut():
    """The wings stop well under the skin: a wing running just below it would show its ink through the body."""
    return [Ellipsoid("cut" + nm, "spine", c, r - 0.018, k=0.004, sub=True)
            for nm, c, r in (("body", BODY_C, BODY_R), ("chest", CHEST_C, CHEST_R), ("head", HEAD_C, HEAD_R))]


def antenna_pts(sx, at=ANTENNA_ROOT, k=1.0):
    a = at * v3(sx, 1, 1)
    return [a, a + v3(sx * 0.035, 0.1, -0.035) * k, a + v3(sx * 0.13, 0.165, -0.03) * k]


def antenna_prims(at=ANTENNA_ROOT, k=1.0):
    out = []
    for sd, sx in SIDES:
        a, b, c = antenna_pts(sx, at, k)
        bone = "ant." + sd
        out += [Cone("stalk%s0" % sd, bone, a, b, 0.009 * k, 0.008 * k, k=0.01 * k),
                Cone("stalk%s1" % sd, bone, b, c, 0.008 * k, 0.006 * k, k=0.01 * k)]
        # the feathery comb: a slim vane along the outer half of the stalk, its barbs combed toward the tip
        d = c - a
        fr = frame(d, v3(0, 0, -1))
        out.append(Ellipsoid("comb" + sd, bone, a + d * 0.62, v3(0.014 * k, 0.005 * k, np.linalg.norm(d) * 0.4), rot=fr,
                             k=0.008 * k))
        for i in range(5):
            on = a + d * (0.36 + 0.12 * i)
            reach = (0.03 - 0.003 * abs(i - 1.5)) * k
            for side in (-1.0, 1.0):
                tip = on + fr[0] * side * reach + d * 0.12
                out.append(Cone("barb%s%d%d" % (sd, i, side > 0), bone, on, tip, 0.006 * k, 0.0035 * k, k=0.004 * k))
    return out


BEAK = (v3(0, 0.43, -0.2), v3(0, 0.402, -0.238), v3(0, 0.372, -0.24))


def beak_prims():
    a, b, c = BEAK
    return [Cone("beak0", "head", a, b, 0.027, 0.015, k=0.006), Cone("beak1", "head", b, c, 0.015, 0.004, k=0.006)]


def dazzle_prims():
    """Silver light over the wings' eye-spots, shown only while it dazzles."""
    out = []
    for sd, sx in SIDES:
        fr = wing_frame(sx)
        for bone, s, c, r in EYESPOTS:
            out.append(Ellipsoid(bone + sd, bone + sd, on_wing(sx, s, c), v3(r * 1.3, r * 1.3, 0.016), rot=fr, k=0))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 1950),
        "wings": (Shape(wing_prims() + body_cut()), 0.003, 630),
        "antennae": (Shape(antenna_prims()), 0.0022, 235),
        "beak": (Shape(beak_prims()), 0.0025, 50),
    }


AXIS = np.array((0.0, 0.45, -0.893))
GRIP = v3(0, 0.385, -0.245)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    out["dazzle"] = (Shape(dazzle_prims()), 0.003, 220)
    return out


GROWN = {
    "horn": ((0.075, 0.585, -0.09), (0.13, 0.72, -0.15), 0.036), "fang": ((0.012, 0.385, -0.235), (0.014, 0.35, -0.238), 0.012),
    "antenna": ((0.06, 0.6, -0.04), (0.12, 0.76, -0.02), 0.012), "brow": ((0.015, 0.505, -0.208), (0.14, 0.535, -0.16), 0.017),
    "head_top": (0, 0.6, -0.06), "fang_at": (0, 0.39, -0.23), "brow_at": (0, 0.52, -0.2), "third_eye": (0, 0.555, -0.19),
    "back": ((0, 0.47, 0.11), (0, 0.38, 0.17), (0, 0.29, 0.19)), "back_at": (0, 0.38, 0.15), "plates": (0, 0.37, 0.15),
    "plate_r": (0.13, 0.05, 0.07), "shell_c": (0, 0.24, 0.02), "shell_r": (0.21, 0.19, 0.06), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[1]), "club_dir": tuple(TAIL_PTS[1] - TAIL_PTS[0]), "club_r": 0.05,
    "spots": ((0.185, 0.27, -0.02, 0.024), (0.19, 0.22, 0.06, 0.02), (0.17, 0.17, 0.12, 0.022)), "spots_at": (0, 0.22, 0.04),
    "wing": ((0.17, 0.26, 0.04), (0.27, 0.20, 0.13), (0.24, 0.16, 0.17)), "wing_at": (0, 0.26, 0.04),
    "fin": ((0.16, 0.16, 0.10), (0.21, 0.26, 0.2)), "fin_at": (0, 0.17, 0.1), "crest": (0.6, -0.12, 0.06, 0.07),
    "crest_at": (0, 0.6, -0.08),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
LAVENDER = hexc("d9d4f2")
LAVENDER_LIGHT = hexc("ece9fb")
LAVENDER_SHADE = hexc("bdb3ea")
LAVENDER_DARK = hexc("9487cf")
CREAM = hexc("fff8e6")
MOON = hexc("fff0a0")
WING = hexc("9fe6b4")
WING_LIGHT = hexc("d2f7dc")
WING_DARK = hexc("5fb98c")
PLUM = hexc("8c6cb8")
GOLD = hexc("f2c46a")
GOLD_DARK = hexc("c98f3a")
TALON = hexc("5c4a7a")
BLUSH = hexc("ffa0b4")
LILAC = hexc("7666b8")     # brows: dark enough to read on the pale disc
LID = CREAM / 1.13
INK = hexc("3a2f5c")
MOUTH_DARK = hexc("5a2a4a")
TONGUE = hexc("f08aa0")
IRIS = hexc("ffc83a")
SHELL_A = hexc("e6e0fa")
SHELL_B = hexc("b4aae0")
SHELL_C = hexc("7a6aae")


def disc(x, y):
    """Signed: below 0 inside the facial disc (front view x, y)."""
    out = None
    for sx in (-1.0, 1.0):
        d = np.hypot((x - sx * DISC_C[0]) / DISC_R[0], (y - DISC_C[1]) / DISC_R[1]) - 1.0
        out = d if out is None else np.minimum(out, d)
    return out * DISC_R[1]


def chevrons(x, y, rows):
    """Little V marks of the chest feathers, staggered row by row."""
    out = np.zeros(len(x))
    for i, ry in enumerate(rows):
        for cx in np.arange(-0.12, 0.13, 0.05) + (0.025 if i % 2 else 0.0):
            u = np.abs(x - cx)
            v = y - (ry - (0.014 - u) * 0.7)
            out = np.maximum(out, edge(0.0036 - np.abs(v), 0.0012) * edge(0.014 - u, 0.002))
    return out


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    fluff = (value_noise(p * np.array([70, 40, 70])) - 0.5) * 0.02
    col = mixc(LAVENDER_SHADE, LAVENDER, sat(n[:, 1] * 0.8 + 0.55 + fluff * 10))
    col = mixc(col, LAVENDER_LIGHT, sat(n[:, 1] * 1.5 - 0.7))
    front = sat(-n[:, 2] * 3 - 0.3) * (z < -0.02)
    # the cream belly, scalloped with lavender chevrons
    belly = edge(1.0 - (x / 0.15) ** 2 - ((y - 0.215) / 0.17) ** 2 + fluff * 8, 0.04) * front
    col = mixc(col, CREAM, belly)
    col = mixc(col, LAVENDER_DARK, chevrons(x, y, (0.16, 0.2, 0.24, 0.28)) * belly * 0.85)
    # the facial disc: pale rounds about the eyes with a darker ruff at their rim, dipping to a V over the beak
    dd = disc(x, y) + fluff * 0.3
    face = sat(-n[:, 2] * 4 - 0.6) * (z < -0.1)
    col = mixc(col, LAVENDER_DARK, edge(0.016 - np.abs(dd + 0.004), 0.004) * face)
    col = mixc(col, CREAM, edge(-0.004 - dd, 0.003) * face)
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.125, 0.405, 0])) / np.array([0.04, 0.024, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.3) * face * 0.6)
    # a crescent moon on the crown, for the high cameras
    top = sat(n[:, 1] * 3 - 1.2)
    moon = edge(0.036 - np.hypot(x, z + 0.075), 0.003) * edge(np.hypot(x - 0.018, z + 0.09) - 0.03, 0.003)
    col = mixc(col, MOON, moon * top)
    # moondust: a few pale specks on the back
    speck = sat((value_noise(p * 55, seed=3) - 0.8) / 0.04) * sat(n[:, 2] * 2) * (y > 0.2)
    col = mixc(col, LAVENDER_LIGHT * 1.05, speck * 0.8)
    # tufts with dark tips; feathered thighs; gold shanks and toes, dark talon tips
    tuft = np.minimum(prim["tuftL"].d(p), prim["tuftR"].d(p)) < 0.012
    col = mixc(col, LAVENDER_DARK * 0.85, edge(y - 0.655 + fluff, 0.01) * tuft)
    shank = np.minimum(prim["shankL"].d(p), prim["shankR"].d(p))
    toes = np.min([prim["toe%s%d" % (sd, j)].d(p) for sd in "LR" for j in range(4)], axis=0)
    gold = edge(0.004 - np.minimum(shank, toes), 0.003) * (y < 0.08)
    col = mixc(col, mixc(GOLD_DARK, GOLD, sat(n[:, 1] * 0.5 + 0.6)), gold)
    tips = np.zeros(len(p))
    for sd, sx in SIDES:
        for j, (dx, dz) in enumerate(((0.032, -0.05), (0.0, -0.062), (-0.03, -0.048), (0.004, 0.04))):
            tip = v3(sx * (0.092 + dx), 0.014, -0.02 + dz)
            tips = np.maximum(tips, edge(0.013 - np.linalg.norm(p - tip, axis=1), 0.003))
    col = mixc(col, TALON, tips)
    thigh = np.minimum(prim["thighL"].d(p), prim["thighR"].d(p))
    col = mixc(col, CREAM * 0.97, edge(0.004 - thigh, 0.004) * (y < 0.14) * (y > 0.06))
    tail = np.min([prim["tail%d" % i].d(p) for i in range(3)], axis=0) < 0.006
    bars = edge(np.sin(z * 150) - 0.55, 0.15) * tail * (z > 0.2)
    return mixc(col, LAVENDER_DARK, bars * 0.8)


def paint_wings(q, at=SHOULDER, k=1.0):
    col = np.zeros((len(q), 3))
    for sd, sx in SIDES:
        m = q[:, 0] * sx > 0
        if not m.any():
            continue
        fr = wing_frame(sx)
        rel = (q[m] - at * v3(sx, 1, 1)) / k
        s, c = rel @ fr[0], rel @ fr[1]
        far = np.hypot(s, c)
        ang = np.arctan2(c, s)
        wc = mixc(WING_LIGHT, WING, sat(far / 0.26))
        wc = mixc(wc, WING_DARK, sat((far - 0.24) / 0.1) * 0.6)
        veins = edge(0.06 - np.abs(np.sin(ang * 7.0)), 0.03) * sat((far - 0.06) / 0.06) * (far < 0.33)
        wc = mixc(wc, WING_DARK, veins * 0.35)
        # the margin glows faintly gold, the leading edge carries a plum stripe up to the shoulder
        margin = sat((far - 0.29) / 0.05) * (c < 0.08)
        wc = mixc(wc, mixc(WING, MOON, np.full(len(s), 0.6)), margin * 0.5)
        costa = edge(-0.024 - c + s * 0.06, 0.005) * (s < 0.27)
        wc = mixc(wc, PLUM, costa)
        wc = mixc(wc, WING_LIGHT, sat((c - 0.3) / 0.12) * 0.7)      # the tails pale toward their tips
        for _, s0, c0, r in EYESPOTS:
            d = np.hypot(s - s0, c - c0) / r      # eye-spot rings, outside in: green, moon gold, plum, a pale window
            ring = mixc(np.tile(WING_DARK * 0.8, (len(s), 1)), MOON, edge(0.86 - d, 0.05))
            ring = mixc(ring, PLUM, edge(0.62 - d, 0.05))
            ring = mixc(ring, CREAM, edge(0.3 - d, 0.05))
            wc = mixc(wc, ring, edge(1.0 - d, 0.06))
        col[m] = wc
    return col


def paint_antennae(q, at=ANTENNA_ROOT, k=1.0):
    fine = np.zeros(len(q))
    for _, sx in SIDES:
        a, _, c = antenna_pts(sx, at, k)
        d = c - a
        t = ((q - a) @ d) / (d @ d)
        fine = np.maximum(fine, edge(np.sin(t * 90) - 0.2, 0.3) * (q[:, 0] * sx > 0) * (t > 0.3))
    return mixc(np.tile(mixc(GOLD, CREAM, np.full(1, 0.45))[0], (len(q), 1)), CREAM, fine * 0.6)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "wings":
        return paint_wings(q)
    if pc.name == "antennae":
        return paint_antennae(q)
    if pc.name == "beak":
        return mixc(np.tile(GOLD_DARK, (len(q), 1)), GOLD, sat(nn[:, 1] * 0.8 + 0.5))
    if pc.name == "dazzle":
        return np.tile(MOON, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(MOON, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)

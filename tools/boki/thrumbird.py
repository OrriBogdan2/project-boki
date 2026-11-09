"""Thrumbird (thrumbird), a tiny emerald hummingbird whose tail is a silver tuning fork: shapes and coat. Game axes as
vespyx.py. Modelled perched (feet on the ground); its clips lift it into a hover."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
BODY_C = v3(0, 0.215, 0.05)
BODY_R = v3(0.112, 0.118, 0.152)
BODY_AXIS = v3(0, 0.42, -0.9)      # the body's long axis, tail to chest: it sits a little upright, as perched
CHEST_C = v3(0, 0.28, -0.035)
CHEST_R = v3(0.118, 0.112, 0.11)
HEAD_C = v3(0, 0.44, -0.06)
HEAD_R = v3(0.178, 0.16, 0.165)
EYE_YAW = 0.44
EYE_R = v3(0.048, 0.052, 0.03)
BEAK_ROOT = v3(0, 0.415, -0.205)
BEAK_TIP = v3(0, 0.39, -0.46)
SHOULDER = v3(0.1, 0.335, 0.0)
WING_TIP = v3(0.40, 0.45, 0.10)      # the wing at rest: out, up and a little back, where its beat sweeps
FAN_DROP = 0.022                     # m the blur sits under the wing, so the two never fight for depth
TAIL_ROOT = v3(0, 0.18, 0.15)
YOKE = v3(0, 0.14, 0.275)            # the fork's bend, where the hum lives
PRONG_X = 0.036
PRONG_END = v3(0.04, 0.112, 0.46)
RING_C = v3(0, 0.24, 0.02)
RING_RADII = (0.27, 0.40, 0.53)      # m: the hum rings, shown one after another as a pulse
GLOW_PIECES = ("hum",)
LIT_PIECES = ("blur", "rings")       # painted, unlined, lit from within: the wing blur and the hum
PALE_PIECES = ("blur", "rings", "fork")
BERRY_C = v3(0, 0.04, -0.47)
FACE = {"mouth_w": 0.042, "mouth_y": 0.372, "mouth_z": -0.21, "cat_mouth": False, "brow_x": 0.078, "brow_up": 0.016,
        "brow_k": 0.72, "fang_k": 0.0}
GRIP = v3(0, 0.03, -0.035)           # tools are held in its feet
AXIS = np.array((0.0, 0.25, -0.968))


def _eye_dir(sx):
    return v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))


def _on_head(d, depth):
    """The point `depth` of the way from the head's centre to its skin, along d."""
    d = d / np.linalg.norm(d)
    return HEAD_C + d * depth / np.linalg.norm(d / HEAD_R)


EYE_C = _on_head(_eye_dir(1.0), 0.86)


def eye_frame(sx):
    fr = frame(_eye_dir(sx), v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def mir(p, sx):
    return v3(p[0] * sx, p[1], p[2])


def wing_frame(sx):
    """Rows: across the wing (chord, toward the back), through it, along it (span)."""
    span = mir(WING_TIP, sx) - mir(SHOULDER, sx)
    return frame(span, v3(0, 1, 0.25))


def body_prims():
    p = [
        Ellipsoid("body", "hips", BODY_C, BODY_R, rot=frame(BODY_AXIS, v3(0, 1, 0)), k=0.03),
        Ellipsoid("chest", "spine", CHEST_C, CHEST_R, k=0.05),
        Cone("neck", "neck", v3(0, 0.3, -0.04), v3(0, 0.38, -0.06), 0.105, 0.12, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.05),
        Cone("rump", "tail1", v3(0, 0.2, 0.12), TAIL_ROOT + v3(0, -0.02, 0.1), 0.07, 0.035, k=0.03,
             flat=0.6, flat_axis=v3(0, 1, 0.3)),
    ]
    for sd, sx in SIDES:
        n = v3(sx * 0.3, 0, -1.0)
        p.append(Cone("crest" + sd, "ear1." + sd, v3(sx * 0.016, 0.578, -0.05), v3(sx * 0.036, 0.63, 0.14), 0.032,
                      0.006, k=0.03, flat=0.45, flat_axis=n))
        hip = v3(sx * 0.05, 0.13, 0.05)
        knee = v3(sx * 0.055, 0.072, 0.03)
        ankle = v3(sx * 0.056, 0.024, 0.0)
        p.append(Cone("thigh" + sd, "hleg1." + sd, hip, knee, 0.042, 0.026, k=0.025))
        p.append(Cone("shank" + sd, "hleg2." + sd, knee, ankle, 0.016, 0.014, k=0.01))
        for j, (dx, dz) in enumerate(((0.024, -0.042), (0.0, -0.052), (-0.022, -0.04), (0.003, 0.03))):
            tip = ankle + v3(sx * dx, -0.01, dz)
            p.append(Cone("toe%s%d" % (sd, j), "hpaw." + sd, ankle + v3(0, -0.004, 0), tip, 0.012, 0.007, k=0.006))
    return p


def wing_prims():
    out = []
    for sd, sx in SIDES:
        fr = wing_frame(sx)
        a, b = mir(SHOULDER, sx), mir(WING_TIP, sx)
        span = np.linalg.norm(b - a)
        out.append(Ellipsoid("blade" + sd, "wing." + sd, a + (b - a) * 0.56, v3(0.05, 0.011, span * 0.5), rot=fr,
                             k=0.02))
        out.append(Ellipsoid("covert" + sd, "wing." + sd, a + (b - a) * 0.2 + fr[0] * 0.012, v3(0.058, 0.016, 0.085),
                             rot=fr, k=0.03))
    return out


def blur_prims():
    """The beat as a fan: the swept area of each wing, a wedge from the shoulder out past the tip."""
    out = []
    for sd, sx in SIDES:
        fr = wing_frame(sx)
        a = mir(SHOULDER, sx) - fr[1] * FAN_DROP
        b = a + (mir(WING_TIP, sx) - mir(SHOULDER, sx)) * 1.02
        out.append(Cone("fan" + sd, "prop_blur." + sd, a, b, 0.035, 0.16, k=0.0, flat=0.05, flat_axis=fr[1]))
    return out


def beak_prims():
    mid = BEAK_ROOT + (BEAK_TIP - BEAK_ROOT) * 0.3
    return [Cone("beak0", "head", BEAK_ROOT, mid, 0.022, 0.013, k=0.006),
            Cone("beak1", "head", mid, BEAK_TIP, 0.013, 0.004, k=0.006)]


def fork_prims():
    """The silver tuning fork: a short handle out of the tail feathers, the bend, two prongs on their own bones."""
    p = [Cone("handle", "tail1", TAIL_ROOT + v3(0, -0.02, 0.07), YOKE, 0.02, 0.022, k=0.01),
         Cone("yoke", "tail1", YOKE - v3(PRONG_X, 0, 0), YOKE + v3(PRONG_X, 0, 0), 0.024, 0.024, k=0.012)]
    for sd, sx in SIDES:
        a = YOKE + v3(sx * PRONG_X, 0, 0)
        p.append(Cone("prong" + sd, "fork." + sd, a, mir(PRONG_END, sx), 0.026, 0.022, k=0.0, flat=0.75,
                      flat_axis=v3(0, 1, 0)))
    return p


def ring_prims(radius, bone, n=18):
    pts = [RING_C + v3(math.cos(math.tau * i / n), 0, math.sin(math.tau * i / n)) * radius for i in range(n)]
    return [Cone("r%d" % i, bone, pts[i], pts[(i + 1) % n], 0.014, 0.014, k=0.004) for i in range(n)]


def parts():
    rings = []
    for i, r in enumerate(RING_RADII):
        rings += ring_prims(r, "prop_ring%d" % (i + 1))
    return {
        "body": (Shape(body_prims()), 0.0032, 2200),
        "wings": (Shape(wing_prims()), 0.0025, 150),
        "blur": (Shape(blur_prims()), 0.0025, 70),
        "beak": (Shape(beak_prims()), 0.002, 50),
        "fork": (Shape(fork_prims()), 0.0025, 190),
        "hum": (Shape([Ellipsoid("hum", "tail1", YOKE + v3(0, 0.006, -0.012), v3(0.026, 0.026, 0.026), k=0)]), 0.0025,
                24),
        "rings": (Shape(rings), 0.003, 260),
    }


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.08, 0.52, -0.1), (0.13, 0.64, -0.14), 0.032), "fang": ((0.03, 0.36, -0.2), (0.032, 0.32, -0.205), 0.012),
    "antenna": ((0.05, 0.55, -0.12), (0.12, 0.70, -0.2), 0.011), "brow": ((0.02, 0.5, -0.19), (0.12, 0.505, -0.155),
                                                                           0.016),
    "head_top": (0, 0.55, -0.08), "fang_at": (0, 0.36, -0.2), "brow_at": (0, 0.49, -0.18), "third_eye": (0, 0.5, -0.2),
    "back": ((0, 0.34, 0.0), (0, 0.32, 0.08), (0, 0.27, 0.16)), "back_at": (0, 0.32, 0.06), "plates": (0, 0.33, 0.04),
    "plate_r": (0.1, 0.03, 0.08), "shell_c": (0, 0.24, 0.07), "shell_r": (0.13, 0.12, 0.05), "tail_bone": "tail1",
    "club_at": tuple(YOKE), "club_dir": tuple(YOKE - TAIL_ROOT), "club_r": 0.045,
    "spots": ((0.11, 0.24, 0.02, 0.02), (0.112, 0.22, 0.1, 0.017), (0.1, 0.2, 0.16, 0.018)), "spots_at": (0, 0.22, 0.08),
    "wing": ((0.09, 0.3, 0.06), (0.22, 0.36, 0.2), (0.18, 0.3, 0.26)), "wing_at": (0, 0.3, 0.06),
    "fin": ((0.1, 0.2, 0.1), (0.13, 0.31, 0.2)), "fin_at": (0, 0.2, 0.1), "crest": (0.57, -0.12, 0.04, 0.06),
    "crest_at": (0, 0.55, -0.1),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
EMERALD = hexc("3aa88a")
JADE = hexc("68cfa8")
EMERALD_DEEP = hexc("23705e")
SHEEN = hexc("9ff0c4")
PALE = hexc("e8f4e8")
CREST_TIP = hexc("8ff2ee")
WING = hexc("6ad0c0")
WING_DARK = hexc("2f7f74")
BLUR_EDGE = hexc("f0fffb")
BEAK = hexc("2c2c36")
FOOT = hexc("3a3f48")
SILVER_A = hexc("f2f7fa")
SILVER_B = hexc("b4c2cc")
SILVER_C = hexc("5e6c78")
HUM = hexc("7fe8ff")
RING_CORE = hexc("e6fdff")
GROWN_A = hexc("9fe8d0")
GROWN_B = hexc("3aa88a")
GROWN_C = hexc("1f5c4e")
BLUSH = hexc("ff8fa0")
LILAC = hexc("e8f4e8")     # brows
LID = EMERALD
INK = hexc("15342c")
MOUTH_DARK = hexc("5a1f30")
TONGUE = hexc("f08aa0")
IRIS = hexc("3a7fa8")
IRIS_DEEP = hexc("10283a")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    fine = value_noise(p * np.array([90, 60, 90]))
    scale = value_noise(p * np.array([40, 40, 40]))
    col = mixc(EMERALD_DEEP, EMERALD, sat(n[:, 1] * 0.6 + 0.6 + (fine - 0.5) * 0.4))
    col = mixc(col, JADE, sat(n[:, 1] - 0.2) * 0.55)
    col = mixc(col, SHEEN, sat((scale - 0.62) * 4.0) * sat(n[:, 1] + 0.3) * 0.35)     # an iridescent glint
    # pale front: the cheeks under the eyes, the chest and the belly
    front = -n[:, 2] * 0.5 + 0.5
    face = edge(0.41 - y + (ax - 0.06) * 0.3, 0.012) * edge(-0.12 - z, 0.03)
    belly = edge(0.30 - y - ax * 0.4 + (fine - 0.5) * 0.02, 0.012) * edge(0.08 - ax - (0.3 - y) * 0.25 + 0.06, 0.02)
    pale = sat(face + belly * sat(front * 1.6 - 0.2) + edge(0.13 - y, 0.015))
    col = mixc(col, PALE, pale)
    for sd, sx in SIDES:        # the white spot behind each eye
        q = np.hypot((x - sx * 0.13) / 0.02, (y - 0.47) / 0.016)
        col = mixc(col, PALE, edge(1.0 - q, 0.25) * (z < -0.07))
        col = mixc(col, mixc(EMERALD, CREST_TIP, sat(y - 0.6) * 4), edge(0.003 - prim["crest" + sd].d(p), 0.003))
        b = (p - np.array([sx * 0.118, 0.405, 0])) / np.array([0.04, 0.024, 1.0])
        col = mixc(col, BLUSH, np.exp(-(b[:, 0] ** 2 + b[:, 1] ** 2) * 1.25) * (z < -0.12) * 0.45)
        leg = np.minimum.reduce([prim[nm].d(p) for nm in ["shank" + sd] + ["toe%s%d" % (sd, j) for j in range(4)]])
        col = mixc(col, FOOT, edge(0.004 - leg, 0.003) * edge(0.07 - y, 0.006))
    return col


def paint_wing(q, nn):
    """Teal flight feathers: dark at the root and along the leading edge, pale toward the tip."""
    fine = value_noise(q * np.array([30, 80, 30]))
    out = sat((np.abs(q[:, 0]) - 0.1) / 0.3)
    return mixc(WING_DARK, WING, sat(out * 1.3 + (fine - 0.5) * 0.3 + nn[:, 1] * 0.2))


def paint_blur(q):
    """Motion blur painted on: streaks fanning out from the shoulder, washing out to white at the rim."""
    sx = np.sign(q[:, 0])
    rel = q - np.stack([SHOULDER[0] * sx, np.full(len(q), SHOULDER[1]), np.full(len(q), SHOULDER[2])], -1)
    dist = np.linalg.norm(rel, axis=1)
    ang = np.arctan2(rel[:, 2], np.abs(rel[:, 0]))
    streak = value_noise(np.stack([ang * 9.0, dist * 3.0, np.zeros(len(q))], -1))
    col = mixc(WING, BLUR_EDGE, sat(dist / 0.32 * 0.85 + (streak - 0.5) * 0.7))
    return mixc(col, WING_DARK, sat(0.08 - dist) * 6)


def paint_rings(q):
    r = np.hypot(q[:, 0] - RING_C[0], q[:, 2] - RING_C[2])
    tube = np.minimum.reduce([np.abs(r - rr) for rr in RING_RADII])
    lift = np.abs(q[:, 1] - RING_C[1])
    return mixc(HUM, RING_CORE, sat(1.0 - np.hypot(tube, lift) / 0.014) ** 2)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "wings":
        return paint_wing(q, nn)
    if pc.name == "blur":
        return paint_blur(q)
    if pc.name == "rings":
        return paint_rings(q)
    if pc.name == "beak":
        return np.tile(BEAK, (len(q), 1))
    if pc.name == "fork":
        return paint_shell(q, nn, np.full(len(q), 1.0), SILVER_A, SILVER_B, SILVER_C)
    if pc.name == "hum":
        return np.tile(HUM, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(HUM, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), GROWN_A, GROWN_B, GROWN_C)
    return tool_colour(pc.name, q)

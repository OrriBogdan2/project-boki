"""Vespyx (cindle), fox + scorpion: the shapes. Game axes: +x its right, +y up, -z its front, feet on y = 0.

Character L is -x, as on the Hunters. Every primitive names the bone it rides, which is how the skin weights come out.
"""
import math

import numpy as np

from boki_sdf import Cone, Ellipsoid, Shape, frame, v3

SIDES = (("L", -1.0), ("R", 1.0))
HEAD_C = v3(0, 0.47, -0.13)
HEAD_R = v3(0.25, 0.208, 0.208)
# the eye dome: centre and radii in the head's frame, set into the socket the head carves for it
EYE_C = v3(0.116, 0.452, -0.283)
EYE_R = v3(0.080, 0.096, 0.056)
EYE_YAW = 0.42


def eye_frame(sx):
    """Rows: outward along the face, up, out of the eye."""
    out = v3(sx * math.sin(EYE_YAW), 0.06, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def body_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.235, 0.085), v3(0.122, 0.122, 0.185), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.255, -0.05), v3(0.122, 0.135, 0.125), k=0.05),
        Cone("neck", "neck", v3(0, 0.30, -0.05), v3(0, 0.42, -0.12), 0.095, 0.11, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.035),
        Ellipsoid("muzzle", "head", v3(0, 0.392, -0.29), v3(0.104, 0.074, 0.092), k=0.05),
        Ellipsoid("nose", "head", v3(0, 0.434, -0.372), v3(0.031, 0.021, 0.02), k=0.006),
    ]
    tufts = [
        ("top0", (0.0, 0.655, -0.15), (0.015, 0.735, -0.10), 0.034),
        ("top1", (-0.045, 0.65, -0.13), (-0.07, 0.712, -0.09), 0.026),
        ("top2", (0.05, 0.65, -0.13), (0.078, 0.70, -0.085), 0.024),
    ]
    for nm, a, b, r in tufts:
        p.append(Cone(nm, "head", v3(*a), v3(*b), r, 0.003, k=0.016))
    for sd, sx in SIDES:
        p.append(Ellipsoid("cheek" + sd, "head", v3(sx * 0.125, 0.415, -0.15), v3(0.135, 0.105, 0.125), k=0.04))
        for i, (a, b, r) in enumerate([
            ((0.215, 0.455, -0.105), (0.322, 0.480, -0.060), 0.058),
            ((0.205, 0.390, -0.115), (0.340, 0.385, -0.070), 0.066),
            ((0.170, 0.335, -0.135), (0.262, 0.285, -0.095), 0.056),
        ]):
            p.append(Cone("ruff%s%d" % (sd, i), "head", v3(sx * a[0], a[1], a[2]), v3(sx * b[0], b[1], b[2]),
                          r, 0.003, k=0.016))
        n = v3(sx * 0.3, 0.0, -1.0)
        base = v3(sx * 0.118, 0.60, -0.105)
        mid = v3(sx * 0.178, 0.745, -0.095)
        tip = v3(sx * 0.235, 0.905, -0.085)
        p.append(Cone("ear1" + sd, "ear1." + sd, base, mid, 0.128, 0.086, k=0.03, flat=0.36, flat_axis=n))
        p.append(Cone("ear2" + sd, "ear2." + sd, mid, tip, 0.086, 0.003, k=0.012, flat=0.36, flat_axis=n))
        ear = (tip - base) / np.linalg.norm(tip - base)
        nn = n / np.linalg.norm(n)
        p.append(Ellipsoid("earhole" + sd, "ear1." + sd, base + ear * 0.135 + nn * 0.042, v3(0.072, 0.135, 0.030),
                           rot=frame(nn, ear), k=0.014, sub=True))
        # front leg: a short straight post, the paw splayed out
        hip = v3(sx * 0.082, 0.235, -0.075)
        knee = v3(sx * 0.090, 0.125, -0.080)
        ankle = v3(sx * 0.094, 0.040, -0.084)
        p.append(Cone("fleg1" + sd, "fleg1." + sd, hip, knee, 0.058, 0.048, k=0.03))
        p.append(Cone("fleg2" + sd, "fleg2." + sd, knee, ankle, 0.048, 0.044, k=0.012))
        p.append(Ellipsoid("fpaw" + sd, "fpaw." + sd, v3(sx * 0.096, 0.030, -0.110), v3(0.056, 0.032, 0.072), k=0.018))
        # hind leg: a round haunch
        hip = v3(sx * 0.095, 0.215, 0.195)
        knee = v3(sx * 0.108, 0.115, 0.175)
        ankle = v3(sx * 0.108, 0.040, 0.205)
        p.append(Ellipsoid("haunch" + sd, "hleg1." + sd, v3(sx * 0.100, 0.200, 0.190), v3(0.066, 0.094, 0.105), k=0.03))
        p.append(Cone("hleg2" + sd, "hleg2." + sd, knee, ankle, 0.050, 0.044, k=0.014))
        p.append(Ellipsoid("hpaw" + sd, "hpaw." + sd, v3(sx * 0.110, 0.030, 0.175), v3(0.056, 0.032, 0.072), k=0.018))
    for i, (a, b, r) in enumerate([
        ((0.0, 0.215, -0.17), (0.0, 0.155, -0.205), 0.042),
        ((-0.048, 0.235, -0.165), (-0.058, 0.170, -0.195), 0.034),
        ((0.048, 0.235, -0.165), (0.058, 0.170, -0.195), 0.034),
        ((0.0, 0.32, 0.20), (0.0, 0.372, 0.235), 0.03),
    ]):
        p.append(Cone("chestfur%d" % i, "spine" if i < 3 else "hips", v3(*a), v3(*b), r, 0.003, k=0.014))
    return p


# ---------------------------------------------------------------- the tail
TAIL_PTS = [v3(0, 0.27, 0.235), v3(0, 0.335, 0.335), v3(0, 0.445, 0.405), v3(0, 0.570, 0.425), v3(0, 0.690, 0.385),
            v3(0, 0.780, 0.295), v3(0, 0.815, 0.185), v3(0, 0.800, 0.095)]
TAIL_RADII = [0.070, 0.074, 0.074, 0.071, 0.066, 0.060, 0.052]


def tail_prims():
    out = []
    for i, r in enumerate(TAIL_RADII):
        a, b = TAIL_PTS[i], TAIL_PTS[i + 1]
        c = (a + b) * 0.5
        d = b - a
        length = np.linalg.norm(d)
        out.append(Ellipsoid("plate%d" % i, "tail%d" % (i + 1), c, v3(r, r * 0.96, length * 0.72),
                             rot=frame(d, v3(1, 0, 0)), k=0.006))
    return out


STING_C = v3(0, 0.770, 0.040)
STING_DIR = np.array((0.0, -0.62, -0.78))


def sting_prims():
    tip = STING_C + STING_DIR * 0.150
    return [Cone("bulb", "sting", STING_C, tip, 0.076, 0.006, k=0.0)]


def collar_prims():
    d = TAIL_PTS[-1] - TAIL_PTS[-2]
    return [Ellipsoid("collar", "tail7", TAIL_PTS[-1] + d * 0.05, v3(0.05, 0.05, 0.024),
                      rot=frame(d, v3(1, 0, 0)), k=0.0)]


# ---------------------------------------------------------------- pincers, held up at the chest
def claw_prims(sd, sx):
    s = v3(sx, 1, 1)
    arm = "arm." + sd
    claw = "claw." + sd
    nip = "nip." + sd
    return [
        Cone("arm" + sd, arm, v3(0.070, 0.250, -0.130) * s, v3(0.118, 0.232, -0.195) * s, 0.036, 0.034, k=0.01),
        Ellipsoid("palm" + sd, claw, v3(0.138, 0.228, -0.238) * s, v3(0.070, 0.064, 0.070), k=0.01),
        Cone("finger" + sd, claw, v3(0.178, 0.230, -0.272) * s, v3(0.186, 0.236, -0.338) * s, 0.040, 0.030, k=0.02),
        Cone("fingertip" + sd, claw, v3(0.186, 0.236, -0.338) * s, v3(0.132, 0.240, -0.388) * s, 0.030, 0.004, k=0.012),
        Cone("nip0" + sd, nip, v3(0.092, 0.230, -0.272) * s, v3(0.080, 0.234, -0.332) * s, 0.032, 0.024, k=0.0),
        Cone("nip1" + sd, nip, v3(0.080, 0.234, -0.332) * s, v3(0.116, 0.238, -0.376) * s, 0.024, 0.004, k=0.012),
    ]


def parts():
    """name -> (Shape, grid step m, target tris) of each separately meshed piece."""
    out = {
        "body": (Shape(body_prims()), 0.0035, 5700),
        "tail": (Shape(tail_prims()), 0.0035, 1300),
        "collar": (Shape(collar_prims()), 0.0035, 120),
        "sting": (Shape(sting_prims()), 0.0035, 260),
    }
    for sd, sx in SIDES:
        out["claw" + sd] = (Shape(claw_prims(sd, sx)), 0.0035, 520)
    return out


# ---------------------------------------------------------------- work props: skinned to their own bones, scaled to
# nothing except in the clips that use them
AXIS = STING_DIR / np.linalg.norm(STING_DIR)
SIDE = v3(1, 0, 0)
AX_UP = np.cross(SIDE, AXIS)


def axe_blade(base):
    """A fan from the eye of the axe to a straight cutting edge."""
    c1 = base + AX_UP * 0.155 + AXIS * 0.080
    c2 = base + AX_UP * 0.155 - AXIS * 0.090
    mid = (c1 + c2) * 0.5
    flat = {"flat": 0.24, "flat_axis": SIDE}
    return [Cone("b0", "prop_axe", base, mid, 0.034, 0.078, k=0.0, **flat),
            Cone("b1", "prop_axe", base, c1, 0.030, 0.012, k=0.01, **flat),
            Cone("b2", "prop_axe", base, c2, 0.030, 0.012, k=0.01, **flat),
            Cone("b3", "prop_axe", c1, c2, 0.012, 0.012, k=0.01, **flat)]


def prop_parts():
    """name -> (Shape, step, tris, bone)."""
    g = STING_C + AXIS * 0.06
    end = g + AXIS * 0.30
    blade = end - AXIS * 0.045
    out = {
        "axe_handle": (Shape([Cone("h", "prop_axe", g, end, 0.017, 0.015, k=0)]), 0.004, 60),
        "axe_blade": (Shape(axe_blade(blade)), 0.003, 170),
        "pick_handle": (Shape([Cone("h", "prop_pick", g, end, 0.017, 0.015, k=0)]), 0.004, 60),
        "pick_head": (Shape([Cone("a", "prop_pick", end, end + AX_UP * 0.17 + AXIS * -0.06, 0.034, 0.006, k=0.0),
                             Cone("b", "prop_pick", end, end - AX_UP * 0.17 + AXIS * -0.06, 0.034, 0.006, k=0.005)]),
                      0.003, 160),
        "berry": (Shape([Ellipsoid("b", "prop_berry", v3(0, 0.285, -0.365), v3(0.054, 0.052, 0.054), k=0)]), 0.003, 90),
    }
    return out


# ---------------------------------------------------------------- grown parts (Evo's mutations), one bone each, shown
# only on a Boki that has grown them (BokiDna). id -> (parent bone, bone head, look, tris, primitives)
def grown_parts():
    def pair(fn):
        return [p for _, sx in SIDES for p in fn(sx)]

    def horns(sx):
        return [Cone("h", "part_horns", v3(sx * 0.075, 0.645, -0.17), v3(sx * 0.15, 0.80, -0.235), 0.042, 0.004, k=0)]

    def fangs(sx):
        return [Cone("f", "part_fangs", v3(sx * 0.052, 0.352, -0.345), v3(sx * 0.058, 0.298, -0.355), 0.017, 0.002, k=0)]

    def antennae(sx):
        return [Cone("a", "part_antennae", v3(sx * 0.05, 0.655, -0.2), v3(sx * 0.125, 0.83, -0.30), 0.014, 0.008, k=0)]

    def antenna_tips(sx):
        return [Ellipsoid("t", "part_antennae", v3(sx * 0.13, 0.84, -0.31), v3(0.034, 0.034, 0.034), k=0)]

    def spots(sx):
        return [Ellipsoid("s", "part_spots", v3(sx * x, y, z), v3(0.016, r, r), k=0)
                for x, y, z, r in ((0.122, 0.27, -0.01, 0.026), (0.125, 0.22, 0.09, 0.022), (0.125, 0.28, 0.13, 0.024))]

    def wings(sx):
        n = v3(0, 1, 0.3)
        return [Cone("w0", "part_wings", v3(sx * 0.10, 0.345, 0.0), v3(sx * 0.30, 0.44, 0.10), 0.040, 0.012, k=0.0,
                     flat=0.22, flat_axis=n),
                Cone("w1", "part_wings", v3(sx * 0.10, 0.345, 0.03), v3(sx * 0.25, 0.40, 0.19), 0.034, 0.010, k=0.02,
                     flat=0.22, flat_axis=n)]

    def fins(sx):
        n = v3(1, 0, 0)
        return [Cone("f", "part_fins", v3(sx * 0.118, 0.265, 0.12), v3(sx * 0.15, 0.40, 0.25), 0.055, 0.006, k=0,
                     flat=0.2, flat_axis=n)]

    back = v3(0, -0.35, 1)
    side = v3(1, 0, 0)
    return {
        "horns": ("head", v3(0, 0.66, -0.2), "shell", 90, pair(horns)),
        "spikes": ("spine", v3(0, 0.36, 0.05), "shell", 110, [
            Cone("s%d" % i, "part_spikes", v3(0, 0.335 - i * 0.006, z), v3(0, 0.335 - i * 0.006 + h, z + 0.035),
                 0.042, 0.004, k=0, flat=0.45, flat_axis=side) for i, (z, h) in enumerate(((-0.02, 0.105), (0.07, 0.12),
                                                                                       (0.16, 0.10)))]),
        "fangs": ("head", v3(0, 0.34, -0.34), "white", 40, pair(fangs)),
        "brow": ("head", v3(0, 0.56, -0.29), "shell", 110, [
            Cone("b" + sd, "part_brow", v3(sx * 0.015, 0.545, -0.325), v3(sx * 0.195, 0.585, -0.235), 0.024, 0.018, k=0.012)
            for sd, sx in SIDES]),
        "plates": ("spine", v3(0, 0.34, 0.08), "shell", 130, [
            Ellipsoid("p0", "part_plates", v3(0, 0.348, 0.03), v3(0.128, 0.040, 0.082), k=0),
            Ellipsoid("p1", "part_plates", v3(0, 0.335, 0.165), v3(0.12, 0.040, 0.082), k=0.004)]),
        "shell": ("hips", v3(0, 0.235, 0.085), "shell", 170, [
            Ellipsoid("s", "part_shell", v3(0, 0.238, 0.085), v3(0.142, 0.138, 0.058), k=0)]),
        "club": ("tail6", tuple(TAIL_PTS[6]), "shell", 120, [
            Ellipsoid("c", "part_club", TAIL_PTS[6], v3(0.076, 0.076, 0.05), rot=frame(TAIL_PTS[7] - TAIL_PTS[5],
                                                                                    v3(1, 0, 0)), k=0)]),
        "antennae": ("head", v3(0, 0.66, -0.2), "shell", 60, pair(antennae)),
        "antenna_tips": ("part_antennae", None, "glow", 50, pair(antenna_tips)),
        "spots": ("hips", v3(0, 0.25, 0.08), "glow", 100, pair(spots)),
        "third_eye": ("head", v3(0, 0.585, -0.3), "glow", 40, [
            Ellipsoid("e", "part_third_eye", v3(0, 0.583, -0.312), v3(0.030, 0.034, 0.018), k=0)]),
        "crest": ("head", v3(0, 0.66, -0.1), "shell", 110, [
            Cone("c%d" % i, "part_crest", v3(0, 0.655 - i * 0.05, -0.17 + i * 0.075),
                 v3(0, 0.655 - i * 0.05 + 0.13 - i * 0.02, -0.17 + i * 0.075 + 0.05), 0.046, 0.005, k=0, flat=0.3,
                 flat_axis=side) for i in range(3)]),
        "wings": ("spine", v3(0, 0.345, 0.02), "shell", 110, pair(wings)),
        "fins": ("hips", v3(0, 0.26, 0.12), "shell", 70, pair(fins)),
    }

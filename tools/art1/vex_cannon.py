"""ART-1 Vex v2: the minigun arm as data (briefs/art-refs/vex_v2/). Her right forearm IS the gun from the elbow down (no hand): the brass
cuff over the elbow, the receiver with its side boss, six barrels on `gatling`, the ammo drum under the receiver, the ribbed belt loop
over the top, the chain with the bullet charm. All rigid on forearm.R, so aim = arm pose. v2 has no launcher tube: the `launcher` bone
stays (the clip set swings it) and carries nothing; its FX points sit on its pivot at the drum's mouth, where the charge leaves.
Cannon space: s along the forearm from the elbow toward the muzzle, u outward (+X at rest), f forward at rest (the TOP once she aims).
Blender frame: Z up, she faces +Y, her right hand is +X."""
import json, os
import numpy as np
from meshkit import Piece, norm

HERE = os.path.dirname(os.path.abspath(__file__))
_rig = json.load(open(os.path.join(HERE, "..", "..", "art", "wardens", "src", "vex_rig.json")))["bones"]


def J(b):
    x, y, z = _rig[b]["head"]
    return np.array([x, -z, y], float)


E = J("forearm.R")                # the pivot
OUT = 0.03                        # the gun's axis this far outside the elbow, clear of the hip
CUFF_R = 0.056                    # the brass cuff over the elbow (sheet: cuff width = a third of the gun's length to the muzzle)
REC_S0, REC_S1 = 0.12, 0.25       # the receiver along the gun
REC_U, REC_F = 0.055, 0.06        # its half width (side) and half height (top)
GATLING_F = 0.0                   # the barrels' axis
TIP_S = 0.55                      # the barrels' mouths: elbow to muzzle 0.55 m = 31% of her height (the sheet: about 30%)
DRUM_F, DRUM_R = -0.105, 0.058    # the ammo drum under the receiver (the bottom once she aims)
DRUM_S0, DRUM_S1 = 0.10, 0.26
PIVOT_S = DRUM_S1 + 0.02          # the charge's mouth, ahead of the drum


def C(s, u=0.0, f=0.0):
    return E + np.array([OUT + u, f, -s], float)


def ring(n, phase=0.0):
    return [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, n, endpoint=False) + phase]


def lathe(name, mat, centre_u, centre_f, prof, n=12, bone="forearm.R", cap=True):
    """A solid of revolution round the gun's axis: prof [(s, r)]. Open ends are closed with a fan (or left open, cap=False)."""
    v, f = [], []
    sec = ring(n)
    for s, r in prof:
        for a, b in sec:
            v.append(C(s, centre_u + a * r, centre_f + b * r))
    m = len(prof)
    for i in range(m - 1):
        for j in range(n):
            a, b = i * n + j, i * n + (j + 1) % n
            f.append([a, b, b + n, a + n])
    if cap:
        for i_, sg in ((0, 1), (m - 1, -1)):
            c = len(v)
            v.append(C(prof[i_][0], centre_u, centre_f))
            for j in range(n):
                a, b = i_ * n + j, i_ * n + (j + 1) % n
                f.append([a, b, c] if sg < 0 else [b, a, c])
    return Piece(name, mat, np.array(v), f).rigid(bone)


def box(name, mat, c, ax, ay, az, bone="forearm.R"):
    """A box: centre, half-axis vectors."""
    c, ax, ay, az = [np.asarray(q, float) for q in (c, ax, ay, az)]
    v = [c + sx * ax + sy * ay + sz * az for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    f = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return Piece(name, mat, np.array(v), f).rigid(bone)


def body():
    """The brass cuff (lipped at the elbow, banded at its foot), the receiver block and its side boss, the drum and its face."""
    cuff = [(-0.035, 0.0), (-0.035, CUFF_R - 0.012), (-0.03, CUFF_R + 0.004), (-0.005, CUFF_R + 0.004), (0.0, CUFF_R), (0.11, CUFF_R),
            (0.112, CUFF_R + 0.005), (0.13, CUFF_R + 0.005), (0.13, 0.0)]
    out = [lathe("cuff", "brass-vex", 0.0, 0.0, cuff, n=14)]
    sc_ = (REC_S0 + REC_S1) / 2
    out.append(box("receiver", "brass-vex", C(sc_), (REC_U, 0, 0), (0, REC_F, 0), (0, 0, (REC_S1 - REC_S0) / 2)))
    out.append(box("boss", "metal-vex", C(sc_, REC_U + 0.008), (0.008, 0, 0), (0, 0.036, 0), (0, 0, 0.04)))
    out.append(lathe("drum", "brass-vex", 0.0, DRUM_F, [(DRUM_S0, 0.0), (DRUM_S0, DRUM_R - 0.006), (DRUM_S0 + 0.006, DRUM_R), (DRUM_S1 - 0.006, DRUM_R),
                                                         (DRUM_S1, DRUM_R - 0.006), (DRUM_S1, 0.0)], n=14))
    out.append(lathe("drumface", "metal-vex", 0.0, DRUM_F, [(DRUM_S1, 0.0), (DRUM_S1, 0.03), (DRUM_S1 + 0.008, 0.026), (DRUM_S1 + 0.008, 0.0)], n=10, cap=False))
    return out


def gatling():
    """Six barrels round a spindle on the spin bone, the rear collar, a middle band and the muzzle plate."""
    out = [lathe("gcollar", "metal-vex", 0.0, GATLING_F, [(REC_S1 - 0.005, 0.0), (REC_S1 - 0.005, 0.046), (REC_S1 + 0.03, 0.05), (REC_S1 + 0.045, 0.042), (REC_S1 + 0.045, 0.0)], n=12)]
    out.append(lathe("gspindle", "metal-vex", 0.0, GATLING_F, [(REC_S1 + 0.04, 0.018), (TIP_S - 0.01, 0.018)], n=6, bone="gatling", cap=False))
    for s0, s1, r in ((0.41, 0.43, 0.05), (TIP_S - 0.03, TIP_S - 0.005, 0.052)):
        out.append(lathe("gband%d" % int(s0 * 100), "metal-vex", 0.0, GATLING_F, [(s0, 0.02), (s0, r), (s1, r), (s1, 0.02)], n=12, bone="gatling", cap=False))
    for i in range(6):
        t = i / 6 * 2 * np.pi
        bu, bf = 0.033 * np.cos(t), GATLING_F + 0.033 * np.sin(t)
        out.append(lathe("barrel%d" % i, "metal-vex", bu, bf, [(REC_S1 + 0.04, 0.0125), (TIP_S, 0.0125), (TIP_S, 0.006), (TIP_S - 0.02, 0.006)], n=6, bone="gatling", cap=False))
    return out


def belt_path_tile(name, path, width=0.021, uvrect=(0, 0, 1, 1), up=None):
    """A ribbed belt: a saw-tooth ribbon, each link a raised step, with a tiled paint. up: the ribs' outward side per point."""
    p = np.asarray(path, float)
    t = norm(np.gradient(p, axis=0))
    n = norm(up if up is not None else p * [1, 1, 0] - [0, -0.02, 0])
    s = norm(np.cross(t, n))
    n = norm(np.cross(s, t)) * np.sign(np.sum(np.cross(s, t) * n, axis=1, keepdims=True))
    v, f, uv = [], [], []
    for i in range(len(p)):
        h = 0.016 if i % 2 == 0 else 0.004
        v.append(p[i] + s[i] * width)
        v.append(p[i] + n[i] * h)
        v.append(p[i] - s[i] * width)
    u0, v0, u1, v1 = uvrect
    for i in range(len(p) - 1):
        for k in range(2):
            a = i * 3 + k
            f.append([a + 3, a + 4, a + 1, a])
            uk0, uk1 = v0 + (v1 - v0) * k / 2, v0 + (v1 - v0) * (k + 1) / 2
            ua, ub = (u0, u1) if i % 2 == 0 else (u1, u0)
            uv.append([(ub, uk0), (ub, uk1), (ua, uk1), (ua, uk0)])
    return Piece(name, "metal-belt", np.array(v), f, uv, room=0.3)


def belt_loop():
    """The ammo belt's loop: out of the cuff's top, arching over the gun, back into the receiver (the sheet's ribbed loop), on the outer side."""
    th = np.linspace(0.0, np.pi, 23)
    c_s, c_f, rs, rf = 0.11, REC_F + 0.005, 0.105, 0.13
    pts = np.array([C(c_s - rs * np.cos(a), 0.035, c_f + rf * np.sin(a)) for a in th])
    up = pts - C(c_s, 0.035, c_f)
    p = belt_path_tile("ammoloop", pts, width=0.026, up=up)
    return p.rigid("forearm.R")


def charm():
    """The chain off the drum's mouth and the bullet on its end, a green charm beside: hanging toward the ground once she aims (-f)."""
    out, top = [], C(DRUM_S1 - 0.02, 0.0, DRUM_F - DRUM_R)
    for i in range(4):
        c = top + np.array([0, -0.017 * i - 0.01, 0])
        wide, thin = ((0.006, 0, 0), (0, 0, 0.0015)) if i % 2 == 0 else ((0, 0, 0.006), (0.0015, 0, 0))
        out.append(box("chain%d" % i, "metal-vex", c, wide, (0, 0.009, 0), thin))
    bt = top + np.array([0, -0.075, 0])
    v = []
    prof = [(0.0, 0.0), (0.0, 0.0095), (0.03, 0.0095), (0.042, 0.007), (0.05, 0.0)]
    for d, r in prof:
        for a, b in ring(8):
            v.append(bt + np.array([a * r, -d, b * r]))
    f = [[i * 8 + j, i * 8 + (j + 1) % 8, (i + 1) * 8 + (j + 1) % 8, (i + 1) * 8 + j] for i in range(len(prof) - 1) for j in range(8)]
    out.append(Piece("bullet", "brass-vex", np.array(v), f).rigid("forearm.R"))
    g = top + np.array([0, -0.035, -0.02])
    gv = np.array([g + np.array([np.cos(a) * np.sin(b), np.cos(b), np.sin(a) * np.sin(b)]) * 0.013 for b in np.linspace(0, np.pi, 5) for a in np.linspace(0, 2 * np.pi, 8, endpoint=False)])
    gf = [[i * 8 + j, i * 8 + (j + 1) % 8, (i + 1) * 8 + (j + 1) % 8, (i + 1) * 8 + j] for i in range(4) for j in range(8)]
    out.append(Piece("gren0", "metal-vex", gv, gf).rigid("forearm.R"))
    return out


def all_pieces():
    return body() + gatling() + [belt_loop()] + charm()


def empties():
    """FX points in rest space: (bone, position)."""
    mouth = tuple(C(PIVOT_S, 0, DRUM_F))
    return {"weapon_muzzle": ("gatling", tuple(C(TIP_S + 0.03, 0, GATLING_F))),
            "gatling_muzzle": ("gatling", tuple(C(TIP_S + 0.03, 0, GATLING_F))),
            "launcher_muzzle": ("launcher", mouth),          # on the launcher's pivot: the clip's swing leaves it in place
            "launcher_fire": ("forearm.R", mouth),
            "anchor_gatling_root": ("forearm.R", tuple(C(REC_S1 + 0.04, 0, GATLING_F))),
            "anchor_sleeve_mouth": ("forearm.R", tuple(C(-0.035, 0, 0))),
            "anchor_grenade_drum": ("forearm.R", tuple(C((DRUM_S0 + DRUM_S1) / 2, 0, DRUM_F)))}

"""ART-1 Vex: the hybrid arm-cannon as data. She has NO human right arm: the riveted shoulder plate and the strut are upper_arm.R, the
cannon itself is rigid on forearm.R (aim = arm pose), the barrels spin on `gatling`, and the makeshift launcher swings on `launcher`.
The launcher rests bell-up past her shoulder as the master sheet draws it, and swings over the top onto the sleeve, bell forward, to
throw (a post at its middle, the weapon sheet's mount). Cannon space: s along the cannon toward the barrels' tips (from the elbow pivot),
u outward (+X at rest), f forward at rest (the TOP once she aims). Blender frame: Z up, she faces +Y, her right hand is +X."""
import json, os
import numpy as np
from meshkit import Piece, catmull, norm, smooth, sweep, frames

HERE = os.path.dirname(os.path.abspath(__file__))
_rig = json.load(open(os.path.join(HERE, "..", "..", "art", "wardens", "src", "vex_rig.json")))["bones"]


def J(b):
    x, y, z = _rig[b]["head"]
    return np.array([x, -z, y], float)


E = J("forearm.R")                # the pivot
OUT = 0.085                       # the cannon axis sits this far outside the elbow, clear of the hip
SLEEVE_F, SLEEVE_R = 0.05, 0.072
GATLING_F = -0.052
TUBE_F, TUBE_R = 0.15, 0.041      # the launcher: its axis ahead of the sleeve; radius of the scrap pipe
POST_S = -0.24                    # the launcher's pivot along the cannon
BELL_S, BREECH_S = -0.52, -0.11    # bell mouth and breech at rest
TIP_S = 0.535                      # the gatling's mouths


def C(s, u=0.0, f=0.0):
    return E + np.array([OUT + u, f, -s], float)


def ring(n, phase=0.0):
    return [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, n, endpoint=False) + phase]


def lathe(name, mat, centre_u, centre_f, prof, n=12, axis_s=None, bone="forearm.R", room=1.0, cap=True):
    """A solid of revolution round the cannon axis: prof [(s, r)]. Open ends are closed with a fan (or left open, cap=False)."""
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


def box(name, mat, c, ax, ay, az, bone, room=1.0):
    """A box: centre, half-axis vectors."""
    c, ax, ay, az = [np.asarray(q, float) for q in (c, ax, ay, az)]
    v = [c + sx * ax + sy * ay + sz * az for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    f = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return Piece(name, mat, np.array(v), f).rigid(bone)


def sleeve():
    out = []
    # the big sleeve: cap at the shoulder end, swelling through its brass bands to the wide grey mouth; hollow mouth
    prof = [(-0.30, 0.0), (-0.30, 0.058), (-0.285, 0.076), (-0.255, 0.078), (-0.25, SLEEVE_R), (-0.17, SLEEVE_R), (-0.165, 0.078), (-0.135, 0.078), (-0.13, SLEEVE_R),
            (0.10, SLEEVE_R), (0.105, 0.078), (0.135, 0.078), (0.14, SLEEVE_R), (0.175, SLEEVE_R), (0.18, 0.086), (0.235, 0.088), (0.245, 0.074), (0.245, 0.052), (0.15, 0.046), (0.15, 0.0)]
    out.append(lathe("sleeve", "metal-vex", 0.0, SLEEVE_F, prof, n=14, cap=False))
    return out


def gatling():
    """Six barrels round a spindle, on the spin bone; two brass-and-iron collars. The collars read at the match camera."""
    out = []
    cu, cf = 0.0, GATLING_F
    hub = lathe("gcollar0", "metal-vex", cu, cf, [(0.02, 0.0), (0.02, 0.05), (0.06, 0.056), (0.15, 0.056), (0.2, 0.05), (0.2, 0.0)], n=10, bone="forearm.R")
    out.append(hub)
    out.append(lathe("gspindle", "metal-vex", cu, cf, [(0.15, 0.022), (TIP_S - 0.02, 0.022)], n=6, bone="gatling", cap=False))
    for s0, s1, r in ((0.36, 0.395, 0.058), (0.49, 0.52, 0.057)):
        out.append(lathe("gband%d" % int(s0 * 100), "brass-vex" if s0 < 0.45 else "metal-vex", cu, cf, [(s0, 0.03), (s0, r), (s1, r), (s1, 0.03)], n=10, bone="gatling", cap=False))
    for i in range(6):
        t = i / 6 * 2 * np.pi
        bu, bf = cu + 0.036 * np.cos(t), cf + 0.036 * np.sin(t)
        out.append(lathe("barrel%d" % i, "metal-vex", bu, bf, [(0.15, 0.0165), (TIP_S, 0.0165), (TIP_S + 0.012, 0.019), (TIP_S + 0.022, 0.019), (TIP_S + 0.022, 0.0)], n=6, bone="gatling", cap=False))
    return out


def launcher():
    """On `launcher`: the scrap pipe, tape, the flared brass bell, the ring sight on its stalk, the clamp at the post."""
    b = "launcher"
    B0 = BELL_S + 0.09
    prof = [(BREECH_S, 0.0), (BREECH_S, 0.03), (BREECH_S - 0.006, TUBE_R + 0.008), (BREECH_S - 0.04, TUBE_R + 0.008), (BREECH_S - 0.046, TUBE_R), (-0.385, TUBE_R), (-0.39, TUBE_R + 0.007), (-0.42, TUBE_R + 0.007), (-0.425, TUBE_R), (B0, TUBE_R)]
    out = [lathe("tube", "metal-vex", 0.0, TUBE_F, prof, n=11, bone=b, cap=False)]
    bell = [(B0, TUBE_R), (B0 - 0.03, TUBE_R + 0.004), (B0 - 0.055, TUBE_R + 0.016), (BELL_S + 0.008, TUBE_R + 0.042), (BELL_S, TUBE_R + 0.062), (BELL_S - 0.002, TUBE_R + 0.056), (BELL_S + 0.02, TUBE_R + 0.022), (BELL_S + 0.07, 0.024), (BELL_S + 0.07, 0.0)]
    out.append(lathe("bell", "brass-vex", 0.0, TUBE_F, bell, n=13, bone=b, cap=False))
    out.append(lathe("clamp", "metal-vex", 0.0, TUBE_F, [(POST_S - 0.05, TUBE_R + 0.002), (POST_S - 0.05, TUBE_R + 0.016), (POST_S + 0.05, TUBE_R + 0.016), (POST_S + 0.05, TUBE_R + 0.002)], n=9, bone=b, cap=False))
    # the post: fixed to the sleeve
    out.append(box("post", "metal-vex", C(POST_S, 0, (SLEEVE_F + TUBE_F) / 2), (0.014, 0, 0), (0, 0.032, 0), (0, 0, 0.035), "forearm.R"))
    out.append(lathe("hub", "metal-vex", 0, 0, [(0, 0)], n=3, bone=b, cap=False)) if False else None
    # the ring sight: a stalk off the tube's outer side, a flat ring
    st = C(-0.36, TUBE_R * 0.4, TUBE_F + TUBE_R * 0.9)
    tip = C(-0.36, 0.075, TUBE_F + 0.10)
    out.append(sweep("stalk", "metal-vex", [st, (st + tip) / 2, tip], ring(4), np.full(3, 0.005), side_hint=np.array([0, 0, 1.0]), tip=False).rigid(b))
    th = np.linspace(0, 2 * np.pi, 11)
    c0 = tip + norm(tip - st) * 0.034
    u_, v_ = norm(tip - st), np.array([0, 0, 1.0])
    pts = [c0 + u_ * np.cos(t) * 0.034 + v_ * np.sin(t) * 0.034 for t in th]
    out.append(sweep("sightring", "metal-vex", pts, ring(4), np.full(11, 0.0048), side_hint=np.cross(u_, v_), tip=False).rigid(b))
    # the tape's loose tail: a thin strip, double-faced
    a, n_ = C(-0.445, TUBE_R * 0.9, TUBE_F - 0.02), np.array([0, 1.0, 0])
    strip = np.array([a, a + [0.012, 0.004, -0.022], a + [0.03, 0.002, -0.05], a + [0.052, -0.006, -0.07]])
    v = np.vstack([strip - n_ * 0 - [0, 0.0, 0] + [0, 0.012, 0], strip + [0, -0.012, 0]])
    f = [[i, i + 1, i + 5, i + 4] for i in range(3)] + [[i + 4, i + 5, i + 1, i] for i in range(3)]
    out.append(Piece("tapetail", "cloth-vex", v, f).rigid(b))
    return [p for p in out if p is not None]


def poster():
    """The wanted poster, its own sheet on the sleeve (top of the cannon when she aims): a curved patch, torn edges, the pin. The art is the weapon sheet's."""
    rows, cols = 7, 6
    r = SLEEVE_R + 0.0035
    rng = np.random.RandomState(7)
    v, uv = [], []
    S0, S1 = -0.125, 0.092
    A = 0.78
    for i in range(rows):
        k = i / (rows - 1)
        for j in range(cols):
            q = j / (cols - 1)
            a, s_ = (q - 0.5) * 2 * A, S0 + (S1 - S0) * k
            if i in (0, rows - 1):
                s_ += rng.uniform(-0.009, 0.009)
            if j in (0, cols - 1):
                a += rng.uniform(-0.09, 0.09)
            v.append(C(s_, np.sin(a) * r, SLEEVE_F + np.cos(a) * r))
            uv.append((q, k))
    v = np.array(v)
    f = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            a = i * cols + j
            f.append([a, a + 1, a + 1 + cols, a + cols])
    p = Piece("poster", "cloth-vex", v, f).rigid("forearm.R")
    p.orient(tuple(C(0, 0, SLEEVE_F)))
    p.pu = np.array(uv)
    pin = lathe("posterpin", "metal-vex", 0.0, SLEEVE_F + r + 0.002, [(S0 + 0.012, 0.0), (S0 + 0.012, 0.009), (S0 + 0.019, 0.009), (S0 + 0.019, 0.0)], n=6, cap=False)
    return [p, pin]


def pumpkin(name, s, u, f, r, h):
    """A fat ribbed grenade with a steel lid."""
    n = 10
    prof = [(s - h * 0.5, 0.0), (s - h * 0.5, r * 0.55), (s - h * 0.3, r * 0.92), (s, r), (s + h * 0.3, r * 0.92), (s + h * 0.5, r * 0.55), (s + h * 0.5, 0.0)]
    p = lathe(name, "metal-vex", u, f, prof, n=n, cap=False)
    return p


def drum():
    """The grenade drum outside the sleeve: two stacked grenades, the lid, the bracket."""
    u, f = SLEEVE_R + 0.052, SLEEVE_F - 0.016
    out = [pumpkin("gren0", 0.03, u, f, 0.046, 0.075), pumpkin("gren1", -0.05, u, f, 0.046, 0.075)]
    out.append(lathe("dlid", "metal-vex", u, f, [(-0.10, 0.0), (-0.10, 0.05), (-0.085, 0.054), (-0.085, 0.0)], n=10, cap=False))
    out.append(lathe("dfoot", "metal-vex", u, f, [(0.07, 0.0), (0.07, 0.044), (0.082, 0.044), (0.082, 0.0)], n=8, cap=False))
    out.append(box("dbrkt", "brass-vex", C(0.0, SLEEVE_R + 0.008, SLEEVE_F), (0.016, 0, 0), (0, 0.024, 0), (0, 0, 0.1), "forearm.R"))
    return out


def plate():
    """The riveted shoulder plate, the socket: a curved shell over the shoulder and down the strut, its back edge lobed as the weapon sheet."""
    S = J("upper_arm.R")
    rows, cols = 7, 10
    v_out, v_in = [], []
    for i in range(rows):
        k = i / (rows - 1)
        for j in range(cols):
            a = (j / (cols - 1) - 0.5) * 3.5                       # round the arm, front to back through the outside
            w = (0.105 - 0.03 * k) * (1.0 - 0.28 * smooth(0.7, 1.0, abs(a) / 1.75))
            cz = S[2] + 0.07 - 0.27 * k
            top = smooth(0.0, 0.22, k) * 0.7 + 0.3
            x = S[0] + 0.022 + np.cos(a) * w * top * 1.02 + 0.03 * k
            y = np.sin(a) * w * 1.05
            v_out.append((x, y, cz))
            v_in.append((S[0] + 0.022 + np.cos(a) * (w * top - 0.012) * 1.02 + 0.03 * k, np.sin(a) * (w - 0.012) * 1.05, cz))
    v = np.array(v_out + v_in)
    f = []
    n = rows * cols
    for i in range(rows - 1):
        for j in range(cols - 1):
            a = i * cols + j
            f.append([a, a + 1, a + 1 + cols, a + cols])
            f.append([n + a, n + a + cols, n + a + 1 + cols, n + a + 1])
    for j in range(cols - 1):
        f.append([j + 1, j, n + j, n + j + 1])
        a = (rows - 1) * cols + j
        f.append([a, a + 1, n + a + 1, n + a])
    for i in range(rows - 1):
        a = i * cols
        f.append([a, a + cols, n + a + cols, n + a])
        b = a + cols - 1
        f.append([b + cols, b, n + b, n + b + cols])
    return Piece("plate", "metal-vex", v, f).rigid("upper_arm.R")


def strut():
    """The upper arm: a hydraulic strut from the socket to the elbow pivot, and the pivot's drum through the cannon."""
    S = J("upper_arm.R")
    a = S + [0.018, 0, -0.14]
    out = [sweep("strut", "metal-vex", [a, (a + E) / 2, E + [0, 0, 0.01]], ring(7), np.array([0.05, 0.043, 0.038]), side_hint=np.array([0, 1.0, 0]), tip=False).rigid("upper_arm.R")]
    d = np.array([1.0, 0, 0])
    ctr = E + [OUT * 0.5, 0, 0]
    t = np.array([ctr - d * 0.05, ctr + d * 0.05])
    out.append(sweep("pivot", "brass-vex", [t[0], t[0] + d * 0.002, t[1] - d * 0.002, t[1]], ring(10), np.array([0.03, 0.047, 0.047, 0.03]), side_hint=np.array([0, 1.0, 0]), tip=False).rigid("forearm.R"))
    return out


def hose(name, pts, r=0.0125, n=9, bones=None, sec=5):
    path = catmull(np.array(pts, float), n)
    p = sweep(name, "metal-hose", path, ring(sec), np.full(n, r), side_hint=np.array([0.3, 0.3, 0.9]), tip=False)
    t = np.repeat(np.linspace(0, 1, n), sec)
    bones = bones or ["hips"]
    if len(bones) == 1:
        p.rigid(bones[0])
    else:
        b0, b1 = bones
        q = smooth(0.25, 0.75, t)
        p.w = {b0: 1 - q, b1: q}
    p.t = t
    return p


def gear_pack(z_top, back_y):
    """The gear pack: the brass-rimmed round magazine high on her left shoulder blade (it leaves the spine bare), the belt loop round it, the feed hose over the
    neck to the socket. -> pieces, the belt's start."""
    c = np.array([-0.12, back_y - 0.05, z_top + 0.06])
    d = np.array([0, 1.0, 0.12])
    d = norm(d)
    a = norm(np.cross(d, (1.0, 0, 0)))
    b = np.cross(d, a)

    def lat(name, mat, prof, n=14):
        v, f = [], []
        for s, r in prof:
            for t in np.linspace(0, 2 * np.pi, n, endpoint=False):
                v.append(c + d * s + a * np.cos(t) * r + b * np.sin(t) * r)
        for i in range(len(prof) - 1):
            for j in range(n):
                p, q = i * n + j, i * n + (j + 1) % n
                f.append([p, q, q + n, p + n])
        return Piece(name, mat, np.array(v), f).rigid("hips")
    out = [lat("packdisc", "metal-vex", [(0.03, 0.0), (0.03, 0.07), (0.0, 0.076), (-0.036, 0.076), (-0.042, 0.062), (-0.042, 0.0)]),
           lat("packrim", "brass-vex", [(-0.052, 0.07), (-0.058, 0.058), (-0.044, 0.044), (-0.037, 0.044), (-0.036, 0.078), (-0.046, 0.078)])]
    return out, c, a, b


def belt_path_tile(name, path, width=0.021, uvrect=(0, 0, 1, 1), hint=None):
    """The ammunition belt: a saw-tooth ribbon, each cartridge a raised step, with a tiled paint."""
    p = np.asarray(path, float)
    t = norm(np.gradient(p, axis=0))
    n = norm(p * [1, 1, 0] - [0, -0.02, 0])
    s = norm(np.cross(t, n))
    n = norm(np.cross(s, t)) * np.sign(np.sum(np.cross(s, t) * n, axis=1, keepdims=True))
    v, f, uv = [], [], []
    for i in range(len(p)):
        h = 0.021 if i % 2 == 0 else 0.007
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


def all_pieces():
    return sleeve() + gatling() + launcher() + drum() + [plate()] + strut()


def empties():
    """FX points in rest space: (bone, position)."""
    return {"weapon_muzzle": ("gatling", tuple(C(TIP_S + 0.03, 0, GATLING_F))),
            "gatling_muzzle": ("gatling", tuple(C(TIP_S + 0.03, 0, GATLING_F))),
            "launcher_muzzle": ("launcher", tuple(C(BELL_S - 0.02, 0, TUBE_F))),
            "launcher_fire": ("forearm.R", tuple(C(2 * POST_S - BELL_S + 0.02, 0, TUBE_F))),      # the bell's place once swung forward: fixed on the cannon, right at the press
            "anchor_gatling_root": ("forearm.R", tuple(C(0.17, 0, GATLING_F))),
            "anchor_sleeve_mouth": ("forearm.R", tuple(C(0.25, 0, SLEEVE_F))),
            "anchor_grenade_drum": ("forearm.R", tuple(C(-0.01, SLEEVE_R + 0.052, SLEEVE_F - 0.016)))}

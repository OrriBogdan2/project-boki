"""Cinder's own clips on Meshy's skeleton (art/wardens/cinder/cinder_clips.glb), written without Blender.
Meshy's rig is read from art/wardens/cinder/cinder_meshy.glb (nodes only: every bone's +Y runs to its child). Each clip is
a list of key poses (character frame: r = her right, u = up, f = forward, metres from the feet); a pose is solved by FK
with two-bone IK for the arms and (full-body clips) legs, and written as rotation tracks sampled at FPS, on top of the
rest pose, in Meshy's node space (tracks match the game's skeleton by bone name).
Upper clips (names starting cn_u_) key only the torso, head and arms: the game lays them over the walk, run or idle
(data "kmoves" in content/rules/warden_native.json). Full clips (cn_f_) key every joint.
Timings are the kit's: LMB spool 0.34 s then a hold; Cinder Shot cast 0.4 s then the push on the frame the bolt spawns;
Furnace Cloak blast on the first frame (arms-wide peak by 0.05 s); Flue Flight lift 0.22 s then the flight loop; light landing.
Run: python3 -I tools/meshy/cinder_native_clips.py [--shot] [out.glb]   (--shot prints the wrist and palm of each key)"""

import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "art1"))
import glb_add_clips as G  # noqa: E402
import glb_clips_only as CO  # noqa: E402

RIG = "art/wardens/cinder/cinder_meshy.glb"
OUT = "art/wardens/cinder/cinder_clips.glb"
FPS = 30.0


def V(r, u, f, side="R"):
    """A character-frame vector (outward, up, forward) in Meshy's node space (it faces +Z, her right is -X): outward is
    away from the midline on the given side, so one pose reads for both arms and legs."""
    return np.array([-r if side == "R" else r, u, f], float)


def unit(v):
    return v / max(np.linalg.norm(v), 1e-9)


def rot_axis(axis, a):
    axis = unit(np.asarray(axis, float))
    x, y, z = axis
    c, s = math.cos(a), math.sin(a)
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def rot_euler(e):
    """World-frame rotation of (pitch forward, turn to her left, tilt to her right) radians."""
    return rot_axis((0, 0, 1), -e[2]) @ rot_axis((0, 1, 0), e[1]) @ rot_axis((1, 0, 0), e[0])


def arc(a, b):
    a, b = unit(a), unit(b)
    c = float(np.dot(a, b))
    if c > 0.999999:
        return np.eye(3)
    if c < -0.999999:
        p = unit(np.cross(a, (1, 0, 0) if abs(a[0]) < 0.9 else (0, 0, 1)))
        return rot_axis(p, math.pi)
    ax = np.cross(a, b)
    return rot_axis(ax, math.atan2(np.linalg.norm(ax), c))


def quat(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [s / 4, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 1] + m[1, 0]) / s, s / 4, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
    else:
        s = math.sqrt(1 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, s / 4, (m[1, 0] - m[0, 1]) / s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


class Rig:
    def __init__(self, path):
        self.j, self.bin = G.read(path)
        n = self.j["nodes"]
        self.names = [x.get("name", "") for x in n]
        self.idx = {nm: i for i, nm in enumerate(self.names)}
        self.parent = {}
        for i, x in enumerate(n):
            for c in x.get("children", []):
                self.parent[c] = i
        self.rq = [mat(np.array(x.get("rotation", [0, 0, 0, 1]), float)) for x in n]
        self.t = [np.array(x.get("translation", [0, 0, 0]), float) for x in n]
        self.joints = self.j["skins"][0]["joints"]
        self.order = []  # parents first, from the armature
        def walk(i):
            self.order.append(i)
            for c in n[i].get("children", []):
                walk(c)
        walk(self.idx["SmartRigArmature"])
        self.rest = self.fk({})
        self.hips_rest = self.t[self.idx["Hips"]].copy()

    def fk(self, over):
        """Global (R, p) of every node. over: node -> ("rot", R global) | ("dir", dir, twist) | ("delta", R world) | ("t", p local)."""
        out = {}
        for i in self.order:
            nm = self.names[i]
            par = self.parent.get(i)
            Rp, pp = out[par] if par is not None else (np.eye(3), np.zeros(3))
            tl = self.t[i] + over.get(("off", nm), 0)
            R0 = Rp @ self.rq[i]
            R = R0
            o = over.get(nm)
            if o is not None:
                if o[0] == "dir":
                    R = arc(R0[:, 1], o[1]) @ R0
                    if o[2]:
                        R = rot_axis(R[:, 1], o[2]) @ R
                elif o[0] == "delta":
                    R = o[1] @ R0
                elif o[0] == "rot":
                    R = o[1]
            out[i] = (R, pp + Rp @ tl)
        return out

    def pos(self, g, nm):
        return g[self.idx[nm]][1]


RIGS = None


def rig():
    global RIGS
    if RIGS is None:
        RIGS = Rig(RIG)
    return RIGS


def two_bone(S, T, l1, l2, pole):
    d = np.linalg.norm(T - S)
    d = min(max(d, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.999)
    u = unit(T - S)
    T = S + u * d
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    pp = pole - u * np.dot(pole, u)
    pp = unit(pp) if np.linalg.norm(pp) > 1e-6 else unit(np.cross(u, (0, 1, 0)))
    E = S + u * a + pp * h
    return unit(E - S), unit(T - E)


ARM = {"R": ("RightShoulder", "RightArm", "RightForeArm", "RightHand"), "L": ("LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand")}
LEG = {"R": ("RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"), "L": ("LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase")}
SPINE = ["Spine02", "Spine01", "Spine", "neck", "Head"]
UPPER = SPINE + ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
PIVOT_BONE = {"R": "RightHand", "L": "LeftHand"}


def rest_pose():
    """The pose parameters of the standing rest: wrists and ankles where Meshy's rest has them."""
    R = rig()
    g = R.rest
    p = {"hips": (0.0, 0.0, 0.0), "hips_rot": (0.0, 0.0, 0.0)}
    for s in "RL":
        w = R.pos(g, ARM[s][3])
        e = R.pos(g, ARM[s][2])
        sh = R.pos(g, ARM[s][1])
        sg = -1.0 if s == "R" else 1.0
        p["w" + s] = (sg * w[0], w[1], w[2])
        pl = unit(e - (sh + w) / 2)
        p["pole" + s] = (sg * pl[0], pl[1], pl[2])
        p["hand" + s] = None
        p["twist" + s] = 0.0
        p["reach" + s] = 0.0
        a = R.pos(g, LEG[s][2])
        p["a" + s] = (sg * a[0], a[1], a[2])
        p["foot" + s] = None
    for b in SPINE:
        p["e_" + b] = (0.0, 0.0, 0.0)
    return p


def lerp(a, b, k):
    if a is None or b is None:
        return b if k >= 0.5 else a
    if isinstance(a, (int, float)):
        return a + (b - a) * k
    return tuple(x + (y - x) * k for x, y in zip(a, b))


def mix(pa, pb, k):
    return {key: lerp(pa[key], pb[key], k) for key in pa}


def solve(p, full, hips_lock=False):
    """The pose p as local rotations of every joint (full: legs and hips too). Returns ({node name: quat}, hips translation, globals)."""
    R = rig()
    cache = R.rest
    over = {("off", "Hips"): np.array([-p["hips"][0], p["hips"][1], p["hips"][2]])}
    if full:
        over["Hips"] = ("delta", rot_euler(p["hips_rot"]))
    for b in SPINE:
        over[b] = ("delta", rot_euler(p["e_" + b]))
    # pass 1: the spine and shoulders, to know where the shoulders are
    g = R.fk(over)
    for s in "RL":  # a reach shrugs the shoulder bone toward the wrist (the push of a thrown palm)
        if p["reach" + s] > 0:
            sh_n, up_n = ARM[s][0], ARM[s][1]
            T = V(*p["w" + s], side=s)
            now = g[R.idx[sh_n]][0][:, 1]
            over[sh_n] = ("dir", unit(now + (unit(T - R.pos(g, sh_n)) - now) * p["reach" + s]), 0.0)
    g = R.fk(over)
    for s in "RL":
        sh_n, up_n, fo_n, ha_n = ARM[s]
        S = R.pos(g, up_n)
        l1 = np.linalg.norm(R.pos(cache, fo_n) - R.pos(cache, up_n))
        l2 = np.linalg.norm(R.pos(cache, ha_n) - R.pos(cache, fo_n))
        T = V(*p["w" + s], side=s)
        pole = V(*p["pole" + s], side=s)
        d1, d2 = two_bone(S, T, l1, l2, pole)
        over[up_n] = ("dir", d1, 0.0)
        over[fo_n] = ("dir", d2, 0.0)
        hd = p["hand" + s]
        over[ha_n] = ("dir", V(*hd, side=s) if hd is not None else d2, p["twist" + s])
        if s == "R":
            pass
    if full:
        g = R.fk(over)
        for s in "RL":
            up_n, kn_n, an_n, to_n = LEG[s]
            S = R.pos(g, up_n)
            l1 = np.linalg.norm(R.pos(cache, kn_n) - R.pos(cache, up_n))
            l2 = np.linalg.norm(R.pos(cache, an_n) - R.pos(cache, kn_n))
            T = V(*p["a" + s], side=s)
            pole = np.array([0.0, 0.1, 1.0])
            d1, d2 = two_bone(S, T, l1, l2, pole)
            over[up_n] = ("dir", d1, 0.0)
            over[kn_n] = ("dir", d2, 0.0)
            fd = p["foot" + s]
            if fd is not None:
                over[an_n] = ("dir", V(*fd, side=s), 0.0)
            else:
                # flat on the ground as at rest: the foot keeps Meshy's rest world direction
                rest_dir = R.rest[R.idx[an_n]][0][:, 1]
                over[an_n] = ("dir", rest_dir, 0.0)
    g = R.fk(over)
    return over, g


def local_quats(g, nodes):
    R = rig()
    out = {}
    for i in nodes:
        par = R.parent.get(i)
        Rp = g[par][0] if par is not None else np.eye(3)
        out[i] = quat(Rp.T @ g[i][0])
    return out


EASE = {"lin": lambda u: u, "out": lambda u: 1 - (1 - u) ** 2, "in": lambda u: u * u, "sm": lambda u: u * u * (3 - 2 * u)}


def sample(keys, dur, loop=False):
    """keys: [(t, pose-or-delta dict, ease)] -> pose at each frame."""
    base = rest_pose()
    ks = [(t, {**base, **pz}, e) for t, pz, e in keys]
    n = int(round(dur * FPS))
    out = []
    for f in range(n + 1):
        t = f / FPS
        if t <= ks[0][0]:
            out.append(ks[0][1])
            continue
        if t >= ks[-1][0]:
            out.append(ks[-1][1])
            continue
        for a, b in zip(ks, ks[1:]):
            if a[0] <= t <= b[0]:
                u = (t - a[0]) / (b[0] - a[0])
                out.append(mix(a[1], b[1], EASE[b[2]](u)))
                break
    return out


# ---- the poses ----------------------------------------------------------------------------------------------
Z3 = (0.0, 0.0, 0.0)


def P(**kw):
    return kw


def lean(spine=0.0, twist=0.0, tilt=0.0, head=(0.0, 0.0, 0.0), neck=0.0):
    """Torso deltas spread over the spine chain, the head's own."""
    k = {"e_Spine02": (spine * 0.3, twist * 0.2, tilt * 0.3), "e_Spine01": (spine * 0.3, twist * 0.3, tilt * 0.3),
         "e_Spine": (spine * 0.4, twist * 0.5, tilt * 0.4), "e_neck": (neck, 0.0, 0.0), "e_Head": head}
    return k


FOLD = dict(wL=(0.19, 1.00, 0.04), poleL=(0.0, -0.3, -1.0))  # (set per pose where used)


def clips():
    out = {}
    # ---- LMB: the pilot's spool, then the hose held out from her right palm -----------------------------------
    # Right arm: elbow tucked at the hip, forearm out, palm forward at chest height; the left arm stays loose, bracing a little.
    pole_back = (0.5, -0.8, -0.7)
    spool = P(wR=(0.22, 1.18, 0.36), poleR=(0.5, -0.9, -0.5), handR=(0.0, 0.1, 1.0), wL=(0.30, 1.0, 0.1), poleL=(0.5, -0.8, -0.6), **lean(0.12, -0.2, 0.0, (-0.1, 0.1, 0.0)))
    snap = P(wR=(0.16, 1.28, 0.58), poleR=(0.4, -0.9, -0.5), handR=(0.0, 0.15, 1.0), wL=(0.34, 0.98, 0.04), poleL=(0.5, -0.8, -0.6), **lean(0.06, -0.3, 0.0, (-0.05, 0.12, 0.0)))
    kick = P(wR=(0.17, 1.26, 0.50), poleR=(0.4, -0.9, -0.5), handR=(0.0, 0.2, 1.0), wL=(0.34, 1.0, 0.02), poleL=(0.5, -0.8, -0.6), **lean(-0.04, -0.3, 0.0, (-0.08, 0.12, 0.0)))
    held = P(wR=(0.16, 1.27, 0.54), poleR=(0.4, -0.9, -0.5), handR=(0.0, 0.17, 1.0), wL=(0.34, 0.99, 0.03), poleL=(0.5, -0.8, -0.6), **lean(0.02, -0.3, 0.0, (-0.07, 0.12, 0.0)))
    buck = P(wR=(0.16, 1.30, 0.50), poleR=(0.4, -0.9, -0.5), handR=(0.0, 0.25, 1.0), wL=(0.34, 1.01, 0.01), poleL=(0.5, -0.8, -0.6), **lean(-0.04, -0.32, 0.0, (-0.06, 0.12, 0.0)))
    out["cn_u_lance"] = (0.34, False, [(0.0, rest_pose(), "lin"), (0.1, spool, "out"), (0.2, snap, "out"), (0.27, kick, "out"), (0.34, held, "sm")])
    # the hold (loops 0.5 s at 8 Hz-ish bucking, the same first and last pose)
    out["cn_u_lance_loop"] = (0.5, True, [(0.0, held, "lin"), (0.0625, buck, "lin"), (0.125, held, "lin"), (0.1875, buck, "lin"), (0.25, held, "lin"),
                                          (0.3125, buck, "lin"), (0.375, held, "lin"), (0.4375, buck, "lin"), (0.5, held, "lin")])
    # let go: the arm drops back off the aim
    out["cn_u_lance_end"] = (0.3, False, [(0.0, held, "lin"), (0.08, dict(snap, **{}), "out"), (0.3, rest_pose(), "sm")])
    # ---- RMB: the palm up to the eye, sighting along the arm (the cast's 0.4 s), then the push on the bolt frame --
    aim0 = P(wR=(0.16, 1.40, 0.40), poleR=(0.5, -0.9, -0.4), handR=(0.0, 0.3, 1.0), wL=(0.30, 1.0, 0.12), poleL=(0.5, -0.8, -0.6), **lean(0.06, -0.3, 0.0, (0.0, 0.3, 0.0)))
    aim1 = P(wR=(0.11, 1.56, 0.58), poleR=(0.5, -0.9, -0.3), handR=(0.0, 0.1, 1.0), wL=(0.30, 0.98, 0.10), poleL=(0.5, -0.8, -0.6), **lean(0.1, -0.34, 0.0, (0.05, 0.36, 0.0)))
    out["cn_u_aim"] = (0.3, False, [(0.0, rest_pose(), "lin"), (0.1, aim0, "out"), (0.3, aim1, "sm")])
    sh0 = P(wR=(0.11, 1.57, 0.60), poleR=(0.5, -0.9, -0.3), handR=(0.0, 0.1, 1.0), wL=(0.30, 0.98, 0.10), poleL=(0.5, -0.8, -0.6), **lean(0.1, -0.34, 0.0, (0.05, 0.36, 0.0)))
    push = P(wR=(0.10, 1.62, 0.68), reachR=0.8, poleR=(0.5, -0.9, -0.2), handR=(0.0, 0.18, 1.0), wL=(0.32, 1.0, 0.04), poleL=(0.5, -0.8, -0.6), **lean(-0.12, -0.3, 0.0, (-0.1, 0.3, 0.0)))
    out["cn_u_shot"] = (0.5, False, [(0.0, sh0, "lin"), (0.07, push, "out"), (0.16, dict(push, wR=(0.10, 1.62, 0.64)), "sm"), (0.32, dict(aim1, **lean(0.06, -0.2, 0.0, (0.0, 0.2, 0.0))), "sm"), (0.5, rest_pose(), "sm")])
    # ---- E, Furnace Cloak: a tuck for the blink, then everything flung wide on the blast frame ------------------
    tuck = P(wR=(0.14, 1.20, 0.30), poleR=(0.6, -0.8, -0.3), handR=(0.0, 0.0, 1.0), wL=(0.14, 1.20, 0.30), poleL=(0.6, -0.8, -0.3), hips=(0.0, -0.02, 0.0), **lean(0.28, 0.0, 0.0, (0.05, 0.0, 0.0)))
    wide = P(wR=(0.74, 1.54, 0.04), poleR=(0.1, -1.0, -0.3), handR=(1.0, 0.25, 0.0), twistR=0.0,
             wL=(0.74, 1.54, 0.04), poleL=(0.1, -1.0, -0.3), handL=(1.0, 0.25, 0.0), **lean(-0.30, 0.0, 0.0, (-0.35, 0.0, 0.0)))
    # (the pose is 0 at the press: the blast frame is frame 1; the tuck is the 0.03 s before, folded into frame 0)
    out["cn_u_cloak"] = (0.55, False, [(0.0, tuck, "lin"), (0.04, wide, "out"), (0.2, dict(wide, wR=(0.72, 1.52, 0.02), wL=(0.72, 1.52, 0.02)), "sm"), (0.55, rest_pose(), "sm")])
    return out


def flights():
    """Full-body clips (every joint): Flue Flight's take-off, flight loop and landing."""
    out = {}
    R = rig()
    rest = rest_pose()
    aR, aL = rest["aR"], rest["aL"]
    arms_dn = dict(wR=(0.30, 0.95, -0.02), poleR=(0.6, -0.5, -0.8), wL=(0.30, 0.95, -0.02), poleL=(0.6, -0.5, -0.8))
    # take-off: down into a crouch as the ring bursts, then up on the two heel jets, leaning into it, arms back
    crouch = P(hips=(0.0, -0.17, 0.02), hips_rot=(0.28, 0.0, 0.0), aR=(aR[0], aR[1], aR[2]), aL=(aL[0], aL[1], aL[2]),
               wR=(0.26, 1.02, 0.24), poleR=(0.6, -0.6, -0.6), wL=(0.26, 1.02, 0.24), poleL=(0.6, -0.6, -0.6), **lean(0.1, 0.0, 0.0, (-0.15, 0.0, 0.0)))
    hip_pitch = 1.0  # radians the body leans into the flight (the contract's 0.62 + 0.28 hips)
    def fly(ph, a_back=0.0):
        hp = (hip_pitch, 0.0, 0.0)
        return P(hips=(0.0, 0.06, 0.06), hips_rot=hp,
                 aR=(0.13, 0.80, -0.50 - 0.04 * a_back), aL=(0.12, 0.84 + 0.04 * a_back, -0.46), footR=(0.0, -0.45, -0.9), footL=(0.0, -0.45, -0.9),
                 wR=(0.26, 1.22 + 0.2 * ph, -0.10), poleR=(0.7, 0.4, -0.2), wL=(0.28, 1.2 - 0.2 * ph, -0.08), poleL=(0.7, 0.4, -0.2),
                 **lean(-0.15, 0.0, 0.0, (-0.55, 0.0, 0.0)))
    f0 = fly(0.0)
    f1 = fly(0.4, 0.5)
    f2 = fly(-0.3, 1.0)
    f3 = fly(0.2, 0.0)
    out["cn_f_takeoff"] = (0.22, False, [(0.0, rest_pose(), "lin"), (0.08, crouch, "out"), (0.22, f0, "out")])
    out["cn_f_fly"] = (0.78, True, [(0.0, f0, "lin"), (0.23, f1, "lin"), (0.5, f2, "lin"), (0.78, f0, "lin")])
    fl0 = dict(f0, hips_rot=(0.4, 0.0, 0.0))
    sq = P(hips=(0.0, -0.07, 0.0), hips_rot=(0.12, 0.0, 0.0), **lean(0.1, 0.0, 0.0, (-0.1, 0.0, 0.0)),
           wR=(0.28, 1.0, 0.06), poleR=(0.6, -0.6, -0.6), wL=(0.28, 1.0, 0.06), poleL=(0.6, -0.6, -0.6))
    out["cn_f_land"] = (0.25, False, [(0.0, fl0, "lin"), (0.07, sq, "out"), (0.25, rest_pose(), "sm")])
    return out


def _acc(j, bin_, data, typ, comp=5126, minmax=False):
    arr = np.asarray(data, np.float32)
    off = len(bin_)
    bin_.extend(arr.tobytes())
    bin_.extend(b"\0" * (-len(bin_) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes})
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": comp, "count": len(arr), "type": typ}
    if minmax:
        a["min"] = [float(arr.min())]
        a["max"] = [float(arr.max())]
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def build(out_path, shot=False):
    R = rig()
    j, bin_ = CO.rig_only(R.j, R.bin)
    bin_ = bytearray(bin_)
    j["animations"] = []
    fixed = [i for i in R.joints]  # every joint of the skin
    upper = {R.idx[n] for n in UPPER}
    defs = {}
    defs.update({k: (v, False) for k, v in clips().items()})
    defs.update({k: (v, True) for k, v in flights().items()})
    for name, ((dur, loop, keys), full) in defs.items():
        poses = sample(keys, dur, loop)
        nodes = fixed if full else sorted(upper)
        times = [f / FPS for f in range(len(poses))]
        per = {i: [] for i in nodes}
        hips_t = []
        for p in poses:
            over, g = solve(p, full)
            q = local_quats(g, nodes)
            for i in nodes:
                per[i].append(q[i])
            if full:
                hips_t.append(R.t[R.idx["Hips"]] + over[("off", "Hips")])
        t_acc = _acc(j, bin_, times, "SCALAR", minmax=True)
        samplers, channels = [], []
        for i in nodes:
            qs = np.array(per[i])
            for k in range(1, len(qs)):  # one hemisphere, so a straight lerp is the short way
                if np.dot(qs[k], qs[k - 1]) < 0:
                    qs[k] = -qs[k]
            samplers.append({"input": t_acc, "output": _acc(j, bin_, qs, "VEC4"), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": i, "path": "rotation"}})
        if full:
            samplers.append({"input": t_acc, "output": _acc(j, bin_, hips_t, "VEC3"), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": R.idx["Hips"], "path": "translation"}})
        j["animations"].append({"name": name, "samplers": samplers, "channels": channels})
        if shot:
            for f in (0, len(poses) // 2, len(poses) - 1):
                over, g = solve(poses[f], full)
                print(name, "t=%.2f" % times[f], "wristR(r,u,f)", np.round(R.pos(g, "RightHand") * [-1, 1, 1], 2), "wristL(-r)", np.round(R.pos(g, "LeftHand") * [-1, 1, 1], 2),
                      "head", np.round(R.pos(g, "Head") * [-1, 1, 1], 2), "ankleR", np.round(R.pos(g, "RightFoot") * [-1, 1, 1], 2))
    j["buffers"] = [{"byteLength": len(bin_)}]
    G.write(out_path, j, bin_)
    print("wrote", out_path, [a["name"] for a in j["animations"]], os.path.getsize(out_path), "bytes")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build(args[0] if args else OUT, "--shot" in sys.argv)

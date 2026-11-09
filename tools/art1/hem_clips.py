"""ART-1 Hem's animation set (keyed as targets, solved here on tools/art1/posekit.py). Times match the kit's kmove tables
(scripts/match/kmoves_pin_bjorn.gd) and longbow.json: the draw is one steady pull to Supercharged (1.15 s, no pose pop at
Empowered, 0.6 s) so it reads with item 55b's filling line; the perfect-timing circle has no pose of its own.
Personality: cool, patient, economical, feet planted; every release is a flick, not a heave. Standing, she watches: long holds,
one deliberate head turn, a hand on her hip, chin up, and a thread tested between two fingers. The bow never leaves her left hand.
Run: blender -b --python tools/art1/hem_clips.py -- <hem_art1.blend or the last *_anim.blend> <out.glb> [clip,clip]"""
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import hem_pieces as H
import crouchkit
from posekit import Clip, FnClip, Solver, add_breath, ang_dir as D, frame_of, lerp, two_bone

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
J = H.joints(os.path.join(REPO, "art/wardens/src/hem_rig.json"))
LIFT = Vector((0, 0, float(J["hips"][2]) - 0.777))   # the poses below were keyed on a hips at 0.777: hers stand this much taller
A_Z = 0.082
FPS = 30
UP = (0, 0, 1)
GC, GA, GS = [tuple(float(v) for v in a) for a in H.grip_frame(J)]


def n3(v):
    return tuple(Vector(v).normalized())


# ---- poses
READY = {
    "pel": (0.036, 0.006, -0.040), "prt": (0.08, 0.10, -0.070), "tor": (0.14, 0.10, 0.11), "hed": (-0.22, -0.10, -0.04),
    "FL": (-0.130, 0.115, A_Z), "FR": (0.085, -0.040, A_Z), "FLy": 0.42, "FRy": -0.30, "FLp": 0.0, "FRp": 0.0,
    # the bow low and easy in the left hand, the right on her hip
    "G": (-0.255, 0.215, 0.720), "BA": n3((-0.24, 0.60, 0.76)), "BS": n3((0.95, 0.20, 0.22)),
    "Rw": 0.0, "RF": (0.208, 0.010, 0.962), "RD": n3((-0.42, 0.68, -0.60)), "RP": n3((-0.82, -0.40, 0.10)), "Rpole": (1.0, -0.45, 0.0),
    "Lpole": (-0.9, -0.3, -0.3), "dr": 0.0, "ar": 0.0, "brow": 0.25, "lid": 0.08, "fing": 0.45, "pin": 0.25,
}
AIM_Y = -0.98
AIM = {"tor": (0.02, AIM_Y, 0.02), "hed": (-0.03, -AIM_Y - 0.04, 0.05), "G": (-0.052, 0.585, 1.300), "BA": n3((0.10, 0.02, 1.0)), "BS": (0.0, -1.0, 0.0),
       "Lpole": (-0.5, -0.2, -0.9), "Rpole": (0.35, -1.0, 0.1), "RD": (0.0, 1.0, 0.0), "RP": (-1.0, 0.0, 0.0), "brow": 0.75, "lid": 0.2}
NOCK = dict(AIM, Rw=1.0, ar=1.0, dr=0.0, fing=0.7, pin=0.8)
HIP = {k: READY[k] for k in ("tor", "hed", "G", "BA", "BS", "Rw", "RF", "RD", "RP", "Rpole", "Lpole", "dr", "ar", "brow", "lid", "fing", "pin")}


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, keys, base, loop)


class HemSolver(Solver):
    """posekit's Solver, with the weapon in the LEFT hand: G the fist, BA the bow's long axis, BS the side its string lies on.
    Rw 1: the right hand on the string's nock, drawn dr (0..1) from its rest to the anchor at her jaw; Rw 0: free at RF."""

    def __init__(self, arm, pinch):
        super().__init__(arm, {"pelvis": float(J["hips"][2]), "blade_rest": GA, "edge_rest": GS})
        self.bow_rest = frame_of(GA, GS)
        self.hand_rest = frame_of((0, 0, -1), (-1, 0, 0))
        self.pinch = Vector(pinch)
        self.nock0 = Vector(H.bow_to_model(_v3((0, H.STRING_Y, 0)), J))
        self.anchor = Vector((-0.012, 0.140, 1.412 + 0.5 * LIFT.z))
        self.last = {}

    def solve(self, P):
        H0 = self.H0
        piv = Vector((0, 0, self.rig["pelvis"]))
        q_root = _eul(P["prt"])
        pel = Vector(P["pel"])
        root_at = piv + pel - q_root @ piv

        def D_root(x):
            return q_root @ (x - H0["root"]) + root_at
        hp = D_root(H0["hips"])
        q_hips = q_root @ _eul(P["tor"])

        def D_hips(x):
            return q_hips @ (x - H0["hips"]) + hp
        q_head = q_hips @ _eul(P["hed"])
        Q = {"root": q_root, "hips": q_hips, "head": q_head}
        # the bow hand
        G = Vector(P["G"]) + LIFT
        BA, BS = Vector(P["BA"]).normalized(), Vector(P["BS"])
        q_bow = frame_of(BA, BS) @ self.bow_rest.inverted()
        WL = G - q_bow @ (Vector(GC) - H0["hand.L"])
        qu, qf, _ = self.arm_ik("L", D_hips(H0["upper_arm.L"]), WL, Vector(P["Lpole"]), q_hips)
        Q["upper_arm.L"], Q["forearm.L"], Q["hand.L"] = qu, qf, q_bow
        # the string's nock
        n0 = G + q_bow @ (self.nock0 - Vector(GC))
        N = n0.lerp(Vector(P["CH"]) + LIFT if "CH" in P else self.anchor, P["dr"])
        # the draw hand
        q_h = frame_of(P["RD"], P["RP"]) @ self.hand_rest.inverted()
        Won = N - q_h @ (self.pinch - H0["hand.R"])
        WR = (Vector(P["RF"]) + LIFT).lerp(Won, P["Rw"])
        qu, qf, _ = self.arm_ik("R", D_hips(H0["upper_arm.R"]), WR, Vector(P["Rpole"]), q_hips)
        Q["upper_arm.R"], Q["forearm.R"], Q["hand.R"] = qu, qf, q_h
        Q["pauldron.L"], Q["pauldron.R"] = q_hips, q_hips
        # legs
        for side, key in (("L", "FL"), ("R", "FR")):
            Hp = D_root(H0["thigh." + side])
            yaw = P.get(key + "y", 0.0)
            # (key + "k": where the knee points, when not along the foot: a free knee turned in)
            pole = Quaternion((0, 0, 1), P.get(key + "k", yaw)) @ Vector((0.16 * (1 if side == "R" else -1), 1, 0.15))
            qt, qs = self.leg_ik(side, Hp, Vector(P[key]), pole, q_root)
            Q["thigh." + side], Q["shin." + side] = qt, qs
            Q["foot." + side] = Quaternion((0, 0, 1), yaw) @ Quaternion((1, 0, 0), P.get(key + "p", 0.0))
        self.last = {"N": N, "G": G, "q_bow": q_bow, "Q": Q, "hp": hp, "pbow": G - q_bow @ (Vector(GC) - H0["bow"])}
        return Q, root_at


def _v3(p):
    import numpy as np
    return np.array(p, np.float32)


def _eul(p):
    return Quaternion((0, 0, 1), p[1]) @ Quaternion((1, 0, 0), -p[0]) @ Quaternion((0, 1, 0), p[2])


# ---- idle and the signature stance (docs/art/IDLE_AUDIT.md, Lace the Red Stitch)
STAND = 6.0                                     # s: the idle and the stance loop, long enough for one fidget and two breaths
BREATH = 0.02                                   # x_breath's swell at the top of a breath (2 %)
BREATH_OUT = 0.6                                # the swell out through the ribs, against its rise up the bone
BREATH_C, BREATH_R = (0.0, 0.01, 1.14), (0.17, 0.13, 0.13)   # m: the rib cage's centre and half sizes (hips 0.78, shoulders 1.28)
LAG = {"pel": 0.0, "tor": 0.1, "hed": 0.2, "hand": 0.3}     # s behind the weight shift: the pelvis leads, the rest follows
FOLLOW = 4 / FPS                                # s: the shoulders turn this long after the head
SHIFT = (-0.065, 0.045)                         # m: the pelvis moves this far onto the front foot
KNEE_IN = 0.22                                  # rad: the free leg's knee turns in this far
HP0 = (READY["pel"][0], READY["pel"][1], 0.777 + READY["pel"][2])   # the hips' origin in the rest stance
YAW0 = READY["prt"][1] + READY["tor"][1]


def _step(u, a, b):
    """0 before a, 1 after b, a smoothstep between (loop phases)."""
    k = min(1.0, max(0.0, (u - a) / (b - a)))
    return k * k * (3 - 2 * k)


def _beat(u, a, b, c, d):
    """A move that goes out between a and b, holds, and comes back between c and d; 0 outside, so the loop closes."""
    return _step(u, a, b) - _step(u, c, d)


def _at(u, lag):
    """The loop phase `lag` s earlier; it wraps, so a lagged curve still closes on the seam."""
    return (u - lag / STAND) % 1.0


def _blink(u, t):
    return 0.92 * _beat(u, t, t + 0.012, t + 0.02, t + 0.045)


def _turned(point, yaw, hp):
    """A point that rides the hips: turned about the hips' origin hp by the body's yaw change."""
    return tuple(Vector(hp) + Quaternion((0, 0, 1), yaw - YAW0) @ (Vector(point) - Vector(HP0)))


def _stand(p, u, shift):
    """What every standing loop shares: the weight going onto the front foot and back once (shift = (out, in) phases)
    with the pelvis leading and the chest, head and hands trailing, soft knees, and two breaths on the rib cage."""
    a, b = shift
    w = {k: _beat(_at(u, s), a, a + 0.16, b, b + 0.16) for k, s in LAG.items()}
    dip = 4 * w["pel"] * (1 - w["pel"])
    p["pel"] = (0.036 + SHIFT[0] * w["pel"], 0.006 + SHIFT[1] * w["pel"], -0.052 - 0.008 * dip)
    p["prt"] = (0.08, 0.10 + 0.06 * w["pel"], -0.070 + 0.12 * w["pel"])
    p["FLk"] = READY["FLy"] - KNEE_IN * (1 - w["pel"])
    p["FRk"] = READY["FRy"] + KNEE_IN * w["pel"]
    br = {k: math.sin(4 * math.pi * _at(u, s) - math.pi / 2) for k, s in (("tor", 0.0), ("hed", FOLLOW), ("hand", 0.3))}
    p["breath"] = BREATH * (0.5 + 0.5 * br["tor"])
    p["tor"] = (p["tor"][0] - 0.008 * br["tor"], p["tor"][1], 0.11 - 0.09 * w["tor"])
    p["hed"] = (p["hed"][0] + 0.006 * br["hed"], p["hed"][1], -0.04 - 0.03 * w["hed"])
    p["w"], p["br"] = w, br
    return p


def _nock_hand(p):
    """The right hand on the string: fingers toward the bow's belly, the palm toward the bow hand (as at full draw)."""
    BA, BS = Vector(p["BA"]), Vector(p["BS"])
    return tuple(-BS), tuple(BS.cross(BA).normalized())


THREAD = {"G": (-0.16, 0.20, 0.90), "BA": n3((-0.45, 0.45, 0.77)), "BS": n3((0.80, -0.20, 0.58)), "Rpole": (1.0, -0.5, -0.1)}


def idle(u):
    """Watching. Long holds; the weight goes onto the front foot and back; one deliberate head turn the shoulders
    follow four frames later; and once a loop, still looking away, she lifts the bow a little, draws its thread taut
    between two fingers and lets it go: a seamstress testing her thread."""
    p = _stand(dict(READY), u, (0.20, 0.76))
    w, br = p["w"], p["br"]
    h = _beat(u, 0.40, 0.49, 0.80, 0.90)
    hs = 0.35 * _beat(_at(u, FOLLOW), 0.40, 0.49, 0.80, 0.90)
    p["hed"] = (p["hed"][0] + 0.04 * h, -0.10 + 0.50 * h, p["hed"][2])
    p["tor"] = (p["tor"][0], 0.10 + 0.14 * hs, p["tor"][2])
    yaw = p["prt"][1] + p["tor"][1]
    hp = (p["pel"][0], p["pel"][1], 0.777 + p["pel"][2])
    # the thread: reach, pull taut, hold, a flick back, the hand returns to the hip
    r = _beat(u, 0.52, 0.58, 0.73, 0.80)
    taut = _step(u, 0.58, 0.64) * (1 - _step(u, 0.69, 0.705))
    held = _step(u, 0.56, 0.60) * (1 - _step(u, 0.69, 0.705))
    for k in ("G", "BA", "BS", "Rpole"):
        p[k] = lerp(READY[k], THREAD[k], r)
    p["BA"], p["BS"] = n3(p["BA"]), n3(p["BS"])
    rd, rp = _nock_hand(p)
    p["RD"], p["RP"] = n3(lerp(READY["RD"], rd, r)), n3(lerp(READY["RP"], rp, r))
    p["Rw"], p["dr"] = r, 0.07 * taut
    p["pin"], p["fing"] = 0.25 + 0.60 * held, 0.45 + 0.15 * held - 0.15 * r * (1 - held)
    # the bow hand breathes with the chest and trails the weight; the hip hand rides the hip
    lag_w = w["hand"]
    p["G"] = (p["G"][0] + SHIFT[0] * 0.8 * lag_w, p["G"][1] + SHIFT[1] * 0.8 * lag_w, p["G"][2] + 0.003 * br["hand"])
    p["RF"] = _turned(READY["RF"], yaw, hp)
    p["lid"] = 0.08 + _blink(u, 0.495) + _blink(u, 0.905)
    del p["w"], p["br"]
    return p


NOCKED = dict(READY, **{
    "pel": (0.010, 0.028, -0.055), "prt": (0.08, 0.18, -0.03), "tor": (0.12, 0.12, 0.03), "hed": (-0.20, -0.26, 0.02),
    # the bow up loosely across the body, an arrow on the string, not drawn
    "G": (-0.13, 0.26, 0.98), "BA": n3((-0.38, 0.18, 0.91)), "BS": n3((0.33, -0.93, 0.32)),
    "Lpole": (-1.0, -0.3, -0.4), "Rpole": (1.0, -0.6, -0.3),
    "Rw": 1.0, "ar": 1.0, "dr": 0.0, "fing": 0.6, "pin": 0.8, "brow": 0.55, "lid": 0.22,
})
NOCKED["RD"], NOCKED["RP"] = _nock_hand(NOCKED)


def stance(u):
    """Sizing you up on the idle's feet: the bow up loosely across her, an arrow nocked and not drawn. The same slow
    weight shift and breath, one head turn the shoulders and the bow follow, and once a loop she takes up the string a
    little and lets it settle, feeling its tension."""
    p = _stand(dict(NOCKED), u, (0.15, 0.70))
    w, br = p["w"], p["br"]
    p["pel"] = (p["pel"][0] - 0.026, p["pel"][1] + 0.022, p["pel"][2] - 0.003)
    p["prt"] = (p["prt"][0], p["prt"][1] + 0.08, p["prt"][2] + 0.04)
    p["tor"] = (p["tor"][0] + 0.02, p["tor"][1] + 0.02, p["tor"][2] - 0.08)
    h = _beat(u, 0.38, 0.50, 0.78, 0.90)
    hs = 0.35 * _beat(_at(u, FOLLOW), 0.38, 0.50, 0.78, 0.90)
    p["hed"] = (p["hed"][0] + 0.03 * h, -0.26 + 0.44 * h, p["hed"][2] + 0.06)
    p["tor"] = (p["tor"][0], p["tor"][1] + 0.14 * hs, p["tor"][2])
    yaw = p["prt"][1] + p["tor"][1]
    hp = (p["pel"][0], p["pel"][1], 0.777 + p["pel"][2])
    # the bow rides the shoulders' turn and the weight, a beat behind
    hb = 0.35 * _beat(_at(u, 0.3), 0.38, 0.50, 0.78, 0.90)
    G = _turned(NOCKED["G"], NOCKED["prt"][1] + 0.08 + NOCKED["tor"][1] + 0.02 + 0.14 * hb, hp)
    p["G"] = (G[0] + SHIFT[0] * 0.6 * w["hand"], G[1] + SHIFT[1] * 0.6 * w["hand"], G[2] + 0.003 * br["hand"])
    p["BA"] = n3(Quaternion((0, 0, 1), 0.14 * hb) @ Vector(NOCKED["BA"]))
    p["BS"] = n3(Quaternion((0, 0, 1), 0.14 * hb) @ Vector(NOCKED["BS"]))
    p["RD"], p["RP"] = _nock_hand(p)
    p["dr"] = 0.06 * _beat(u, 0.56, 0.64, 0.70, 0.72)
    p["lid"] = 0.22 + _blink(u, 0.51) + _blink(u, 0.91)
    del p["w"], p["br"]
    return p


# ---- locomotion
def gait(k, heading):
    """k 0.45 walk .. 1 run. heading (deg, + left of facing). A straight, narrow line, tall in the chest, hips doing the
    work: she runs tall (kit: eyes up), the bow carried low and level in her left hand, the right arm pumping."""
    d = Vector(D(heading))
    stride = 0.15 + 0.29 * k
    lift = 0.045 + 0.17 * k
    share = 0.60 - 0.2 * k
    fwd, back = max(0.0, d.y), max(0.0, -d.y)

    def foot(ph, sx):
        ph %= 1.0
        base = Vector((sx * 0.078, 0, A_Z))
        if ph < share:
            s, z, pit = 1 - 2 * ph / share, 0.0, 0.0
        else:
            q = (ph - share) / (1 - share)
            s = -1 + 2 * q * q * (3 - 2 * q)
            z = lift * math.sin(q * math.pi) ** 0.8
            pit = -0.75 * math.sin(q * math.pi) * k
        return base + d * s * stride + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        rp, pr = foot(u, 1.0)
        lp, pl = foot(u + 0.5, -1.0)
        p["FR"], p["FL"], p["FRp"], p["FLp"] = tuple(rp), tuple(lp), pr, pl
        p["FRy"], p["FLy"] = -0.06 + math.radians(heading) * 0.5, 0.06 + math.radians(heading) * 0.5
        s2, c1, s1 = math.sin(u * 4 * math.pi + 0.5), math.cos(u * 2 * math.pi), math.sin(u * 2 * math.pi)
        p["pel"] = (0.016 * c1 * (1.3 - k), 0.012 * k * fwd - 0.03 * back, -0.024 - 0.038 * k + (0.012 + 0.018 * k) * s2)
        lean = (0.06 + 0.14 * k) * fwd - 0.08 * back
        p["prt"] = (lean * 0.6, 0.10 * c1, -0.05 * c1 * (1.2 - k) + 0.1 * k * d.x)
        p["tor"] = (lean * 0.55 + 0.01, -0.20 * c1 * (0.5 + k * 0.5) + 0.05, 0.03 * c1)
        p["hed"] = (-lean * 1.0 - 0.05, 0.14 * c1 * k - 0.04, -0.025 * c1)
        # the bow: at her hip when walking, level and trailing at a run
        w = min(1.0, (k - 0.45) / 0.55)
        sw = -0.05 * c1
        p["G"] = (-0.236 - 0.01 * w, 0.06 - 0.05 * w + sw * (1 - w * 0.5), 0.775 + 0.05 * w + 0.008 * s2)
        ba = (0.05, 0.60 + 0.34 * w, 0.80 - 0.60 * w)
        p["BA"] = n3(ba)
        p["BS"] = n3((0.0, -ba[2], ba[1]))
        # the right arm: swings when she walks, pumps bent at a run
        sw2 = 0.075 * c1 * (1 + k) / 1.45
        p["RF"] = (0.205 - 0.025 * w, 0.015 + 0.03 * w + sw2 * (1 + w), 0.885 + 0.075 * w + 0.02 * (w * c1))
        p["RD"] = n3((-0.15 - 0.2 * w, 0.2 + 0.55 * w, -0.97 + 0.5 * w))
        p["RP"] = n3((-1.0, 0.1, 0.1 + 0.3 * w))
        p["Rpole"] = (0.5, -1.0, -0.4)
        p["brow"], p["lid"], p["fing"] = 0.35, 0.1, 0.5
        return p
    return fn


def F(name, dur, fn):
    return FnClip(name, dur, fn, True)


# ---- the draw, on the draw's clock
def draw_t(t):
    """dr at draw time t: the nock at 0.05, then one steady line to full at 1.15."""
    return max(0.0, min(1.0, (t - 0.05) / 1.10)) ** 0.82


# ---- the crouch (item 143): a hunter's stillness. Low and level, the bow held out low in the left hand, the right drawn up by the quiver, the chin up, cold eyes on the far treeline.
STALK = dict(READY, **{
    "pel": (0.02, -0.05, -0.30), "prt": (0.36, 0.14, -0.05), "tor": (0.34, 0.06, 0.06), "hed": (-0.62, -0.08, -0.02),
    "G": (-0.27, 0.46, 0.60), "RF": (0.22, 0.30, 0.70),
    "FL": (-0.12, 0.24, A_Z + 0.03), "FR": (0.13, -0.24, A_Z + 0.06), "FLy": 0.34, "FRy": -0.46, "FLp": 0.25, "FRp": 0.55,
    "brow": 0.45, "lid": 0.14,
})
STILL = {"ankle": A_Z, "foot": 0.10, "width": 0.10, "stride": 0.31, "lift": 0.04, "toe": 0.24, "share": 0.62, "sway": 0.03, "bob": 0.012, "twist": 0.09, "T": 0.62, "toe_out": -0.24}


def crouch_set():
    return crouchkit.quick(C, READY, STALK, STILL, hands=("G", "RF"), scan=0.22)


def clips():
    out = [F("idle", STAND, idle), F("stance", STAND, stance)]
    out += crouch_set()
    wk, rn = 1.04, 0.66
    for n, h in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
        out.append(F("walk_" + n, wk, gait(0.45, h)))
        out.append(F("run_" + n, rn, gait(1.0, h)))
    # --- LMB: the draw. It nocks on the press and pulls along one line, so the pose matches the fill line beat for beat
    keys = [(0.0, dict(HIP)), (0.05, dict(NOCK), "out")]
    for t in (0.2, 0.35, 0.48, 0.6, 0.8, 1.0, 1.15):
        lean = draw_t(t)
        keys.append((t, {"dr": lean, "tor": (0.02 + 0.05 * lean, AIM_Y - 0.1 * lean, 0.02), "hed": (-0.03 + 0.02 * lean, -AIM_Y - 0.04 + 0.08 * lean, 0.05 + 0.05 * lean),
                         "brow": 0.75 + 0.25 * lean, "lid": 0.2 + 0.14 * lean}, "lin"))
    FULL = dict(NOCK, dr=1.0, tor=(0.07, AIM_Y - 0.1, 0.02), hed=(-0.01, -AIM_Y + 0.04, 0.10), brow=1.0, lid=0.34)
    keys.append((1.25, dict(FULL, G=(-0.052, 0.585, 1.302))))
    out.append(C("draw", 1.25, keys, base=READY))
    # the string let go: a clean flick back past her ear, the hand opening, no heave
    def loose(name, dur, frm, back=0.06, rec=0.25, kick=1.0):
        rel = dict(frm, Rw=0.0, ar=0.0, dr=0.0, RF=(0.015, 0.0, 1.46), RD=n3((-0.1, 0.7, 0.7)), RP=(-1.0, 0.0, 0.1), fing=0.05, pin=0.0,
                   tor=(0.02, AIM_Y - 0.14 * kick, 0.02), brow=0.65, lid=0.14)
        return C(name, dur, [(0.0, frm), (back, rel, "out"), (rec, dict(rel, G=(-0.052, 0.585, 1.29), RF=(0.04, -0.02, 1.43), lid=0.1)), (dur, dict(HIP))])
    MID = dict(NOCK, dr=draw_t(0.6), tor=(0.05, AIM_Y - 0.06, 0.02), brow=0.85, lid=0.26)
    QUICK = dict(NOCK, dr=0.32, tor=(0.03, AIM_Y, 0.02))
    OVER = dict(FULL, G=(-0.046, 0.575, 1.288), BA=n3((0.14, 0.02, 1.0)), brow=-0.2, lid=0.1)
    out.append(loose("tap", 0.36, QUICK, 0.04, 0.2, 0.5))
    out.append(loose("loose", 0.42, MID, 0.05, 0.22, 0.8))
    out.append(loose("perfect", 0.55, MID, 0.06, 0.3, 0.9))
    sup = dict(FULL, tor=(0.1, AIM_Y - 0.28, 0.0), RF=(0.05, -0.06, 1.47), RD=n3((-0.1, 0.6, 0.8)), RP=(-1.0, 0.0, 0.1), G=(-0.05, 0.60, 1.32), Rw=0.0, ar=0.0, dr=0.0, fing=0.05, pin=0.0, brow=0.9, lid=0.2)
    out.append(C("super", 0.6, [(0.0, FULL), (0.05, sup, "out"), (0.15, dict(sup, tor=(0.04, AIM_Y - 0.22, 0.0))), (0.3, dict(sup, tor=(0.02, AIM_Y - 0.15, 0.0), G=(-0.052, 0.585, 1.29))), (0.6, dict(HIP))]))
    # overdrawn: the arm starts to shake, the brows lift
    out.append(C("over", 0.56, [(0.0, FULL)] + [(0.08 * i, dict(OVER, dr=1.0, G=(-0.046 + 0.0035 * (-1) ** i, 0.575, 1.288 + 0.003 * (-1) ** (i // 2))), "lin") for i in range(1, 8)]))
    out.append(loose("over_loose", 0.55, OVER, 0.06, 0.3, 0.6))
    # --- RMB: Heavy Shot. Sunk low, weight back, the shoulders turned hard; a held creak; thrown back by the shot
    HW = dict(NOCK, ar=0.0, dr=1.0, tor=(0.2, AIM_Y - 0.32, -0.08), hed=(-0.16, -AIM_Y + 0.14, 0.12), G=(0.0, 0.60, 1.13), BA=n3((0.30, 0.05, 0.95)), BS=(0.0, -1.0, 0.0), CH=(0.02, 0.03, 1.15), brow=1.0, lid=0.42,
              pel=(0.0, -0.05, -0.10), prt=(0.05, -0.1, 0.0), FL=(-0.15, 0.24, A_Z), FR=(0.13, -0.22, A_Z), FLy=0.12, FRy=-0.7)
    out.append(C("heavy_wind", 1.2, [(0.0, dict(HIP)), (0.2, dict(HW, dr=0.2), "out"), (0.8, dict(HW, dr=0.85)), (1.1, HW), (1.2, dict(HW, G=(0.0, 0.598, 1.128)))]))
    hrel = dict(HW, Rw=0.0, ar=0.0, dr=0.0, RF=(0.14, -0.2, 1.32), RD=n3((0.3, -0.5, 0.8)), RP=(-0.8, 0.3, 0.1), fing=0.0, pin=0.0, tor=(-0.1, AIM_Y - 0.5, -0.14), hed=(0.08, -AIM_Y + 0.2, 0.16),
                pel=(0.0, -0.13, -0.08), G=(0.0, 0.56, 1.18), BA=n3((0.22, -0.32, 0.92)), brow=1.0, lid=0.1)
    out.append(C("heavy", 0.6, [(0.0, HW), (0.06, hrel, "out"), (0.28, dict(hrel, tor=(0.0, AIM_Y - 0.3, -0.08), pel=(0.0, -0.09, -0.12), G=(-0.02, 0.55, 1.14))), (0.6, READY)]))
    # --- E: Hail Wall. The bow high, the body arched back, the volley lobbed up in an arc
    H0 = dict(NOCK, dr=0.75, tor=(-0.32, AIM_Y + 0.1, 0.0), hed=(-0.3, -AIM_Y - 0.1, 0.0), G=(-0.09, 0.36, 1.70), BA=n3((0.1, -0.72, 0.68)), BS=n3((0.0, -0.68, -0.72)), RD=n3((0.0, 0.6, 0.8)), brow=0.7, lid=0.2, Lpole=(-0.9, 0.1, 0.2), Rpole=(0.5, -1.0, -0.4))
    H1 = dict(H0, Rw=0.0, ar=0.0, dr=0.0, RF=(0.05, 0.02, 1.52), RD=n3((-0.1, 0.5, 0.85)), RP=(-1.0, 0.0, 0.0), fing=0.05, pin=0.0, tor=(-0.36, AIM_Y, 0.0))
    out.append(C("hail", 0.6, [(0.0, dict(HIP)), (0.12, H0, "out"), (0.3, dict(H0, dr=1.0)), (0.36, H1, "out"), (0.42, H1), (0.6, dict(HIP))]))
    # --- Shift: the dodge roll, a low tuck through her left shoulder with the bow held out of the way, up onto her toes
    T = {"prt": (0.4, 0, 0), "tor": (0.5, 0, 0), "hed": (0.4, 0, 0), "pel": (0, 0.1, -0.28), "G": (-0.2, 0.12, 0.72), "BA": n3((0.0, 0.9, 0.4)), "BS": n3((0.0, -0.4, 0.9)), "RF": (0.2, 0.24, 0.72), "RD": n3((0, 0.3, -1)), "RP": (-1, 0, 0), "Rpole": (0.8, -0.5, 0.0)}
    out.append(C("roll", 0.36, [(0.0, dict(READY)), (0.07, dict(T, prt=(1.4, 0.0, 0.2), pel=(0, 0.2, -0.36), FL=(-0.12, 0.3, 0.3), FR=(0.12, 0.05, 0.28), FLp=1.0, FRp=1.0), "out"),
                                (0.17, dict(T, prt=(3.3, 0.0, 0.3), pel=(0, 0.26, -0.33), tor=(0.8, 0, 0), FL=(-0.12, 0.3, 0.6), FR=(0.12, 0.34, 0.66), FLp=2.0, FRp=2.0), "lin"),
                                (0.24, dict(T, prt=(5.2, 0.0, 0.1), pel=(0, 0.28, -0.3), FL=(-0.12, 0.3, 0.2), FR=(0.12, -0.05, 0.3), FLp=0.7, FRp=1.0), "lin"),
                                (0.36, dict(READY, prt=(6.283 + 0.08, 0.0, 0.0), pel=(0, 0.04, -0.09), brow=0.5, lid=0.1), "lin")]))
    # Spirit Walk: light on the toes, leaning in, the arms trailing like a ghost (upper body, the legs keep running)
    SW = {"tor": (0.26, 0.0, 0.0), "hed": (-0.24, 0.0, 0.0), "G": (-0.28, -0.20, 0.92), "BA": n3((0.05, 0.86, 0.5)), "BS": n3((0.0, -0.5, 0.86)), "RF": (0.28, -0.22, 0.92), "RD": n3((0.3, -0.75, -0.55)), "RP": (-0.7, -0.6, 0.3), "Rpole": (0.6, 0.2, -0.8), "Lpole": (-0.6, 0.2, -0.8), "brow": -0.3, "lid": 0.3, "fing": 0.1}
    out.append(C("spirit", 1.0, [(0.0, dict(HIP)), (0.2, SW), (0.6, dict(SW, tor=(0.3, 0.05, 0.03), G=(-0.28, -0.22, 0.90), RF=(0.28, -0.25, 0.95))), (1.0, SW)]))
    # the air dash: a quick flick and a sideways tumble, the coat and tail streaming
    out.append(C("flick", 0.42, [(0.0, dict(READY)), (0.05, dict(T, prt=(0.35, 0, 1.6), pel=(0, 0, 0.02), FL=(-0.14, 0.2, 0.3), FR=(0.14, 0.05, 0.3), FLp=1, FRp=1), "out"),
                                 (0.18, dict(T, prt=(0.15, 0, 6.28), pel=(0, 0, 0.04), FL=(-0.1, -0.1, 0.25), FR=(0.1, -0.2, 0.3), FLp=1, FRp=1), "lin"), (0.42, dict(READY, prt=(0, -0.06, 6.283 - 0.04), pel=(0.02, 0, 0.0)))]))
    # Deadeye: the bow thrust out at the target, the body locked low and still, a slow rise
    DE = dict(HW, CH=(-0.012, 0.14, 1.412), Rw=0.0, ar=0.0, dr=0.0, pel=(0, 0.04, -0.12), tor=(0.14, AIM_Y, 0.0), hed=(-0.1, -AIM_Y, 0.0), G=(-0.05, 0.62, 1.2), BA=n3((0.06, 0.0, 1.0)), RF=(0.06, 0.05, 1.2), RD=n3((0, 0.9, 0.2)), RP=(-1, 0, 0), brow=1.0, lid=0.42)
    out.append(C("deadeye", 0.75, [(0.0, dict(READY)), (0.05, DE, "out"), (0.4, DE), (0.75, READY)]))
    # --- R: Starpiercer. The bow swept up and across the chest, three beams, the last one thrown
    CAST = dict(HIP, tor=(-0.25, 0.25, 0.0), hed=(-0.3, -0.2, 0.0), G=(0.05, 0.3, 1.5), BA=n3((0.96, 0.1, 0.28)), BS=n3((-0.28, 0.0, 0.96)), RF=(0.3, 0.1, 1.25), RD=n3((1, 0.1, 0.2)), RP=(0, 1, 0), brow=0.6, lid=0.0, Lpole=(-0.8, -0.3, -0.3))
    out.append(C("ult_cast", 0.45, [(0.0, dict(HIP)), (0.1, CAST, "out"), (0.25, dict(CAST, tor=(-0.32, 0.25, 0.0))), (0.45, dict(NOCK))]))
    UN = dict(NOCK, dr=1.0, hed=(-0.01, -AIM_Y, 0.08), brow=1.0, lid=0.3)
    out.append(C("ult_nock", 0.55, [(0.0, dict(NOCK)), (0.1, dict(UN, dr=0.7), "out"), (0.3, UN), (0.55, dict(UN, G=(-0.052, 0.585, 1.303)))]))
    urel = dict(UN, Rw=0.0, ar=0.0, dr=0.0, RF=(0.015, 0.0, 1.46), RD=n3((-0.1, 0.7, 0.7)), fing=0.05, pin=0.0, tor=(0.02, AIM_Y - 0.2, 0.02))
    out.append(C("ult_loose", 0.5, [(0.0, UN), (0.1, urel, "out"), (0.3, dict(urel, tor=(0.02, AIM_Y - 0.12, 0.02))), (0.5, dict(NOCK))]))
    ufin = dict(urel, tor=(-0.12, AIM_Y - 0.5, -0.1), RF=(0.17, -0.22, 1.36), G=(-0.05, 0.57, 1.36), BA=n3((0.1, -0.2, 0.96)))
    out.append(C("ult_final", 0.65, [(0.0, UN), (0.1, ufin, "out"), (0.25, dict(ufin, tor=(-0.08, AIM_Y - 0.4, -0.06))), (0.65, dict(HIP))]))
    # --- reactions
    out.append(C("hit_f", 0.42, [(0.0, dict(READY)), (0.07, {"tor": (-0.22, 0.14, 0.1), "hed": (-0.3, -0.25, 0.14), "G": (-0.27, 0.05, 0.84), "RF": (0.24, 0.04, 1.02), "brow": -0.7, "lid": 0.45}, "out"), (0.42, dict(READY))]))
    out.append(C("hit_b", 0.42, [(0.0, dict(READY)), (0.07, {"tor": (0.26, -0.05, -0.08), "hed": (0.18, 0.2, -0.1), "G": (-0.24, 0.2, 0.83), "RF": (0.24, 0.1, 1.02), "brow": -0.7, "lid": 0.45}, "out"), (0.42, dict(READY))]))
    STUN = {"pel": (0, -0.02, -0.08), "prt": (0.05, 0, 0.05), "tor": (0.32, 0.1, 0.1), "hed": (0.35, 0.2, 0.2), "G": (-0.235, 0.12, 0.60), "BA": n3((0.0, 0.78, 0.62)), "BS": n3((0.0, -0.62, 0.78)), "RF": (0.2, 0.1, 0.8), "RD": (0, 0.1, -1), "RP": (-1, 0, 0), "Rpole": (0.8, -0.5, 0), "brow": -0.8, "lid": 0.55, "fing": 0.1}
    out.append(C("stun", 1.2, [(0.0, STUN), (0.6, dict(STUN, tor=(0.3, -0.1, -0.06), hed=(0.3, -0.2, -0.16), pel=(0, -0.02, -0.09))), (1.2, STUN)], True))
    DN = {"pel": (0.0, -0.1, -0.44), "prt": (0.45, 0.0, -0.1), "tor": (0.3, 0.1, 0.08), "hed": (-0.3, -0.08, 0.05), "FL": (-0.17, 0.18, A_Z), "FR": (0.14, -0.34, 0.12), "FRp": 1.15, "FLy": 0.2, "FRy": -0.1,
          "G": (-0.27, 0.32, 0.45), "BA": n3((0.05, 0.1, 1.0)), "BS": n3((0.0, -1.0, 0.1)), "RF": (0.17, 0.05, 0.5), "RD": n3((0, 0.2, -1)), "RP": (-1, 0, 0), "Rpole": (0.6, -0.6, -0.2), "Lpole": (-1, -0.2, -0.2), "brow": -0.6, "lid": 0.5, "fing": 0.3}
    out.append(C("downed", 2.4, [(0.0, DN), (1.2, dict(DN, tor=(0.34, 0.1, 0.08), pel=(0.0, -0.1, -0.455), hed=(-0.26, -0.12, 0.05))), (2.4, DN)], True))
    out.append(C("revive", 1.3, [(0.0, DN), (0.5, dict(DN, tor=(0.1, 0.1, 0.05), hed=(-0.15, 0, 0), pel=(0, -0.08, -0.34))), (1.0, {"pel": (0, -0.02, -0.11), "prt": (0.15, 0, 0), "tor": (0.2, 0.1, 0.05), "FR": (0.1, -0.1, A_Z), "FRp": 0.3, "G": (-0.25, 0.15, 0.72), "BA": READY["BA"], "BS": READY["BS"], "brow": 0.3, "lid": 0.15}), (1.3, dict(READY))]))
    DD = {"pel": (0.06, -0.12, -0.70), "prt": (1.45, 0.3, 0.35), "tor": (0.1, 0.2, 0.25), "hed": (0.15, 0.6, 0.15), "FL": (-0.1, -0.5, 0.12), "FR": (0.22, -0.56, 0.1), "FLp": 1.4, "FRp": 1.4,
          "G": (-0.42, 0.42, 0.1), "BA": n3((0.05, 0.98, 0.12)), "BS": n3((0.0, -0.12, 0.98)), "RF": (0.3, 0.48, 0.1), "RD": n3((0.2, 0.9, -0.1)), "RP": (0, 0, -1), "Rpole": (0.9, 0, 0.3), "Lpole": (-0.9, 0, 0.3), "brow": -0.5, "lid": 1.0, "fing": 0.1}
    out.append(C("death", 1.5, [(0.0, dict(READY)), (0.16, {"tor": (-0.3, 0, 0), "hed": (-0.5, 0, 0), "lid": 0.2, "brow": -1.0, "RF": (0.2, 0.1, 1.0)}, "out"),
                                (0.6, dict(DN, pel=(0, -0.05, -0.4), lid=0.7)), (1.1, DD), (1.25, dict(DD, pel=(0.06, -0.12, -0.675))), (1.5, DD)]))
    # --- air
    JP = {"pel": (0, 0, 0.0), "prt": (-0.08, 0, 0), "tor": (-0.1, 0.1, 0), "hed": (-0.14, 0, 0), "FL": (-0.1, 0.12, 0.3), "FR": (0.1, -0.08, 0.16), "FLp": -0.4, "FRp": -0.6, "G": (-0.28, 0.0, 0.92), "BA": n3((0.08, 0.9, 0.4)), "BS": n3((0.0, -0.4, 0.9)),
          "RF": (0.3, 0.05, 1.0), "RD": n3((0.5, 0.3, -0.8)), "RP": (-0.9, 0, -0.4), "Rpole": (1.0, -0.4, 0), "brow": 0.4}
    FA = dict(JP, tor=(0.14, 0.05, 0.0), hed=(-0.3, 0, 0), FL=(-0.12, 0.08, 0.2), FR=(0.1, -0.12, 0.3), FLp=0.3, FRp=0.2, G=(-0.3, 0.02, 1.02), RF=(0.33, 0.08, 1.12))
    GL = dict(JP, prt=(0.72, 0, 0), tor=(0.12, 0, 0), hed=(-0.62, 0, 0), pel=(0, 0, 0.0), FL=(-0.1, -0.26, 0.24), FR=(0.1, -0.32, 0.3), FLp=0.8, FRp=0.9, G=(-0.34, 0.30, 0.98), RF=(0.34, 0.28, 0.98), RD=n3((0.2, 0.8, 0.1)))
    DV = dict(GL, prt=(1.25, 0, 0), hed=(-1.0, 0, 0), FL=(-0.08, -0.5, 0.4), FR=(0.08, -0.54, 0.46), FLp=1.3, FRp=1.3, G=(-0.22, 0.22, 0.7), RF=(0.2, 0.2, 0.7))
    out.append(C("jump", 0.8, [(0.0, JP), (0.4, dict(JP, tor=(-0.06, 0.1, 0))), (0.8, JP)], True))
    out.append(C("fall", 0.8, [(0.0, FA), (0.4, dict(FA, G=(-0.31, 0.02, 1.04), RF=(0.34, 0.08, 1.14))), (0.8, FA)], True))
    out.append(C("glide", 1.2, [(0.0, GL), (0.6, dict(GL, tor=(0.15, 0.04, 0.05))), (1.2, GL)], True))
    out.append(C("dive", 0.8, [(0.0, DV), (0.4, dict(DV, FL=(-0.09, -0.5, 0.42))), (0.8, DV)], True))
    out.append(C("land", 0.4, [(0.0, dict(READY, pel=(0.0, 0.0, 0.0), FL=(-0.13, 0.1, A_Z + 0.01))), (0.08, dict(READY, pel=(0.0, 0.03, -0.17), prt=(0.28, 0, 0), tor=(0.26, 0.1, 0), G=(-0.28, 0.2, 0.6), RF=(0.24, 0.16, 0.74), RD=n3((0, 0.2, -1)), RP=(-1, 0, 0)), "out"), (0.4, dict(READY))]))
    # the Fusion transform: curled in on the bow, then thrown open
    FU0 = {"pel": (0, -0.03, -0.24), "prt": (0.42, 0, 0), "tor": (0.5, 0, 0), "hed": (0.45, 0, 0), "G": (-0.12, 0.26, 0.86), "BA": n3((0.5, 0.1, 0.86)), "BS": n3((-0.1, -1.0, 0.1)), "RF": (0.1, 0.24, 0.92), "RD": n3((-0.5, 0.2, -0.8)), "RP": (-0.8, -0.1, 0.5), "lid": 0.9, "brow": 0.9, "fing": 1.0}
    FU1 = {"pel": (0, 0, 0.02), "prt": (-0.14, 0, 0), "tor": (-0.3, 0, 0), "hed": (-0.42, 0, 0), "G": (-0.52, 0.1, 1.34), "BA": n3((0.0, 0.3, 0.95)), "BS": n3((0.9, -0.3, 0.0)), "RF": (0.5, 0.08, 1.4), "RD": n3((0.7, 0.1, 0.7)), "RP": (0.3, 0, -0.9), "Rpole": (1, -0.4, -0.2), "Lpole": (-1, -0.4, -0.2), "lid": 0.0, "fing": 0.0, "brow": 0.2}
    out.append(C("fusion", 0.8, [(0.0, dict(READY)), (0.18, FU0), (0.3, dict(FU0, pel=(0.006, -0.03, -0.26))), (0.45, FU1, "out"), (0.58, dict(FU1, pel=(0, 0, 0.0))), (0.8, dict(READY))]))
    # the emote: one claw taps the painted smile, then a slow, mocking curtsey with the bow held out
    TAP = {"hed": (-0.06, 0.05, -0.08), "tor": (0.0, 0.1, 0.03), "RF": (0.095, 0.15, 1.42), "RD": n3((-0.5, 0.45, 0.72)), "RP": (-0.5, -0.8, 0.2), "Rpole": (0.9, -0.3, -0.5), "fing": 0.55, "brow": 0.8, "lid": 0.2}
    CURT = {"pel": (0.0, -0.05, -0.20), "prt": (0.32, 0.0, 0.0), "tor": (0.36, 0.0, 0.0), "hed": (-0.42, 0.0, 0.0), "FL": (-0.08, 0.1, A_Z), "FR": (0.09, -0.26, A_Z + 0.03), "FRp": 0.5, "FRy": -0.1, "G": (-0.5, 0.24, 0.84), "BA": n3((-0.3, 0.2, 0.93)), "BS": n3((0.9, -0.3, 0.2)), "Lpole": (-0.8, -0.4, -0.4),
            "RF": (0.34, 0.1, 0.92), "RD": n3((0.8, 0.2, -0.5)), "RP": (0.2, 0.8, 0.4), "Rpole": (1, -0.5, -0.2), "fing": 0.2, "brow": 0.3, "lid": 0.5}
    out.append(C("emote", 3.0, [(0.0, dict(READY)), (0.5, TAP), (0.7, dict(TAP, RF=(0.09, 0.16, 1.44))), (0.85, TAP), (1.0, dict(TAP, RF=(0.09, 0.16, 1.44))), (1.15, TAP), (1.8, CURT), (2.4, dict(CURT, pel=(0.0, -0.05, -0.22))), (3.0, dict(READY))]))
    return out


def extras_for(sol):
    """Keys that aren't arm or leg IK: fingers, lids, brows, the bow's limbs, its string's nock, the arrow."""
    pbs = sol.arm.pose.bones
    R0, H0 = sol.R0, sol.H0
    MX, MY, MZ = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    def loc(b, q):
        return R0[b].inverted() @ q @ R0[b]

    def fn(P):
        out = {}
        f = P["fing"]
        pin = P["pin"]
        # the index and thumb hook the string; the rest fold in
        out["fing_a1.R"] = (loc("fing_a1.R", Quaternion(MY, 0.55 * pin + 0.9 * f * (1 - pin))), None)
        out["fing_a2.R"] = (loc("fing_a2.R", Quaternion(MY, 0.9 * pin + 0.9 * f * (1 - pin))), None)
        out["fing_b1.R"] = (loc("fing_b1.R", Quaternion(MY, 0.2 + 1.0 * f)), None)
        out["fing_b2.R"] = (loc("fing_b2.R", Quaternion(MY, 0.3 + 1.2 * f)), None)
        tk = max(f, pin)
        out["thumb1.R"] = (loc("thumb1.R", Quaternion(MY, 0.55 * tk) @ Quaternion(MX, -0.55 * tk)), None)
        out["thumb2.R"] = (loc("thumb2.R", Quaternion(MY, 0.7 * tk)), None)
        b, l = P["brow"], P["lid"]
        for s, side in ((1.0, "R"), (-1.0, "L")):
            out["brow." + side] = (loc("brow." + side, Quaternion(MY, s * 0.22 * b)), R0["brow." + side].inverted() @ Vector((0, 0, -0.0034 * b)))
            out["lid." + side] = (loc("lid." + side, Quaternion(MX, -0.92 * l)), None)
        dr = P["dr"]
        ben = 0.15 * dr
        out["bow_t"] = (loc("bow_t", Quaternion(MX, ben if GS[1] < 0 else -ben)), None)
        out["bow_b"] = (loc("bow_b", Quaternion(MX, -ben if GS[1] < 0 else ben)), None)
        L = sol.last
        # the nock, in the bow's rest
        rest = L["q_bow"].inverted() @ (L["N"] - L["pbow"]) + H0["bow"]
        out["bow_s"] = (None, R0["bow_s"].inverted() @ (rest - H0["bow_s"]))
        if P["ar"] > 0.5:
            Q = L["Q"]
            d = (L["G"] + (L["q_bow"] @ Vector((0, 0, 0.012))) - L["N"]).normalized()
            y0 = sol.Y0["arrow"]
            q_w = y0.rotation_difference(d)
            q = R0["arrow"].inverted() @ Q["hips"].inverted() @ q_w @ R0["arrow"]
            p = Q["hips"].inverted() @ (L["N"] - L["hp"]) + H0["hips"] - H0["arrow"]
            out["arrow"] = (q.normalized(), R0["arrow"].inverted() @ p)
        else:
            out["arrow"] = (Quaternion(), Vector())
        br = P.get("breath", 0.0)
        out["x_breath"] = (None, None, Vector((1.0 + BREATH_OUT * br, 1.0 + br, 1.0 + BREATH_OUT * br)))
        return out
    return fn


def bake(arm, clip, sol, extras):
    act = bpy.data.actions.new(clip.name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    n = max(2, int(round(clip.dur * FPS)) + 1)
    pbs = arm.pose.bones
    names = ["root", "hips", "head", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R", "pauldron.L", "pauldron.R"]
    for b in pbs:
        b.rotation_mode = "QUATERNION"
    for f in range(n):
        t = clip.dur * f / (n - 1)
        P = clip.sample(t)
        Q, root_at = sol.solve(P)
        for b in names:
            par = sol.b[b].parent.name if sol.b[b].parent else None
            dq = Q[par] if par else Quaternion()
            pb = pbs[b]
            pb.rotation_quaternion = (sol.R0[b].inverted() @ dq.inverted() @ Q[b] @ sol.R0[b]).normalized()
            pb.keyframe_insert("rotation_quaternion", frame=f)
        pbs["root"].location = sol.R0["root"].inverted() @ (root_at - sol.H0["root"])
        pbs["root"].keyframe_insert("location", frame=f)
        for b, (q, l, *sc) in extras(P).items():
            pb = pbs[b]
            if q is not None:
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
            if l is not None:
                pb.location = l
                pb.keyframe_insert("location", frame=f)
            if sc:
                pb.scale = sc[0]
                pb.keyframe_insert("scale", frame=f)
    arm.animation_data.action = None
    return act


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    for old in list(bpy.data.actions):     # a re-bake may start from the last *_anim.blend
        bpy.data.actions.remove(old)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    add_breath(arm, bpy.data.objects["hem"], BREATH_C, BREATH_R)
    sol = HemSolver(arm, bpy.context.scene["pinch"])
    bpy.context.scene.render.fps = FPS       # (the exporter times keys by the scene: at its default 24 fps every clip ran 25% long)
    bpy.context.view_layer.objects.active = arm
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    ex = extras_for(sol)
    done = []
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        bake(arm, c, sol, ex)
        done.append((c.name, round(c.dur, 3)))
    print("clips", len(done), done)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(a[1])[0] + "_anim.blend")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))

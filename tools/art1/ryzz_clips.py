"""ART-1 Sparkle's animation set (hand-keyed as targets, solved by posekit). Times match the kit: MOVES in scripts/match/kmoves_vv.gd and content/archetypes/mage.json.
Personality: cocky, light, all hip and wrist; hands-free: every attack is a finger gun with both thumbs up, she blows the smoke off after the good ones.
Hands: G and LP are the wrists; BE/LBE are (index finger direction, thumb direction).
Run: blender -b --python tools/art1/ryzz_clips.py -- <ryzz.blend> <out.glb> [clip,clip]"""
import sys, os, math, json
import bpy
import numpy as np
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, bake, add_breath, ang_dir as D, at, eul, lerp, FPS, frame_of, BREATH_AXES
import ryzz_pieces as K
import crouchkit

UP = (0, 0, 1)
A_Z = K.ANKLE_Z
SZ, HZ = K.SHOULDER_Z, K.HAND_Z


def aim(a, e=0.0, thumb=UP):
    """The index finger toward ang_dir(a, e), the thumb up."""
    return (D(a, e), thumb)


HANG_R, HANG_L = ((0, 0, -1), (0, 1, 0)), ((0, 0, -1), (0, 1, 0))
READY = {
    "pel": (0.022, 0.0, -0.022), "prt": (0.03, -0.1, -0.05), "tor": (0.0, 0.14, 0.05), "hed": (0.02, -0.08, 0.09),
    "G": (0.215, 0.05, 1.0), "BE": ((0.1, 0.25, -1), (0.1, 1, 0.1)), "LP": (-0.235, 0.055, 0.985), "LBE": ((-0.1, 0.25, -1), (-0.1, 1, 0.1)),
    "FL": (-0.085, 0.09, A_Z), "FR": (0.115, -0.06, A_Z), "FLy": 0.14, "FRy": -0.34, "FLp": 0.0, "FRp": 0.0,
    "brow": 0.15, "lidR": 0.12, "lidL": 0.12, "smile": 0.7, "gunR": 0.0, "gunL": 0.0, "skirt": 0.0, "gum": 0.72, "fan": 0.0, "lit": 0.0,
}
GUN = {"gunR": 1.0, "gunL": 1.0}
BOTH_UP = {"G": (0.27, 0.2, 1.3), "BE": aim(-14, 26), "LP": (-0.27, 0.2, 1.3), "LBE": aim(14, 26), "gunR": 1.0, "gunL": 1.0}


def qz(p):
    """The off hand's frame as a quaternion, so posekit's lerp can carry it (it only knows "BE")."""
    if "LBE" not in p or len(p["LBE"]) != 2:
        return p
    q = frame_of(*p["LBE"])
    if q.w < 0:
        q = -q
    return dict(p, LBE=tuple(q))


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, [(k[0], qz(k[1])) + tuple(k[2:]) for k in keys], qz(base), loop)


IDLE_T, STANCE_T = 5.0, 6.0            # s: the standing loops; every curve below runs whole cycles of them, so the seams close (--clip-check)
BEAT = 1.0                             # s: her inner beat; the toe bounce and the gum pop sit on it
BREATH = 0.025                         # x_breath swell (2.5 %) at a full breath
LAG = {"tor": 0.10, "hed": 0.17, "hand": 0.20, "rack": 0.10}      # s: the chest, head, hands and rod rack answer the pelvis this much later
IDLE_SHIFTS = ((0.40, 0.54), (0.80, 0.94))                        # u: the weight goes to the left foot, then back to the right


def ss(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def shift(x):
    """A weight shift 0..1 over x: a small anticipation back, the move, an overshoot that settles; flat at both ends."""
    x = max(0.0, min(1.0, x))
    return ss(x) - 0.25 * math.sin(2 * math.pi * x) * math.sin(math.pi * x) ** 2 * x


def weight(u, windows=IDLE_SHIFTS):
    """0: the weight on the right foot, 1: on the left. A hold, a shift over each window, a hold; closed at the seam."""
    u %= 1.0
    (a0, a1), (b0, b1) = windows
    return shift((u - a0) / (a1 - a0)) - shift((u - b0) / (b1 - b0))


def dip(u, windows=IDLE_SHIFTS):
    """The knees soften through a shift: 0..1, peaking mid-move."""
    u %= 1.0
    return max(math.sin(math.pi * (u - a) / (b - a)) ** 2 if a <= u <= b else 0.0 for a, b in windows)


def bounce(u, dur, skip=()):
    """The toe bounce on the beat: a hop in the first 60 % of a beat, a rest after it; nothing on the skipped beats."""
    t = (u % 1.0) * dur
    i, b = int(t // BEAT), (t % BEAT) / BEAT
    return 0.0 if i in skip or b > 0.6 else math.sin(math.pi * b / 0.6) ** 2


def breath(u, dur, period):
    """0..1, in on the first half; dur is a whole number of periods."""
    return 0.5 - 0.5 * math.cos(2 * math.pi * (u % 1.0) * dur / period)


def blink(u, at, w=0.025):
    """The lids: 0.12 open, shut and open again over a window w wide round each u in at."""
    k = max((1 - abs(u - a) / w for a in at if abs(u - a) < w), default=0.0)
    return 0.12 + 0.88 * k


def mix(p, q, k):
    """p toward the keys of q by k (BE/LBE: both frame vectors)."""
    for n, b in q.items():
        a = p[n]
        p[n] = (lerp(a[0], b[0], k), lerp(a[1], b[1], k)) if n in ("BE", "LBE") else lerp(a, b, k)


def stand(u, dur, s, s_tor, s_hed, s_hand, knee, bo, br):
    """The standing body: the weight s (0 right .. 1 left) on the pelvis, the chest, head and hands on their own lagged copies,
    the knees softened by knee, the toe bounce bo (heels up, the body with them), the breath br in the chest, head and hands."""
    p = dict(READY)
    p["pel"] = (0.022 - 0.044 * s, 0.0, -0.022 - 0.014 * knee + 0.012 * bo)
    p["prt"] = (0.03, -0.1 + 0.2 * s, -0.07 + 0.14 * s)
    p["tor"] = (-0.012 * br, 0.14 - 0.28 * s_tor, 0.05 - 0.1 * s_tor)
    p["hed"] = (0.02 - 0.015 * br, -0.08 + 0.16 * s_hed, 0.09 - 0.18 * s_hed)
    p["G"] = (0.215 - 0.03 * s_hand, 0.05 + 0.03 * (s_hand - s), 1.0 + 0.004 * br)
    p["LP"] = (-0.235 - 0.03 * s_hand, 0.055 + 0.03 * (s_hand - s), 0.985 + 0.004 * br)
    p["FL"], p["FR"] = (-0.085, 0.09, A_Z + 0.016 * bo), (0.115, -0.06, A_Z + 0.016 * bo)
    p["FLp"] = p["FRp"] = 0.18 * bo
    p["breath"] = br
    return p


def snap(p, u, t0, t1):
    """The right hand comes up by the shoulder, the fingers snap (the hand closes to the gun on the beat) and the rods spark, the hand drops."""
    if not t0 < u < t1:
        return
    x = (u - t0) / (t1 - t0)
    lift = ss(x / 0.3) * (1 - ss((x - 0.6) / 0.4))
    mix(p, {"G": (0.26, 0.2, 1.27), "BE": aim(-20, 55), "tor": (p["tor"][0], p["tor"][1] - 0.06, p["tor"][2]), "brow": 0.6}, lift)
    p["gunR"] = ss((x - 0.44) / 0.03) * (1 - ss((x - 0.6) / 0.4))
    p["lit"] = 0.4 * math.sin(math.pi * ss((x - 0.44) / 0.14)) ** 2


def bubble(p, u, t0, t_pop, t1):
    """She blows a bubble from t0; it pops at t_pop (the gum snaps to a scrap, both eyes shut); it is back in her cheek by t1."""
    if t0 <= u < t_pop:
        x = (u - t0) / (t_pop - t0)
        p["gum"] = 0.72 + 0.6 * x ** 1.5
        p["smile"], p["brow"] = 0.7 - 0.5 * ss(x * 3), 0.15 + 0.15 * x
        p["lidL"] = p["lidR"] = 0.12 + 0.2 * ss(x * 3)
        p["hed"] = (p["hed"][0] - 0.05 * ss(x * 3), p["hed"][1], p["hed"][2])
    elif t_pop <= u < t1:
        x = (u - t_pop) / (t1 - t_pop)
        p["gum"] = 0.05 + 0.67 * ss((x - 0.3) / 0.7)
        p["lidL"] = p["lidR"] = max(p["lidL"], 0.8 * (1 - ss(x / 0.25)))
        p["smile"] = 1.0 - 0.3 * ss(x)


def idle(u):
    """Never quite still: a cocked hip, the weight shifted left and back once per loop (pelvis first, chest, head and hands after),
    a toe bounce to an inner beat with a hold, the rod rack rattling after each shift; once per loop a finger snap with a spark and a bubble that pops."""
    T, skip = IDLE_T, (2, 4)
    s_tor, s_hed, s_hand = (weight(u - LAG[k] / T) for k in ("tor", "hed", "hand"))
    p = stand(u, T, weight(u), s_tor, s_hed, s_hand, dip(u), bounce(u, T, skip), breath(u, T, 2.5))
    p["fan"] = 0.5 * abs(weight(u - LAG["rack"] / T) - weight(u - 2 * LAG["rack"] / T))
    p["skirt"] = 0.15 * bounce(u - 0.07 / T, T, skip)
    p["lidL"] = p["lidR"] = blink(u, (0.12, 0.48))
    snap(p, u, 0.20, 0.34)
    bubble(p, u, 0.56, 0.74, 0.84)
    return p


GUNS = dict(BOTH_UP, tor=(-0.03, 0.14, 0.05), smile=1.0, brow=0.4)
LEAN = {"pel": (0.045, -0.01, -0.04), "prt": (0.02, -0.12, -0.11), "tor": (-0.03, 0.18, 0.1), "hed": (0.03, -0.1, 0.16),
        "G": (0.2, 0.0, 0.93), "BE": ((-0.2, 0.8, -0.55), (-0.1, -0.6, -0.8)), "LP": (-0.25, 0.03, 0.98), "smile": 0.9, "brow": 0.2}


def stance(u):
    """Her signature, once per loop: both finger guns come up and double-tap at nobody, a head tilt and a wink, then she drops them and
    leans back into her right hip with a hand on it; the bubble grows and pops on the 4th beat. The idle's feet; the weight stays right.
    Both loops run free under the 0.5 s cross-fade, so the body stays near the idle's the whole way: same feet, hands low outside the guns."""
    T, skip = STANCE_T, (0, 2, 4)
    lean = lambda v: ss((v % 1.0 - 0.30) / 0.12) * (1 - ss((v % 1.0 - 0.86) / 0.10))
    guns = ss(u / 0.08) * (1 - ss((u - 0.30) / 0.12))
    l = lean(u)
    p = stand(u, T, 0.0, 0.0, 0.0, 0.0, 0.0, bounce(u, T, skip) * (1 - 0.4 * l), breath(u, T, 3.0))
    mix(p, GUNS, guns)
    tap = max((1 - ss((u - t) / 0.05)) if t <= u < t + 0.05 else 0.0 for t in (0.14, 0.20))
    mix(p, {"BE": aim(-14, 48), "LBE": aim(14, 48)}, tap)
    p["tor"] = (p["tor"][0] - 0.03 * tap, p["tor"][1], p["tor"][2])
    tilt = 0.16 * ss((u - 0.10) / 0.06) * (1 - ss((u - 0.30) / 0.12))
    p["hed"] = (p["hed"][0], p["hed"][1], p["hed"][2] + tilt)
    mix(p, LEAN, l)
    p["fan"] = 0.4 * abs(lean(u - LAG["rack"] / T) - lean(u - 2 * LAG["rack"] / T))
    p["skirt"] = 0.15 * bounce(u - 0.07 / T, T, skip)
    p["lidL"] = p["lidR"] = blink(u, (0.08, 0.86))
    p["lidR"] = max(p["lidR"], ss((u - 0.19) / 0.02) * (1 - ss((u - 0.29) / 0.03)))
    bubble(p, u, 0.50, 4.0 / T, 0.80)
    return p


def gait(k, heading):
    """k 0.45 walk .. 1 run. A runner's light step on heels, hips swinging, arms loose; at a run the fingers trail, the head is steady."""
    d = Vector((-math.sin(math.radians(heading)), math.cos(math.radians(heading)), 0))
    stride, lift = 0.15 + 0.3 * k, 0.05 + 0.2 * k
    share = 0.62 - 0.22 * k
    fwd, back = max(0.0, d.y), max(0.0, -d.y)

    def foot(ph, sx):
        ph %= 1.0
        base = Vector((sx * (0.085 - 0.04 * (1 - k) * fwd), 0, A_Z))      # a narrow, one-foot-before-the-other walk
        if ph < share:
            s, z, pit = 1 - 2 * ph / share, 0.0, 0.0
        else:
            q = (ph - share) / (1 - share)
            s = -1 + 2 * q * q * (3 - 2 * q)
            z = lift * math.sin(q * math.pi) ** 0.8
            pit = -0.8 * math.sin(q * math.pi) * k
        return base + d * s * stride + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        rp, pr = foot(u, 1.0)
        lp, pl = foot(u + 0.5, -1.0)
        p["FR"], p["FL"], p["FRp"], p["FLp"] = tuple(rp), tuple(lp), pr, pl
        h = math.radians(heading) * 0.45
        p["FRy"], p["FLy"] = -0.08 + h, 0.08 + h
        s2, c1 = math.sin(u * 4 * math.pi + 0.5), math.cos(u * 2 * math.pi)
        s1 = math.sin(u * 2 * math.pi)                        # + mid-stance on the right foot, - on the left
        lean = (0.08 + 0.26 * k) * fwd - 0.1 * back
        sway = 1.0 - 0.55 * k                                 # the swagger is the walk's; a run tucks it in
        p["pel"] = (0.042 * s1 * sway, 0.02 * k * fwd, -0.03 - 0.03 * k + (0.02 + 0.02 * k) * s2)
        p["prt"] = (lean * 0.5, 0.2 * c1 * k + 0.16 * c1 * sway, -0.15 * s1 * sway)      # the stance hip rides up
        p["tor"] = (lean * 0.7, -0.34 * c1 * k - 0.2 * c1 * sway, 0.1 * s1 * sway)        # the shoulders answer it
        p["hed"] = (-lean * 1.05, 0.14 * c1 * k + 0.1 * c1 * sway, -0.05 * s1 * sway + 0.05)
        amp = 0.12 + 0.22 * k
        p["G"] = (0.21, 0.04 - amp * c1, 1.02 + 0.08 * k + 0.05 * k * max(0, c1))
        p["LP"] = (-0.21, 0.04 + amp * c1, 1.02 + 0.08 * k + 0.05 * k * max(0, -c1))
        p["BE"] = ((0.15, 0.3 - 0.8 * c1 * k, -1), (0, 1, 0.3))
        p["LBE"] = ((-0.15, 0.3 + 0.8 * c1 * k, -1), (0, 1, 0.3))
        p["skirt"] = 0.3 * c1 * k
        p["lidR"], p["lidL"] = 0.12, 0.12
        p["smile"] = 0.8
        return p
    return fn


END = {k: READY[k] for k in ("pel", "prt", "tor", "hed", "G", "BE", "LP", "LBE", "FL", "FR", "FLy", "FRy", "FLp", "FRp", "brow", "lidR", "lidL", "smile", "gunR", "gunL", "skirt", "gum", "fan", "lit")}
OPEN = {"lidR": 0.12, "lidL": 0.12}                # the wink opens to aim


def shot(name, right):
    """A finger bolt on the kit's beats (0.03 pull, 0.06 release, 0.09 recoil, settled 0.35). Upper body only: her legs keep walking. Recoil: the wrist snaps up ~20 degrees."""
    sg = 1.0 if right else -1.0
    G_k, B_k, g_k = ("G", "BE", "gunR") if right else ("LP", "LBE", "gunL")
    off, other_b = ("LP", "LBE") if right else ("G", "BE")
    keys = [(0.0, {}),
            (0.03, {G_k: (sg * 0.15, 0.1, 1.28), B_k: aim(sg * -30, 4), g_k: 1.0, "tor": (0.02, sg * 0.38, 0.04), "hed": (0.02, sg * -0.38, 0.06), "smile": 0.9, **OPEN, "brow": 0.5}, "out"),
            (0.06, {G_k: (sg * 0.2, 0.46, 1.32), B_k: aim(0, 0), "tor": (0.03, sg * -0.42, 0.03), "hed": (0.0, sg * 0.42, 0.04), "smile": 1.0}, "out"),
            (0.09, {G_k: (sg * 0.2, 0.42, 1.36), B_k: aim(0, 20), "tor": (-0.03, sg * -0.44, 0.03)}, "out"),
            (0.2, {G_k: (sg * 0.2, 0.42, 1.32), B_k: aim(0, 8), "tor": (0.0, sg * -0.32, 0.03)}),
            (0.35, END)]
    return C(name, 0.35, keys)


# ---- the crouch (item 143): a bouncy coil. Sprung low on her toes, knees out, both finger guns up and ready, grinning; the coil never quite stops.
SPRING = dict(READY, **{
    "pel": (0.02, -0.03, -0.33), "prt": (0.34, -0.10, -0.05), "tor": (0.32, 0.14, 0.05), "hed": (-0.60, -0.08, 0.12),
    "G": (0.26, 0.42, 0.90), "BE": aim(-10, 6), "LP": (-0.26, 0.36, 0.92), "LBE": aim(14, 8),
    "FL": (-0.13, 0.20, A_Z + 0.03), "FR": (0.15, -0.18, A_Z + 0.05), "FLy": 0.34, "FRy": -0.5, "FLp": 0.3, "FRp": 0.5,
    "brow": 0.25, "lidR": 0.3, "lidL": 0.12, "smile": 1.0, "gunR": 1.0, "gunL": 1.0,
})
BOUNCE = {"ankle": A_Z, "foot": 0.10, "width": 0.11, "stride": 0.29, "lift": 0.06, "toe": 0.32, "share": 0.56, "sway": 0.035, "bob": 0.024, "twist": 0.13, "T": 0.54, "toe_out": -0.26}


def crouch_set():
    return crouchkit.quick(C, END, SPRING, BOUNCE, scan=0.3, bounce=0.022)


def clips():
    out = [FnClip("idle", IDLE_T, idle), FnClip("stance", STANCE_T, stance)]
    out += crouch_set()
    for nm, ang in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
        out.append(FnClip("walk_" + nm, 0.92, gait(0.45, ang)))
        out.append(FnClip("run_" + nm, 0.6, gait(1.0, ang)))
    out += [shot("lmb_l", False), shot("lmb_r", True)]
    # Storm Rod: she reaches back over her right shoulder, the rod comes off the rack; side-on, left finger aiming
    RH = {"G": (0.3, -0.06, 1.62), "BE": ((0.2, -0.1, 1), (0, 1, 0)), "gunR": 0.75, "LP": (0.05, 0.46, 1.34), "LBE": aim(-4, 0), "gunL": 1.0, "tor": (0.06, -0.75, 0.03), "hed": (0.0, 0.75, 0.03), "prt": (0.03, -0.3, 0), "FL": (-0.09, 0.2, A_Z), "FR": (0.13, -0.15, A_Z), "FLy": 0.05, "FRy": -0.6, **OPEN, "brow": 0.6, "smile": 0.6}
    out.append(C("rmb_hold", 0.8, [(0.0, {}), (0.12, RH, "out"), (0.8, dict(RH, G=(0.31, -0.08, 1.64), tor=(0.08, -0.82, 0.03)))]))
    out.append(C("rmb", 0.7, [(0.0, dict(RH, G=(0.31, -0.08, 1.64))), (0.06, {"G": (0.28, 0.3, 1.58), "BE": ((0, 1, 0.3), (0, 0, 1)), "gunR": 0.2, "tor": (0.35, 0.3, 0), "hed": (-0.25, -0.3, 0), "prt": (0.15, 0.25, 0), "FL": (-0.09, 0.3, A_Z), "FR": (0.13, -0.26, A_Z), "FRp": 0.3, "smile": 1.0}, "out"),
                              (0.16, {"G": (0.22, 0.42, 1.0), "BE": ((0, 0.7, -0.7), (0, 0.7, 0.7)), "LP": (-0.28, -0.05, 1.1), "tor": (0.55, 0.42, 0), "hed": (-0.45, -0.42, 0)}, "out"),
                              (0.42, {"tor": (0.12, 0.15, 0), "hed": (-0.08, -0.1, 0), "prt": (0.05, 0, 0), "G": (0.24, 0.2, 1.05)}), (0.7, END)]))
    # Wirerun held: low in a sprinter's crouch, the right arm out and aimed, the wire reeling off her hand
    CR = {"pel": (0, -0.04, -0.24), "prt": (0.5, 0, 0), "tor": (0.32, -0.18, 0), "hed": (-0.72, 0.1, 0), "G": (0.15, 0.62, 1.12), "BE": aim(0, 4), "gunR": 1.0, "LP": (-0.3, -0.24, 1.02), "LBE": ((-0.3, -1, -0.2), (0, 0, 1)), "gunL": 0.4,
          "FL": (-0.1, 0.26, A_Z), "FR": (0.11, -0.3, A_Z + 0.04), "FRp": 0.8, "FLy": 0.05, "FRy": -0.1, **OPEN, "brow": 0.8, "smile": 0.5, "skirt": 0.5}
    out.append(C("dash", 0.6, [(0.0, {}), (0.12, CR, "out"), (0.6, dict(CR, pel=(0, -0.04, -0.26), G=(0.15, 0.64, 1.1)))]))
    # Let go: flat along the wire, right hand leading, she flies behind her own finger
    GO = {"pel": (0, 0.1, -0.2), "prt": (1.05, 0, 0), "tor": (0.15, 0, 0), "hed": (-1.0, 0, 0), "G": (0.14, 0.68, 1.12), "BE": aim(0, 0), "gunR": 1.0, "LP": (-0.28, -0.3, 0.98), "LBE": ((-0.2, -1, 0), (0, 0, 1)),
          "FL": (-0.09, 0.0, 0.42), "FR": (0.09, -0.62, 0.72), "FLp": 0.5, "FRp": 0.9, "skirt": 1.0, "brow": 0.2, "smile": 1.0, "lidR": 0.12}
    out.append(C("dash_go", 0.5, [(0.0, CR), (0.14, GO), (0.4, dict(GO, pel=(0, 0.11, -0.19))), (0.5, dict(GO, prt=(0.75, 0, 0), hed=(-0.7, 0, 0)))]))
    LA = {"pel": (0, -0.03, -0.3), "prt": (0.42, 0, 0), "tor": (0.2, 0, 0), "hed": (-0.5, 0, 0), "G": (0.33, 0.25, 0.86), "BE": aim(-30, -20), "LP": (-0.36, 0.1, 0.72), "LBE": ((-0.3, 0, -1), (0, 1, 0)), "FL": (-0.15, 0.2, A_Z), "FR": (0.15, -0.2, A_Z + 0.02), "skirt": 0.8, "smile": 0.9}
    out.append(C("dash_land", 0.42, [(0.0, LA), (0.14, {"pel": (0.02, 0, 0.03), "prt": (-0.08, 0, 0), "tor": (-0.1, 0.1, 0), "hed": (0.15, 0, 0.1), "G": (0.3, 0.2, 1.3), "BE": aim(-30, 30), "gunR": 1.0, "LP": (-0.3, 0.1, 1.05), "skirt": 0.0}, "out"), (0.42, END)]))
    # the air dash: a tuck-and-flip
    TK = {"pel": (0, 0, -0.1), "tor": (0.7, 0, 0), "hed": (0.5, 0, 0), "G": (0.15, 0.3, 0.95), "BE": ((0, 0.3, -1), (0, 1, 0)), "LP": (-0.15, 0.3, 0.95), "LBE": ((0, 0.3, -1), (0, 1, 0)), "FL": (-0.09, 0.28, 0.45), "FR": (0.09, 0.3, 0.5), "FLp": 0.9, "FRp": 0.9}
    out.append(C("dash_ex", 0.5, [(0.0, {"prt": (0, 0, 0)}), (0.05, dict(TK, prt=(1.5, 0, 0)), "out"), (0.2, dict(TK, prt=(5.2, 0, 0))), (0.36, {"prt": (6.283, 0, 0), "tor": (0.1, 0, 0), "hed": (0.05, 0, 0), "G": READY["G"], "BE": READY["BE"], "LP": READY["LP"], "LBE": READY["LBE"], "FL": READY["FL"], "FR": READY["FR"], "FLp": 0, "FRp": 0}), (0.5, {"prt": (6.283, 0, 0)})]))
    # Skycall: left finger stabs the spot, then points straight up through the 0.8 s countdown
    PT = {"LP": (-0.14, 0.55, 1.32), "LBE": aim(10, -12), "gunL": 1.0, "tor": (0.05, 0.3, 0), "hed": (0.05, -0.3, 0), **OPEN}
    SK = {"LP": (-0.2, 0.1, 1.78), "LBE": ((0, 0.05, 1), (0, -1, 0.05)), "gunL": 1.0, "G": (0.26, 0.03, 1.02), "tor": (-0.18, 0.1, 0.06), "hed": (-0.42, 0.0, 0.05), "pel": (0.02, 0, 0.0), "lidR": 0.25, "lidL": 0.12, "smile": 1.0}
    out.append(C("sky", 1.4, [(0.0, {}), (0.07, {"tor": (0.1, 0.5, 0), "LP": (-0.3, -0.05, 1.2), "gunL": 1.0}), (0.14, PT, "out"), (0.3, SK, "out"), (0.5, dict(SK, LP=(-0.2, 0.1, 1.74))), (1.15, SK), (1.4, END)]))
    out.append(C("sky_snap", 0.55, [(0.0, SK), (0.06, {"LP": (-0.18, 0.5, 0.98), "LBE": aim(6, -48), "tor": (0.42, 0.1, 0), "hed": (-0.1, -0.1, 0), "pel": (0, 0, -0.1), "prt": (0.2, 0, 0), "smile": 1.0, "lidR": 0.9}, "out"), (0.3, {"LP": (-0.22, 0.42, 1.08), "tor": (0.2, 0.1, 0), "pel": (0, 0, -0.04), "prt": (0.08, 0, 0)}), (0.55, END)]))
    out.append(C("live", 0.55, [(0.0, {}), (0.07, {"LP": (-0.2, 0.1, 1.76), "LBE": ((0, 0.05, 1), (0, -1, 0.05)), "gunL": 1.0, "tor": (-0.12, 0, 0), "hed": (-0.3, 0, 0), "smile": 1.0}, "out"), (0.3, {"LP": (-0.2, 0.1, 1.7)}), (0.55, END)]))
    # Kitefall: the crouch, the launch and hang with the rods blazing, the dive down the bolt, the landing on one knee
    XC = {"pel": (0, -0.02, -0.34), "prt": (0.55, 0, 0), "tor": (0.3, 0, 0), "hed": (-0.65, 0, 0), "G": (0.34, -0.22, 0.92), "BE": ((0.2, -0.6, -0.8), (0, 0, 1)), "LP": (-0.34, -0.22, 0.92), "LBE": ((-0.2, -0.6, -0.8), (0, 0, 1)), "gunR": 0.8, "gunL": 0.8,
          "FL": (-0.15, 0.08, A_Z), "FR": (0.15, -0.1, A_Z), "skirt": 0.7, "brow": 0.9, **OPEN, "smile": 0.6, "lit": 0.6, "fan": 0.4}
    out.append(C("ult", 0.3, [(0.0, {}), (0.1, dict(XC, pel=(0, -0.02, -0.22)), "out"), (0.3, XC)]))
    XA = {"pel": (0, 0, 0.0), "prt": (-0.12, 0, 0), "tor": (-0.22, 0, 0), "hed": (0.22, 0, 0), "G": (0.62, 0.06, 1.68), "BE": aim(-85, 22), "LP": (-0.62, 0.06, 1.68), "LBE": aim(85, 22), "gunR": 1.0, "gunL": 1.0, "FL": (-0.1, 0.12, 0.34), "FR": (0.1, -0.08, 0.2), "FLp": 0.7, "FRp": 0.9, "skirt": 0.9, "smile": 1.0, "lidR": 0.12, "lit": 1.0, "fan": 1.0, "brow": 0.2}
    out.append(C("ult_air", 0.4, [(0.0, dict(XA, G=(0.12, 0.05, 1.86), LP=(-0.12, 0.05, 1.86), BE=((0, 0, 1), (0, 1, 0)), LBE=((0, 0, 1), (0, 1, 0)), FL=(-0.07, 0, 0.1), FR=(0.07, 0, 0.1), prt=(-0.1, 0, 0))), (0.2, XA), (0.4, dict(XA, pel=(0, 0, 0.012)))]))
    XD = {"pel": (0, 0.05, 0.0), "prt": (1.45, 0, 0), "tor": (0.25, 0, 0), "hed": (-0.85, 0, 0), "G": (0.1, 1.0, 0.86), "BE": aim(0, -30), "LP": (-0.1, 1.0, 0.86), "LBE": aim(0, -30), "FL": (-0.07, -0.72, 0.8), "FR": (0.07, -0.76, 0.86), "FLp": 1.0, "FRp": 1.0, "skirt": 1.0, "lit": 1.0, "fan": 1.0}
    out.append(C("ult_dive", 0.1, [(0.0, XA), (0.1, XD, "out")]))
    XL = {"pel": (0, 0.0, -0.46), "prt": (0.5, 0.1, 0), "tor": (0.45, 0, 0), "hed": (-0.75, 0, 0), "G": (0.32, 0.26, 0.58), "BE": ((0.1, 0.5, -0.85), (0, 1, 0.3)), "LP": (-0.3, 0.42, 0.14), "LBE": ((0, 0.3, -1), (0, 1, 0)), "FL": (-0.15, 0.2, A_Z), "FR": (0.15, -0.36, 0.12), "FRp": 1.2, "skirt": 0.9, "lit": 1.0, "fan": 0.6, "smile": 1.0}
    out.append(C("ult_land", 0.5, [(0.0, XL), (0.1, dict(XL, pel=(0, 0, -0.42), lit=0.8)), (0.3, {"pel": (0.02, 0, 0.0), "prt": (0.0, 0, 0), "tor": (-0.08, 0, 0), "hed": (0.1, 0, 0.05), "G": (0.42, 0.1, 1.25), "BE": aim(-50, 15), "LP": (-0.42, 0.1, 1.25), "LBE": aim(50, 15), "gunR": 1.0, "gunL": 1.0, "FL": READY["FL"], "FR": READY["FR"], "FRp": 0.0, "lit": 0.3, "fan": 0.2}, "out"), (0.5, END)]))
    # the gum: she blows it up, it pops (0.9 s, the kit's mage_bubble_pop), she sucks it back. Idle fidget, kills, after the ult. Head and gum only do anything.
    BLOW = {"hed": (0.04, 0.1, 0.06), "smile": 0.2, "lidL": 0.3, "lidR": 0.3, "brow": 0.3}
    out.append(C("gum", 1.2, [(0.0, {}), (0.2, dict(BLOW, gum=0.65)), (0.86, dict(BLOW, gum=1.25)), (0.9, {"gum": 0.03, "smile": 1.0, "lidL": 0.7, "lidR": 0.7, "hed": (-0.03, -0.05, 0.0)}, "out"), (0.98, {"gum": 0.05, "lidL": 0.12, "lidR": 0.12}), (1.2, END)]))
    # air, landing
    out.append(C("jump", 0.4, [(0.0, {"pel": (0, 0, -0.1), "tor": (0.15, 0, 0), "G": (0.28, -0.05, 0.95), "LP": (-0.28, -0.05, 0.95)}), (0.15, {"pel": (0, 0, 0.0), "tor": (-0.08, 0, 0), "G": (0.3, 0.1, 1.28), "LP": (-0.3, 0.05, 1.2), "FL": (-0.09, 0.14, 0.32), "FLp": 0.6, "FR": (0.09, -0.05, 0.16), "skirt": 0.5}, "out"), (0.4, {"FR": (0.09, -0.08, 0.24)})]))
    out.append(C("fall", 0.8, [(0.0, {"tor": (-0.05, 0, 0), "G": (0.36, 0.03, 1.32), "BE": ((1, 0, -0.5), (0, 1, 0)), "LP": (-0.36, 0.03, 1.32), "LBE": ((-1, 0, -0.5), (0, 1, 0)), "FL": (-0.1, 0.1, 0.3), "FR": (0.1, -0.1, 0.22), "FLp": 0.4, "FRp": 0.5, "skirt": 0.8, "smile": 0.3, "lidR": 0.12}), (0.4, {"G": (0.37, 0.03, 1.35), "LP": (-0.37, 0.03, 1.35)}), (0.8, {"G": (0.36, 0.03, 1.32), "LP": (-0.36, 0.03, 1.32)})]))
    out.append(C("glide", 1.2, [(0.0, {"prt": (0.42, 0, 0), "tor": (0.1, 0, 0), "hed": (-0.5, 0, 0), "G": (0.15, 0.06, 1.68), "BE": ((0, 0, 1), (0, 1, 0)), "LP": (-0.15, 0.06, 1.68), "LBE": ((0, 0, 1), (0, 1, 0)), "FL": (-0.08, -0.1, 0.22), "FR": (0.08, -0.25, 0.3), "FLp": 0.9, "FRp": 0.9, "skirt": 0.9, "lidR": 0.12, "smile": 1.0}), (0.6, {"prt": (0.45, 0, 0.03)}), (1.2, {"prt": (0.42, 0, 0)})]))
    out.append(C("land", 0.4, [(0.0, {"pel": (0, 0, -0.2), "prt": (0.3, 0, 0), "tor": (0.2, 0, 0), "skirt": 0.7, "G": (0.3, 0.1, 0.92), "LP": (-0.3, 0.1, 0.92)}), (0.4, END)]))
    # hit: the head goes first; both eyes shut
    out.append(C("hit_f", 0.42, [(0.0, {}), (0.06, {"pel": (0, -0.05, -0.03), "prt": (-0.2, 0, 0.05), "tor": (-0.3, 0.1, 0), "hed": (-0.32, 0.2, 0.1), "brow": -1.0, "lidR": 0.9, "lidL": 0.9, "smile": -0.6, "G": (0.28, -0.03, 1.1), "LP": (-0.28, 0.0, 1.12), "gum": 0.2}, "out"), (0.42, END)]))
    out.append(C("hit_b", 0.42, [(0.0, {}), (0.06, {"pel": (0, 0.05, -0.03), "prt": (0.2, 0, -0.05), "tor": (0.3, -0.1, 0), "hed": (0.3, 0, 0), "brow": -1.0, "lidR": 0.9, "lidL": 0.9, "smile": -0.6, "G": (0.3, -0.1, 1.08), "LP": (-0.3, -0.1, 1.08), "gum": 0.2}, "out"), (0.42, END)]))
    SI = {"pel": (0, -0.1, -0.62), "prt": (0.3, 0.12, 0.08), "tor": (0.28, -0.1, 0.05), "hed": (0.2, 0.15, -0.1), "G": (0.2, 0.2, 0.26), "BE": ((0.3, 0.5, -0.8), (0, 1, 0)), "LP": (-0.26, 0.12, 0.34), "LBE": ((-0.2, 0.3, -1), (0, 1, 0)), "FL": (-0.3, 0.3, 0.11), "FR": (0.16, 0.42, 0.11), "FLy": 0.6, "FRy": -0.5, "FLp": 1.2, "FRp": 1.2, "brow": -0.8, "lidR": 0.7, "lidL": 0.6, "smile": -0.4, "gum": 0.0, "skirt": 0.6}
    out.append(C("downed", 2.4, [(0.0, SI), (1.2, dict(SI, tor=(0.34, -0.1, 0.05), hed=(0.28, 0.15, -0.1), pel=(0, -0.1, -0.61))), (2.4, SI)]))
    out.append(C("revive", 1.6, [(0.0, SI), (0.6, dict(SI, tor=(0.3, 0, 0), hed=(-0.1, 0, 0), lidR=0.2, brow=0.5)), (1.0, {"pel": (0, -0.02, -0.26), "prt": (0.3, 0, 0), "tor": (0.2, 0, 0), "hed": (-0.3, 0, 0), "FL": (-0.1, 0.15, A_Z), "FR": (0.13, -0.2, A_Z), "G": (0.2, 0.3, 0.9), "smile": 0.8}), (1.6, END)]))
    DE = {"pel": (0, -0.08, -0.72), "prt": (-1.35, 0, 0.1), "tor": (-0.1, 0.2, 0.1), "hed": (0.05, 0.5, 0.15), "G": (0.5, -0.24, 0.28), "BE": ((1, 0, -0.1), (0, 0, 1)), "LP": (-0.46, 0.05, 0.12), "LBE": ((-1, 0.4, 0), (0, 0, 1)), "FL": (-0.2, 0.6, 0.12), "FR": (0.16, 0.5, 0.24), "FLp": -0.8, "FRp": -0.6, "lidR": 1.0, "lidL": 1.0, "brow": -0.4, "smile": -0.2, "gum": 0.0, "skirt": 0.6}
    out.append(C("death", 1.5, [(0.0, {}), (0.14, {"pel": (0, -0.08, -0.06), "prt": (-0.2, 0, 0), "tor": (-0.35, 0, 0), "hed": (-0.4, 0, 0), "brow": -1, "lidR": 0.2, "lidL": 0.2, "smile": -0.8, "G": (0.34, 0.06, 1.2), "LP": (-0.34, 0.06, 1.2), "gum": 0.0}, "out"), (0.55, {"pel": (0, -0.05, -0.38), "prt": (-0.55, 0, 0.05), "tor": (-0.2, 0, 0), "hed": (0.1, 0.2, 0), "FL": (-0.15, 0.25, A_Z), "FR": (0.15, 0.1, A_Z + 0.04), "lidR": 0.7, "lidL": 0.7, "G": (0.42, -0.05, 0.75), "LP": (-0.42, 0, 0.72)}), (1.05, DE), (1.2, dict(DE, pel=(0, -0.08, -0.69))), (1.5, DE)]))
    out.append(C("stun", 1.0, [(0.0, {"tor": (0.25, 0.1, 0.1), "hed": (0.3, 0.3, 0.2), "lidR": 0.6, "lidL": 0.6, "brow": -0.6, "smile": -0.4, "G": (0.26, 0.05, 0.98), "LP": (-0.26, 0.05, 0.98), "pel": (0, 0, -0.06)}), (0.5, {"hed": (0.3, -0.3, -0.2), "tor": (0.25, -0.1, -0.1)}), (1.0, {"hed": (0.3, 0.3, 0.2), "tor": (0.25, 0.1, 0.1)})]))
    FU = {"pel": (0, -0.03, -0.3), "prt": (0.4, 0, 0), "tor": (0.45, 0, 0), "hed": (-0.1, 0, 0), "G": (0.2, 0.22, 0.86), "LP": (-0.2, 0.22, 0.86), "lidR": 0.9, "lidL": 0.9, "brow": 0.9, "lit": 0.7}
    out.append(C("fusion", 0.8, [(0.0, END), (0.18, FU), (0.3, dict(FU, pel=(0, -0.03, -0.32))), (0.45, dict(XA, pel=(0, 0, 0), FL=READY["FL"], FR=READY["FR"], FLp=0.0, FRp=0.0, skirt=0.3), "out"), (0.58, {"pel": (0, 0, -0.012)}), (0.8, END)]))
    # the emote: a cocky pair of finger guns, the wink, she blows the smoke off the right finger and holsters it
    G0 = {**BOTH_UP, "G": (0.3, 0.42, 1.3), "LP": (-0.3, 0.42, 1.3), "BE": aim(-8, 8), "LBE": aim(8, 8), "tor": (-0.05, 0.1, 0), "hed": (-0.05, -0.05, 0.12), "prt": (0.02, -0.14, -0.1), "pel": (0.05, 0, -0.03), "smile": 1.0, "lidR": 1.0, "lidL": 0.1, "brow": 0.4}
    BL = {"G": (0.09, 0.26, 1.52), "BE": ((-0.35, 0.3, 0.9), (0, 1, 0)), "LP": (-0.22, 0.08, 1.05), "LBE": READY["LBE"], "gunL": 0.1, "hed": (0.1, 0.18, 0.05), "lidR": 0.7, "lidL": 0.7, "smile": 0.2, "gum": 0.2}
    out.append(C("emote", 3.0, [(0.0, END), (0.25, G0, "out"), (0.32, dict(G0, BE=aim(-8, 26), LBE=aim(8, 26)), "out"), (0.42, G0), (1.0, dict(G0, pel=(0.06, 0, -0.04))), (1.4, BL), (1.95, dict(BL, gum=1.1)), (2.0, dict(BL, gum=0.03), "out"), (2.3, {"G": READY["G"], "BE": READY["BE"], "gunR": 0.0, "gunL": 0.0, "hed": READY["hed"], "smile": 1.0, "lidR": 0.12, "lidL": 0.12, "gum": 0.72}), (3.0, END)]))
    return out


class RSolver(Solver):
    """Both hands are free wrists: the off hand gets its own frame too, and the wrist is G itself."""

    def solve(self, P):
        Q, root_at = super().solve(P)
        fr = frame_of(*P["LBE"]) if len(P["LBE"]) == 2 else Quaternion(P["LBE"]).normalized()
        Q["hand.L"] = fr @ self.rest_frame.inverted()
        return Q, root_at


def ease_q(q):
    return q


def extras(P):
    if not P:
        return {}
    out = {}
    b, sm = P.get("brow", 0.0), P.get("smile", 0.5)
    for s, side in ((1.0, "R"), (-1.0, "L")):
        out["brow." + side] = (None, Vector((0, 0, -0.004 * b)))
        l = P.get("lid" + side, 0.12)
        out["lid." + side] = (Quaternion((1, 0, 0), -0.82 * max(0.0, min(1.0, l))), None)
        out["mouth." + side] = (None, Vector((s * 0.003 * (sm - 0.4), 0, 0.0065 * (sm - 0.4))))
        g = P.get("gun" + side, 0.0)
        c1 = 1.45 * g + 0.15
        c2 = 1.55 * g + 0.1
        sg = -1.0 if side == "R" else 1.0
        out["curl." + side] = (Quaternion((0, 0, 1), 0) @ Quaternion((0, 1, 0), 0) @ Quaternion((1, 0, 0), 0), None)
        out["curl." + side] = (Quaternion(CURL_AX[side], c1), None)
        out["curl2." + side] = (Quaternion(CURL_AX[side], c2), None)
        out["index." + side] = (Quaternion(CURL_AX[side], 0.12 - 0.12 * g), None)
        out["index2." + side] = (Quaternion(CURL_AX[side], 0.1 - 0.1 * g), None)
        out["thumb." + side] = (Quaternion(CURL_AX[side], -0.55 * g), None)
    out["skirt"] = (Quaternion((1, 0, 0), 0.35 * P.get("skirt", 0.0)), None)
    k = max(0.02, P.get("gum", 1.0))
    out["gum"] = (None, None)
    return out


CURL_AX = {"R": (0, 0, 1), "L": (0, 0, -1)}
EXTRA_SCALE = []


def rib_cage(p):
    """How much of the chest a hips-skinned point is (x_breath's weight): the torso from the waist to the collar, not the arms."""
    return ss((p.z - 1.12) / 0.1) * ss((1.43 - p.z) / 0.06) * ss((0.23 - abs(p.x)) / 0.06)


def scale_keys(arm, clip, n):
    """Bone scale channels the pose solver doesn't write: the gum, the rods' glow sleeves; and each rod's fan."""
    pbs = arm.pose.bones
    for f in range(n):
        t = clip.dur * f / max(n - 1, 1)
        P = clip.sample(t)
        g = max(0.03, P.get("gum", 1.0))
        pbs["gum"].scale = (g, g, g)
        pbs["gum"].keyframe_insert("scale", frame=f)
        pbs["x_breath"].scale = tuple(1.0 + BREATH * P.get("breath", 0.0) * ax for ax in BREATH_AXES)
        pbs["x_breath"].keyframe_insert("scale", frame=f)
        lit = P.get("lit", 0.0)
        fl = 1.0 + 3.0 * lit * (0.92 + 0.08 * math.sin(f * 2.4))
        fan = P.get("fan", 0.0)
        for i in range(4):
            pb = pbs["rodlit.%d" % i]
            pb.scale = (fl, 1.0, fl)
            pb.keyframe_insert("scale", frame=f)
            r = pbs["rod.%d" % i]
            r.rotation_mode = "QUATERNION"
            sg = (-1.5 + i) / 1.5
            r.rotation_quaternion = Quaternion((0, 0, 1), -0.3 * fan * sg) @ Quaternion((1, 0, 0), 0.0)
            r.keyframe_insert("rotation_quaternion", frame=f)
        # the lids only exist while they close: open, they collapse into the head instead of poking through the eye corners
        for sd in "RL":
            k = 1.0 if P.get("lid" + sd, 0.12) > 0.3 else 0.02
            pbs["lid." + sd].scale = (k, k, k)
            pbs["lid." + sd].keyframe_insert("scale", frame=f)


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    for im in bpy.data.images:  # the finish stage saves the atlas paths relative to build.sh's cwd; anywhere else (jobq) they fail to load and the export drops the textures
        if not im.has_data and not im.packed_file:
            im.filepath = os.path.join(os.path.dirname(os.path.abspath(a[0])), os.path.basename(im.filepath))
            im.reload()
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig = {"grip_rest": tuple(K.wrist_at(1.0)), "blade_rest": (0, 0, -1), "edge_rest": (0, 1, 0), "pelvis": 0.84, "hilt_l": 0.08,
           "lhand": {"k": (0, 1, 0), "o": (-1, 0, 0), "palm": tuple(K.wrist_at(-1.0))}}
    bpy.context.scene.render.fps = FPS
    add_breath(arm, (0, -0.08, 1.24), rib_cage)
    sol = RSolver(arm, rig)
    bpy.context.view_layer.objects.active = arm
    names = []
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        act = bake(arm, c, sol, extras)
        arm.animation_data.action = act
        n = max(2, int(round(c.dur * FPS)) + 1)
        scale_keys(arm, c, n)
        arm.animation_data.action = None
        names.append((c.name, round(c.dur, 3)))
    print("clips", len(names), names)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(a[1])[0] + "_anim.blend")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY") and o.name not in ("Src", "Low"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))

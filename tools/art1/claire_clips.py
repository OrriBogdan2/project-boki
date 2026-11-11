"""ART-1 Claire's animation set (hand-keyed as targets, solved by posekit). Times match the kit: the "tm_" tables in scripts/match/kmoves_care.gd and
content/archetypes/rimewright.json. Personality: elegant, playful, a cold edge. She is a figure skater: she never walks, she glides; long quiet edges, a soft knee, arms carried, the head a little down
and glancing up. Every flourish is grace, never display: modest lines, the legs low, nothing aimed at the body. The spear is carried upright like a staff, both hands on it for the big pushes.
Run: blender -b --python tools/art1/claire_clips.py -- <claire.blend> <out.glb> [clip,clip]"""
import sys, os, math
import bpy
import numpy as np
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, bake, ang_dir as D, at, eul, FPS, frame_of, lerp
import claire_pieces as K
import crouchkit

UP = (0, 0, 1)
A_Z = K.ANKLE_Z
FX = K.THIGH_X - 0.01


def spr(a, e, back=(0, -1, 0)):
    """The spear toward ang_dir(a, e); `back`: from the fist toward the elbow (the hand's own frame)."""
    return (D(a, e), back)


class HandSolver(Solver):
    """The free hand follows its forearm (a relaxed wrist) and takes a bend "LH", so a palm can push."""

    def solve(self, P):
        Q, r = Solver.solve(self, P)
        w = P.get("Lw", 0.0)
        if w < 1.0:
            q = Q["forearm.L"] @ eul(P.get("LH", (0, 0, 0)))
            Q["hand.L"] = q.slerp(Q["hand.L"], w)
        return Q, r


READY = {
    "pel": (0.012, 0.0, -0.022), "prt": (0.02, 0.1, -0.02), "tor": (0.03, -0.06, 0.03), "hed": (0.0, 0.06, 0.0),
    "G": (0.27, 0.15, 1.02), "BE": spr(2, 84, (-0.35, -0.9, -0.1)), "Lw": 0.0, "LP": (-0.29, 0.10, 0.99), "LH": (0.0, 0, 0.0),
    "FL": (-0.078, -0.03, A_Z), "FR": (0.095, 0.10, A_Z), "FLy": 0.4, "FRy": -0.16, "FLp": 0.0, "FRp": 0.0,
    "brow": -0.45, "lid": 0.04, "fing": 0.14, "skirt": 0.0, "skirtz": 0.0, "smile": 0.5,
}
LOWS = {"G": (0.29, 0.02, 0.97), "BE": spr(4, 12, (-0.3, -0.5, 0.8))}             # the spear carried low along her, for speed
PRAY = {"G": (0.09, 0.27, 1.17), "BE": spr(0, 80, (0.25, -0.95, -0.15)), "Lw": 1.0}
AIM_G = {"G": (0.055, 0.44, 1.16), "BE": spr(0, 3, (0.1, -0.5, -0.86)), "Lw": 1.0}


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, keys, base, loop)


END = dict(READY)


# ---- the idle and the stance (docs/art/IDLE_AUDIT.md, Neve). Both are 6 s loops on one pair of FEET, so the 0.5 s
# hand-off never slides a blade. Every curve is whole cycles of the loop or a beat that starts and ends inside it, so
# the seam closes. The pelvis leads; the torso, head and hands trail it by LAG seconds.
STAND_T = 6.0
LAG = {"tor": 0.12, "hed": 0.24, "hand": 0.36}      # s behind the pelvis
SWAY_T = 3.0                                        # s per edge-sway: two a loop
BREATH = 0.025                                      # x_breath's scale on a full breath (IDLE_AUDIT: 1 to 3 %)
BREATHS = 2                                         # a loop, 3 s each
BREATH_C = (0.0, 0.0, 1.30)                         # m, the rib cage's centre (hips at 0.86, shoulders at 1.34)
BREATH_R = (0.19, 0.15, 0.16)                       # m, its half sizes: the skin outside moves with hips alone
BREATH_CORE = 0.5                                   # of the half sizes: fully on x_breath inside this
# her rest: the weight on the left blade with a soft knee, the right toe pick tucked behind on the ice, the spear
# laid across her shoulders behind the hood with the right hand draped over it at the shoulder and the left resting on
# the shaft; the free hip dropped, the torso and head countering it
FEET = {"FL": (-0.05, 0.02, A_Z), "FLy": 0.22, "FLp": 0.0, "FR": (0.04, -0.17, A_Z + 0.03), "FRy": -0.55, "FRp": -0.35}
REST = dict(READY, **FEET, pel=(-0.035, 0.0, -0.045), prt=(0.01, 0.0, 0.05), tor=(0.02, 0.0, -0.06),
            hed=(0.0, 0.0, 0.02), G=(0.21, -0.06, 1.44), BE=spr(-70, 12, (0.45, -0.3, -0.84)),
            LP=(-0.26, -0.21, 1.37), LH=(0.4, 0.0, 0.0), fing=0.3, brow=-0.1, lid=0.12, smile=0.55, smirk=0.0)
# the ready: the same feet, the spear lowered across her to a low diagonal, the right hand forward, the left on the
# shaft at her hip, a heavy lid and a smirk at one corner
GUARD = dict(REST, G=(0.15, 0.22, 1.0), BE=spr(-48, 21, (0.55, -0.6, -0.55)), Lw=1.0, hed=(0.02, -0.06, 0.02),
             brow=0.2, lid=0.25, smile=0.5, smirk=0.7)
TWIRL_G = (0.12, 0.34, 1.20)                        # the right hand at her chest for the twirl
TWIRL_AXIS = Vector((0.3, -0.88, -0.37)).normalized()   # fist toward elbow: the spear spins round the forearm


def sm01(x):
    """0 below 0, 1 above 1, a smoothstep between."""
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def hill(t, a, b, k=1.0):
    """0 outside a..b seconds, a smooth hill inside; k > 1 rises slowly and falls fast (a tap)."""
    return math.sin(math.pi * ((t - a) / (b - a)) ** k) ** 2 if a < t < b else 0.0


def shift(ph):
    """One weight shift a cycle, 0..1: over in 35 % with a hair of overshoot, a hold, back, a hold."""
    ph %= 1.0
    if ph < 0.5:
        return sm01(ph / 0.35) + 0.08 * hill(ph, 0.3, 0.5)
    return 1 - sm01((ph - 0.5) / 0.35) - 0.08 * hill(ph, 0.8, 1.0)


def breath(u, lag=0.0):
    """BREATHS a loop, 0..1: a 40 % inhale and a longer exhale, flat at both ends of each."""
    ph = (u - lag / STAND_T) * BREATHS % 1.0
    return sm01(ph / 0.4) if ph < 0.4 else 1 - sm01((ph - 0.4) / 0.6)


def turned(p, th, piv):
    """The pose p turned th rad (+ left) about the vertical through piv (x, y): every world target and the blade."""
    c, s = math.cos(th), math.sin(th)

    def rz(v):
        x, y = v[0] - piv[0], v[1] - piv[1]
        return (piv[0] + x * c - y * s, piv[1] + x * s + y * c, v[2])
    q = dict(p, prt=(p["prt"][0], p["prt"][1] + th, p["prt"][2]))
    for k in ("pel", "G", "LP", "FL", "FR"):
        q[k] = rz(p[k]) if k != "pel" else rz((p[k][0], p[k][1], 0.0))[:2] + (p[k][2],)
    q["FLy"], q["FRy"] = p["FLy"] + th, p["FRy"] + th
    q["BE"] = tuple((d[0] * c - d[1] * s, d[0] * s + d[1] * c, d[2]) for d in p["BE"])
    return q


def life(p, u, amp=1.0):
    """The edge-sway with its overlap, the breath and a blink, shared by both clips; amp scales the sway."""
    t = u * STAND_T
    w = {k: amp * (2 * shift((t - LAG.get(k, 0.0)) / SWAY_T) - 1) for k in ("pel", "tor", "hed", "hand")}
    b, bt, bh = breath(u), breath(u, LAG["tor"]), breath(u, LAG["hed"])
    p["pel"] = (p["pel"][0] + 0.02 * w["pel"], p["pel"][1] + 0.005 * w["pel"], p["pel"][2] - 0.004 * abs(w["pel"]))
    p["prt"] = (p["prt"][0], p["prt"][1] + 0.03 * w["pel"], p["prt"][2] + 0.02 * w["pel"])
    p["tor"] = (p["tor"][0] - 0.012 * bt, p["tor"][1] - 0.04 * w["tor"], p["tor"][2] - 0.05 * w["tor"])
    p["hed"] = (p["hed"][0] + 0.01 * bh, p["hed"][1] + 0.03 * w["hed"], p["hed"][2] + 0.03 * w["hed"])
    for k in ("G", "LP"):
        v = p[k]
        p[k] = (v[0] + 0.012 * w["hand"], v[1] + 0.004 * w["hand"], v[2] + 0.004 * bt)
    p["skirtz"] = 0.15 * w["hand"]
    p["breath"] = b
    p["lid"] = max(p["lid"], hill(t, 1.45, 1.75), hill(t, 5.0, 5.25))
    return p


def idle(u):
    """A skater's rest on the left blade, the spear across her shoulders, swaying on the edge. Once a loop the right
    toe pick taps the ice twice while she glances down at it, then she turns one full spin on the blade back to rest."""
    t = u * STAND_T
    spin = hill(t, 3.55, 5.15)                                  # gathered over the blade for the spin
    p = life(dict(REST), u, 1.0 - spin)
    p["hed"] = (p["hed"][0], p["hed"][1] + 0.08 * math.sin(u * 2 * math.pi), p["hed"][2])
    # the taps: the tucked blade lifts and its pick comes down twice; the pelvis dips with each
    tap = hill(t, 2.85, 3.1, 1.6) + hill(t, 3.15, 3.4, 1.6)
    look = hill(t, 2.7, 3.7)
    fr = p["FR"]
    p["FR"] = (fr[0], fr[1], fr[2] + 0.05 * tap + 0.08 * spin)
    p["FRp"] = p["FRp"] - 0.2 * tap
    p["pel"] = (p["pel"][0] + (FEET["FL"][0] - p["pel"][0]) * spin, p["pel"][1] + (FEET["FL"][1] - p["pel"][1]) * spin,
                p["pel"][2] - 0.01 * tap - 0.01 * spin)
    p["hed"] = (p["hed"][0] + 0.22 * look, p["hed"][1] - 0.18 * look, p["hed"][2])
    p["smile"] = p["smile"] + 0.25 * look
    # the spin: one turn on the left blade, the right foot tucked to its ankle, a small overshoot on the stop
    th = 2 * math.pi * sm01((t - 3.9) / 0.9) - 0.08 * hill(t, 4.75, 5.05) + 0.03 * hill(t, 5.05, 5.35)
    p["FR"] = (fr[0] + (FEET["FL"][0] + 0.06 - fr[0]) * spin, fr[1] + (FEET["FL"][1] + 0.08 - fr[1]) * spin, p["FR"][2])
    p["skirtz"] = p["skirtz"] + 0.5 * spin
    return turned(p, th, FEET["FL"][:2])


def stance(u):
    """The same feet, the spear at a low ready across her, a cool smirk. Once a loop it lifts to her chest, twirls one
    full turn round her forearm while the free arm opens for balance, and lowers back to the ready."""
    t = u * STAND_T
    p = life(dict(GUARD), u)
    lift = sm01((t - 1.2) / 0.5) * (1 - sm01((t - 2.9) / 0.6))
    th = 2 * math.pi * sm01((t - 1.7) / 1.1)
    p["Lw"] = 1 - sm01((t - 1.0) / 0.4) * (1 - sm01((t - 3.2) / 0.5))
    p["G"] = lerp(p["G"], TWIRL_G, lift)
    ready = Vector(GUARD["BE"][0])
    flat = (ready - TWIRL_AXIS * ready.dot(TWIRL_AXIS)).normalized()
    blade = Quaternion(TWIRL_AXIS, th) @ ready.lerp(flat, lift).normalized()
    back = Vector(GUARD["BE"][1]).lerp(TWIRL_AXIS, lift).normalized()
    p["BE"] = (tuple(blade), tuple(back))
    p["LP"] = (-0.42, -0.08, 1.18)
    p["LH"] = (0.0, 0.0, 0.3)
    p["hed"] = (p["hed"][0] - 0.06 * lift, p["hed"][1] - 0.1 * lift, p["hed"][2])
    p["pel"] = (p["pel"][0], p["pel"][1], p["pel"][2] - 0.012 * lift)
    p["skirtz"] = p["skirtz"] + 0.2 * lift
    return p


def gait(speed_k, heading, stroke, period_lift):
    """She skates: one long edge while the other blade pushes out and back, then they trade. speed_k 0 walk .. 1 run. heading (deg, + left of facing)."""
    d = Vector((-math.sin(math.radians(heading)), math.cos(math.radians(heading)), 0))
    sd = Vector((d.y, -d.x, 0))                  # the push's side: to the right of the heading
    back = max(0.0, -d.y)
    fwd = max(0.0, d.y)
    lat = abs(d.x)

    def foot(ph, sx):
        ph = ph % 1.0
        base = Vector((sx * FX, 0, A_Z))
        if ph < 0.56:          # the glide: in under her, out in front
            k = ph / 0.56
            y = stroke * (0.5 - 0.75 * k)
            out = 0.0
            z, yaw = 0.0, 0.0
        elif ph < 0.84:        # the push: out to the side and behind
            k = (ph - 0.56) / 0.28
            y = stroke * (-0.25 - 0.55 * k)
            out = 0.11 * stroke / 0.3 * math.sin(k * math.pi * 0.5)
            z, yaw = 0.0, 0.5
        else:                  # the recover: skimming back in
            k = (ph - 0.84) / 0.16
            sm = k * k * (3 - 2 * k)
            y = stroke * (-0.8 + 1.3 * sm)
            out = 0.11 * stroke / 0.3 * (1 - sm)
            z, yaw = period_lift * math.sin(k * math.pi), 0.5 * (1 - sm)
        return base + d * y + Vector((sx, 0, 0)) * out + Vector((0, 0, z)), yaw

    def fn(u):
        p = dict(READY)
        rp, ry = foot(u, 1.0)
        lp, ly = foot(u + 0.5, -1.0)
        p["FR"], p["FL"] = tuple(rp), tuple(lp)
        hy = math.radians(heading) * 0.55
        p["FRy"], p["FLy"] = -ry - 0.05 + hy, ly + 0.05 + hy
        p["FRp"], p["FLp"] = 0.0, 0.0
        c1 = math.cos(u * 2 * math.pi)                 # + over the left blade.. - over the right
        s2 = math.sin(u * 4 * math.pi + 0.4)
        p["pel"] = (-0.03 * c1 + (0.02 * d.x), -0.02 * back + 0.03 * speed_k * fwd, -0.035 - 0.05 * speed_k + 0.008 * s2)
        lean = (0.07 + 0.2 * speed_k) * fwd - 0.05 * back
        p["prt"] = (lean * 0.55, 0.05 * c1, 0.05 * c1 + 0.1 * d.x * lat)
        p["tor"] = (lean * 0.55 + 0.012 * s2, -0.09 * c1, -0.03 * c1 + 0.05 * d.x)
        p["hed"] = (-lean * 0.7 + 0.06, 0.06 * c1 + 0.03, 0.03 * c1)
        w = speed_k
        low, rd = LOWS["G"], READY["G"]
        p["G"] = (rd[0] + (low[0] - rd[0]) * w, rd[1] + (low[1] - rd[1]) * w + 0.03 * c1 * (1 - w) * 0.5, low[2] + (rd[2] - low[2]) * (1 - w) + 0.012 * s2)
        p["BE"] = frame_of(tuple(Vector(D(2, 84)).lerp(Vector(D(5, 14 + 3 * s2)), w).normalized()), tuple(Vector((-0.35, -0.9, -0.1)).lerp(Vector((-0.3, -0.5, 0.8)), w).normalized()))
        # the left arm carried out, floating with the stroke
        p["LP"] = (-0.31 - 0.06 * w, 0.08 + 0.06 * w - 0.08 * c1 * (0.5 + 0.5 * w), 0.99 + 0.07 * w + 0.03 * max(0.0, c1))
        p["LH"] = (0.2 * w, 0, 0.1)
        p["fing"] = 0.1
        p["skirt"] = 0.25 * c1 * (0.4 + 0.6 * w)
        p["skirtz"] = 0.3 * math.sin(u * 2 * math.pi + 0.8) * (0.4 + 0.6 * w)
        p["brow"], p["lid"], p["smile"] = -0.1, 0.12, 0.5 + 0.3 * w
        return p
    return fn


# ---- the crouch (item 143): a skater's low edge. One long quiet lunge, the spear laid low along her line, the free hand out for balance, the head a little down and glancing up.
EDGE = dict(READY, **{
    "pel": (0.02, -0.06, -0.34), "prt": (0.36, 0.14, -0.04), "tor": (0.40, -0.16, 0.04), "hed": (-0.66, 0.10, 0.0),
    "G": (0.24, 0.42, 0.66), "BE": spr(6, 8, (-0.3, -0.5, 0.8)), "Lw": 0.0, "LP": (-0.38, 0.16, 0.60),
    "FL": (-0.10, 0.28, A_Z + 0.02), "FR": (0.14, -0.30, A_Z + 0.05), "FLy": 0.2, "FRy": -0.55, "FLp": 0.2, "FRp": 0.55,
    "brow": -0.5, "lid": 0.04, "fing": 0.3,
})
GLIDE = {"ankle": A_Z, "foot": 0.10, "width": 0.10, "stride": 0.33, "lift": 0.035, "toe": 0.22, "share": 0.66, "sway": 0.04, "bob": 0.01, "twist": 0.12, "T": 0.7, "toe_out": -0.28}


def crouch_set():
    return crouchkit.quick(C, END, EDGE, GLIDE, scan=0.24)


def clips():
    out = [FnClip("idle", STAND_T, idle), FnClip("stance", STAND_T, stance)]
    out += crouch_set()
    for nm, sk, stroke, lift, T in (("walk", 0.0, 0.26, 0.012, 1.5), ("run", 1.0, 0.42, 0.03, 1.0)):
        for tag, hd in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
            out.append(FnClip("%s_%s" % (nm, tag), T, gait(sk, hd, stroke * (0.8 if tag in "lr" else 1.0), lift)))

    # LMB (tm_dart_*: 0.03 cock, 0.07 flick, 0.16): the spear's tip dips and flicks a dart off it; then the left hand's turn, a little wrist flick off the palm, like tossing snow
    f0 = {"G": (0.2, 0.22, 1.13), "BE": spr(0, 38, (-0.2, -0.55, -0.8)), "tor": (0.04, -0.14, 0.03), "hed": (0.04, 0.14, 0.0), "brow": 0.1, "lid": 0.12}
    f1 = dict(f0, G=(0.17, 0.33, 1.15), BE=spr(0, 16, (-0.15, -0.5, -0.85)), tor=(0.08, 0.1, 0.0), hed=(0.0, -0.08, 0), smile=0.3)
    out.append(C("dart_r", 0.16, [(0.0, END), (0.03, f0, "out"), (0.07, f1, "out"), (0.16, dict(f0, G=(0.21, 0.24, 1.1), BE=spr(1, 50, (-0.25, -0.75, -0.6))))]))
    l0 = {"LP": (-0.2, 0.14, 1.2), "LH": (0.8, 0, 0.0), "fing": 0.35, "tor": (0.04, 0.16, -0.03), "hed": (0.04, -0.12, 0.0), "brow": 0.05}
    l1 = dict(l0, LP=(-0.14, 0.42, 1.2), LH=(-0.55, 0, 0), fing=0.0, tor=(0.09, -0.14, 0), hed=(0.0, 0.1, 0.0))
    out.append(C("dart_l", 0.16, [(0.0, END), (0.03, l0, "out"), (0.07, l1, "out"), (0.16, dict(l0, LP=(-0.22, 0.2, 1.1), LH=(0.3, 0, 0)))]))
    # the large darts: both hands on the shaft, drawn back to the hip and swept forward, the whole body following through
    h0 = {"G": (0.2, 0.2, 1.0), "BE": spr(10, 30, (-0.1, -0.6, -0.8)), "Lw": 1.0, "tor": (0.02, -0.34, 0.0), "prt": (0.06, -0.14, 0.0), "pel": (0, -0.03, -0.05), "brow": 0.2}
    h1 = dict(h0, G=(0.1, 0.48, 1.12), BE=spr(-1, 8, (0.1, -0.5, -0.85)), tor=(0.14, 0.24, 0), prt=(0.1, 0.1, 0), pel=(0, 0.06, -0.06), smile=0.2)
    out.append(C("dart_heavy", 0.18, [(0.0, END), (0.04, h0, "out"), (0.08, h1, "out"), (0.18, dict(h1, G=(0.14, 0.38, 1.08), BE=spr(2, 22, (0.0, -0.55, -0.83))))]))
    # LMB while skating (tm_beam): both hands level the spear straight ahead along the line, the head steady behind it
    b0 = {"G": (0.2, 0.2, 1.06), "BE": spr(1, 3, (-0.1, -0.5, -0.86)), "Lw": 1.0, "tor": (0.14, 0.0, 0.0), "hed": (-0.06, 0.0, 0), "brow": 0.3, "lid": 0.1}
    b1 = dict(b0, G=(0.19, 0.28, 1.07))
    out.append(C("beam", 0.22, [(0.0, b0), (0.04, dict(b0, G=(0.2, 0.16, 1.06)), "out"), (0.08, b1, "out"), (0.14, dict(b1, G=(0.195, 0.25, 1.065))), (0.22, b0)]))

    # RMB held (tm_spear_aim, 0.12): the spear drawn level between her hands at her chest, weight on the back blade, the head down and looking along it; a slow breath while it's held
    ai = dict(AIM_G, G=(0.055, 0.36, 1.13), tor=(0.03, 0.06, 0.0), prt=(-0.04, 0.04, 0), pel=(0, -0.035, -0.05), hed=(0.06, -0.02, 0), FR=(0.095, -0.08, A_Z), FL=(-0.08, 0.14, A_Z), FRy=-0.3, FLy=0.1, brow=0.15, lid=0.2, smile=0.25, skirt=-0.1)
    out.append(C("spear_aim", 0.92, [(0.0, END), (0.12, ai, "out"), (0.52, dict(ai, G=(0.055, 0.35, 1.145), tor=(0.0, 0.06, 0.0))), (0.92, ai)]))
    # RMB release (tm_spear: 0.05 load, 0.1 pushed out, 0.28 held through the recoil, 0.55): a two-handed push, never a throw: the weight rides forward onto the front blade and the back leg extends low
    lo = dict(ai, G=(0.055, 0.30, 1.1), pel=(0, -0.06, -0.075))
    pu = dict(AIM_G, G=(0.055, 0.62, 1.15), BE=spr(0, 1, (0.1, -0.5, -0.86)), prt=(0.26, 0.0, 0), tor=(0.16, 0.0, 0), hed=(-0.3, 0, 0), pel=(0, 0.14, -0.1), FR=(0.1, -0.3, A_Z), FL=(-0.08, 0.24, A_Z), FRy=-0.45, FLy=0.05, skirt=0.5, brow=0.2, lid=0.08, smile=0.3)
    out.append(C("spear", 0.55, [(0.0, ai), (0.05, lo, "out"), (0.1, pu, "out"), (0.28, dict(pu, pel=(0, 0.11, -0.09), G=(0.055, 0.57, 1.14), skirt=0.2)), (0.55, END)]))
    # E (tm_wall: 0.1-0.2 the tell, 0.27 out, 0.42 held, 0.7): a dip, the spear lifted; then its butt driven down into the ice while the left palm presses out at the wall
    wl0 = {"pel": (0, -0.02, -0.11), "prt": (0.12, 0.1, 0), "tor": (0.14, 0, 0), "hed": (0.02, 0, 0), "G": (0.24, 0.26, 1.18), "BE": spr(0, 86, (-0.3, -0.9, -0.2)), "LP": (-0.24, 0.0, 0.96), "LH": (0.3, 0, 0), "fing": 0.5, "brow": 0.2, "FR": (0.12, 0.1, A_Z), "FL": (-0.1, -0.06, A_Z), "skirt": -0.15}
    wl1 = dict(wl0, pel=(0, 0.09, -0.15), prt=(0.28, -0.05, 0), tor=(0.12, 0.05, 0), hed=(-0.28, 0, 0), G=(0.24, 0.4, 0.95), LP=(-0.2, 0.58, 1.02), LH=(-1.1, 0, 0), fing=0.0, FR=(0.12, 0.2, A_Z), FL=(-0.1, -0.22, A_Z), skirt=0.5, smile=0.3, lid=0.1)
    out.append(C("wall", 0.7, [(0.0, END), (0.1, wl0), (0.2, dict(wl0, pel=(0, -0.03, -0.13))), (0.27, wl1, "out"), (0.42, dict(wl1, pel=(0, 0.08, -0.14))), (0.7, END)]))
    # E again (tm_freeze: 0.07 knee up, 0.13 stamp, 0.42): the toe pick tapped into the ice, a small closing of the left hand
    fz0 = {"pel": (0, 0, 0.0), "tor": (-0.03, 0.05, 0), "FL": (-0.08, 0.1, A_Z + 0.13), "FLp": 0.5, "LP": (-0.2, 0.2, 1.16), "LH": (-0.2, 0, 0), "fing": 0.3, "smile": 0.3}
    fz1 = dict(fz0, pel=(0, 0.03, -0.09), tor=(0.12, 0, 0), hed=(0.2, 0, 0), FL=(-0.09, 0.2, A_Z - 0.01), FLp=0.0, LP=(-0.2, 0.16, 0.98), fing=1.0, skirt=0.3)
    out.append(C("freeze", 0.42, [(0.0, END), (0.07, fz0, "out"), (0.13, fz1, "out"), (0.42, END)]))

    # Shift, the Skate. Go (tm_skate_go, 0.16): the knee sinks and the back blade drives out; a distinct push-off
    sg0 = {"pel": (0, -0.04, -0.12), "prt": (0.3, 0, 0), "tor": (0.16, -0.1, 0), "hed": (-0.26, 0, 0), "FR": (0.1, -0.26, A_Z), "FL": (-0.08, 0.14, A_Z), "FRy": -0.75, "FLy": 0.05, "LP": (-0.36, 0.0, 1.0), "LH": (0.3, 0, 0), "skirt": -0.3, "smile": 0.7, "lid": 0.1}
    sg0.update(LOWS)
    sg1 = dict(sg0, pel=(0.04, 0.09, -0.13), prt=(0.42, 0, 0.1), FR=(0.14, -0.36, A_Z + 0.02), FL=(-0.09, 0.2, A_Z), skirt=-0.4, G=(0.31, -0.04, 0.98), LP=(-0.36, 0.24, 1.07))
    out.append(C("skate_go", 0.16, [(0.0, END), (0.08, sg0, "out"), (0.16, sg1)]))
    # held (tm_skate, looped every 0.56 s by the kit): long edges, the free leg trailing low, the arms opposed: the kit's speed made calm
    def sk(sw):
        return {"pel": (sw * 0.05, 0.08, -0.115), "prt": (0.4, 0.08 * sw, 0.11 * sw), "tor": (0.1, -0.16 * sw, -0.05 * sw), "hed": (-0.32, 0.12 * sw, 0.05 * sw),
                "G": (0.31, 0.0 - 0.04 * sw, 0.98), "BE": spr(4, 12 - 3 * sw, (-0.3, -0.5, 0.8)), "LP": (-0.36, 0.16 + 0.12 * sw, 1.08), "LH": (0.25, 0, 0.15),
                "FR": (0.09 + 0.1 * max(0, sw), 0.2 - 0.58 * max(0.0, sw), A_Z + 0.03 * max(0, sw)), "FL": (-0.09 - 0.1 * max(0, -sw), 0.2 - 0.58 * max(0.0, -sw), A_Z + 0.03 * max(0, -sw)),
                "FRy": -0.5 * max(0, sw), "FLy": 0.5 * max(0, -sw), "skirt": -0.35, "skirtz": 0.5 * sw, "brow": -0.15, "lid": 0.1, "smile": 0.8, "fing": 0.1}
    out.append(C("skate", 0.56, [(0.0, sk(1.0)), (0.28, sk(-1.0)), (0.56, sk(1.0))]))
    # in the air (tm_skate_air, item 62, same 0.56 loop): the stride goes soft over nothing: toes pointed, one blade trailing, the arms out for balance on her ribbon of ice
    def ska(sw):
        p = sk(sw)
        p.update({"pel": (sw * 0.03, 0.05, 0.03), "prt": (0.24, 0.06 * sw, 0.07 * sw), "hed": (-0.18, 0.08 * sw, 0.03 * sw), "skirt": -0.5,
                  "FR": (0.08, 0.08 - 0.3 * max(0.0, sw), A_Z + 0.09), "FL": (-0.08, 0.08 - 0.3 * max(0.0, -sw), A_Z + 0.09), "FRp": 0.35, "FLp": 0.35})
        return p
    out.append(C("skate_air", 0.56, [(0.0, ska(1.0)), (0.28, ska(-1.0)), (0.56, ska(1.0))]))
    # stop (tm_skate_stop: 0.07 / 0.22 / 0.5): a hockey-free little T-stop: the blades turn across, spray, and she straightens with a small breath out
    st0 = {"pel": (0.0, -0.03, -0.12), "prt": (-0.1, 0.5, 0.06), "tor": (0.12, -0.5, 0), "hed": (0.0, 0, 0), "FR": (0.16, 0.2, A_Z), "FL": (-0.14, -0.12, A_Z), "FRy": -1.2, "FLy": -0.9, "LP": (-0.34, 0.2, 1.08), "skirt": 0.45, "skirtz": 0.4, "smile": 0.6}
    st0.update(LOWS)
    out.append(C("skate_stop", 0.5, [(0.0, sk(1.0)), (0.07, st0, "out"), (0.22, dict(st0, pel=(0, -0.01, -0.09), skirt=0.2, skirtz=0.1)), (0.5, END)]))

    # passive (tm_shatter, 0.45): the spear's butt taps the ice once: a soft full stop
    sh0 = {"G": (0.27, 0.16, 1.12), "tor": (-0.03, 0, 0), "hed": (-0.04, 0.05, 0), "lid": 0.1, "smile": 0.4}
    out.append(C("shatter", 0.45, [(0.0, END), (0.06, sh0), (0.13, dict(sh0, G=(0.27, 0.16, 0.96), tor=(0.06, 0, 0), hed=(0.14, 0, 0)), "out"), (0.24, dict(sh0, G=(0.27, 0.16, 0.98), tor=(0.04, 0, 0), hed=(0.1, 0, 0))), (0.45, END)]))
    # the detonation (tm_clench, 0.34): the left hand closes, a small gesture to her chest
    out.append(C("clench", 0.34, [(0.0, END), (0.05, {"LP": (-0.2, 0.2, 1.12), "LH": (-0.2, 0, 0), "fing": 0.1}), (0.1, {"LP": (-0.14, 0.2, 1.16), "LH": (-0.3, 0, 0.2), "fing": 1.0, "tor": (0.05, 0, 0), "brow": 0.25}, "out"), (0.34, END)]))

    # X, Rimelock (tm_rime, 0.2): she folds in, both hands to the spear before her heart, eyes closing: a statue at prayer, not a crouch
    still = dict(PRAY, pel=(0.0, 0.0, -0.04), prt=(0.04, 0, 0), tor=(0.05, 0, 0), hed=(0.26, 0, 0), LP=(-0.1, 0.2, 1.2), fing=1.0, lid=0.95, brow=-0.35, smile=0.3,
                 FL=(-0.08, -0.02, A_Z), FR=(0.08, 0.05, A_Z), FLy=0.2, FRy=-0.1, skirt=0.0, skirtz=0.0)
    out.append(C("rime", 0.2, [(0.0, END), (0.12, dict(still, hed=(0.1, 0, 0), lid=0.5), "out"), (0.2, still)]))
    # cast from a skate (tm_rime_carry, 0.5): the same fold, the blades still running under her
    ca = dict(still, FL=(-0.08, -0.12, A_Z), FR=(0.08, 0.12, A_Z), prt=(0.18, 0, 0), hed=(0.2, 0, 0), skirt=-0.3)
    out.append(C("rime_carry", 0.5, [(0.0, sk(1.0)), (0.08, dict(ca, hed=(0.0, 0, 0), lid=0.4), "out"), (0.28, ca), (0.5, still)]))
    # held (tm_rime_hold): a frozen statue: nothing moves (item 65)
    out.append(C("rime_hold", 0.4, [(0.0, still), (0.4, still)]))
    # the crash (tm_rime_crash: 0.04 / 0.1 / 0.2 / 0.4): the ice bursts, arms open wide as a flower, chin lifting, then settling
    bu = {"pel": (0, 0, 0.0), "prt": (-0.06, 0, 0), "tor": (-0.14, 0, 0), "hed": (-0.24, 0, 0), "G": (0.42, 0.14, 1.2), "BE": spr(-14, 76, (-0.7, -0.6, -0.2)), "Lw": 0.0, "LP": (-0.46, 0.14, 1.26), "LH": (-0.3, 0, -0.2), "fing": 0.0, "lid": 0.0, "brow": -0.6, "smile": 0.9, "skirt": 0.3}
    out.append(C("rime_crash", 0.4, [(0.0, still), (0.04, dict(still, pel=(0, 0, -0.07), hed=(0.34, 0, 0))), (0.1, bu, "out"), (0.2, dict(bu, pel=(0, 0, -0.02))), (0.4, dict(bu, pel=(0, 0, -0.03), LP=(-0.38, 0.12, 1.12), G=(0.36, 0.14, 1.12), hed=(-0.05, 0, 0)))]))
    # ended early (tm_rime_break, 0.3): eyes open, the arms come down
    out.append(C("rime_break", 0.3, [(0.0, still), (0.08, dict(still, lid=0.2, hed=(0.1, 0, 0))), (0.3, END)]))

    # air: the jump is a small figure-skating hop, toes neat; the fall gathers, arms out for balance; the glide is the glider's grips, ankles together
    out.append(C("jump", 0.45, [(0.0, {"pel": (0, 0, -0.11), "prt": (0.16, 0, 0)}), (0.08, {"pel": (0, 0, 0.0), "prt": (-0.03, 0, 0), "tor": (-0.08, 0, 0), "FL": (-0.07, 0.05, A_Z + 0.14), "FR": (0.075, 0.12, A_Z + 0.07), "FLp": 0.35, "FRp": 0.35, "LP": (-0.36, 0.06, 1.16), "smile": 0.8, "skirt": 0.3}, "out"),
                                (0.3, {"FL": (-0.07, 0.03, A_Z + 0.17), "FR": (0.075, 0.09, A_Z + 0.11)}), (0.45, {"FL": (-0.07, 0.02, A_Z + 0.15), "FR": (0.075, 0.06, A_Z + 0.09)})]))
    ri = {"pel": (0, 0, 0.0), "prt": (-0.03, 0, 0), "tor": (-0.05, 0, 0), "FL": (-0.07, 0.03, A_Z + 0.16), "FR": (0.075, 0.09, A_Z + 0.1), "FLp": 0.35, "FRp": 0.35, "LP": (-0.36, 0.06, 1.14), "skirt": 0.2}
    out.append(C("rise", 0.4, [(0.0, ri), (0.2, dict(ri, FL=(-0.07, 0.03, A_Z + 0.18))), (0.4, ri)]))
    fa = {"pel": (0, 0, 0.02), "prt": (0.03, 0, 0), "tor": (-0.04, 0, 0), "hed": (0.12, 0, 0), "G": (0.33, 0.1, 1.08), "LP": (-0.38, 0.06, 1.12), "FL": (-0.09, 0.0, A_Z + 0.08), "FR": (0.09, 0.07, A_Z + 0.1), "FLp": 0.3, "FRp": 0.3, "skirt": -0.35, "brow": -0.5}
    out.append(C("fall", 0.6, [(0.0, fa), (0.3, dict(fa, LP=(-0.38, 0.06, 1.16), G=(0.33, 0.1, 1.11), skirt=-0.45)), (0.6, fa)]))
    gr = dict(G=(0.15, 0.08, K.SHOULDER_Z + 0.36), BE=spr(90, 4, (-0.2, -0.1, -0.95)))
    gl = {"pel": (0, 0, 0.04), "prt": (0.3, 0, 0), "tor": (-0.04, 0, 0), "hed": (-0.12, 0, 0), "LP": (-0.14, 0.08, K.SHOULDER_Z + 0.42), "LH": (0, 0, 0), "fing": 0.9, "FL": (-0.06, -0.1, A_Z + 0.1), "FR": (0.06, -0.06, A_Z + 0.12), "FLp": 0.5, "FRp": 0.5, "skirt": -0.5, "smile": 0.9, "lid": 0.1}
    gl.update(gr)
    out.append(C("glide", 1.2, [(0.0, gl), (0.6, dict(gl, pel=(0, 0, 0.02), FL=(-0.06, -0.12, A_Z + 0.08), skirtz=0.25)), (1.2, gl)]))
    l2 = {"pel": (0, 0.0, -0.17), "prt": (0.2, 0, 0), "tor": (0.16, 0, 0), "hed": (-0.1, 0, 0), "LP": (-0.4, 0.04, 1.05), "G": (0.34, 0.14, 1.0), "FL": (-0.09, -0.1, A_Z), "FR": (0.09, 0.14, A_Z), "skirt": 0.3, "smile": 0.7}
    out.append(C("land", 0.4, [(0.0, fa), (0.08, l2, "out"), (0.2, dict(l2, pel=(0, 0, -0.08))), (0.4, END)]))

    # hit reacts: a flinch and a worried look, the spear pulled in; never a stagger
    fl = {"pel": (0, -0.04, -0.06), "prt": (-0.14, 0, 0), "tor": (-0.18, 0.1, 0), "hed": (0.14, 0.2, 0.05), "brow": -0.9, "lid": 0.5, "smile": -0.6, "LP": (-0.12, 0.2, 1.24), "LH": (-0.8, 0, 0.3), "fing": 0.6, "G": (0.24, 0.12, 1.08), "skirt": -0.3}
    out.append(C("hit_f", 0.42, [(0.0, END), (0.07, fl, "out"), (0.2, dict(fl, pel=(0, -0.02, -0.04))), (0.42, END)]))
    fb = dict(fl, pel=(0, 0.04, -0.06), prt=(0.2, 0, 0), tor=(0.14, -0.1, 0), hed=(-0.16, -0.2, 0.05), skirt=0.3)
    out.append(C("hit_b", 0.42, [(0.0, END), (0.07, fb, "out"), (0.2, dict(fb, pel=(0, 0.02, -0.04))), (0.42, END)]))
    daz = {"pel": (0.0, 0, -0.1), "prt": (0.06, 0, 0.05), "tor": (0.12, 0, -0.1), "hed": (0.3, 0, -0.14), "LP": (-0.28, 0.1, 0.96), "fing": 0.0, "lid": 0.55, "brow": -0.8, "smile": -0.3, "G": (0.28, 0.14, 0.98)}
    out.append(C("stun", 1.2, [(0.0, daz), (0.6, dict(daz, hed=(0.3, 0, 0.14), tor=(0.12, 0, 0.1), prt=(0.06, 0, -0.05))), (1.2, daz)]))

    # downed: sunk to the ice sitting to one side, legs folded together, leaning on the spear, breath coming slow
    dn = {"pel": (-0.03, -0.1, -0.60), "prt": (0.1, 0.25, 0.14), "tor": (0.22, 0.05, 0.12), "hed": (0.24, 0, 0.1), "G": (0.33, 0.28, 0.6), "BE": spr(3, 78, (-0.3, -0.9, -0.1)), "LP": (-0.26, 0.08, 0.42), "LH": (-0.5, 0, 0), "fing": 0.0,
          "FL": (-0.16, 0.3, A_Z - 0.05), "FR": (0.03, 0.34, A_Z - 0.05), "FLy": 1.2, "FRy": 1.0, "FLp": -0.3, "FRp": -0.3, "brow": -0.9, "lid": 0.6, "smile": -0.3, "skirt": 0.0}
    d2 = dict(dn, tor=(0.27, 0.05, 0.12), pel=(-0.03, -0.1, -0.615), hed=(0.3, 0, 0.1))
    out.append(C("downed", 2.4, [(0.0, dn), (1.2, d2), (2.4, dn)]))
    out.append(C("revive", 1.6, [(0.0, dn), (0.5, dict(dn, tor=(0.1, 0.05, 0.05), hed=(-0.1, 0, 0), lid=0.3, brow=-0.5, G=(0.33, 0.3, 0.72))),
                                 (0.95, {"pel": (0, -0.05, -0.34), "prt": (0.3, 0, 0), "tor": (0.3, 0, 0), "hed": (-0.26, 0, 0), "FL": (-0.1, -0.18, A_Z), "FR": (0.12, 0.26, A_Z), "FLy": 0.3, "FRy": 0, "FLp": 0.0, "FRp": 0.0, "G": (0.3, 0.36, 0.86), "LP": (-0.3, 0.2, 0.84), "lid": 0.25, "smile": 0.2}), (1.6, END)]))
    # death: the spear slips, she folds softly to her knees and over onto her side, hands drawn in
    dd0 = {"pel": (0, -0.02, -0.08), "prt": (-0.08, 0, 0), "tor": (-0.16, 0, 0), "hed": (-0.1, 0.1, 0), "lid": 0.4, "brow": -1.0, "smile": -0.4, "LP": (-0.16, 0.18, 1.24), "LH": (-0.8, 0, 0.3), "G": (0.3, 0.2, 0.9)}
    dd1 = {"pel": (0, 0.0, -0.46), "prt": (0.25, 0, 0.12), "tor": (0.3, 0, 0.12), "hed": (0.3, 0.1, 0.1), "G": (0.36, 0.34, 0.42), "BE": spr(30, 30, (-0.3, -0.9, 0.0)), "LP": (-0.2, 0.18, 0.74), "FL": (-0.12, -0.2, A_Z - 0.04), "FR": (0.12, -0.14, A_Z - 0.04), "FLp": 0.8, "FRp": 0.8, "lid": 0.7, "skirt": 0.2}
    dead = {"pel": (0.06, -0.16, -0.70), "prt": (0.28, 0.1, 1.2), "tor": (0.14, 0.1, 0.12), "hed": (0.3, 0.25, 0.1), "G": (0.5, 0.3, 0.1), "BE": spr(60, 0, (-0.2, -0.3, 0.9)), "LP": (-0.04, 0.34, 0.2), "LH": (-0.3, 0, 0), "FL": (-0.3, -0.16, 0.1), "FR": (-0.24, -0.02, 0.1), "FLy": 1.2, "FRy": 1.2, "FLp": 0.2, "FRp": 0.2, "lid": 1.0, "brow": -0.5, "fing": 0.3, "skirt": 0.0, "smile": 0.1}
    out.append(C("death", 1.5, [(0.0, END), (0.18, dd0, "out"), (0.62, dd1), (1.08, dead), (1.22, dict(dead, pel=(0.06, -0.16, -0.72))), (1.5, dead)]))

    # Fusion (mf_xform, 0.8): a gathered breath, then a single rising turn with the spear lifted, arms opening
    def fus(u):
        p = dict(READY)
        k = min(1.0, max(0.0, (u - 0.28) / 0.42))
        k = k * k * (3 - 2 * k)
        t = 2 * math.pi * k
        back = min(1.0, max(0.0, (u - 0.72) / 0.28))
        back = back * back * (3 - 2 * back)
        low = math.exp(-((u - 0.2) / 0.14) ** 2)
        up = math.sin(min(1.0, max(0.0, (u - 0.28) / 0.6)) * math.pi)
        c, s = math.cos(t), math.sin(t)
        def rz(x, y):
            return x * c - y * s, x * s + y * c
        p["prt"] = (0.1 * low, t, 0.0)
        p["pel"] = (0, 0, -0.03 - 0.12 * low + 0.03 * up)
        fl, fr = rz(-0.06, -0.02), rz(0.06, 0.05)
        p["FL"] = (fl[0], fl[1], A_Z + 0.05 * up)
        p["FR"] = (fr[0], fr[1], A_Z)
        p["FLy"], p["FRy"] = t, t
        p["FLp"], p["FRp"] = 0.3 * up, 0.3 * up
        ga, gb = (0.27, 0.15), (0.2, 0.12)
        g = rz(ga[0] + (gb[0] - ga[0]) * up, ga[1] + (gb[1] - ga[1]) * up)
        p["G"] = (g[0], g[1], 1.02 + 0.36 * up - 0.05 * low)
        lp = rz(-0.29 - 0.12 * up, 0.1)
        p["LP"] = (lp[0], lp[1], 0.99 + 0.3 * up)
        b0 = Vector(rz(-0.35, -0.9) + (-0.1,))
        p["BE"] = frame_of(D(2, 84), tuple(b0.normalized()))
        p["hed"] = (0.26 * low - 0.26 * up, 0, 0)
        p["lid"] = 0.2 + 0.7 * low
        p["smile"], p["brow"] = 0.8, -0.6
        p["fing"] = 0.0
        p["skirtz"] = 0.6 * up
        return p
    out.append(FnClip("fusion", 0.8, fus, loop=False))

    # the emote: one small, careful spin on the spot, a little surprised at herself; then a shy curtsey and a glance up
    def emo(u):
        p = dict(READY)
        T = 3.2
        tt = u * T
        k = min(1.0, max(0.0, (tt - 0.3) / 1.2))
        k = k * k * (3 - 2 * k)
        t = 2 * math.pi * k
        c, s = math.cos(t), math.sin(t)
        def rz(x, y):
            return x * c - y * s, x * s + y * c
        spin = math.sin(min(1.0, max(0.0, (tt - 0.15) / 1.5)) * math.pi)
        p["prt"] = (0.03, t + 0.1 * (1 - spin), -0.02)
        fr = rz(0.03 + 0.06 * (1 - spin), 0.03)
        fl = rz(-0.09 * (1 - spin) - 0.05 * spin, -0.03 - 0.1 * spin)
        p["FR"] = (fr[0], fr[1], A_Z)
        p["FL"] = (fl[0], fl[1], A_Z + 0.08 * spin)
        p["FRy"], p["FLy"] = t - 0.1, t + 0.3
        g = rz(0.27 - 0.12 * spin, 0.15 - 0.03 * spin)
        p["G"] = (g[0], g[1], 1.02 + 0.08 * spin)
        lp = rz(-0.29 - 0.08 * spin, 0.1)
        p["LP"] = (lp[0], lp[1], 0.99 + 0.2 * spin)
        b0 = Vector(rz(-0.35, -0.9) + (-0.1,))
        p["BE"] = frame_of(D(2, 85), tuple(b0.normalized()))
        p["skirtz"] = 0.7 * spin
        p["skirt"] = 0.0
        p["smile"], p["brow"], p["lid"] = 0.9, -0.5, 0.1
        # the curtsey (2.0 .. 2.9 s): one blade slides behind, the knees sink, the head dips, then the glance up
        cy = math.sin(min(1.0, max(0.0, (tt - 1.75) / 1.2)) * math.pi)
        if cy > 0.0:
            p["pel"] = (0.0, -0.01 * cy, -0.022 - 0.12 * cy)
            p["FL"] = (-0.09, -0.03 - 0.17 * cy, A_Z)
            p["FR"] = (0.09, 0.1, A_Z)
            p["FLy"], p["FRy"] = 0.4 * (1 - cy), -0.16
            p["prt"] = (0.03 + 0.06 * cy, 0.1, -0.02)
            p["tor"] = (0.03 + 0.16 * cy, -0.06, 0.03)
            p["hed"] = (0.08 + 0.3 * cy, 0.1, 0.03)
            p["LP"] = (-0.34, 0.14, 0.92 + 0.0 * cy)
            p["LH"] = (0.3 * cy, 0, 0)
            p["lid"] = 0.1 + 0.6 * cy
        gl = math.exp(-((tt - 2.95) / 0.16) ** 2)
        p["hed"] = (p["hed"][0] - 0.24 * gl, p["hed"][1] + 0.2 * gl, p["hed"][2])
        p["lid"] = p["lid"] * (1 - gl)
        return p
    out.append(FnClip("emote", 3.2, emo, loop=False))
    return out


def extras(P):
    if not P:
        return {}
    out = {}
    b = P.get("brow", 0.0)
    l = P.get("lid", 0.15)
    sm = P.get("smile", 0.5)
    for s, side in ((1.0, "R"), (-1.0, "L")):
        # brow: - lifts its inner end (worried, gentle), + lowers it (focus)
        out["brow." + side] = (Quaternion((0, 1, 0), -s * 0.2 * b), Vector((0, 0, -0.005 * b)))
        out["lid." + side] = (Quaternion((1, 0, 0), -0.82 * max(0.0, min(1.0, l))), None)
        lift = sm - 0.5 + (P.get("smirk", 0.0) * 0.5 if side == "R" else 0.0)    # the smirk lifts her right corner only
        out["mouth." + side] = (None, Vector((s * 0.0016 * lift, 0, 0.0034 * lift)))
    f = max(P.get("fing", 0.1), P.get("Lw", 0.0))
    out["fingers.L"] = (Quaternion((1, 0, 0), -1.0 * f), None)
    out["thumb.L"] = (Quaternion((1, 0, 0), -0.45 * f), None)
    q = Quaternion((1, 0, 0), 0.32 * P.get("skirt", 0.0)) @ Quaternion((0, 0, 1), 0.2 * P.get("skirtz", 0.0))
    out["skirt"] = (q, None)
    k = 1.0 + BREATH * P.get("breath", 0.0)
    out["x_breath"] = (None, None, Vector((k, k, k)))
    return out


def add_breath(arm):
    """The leaf bone x_breath under hips at the bottom of the rib cage, and the rib cage's skin moved onto it from hips
    (an ellipsoid round the chest, full inside BREATH_CORE, nothing at its rim), so a scale on it swells the chest."""
    if "x_breath" in arm.data.bones:
        return
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones.new("x_breath")
    eb.head, eb.tail = (0, 0, 1.30), (0, 0, 1.50)
    eb.parent = arm.data.edit_bones["hips"]
    bpy.ops.object.mode_set(mode="OBJECT")
    for body in bpy.data.objects:
        if body.type != "MESH" or body.name in ("Src", "Low") or "hips" not in body.vertex_groups:
            continue
        hips, xb = body.vertex_groups["hips"], body.vertex_groups.new(name="x_breath")
        to_arm = arm.matrix_world.inverted() @ body.matrix_world
        n = 0
        for v in body.data.vertices:
            w = next((g.weight for g in v.groups if g.group == hips.index), 0.0)
            p = to_arm @ v.co
            r = math.sqrt(sum(((p[i] - BREATH_C[i]) / BREATH_R[i]) ** 2 for i in range(3)))
            k = min(1.0, max(0.0, (1.0 - r) / (1.0 - BREATH_CORE)))
            k = w * k * k * (3 - 2 * k)
            if k > 1e-3:
                hips.add([v.index], w - k, "REPLACE")
                xb.add([v.index], k, "REPLACE")
                n += 1
        print("x_breath", body.name, n, "verts")


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    for img in bpy.data.images:             # the atlas is kept by a path from the build dir; find it from any cwd
        if img.filepath and not img.packed_file and not os.path.exists(bpy.path.abspath(img.filepath)):
            img.filepath = os.path.join(os.path.dirname(os.path.abspath(a[0])), os.path.basename(img.filepath))
            img.reload()
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    add_breath(arm)                                 # before the solver: edit mode rebuilds the bones it keeps
    b_, e_ = K.spear_frame()
    rig = {"grip_rest": tuple(K.GRIP_AT), "blade_rest": tuple(b_), "edge_rest": tuple(e_), "pelvis": K.HIPS_Z, "hilt_l": K.HILT_L,
           "lhand": {"k": (0, 1, -0.15), "o": (-1, 0, 0), "palm": (-K.SH + 0.012, 0.0, K.HAND_Z - 0.044)}}
    bpy.context.scene.render.fps = FPS
    sol = HandSolver(arm, rig)
    bpy.context.view_layer.objects.active = arm
    names = []
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        bake(arm, c, sol, extras)
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

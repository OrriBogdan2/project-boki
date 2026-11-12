"""ART-1 Kael's animation set (hand-keyed as targets, solved by posekit). Times match the kit: the kmove tables in
scripts/match/kmoves_dj.gd and content/archetypes/juggernaut.json. Personality (briefs/LORE_MASKS: grim, cold, never
cocky; he kills out of necessity): enormous, grim, economical: he never hurries his upper body, the sword's weight drags
everything after it, every stop lands heavy.
The keys are solved on the first Kael's rig (the build in /home/boki/art1kael/build/kael.blend, whose numbers are inlined
below) and played on the v2 model by tools/art1/kael_retarget.py, which also skins the x_breath leaf the idle breathes on.
Run: blender -b --python tools/art1/kael_clips.py -- <kael.blend> <out.glb> [idle,stance]"""
import sys, os, math
import bpy
import numpy as np
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, bake, ang_dir as D, at, eul, FPS, frame_of

# The first rig's measures (ext/art1-kael-2 kael_pieces): the keys below are written against them.
SH = 0.2608 * 0.9                                   # m: shoulder half-width
HAND_Z, SHOULDER_Z, ANKLE_Z, NECK_Z = 0.8228, 1.2678, 0.10, 1.3729   # m: rest heights, arms hanging
GRIP_DIR = Vector((0.0, 0.76, -0.65)).normalized()  # the blade from the fist, rest pose (he faces +Y)
_a = (Vector((0, 0, -1.0)) - GRIP_DIR * GRIP_DIR.dot(Vector((0, 0, -1.0)))).normalized()
GRIP_AT = Vector((SH, 0.0, HAND_Z + 0.012)) + _a * 0.094 + Vector((-0.03, 0.0, 0.0))   # inside the closed fist


def sword_frame():
    b = GRIP_DIR                                     # along the blade
    e = b.cross(Vector((1.0, 0, 0))).normalized()    # along the edge, upward
    if e.z < 0:
        e = -e
    return b, e, b.cross(e)


UP = (0, 0, 1)
A_Z = ANKLE_Z
BREATH = 0.03          # the rib cage's scale on a full breath (IDLE_AUDIT: 1-3 %)
BREATH_S = 3.0         # s per breath, slow and deep (6 s idle: two; 8 s stance: three of 2.67 s)


def be(a, e, edge=UP):
    """blade toward ang_dir(a, e), its edge toward `edge`."""
    return (D(a, e), edge)


READY = {
    "pel": (0.015, -0.015, -0.065), "prt": (0.10, 0.10, -0.03), "tor": (0.15, 0.12, 0.03), "hed": (-0.16, -0.14, 0.0),
    "G": (0.335, 0.20, 0.66), "BE": be(14, -30, (0.96, 0.1, 0.25)), "Lw": 0.0, "LP": (-0.315, 0.10, 0.63),
    "FL": (-0.165, 0.11, A_Z), "FR": (0.185, -0.10, A_Z), "FLy": 0.22, "FRy": -0.42, "FLp": 0.0, "FRp": 0.0,
    "brow": 0.7, "lid": 0.32, "fing": 0.1, "skirt": 0.0,
}
LOW = {"pel": (0.0, 0.0, -0.13), "prt": (0.2, 0.0, 0.0), "tor": (0.3, 0.0, 0.0)}
WIDE = {"FL": (-0.2, 0.2, A_Z), "FR": (0.22, -0.2, A_Z)}
SHOULDER = {"G": (0.30, 0.13, 1.20), "BE": be(172, 26, (0.15, -0.3, 0.9)), "Lw": 0.0}


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, keys, base, loop)


# ---- idle and the signature stance (docs/art/IDLE_AUDIT.md, Kael): every curve below is periodic in the phase u, so
# the last frame is the first and the loop seam closes (--clip-check SEAM_DEG / SEAM_M).
IDLE_S, STANCE_S = 6.0, 8.0
# The base both share, so the 0.5 s cross-fade never slides a foot: a wide-but-relaxed stand, left foot forward, right
# (sword) foot back and toed out, the weight on the back leg, knees soft, the right shoulder hung lower by the blade.
PLANT = {"FL": (-0.19, 0.10, A_Z), "FR": (0.21, -0.12, A_Z), "FLy": 0.22, "FRy": -0.45, "FLp": 0.0, "FRp": 0.0,
         "pel": (0.035, -0.03, -0.075), "prt": (0.03, 0.05, -0.04), "tor": (0.06, 0.04, 0.06), "hed": (-0.09, -0.09, -0.03),
         "LP": (-0.31, 0.05, 0.60), "Lw": 0.0, "fing": 0.35, "brow": 0.75, "lid": 0.32, "skirt": 0.0, "breath": 0.0}
# The sword rests point-down in front of his right foot, his hand round the hilt at chest height (v2's blade is 0.58 of
# his height, so the hilt comes up to the sternum), knuckles forward, the edge toward the viewer's left.
REST_G, REST_BE = (0.265, 0.15, 1.04), be(-20, -80, (0, 1, 0))
# Frame lags of the overlap: the pelvis moves, the chest follows, then the head and the free hand (IDLE_AUDIT: 2-6 frames).
LAG_CHEST, LAG_HEAD, LAG_HAND = 3.0, 5.0, 4.0


def sstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def bump(u, c, w):
    """A smooth hump of phase half-width w centred on c, 0 outside; periodic in u."""
    d = ((u - c + 0.5) % 1.0) - 0.5
    return 0.5 + 0.5 * math.cos(math.pi * d / w) if abs(d) < w else 0.0


def shift(u, a, b, r, over=0.2):
    """Hold, ease across r into a new place, overshoot a little and settle, hold, come back the same way (a < b, b + r < 1)."""
    s = sstep((u - a) / r) - sstep((u - b) / r)
    return s + over * (bump(u, a + r * 1.1, r * 0.8) - bump(u, b + r * 1.1, r * 0.8))


def dip(u, c, w):
    """A sink that rebounds past rest and settles: 1 at c, about -0.25 at c + 1.2 w, 0 beyond."""
    return bump(u, c, w) - 0.25 * bump(u, c + w * 1.2, w * 0.7)


def breath(u, n):
    """n slow breaths over the loop: a 42 % inhale, a longer exhale, 0..1, flat at both ends of each."""
    x = (u * n) % 1.0
    return 0.5 - 0.5 * math.cos(math.pi * x / 0.42) if x < 0.42 else 0.5 + 0.5 * math.cos(math.pi * (x - 0.42) / 0.58)


def _lag(u, frames, dur):
    return u - frames / (dur * FPS)


def _breathing(p, u, dur, n):
    """The rib cage swells on x_breath; the chest lifts a hair back, the head keeps its eyes level two frames later."""
    b = breath(u, n)
    p["breath"] = b
    bc, bh = breath(_lag(u, 1.0, dur), n), breath(_lag(u, 2.0, dur), n)
    t, h = p["tor"], p["hed"]
    p["tor"] = (t[0] - 0.006 * bc, t[1], t[2])
    p["hed"] = (h[0] + 0.006 * bh, h[1], h[2])
    lp = p["LP"]
    p["LP"] = (lp[0], lp[1], lp[2] + 0.005 * bh)


def idle(u):
    """6 s. Weight on the back leg; once per loop it eases forward onto both feet and settles back (the pelvis first,
    the chest, head and free hand frames behind). Slow deep breaths. The fidget, once: a few degrees of neck roll and the
    grip lifted and set down again. The head otherwise barely moves."""
    p = dict(READY)
    p.update(PLANT)
    T = IDLE_S
    sp, sc, sh, sa = (shift(_lag(u, k, T), 0.40, 0.68, 0.09) for k in (0.0, LAG_CHEST, LAG_HEAD, LAG_HAND))
    pel, prt, tor, hed, lp = PLANT["pel"], PLANT["prt"], PLANT["tor"], PLANT["hed"], PLANT["LP"]
    p["pel"] = (pel[0] - 0.030 * sp, pel[1] + 0.030 * sp, pel[2] + 0.008 * sp)
    p["prt"] = (prt[0] + 0.01 * sp, prt[1], prt[2] + 0.03 * sp)
    p["tor"] = (tor[0] + 0.015 * sc, tor[1] - 0.02 * sc, tor[2] - 0.03 * sc)
    # the fidget: the neck rolls left then right and comes back (u 0.08..0.34), the chin dipping a touch
    q = min(1.0, max(0.0, (u - 0.08) / 0.26))
    roll = 0.06 * math.sin(2 * math.pi * q) * math.sin(math.pi * q)
    p["hed"] = (hed[0] - 0.02 * sh - 0.03 * math.sin(math.pi * q) ** 2, hed[1] + 0.02 * sh, hed[2] + roll)
    # the grip resettles: the hand comes up a finger's width and sets down (u 0.20..0.32), the shoulder with it
    q2 = min(1.0, max(0.0, (u - 0.20) / 0.12))
    lift = math.sin(math.pi * q2) ** 2
    g = REST_G
    p["G"], p["BE"] = (g[0], g[1], g[2] + 0.012 * lift), REST_BE
    p["tor"] = (p["tor"][0], p["tor"][1], p["tor"][2] - 0.02 * lift)
    p["LP"] = (lp[0] - 0.005 * sa, lp[1] + 0.015 * sa, lp[2] + 0.004 * sa)
    p["fing"] = 0.35 + 0.4 * lift
    p["lid"] = 1.0 if 0.86 < u < 0.885 else 0.32
    _breathing(p, u, T, round(T / BREATH_S))
    return p


def stance(u):
    """8 s, on the idle's feet. The sword up on his right shoulder, long holds; once per loop the shoulder sinks under
    its weight and resettles. The head stays level, nothing showy."""
    p = dict(READY)
    p.update(PLANT)
    p.update(SHOULDER)
    T = STANCE_S
    pel, tor, hed = PLANT["pel"], PLANT["tor"], PLANT["hed"]
    sway = math.sin(2 * math.pi * u)
    p["pel"] = (pel[0] + 0.004 * sway, pel[1] + 0.005, pel[2] - 0.005)
    dp, dc, dh = (dip(_lag(u, k, T), 0.50, 0.08) for k in (0.0, LAG_CHEST, LAG_HEAD))
    p["prt"] = (PLANT["prt"][0] + 0.01, PLANT["prt"][1], PLANT["prt"][2] - 0.01 * dp)
    p["tor"] = (tor[0] + 0.02 + 0.01 * dc, tor[1] - 0.02, tor[2] + 0.04 * dc)
    p["hed"] = (hed[0] - 0.01 - 0.01 * dh, hed[1] + 0.02 + 0.02 * sway, hed[2] - 0.02 * dh)
    g = SHOULDER["G"]
    p["G"] = (g[0], g[1] - 0.005 * dc, g[2] - 0.025 * dc)
    p["fing"] = 0.5
    p["brow"], p["lid"] = 0.9, 0.36
    _breathing(p, u, T, round(T / BREATH_S))
    return p


# ---- locomotion: one generator, the stride along any heading
def gait(speed_k, heading, T):
    """speed_k 0.45 walk .. 1 run. heading (deg, + left of facing). The heavy two-beat: he drops into every step."""
    d = Vector((-math.sin(math.radians(heading)), math.cos(math.radians(heading)), 0))
    side = Vector((d.y, -d.x, 0))
    stride = 0.16 + 0.27 * speed_k
    lift = 0.05 + 0.15 * speed_k
    stance_share = 0.62 - 0.2 * speed_k
    back = max(0.0, -d.y)
    fwd = max(0.0, d.y)

    def foot(ph, sx):
        ph = ph % 1.0
        base = Vector((sx * 0.135, 0, A_Z))
        if ph < stance_share:
            k = ph / stance_share
            s = 1 - 2 * k
            z = 0.0
            pit = 0.0
        else:
            k = (ph - stance_share) / (1 - stance_share)
            sm = k * k * (3 - 2 * k)
            s = -1 + 2 * sm
            z = lift * math.sin(k * math.pi) ** 0.8 * (1.0 if k < 0.5 else 1.0)
            pit = -0.7 * math.sin(k * math.pi) * speed_k
        return base + d * s * stride + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        ph = u
        rp, pr = foot(ph, 1.0)
        lp, pl = foot(ph + 0.5, -1.0)
        p["FR"], p["FL"] = tuple(rp), tuple(lp)
        p["FRp"], p["FLp"] = pr, pl
        p["FRy"], p["FLy"] = -0.12 + math.radians(heading) * 0.5, 0.1 + math.radians(heading) * 0.5
        s2 = math.sin(u * 4 * math.pi + 0.5)
        c1 = math.cos(u * 2 * math.pi)
        drop = -0.055 - 0.06 * speed_k + (0.022 + 0.03 * speed_k) * s2
        p["pel"] = (0.024 * c1, 0.03 * speed_k * fwd - 0.03 * back, drop)
        lean = (0.13 + 0.26 * speed_k) * fwd - 0.12 * back
        p["prt"] = (lean * 0.55, 0.13 * c1 * speed_k + side.x * -0.0, -0.03 * c1 + 0.14 * speed_k * d.x)
        p["tor"] = (lean * 0.8 + 0.05 + 0.02 * s2, -0.26 * c1 * speed_k + 0.08, 0.05 * c1)
        p["hed"] = (-lean * 1.05 - 0.14, 0.2 * c1 * speed_k - 0.06, -0.04 * c1)
        # the sword trails low behind his right side, dragged by the arm, bouncing on the steps
        w = speed_k
        low = (0.33, -0.02 - 0.12 * w, 0.655 - 0.012 * s2)
        p["G"] = (READY["G"][0] + (low[0] - READY["G"][0]) * min(1, w * 1.6),
                  READY["G"][1] + (low[1] - READY["G"][1]) * min(1, w * 1.6), low[2])
        trail = 180 - 28 * (1 - w) + 6 * c1
        tip = -25 + 9 * s2
        p["BE"] = frame_of(D(-trail, tip) if w > 0.7 else tuple(Vector(D(14, -33)).lerp(Vector(D(-trail, tip)), min(1, w * 1.5))),
                           (1, 0, 0.15))
        # the free fist pumps
        p["LP"] = (-0.31, 0.16 - 0.24 * c1 * w, 0.68 + 0.12 * max(0, -c1) * w)
        p["fing"] = 0.6
        p["skirt"] = 0.25 * c1 * speed_k
        p["brow"], p["lid"] = 0.8, 0.34
        return p
    return fn


# ---- the sword's work
def overhead(a=0, e=128):
    return be(a, e, (0, 1, 0.1))


READY_END = {"G": READY["G"], "BE": READY["BE"], "Lw": 0.0, "pel": READY["pel"], "prt": READY["prt"], "tor": READY["tor"],
             "hed": READY["hed"], "FL": READY["FL"], "FR": READY["FR"], "FLp": 0, "FRp": 0, "LP": READY["LP"], "brow": 0.7,
             "lid": 0.32, "fing": 0.1, "skirt": 0.0}


def slash(side):
    s = 1 if side == "r" else -1            # r: from his right across to his left
    w = {"pel": (s * 0.03, -0.02, -0.11), "prt": (0.12, -s * 0.3, 0), "tor": (0.1, -s * 0.5, s * 0.08), "hed": (0.0, s * 0.45, 0),
         "G": at(-s * 62, 0.40, 1.02), "BE": be(-s * 118, 14, (0, 0, 1) if s > 0 else (0, 0, -1)), "Lw": 1.0,
         "FL": (-0.2, 0.16, A_Z), "FR": (0.22, -0.16, A_Z), "brow": 1.0, "lid": 0.25, "fing": 0.9}
    hit = {"pel": (-s * 0.04, 0.09, -0.15), "prt": (0.32, s * 0.45, 0), "tor": (0.32, s * 0.5, -s * 0.08), "hed": (-0.35, -s * 0.72, 0),
           "G": at(s * 28, 0.56, 0.86), "BE": be(s * 72, -4, (0, 0, 1) if s > 0 else (0, 0, -1)),
           "FL": (-0.22, 0.34 if s > 0 else 0.1, A_Z), "FR": (0.24, -0.26 if s > 0 else 0.26, A_Z), "skirt": s * 0.5}
    fol = {"pel": (-s * 0.05, 0.1, -0.16), "prt": (0.3, s * 0.55, 0), "tor": (0.26, s * 0.62, -s * 0.1), "hed": (-0.3, -s * 0.85, 0),
           "G": at(s * 66, 0.48, 0.8), "BE": be(s * 128, -16, (0, 0, 1) if s > 0 else (0, 0, -1))}
    return C("slash_" + side, 0.45, [(0.0, w), (0.1, hit, "out"), (0.24, fol, "out"), (0.45, READY_END)])


def clips():
    out = []
    out.append(FnClip("idle", IDLE_S, idle))
    out.append(FnClip("stance", STANCE_S, stance))
    for nm, sp, T in (("walk", 0.45, 1.1), ("run", 1.0, 0.68)):
        for tag, hd in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
            out.append(FnClip("%s_%s" % (nm, tag), T, gait(sp, hd, T)))
    out += [slash("r"), slash("l")]

    # Searing Wave: held, the blade dragged up and back behind his head, chest open; then the carve and long low lunge
    wind = {"pel": (0.0, -0.06, -0.09), "prt": (-0.08, 0, 0), "tor": (-0.26, 0.12, 0.0), "hed": (-0.08, -0.1, 0),
            "G": (0.15, -0.02, 1.32), "BE": be(178, 34, (0, 0.5, 0.8)), "Lw": 1.0, "FL": (-0.2, 0.24, A_Z), "FR": (0.22, -0.22, A_Z),
            "brow": 1.0, "lid": 0.2, "fing": 0.9}
    out.append(C("wave_wind", 0.7, [(0.0, READY_END), (0.25, wind), (0.5, {"pel": (0, -0.08, -0.12), "tor": (-0.34, 0.14, 0)}),
                                    (0.7, {"pel": (0, -0.075, -0.11), "tor": (-0.31, 0.14, 0)})]))
    out.append(C("wave", 0.6, [(0.0, wind), (0.1, {"pel": (0, 0.2, -0.2), "prt": (0.5, 0, 0), "tor": (0.45, -0.1, 0), "hed": (-0.75, 0.1, 0),
                                                   "G": (0.1, 0.62, 0.62), "BE": be(0, -24, (0, 0, -1)), "FL": (-0.2, 0.5, A_Z), "FR": (0.22, -0.34, A_Z),
                                                   "FRp": -0.5}, "out"),
                               (0.32, {"pel": (0, 0.18, -0.19), "G": (0.1, 0.6, 0.56)}, "lin"), (0.6, READY_END)]))
    # Finishing Slam: 0.6 s of a coil that rises, the blade high behind, then the whole weight through it at 0.6
    coil = {"pel": (0.02, -0.1, -0.15), "prt": (-0.02, -0.4, 0.05), "tor": (-0.1, -0.5, 0.08), "hed": (0.05, 0.75, 0),
            "G": (0.36, -0.16, 1.1), "BE": be(-155, 44, (0, -0.7, 0.7)), "Lw": 1.0, "FL": (-0.2, 0.26, A_Z), "FR": (0.24, -0.25, A_Z),
            "brow": 1.0, "lid": 0.2, "fing": 1.0}
    peak = dict(coil)
    peak.update({"pel": (0.0, -0.05, -0.06), "prt": (-0.14, -0.5, 0.05), "tor": (-0.24, -0.5, 0.1), "G": (0.28, -0.1, 1.36),
                 "BE": be(-175, 62, (0, -0.8, 0.6))})
    hit = {"pel": (0, 0.2, -0.24), "prt": (0.5, 0.2, 0), "tor": (0.55, 0.2, -0.05), "hed": (-0.8, -0.2, 0), "G": at(4, 0.62, 0.56),
           "BE": be(2, -34, (0, 0.6, -0.8)), "FL": (-0.22, 0.46, A_Z), "FR": (0.26, -0.3, A_Z), "FRp": -0.5, "skirt": 0.3}
    out.append(C("slam", 1.15, [(0.0, READY_END), (0.3, coil), (0.56, peak), (0.62, hit, "out"),
                                (0.85, {"pel": (0, 0.17, -0.21), "G": at(4, 0.6, 0.52), "tor": (0.48, 0.15, 0)}), (1.15, READY_END)]))
    # the Lunge held: sunk on the loaded back leg, the blade overhead, tip laid back, trembling with the charge
    hold = {"pel": (0, -0.1, -0.21), "prt": (0.12, -0.2, 0), "tor": (-0.1, -0.2, 0.03), "hed": (-0.08, 0.3, 0),
            "G": (0.16, 0.08, 1.4), "BE": be(180, 48, (0, 0.6, 0.8)), "Lw": 1.0, "FL": (-0.2, 0.36, A_Z), "FR": (0.22, -0.3, A_Z),
            "FRp": 0, "brow": 1.0, "lid": 0.18, "fing": 1.0}
    h2 = dict(hold)
    h2.update({"pel": (0.006, -0.105, -0.215), "G": (0.163, 0.08, 1.392)})
    out.append(C("lunge_wind", 0.73, [(0.0, READY_END), (0.1, {"prt": (0.1, -0.25, 0), "G": (0.34, 0.0, 1.0), "BE": be(-120, 30, (0, 0, 1)), "Lw": 1.0,
                                                                 "pel": (0, -0.05, -0.14)}),
                                      (0.28, hold), (0.45, h2), (0.59, hold), (0.73, h2)]))
    out.append(C("lunge", 0.6, [(0.0, hold), (0.08, {"pel": (0, 0.3, -0.13), "prt": (0.72, 0.2, 0), "tor": (0.3, 0.1, 0), "hed": (-0.95, -0.1, 0),
                                                     "G": (0.12, 0.72, 0.72), "BE": be(0, -8, (0, 0, -1)), "FL": (-0.2, 0.62, A_Z + 0.03),
                                                     "FR": (0.22, -0.56, A_Z + 0.06), "FRp": -0.8}, "out"),
                                (0.3, {"pel": (0, 0.26, -0.15), "prt": (0.6, 0.2, 0)}, "lin"), (0.6, READY_END)]))
    # Meteor: rocks back, hauls the blade up, one full turn gathering, pitches head-first; held till the ground
    tuck = {"pel": (0, 0, 0.04), "prt": (-0.4, 0, 0), "tor": (-0.25, 0, 0), "hed": (0.1, 0, 0), "G": (0.1, 0.1, 1.42), "BE": be(180, 60, (0, 0.8, 0.6)),
            "Lw": 1.0, "FL": (-0.14, 0.2, 0.42), "FR": (0.14, 0.16, 0.4), "FLp": -0.5, "FRp": -0.5, "fing": 1.0, "brow": 1.0, "lid": 0.15}
    spin = dict(tuck)
    spin["prt"] = (-0.5, -2 * math.pi, 0)
    dive = {"prt": (1.0, -2 * math.pi, 0), "pel": (0, 0.1, 0.1), "tor": (0.3, 0, 0), "hed": (-1.0, 0, 0), "G": (0.12, 0.62, 0.42), "BE": be(0, -62, (0, 0.8, -0.6)),
            "FL": (-0.12, -0.46, 0.34), "FR": (0.14, -0.6, 0.42), "FLp": 0.9, "FRp": 0.9}
    out.append(C("meteor", 0.42, [(0.0, READY_END), (0.08, tuck), (0.2, spin), (0.3, dive, "out"), (0.42, {"pel": (0, 0.11, 0.09)})]))
    land = {"pel": (0, 0.1, -0.36), "prt": (0.72, 0, 0), "tor": (0.42, 0, 0), "hed": (-1.0, 0, 0), "G": (0.1, 0.6, 0.36), "BE": be(0, -70, (0, 0.8, -0.6)),
            "FL": (-0.26, 0.36, A_Z), "FR": (0.26, -0.3, A_Z), "FRp": -0.7, "Lw": 1.0, "fing": 1.0, "skirt": 0.6, "brow": 1.0, "lid": 0.2}
    out.append(C("meteor_land", 0.5, [(0.0, land), (0.07, {"pel": (0, 0.09, -0.32)}, "out"),
                                      (0.25, {"pel": (0, 0.05, -0.26), "prt": (0.5, 0, 0), "G": (0.25, 0.45, 0.48), "BE": be(-20, -40, (0, 0.6, 0.8))}),
                                      (0.5, READY_END)]))
    # Rampage: a crouch, the blade cocked behind; the drive flat out, shoulder first, sword levelled; the long drag home
    cr = {"pel": (0, -0.06, -0.2), "prt": (0.28, -0.42, 0), "tor": (0.22, -0.4, 0), "hed": (-0.3, 0.6, 0), "G": (0.34, -0.2, 0.95), "BE": be(-160, 18, (0, 0, 1)),
          "Lw": 0.0, "LP": (-0.24, 0.3, 0.86), "FL": (-0.2, 0.22, A_Z), "FR": (0.22, -0.28, A_Z), "FRp": 0, "brow": 1.0, "lid": 0.2, "fing": 0.9}
    dr = {"pel": (0, 0.26, -0.17), "prt": (0.9, -0.45, 0), "tor": (0.35, 0.1, 0.1), "hed": (-1.1, 0.45, 0), "G": at(-4, 0.78, 0.74), "BE": be(-2, -4, (0.2, 0, 1)),
          "LP": (-0.3, -0.26, 0.74), "FL": (-0.16, 0.5, A_Z + 0.02), "FR": (0.18, -0.62, A_Z + 0.12), "FRp": -1.1, "skirt": -0.6}
    th = dict(dr)
    th.update({"G": at(-2, 0.92, 0.78), "tor": (0.4, 0.3, 0.1), "FL": (-0.16, 0.56, A_Z)})
    rec = {"pel": (0, 0.08, -0.22), "prt": (0.42, 0.1, 0), "tor": (0.28, 0.1, 0), "hed": (-0.6, -0.05, 0), "G": (0.36, -0.1, 0.66), "BE": be(-168, -18, (0, 0.2, 1)),
           "LP": (-0.3, 0.1, 0.72), "FL": (-0.2, 0.32, A_Z), "FR": (0.22, -0.3, A_Z), "FRp": 0}
    out.append(C("dash", 0.9, [(0.0, READY_END), (0.07, cr), (0.15, {"pel": (0, -0.07, -0.22)}), (0.21, dr, "out"), (0.38, th, "lin"), (0.5, rec), (0.78, {"pel": (0, 0.05, -0.17)}),
                               (0.9, READY_END)]))
    # the air dash: flat behind the leading shoulder, the blade trailing, knees up at the end
    a0 = {"pel": (0, 0, 0.02), "prt": (0.1, 0.4, 0), "tor": (0.1, 0.2, 0), "hed": (0, -0.3, 0), "G": (0.34, -0.1, 0.8), "BE": be(-150, -10, (0, 0, 1)),
          "FL": (-0.15, 0.15, 0.36), "FR": (0.16, 0.05, 0.3), "FLp": -0.4, "FRp": -0.4, "LP": (-0.28, 0.26, 0.86)}
    a1 = {"prt": (1.05, 0.45, 0.1), "tor": (0.2, 0.2, 0.05), "hed": (-1.2, -0.4, 0), "G": (0.3, -0.28, 0.86), "BE": be(-175, 6, (0, 0, 1)),
          "FL": (-0.12, -0.42, 0.3), "FR": (0.13, -0.55, 0.4), "FLp": 0.8, "FRp": 0.8, "LP": (-0.3, 0.45, 0.72)}
    a2 = {"prt": (0.3, 0.2, 0), "tor": (0.3, 0.1, 0), "hed": (-0.5, 0, 0), "FL": (-0.15, 0.22, 0.3), "FR": (0.16, 0.14, 0.26), "FLp": -0.2, "FRp": -0.2}
    out.append(C("exdash", 0.5, [(0.0, a0), (0.05, a1, "out"), (0.22, {"prt": (1.0, 0.42, 0.14)}, "lin"), (0.32, a2), (0.5, {"pel": (0, 0, -0.03)})]))
    # Warchain: the sword arm whips the chain out from the wrist: a sidearm crack, the blade held out of the way
    th0 = {"pel": (0, -0.04, -0.09), "prt": (0.05, -0.35, 0), "tor": (0, -0.5, 0.1), "hed": (-0.1, 0.8, 0), "G": (0.44, -0.2, 0.96), "BE": be(-170, 34, (0, 0, 1)),
           "LP": (-0.2, 0.3, 0.92), "fing": 0.3, "brow": 1.0, "lid": 0.2}
    th1 = {"pel": (0, 0.1, -0.13), "prt": (0.3, 0.4, 0), "tor": (0.28, 0.5, -0.1), "hed": (-0.42, -0.72, 0), "G": at(-16, 0.72, 1.0), "BE": be(-26, -6, (0, 0, 1)),
           "LP": (-0.34, -0.14, 0.86), "FL": (-0.2, 0.34, A_Z), "FR": (0.22, -0.28, A_Z)}
    out.append(C("chain", 0.7, [(0.0, READY_END), (0.08, th0, "out"), (0.16, th1, "out"), (0.45, {"G": at(-14, 0.66, 0.98)}), (0.7, READY_END)]))
    # pulled along it: leaning into the heading, chain arm out ahead, feet trailing. It holds while the kit reels.
    r1 = {"pel": (0, 0.05, 0.05), "prt": (0.55, 0.15, 0), "tor": (0.2, 0.1, 0), "hed": (-0.7, -0.1, 0), "G": at(-10, 0.74, 1.04), "BE": be(-24, -14, (0, 0, 1)),
          "LP": (-0.3, -0.2, 0.86), "FL": (-0.14, -0.1, 0.26), "FR": (0.16, -0.3, 0.3), "FLp": 0.5, "FRp": 0.7, "skirt": -0.5, "brow": 0.9, "lid": 0.25}
    r2 = dict(r1)
    r2.update({"pel": (0.01, 0.05, 0.075), "FR": (0.16, -0.34, 0.33), "FL": (-0.14, -0.14, 0.24)})
    out.append(C("reel", 0.65, [(0.0, {"G": at(-14, 0.66, 0.98), "BE": be(-26, -6, (0, 0, 1))}), (0.08, r1, "out"), (0.25, r2), (0.4, r1), (0.53, r2), (0.65, r1)]))
    # Cinder Spin: blade flung out wide, the body turns twice
    sp0 = {"pel": (0, 0, -0.14), "prt": (0.15, 0, 0), "tor": (0.12, 0, 0), "hed": (-0.2, 0, 0), "G": at(-55, 0.62, 0.92), "BE": be(-74, -2, (0, 0, 1)),
           "Lw": 1.0, "FL": (-0.22, 0.08, A_Z), "FR": (0.22, -0.08, A_Z), "fing": 1, "brow": 1, "lid": 0.2}
    sp1 = dict(sp0)
    sp1["prt"] = (0.15, -4 * math.pi, 0)
    out.append(C("spin", 0.55, [(0.0, sp0), (0.36, sp1, "lin"), (0.55, dict(READY_END, prt=(0.1, -4 * math.pi + 0.1, -0.03)))]))
    # the Chain Lunge
    out.append(C("chainlunge", 0.6, [(0.0, {"G": at(-40, 0.6, 1.0), "BE": be(-50, -8, (0, 0, 1)), "prt": (0.3, 0.3, 0), "Lw": 1, "pel": (0, 0, -0.1)}),
                                     (0.07, {"pel": (0, 0.3, -0.05), "prt": (0.85, -0.3, 0), "tor": (0.3, -0.1, 0), "hed": (-1.05, 0.3, 0), "G": at(0, 0.84, 0.82), "BE": be(0, -2, (0, 0, -1)),
                                             "FL": (-0.15, 0.5, A_Z + 0.05), "FR": (0.18, -0.6, A_Z + 0.12), "FRp": -1.0}, "out"),
                                     (0.3, {"pel": (0, 0.25, -0.1)}, "lin"), (0.6, READY_END)]))
    # a Haul Slam armed, and arriving
    hw = {"pel": (0, 0, 0.06), "prt": (0.15, 0, 0), "tor": (-0.2, 0, 0), "hed": (-0.1, 0, 0), "G": (0.14, -0.02, 1.38), "BE": be(180, 40, (0, 0.6, 0.8)), "Lw": 1.0,
          "FL": (-0.14, 0.14, 0.36), "FR": (0.15, -0.1, 0.34), "FLp": -0.3, "FRp": -0.3, "fing": 1, "brow": 1, "lid": 0.15}
    out.append(C("haul_wind", 0.15, [(0.0, r1), (0.15, hw)]))
    hs = {"pel": (0, 0.14, -0.3), "prt": (0.72, 0, 0), "tor": (0.5, 0, 0), "hed": (-1.05, 0, 0), "G": (0.1, 0.68, 0.46), "BE": be(0, -44, (0, 0.7, -0.7)),
          "FL": (-0.24, 0.42, A_Z), "FR": (0.26, -0.3, A_Z), "FLp": 0, "FRp": -0.6, "skirt": 0.5}
    out.append(C("haulslam", 0.7, [(0.0, hw), (0.06, hs, "out"), (0.35, {"pel": (0, 0.12, -0.25)}), (0.7, READY_END)]))
    # Gilded Riposte: the blade up before him, planted, shivering under the gold; then down and up through them
    gd = {"pel": (0, 0, -0.14), "prt": (0.02, 0, 0), "tor": (0.0, 0, 0), "hed": (-0.04, 0, 0), "G": (0.08, 0.34, 0.92), "BE": be(0, 86, (1, 0, 0)), "Lw": 1.0,
          "FL": (-0.24, 0.16, A_Z), "FR": (0.24, -0.16, A_Z), "brow": 1.0, "lid": 0.12, "fing": 1}
    g2 = dict(gd)
    g2.update({"pel": (0.006, 0, -0.15), "G": (0.085, 0.34, 0.915)})
    out.append(C("guard", 0.66, [(0.0, READY_END), (0.08, gd, "out"), (0.2, g2, "lin"), (0.3, gd, "lin"), (0.42, g2, "lin"), (0.54, gd, "lin"), (0.66, g2, "lin")]))
    out.append(C("riposte", 0.45, [(0.0, {"pel": (0, -0.04, -0.2), "prt": (0.32, 0, 0), "tor": (0.22, 0, 0), "hed": (-0.5, 0, 0), "G": (0.12, 0.3, 0.5), "BE": be(0, -52, (0, 0.8, 0.6)), "Lw": 1, "FL": (-0.22, 0.22, A_Z), "FR": (0.24, -0.2, A_Z), "brow": 1, "lid": 0.15, "fing": 1}),
                                   (0.06, {"pel": (0, 0.14, 0.02), "prt": (-0.15, 0, 0), "tor": (-0.22, 0, 0), "hed": (0.1, 0, 0), "G": (0.1, 0.46, 1.3), "BE": be(0, 72, (0, -0.3, 0.9)), "FL": (-0.22, 0.38, A_Z), "FR": (0.24, -0.28, A_Z + 0.02), "FRp": -0.5}, "out"),
                                   (0.14, {"G": (0.1, 0.3, 1.42), "BE": be(180, 80, (0, 0.9, 0.3))}),
                                   (0.3, {"pel": (0, 0.1, -0.1), "prt": (0.1, 0, 0), "tor": (0.05, 0, 0), "G": (0.2, 0.34, 1.14), "BE": be(0, 66, (0, 0, 1))}), (0.45, READY_END)]))
    # Rage: the roar (a tell): back arched, sword low, fist clenched at his side
    out.append(C("roar", 1.0, [(0.0, READY_END), (0.15, {"pel": (0, -0.04, -0.12), "prt": (0.3, 0, 0), "tor": (0.42, 0, 0), "hed": (-0.1, 0, 0), "brow": 1, "lid": 0.6}),
                               (0.32, {"pel": (0, -0.03, -0.04), "prt": (-0.14, 0, 0), "tor": (-0.3, 0, 0), "hed": (-0.42, 0, 0), "LP": (-0.36, -0.04, 0.82), "fing": 1, "brow": 1, "lid": 0.0}, "out"),
                               (0.75, {"pel": (0.0, -0.03, -0.05)}), (1.0, READY_END)]))
    # air and landing
    out.append(C("jump", 0.3, [(0.0, {"pel": (0, 0, -0.14), "prt": (0.25, 0, 0)}), (0.12, {"pel": (0, 0, 0.0), "prt": (0.0, 0, 0), "tor": (-0.08, 0.1, 0), "FL": (-0.12, 0.2, 0.3), "FR": (0.15, -0.1, 0.16), "FLp": -0.5, "FRp": 0.4, "G": (0.34, -0.08, 0.72), "BE": be(-150, -24, (0, 0.3, 1)), "LP": (-0.3, 0.14, 0.92)}, "out"), (0.3, {"FL": (-0.12, 0.18, 0.34), "FR": (0.15, -0.06, 0.26)})]))
    fall = {"pel": (0, 0, 0.0), "prt": (0.06, 0, 0), "tor": (0.1, 0.1, 0), "hed": (-0.1, 0, 0), "G": (0.38, -0.04, 0.84), "BE": be(-140, -5, (0, 0.3, 1)), "LP": (-0.38, 0.06, 0.92), "FL": (-0.14, 0.14, 0.2), "FR": (0.16, -0.08, 0.17), "FLp": -0.2, "FRp": -0.2, "skirt": -0.4}
    f2 = dict(fall)
    f2.update({"G": (0.38, -0.04, 0.86), "FL": (-0.14, 0.14, 0.215)})
    out.append(C("fall", 0.6, [(0.0, fall), (0.3, f2), (0.6, fall)]))
    land2 = {"pel": (0, 0.03, -0.26), "prt": (0.42, 0, 0), "tor": (0.32, 0, 0), "hed": (-0.5, 0, 0), "G": (0.38, 0.1, 0.5), "BE": be(-30, -26, (0, 0.4, 1)), "LP": (-0.32, 0.2, 0.56), "FL": (-0.2, 0.16, A_Z), "FR": (0.22, -0.1, A_Z), "FLp": 0, "FRp": 0, "skirt": 0.4, "brow": 1}
    out.append(C("land", 0.4, [(0.0, land2), (0.08, {"pel": (0, 0.03, -0.29)}, "out"), (0.4, READY_END)]))
    gl = {"pel": (0, 0, 0.0), "prt": (0.2, 0, 0), "tor": (0.0, 0, 0), "hed": (-0.1, 0, 0), "G": (0.215, -0.06, 1.5), "BE": be(-176, -62, (0, 0.3, 1)), "LP": (-0.215, -0.06, 1.51), "FL": (-0.12, 0.0, 0.2), "FR": (0.14, -0.2, 0.26), "FLp": 0.4, "FRp": 0.5, "skirt": -0.5, "fing": 1}
    g3 = dict(gl)
    g3.update({"pel": (0.01, 0, 0.012), "FR": (0.14, -0.23, 0.27), "FL": (-0.12, 0.03, 0.19)})
    out.append(C("glide", 1.6, [(0.0, gl), (0.8, g3), (1.6, gl)]))
    # hit reacts: a heavy man barely moves, the shoulders and head take it
    out.append(C("hit_f", 0.42, [(0.0, READY_END), (0.06, {"pel": (0, -0.09, -0.12), "prt": (-0.12, 0.08, 0.04), "tor": (-0.34, -0.26, 0.12), "hed": (0.34, 0.3, 0.1), "brow": -1.0, "lid": 0.7,
                                                           "G": (0.42, 0.06, 0.76), "BE": be(20, -40, (0, 0.5, 0.86)), "LP": (-0.36, 0.02, 0.72), "FR": (0.185, -0.17, A_Z), "skirt": -0.4}, "out"),
                                 (0.16, {"pel": (0, -0.07, -0.13), "tor": (-0.2, -0.18, 0.08), "hed": (0.16, 0.16, 0.06)}), (0.42, READY_END)]))
    out.append(C("hit_b", 0.42, [(0.0, READY_END), (0.06, {"pel": (0, 0.09, -0.13), "prt": (0.34, -0.08, -0.04), "tor": (0.5, 0.22, -0.1), "hed": (-0.6, -0.2, 0), "brow": -1.0, "lid": 0.7,
                                                           "G": (0.36, 0.3, 0.6), "LP": (-0.3, -0.08, 0.7), "FL": (-0.165, 0.2, A_Z), "skirt": 0.4}, "out"),
                                 (0.16, {"pel": (0, 0.07, -0.13), "tor": (0.34, 0.14, -0.06), "hed": (-0.4, -0.12, 0)}), (0.42, READY_END)]))
    # stun: reeling
    s1 = {"pel": (0.03, -0.02, -0.12), "prt": (0.2, 0.1, 0.05), "tor": (0.3, 0.1, 0.1), "hed": (0.3, 0.3, 0.2), "G": (0.34, 0.12, 0.6), "BE": be(-20, -40, UP), "brow": -0.8, "lid": 0.7, "LP": (-0.32, 0.08, 0.68)}
    s2 = dict(s1)
    s2.update({"pel": (-0.03, -0.02, -0.12), "prt": (0.2, -0.1, -0.05), "tor": (0.3, -0.1, -0.1), "hed": (0.3, -0.3, -0.2)})
    out.append(C("stun", 1.2, [(0.0, s1), (0.6, s2), (1.2, s1)]))
    # downed: on one knee, propped on the driven blade (he never lies flat while there is fight left); revive: he rises by it
    dn = {"pel": (0.0, -0.12, -0.3), "prt": (0.34, 0.1, 0.05), "tor": (0.42, 0.1, 0.1), "hed": (0.28, 0, 0.1), "G": (0.2, 0.52, 0.58), "BE": be(0, -82, (0, 0.8, 0.3)),
          "LP": (-0.22, 0.28, 0.4), "FL": (-0.2, 0.3, A_Z), "FR": (0.2, -0.6, A_Z + 0.06), "FRp": 1.2, "FRy": 0, "brow": -0.6, "lid": 0.72, "fing": 0.4, "skirt": 0.5}
    d2 = dict(dn)
    d2.update({"tor": (0.46, 0.1, 0.1), "pel": (0.0, -0.12, -0.31), "hed": (0.33, 0, 0.1)})
    out.append(C("downed", 2.4, [(0.0, dn), (1.2, d2), (2.4, dn)]))
    out.append(C("revive", 1.6, [(0.0, dn), (0.5, dict(dn, tor=(0.5, 0.1, 0.1), hed=(-0.1, 0, 0), lid=0.3, brow=1.0)),
                                 (0.95, {"pel": (0, -0.02, -0.2), "prt": (0.3, 0, 0), "tor": (0.3, 0, 0), "hed": (-0.4, 0, 0), "FR": (0.2, -0.28, A_Z), "FRp": 0.2, "G": (0.2, 0.46, 0.64), "lid": 0.25}), (1.6, READY_END)]))
    # death: the sword goes first, he folds forward over it onto his knees, then down
    dead = {"pel": (0, -0.1, -0.5), "prt": (1.25, 0.1, 0.1), "tor": (0.3, 0.1, 0.2), "hed": (0.4, 0.4, 0.3), "G": (0.3, 0.72, 0.13), "BE": be(30, 2, (0, 0, 1)), "LP": (-0.36, 0.6, 0.12),
            "FL": (-0.18, -0.34, 0.1), "FR": (0.2, -0.42, 0.1), "FLp": 1.2, "FRp": 1.2, "lid": 1.0, "brow": -0.4, "fing": 0.1, "skirt": 0.6}
    out.append(C("death", 1.5, [(0.0, READY_END), (0.18, {"pel": (0, -0.08, -0.08), "prt": (-0.2, 0, 0), "tor": (-0.32, 0, 0), "hed": (-0.5, 0, 0), "lid": 0.1, "brow": -1, "G": (0.4, 0.1, 0.62)}, "out"),
                                (0.6, {"pel": (0, 0.0, -0.36), "prt": (0.5, 0, 0), "tor": (0.5, 0, 0.1), "hed": (0.4, 0.1, 0), "G": (0.42, 0.4, 0.3), "BE": be(-10, -40, UP), "LP": (-0.3, 0.3, 0.3), "FL": (-0.2, 0.05, A_Z + 0.05), "FR": (0.2, -0.3, A_Z + 0.08), "FLp": 0.8, "FRp": 1.0, "lid": 0.75}),
                                (1.05, dead), (1.2, dict(dead, pel=(0, -0.1, -0.47))), (1.5, dead)]))
    # Fusion transform: a held crouch that bursts upright, arms flung, sword high
    fu0 = {"pel": (0, -0.03, -0.26), "prt": (0.42, 0, 0), "tor": (0.55, 0, 0), "hed": (0.5, 0, 0), "G": (0.34, 0.22, 0.56), "BE": be(-10, -30, UP), "LP": (-0.26, 0.2, 0.58), "fing": 1, "lid": 0.9, "brow": 1}
    fu1 = {"pel": (0, 0, 0.0), "prt": (-0.14, 0, 0), "tor": (-0.3, 0, 0), "hed": (-0.42, 0, 0), "G": (0.34, 0.1, 1.45), "BE": be(0, 88, (0, 1, 0)), "LP": (-0.52, 0.06, 1.2), "lid": 0.0, "fing": 0.0}
    out.append(C("fusion", 0.8, [(0.0, READY_END), (0.18, fu0), (0.3, dict(fu0, pel=(0.006, -0.03, -0.28))), (0.45, fu1, "out"), (0.58, dict(fu1, pel=(0, 0, -0.01))), (0.8, READY_END)]))
    # the emote: drives the blade into the ground, rests both hands on the pommel and stares
    em0 = {"pel": (0, -0.02, -0.05), "prt": (0.03, 0, 0), "tor": (0.08, 0, 0), "hed": (-0.08, 0, 0), "G": (0.04, 0.34, 0.92), "BE": be(0, -86, (0, 0.8, 0.2)), "Lw": 1.0, "FL": (-0.2, 0.06, A_Z), "FR": (0.2, 0.0, A_Z), "FLy": 0.2, "FRy": -0.25, "fing": 0.9, "brow": 0.9, "lid": 0.35}
    up = dict(em0)
    up.update({"G": (0.1, 0.34, 1.34), "BE": be(0, -70, (0, 0.8, 0.2)), "Lw": 1.0})
    out.append(C("emote", 3.0, [(0.0, READY_END), (0.35, up), (0.52, em0, "out"), (0.62, dict(em0, skirt=0.3, pel=(0, -0.02, -0.08)), "out"), (0.9, em0), (2.4, dict(em0, hed=(-0.2, 0.25, 0))), (3.0, READY_END)]))
    return out


def extras(P):
    if not P:
        return {}
    out = {}
    b = P.get("brow", 0.0)
    l = P.get("lid", 0.3)
    for s, side in ((1.0, "R"), (-1.0, "L")):
        # brow: + scowls (down and in, inner end low), - lifts (hurt)
        rot = Quaternion((0, 1, 0), -s * 0.22 * b)
        out["brow." + side] = (rot, Vector((0, 0.004 * b * 0 - 0.0065 * b, 0)))
        # (a bone's Y is its tail: +Y here is forward; the local X/Z are read off the armature in Solver below)
        out["lid." + side] = (Quaternion((1, 0, 0), 0.75 * (l - 0.3)), None)
    f = P.get("fing", 0.1)
    w = P.get("Lw", 0.0)
    f = max(f, w)
    out["fingers.L"] = (Quaternion((1, 0, 0), -0.9 * f), None)
    out["thumb.L"] = (Quaternion((1, 0, 0), -0.4 * f), None)
    out["skirt"] = (Quaternion((1, 0, 0), 0.35 * P.get("skirt", 0.0)), None)
    k = 1.0 + BREATH * P.get("breath", 0.0)
    out["x_breath"] = (None, None, Vector((k, k, k)))
    return out


def add_breath_bone(arm):
    """x_breath: the leaf under hips the idle breathes on. Here only a carrier for its scale keys (no deform); the v2 model
    gets its own, skinned to the rib cage, from kael_retarget.py."""
    if "x_breath" in arm.data.bones:
        return
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones.new("x_breath")
    hips = arm.data.edit_bones["hips"]
    eb.head = hips.head + Vector((0, -0.08, 0.36))
    eb.tail = eb.head + Vector((0, 0, 0.05))
    eb.parent, eb.use_connect, eb.use_deform = hips, False, False
    bpy.ops.object.mode_set(mode="OBJECT")


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    add_breath_bone(arm)
    b_, e_, n_ = sword_frame()
    rig = {"grip_rest": tuple(GRIP_AT), "blade_rest": tuple(b_), "edge_rest": tuple(e_), "pelvis": NECK_Z - 0.46, "hilt_l": 0.078, "dz": SHOULDER_Z - 1.151, "leg_k": 1.3, "ankle_keys": ANKLE_Z, "ankle": ANKLE_Z,
           "lhand": {"k": (0, 1, -0.15), "o": (-1, 0, 0), "palm": (-SH + 0.006, 0.0, HAND_Z - 0.052)}}
    bpy.context.scene.render.fps = FPS
    sol = Solver(arm, rig)
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
        if o.type in ("ARMATURE", "MESH", "EMPTY") and o.name not in ("Src", "Low", "Skirt"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))

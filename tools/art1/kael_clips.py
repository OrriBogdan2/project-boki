"""ART-1 Kael's animation set (hand-keyed as targets, solved by posekit). Times match the kit: the kmove tables in
scripts/match/kmoves_dj.gd and content/archetypes/juggernaut.json. Personality: enormous, grim, economical: he never
hurries his upper body, the sword's weight drags everything after it, every stop lands heavy.
Run: blender -b --python tools/art1/kael_clips.py -- <kael.blend> <out.glb>"""
import sys, os, math
import bpy
import numpy as np
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, bake, ang_dir as D, at, eul, FPS, frame_of
import kael_pieces as K

UP = (0, 0, 1)
A_Z = K.ANKLE_Z


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


# ---- idle and the signature stance
def idle(u):
    a = math.sin(u * 2 * math.pi)
    b = math.cos(u * 2 * math.pi)
    p = dict(READY)
    p["pel"] = (0.015 + 0.006 * b, -0.015, -0.065 - 0.009 * a)
    p["tor"] = (0.15 + 0.025 * a, 0.12, 0.03)            # the slow heave of the chest
    p["hed"] = (-0.16 - 0.02 * a, -0.14 + 0.03 * math.sin(u * 4 * math.pi), 0.0)
    g = READY["G"]
    p["G"] = (g[0], g[1], g[2] - 0.006 * a)
    p["LP"] = (-0.315 + 0.004 * a, 0.10, 0.63 - 0.008 * a)
    p["lid"] = 1.0 if 0.40 < u < 0.43 else 0.32           # one slow blink
    return p


def stance(u):
    """The sword laid back over his right shoulder, the left fist loose, chin down, staring you out."""
    a = math.sin(u * 2 * math.pi)
    p = dict(READY)
    p.update(SHOULDER)
    p["pel"] = (0.02, 0.0, -0.05 - 0.008 * a)
    p["prt"] = (0.06, 0.26, -0.05)
    p["tor"] = (0.12 + 0.02 * a, -0.22, 0.05)
    p["hed"] = (0.05, -0.04, -0.05)
    p["FL"], p["FR"] = (-0.17, 0.17, A_Z), (0.19, -0.11, A_Z)
    p["FLy"], p["FRy"] = 0.3, -0.5
    p["G"] = (0.30, 0.13 + 0.004 * a, 1.20 - 0.006 * a)
    p["LP"] = (-0.33, 0.12, 0.66 - 0.008 * a)
    p["fing"] = 0.5
    p["brow"], p["lid"] = 1.0, 0.42
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
    out.append(FnClip("idle", 3.2, idle))
    out.append(FnClip("stance", 4.0, stance))
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
    return out


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    b_, e_, n_ = K.sword_frame()
    rig = {"grip_rest": tuple(K.GRIP_AT), "blade_rest": tuple(b_), "edge_rest": tuple(e_), "pelvis": K.NECK_Z - 0.46, "hilt_l": 0.078, "dz": K.SHOULDER_Z - 1.151, "leg_k": 1.3, "ankle_keys": K.ANKLE_Z, "ankle": K.ANKLE_Z,
           "lhand": {"k": (0, 1, -0.15), "o": (-1, 0, 0), "palm": (-K.SH + 0.006, 0.0, K.HAND_Z - 0.052)}}
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

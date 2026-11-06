"""ART-1 crouch set (item 143): what every Hero's crouch shares, in the keys posekit solves. A Hero's clips file gives its hold pose and its own upper body; this
gives the sneak's feet and hips, and the dip into and out of the crouch. Weight on the balls of the feet: the heels lift ("toe" rad) and the ankle rises with them.
clips(): crouch_idle, crouch_f/b/l/r (FnClip loops), crouch_in, crouch_out (the 0.1 s dip, then the settle)."""
import math
from mathutils import Vector
from posekit import Clip, FnClip, lerp

TAU = 2 * math.pi


def off(p, **d):
    """p with these vector keys moved by the given amounts."""
    o = dict(p)
    for k, v in d.items():
        o[k] = tuple(a + b for a, b in zip(o[k], v))
    return o


def on_toes(z, ankle, foot, pit):
    """Ankle height with the heel lifted pit rad off a ball of the foot `foot` m ahead of it."""
    return z + foot * math.sin(max(pit, 0.0))


def sneak(hold, heading, cfg, upper):
    """One cycle of the sneak along heading (deg, + left of facing). cfg: ankle, foot (ankle to ball, m), width, stride (a step's reach, m), lift, toe (the planted heel's
    lift), swing (how much the foot trails as it leaves the ground, 1 by default), share (of the cycle a foot stays down), sway (m the hips swing over the planted foot), bob (m), twist (rad of hips against shoulders).
    upper(p, u, c1, s2, d) sets the Hero's own hands, head and face on p; d is the heading's unit vector."""
    h = math.radians(heading)
    d = Vector((-math.sin(h), math.cos(h), 0))
    fwd, back, lat = max(0.0, d.y), max(0.0, -d.y), d.x
    stride = cfg["stride"] * (1.0 if fwd > 0.5 else 0.75)
    share = cfg["share"]
    A = cfg["ankle"]

    def foot(ph, sx):
        ph %= 1.0
        base = Vector((sx * cfg["width"], cfg.get("y", 0.0), A))
        if ph < share:                      # planted: rolls from the ball back under the hip, the heel coming up as it trails
            k = ph / share
            s = 1 - 2 * k
            pit = cfg["toe"] + 0.55 * max(0.0, k - 0.55) / 0.45 * fwd
            return base + d * s * stride + Vector((0, 0, cfg["foot"] * math.sin(pit))), pit
        k = (ph - share) / (1 - share)      # the swing: low, the toe reaching for the next quiet step
        sm = k * k * (3 - 2 * k)
        s = -1 + 2 * sm
        z = cfg["lift"] * math.sin(k * math.pi)
        pit = cfg["toe"] + cfg.get("swing", 1.0) * ((0.55 * fwd + 0.3) * (1 - k) * (1 - k) + 0.15 * math.sin(k * math.pi))
        return base + d * s * stride + Vector((0, 0, z + cfg["foot"] * math.sin(pit))), pit

    def fn(u):
        p = dict(hold)
        rp, pr = foot(u, 1.0)
        lp, pl = foot(u + 0.5, -1.0)
        p["FR"], p["FL"], p["FRp"], p["FLp"] = tuple(rp), tuple(lp), pr, pl
        hy = h * 0.45
        p["FRy"], p["FLy"] = cfg.get("toe_out", -0.25) + hy, -cfg.get("toe_out", -0.25) + hy
        c1 = math.cos(u * TAU)              # +1: the right foot just landed ahead
        s2 = math.cos(u * 2 * TAU - 0.5)    # one rise per step, lowest as the weight lands
        g = hold["pel"]
        p["pel"] = (g[0] * fwd + cfg["sway"] * c1 + 0.04 * lat, g[1] * fwd + 0.05 * back * -1 + 0.01 * s2, g[2] - cfg["bob"] * s2)
        pr0, tr0 = hold["prt"], hold["tor"]
        tw = cfg["twist"]
        lean = fwd + 0.55 * (1 - fwd)        # backing off and strafing stay low but sit up a little
        p["prt"] = (pr0[0] * lean, pr0[1] * fwd + tw * c1, pr0[2] * fwd + 0.05 * c1 - 0.14 * lat)
        p["tor"] = (tr0[0] * lean + 0.012 * s2, tr0[1] * fwd - tw * 1.5 * c1, tr0[2] * fwd - 0.03 * c1 - 0.06 * lat)
        upper(p, u, c1, s2, d)
        return p
    return fn


def clips(C, ready, hold, idle, cfg, upper, dip, up=None, idle_t=3.6, dip_t=0.15):
    """C(name, dur, keys): the Hero's Clip maker. ready: its standing pose. hold: the crouch. idle(u): the crouch's loop. dip: hold, dip_t s in, lower and over-leaned.
    up: the standing pose just past straight, the last beat of the way out."""
    T = cfg["T"]
    out = [FnClip("crouch_idle", idle_t, idle)]
    for tag, hd in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
        out.append(FnClip("crouch_" + tag, T if tag == "f" else T * cfg.get("T_side", 1.0), sneak(hold, hd, cfg, upper)))
    first = idle(0.0)
    out.append(C("crouch_in", dip_t + 0.19, [(0.0, ready), (dip_t, dip), (dip_t + 0.19, first)]))
    out.append(C("crouch_out", 0.36, [(0.0, first), (0.08, dip), (0.24, up or ready), (0.36, ready)]))
    return out


def quick(C, ready, hold, cfg, hands=("G", "LP"), up=None, scan=0.3, dip_t=0.18, bounce=0.0, idle_t=3.6):
    """clips() from a hold pose alone: a breath, the head scanning scan rad either way, the hands riding the steps; a Hero's own look is its hold and cfg.
    hands: the keys of the hand targets. bounce: m of a coil's spring in the idle, twice a loop."""
    h0, g0, t0 = hold["hed"], hold["pel"], hold["tor"]

    def idle(u):
        a, b = math.sin(u * TAU), math.cos(u * TAU)
        p = dict(hold)
        p["pel"] = (g0[0] + 0.006 * a, g0[1], g0[2] - 0.006 * (b - 1) - bounce * (1 - math.cos(u * 2 * TAU)) / 2)
        p["tor"] = (t0[0] + 0.012 * (b - 1), t0[1], t0[2])
        p["hed"] = (h0[0], h0[1] + scan * a, h0[2] - 0.05 * a)
        for k in hands:
            v = hold[k]
            p[k] = (v[0], v[1], v[2] + 0.005 * (b - 1))
        return p

    def upper(p, u, c1, s2, d):
        k = max(d.y, 0.6)
        for key in hands:
            v = hold[key]
            p[key] = (v[0] + 0.02 * d.x, v[1] * k + 0.012 * c1, v[2] + 0.007 * s2)
        p["hed"] = (h0[0] * (0.6 + 0.4 * max(d.y, 0.0)), h0[1] - 0.05 * c1, h0[2])

    dip = off(hold, pel=(0.0, 0.0, -cfg.get("dip", 0.05)), prt=(0.08, 0, 0), hed=(-0.06, 0, 0), **{k: (0.0, -0.06, -0.04) for k in hands})
    return clips(C, ready, hold, idle, cfg, upper, dip, up=up, idle_t=idle_t, dip_t=dip_t)

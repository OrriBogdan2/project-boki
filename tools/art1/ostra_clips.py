"""Ostra's hand-keyed clips: the table ostra_anim.py samples. Key = (t, {channels}, easing into it). ostra_pose.NEUTRAL lists the channels.
The action clips run on the kit's clock: lengths and beats are those of the moves in scripts/match/kmoves_stone.gd (the hit frame of a Snap
is its t = 0; an orb leaves at t = 0, a Trade's lantern at 0.14, the Well commits at 0.25). The Rig keeps the lift, squash and spins those moves
key, so here the body only answers them: the root bone isn't keyed."""
import math

TAU = 2 * math.pi

# his two signature holds
ORB_UP = {"hR": (0.31, 0.20, 1.05), "fR": (0.05, 0.75, 0.65), "pR": (-0.25, -0.45, 0.85), "eR": (1.0, -0.7, -0.6), "cR": 0.3, "sR": 1.0}
OFF_LOW = {"hL": (-0.31, 0.12, 0.88), "fL": (-0.45, 0.35, -0.8), "pL": (0.3, 0.85, 0.2), "eL": (-1.0, -0.5, 0.0), "cL": 0.35, "sL": 1.0}
STILL = dict(ORB_UP, **OFF_LOW, spine=(14.0, -6.0, 3.0), head=(-8.0, 6.0, 13.0), brow=-0.8, cheek=0.3, lid=0.3, jaw=0.0)

# claws out in front, both hands on the strings
READY = {"hR": (0.27, 0.32, 1.12), "fR": (0.1, 0.8, 0.5), "pR": (-0.3, -0.35, 0.85), "cR": 0.45, "sR": 1.0, "hL": (-0.24, 0.32, 1.0),
         "fL": (-0.2, 0.85, 0.3), "pL": (0.5, -0.2, -0.8), "cL": 0.55, "sL": 1.0, "eL": (-1.0, -0.7, -0.5),
         "spine": (22.0, -8.0, 0.0), "head": (-18.0, 8.0, 8.0), "brow": -1.0, "cheek": 0.6, "lid": 0.6, "lift": (0.0, 0.0, -0.02)}

# the arms flung wide and high, a showman
SPREAD = {"hR": (0.42, 0.06, 1.46), "fR": (0.45, 0.15, 0.85), "pR": (-0.2, 0.9, 0.2), "eR": (1.0, -0.4, -0.5), "cR": 0.1, "sR": 1.0,
          "hL": (-0.42, 0.06, 1.46), "fL": (-0.45, 0.15, 0.85), "pL": (0.2, 0.9, 0.2), "eL": (-1.0, -0.4, -0.5), "cL": 0.1, "sL": 1.0,
          "spine": (-8.0, 0.0, 0.0), "head": (-16.0, 0.0, 0.0), "jaw": 16.0, "cheek": 1.0, "brow": 0.3, "lid": 0.0, "pld": (22.0, 22.0)}

# fists hauled in to the chest
CLENCH = {"hR": (0.09, 0.2, 1.17), "fR": (-0.5, 0.5, 0.5), "pR": (-0.7, -0.5, -0.3), "cR": 1.0, "sR": 0.0, "hL": (-0.09, 0.2, 1.17), "fL": (0.5, 0.5, 0.5),
          "pL": (0.7, -0.5, -0.3), "cL": 1.0, "sL": 0.0, "eR": (1.0, -0.3, -0.8), "eL": (-1.0, -0.3, -0.8), "spine": (24.0, 0.0, 0.0), "head": (10.0, 0.0, 0.0),
          "brow": -1.0, "cheek": 0.2, "lid": 1.0, "jaw": 0.0, "skirt": (-8.0, 0.0), "pld": (-12.0, -12.0)}

# hands hanging, nothing holding him: the strings cut
LIMP = {"hR": (0.2, 0.07, 0.82), "hL": (-0.2, 0.07, 0.82), "fR": (0.05, 0.1, -1.0), "fL": (-0.05, 0.1, -1.0), "pR": (-1.0, 0.0, 0.0), "pL": (1.0, 0.0, 0.0),
        "cR": 0.3, "cL": 0.3, "sR": 0.2, "sL": 0.2, "eR": (1.0, -0.5, 0.0), "eL": (-1.0, -0.5, 0.0)}


def breath(P, t, period, amp=0.75):
    s = P["spine"]
    P["spine"] = (s[0] + amp * math.sin(t / period * TAU), s[1], s[2])


def idle_add(P, t):
    breath(P, t, 3.2)
    P["wR"] = 0.13
    P["wL"] = 0.2


def stance_add(P, t):
    breath(P, t, 2.0, 0.8)
    P["wR"] = 0.2
    P["wL"] = 0.26


def laugh(a, rate=11.0, t0=0.0, t1=99.0):
    """the jaw chattering: a silent cackle"""
    def fn(P, t):
        if t0 <= t <= t1:
            P["jaw"] = P["jaw"] + a * (0.5 + 0.5 * math.sin((t - t0) * rate * TAU / 3.0))
    return fn


def drift(period, pitch, sway=0.0, bob=0.012, wave=0.1):
    """the slow rock and bob of a body hung on strings, as it travels"""
    def fn(P, t):
        ph = t / period * TAU
        s = P["spine"]
        P["spine"] = (s[0] + pitch * math.sin(ph * 2), s[1] + sway * math.sin(ph), s[2] + sway * 0.6 * math.cos(ph))
        l = P["lift"]
        P["lift"] = (l[0], l[1], l[2] + bob * math.sin(ph * 2))
        hd = P["head"]
        P["head"] = (hd[0] - pitch * 0.7 * math.sin(ph * 2), hd[1] - sway * 0.6 * math.sin(ph), hd[2])
        sk = P["skirt"]
        P["skirt"] = (sk[0] + 3.0 * math.sin(ph * 2 + 1.0), sk[1] + 5.0 * math.sin(ph + 0.6))
        P["wR"] = wave
        P["wL"] = wave
    return fn


def run_arms(P, t, period, amp):
    ph = t / period * TAU
    for c, s in (("hR", 1), ("hL", -1)):
        x, y, z = P[c]
        P[c] = (x, y + s * amp * math.sin(ph), z + amp * 0.3 * math.cos(ph * 2))


def run_add(period, pitch, sway, amp):
    d = drift(period, pitch, sway, 0.016, 0.18)
    def fn(P, t):
        d(P, t)
        run_arms(P, t, period, amp)
    return fn


def walk_base(sp, hd, skirt, **kw):
    b = dict(STILL, spine=sp, head=hd, skirt=skirt, brow=-0.7, cheek=0.35, lid=0.25)
    b.update(kw)
    return b


def run_base(sp, hd, skirt, **kw):
    # arms thrown out behind him, the fingers trailing, the orb kept high in his right
    b = dict(STILL, spine=sp, head=hd, skirt=skirt, brow=-1.0, cheek=0.7, lid=0.45,
             hR=(0.36, -0.10, 1.04), fR=(0.25, -0.5, 0.8), pR=(-0.2, 0.55, 0.8), eR=(1.0, -0.2, -0.6), cR=0.4,
             hL=(-0.34, -0.22, 0.98), fL=(-0.25, -0.75, -0.5), pL=(0.2, -0.5, 0.8), eL=(-1.0, 0.1, -0.5), cL=0.2)
    b.update(kw)
    return b


def twitch(amp, rate):
    """a body shaken"""
    def fn(P, t):
        s = P["spine"]
        P["spine"] = (s[0] + amp * math.sin(t * rate), s[1] + amp * 1.3 * math.sin(t * rate * 1.37), s[2] + amp * math.cos(t * rate * 0.83))
        h = P["head"]
        P["head"] = (h[0], h[1] + amp * 1.5 * math.sin(t * rate * 1.13), h[2] + amp * 1.5 * math.cos(t * rate * 1.7))
    return fn


AIM_LOW = {"hR": (0.30, -0.24, 0.92), "fR": (0.2, -0.75, -0.55), "pR": (-0.1, -0.6, 0.8), "eR": (1.0, -0.4, 0.4), "cR": 0.55, "sR": 0.8,
           "hL": (-0.27, 0.27, 1.12), "fL": (-0.1, 0.9, 0.35), "pL": (0.4, -0.2, -0.85), "cL": 0.45, "sL": 1.0, "eL": (-1.0, -0.6, -0.4),
           "spine": (6.0, 20.0, 4.0), "head": (-2.0, -14.0, 6.0), "brow": -0.9, "cheek": 0.8, "lid": 0.5}

WIND = {"hR": (0.13, 0.24, 1.26), "fR": (-0.45, 0.55, 0.65), "pR": (-0.8, -0.3, -0.5), "cR": 0.65, "sR": 0.8, "hL": (-0.13, 0.24, 1.2), "fL": (0.45, 0.55, 0.7),
        "pL": (0.8, -0.3, -0.45), "cL": 0.65, "sL": 0.8, "eR": (1.0, -0.8, -0.2), "eL": (-1.0, -0.8, -0.2),
        "spine": (-20.0, 32.0, 0.0), "head": (10.0, -22.0, 6.0), "brow": -1.0, "cheek": 0.9, "lid": 0.9, "orb": 1.35, "orbp": (0.04, 0.0, 0.0), "pld": (10.0, 10.0)}

SHOVE = {"hR": (0.09, 0.44, 1.28), "fR": (0.0, 0.5, 0.85), "pR": (0.0, 1.0, -0.4), "eR": (1.0, -0.4, -0.7), "cR": 0.05, "sR": 1.0, "hL": (-0.09, 0.44, 1.24),
         "fL": (0.0, 0.5, 0.85), "pL": (0.0, 1.0, -0.4), "eL": (-1.0, -0.4, -0.7), "cL": 0.05, "sL": 1.0, "spine": (34.0, -22.0, 0.0), "head": (-20.0, 16.0, 0.0),
         "brow": -1.0, "cheek": 1.0, "lid": 0.6, "jaw": 7.0, "orb": 0.0, "skirt": (22.0, 0.0), "pld": (-10.0, -10.0)}

CLIPS = {
    # ---------------------------------------------------------------- loco
    "idle": {"len": 3.2, "step": 3, "base": STILL, "add": idle_add, "loop": True, "keys": [
        (0.0, {}),
        (1.3, {}),
        # the puppet's tick: the head yanked over to the other side, held, snapped back
        (1.42, {"head": (-8.0, -10.0, -9.0), "brow": -0.5, "cheek": 0.7}, "snap"),
        (2.3, {"head": (-6.0, -8.0, -10.0)}),
        (2.42, {"head": (-8.0, 6.0, 13.0), "brow": -0.8, "cheek": 0.3}, "snap"),
        (3.2, {}),
    ]},
    "stance": {"len": 2.0, "step": 3, "base": READY, "add": stance_add, "loop": True, "keys": [(0.0, {}), (2.0, {})]},
    "walk_f": {"len": 1.5, "step": 3, "loop": True, "base": walk_base((22.0, -6.0, 2.0), (-14.0, 4.0, 8.0), (10.0, 0.0)), "add": drift(1.5, 2.0, 4.0), "keys": [(0.0, {}), (1.5, {})]},
    "walk_b": {"len": 1.5, "step": 3, "loop": True, "base": walk_base((-6.0, -4.0, 0.0), (6.0, 2.0, 10.0), (-10.0, 0.0)), "add": drift(1.5, 2.0, 3.0), "keys": [(0.0, {}), (1.5, {})]},
    "walk_l": {"len": 1.5, "step": 3, "loop": True, "base": walk_base((12.0, 10.0, -13.0), (-8.0, -10.0, 16.0), (2.0, 12.0)), "add": drift(1.5, 2.0, 2.0), "keys": [(0.0, {}), (1.5, {})]},
    "walk_r": {"len": 1.5, "step": 3, "loop": True, "base": walk_base((12.0, -16.0, 13.0), (-8.0, 12.0, -2.0), (2.0, -12.0)), "add": drift(1.5, 2.0, 2.0), "keys": [(0.0, {}), (1.5, {})]},
    "run_f": {"len": 0.96, "step": 2, "loop": True, "base": run_base((38.0, 0.0, 0.0), (-34.0, 0.0, 6.0), (30.0, 0.0)), "add": run_add(0.96, 3.0, 6.0, 0.05), "keys": [(0.0, {}), (0.96, {})]},
    "run_b": {"len": 0.96, "step": 2, "loop": True, "base": run_base((-16.0, 0.0, 0.0), (10.0, 0.0, 6.0), (-22.0, 0.0), hR=(0.33, 0.24, 1.08), fR=(0.15, 0.7, 0.7), pR=(-0.3, -0.5, 0.8),
                                                                    hL=(-0.33, 0.2, 1.0), fL=(-0.3, 0.8, 0.3), pL=(0.4, -0.3, -0.85)), "add": run_add(0.96, 3.0, 5.0, 0.03), "keys": [(0.0, {}), (0.96, {})]},
    "run_l": {"len": 0.96, "step": 2, "loop": True, "base": run_base((16.0, 8.0, -26.0), (-16.0, -8.0, 22.0), (4.0, 22.0)), "add": run_add(0.96, 3.0, 3.0, 0.03), "keys": [(0.0, {}), (0.96, {})]},
    "run_r": {"len": 0.96, "step": 2, "loop": True, "base": run_base((16.0, -8.0, 26.0), (-16.0, 8.0, -18.0), (4.0, -22.0)), "add": run_add(0.96, 3.0, 3.0, 0.03), "keys": [(0.0, {}), (0.96, {})]},

    # ---------------------------------------------------------------- LMB: Tether Lantern
    # an orb: a flick from the shoulder (it leaves on the frame the kit fires, the move starts with the shot)
    "orb": {"len": 0.30, "step": 1, "base": STILL, "keys": [
        (0.00, {}),
        (0.035, {"hR": (0.31, 0.02, 1.24), "fR": (0.2, 0.4, 0.9), "pR": (-0.1, 0.8, -0.3), "spine": (10.0, 10.0, 3.0), "orb": 1.2}, "out"),
        (0.09, {"hR": (0.14, 0.42, 1.22), "fR": (-0.1, 0.95, 0.1), "pR": (0.0, 0.2, -1.0), "eR": (1.0, -0.5, -0.5), "cR": 0.12, "sR": 1.0, "spine": (18.0, -20.0, 3.0), "head": (-14.0, 14.0, 10.0),
                 "orb": 0.25, "cheek": 0.7, "brow": -1.0}, "snap"),
        (0.16, {"orb": 0.55, "cR": 0.3}),
        (0.30, dict(STILL, orb=1.0)),
    ]},
    # the Settled bolt: drawn right back, flung out straight, the body kicked back by it
    "orb_hot": {"len": 0.50, "step": 1, "base": STILL, "keys": [
        (0.00, {}),
        (0.06, {"hR": (0.36, -0.14, 1.22), "fR": (0.25, -0.5, 0.8), "pR": (-0.1, 0.8, 0.5), "eR": (1.0, -0.2, -0.8), "spine": (4.0, 26.0, 3.0), "head": (0.0, -18.0, 8.0), "orb": 1.5, "lid": 1.0, "cheek": 0.9, "brow": -1.0}, "out"),
        (0.11, {"hR": (0.08, 0.45, 1.26), "fR": (0.0, 1.0, 0.1), "pR": (0.0, 0.1, -1.0), "cR": 0.02, "sR": 1.0, "eR": (1.0, -0.4, -0.6), "spine": (26.0, -30.0, 0.0), "head": (-22.0, 24.0, 4.0),
                 "hL": (-0.3, -0.1, 0.98), "orb": 0.0, "jaw": 8.0, "skirt": (16.0, 0.0)}, "snap"),
        (0.22, {"spine": (2.0, -24.0, 0.0), "hR": (0.14, 0.40, 1.34), "fR": (0.1, 0.5, 0.85), "cR": 0.2, "head": (-6.0, 20.0, 6.0), "jaw": 10.0, "skirt": (-6.0, 0.0)}),
        (0.50, dict(STILL, orb=1.0, jaw=0.0, skirt=(0.0, 0.0))),
    ]},
    # ---------------------------------------------------------------- RMB: Shard Snap
    "snap_wind": {"len": 0.70, "step": 1, "base": STILL, "add": lambda P, t: t > 0.3 and twitch(0.5, 44.0)(P, t), "keys": [
        (0.00, {}),
        (0.12, dict(WIND, spine=(4.0, 12.0, 0.0), head=(0.0, -8.0, 8.0), hR=(0.13, 0.25, 1.14), hL=(-0.13, 0.25, 1.1), orb=1.1)),
        (0.30, WIND),
        (0.70, WIND),
    ]},
    "snap": {"len": 0.50, "step": 1, "base": WIND, "keys": [
        (0.00, {}),
        (0.05, SHOVE, "snap"),
        (0.16, {"spine": (-14.0, -14.0, 0.0), "hR": (0.2, 0.32, 1.32), "hL": (-0.28, 0.2, 1.12), "fL": (-0.3, 0.7, 0.3), "cR": 0.35, "cL": 0.4, "head": (2.0, 10.0, 6.0), "skirt": (-14.0, 0.0), "orb": 0.3}),
        (0.50, dict(STILL, orb=1.0, jaw=0.0, skirt=(0.0, 0.0), pld=(0.0, 0.0))),
    ]},
    # ---------------------------------------------------------------- Shift: Lantern Trade
    "swap_aim": {"len": 0.66, "step": 2, "base": STILL, "add": lambda P, t: t > 0.16 and twitch(0.35, 30.0)(P, t), "keys": [
        (0.00, {}),
        (0.16, AIM_LOW),
        (0.66, AIM_LOW),
    ]},
    # the lob: low behind (0.06), swept up and over (0.14, it leaves), floats on the follow-through; a showman's flourish, not a throw
    "swap": {"len": 0.85, "step": 2, "base": AIM_LOW, "keys": [
        (0.00, {}),
        (0.06, {"hR": (0.28, -0.32, 0.86), "spine": (-2.0, 24.0, 4.0), "orb": 1.2}),
        (0.14, {"hR": (0.14, 0.26, 1.60), "fR": (0.0, 0.5, 0.85), "pR": (0.0, 0.9, -0.4), "eR": (1.0, -0.2, -0.3), "cR": 0.05, "sR": 1.0, "hL": (-0.34, -0.05, 0.98), "fL": (-0.4, -0.3, -0.8), "pL": (0.5, 0.3, -0.3),
                 "spine": (-12.0, -12.0, -5.0), "head": (-22.0, 8.0, -4.0), "orb": 0.0, "jaw": 12.0, "cheek": 1.0, "skirt": (-10.0, 0.0)}, "out"),
        (0.40, {"hR": (0.2, 0.22, 1.46), "fR": (0.3, 0.5, 0.8), "cR": 0.2, "head": (-16.0, 8.0, 6.0), "jaw": 5.0, "orb": 0.0}),
        (0.60, {"orb": 0.5}),
        (0.85, dict(STILL, orb=1.0, jaw=0.0, skirt=(0.0, 0.0))),
    ]},
    # the same lob from the air, then drifting after his lantern, marionette-limp, swaying (loops from 0.45)
    "swap_air": {"len": 1.25, "step": 2, "base": STILL, "keys": [
        (0.00, {}),
        (0.08, {"hR": (-0.14, 0.26, 0.98), "fR": (-0.6, 0.2, -0.75), "pR": (0.3, 0.8, 0.3), "eR": (1.0, -0.4, 0.4), "spine": (12.0, -24.0, 0.0), "head": (-6.0, 18.0, 4.0), "orb": 1.15}),
        (0.18, {"hR": (0.2, 0.22, 1.6), "fR": (0.1, 0.5, 0.85), "pR": (0.0, 0.9, -0.4), "cR": 0.05, "sR": 1.0, "hL": (-0.4, -0.1, 1.0), "fL": (-0.5, -0.3, -0.7), "pL": (0.3, 0.5, 0.7),
                 "spine": (-8.0, 12.0, 0.0), "head": (-20.0, 0.0, 0.0), "orb": 0.0, "jaw": 12.0, "cheek": 1.0}, "out"),
        (0.45, {"hR": (0.34, -0.2, 0.92), "fR": (0.3, -0.75, -0.55), "pR": (-0.1, -0.6, 0.8), "hL": (-0.34, -0.2, 0.92), "fL": (-0.3, -0.75, -0.55), "pL": (0.1, -0.6, 0.8), "cR": 0.2, "cL": 0.2, "sR": 0.6, "sL": 0.6,
                 "spine": (28.0, 4.0, 5.0), "head": (-26.0, 0.0, -6.0), "jaw": 0.0, "cheek": 0.8, "skirt": (24.0, 4.0)}),
        (0.85, {"spine": (26.0, -4.0, -5.0), "head": (-24.0, 0.0, 6.0), "skirt": (24.0, -4.0), "hR": (0.3, -0.24, 0.98), "hL": (-0.36, -0.18, 0.9)}),
        (1.25, {"spine": (28.0, 4.0, 5.0), "head": (-26.0, 0.0, -6.0), "skirt": (24.0, 4.0), "hR": (0.34, -0.2, 0.92), "hL": (-0.34, -0.2, 0.92)}),
    ]},
    # arriving: he pops in tall with his arms up, slams wide, overshoots, and takes a little bow of it
    "arrive": {"len": 0.60, "step": 1, "base": dict(SPREAD, hR=(0.12, 0.06, 1.68), hL=(-0.12, 0.06, 1.68), fR=(0.0, 0.1, 1.0), fL=(0.0, 0.1, 1.0), orb=0.0), "add": laugh(9.0, 12.0, 0.1, 0.5), "keys": [
        (0.00, {}),
        (0.08, {"hR": (0.44, 0.08, 1.14), "hL": (-0.44, 0.08, 1.14), "fR": (0.8, 0.1, -0.2), "fL": (-0.8, 0.1, -0.2), "pR": (0.0, 0.9, -0.4), "pL": (0.0, 0.9, -0.4), "eR": (1.0, -0.5, 0.2), "eL": (-1.0, -0.5, 0.2),
                 "spine": (22.0, 0.0, 0.0), "head": (-22.0, 0.0, 0.0), "skirt": (-16.0, 0.0), "pld": (-16.0, -16.0)}, "snap"),
        (0.15, {"hR": (0.42, 0.06, 1.3), "hL": (-0.42, 0.06, 1.3), "fR": (0.6, 0.1, 0.7), "fL": (-0.6, 0.1, 0.7), "spine": (-6.0, 0.0, 0.0), "head": (-14.0, 0.0, 8.0), "pld": (14.0, 14.0), "skirt": (6.0, 0.0)}),
        (0.30, {"hR": (0.38, 0.14, 1.14), "hL": (-0.38, 0.14, 1.06), "orb": 0.6, "spine": (10.0, -4.0, 2.0), "head": (-8.0, 4.0, 12.0), "pld": (0.0, 0.0), "skirt": (0.0, 0.0)}),
        (0.60, dict(STILL, orb=1.0, jaw=0.0, pld=(0.0, 0.0), skirt=(0.0, 0.0))),
    ]},
    # ---------------------------------------------------------------- E: Brimseed
    "seed": {"len": 0.80, "step": 2, "base": STILL, "keys": [
        (0.00, {}),
        (0.08, {"hR": (0.2, 0.2, 1.5), "fR": (0.0, 0.25, 1.0), "pR": (0.0, 0.9, -0.2), "eR": (1.0, -0.2, -0.5), "cR": 0.55, "spine": (2.0, -4.0, 2.0), "head": (-16.0, 6.0, -8.0), "orb": 0.7, "cheek": 0.9}, "out"),
        (0.20, {"hR": (0.14, 0.44, 1.06), "fR": (0.0, 0.75, -0.65), "pR": (0.0, -0.3, -0.95), "cR": 0.12, "sR": 1.0, "hL": (-0.3, -0.05, 1.04), "fL": (-0.5, -0.2, -0.8),
                 "spine": (32.0, -12.0, 0.0), "head": (-16.0, 8.0, 10.0), "orb": 0.0, "brow": -1.0, "lid": 0.7, "skirt": (12.0, 0.0)}, "snap"),
        (0.50, {"hR": (0.2, 0.36, 1.08), "cR": 0.3, "spine": (20.0, -8.0, 2.0), "orb": 0.3}),
        (0.80, dict(STILL, orb=1.0, skirt=(0.0, 0.0))),
    ]},
    # the pop: fists to the chest (the implosion), then flung wide, delighted
    "pop": {"len": 0.60, "step": 1, "base": STILL, "add": laugh(11.0, 12.0, 0.2, 0.55), "keys": [
        (0.00, {}),
        (0.08, CLENCH, "out"),
        (0.20, SPREAD, "snap"),
        (0.60, dict(STILL, pld=(0.0, 0.0), jaw=0.0, skirt=(0.0, 0.0), orb=1.0)),
    ]},
    # ---------------------------------------------------------------- X: Nightwell
    "well": {"len": 1.25, "step": 2, "base": STILL, "add": lambda P, t: t > 0.25 and (P.update(wR=0.3, wL=0.3) or laugh(7.0, 9.0, 0.25, 9.0)(P, t)), "keys": [
        (0.00, {}),
        (0.10, {"hR": (-0.1, 0.25, 0.92), "fR": (-0.5, 0.3, -0.8), "pR": (0.3, 0.9, 0.2), "hL": (0.1, 0.25, 0.92), "fL": (0.5, 0.3, -0.8), "pL": (-0.3, 0.9, 0.2), "eR": (1.0, -0.2, 0.3), "eL": (-1.0, -0.2, 0.3),
                 "spine": (24.0, 0.0, 0.0), "head": (14.0, 0.0, 0.0), "brow": -1.0, "lid": 1.0, "cheek": 0.5, "cR": 0.7, "cL": 0.7, "pld": (-12.0, -12.0), "skirt": (6.0, 0.0)}, "out"),
        (0.25, SPREAD, "snap"),
        (0.75, {"spine": (-11.0, 0.0, 2.0), "head": (-20.0, 0.0, 4.0), "cR": 0.2, "cL": 0.2}),
        (1.25, SPREAD),
    ]},
    "well_snap": {"len": 0.55, "step": 1, "base": SPREAD, "keys": [
        (0.00, {}),
        (0.08, dict(CLENCH, hR=(0.2, 0.34, 1.3), hL=(-0.2, 0.34, 1.3)), "snap"),
        (0.22, dict(CLENCH, hR=(0.14, 0.26, 1.2), hL=(-0.14, 0.26, 1.2), spine=(30.0, 0.0, 0.0))),
        (0.36, {"hR": (0.34, 0.1, 0.88), "hL": (-0.34, 0.1, 0.88), "fR": (0.5, 0.3, -0.8), "fL": (-0.5, 0.3, -0.8), "pR": (0.0, -0.9, 0.3), "pL": (0.0, -0.9, 0.3), "cR": 0.1, "cL": 0.1, "sR": 1.0, "sL": 1.0,
                 "spine": (-4.0, 0.0, 0.0), "head": (-12.0, 0.0, 6.0), "lid": 0.2, "jaw": 8.0, "pld": (6.0, 6.0)}, "out"),
        (0.55, dict(STILL, jaw=0.0, pld=(0.0, 0.0), skirt=(0.0, 0.0))),
    ]},
    "well_end": {"len": 0.35, "step": 1, "base": SPREAD, "keys": [
        (0.00, {}),
        (0.14, dict(LIMP, spine=(10.0, 0.0, 0.0), head=(6.0, 0.0, 10.0), jaw=0.0, pld=(0.0, 0.0), brow=-0.3)),
        (0.35, dict(STILL, jaw=0.0, pld=(0.0, 0.0))),
    ]},
    # Swollen: lifted, arms flung up, one full turn (the turn is the kit's), then down
    "empower": {"len": 0.90, "step": 2, "base": STILL, "add": laugh(12.0, 11.0, 0.3, 0.85), "keys": [
        (0.00, {}),
        (0.10, dict(CLENCH, spine=(14.0, 0.0, 0.0))),
        (0.30, dict(SPREAD, orb=1.6), "out"),
        (0.55, {"spine": (-12.0, 0.0, 0.0), "orb": 1.6}),
        (0.65, {"spine": (-4.0, 0.0, 0.0), "orb": 1.3}),
        (0.90, dict(STILL, jaw=0.0, pld=(0.0, 0.0), skirt=(0.0, 0.0), orb=1.0)),
    ]},
    # ---------------------------------------------------------------- the body's states
    "jump": {"len": 0.5, "step": 3, "base": STILL, "keys": [
        (0.0, {}),
        (0.12, {"spine": (-6.0, 0.0, 0.0), "hR": (0.33, 0.1, 1.3), "hL": (-0.34, 0.05, 1.2), "fL": (-0.4, 0.1, 0.9), "pL": (0.3, 0.8, -0.2), "skirt": (6.0, 0.0), "head": (-16.0, 0.0, 8.0), "cheek": 0.8}, "out"),
        (0.5, {"spine": (2.0, 0.0, 0.0), "hR": (0.33, 0.12, 1.24), "hL": (-0.36, 0.05, 1.12)}),
    ]},
    "fall": {"len": 0.8, "step": 3, "loop": True, "base": dict(STILL, spine=(4.0, 0.0, 0.0), hR=(0.36, 0.08, 1.36), hL=(-0.38, 0.05, 1.32), fL=(-0.5, 0.0, 0.85), pL=(0.2, 0.9, 0.3), fR=(0.3, 0.3, 0.9), pR=(-0.2, -0.3, 0.9),
                                                                eL=(-1.0, -0.2, -0.6), skirt=(-10.0, 0.0), head=(-4.0, 0.0, 10.0), pld=(12.0, 12.0), brow=0.2, cheek=0.7), "add": drift(0.8, 0.0, 3.0, 0.0, 0.2), "keys": [(0.0, {}), (0.8, {})]},
    # gliding: hung from his own strings, arms out, the head lolled and grinning
    "glide": {"len": 1.6, "step": 3, "loop": True, "base": dict(STILL, spine=(26.0, 0.0, 0.0), hR=(0.40, 0.0, 1.32), hL=(-0.40, 0.0, 1.32), fR=(0.7, 0.1, 0.6), fL=(-0.7, 0.1, 0.6), pR=(0.0, 0.5, -0.8), pL=(0.0, 0.5, -0.8),
                                                                  eR=(1.0, -0.2, 0.2), eL=(-1.0, -0.2, 0.2), cL=0.15, cR=0.15, sL=1.0, sR=1.0, head=(-26.0, 0.0, 10.0), skirt=(24.0, 0.0), cheek=0.8), "add": drift(1.6, 1.5, 7.0, 0.01, 0.16), "keys": [(0.0, {}), (1.6, {})]},
    # diving: head first, arms swept behind
    "dive": {"len": 0.8, "step": 3, "loop": True, "base": dict(run_base((58.0, 0.0, 0.0), (-44.0, 0.0, 0.0), (40.0, 0.0)), jaw=9.0), "add": drift(0.8, 2.0, 3.0, 0.0, 0.25), "keys": [(0.0, {}), (0.8, {})]},
    # stunned: yanked upright, jerking on his strings
    "stun": {"len": 1.0, "step": 2, "loop": True, "base": dict(LIMP, spine=(6.0, 0.0, 5.0), head=(18.0, 8.0, 24.0), brow=0.8, lid=0.0, jaw=8.0, cheek=0.0), "add": twitch(2.2, 37.7), "keys": [(0.0, {}), (1.0, {})]},
    # downed: the strings cut: sunk, head on his chest, the hands in the coat, a finger still twitching
    "downed": {"len": 3.0, "step": 4, "loop": True, "base": dict(LIMP, spine=(36.0, 0.0, 9.0), head=(40.0, 8.0, 18.0), hL=(-0.16, 0.22, 0.86), hR=(0.14, 0.16, 0.84), brow=0.4, cheek=0.0, jaw=11.0, lid=0.8, orb=0.45, lift=(0.0, 0.0, -0.2), skirt=(-10.0, 0.0)),
               "add": lambda P, t: P.update(wL=0.12 * max(0.0, math.sin(t / 3.0 * TAU * 2)), spine=(P["spine"][0] + 1.5 * math.sin(t / 3.0 * TAU), P["spine"][1], P["spine"][2])), "keys": [(0.0, {}), (3.0, {})]},
    # reviving a friend: one long hand out, the fingers playing the strings of a broken doll
    "revive": {"len": 2.0, "step": 3, "loop": True, "base": dict(STILL, spine=(34.0, 0.0, 0.0), head=(-8.0, 0.0, 14.0), hR=(0.2, 0.42, 0.98), fR=(0.1, 0.65, -0.75), pR=(0.0, -0.75, -0.65), hL=(-0.2, 0.42, 0.98), fL=(-0.1, 0.65, -0.75), pL=(0.0, -0.75, -0.65), cL=0.2, cR=0.2, sL=1.0, sR=1.0), "add": lambda P, t: P.update(wR=0.35, wL=0.35), "keys": [(0.0, {}), (2.0, {})]},
    # ---------------------------------------------------------------- one-shots
    "land": {"len": 0.4, "step": 2, "base": dict(STILL, spine=(30.0, 0.0, 0.0), head=(-14.0, 0.0, 6.0), hL=(-0.34, 0.08, 0.86), hR=(0.33, 0.14, 1.0), skirt=(-16.0, 0.0), pld=(-10.0, -10.0)), "keys": [
        (0.0, {}), (0.1, {"spine": (24.0, 0.0, 0.0), "skirt": (-6.0, 0.0)}), (0.4, dict(STILL, skirt=(0.0, 0.0), pld=(0.0, 0.0)))]},
    "hit": {"len": 0.35, "step": 1, "base": STILL, "keys": [
        (0.00, {}),
        (0.05, {"spine": (-12.0, 12.0, -8.0), "head": (-20.0, -22.0, -16.0), "hL": (-0.38, -0.05, 1.08), "hR": (0.38, 0.0, 1.12), "brow": 0.9, "lid": 0.0, "jaw": 12.0, "cheek": 0.0, "skirt": (-10.0, 0.0)}, "snap"),
        (0.14, {"spine": (-4.0, 8.0, -4.0), "head": (2.0, -8.0, 16.0), "jaw": 4.0}),
        (0.35, STILL),
    ]},
    # his emote: a jester's deep bow with a flourish of the off hand, the head held up and grinning; then the silent cackle
    "emote": {"len": 2.4, "step": 3, "base": STILL, "add": laugh(14.0, 11.0, 1.1, 2.1), "keys": [
        (0.00, {}),
        (0.25, {"hL": (-0.42, 0.14, 1.36), "fL": (-0.6, 0.3, 0.7), "pL": (0.0, 0.9, 0.3), "cL": 0.1, "spine": (-6.0, 8.0, -4.0), "head": (-14.0, -8.0, -10.0), "cheek": 0.9, "brow": 0.5}, "out"),
        (0.7, {"hL": (-0.2, 0.38, 1.0), "fL": (0.3, 0.7, -0.6), "pL": (0.0, -0.3, 0.95), "spine": (52.0, 0.0, 0.0), "head": (-44.0, 0.0, 12.0), "hR": (0.34, -0.26, 1.06), "fR": (0.3, -0.6, 0.7), "skirt": (28.0, 0.0), "brow": -1.0}),
        (1.05, {"spine": (52.0, 0.0, 0.0)}),
        (1.2, {"spine": (-4.0, 0.0, 0.0), "head": (-20.0, 0.0, 0.0), "hL": (-0.16, 0.28, 1.3), "fL": (0.3, 0.3, 0.9), "pL": (0.5, 0.0, -0.8), "hR": (0.16, 0.28, 1.2), "fR": (-0.3, 0.5, 0.8), "pR": (-0.5, 0.0, -0.8), "skirt": (-12.0, 0.0), "brow": 0.6}, "snap"),
        (2.1, {"spine": (2.0, 0.0, 6.0), "head": (-16.0, 0.0, -10.0), "skirt": (0.0, 0.0)}),
        (2.4, STILL),
    ]},
    # Fusion: drawn up on the strings, the orb taken into his chest, thrown open as the form takes him
    "fuse": {"len": 1.6, "step": 3, "base": STILL, "keys": [
        (0.00, {}),
        (0.3, CLENCH),
        (0.7, dict(CLENCH, hR=(0.03, 0.12, 1.14), hL=(-0.03, 0.12, 1.14), spine=(10.0, 0.0, 0.0), head=(-12.0, 0.0, 0.0), orb=0.2)),
        (0.95, dict(SPREAD, orb=0.0), "snap"),
        (1.3, {"spine": (-12.0, 0.0, 0.0), "wR": 0.2}),
        (1.6, dict(STILL, jaw=0.0, pld=(0.0, 0.0), orb=1.0)),
    ]},
    # death: every string goes at once: arms drop, the head falls, the orb gutters out
    "death": {"len": 1.6, "step": 2, "base": STILL, "keys": [
        (0.00, {}),
        (0.12, {"spine": (-14.0, 0.0, -6.0), "head": (-26.0, -14.0, 0.0), "brow": 1.0, "jaw": 16.0, "lid": 0.0, "hL": (-0.4, 0.05, 1.28), "hR": (0.4, 0.05, 1.34)}, "snap"),
        (0.5, dict(LIMP, spine=(44.0, 0.0, 12.0), head=(42.0, 10.0, 24.0), lift=(0.0, 0.0, -0.16), jaw=14.0, orb=0.3), "in"),
        (0.7, {"spine": (38.0, 0.0, 10.0), "head": (36.0, 10.0, 24.0)}),
        (1.6, {"spine": (52.0, 0.0, 14.0), "head": (46.0, 12.0, 26.0), "orb": 0.0, "lid": 1.0, "lift": (0.0, 0.0, -0.3), "skirt": (-22.0, 0.0)}),
    ]},
}

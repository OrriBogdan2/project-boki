"""Motley's hand-keyed clips: the table ostra_anim.py samples. Key = (t, {channels}, easing into it). ostra_pose.NEUTRAL lists the channels.
The action clips run on the kit's clock: lengths and beats are those of the moves in scripts/match/kmoves_stone.gd (the Snap's release is its
t = 0; an orb leaves at t = 0, a Trade's lantern at 0.14, the Well commits at 0.25). The Rig keeps the lift, squash and spins those moves key,
so here the box and body only answer them: the root bone isn't keyed. Everything is a jack-in-the-box: compress, release, overshoot, wobble."""
import math

TAU = 2 * math.pi

ORB_UP = {"hR": (0.31, 0.20, 1.05), "fR": (0.05, 0.75, 0.65), "pR": (-0.25, -0.45, 0.85), "eR": (1.0, -0.7, -0.6), "cR": 0.3, "sR": 1.0}
FAN_UP = {"hL": (-0.30, 0.18, 1.10), "fL": (-0.25, 0.25, 0.95), "pL": (0.15, -0.95, 0.2), "eL": (-1.0, -0.6, -0.5), "cL": 0.55, "sL": 0.6}
STILL = dict(ORB_UP, **FAN_UP, spine=(8.0, -5.0, 2.0), head=(-14.0, 6.0, 12.0), brow=-0.5, cheek=0.3, lid=0.3)

# leaning out, both hands in it
READY = dict(STILL, hR=(0.26, 0.32, 1.12), hL=(-0.26, 0.28, 1.14), spine=(18.0, -8.0, 0.0), head=(-22.0, 8.0, 8.0), brow=-1.0, cheek=0.6, lift=(0.0, 0.03, -0.05), box=(3.0, 0.0))

SPREAD = {"hR": (0.42, 0.06, 1.46), "fR": (0.45, 0.15, 0.85), "pR": (-0.2, 0.9, 0.2), "eR": (1.0, -0.4, -0.5), "cR": 0.1, "sR": 1.0,
          "hL": (-0.42, 0.06, 1.46), "fL": (-0.45, 0.15, 0.85), "pL": (0.2, 0.9, 0.2), "eL": (-1.0, -0.4, -0.5), "cL": 0.2, "sL": 1.0,
          "spine": (-8.0, 0.0, 0.0), "head": (-20.0, 0.0, 0.0), "jaw": 12.0, "cheek": 1.0, "brow": 0.3, "lid": 0.0, "pld": (22.0, 22.0), "lift": (0.0, 0.0, 0.1)}

CLENCH = {"hR": (0.09, 0.2, 1.17), "fR": (-0.5, 0.5, 0.5), "pR": (-0.7, -0.5, -0.3), "cR": 1.0, "sR": 0.0, "hL": (-0.09, 0.2, 1.17), "fL": (0.5, 0.5, 0.5),
          "pL": (0.7, -0.5, -0.3), "cL": 1.0, "sL": 0.0, "eR": (1.0, -0.3, -0.8), "eL": (-1.0, -0.3, -0.8), "spine": (22.0, 0.0, 0.0), "head": (6.0, 0.0, 0.0),
          "brow": -1.0, "cheek": 0.2, "lid": 1.0, "jaw": 0.0, "pld": (-12.0, -12.0), "lift": (0.0, 0.0, -0.2), "smoke": 1.0}

LIMP = {"hR": (0.2, 0.07, 0.82), "hL": (-0.2, 0.07, 0.82), "fR": (0.05, 0.1, -1.0), "fL": (-0.05, 0.1, -1.0), "pR": (-1.0, 0.0, 0.0), "pL": (1.0, 0.0, 0.0),
        "cR": 0.3, "cL": 0.3, "sR": 0.2, "sL": 0.2, "eR": (1.0, -0.5, 0.0), "eL": (-1.0, -0.5, 0.0)}


def breath(P, t, period, amp=0.6):
    s = P["spine"]
    P["spine"] = (s[0] + amp * math.sin(t / period * TAU), s[1], s[2])
    l = P["lift"]
    P["lift"] = (l[0], l[1], l[2] + 0.006 * math.sin(t / period * TAU * 2))


def idle_add(P, t):
    breath(P, t, 3.2)
    P["wR"] = 0.1
    P["wL"] = 0.06


def stance_add(P, t):
    breath(P, t, 2.0, 0.7)
    P["wR"] = 0.18
    P["wL"] = 0.1


def laugh(a, rate=11.0, t0=0.0, t1=99.0):
    def fn(P, t):
        if t0 <= t <= t1:
            P["jaw"] = P["jaw"] + a * (0.5 + 0.5 * math.sin((t - t0) * rate * TAU / 3.0))
    return fn


def wobble(period, pitch, roll, bob):
    """travelling: the spring breathes under him, the body a beat behind the box"""
    def fn(P, t):
        ph = t / period * TAU
        s = P["spine"]
        P["spine"] = (s[0] + pitch * math.sin(ph - 0.9), s[1], s[2] + roll * math.sin(ph * 0.5 * 2 - 0.9))
        b = P["box"]
        P["box"] = (b[0] + pitch * 0.5 * math.sin(ph), b[1] + roll * 0.5 * math.sin(ph))
        l = P["lift"]
        P["lift"] = (l[0], l[1], l[2] + bob * math.sin(ph * 2 - 0.9))
        hd = P["head"]
        P["head"] = (hd[0] - pitch * 0.5 * math.sin(ph - 1.5), hd[1], hd[2])
        P["wR"], P["wL"] = 0.12, 0.08
    return fn


def twitch(amp, rate):
    def fn(P, t):
        s = P["spine"]
        P["spine"] = (s[0] + amp * math.sin(t * rate), s[1] + amp * 1.3 * math.sin(t * rate * 1.37), s[2] + amp * math.cos(t * rate * 0.83))
        h = P["head"]
        P["head"] = (h[0], h[1] + amp * 1.5 * math.sin(t * rate * 1.13), h[2] + amp * 1.5 * math.cos(t * rate * 1.7))
    return fn


def loco(box, spine, lift, **kw):
    b = dict(STILL, box=box, spine=spine, lift=lift)
    b.update(kw)
    return b


TRAIL = {"hR": (0.34, 0.02, 1.10), "fR": (0.2, -0.3, 0.9), "pR": (-0.2, 0.2, 0.9), "hL": (-0.34, -0.06, 1.06), "fL": (-0.3, -0.4, 0.85), "pL": (0.1, -0.9, 0.3)}

AIM_LOW = {"hR": (0.30, -0.24, 0.92), "fR": (0.2, -0.75, -0.55), "pR": (-0.1, -0.6, 0.8), "eR": (1.0, -0.4, 0.4), "cR": 0.55, "sR": 0.8,
           "hL": (-0.27, 0.27, 1.12), "fL": (-0.1, 0.9, 0.35), "pL": (0.4, -0.2, -0.85), "cL": 0.45, "sL": 1.0, "eL": (-1.0, -0.6, -0.4),
           "spine": (14.0, 20.0, 4.0), "head": (-14.0, -14.0, 6.0), "brow": -0.9, "cheek": 0.8, "lid": 0.5, "lift": (0.0, 0.0, -0.24), "smoke": 1.0, "box": (-3.0, 0.0)}

WIND = {"hR": (0.13, 0.24, 1.26), "fR": (-0.45, 0.55, 0.65), "pR": (-0.8, -0.3, -0.5), "cR": 0.65, "sR": 0.8, "hL": (-0.13, 0.24, 1.2), "fL": (0.45, 0.55, 0.7),
        "pL": (0.8, -0.3, -0.45), "cL": 0.65, "sL": 0.8, "eR": (1.0, -0.8, -0.2), "eL": (-1.0, -0.8, -0.2), "fan": 0.3,
        "spine": (-16.0, 28.0, 0.0), "head": (0.0, -20.0, 6.0), "brow": -1.0, "cheek": 0.9, "lid": 0.9, "pld": (10.0, 10.0),
        "lift": (0.0, -0.08, -0.2), "box": (-5.0, 0.0), "smoke": 0.8}

SHOVE = {"hR": (0.09, 0.44, 1.28), "fR": (0.0, 0.5, 0.85), "pR": (0.0, 1.0, -0.4), "eR": (1.0, -0.4, -0.7), "cR": 0.05, "sR": 1.0, "hL": (-0.09, 0.44, 1.24),
         "fL": (0.0, 0.5, 0.85), "pL": (0.0, 1.0, -0.4), "eL": (-1.0, -0.4, -0.7), "cL": 0.05, "sL": 1.0, "spine": (36.0, -18.0, 0.0), "head": (-26.0, 14.0, 0.0),
         "brow": -1.0, "cheek": 1.0, "lid": 0.6, "jaw": 8.0, "pld": (-10.0, -10.0), "lift": (0.0, 0.2, 0.1), "box": (7.0, 0.0), "smoke": 0.0, "fan": 1.0}

DOWN = dict(LIMP, spine=(34.0, 0.0, 9.0), head=(34.0, 8.0, 16.0), hL=(-0.16, 0.22, 0.86), hR=(0.14, 0.16, 0.84), brow=0.4, cheek=0.0, jaw=8.0, lid=0.8, fan=0.5,
            lift=(0.0, 0.04, -0.3), lidb=0.22, box=(0.0, -5.0))

def flurry_add(P, t):
    """one flick of the wrist a card, the shoulders rocking with it; the fan thins as the deck is dealt"""
    if t > 0.70:
        return
    i = int(t / 0.08)
    k = math.sin(math.pi * ((t / 0.08) % 1.0))
    x, y, z = P["hR"]
    P["hR"] = (x - 0.05 * k * (1 if i % 2 else -1), y + 0.15 * k, z + 0.03 * k)
    P["cR"] = 0.45 - 0.4 * k
    s = P["spine"]
    P["spine"] = (s[0], s[1] + 7.0 * k * (1 if i % 2 else -1), s[2])
    P["fan"] = 1.0 - 0.7 * min(i + 1, 8) / 8.0


# ---- the crouch (item 143): the jack half back in his box. The spring wound down, the hat low, the hands gathered at the ruff with the grin just showing over it. No feet, no stride: a sneak is the box gliding on small spring bobs.
HUNCH = dict(STILL, lift=(0.0, 0.0, -0.34), spine=(20.0, -4.0, 0.0), head=(-26.0, 6.0, 6.0), box=(4.0, 0.0), pld=(16.0, 16.0),
             hR=(0.13, 0.27, 1.08), hL=(-0.13, 0.25, 1.10), cR=0.7, cL=0.75, sR=0.3, sL=0.3, brow=-0.7, cheek=0.9, lid=0.45)
SQUEEZE = dict(HUNCH, lift=(0.0, 0.0, -0.40), spine=(26.0, -4.0, 0.0), head=(-20.0, 6.0, 6.0))
SPRUNG = dict(STILL, lift=(0.0, 0.0, 0.035), cheek=0.6, brow=-0.3)


def hunch_add(P, t):
    """Wound down and still: a held breath, the hat turning slowly under its brim, the spring's small tremble."""
    a = math.sin(t / 3.6 * TAU)
    h = P["head"]
    P["head"] = (h[0], h[1] + 14.0 * a, h[2] - 3.0 * a)
    s = P["spine"]
    P["spine"] = (s[0] + 0.8 * math.cos(t / 3.6 * TAU) - 0.8, s[1], s[2])
    l = P["lift"]
    P["lift"] = (l[0], l[1], l[2] + 0.006 * math.sin(t / 3.6 * TAU * 2))
    P["wR"], P["wL"] = 0.14, 0.1


def creep(box, shift):
    return {"len": 0.9, "loop": True, "base": dict(HUNCH, box=box, lift=(shift[0], shift[1], -0.34)), "add": wobble(0.9, 1.2, 1.2, 0.012), "keys": [(0.0, {}), (0.9, {})]}


def pump(P, t):
    """reviving: both hands press on his friend's chest, one then the other, the spring rocking with it"""
    ph = t / 2.0 * TAU * 2
    a, b = max(0.0, math.sin(ph)), max(0.0, -math.sin(ph))
    for k, v in (("hR", a), ("hL", b)):
        x, y, z = P[k]
        P[k] = (x, y, z - 0.07 * v)
    s0 = P["spine"]
    P["spine"] = (s0[0] + 3.0 * math.sin(ph - 0.5), s0[1], s0[2])
    P["wR"], P["wL"] = 0.35, 0.2


CLIPS = {
    # ---------------------------------------------------------------- loco: the box goes first, tilting toward the way he moves; the body rides late
    "idle": {"len": 3.2, "base": STILL, "add": idle_add, "loop": True, "keys": [
        (0.0, {}),
        (1.3, {}),
        # a jack's tick: the head snapped over, held, snapped back, the grin wider
        (1.42, {"head": (-14.0, -10.0, -9.0), "brow": -0.2, "cheek": 0.7}, "snap"),
        (2.3, {"head": (-12.0, -8.0, -10.0)}),
        (2.42, {"head": (-14.0, 6.0, 12.0), "brow": -0.5, "cheek": 0.3}, "snap"),
        (3.2, {}),
    ]},
    "stance": {"len": 2.0, "base": READY, "add": stance_add, "loop": True, "keys": [(0.0, {}), (2.0, {})]},
    "walk_f": {"len": 1.4, "loop": True, "base": loco((9.0, 0.0), (4.0, -4.0, 2.0), (0.0, -0.03, -0.03), head=(-18.0, 4.0, 8.0)), "add": wobble(1.4, 2.5, 2.0, 0.012), "keys": [(0.0, {}), (1.4, {})]},
    "walk_b": {"len": 1.4, "loop": True, "base": loco((-9.0, 0.0), (10.0, -4.0, 0.0), (0.0, 0.03, -0.03), head=(-12.0, 2.0, 10.0)), "add": wobble(1.4, 2.5, 2.0, 0.012), "keys": [(0.0, {}), (1.4, {})]},
    "walk_l": {"len": 1.4, "loop": True, "base": loco((3.0, -9.0), (6.0, 8.0, 6.0), (0.03, 0.0, -0.03)), "add": wobble(1.4, 2.0, 2.5, 0.012), "keys": [(0.0, {}), (1.4, {})]},
    "walk_r": {"len": 1.4, "loop": True, "base": loco((3.0, 9.0), (6.0, -12.0, -6.0), (-0.03, 0.0, -0.03)), "add": wobble(1.4, 2.0, 2.5, 0.012), "keys": [(0.0, {}), (1.4, {})]},
    "run_f": {"len": 0.9, "loop": True, "turns": 2, "base": dict(loco((17.0, 0.0), (2.0, 0.0, 0.0), (0.0, -0.09, -0.07), head=(-22.0, 0.0, 6.0), brow=-1.0, cheek=0.7), **TRAIL), "add": wobble(0.9, 3.5, 3.0, 0.02), "keys": [(0.0, {}), (0.9, {})]},
    "run_b": {"len": 0.9, "loop": True, "turns": 2, "base": dict(loco((-16.0, 0.0), (14.0, 0.0, 0.0), (0.0, 0.08, -0.07), head=(-16.0, 0.0, 6.0), cheek=0.7)), "add": wobble(0.9, 3.5, 3.0, 0.02), "keys": [(0.0, {}), (0.9, {})]},
    "run_l": {"len": 0.9, "loop": True, "turns": 2, "base": dict(loco((4.0, -17.0), (6.0, 8.0, 12.0), (0.08, 0.0, -0.07), head=(-16.0, -8.0, 4.0), cheek=0.7), **TRAIL), "add": wobble(0.9, 3.0, 3.5, 0.02), "keys": [(0.0, {}), (0.9, {})]},
    "run_r": {"len": 0.9, "loop": True, "turns": 2, "base": dict(loco((4.0, 17.0), (6.0, -8.0, -12.0), (-0.08, 0.0, -0.07), head=(-16.0, 8.0, 20.0), cheek=0.7), **TRAIL), "add": wobble(0.9, 3.0, 3.5, 0.02), "keys": [(0.0, {}), (0.9, {})]},

    # ---------------------------------------------------------------- the crouch: down with a squeeze past the hold, up with a small overshoot
    "crouch_idle": {"len": 3.6, "base": HUNCH, "add": hunch_add, "loop": True, "keys": [(0.0, {}), (3.6, {})]},
    "crouch_f": creep((7.0, 0.0), (0.0, -0.02)),
    "crouch_b": creep((-7.0, 0.0), (0.0, 0.02)),
    "crouch_l": creep((3.0, -7.0), (0.02, 0.0)),
    "crouch_r": creep((3.0, 7.0), (-0.02, 0.0)),
    "crouch_in": {"len": 0.34, "base": STILL, "keys": [(0.0, {}), (0.15, SQUEEZE), (0.34, HUNCH)]},
    "crouch_out": {"len": 0.36, "base": HUNCH, "keys": [(0.0, {}), (0.08, SQUEEZE), (0.24, SPRUNG), (0.36, STILL)]},

    # ---------------------------------------------------------------- LMB: Tether Lantern (leans out on the spring)
    "orb": {"len": 0.30, "base": STILL, "keys": [
        (0.00, {}),
        (0.033, {"hR": (0.31, 0.02, 1.24), "fR": (0.2, 0.4, 0.9), "pR": (-0.1, 0.8, -0.3), "spine": (2.0, 10.0, 3.0), "lift": (0.0, -0.04, -0.03)}, "out"),
        (0.10, {"hR": (0.14, 0.42, 1.22), "fR": (-0.1, 0.95, 0.1), "pR": (0.0, 0.2, -1.0), "eR": (1.0, -0.5, -0.5), "cR": 0.12, "sR": 1.0, "spine": (16.0, -20.0, 3.0), "head": (-22.0, 14.0, 10.0),
                "lift": (0.0, 0.1, 0.02), "cheek": 0.7, "brow": -1.0}, "snap"),
        (0.17, {"cR": 0.3, "lift": (0.0, 0.05, 0.0)}),
        (0.30, dict(STILL, lift=(0.0, 0.0, 0.0))),
    ]},
    # the alternate cast, off his left hand: the fan drops as the hand flicks (WardenClips "alt": every other orb)
    "orb_l": {"len": 0.30, "base": STILL, "keys": [
        (0.00, {}),
        (0.033, {"hL": (-0.31, 0.02, 1.24), "fL": (-0.2, 0.4, 0.9), "pL": (0.1, 0.8, -0.3), "spine": (2.0, -10.0, -3.0), "lift": (0.0, -0.04, -0.03), "fan": 0.6}, "out"),
        (0.10, {"hL": (-0.14, 0.42, 1.22), "fL": (0.1, 0.95, 0.1), "pL": (0.0, 0.2, -1.0), "eL": (-1.0, -0.5, -0.5), "cL": 0.12, "sL": 1.0, "spine": (16.0, 20.0, -3.0), "head": (-22.0, -14.0, 10.0),
                "lift": (0.0, 0.1, 0.02), "cheek": 0.7, "brow": -1.0, "fan": 0.3}, "snap"),
        (0.17, {"cL": 0.3, "lift": (0.0, 0.05, 0.0), "fan": 0.6}),
        (0.30, dict(STILL, lift=(0.0, 0.0, 0.0), fan=1.0)),
    ]},
    # item 136's RMB: eight cards, one each 0.08 s, dealt off the fan by the right hand; the left holds the deck up; he keeps moving
    "flurry": {"len": 0.90, "base": dict(READY, hR=(0.2, 0.3, 1.16), fR=(0.0, 0.9, 0.35), pR=(0.0, 0.2, -1.0), cR=0.2, hL=(-0.2, 0.26, 1.16), fL=(0.1, 0.5, 0.85), pL=(0.2, -0.9, 0.2), spine=(14.0, -6.0, 0.0), head=(-24.0, 6.0, 4.0), cheek=1.0), "add": flurry_add, "keys": [
        (0.00, dict(STILL)),
        (0.05, dict(READY, hR=(0.2, 0.3, 1.16), fR=(0.0, 0.9, 0.35), pR=(0.0, 0.2, -1.0), cR=0.2, hL=(-0.2, 0.26, 1.16), fL=(0.1, 0.5, 0.85), pL=(0.2, -0.9, 0.2), spine=(14.0, -6.0, 0.0), head=(-24.0, 6.0, 4.0), cheek=1.0), "out"),
        (0.66, {}),
        (0.90, STILL),
    ]},
    # the full orb only (the kit plays this at full charge): compressed, then the whole spring flung out behind the throw
    "orb_hot": {"len": 0.50, "base": STILL, "keys": [
        (0.00, {}),
        (0.067, {"hR": (0.36, -0.14, 1.22), "fR": (0.25, -0.5, 0.8), "pR": (-0.1, 0.8, 0.5), "eR": (1.0, -0.2, -0.8), "spine": (-6.0, 26.0, 3.0), "head": (-8.0, -18.0, 8.0), "lift": (0.0, -0.08, -0.16), "lid": 1.0, "cheek": 0.9, "brow": -1.0, "smoke": 0.5}, "out"),
        (0.133, {"hR": (0.08, 0.45, 1.26), "fR": (0.0, 1.0, 0.1), "pR": (0.0, 0.1, -1.0), "cR": 0.02, "sR": 1.0, "eR": (1.0, -0.4, -0.6), "spine": (28.0, -30.0, 0.0), "head": (-28.0, 24.0, 4.0),
                  "hL": (-0.3, -0.1, 0.98), "lift": (0.0, 0.2, 0.1), "box": (6.0, 0.0), "jaw": 8.0, "smoke": 0.0}, "snap"),
        (0.233, {"spine": (-4.0, -24.0, 0.0), "lift": (0.0, -0.05, 0.06), "hR": (0.14, 0.40, 1.34), "fR": (0.1, 0.5, 0.85), "cR": 0.2, "head": (-10.0, 20.0, 6.0), "jaw": 10.0, "box": (-4.0, 0.0)}),
        (0.50, dict(STILL, jaw=0.0)),
    ]},
    # ---------------------------------------------------------------- RMB: Shard Snap (the spring wound right down, then the release)
    "snap_wind": {"len": 0.70, "base": STILL, "add": lambda P, t: t > 0.3 and twitch(0.5, 44.0)(P, t), "keys": [
        (0.00, {}),
        (0.133, dict(WIND, spine=(0.0, 12.0, 0.0), head=(-8.0, -8.0, 8.0), hR=(0.13, 0.25, 1.14), hL=(-0.13, 0.25, 1.1), lift=(0.0, -0.03, -0.1), smoke=0.3)),
        (0.30, WIND),
        (0.70, WIND),
    ]},
    "snap": {"len": 0.50, "base": WIND, "keys": [
        (0.00, {}),
        (0.067, SHOVE, "snap"),
        (0.167, {"spine": (-12.0, -14.0, 0.0), "lift": (0.0, -0.1, 0.03), "hR": (0.2, 0.32, 1.32), "hL": (-0.28, 0.2, 1.12), "fL": (-0.3, 0.7, 0.3), "cR": 0.35, "cL": 0.4, "head": (-6.0, 10.0, 6.0), "box": (-6.0, 0.0)}),
        (0.30, {"spine": (12.0, -8.0, 0.0), "lift": (0.0, 0.04, -0.03), "box": (3.0, 0.0)}),
        (0.50, dict(STILL, jaw=0.0, pld=(0.0, 0.0), lift=(0.0, 0.0, 0.0), box=(0.0, 0.0))),
    ]},
    # ---------------------------------------------------------------- Shift: Lantern Trade
    # holding Shift: the spring compresses, the smoke winds on
    "swap_aim": {"len": 0.66, "base": STILL, "add": lambda P, t: t > 0.16 and twitch(0.35, 30.0)(P, t), "keys": [(0.00, {}), (0.167, AIM_LOW, "out"), (0.66, AIM_LOW)]},
    # the launch: the spring lets go with the lob (0.14 it leaves)
    "swap": {"len": 0.85, "base": AIM_LOW, "keys": [
        (0.00, {}),
        (0.067, {"hR": (0.28, -0.32, 0.86), "spine": (6.0, 24.0, 4.0), "lift": (0.0, 0.0, -0.28)}),
        (0.133, {"hR": (0.14, 0.26, 1.60), "fR": (0.0, 0.5, 0.85), "pR": (0.0, 0.9, -0.4), "eR": (1.0, -0.2, -0.3), "cR": 0.05, "sR": 1.0, "hL": (-0.34, -0.05, 0.98), "fL": (-0.4, -0.3, -0.8), "pL": (0.5, 0.3, -0.3),
                  "spine": (-10.0, -12.0, -5.0), "head": (-26.0, 8.0, -4.0), "jaw": 10.0, "cheek": 1.0, "lift": (0.0, 0.04, 0.16), "smoke": 0.0, "box": (0.0, 0.0)}, "smooth"),
        (0.30, {"lift": (0.0, 0.0, -0.05)}),
        (0.43, {"hR": (0.2, 0.22, 1.46), "fR": (0.3, 0.5, 0.8), "cR": 0.2, "head": (-20.0, 8.0, 6.0), "jaw": 5.0, "lift": (0.0, 0.0, 0.03)}),
        (0.60, {"lift": (0.0, 0.0, -0.01)}),
        (0.85, dict(STILL, jaw=0.0, lift=(0.0, 0.0, 0.0))),
    ]},
    # the same from the air, then drifting after his lantern (about 1.4 m/s): the box leads, tipped into the drift, the body strung out behind (loops from 0.47)
    "swap_air": {"len": 1.27, "base": STILL, "keys": [
        (0.00, {}),
        (0.067, {"hR": (-0.14, 0.26, 0.98), "fR": (-0.6, 0.2, -0.75), "pR": (0.3, 0.8, 0.3), "eR": (1.0, -0.4, 0.4), "spine": (12.0, -24.0, 0.0), "head": (-6.0, 18.0, 4.0), "lift": (0.0, 0.0, -0.16)}, "out"),
        (0.167, {"hR": (0.2, 0.22, 1.6), "fR": (0.1, 0.5, 0.85), "pR": (0.0, 0.9, -0.4), "cR": 0.05, "sR": 1.0, "hL": (-0.4, -0.1, 1.0), "fL": (-0.5, -0.3, -0.7), "pL": (0.3, 0.5, 0.7),
                 "spine": (-8.0, 12.0, 0.0), "head": (-24.0, 0.0, 0.0), "jaw": 10.0, "cheek": 1.0, "lift": (0.0, 0.0, 0.12)}, "snap"),
        (0.47, dict(TRAIL, spine=(4.0, 4.0, 4.0), head=(-22.0, 0.0, -6.0), jaw=0.0, cheek=0.8, lift=(0.0, -0.06, 0.0), box=(11.0, 3.0), cR=0.2, cL=0.5)),
        (0.87, {"spine": (6.0, -4.0, -4.0), "head": (-20.0, 0.0, 6.0), "box": (9.0, -3.0), "lift": (0.0, -0.05, -0.03)}),
        (1.27, {"spine": (4.0, 4.0, 4.0), "head": (-22.0, 0.0, -6.0), "box": (11.0, 3.0), "lift": (0.0, -0.06, 0.0)}),
    ]},
    # arriving: the lid is shut, he is inside; it bursts open and the jack is out, overshooting, wobbling down: the void pop
    "arrive": {"len": 0.60, "base": dict(SPREAD, hR=(0.12, 0.06, 1.68), hL=(-0.12, 0.06, 1.68), fR=(0.0, 0.1, 1.0), fL=(0.0, 0.1, 1.0), body=0.02, lidb=1.0, lift=(0.0, 0.0, -0.47), smoke=0.0), "add": laugh(9.0, 12.0, 0.1, 0.5), "keys": [
        (0.00, {}),
        (0.10, {"lidb": 1.0, "body": 0.02}),
        (0.167, {"lidb": -0.3, "body": 1.08, "lift": (0.0, 0.0, 0.2), "hR": (0.44, 0.08, 1.3), "hL": (-0.44, 0.08, 1.3), "fR": (0.8, 0.1, 0.3), "fL": (-0.8, 0.1, 0.3), "pR": (0.0, 0.9, -0.4), "pL": (0.0, 0.9, -0.4),
                "spine": (-10.0, 0.0, 0.0), "head": (-24.0, 0.0, 0.0), "pld": (16.0, 16.0), "smoke": 0.4}, "snap"),
        (0.25, {"lift": (0.0, 0.0, -0.1), "body": 1.0, "lidb": 0.05, "spine": (14.0, 0.0, 0.0), "head": (-22.0, 0.0, 8.0), "hR": (0.42, 0.06, 1.2), "hL": (-0.42, 0.06, 1.2), "smoke": 0.0, "pld": (-8.0, -8.0)}),
        (0.37, {"lift": (0.0, 0.0, 0.05), "lidb": -0.05, "hR": (0.38, 0.14, 1.14), "hL": (-0.34, 0.14, 1.14), "spine": (0.0, -4.0, 2.0), "head": (-14.0, 4.0, 12.0), "pld": (0.0, 0.0)}),
        (0.60, dict(STILL, jaw=0.0, pld=(0.0, 0.0), lidb=0.0)),
    ]},
    # ---------------------------------------------------------------- E: Brimseed
    "seed": {"len": 0.80, "base": STILL, "keys": [
        (0.00, {}),
        (0.067, {"hR": (0.2, 0.2, 1.5), "fR": (0.0, 0.25, 1.0), "pR": (0.0, 0.9, -0.2), "eR": (1.0, -0.2, -0.5), "cR": 0.55, "spine": (0.0, -4.0, 2.0), "head": (-20.0, 6.0, -8.0), "cheek": 0.9, "lift": (0.0, 0.0, 0.05)}, "out"),
        (0.20, {"hR": (0.14, 0.44, 1.06), "fR": (0.0, 0.75, -0.65), "pR": (0.0, -0.3, -0.95), "cR": 0.12, "sR": 1.0, "hL": (-0.3, -0.05, 1.04), "fL": (-0.5, -0.2, -0.8),
                "spine": (32.0, -12.0, 0.0), "head": (-22.0, 8.0, 10.0), "brow": -1.0, "lid": 0.7, "lift": (0.0, 0.14, -0.08), "box": (7.0, 0.0)}, "snap"),
        (0.50, {"hR": (0.2, 0.36, 1.08), "cR": 0.3, "spine": (18.0, -8.0, 2.0), "lift": (0.0, 0.07, -0.03), "box": (3.0, 0.0)}),
        (0.80, dict(STILL, lift=(0.0, 0.0, 0.0), box=(0.0, 0.0))),
    ]},
    "pop": {"len": 0.60, "base": STILL, "add": laugh(11.0, 12.0, 0.2, 0.55), "keys": [
        (0.00, {}),
        (0.067, CLENCH, "out"),
        (0.20, SPREAD, "snap"),
        (0.34, {"lift": (0.0, 0.0, -0.03)}),
        (0.60, dict(STILL, pld=(0.0, 0.0), jaw=0.0, lift=(0.0, 0.0, 0.0), smoke=0.0)),
    ]},
    # ---------------------------------------------------------------- X: Nightwell: the lid thrown wide, the void hauling at everything, the jack riding high and laughing
    "well": {"len": 1.27, "base": STILL, "add": lambda P, t: t > 0.25 and (P.update(wR=0.3, wL=0.2) or laugh(7.0, 9.0, 0.25, 9.0)(P, t)), "keys": [
        (0.00, {}),
        (0.10, dict(CLENCH, hR=(-0.1, 0.25, 0.92), fR=(-0.5, 0.3, -0.8), pR=(0.3, 0.9, 0.2), hL=(0.1, 0.25, 0.92), fL=(0.5, 0.3, -0.8), pL=(-0.3, 0.9, 0.2), lift=(0.0, 0.0, -0.26), lidb=0.5, cR=0.7, cL=0.7), "out"),
        (0.267, dict(SPREAD, lidb=-0.42, box=(-5.0, 0.0), smoke=0.0, lift=(0.0, -0.05, 0.14)), "snap"),
        (0.77, {"spine": (-11.0, 0.0, 2.0), "head": (-24.0, 0.0, 4.0), "cR": 0.2, "cL": 0.3, "lidb": -0.36}),
        (1.27, {"spine": (-8.0, 0.0, 0.0), "head": (-20.0, 0.0, 0.0), "cR": 0.1, "cL": 0.2, "lidb": -0.42}),
    ]},
    "well_snap": {"len": 0.57, "base": dict(SPREAD, lidb=-0.42, box=(-5.0, 0.0), lift=(0.0, -0.05, 0.14)), "keys": [
        (0.00, {}),
        (0.067, dict(CLENCH, hR=(0.2, 0.34, 1.3), hL=(-0.2, 0.34, 1.3), lift=(0.0, 0.0, -0.2)), "snap"),
        (0.233, dict(CLENCH, hR=(0.14, 0.26, 1.2), hL=(-0.14, 0.26, 1.2), spine=(28.0, 0.0, 0.0))),
        (0.367, {"hR": (0.34, 0.1, 0.88), "hL": (-0.34, 0.1, 0.88), "fR": (0.5, 0.3, -0.8), "fL": (-0.5, 0.3, -0.8), "pR": (0.0, -0.9, 0.3), "pL": (0.0, -0.9, 0.3), "cR": 0.1, "cL": 0.1, "sR": 1.0, "sL": 1.0,
                 "spine": (-4.0, 0.0, 0.0), "head": (-16.0, 0.0, 6.0), "lid": 0.2, "jaw": 6.0, "pld": (6.0, 6.0), "lift": (0.0, 0.0, 0.08), "smoke": 0.0, "lidb": 0.0, "box": (0.0, 0.0)}, "out"),
        (0.567, dict(STILL, jaw=0.0, pld=(0.0, 0.0), lift=(0.0, 0.0, 0.0))),
    ]},
    "well_end": {"len": 0.37, "base": dict(SPREAD, lidb=-0.42, box=(-5.0, 0.0), lift=(0.0, -0.05, 0.14)), "keys": [
        (0.00, {}),
        (0.133, dict(LIMP, spine=(14.0, 0.0, 0.0), head=(0.0, 0.0, 10.0), jaw=0.0, pld=(0.0, 0.0), brow=-0.3, lift=(0.0, 0.0, -0.1), lidb=0.0, box=(0.0, 0.0))),
        (0.367, dict(STILL, jaw=0.0, pld=(0.0, 0.0), lift=(0.0, 0.0, 0.0))),
    ]},
    # Swollen: wound down, sprung up, one full turn (the turn is the kit's), then down
    "empower": {"len": 0.90, "base": STILL, "add": laugh(12.0, 11.0, 0.3, 0.85), "keys": [
        (0.00, {}),
        (0.10, dict(CLENCH, spine=(14.0, 0.0, 0.0))),
        (0.30, dict(SPREAD, smoke=0.0, lift=(0.0, 0.0, 0.16)), "snap"),
        (0.57, {"spine": (-12.0, 0.0, 0.0)}),
        (0.67, {"spine": (-4.0, 0.0, 0.0)}),
        (0.90, dict(STILL, jaw=0.0, pld=(0.0, 0.0), lift=(0.0, 0.0, 0.0))),
    ]},
    # ---------------------------------------------------------------- the body's states
    "jump": {"len": 0.5, "base": STILL, "keys": [
        (0.0, dict(STILL, lift=(0.0, 0.0, -0.12))),
        (0.1, {"spine": (-4.0, 0.0, 0.0), "hR": (0.33, 0.1, 1.3), "hL": (-0.34, 0.05, 1.2), "fL": (-0.4, 0.1, 0.9), "pL": (0.3, 0.8, -0.2), "head": (-22.0, 0.0, 8.0), "cheek": 0.8, "lift": (0.0, 0.0, 0.14)}, "snap"),
        (0.5, {"spine": (2.0, 0.0, 0.0), "hR": (0.33, 0.12, 1.24), "hL": (-0.36, 0.05, 1.12), "lift": (0.0, 0.0, 0.06)}),
    ]},
    "fall": {"len": 0.8, "loop": True, "base": dict(STILL, spine=(4.0, 0.0, 0.0), hR=(0.36, 0.08, 1.36), hL=(-0.38, 0.05, 1.32), fL=(-0.5, 0.0, 0.85), pL=(0.2, 0.9, 0.3), fR=(0.3, 0.3, 0.9), pR=(-0.2, -0.3, 0.9),
                                                 eL=(-1.0, -0.2, -0.6), head=(-10.0, 0.0, 10.0), pld=(12.0, 12.0), brow=0.2, cheek=0.7, lift=(0.0, 0.0, 0.1), box=(-3.0, 0.0)), "add": wobble(0.8, 1.0, 1.5, 0.008), "keys": [(0.0, {}), (0.8, {})]},
    # gliding: arms out, the box slung under him, swinging
    "glide": {"len": 1.6, "loop": True, "base": dict(STILL, spine=(14.0, 0.0, 0.0), hR=(0.40, 0.0, 1.32), hL=(-0.40, 0.0, 1.32), fR=(0.7, 0.1, 0.6), fL=(-0.7, 0.1, 0.6), pR=(0.0, 0.5, -0.8), pL=(0.0, 0.5, -0.8),
                                                  eR=(1.0, -0.2, 0.2), eL=(-1.0, -0.2, 0.2), cL=0.5, cR=0.15, sL=1.0, sR=1.0, head=(-24.0, 0.0, 10.0), cheek=0.8, box=(-10.0, 0.0)), "add": wobble(1.6, 1.5, 4.0, 0.012), "keys": [(0.0, {}), (1.6, {})]},
    "dive": {"len": 0.8, "loop": True, "base": dict(STILL, spine=(40.0, 0.0, 0.0), head=(-34.0, 0.0, 0.0), jaw=9.0, lift=(0.0, -0.1, -0.08), box=(16.0, 0.0), **TRAIL), "add": wobble(0.8, 2.0, 2.0, 0.01), "keys": [(0.0, {}), (0.8, {})]},
    "stun": {"len": 1.0, "loop": True, "base": dict(LIMP, spine=(6.0, 0.0, 5.0), head=(10.0, 8.0, 24.0), brow=0.8, lid=0.0, jaw=8.0, cheek=0.0, lift=(0.0, 0.0, -0.08)), "add": twitch(2.2, 37.7), "keys": [(0.0, {}), (1.0, {})]},
    # downed: the spring gone slack, slumped over the box, the lid sagging, a finger still twitching
    "downed": {"len": 3.0, "loop": True, "base": DOWN,
               "add": lambda P, t: P.update(wL=0.12 * max(0.0, math.sin(t / 3.0 * TAU * 2)), spine=(P["spine"][0] + 1.5 * math.sin(t / 3.0 * TAU), P["spine"][1], P["spine"][2])), "keys": [(0.0, {}), (3.0, {})]},
    "revive": {"len": 2.0, "loop": True, "base": dict(STILL, spine=(30.0, 0.0, 0.0), head=(-16.0, 0.0, 14.0), hR=(0.2, 0.42, 0.98), fR=(0.1, 0.65, -0.75), pR=(0.0, -0.75, -0.65), hL=(-0.2, 0.42, 0.98), fL=(-0.1, 0.65, -0.75), pL=(0.0, -0.75, -0.65),
                                                  cL=0.4, cR=0.2, sL=1.0, sR=1.0, lift=(0.0, 0.1, -0.08), box=(5.0, 0.0)), "add": pump, "keys": [(0.0, {}), (2.0, {})]},
    # finishing a downed foe (Hunter.stomp: 0.7 s, the hit at 0.49 s): no feet, so the spring does it. Coil, spring up with both fists high, hang, drop the whole box on the beat, squash, settle
    "stomp": {"len": 0.7, "base": STILL, "keys": [
        (0.00, {}),
        (0.14, {"lift": (0.0, 0.0, -0.22), "spine": (26.0, 0.0, 0.0), "head": (-18.0, 0.0, 6.0), "hR": (0.3, 0.12, 0.92), "hL": (-0.3, 0.1, 0.92), "brow": -1.0, "cheek": 0.8}, "out"),
        (0.30, {"lift": (0.0, 0.0, 0.2), "spine": (-8.0, 0.0, 0.0), "head": (-24.0, 0.0, 0.0), "hR": (0.4, 0.06, 1.48), "hL": (-0.4, 0.06, 1.48), "jaw": 8.0, "cheek": 1.0, "box": (-4.0, 0.0)}, "out"),
        (0.40, {"lift": (0.0, 0.0, 0.22), "box": (-6.0, 0.0)}),
        (0.49, {"lift": (0.0, 0.0, -0.28), "spine": (32.0, 0.0, 0.0), "head": (-14.0, 0.0, 4.0), "hR": (0.3, 0.2, 0.9), "hL": (-0.3, 0.2, 0.9), "jaw": 2.0, "box": (8.0, 0.0), "smoke": 1.0, "brow": -1.0}, "snap"),
        (0.58, {"lift": (0.0, 0.0, -0.2), "spine": (26.0, 0.0, 0.0), "smoke": 0.4}, "out"),
        (0.70, dict(STILL, lift=(0.0, 0.0, 0.0), smoke=0.0, box=(0.0, 0.0), jaw=0.0)),
    ]},
    # the sip (1.1 s, upper body): the left hand brings the cup up to the grin, the head tips back, the cheeks puff, it comes down
    "drink": {"len": 1.1, "base": STILL, "keys": [
        (0.00, {}),
        (0.22, {"hL": (-0.26, 0.26, 1.2), "fL": (-0.1, 0.4, 0.9), "pL": (0.2, -0.9, 0.3)}, "out"),
        (0.42, {"hL": (-0.1, 0.3, 1.42), "fL": (0.0, -0.2, 1.0), "pL": (0.2, -0.9, 0.3), "head": (-32.0, 4.0, 8.0), "jaw": 10.0, "cheek": 1.0, "brow": -0.2}, "out"),
        (0.62, {"head": (-42.0, 4.0, 8.0), "hL": (-0.1, 0.32, 1.46), "jaw": 2.0, "cheek": 0.2, "lid": 1.0}),
        (0.80, {"head": (-30.0, 4.0, 8.0), "jaw": 8.0, "cheek": 1.0, "lid": 0.3}),
        (1.10, dict(STILL)),
    ]},
    # ---------------------------------------------------------------- one-shots
    "land": {"len": 0.4, "base": dict(STILL, spine=(24.0, 0.0, 0.0), head=(-20.0, 0.0, 6.0), hL=(-0.34, 0.08, 0.96), hR=(0.33, 0.14, 1.0), pld=(-10.0, -10.0), lift=(0.0, 0.0, -0.26), smoke=0.8), "keys": [
        (0.0, {}), (0.133, {"spine": (2.0, 0.0, 0.0), "lift": (0.0, 0.0, 0.06), "smoke": 0.0}, "out"), (0.267, {"lift": (0.0, 0.0, -0.03), "spine": (10.0, 0.0, 0.0)}), (0.4, dict(STILL, pld=(0.0, 0.0), lift=(0.0, 0.0, 0.0)))]},
    "hit": {"len": 0.35, "base": STILL, "keys": [
        (0.00, {}),
        (0.067, {"spine": (-16.0, 12.0, -8.0), "head": (-26.0, -22.0, -16.0), "hL": (-0.38, -0.05, 1.08), "hR": (0.38, 0.0, 1.12), "brow": 0.9, "lid": 0.0, "jaw": 10.0, "cheek": 0.0, "lift": (0.0, -0.1, -0.05), "box": (-5.0, 0.0)}, "snap"),
        (0.167, {"spine": (10.0, 6.0, 4.0), "head": (-6.0, -8.0, 16.0), "jaw": 4.0, "lift": (0.0, 0.05, -0.03), "box": (3.0, 0.0)}),
        (0.35, STILL),
    ]},
    # his emote: the lid slams, he is gone; a beat; bursts out with the deep flourish of a bow, and the silent cackle
    "emote": {"len": 2.4, "base": STILL, "add": laugh(14.0, 11.0, 1.3, 2.1), "keys": [
        (0.00, {}),
        (0.20, {"lift": (0.0, 0.0, -0.3), "smoke": 1.0, "cheek": 0.9}, "out"),
        (0.30, {"body": 0.02, "lidb": 1.0, "smoke": 0.0, "lift": (0.0, 0.0, -0.47)}, "in"),
        (0.80, {"crank": 0.0}),
        (0.90, {"lidb": 1.0}),
        (1.00, {"body": 1.06, "lidb": -0.3, "lift": (0.0, 0.0, 0.18), "smoke": 0.0, "hL": (-0.42, 0.14, 1.36), "fL": (-0.6, 0.3, 0.7), "pL": (0.0, 0.9, 0.3), "spine": (-8.0, 0.0, 0.0), "head": (-24.0, 0.0, -10.0), "brow": 0.5}, "snap"),
        (1.30, {"body": 1.0, "lidb": 0.0, "lift": (0.0, 0.1, -0.06), "spine": (46.0, 0.0, 0.0), "head": (-44.0, 0.0, 12.0), "hL": (-0.2, 0.38, 1.0), "fL": (0.3, 0.7, -0.6), "pL": (0.0, -0.3, 0.95), "hR": (0.34, -0.26, 1.06), "fR": (0.3, -0.6, 0.7), "brow": -1.0}),
        (1.60, {"spine": (46.0, 0.0, 0.0)}),
        (1.75, dict(STILL, spine=(-6.0, 0.0, 4.0), head=(-24.0, 0.0, 0.0), lift=(0.0, 0.0, 0.08), brow=0.6), "snap"),
        (2.1, {"spine": (2.0, 0.0, 6.0), "head": (-22.0, 0.0, -10.0), "lift": (0.0, 0.0, 0.0)}),
        (2.4, dict(STILL, jaw=0.0)),
    ]},
    # Fusion: wound down into the box, the orb taken in, flung open as the form takes him
    "fuse": {"len": 0.8, "base": STILL, "keys": [
        (0.00, {}),
        (0.17, CLENCH),
        (0.37, dict(CLENCH, hR=(0.03, 0.12, 1.14), hL=(-0.03, 0.12, 1.14), spine=(10.0, 0.0, 0.0), head=(-12.0, 0.0, 0.0), lift=(0.0, 0.0, -0.28))),
        (0.50, dict(SPREAD, lidb=-0.3, smoke=0.0, lift=(0.0, 0.0, 0.14)), "snap"),
        (0.63, {"spine": (-12.0, 0.0, 0.0), "wR": 0.2}),
        (0.80, dict(STILL, jaw=0.0, pld=(0.0, 0.0), lidb=0.0, lift=(0.0, 0.0, 0.0))),
    ]},
    # death: the spring gives, the jack folds down into his box, the lid drops shut on him
    "death": {"len": 1.6, "base": STILL, "keys": [
        (0.00, {}),
        (0.133, {"spine": (-14.0, 0.0, -6.0), "head": (-32.0, -14.0, 0.0), "brow": 1.0, "jaw": 12.0, "lid": 0.0, "hL": (-0.4, 0.05, 1.28), "hR": (0.4, 0.05, 1.34), "lift": (0.0, 0.0, 0.08)}, "snap"),
        (0.6, dict(DOWN, lidb=0.0), "in"),
        (0.8, {"spine": (28.0, 0.0, 9.0), "head": (28.0, 8.0, 16.0), "lift": (0.0, 0.0, -0.24)}),
        (1.25, {"spine": (40.0, 0.0, 12.0), "lift": (0.0, 0.0, -0.32), "body": 0.5}, "in"),
        (1.45, {"body": 0.02, "lidb": 1.0, "lift": (0.0, 0.0, -0.47)}, "in"),
        (1.6, {"body": 0.02, "lidb": 1.0}),
    ]},
}

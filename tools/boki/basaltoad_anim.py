"""Basaltoad's (Rampartoad's) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
placid cane toad with a castle wall on its back. Everything it does is slow and heavy: the throat pulses in a long
breath, it shuffles in short weighted steps, hops in a crouch and a thud, and its boulder heave sinks the whole
wall down and then pushes it up and out in one long effort."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.3  # a toad sits low and looks out level, unbothered


def shuffle(t, amp, lean):
    """A heavy waddle: every step the whole squat body shifts onto one side and sinks, then heaves up and over to
    the other; the wall on its back rocks a beat behind."""
    w = s(t, 1)
    dip = abs(s(t, 1, 0.25))
    p = {"root_at": (0, 0.012 * amp * (1 - dip), 0)}
    p["root_sc"] = (1 + 0.03 * amp * dip, 1 - 0.04 * amp * dip, 1)
    add(p, "root", rz=0.08 * amp * w, rx=-lean)
    add(p, "hips", ry=0.05 * amp * w)
    add(p, "spine", rz=-0.05 * amp * s(t, 1, -0.1), ry=-0.04 * amp * w)
    add(p, "head", rx=LOOK - 0.04 - 0.4 * lean, rz=-0.05 * amp * w)
    return p


def idle(t):
    """Squats and breathes: the throat swells and falls in a long slow pulse; every so often it sinks its head, blinks
    heavily and croaks once, deep, the whole body swelling with the note."""
    br = s(t, 1)
    croak = seq(t, [(0, 0), (0.6, 0), (0.72, 0.5), (0.78, 1), (0.9, 1), (0.96, 0), (1, 0)])
    sink = seq(t, [(0, 0), (0.3, 0), (0.38, 1), (0.5, 1), (0.58, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br + 0.05 * croak, 1 + 0.02 * br + 0.05 * croak - 0.03 * sink, 1 + 0.012 * br)}
    p["root_at"] = (0, -0.005 * sink, 0)
    add(p, "spine", rx=0.02 * br - 0.04 * sink)
    add(p, "head", rx=LOOK + 0.02 * br + 0.2 * croak - 0.12 * sink, ry=0.03 * s(t, 1, 0.3))
    return p


def walk(t):
    return shuffle(t, 1.0, 0.0)


def run(t):
    """A run is a string of short heavy hops: each one a quick squat, a low leap with the body stretched out, and a
    thud that squashes it flat before the next."""
    u = (t * 2.0) % 1.0
    air = seq(u, [(0, -0.6), (0.2, 0), (0.45, 1), (0.7, 0), (0.88, -1), (1, -0.6)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.07 * up, 0)}
    p["root_sc"] = (1 + 0.08 * down - 0.03 * up, 1 - 0.13 * down + 0.08 * up, 1 + 0.05 * down + 0.04 * up)
    add(p, "root", rx=-0.08 + 0.1 * (up - down), rz=0.03 * s(t, 1))
    add(p, "spine", rx=0.05 * up)
    add(p, "head", rx=LOOK - 0.1 + 0.08 * up - 0.06 * down)
    return p


def carry(t):
    return shuffle(t, 0.7, -0.03)


def lunge(t):
    """Attack: rocks back onto its haunches, throat swelling, then slams its whole weight forward in a flop and lets
    it settle."""
    wind = seq(t, [(0, 0), (0.36, 1), (0.46, 1), (0.5, 0), (1, 0)])
    slam = seq(t, [(0.44, 0), (0.54, 1), (0.64, 0.5), (0.84, 0), (1, 0)])
    p = {"root_at": (0, 0.012 * wind, 0.05 * wind - 0.15 * slam)}
    p["root_sc"] = (1 - 0.04 * wind + 0.08 * slam, 1 + 0.07 * wind - 0.14 * slam, 1 + 0.03 * wind + 0.08 * slam)
    add(p, "root", rx=0.2 * wind - 0.2 * slam)
    add(p, "spine", rx=0.08 * wind - 0.1 * slam)
    add(p, "head", rx=LOOK + 0.22 * wind - 0.28 * slam)
    return p


def heave(t):
    """Its boulder heave: sinks low and wide under the wall, shaking with the strain; then in one long push it
    straightens, throws its head up and the stone goes."""
    strain = seq(t, [(0, 0), (0.12, 0.3), (0.5, 1), (0.6, 1), (0.64, 0), (1, 0)])
    push = seq(t, [(0.58, 0), (0.7, 1), (0.82, 0.6), (1, 0)])
    shudder = s(t, 12) * strain * seq(t, [(0.2, 0), (0.45, 1)])
    p = {"root_at": (0, -0.018 * strain + 0.09 * push, 0.05 * push)}
    p["root_sc"] = (1 + 0.12 * strain - 0.06 * push + 0.01 * shudder, 1 - 0.16 * strain + 0.2 * push,
                    1 + 0.08 * strain - 0.04 * push)
    add(p, "root", rx=0.04 * strain - 0.3 * push, rz=0.02 * shudder)
    add(p, "spine", rx=0.1 * strain - 0.16 * push)
    add(p, "head", rx=LOOK - 0.12 * strain + 0.34 * push)
    return p


def leap(t):
    """Hop: a long crouch that swells it wide, a stretched low leap, a flat landing that squashes it and settles."""
    air = seq(t, [(0, 0), (0.28, -0.9), (0.44, 0.3), (0.56, 1), (0.7, 0.2), (0.8, -1), (0.9, -0.25), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.01 * down, 0)}
    p["root_sc"] = (1 + 0.12 * down - 0.03 * up, 1 - 0.2 * down + 0.08 * up, 1 + 0.08 * down + 0.05 * up)
    add(p, "root", rx=-0.1 * down + 0.15 * up)
    add(p, "head", rx=LOOK + 0.14 * up - 0.1 * down)
    return p


def gulp(t):
    """Eat: sits and does not move at all until the snap: the head flicks forward and down and the throat bulges as it
    swallows, then it blinks and sits still again."""
    snap = seq(t, [(0, 0), (0.14, 0), (0.2, 1), (0.27, 0), (1, 0)])
    swallow = seq(t, [(0, 0), (0.28, 0), (0.4, 1), (0.58, 0), (1, 0)])
    snap2 = seq(t, [(0, 0), (0.64, 0), (0.7, 1), (0.77, 0), (1, 0)])
    swallow2 = seq(t, [(0, 0), (0.78, 0), (0.88, 1), (1, 0)])
    sw = swallow + swallow2
    p = {"root_sc": (1 + 0.05 * sw, 1 + 0.07 * sw, 1)}
    add(p, "root", rx=-0.04 * (snap + snap2))
    add(p, "spine", rx=-0.08 * (snap + snap2))
    add(p, "head", rx=LOOK - 0.34 * (snap + snap2) + 0.2 * sw)
    return p


def sag(t):
    """Sleep: sags to the ground under its wall, flat and wide, the throat pulsing slow and the head sunk to its
    shoulders."""
    br = s(t, 1)
    p = {"root_at": (0, -0.012, 0), "root_sc": (1.12 + 0.01 * br, 0.8 + 0.03 * br, 1.08)}
    add(p, "spine", rx=-0.06)
    add(p, "head", rx=-0.26 + 0.015 * br, rz=0.05)
    return p


def lean_in(t):
    """Pet: unmoved for a long moment, then slowly leans its whole bulk towards the hand and blinks."""
    lean = seq(t, [(0, 0), (0.3, 0), (0.6, 1), (0.9, 1), (1, 0)])
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.04 * lean, 1 + 0.02 * lean)}
    add(p, "root", rz=0.05 * lean)
    add(p, "head", rx=LOOK + 0.02 * lean, rz=0.14 * lean, ry=0.06 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (4.2, True, idle),
        "walk": (1.2, True, walk),
        "run": (0.7, True, run),
        "hop": (1.1, True, leap),
        "carry": (1.3, True, carry),
        "pet": (3.0, True, lean_in),
        "attack": (0.95, False, lunge),
        "ability": (1.6, False, heave),
        "sleep": (5.0, True, sag),
        "eat": (2.4, True, gulp),
    }
)

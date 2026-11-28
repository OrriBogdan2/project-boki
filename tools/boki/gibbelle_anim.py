"""Gibbelle's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a gibbon with a temple
bell for a belly. It rolls along like a pendulum, swings through to clang the bell, and the bell rings on after."""
import math

import glomwort_anim
from boki_clips import LOOK_UP, TAU, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def ring(t, at, hz=9.0, decay=8.0):
    """The bell after a strike at `at`: a fast shiver that dies away."""
    x = t - at
    return math.exp(-x * decay) * math.sin(TAU * x * hz) if x > 0 else 0.0


def ring_sc(p, k, swell=0.0):
    """The belly swelling and shrinking with the ring `k`, over a steady `swell`."""
    p["root_sc"] = (1 + swell + 0.08 * k, 1 + 0.7 * swell - 0.06 * k, 1 + swell + 0.08 * k)


def pendulum(t, amp, bob):
    """The waddle: the body swings on its feet like a bell on its beam, the shoulders winding against the hips and
    the head staying level."""
    w = s(t, 1)
    p = {"root_at": (0.015 * amp * w, 0.5 * bob * (1 + s(t, 2)), 0)}
    add(p, "root", rz=0.11 * amp * w, ry=0.06 * amp * s(t, 1, 0.5))
    add(p, "spine", ry=-0.14 * amp * w)
    add(p, "hips", ry=0.1 * amp * w)
    add(p, "head", rx=LOOK + 0.04 * s(t, 2), ry=0.1 * amp * w, rz=-0.08 * amp * w)
    return p


def idle(t):
    br = s(t, 2)
    p = {}
    ring_sc(p, ring(t, 0.4, decay=14.0))
    add(p, "root", rz=0.04 * s(t, 1))
    add(p, "spine", rx=0.02 * br)
    add(p, "head", rx=LOOK + 0.05 * s(t, 2, 0.2), ry=0.18 * s(t, 1, 0.1) + 0.06 * s(t, 3), rz=0.06 * s(t, 1, 0.3))
    return p


def walk(t):
    return pendulum(t, 1.0, 0.014)


def run(t):
    """A lope: leaning in, the swing wider and quicker, every stride a hop on the beam."""
    p = pendulum(t, 1.7, 0.03)
    add(p, "root", rx=-0.1 + 0.04 * s(t, 2))
    add(p, "spine", rx=-0.08 * s(t, 2, 0.5))
    return p


def carry(t):
    p = pendulum(t, 0.8, 0.012)
    add(p, "spine", rx=0.1)
    return p


def clang(t):
    """Attack: winds its shoulders back, swings through and thrusts the bell belly into the target; the bell rings."""
    k = seq(t, [(0, 0), (0.3, 1), (0.4, -1), (0.58, -0.6), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    twist = seq(t, [(0, 0), (0.3, -0.4), (0.42, 0.35), (0.7, 0.1), (1, 0)])
    p = {"root_at": (0, 0.01 * up, 0.03 * up - 0.1 * down)}
    ring_sc(p, 0.9 * down + ring(t, 0.42))
    add(p, "root", rx=0.12 * up - 0.18 * down, ry=0.5 * twist)
    add(p, "spine", rx=0.35 * up - 0.3 * down, ry=twist)
    add(p, "head", rx=0.15 * up - 0.15 * down)
    return p


def sing(t):
    """Its call: head back, chest out, rocking side to side as it sings, the bell rung twice."""
    rise = seq(t, [(0, 0), (0.25, 1), (0.8, 1), (1, 0)])
    pulse = s(t, 5) * rise * 0.035
    p = {}
    ring_sc(p, ring(t, 0.3) + 0.8 * ring(t, 0.6), 0.06 * rise + pulse)
    add(p, "root", rz=0.07 * s(t, 1.5) * rise)
    add(p, "spine", rx=0.12 * rise)
    add(p, "head", rx=LOOK + 0.35 * rise, rz=0.06 * s(t, 1.5, 0.25) * rise)
    return p


def swing_hop(t):
    """Hop: a swing off the beam, rolling over to one side in the air and landing with the bell clanking."""
    air = seq(t, [(0, 0), (0.18, -0.5), (0.32, 0.3), (0.5, 1), (0.68, 0.3), (0.8, -0.5), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0.05 * s(t, 1), 0.2 * up - 0.05 * down, 0)}
    ring_sc(p, 0.5 * down)
    add(p, "root", rx=-0.15 * up, rz=0.25 * s(t, 1) * up)
    add(p, "spine", ry=0.3 * s(t, 1))
    add(p, "head", rx=LOOK + 0.1 * up, rz=-0.2 * s(t, 1) * up)
    return p


def curl(t):
    """Sleep: rolled up round its bell with its head tucked in, breathing slowly."""
    br = s(t, 1)
    p = {"root_at": (0, -0.015, 0), "root_sc": (1.04 + 0.02 * br, 0.9 + 0.03 * br, 1.04 + 0.02 * br)}
    add(p, "root", rx=-0.1)
    add(p, "spine", rx=-0.25)
    add(p, "head", rx=-0.4 + 0.01 * br, rz=0.1)
    return p


def pet(t):
    """Leans into a hand, swaying, the bell giving a soft tinkle."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    ring_sc(p, 0.25 * ring(t, 0.5, 12))
    add(p, "root", rz=0.06 * s(t, 1, 0.25))
    add(p, "spine", rx=0.05 + 0.05 * lean)
    add(p, "head", rx=LOOK + 0.08 + 0.1 * lean, rz=0.18 + 0.14 * lean, ry=0.1 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update({
    "idle": (2.6, True, idle),
    "walk": (0.8, True, walk),
    "run": (0.5, True, run),
    "hop": (0.8, True, swing_hop),
    "carry": (0.85, True, carry),
    "pet": (2.0, True, pet),
    "attack": (0.8, False, clang),
    "ability": (1.5, False, sing),
    "sleep": (3.4, True, curl),
})

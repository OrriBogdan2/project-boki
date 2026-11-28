"""Crofthollow's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a stout, hollow
little croft of a creature with leaves for ears and a sprout for a tail. Steady and not curious, it plods with the
roll of a haystack, shoulders its way into a fight and settles into the ground to sleep like a house at dusk."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def plod(t, amp, rate):
    """A haystack's plod: the whole body rolls forward over each stump, the shoulders swinging against the hips."""
    w = s(t, rate)
    p = {"root_at": (0, 0.008 * amp * s(t, 2 * rate, 0.25), 0)}
    p["root_sc"] = (1 - 0.015 * amp * s(t, 2 * rate), 1 + 0.02 * amp * s(t, 2 * rate), 1)
    add(p, "root", rz=0.07 * amp * w, rx=0.04 * amp * s(t, 2 * rate, 0.4))
    add(p, "spine", ry=0.1 * amp * w, rz=-0.04 * amp * w)
    add(p, "hips", ry=-0.1 * amp * w)
    add(p, "head", rx=LOOK - 0.04 * amp, ry=-0.08 * amp * s(t, rate, 0.3))
    return p


def idle(t):
    """Planted and patient, the whole body settling with a slow breath; now and then it gives a leafy shiver, as if
    a wind passed through it, and the head nods once."""
    br = s(t, 1)
    shiver = seq(t, [(0, 0), (0.55, 0), (0.58, 1), (0.64, -1), (0.7, 1), (0.76, -0.5), (0.82, 0), (1, 0)])
    nod = seq(t, [(0.3, 0), (0.36, 1), (0.44, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br + 0.008 * shiver, 1 + 0.018 * br, 1 + 0.012 * br + 0.008 * shiver)}
    add(p, "root", rz=0.012 * shiver)
    add(p, "spine", rx=0.015 * br)
    add(p, "head", rx=LOOK + 0.03 * s(t, 1, 0.2) - 0.1 * nod, ry=0.04 * s(t, 1, 0.5))
    return p


def walk(t):
    return plod(t, 1.0, 1)


def run(t):
    """A rolling, ungainly gallop: the body pitches forward and bounds on every stride, shoulders low."""
    p = plod(t, 1.7, 2)
    p["root_at"] = (0, 0.02 * abs(s(t, 2)), 0)
    add(p, "root", rx=-0.12)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.08)
    return p


def carry(t):
    return plod(t, 0.7, 1)


def barge(t):
    """Attack: lowers its shoulder and digs in, then drives it forward with the whole body in a straight shove."""
    dig = seq(t, [(0, 0), (0.32, 1), (0.42, 1), (0.5, 0), (1, 0)])
    drive = seq(t, [(0.4, 0), (0.54, 1), (0.7, 0.5), (0.9, 0), (1, 0)])
    p = {"root_at": (0, -0.02 * dig, -0.04 * dig + 0.12 * drive)}
    p["root_sc"] = (1 + 0.04 * dig - 0.03 * drive, 1 - 0.07 * dig - 0.02 * drive, 1 - 0.04 * dig + 0.08 * drive)
    add(p, "root", rx=-0.15 * dig + 0.25 * drive, rz=0.1 * dig - 0.1 * drive)
    add(p, "spine", rx=-0.1 * dig + 0.15 * drive)
    add(p, "head", rx=LOOK - 0.25 * dig - 0.2 * drive)
    return p


def rootshake(t):
    """Its E: stamps down twice like roots driving into the ground, then straightens and sends a shudder up through
    its leaves."""
    stamp = seq(t, [(0, 0), (0.15, 1), (0.25, 0), (0.4, 1), (0.5, 0), (0.55, 0), (1, 0)])
    up = seq(t, [(0.5, 0), (0.64, 1), (0.82, 0.4), (1, 0)])
    shudder = s(t, 12) * up
    p = {"root_at": (0, -0.02 * stamp + 0.05 * up, 0)}
    p["root_sc"] = (
        1 + 0.08 * stamp + 0.02 * shudder - 0.03 * up,
        1 - 0.1 * stamp + 0.14 * up,
        1 + 0.08 * stamp + 0.02 * shudder,
    )
    add(p, "root", rz=0.03 * shudder)
    add(p, "head", rx=LOOK - 0.12 * stamp + 0.3 * up)
    return p


def tumble_hop(t):
    """Hop: a stout little bounce, the body staying round and level, one squat before and a rocking settle after."""
    air = seq(t, [(0, 0), (0.25, -0.7), (0.45, 1), (0.62, 0.3), (0.74, -0.9), (0.88, 0.15), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.12 * up - 0.02 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down - 0.02 * up, 1 - 0.16 * down + 0.06 * up, 1 + 0.1 * down - 0.02 * up)
    add(p, "root", rz=0.07 * seq(t, [(0.45, 0), (0.6, 1), (0.8, -0.6), (1, 0)]))
    add(p, "head", rx=LOOK + 0.1 * up - 0.08 * down)
    return p


def sink(t):
    """Sleep: sinks into the ground like a croft at dusk, a slow breath, the head tipped and the leaves drooped."""
    br = s(t, 1)
    p = {"root_at": (0, -0.035, 0), "root_sc": (1.1 + 0.01 * br, 0.8 + 0.02 * br, 1.08 + 0.01 * br)}
    add(p, "spine", rx=-0.06)
    add(p, "head", rx=-0.35 + 0.01 * br, rz=0.12, ry=-0.2)
    return p


def graze(t):
    """Eat: shuffles down to the food and chews steadily, the whole body rocking with every grind."""
    dip = seq(t, [(0, 0), (0.18, 1), (0.82, 1), (1, 0)])
    chew = s(t, 6) * dip
    p = {"root_sc": (1 + 0.012 * chew, 1 - 0.02 * chew, 1)}
    add(p, "root", rx=-0.06 * dip)
    add(p, "spine", rx=-0.12 * dip)
    add(p, "head", rx=LOOK - 0.4 * dip + 0.05 * chew)
    return p


def pet(t):
    """It does not look up, but it settles under the hand and its whole body rocks slowly side to side."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.03 * lean, 1 + 0.02 * lean)}
    add(p, "root", rz=0.06 * s(t, 1, 0.25))
    add(p, "head", rx=LOOK - 0.1 * lean, rz=0.08 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.2, True, idle),
        "walk": (1.2, True, walk),
        "run": (0.65, True, run),
        "hop": (1.0, True, tumble_hop),
        "carry": (1.3, True, carry),
        "pet": (2.6, True, pet),
        "attack": (1.0, False, barge),
        "ability": (1.5, False, rootshake),
        "sleep": (4.4, True, sink),
        "eat": (2.2, True, graze),
    }
)

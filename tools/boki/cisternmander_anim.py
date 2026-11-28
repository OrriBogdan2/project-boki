"""Vatmander's (cisternmander) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
giant salamander with a water tower for a body. The water inside has weight of its own: it sloshes a beat behind every
move, so it wades in a slow side-to-side swing and heaves forward when it fights."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def slosh(p, t, amp, rate=1):
    """The tank squashes and stretches lengthwise as the water runs to one end and back."""
    w = s(t, rate, 0.25)
    p["root_sc"] = (1 - 0.02 * amp * w, 1 + 0.03 * amp * s(t, 2 * rate), 1 + 0.04 * amp * w)


def wade(t, amp, rate):
    """A salamander's wade: the body swings in an S, the head and the tail end opposite, the whole tank lurching
    over each planted side."""
    w = s(t, rate)
    p = {"root_at": (0, -0.006 * amp * abs(w), 0)}
    slosh(p, t, amp, rate)
    add(p, "root", rz=0.05 * amp * w)
    add(p, "hips", ry=0.16 * amp * w)
    add(p, "spine", ry=-0.1 * amp * w)
    add(p, "neck", ry=-0.1 * amp * s(t, rate, 0.2))
    add(p, "head", rx=LOOK, ry=-0.1 * amp * s(t, rate, 0.3))
    return p


def idle(t):
    """A tank at rest: the water settles in slow waves, a gill-flutter of tiny shudders, now and then the head swings
    slowly to look you over."""
    br = s(t, 1)
    look = seq(t, [(0, 0), (0.5, 0), (0.62, 1), (0.8, 1), (0.92, 0), (1, 0)])
    p = {"root_sc": (1 + 0.01 * br, 1 + 0.02 * br, 1 + 0.015 * s(t, 1, 0.3))}
    add(p, "spine", rx=0.015 * br, ry=0.05 * s(t, 1, 0.1))
    add(p, "head", rx=LOOK + 0.03 * s(t, 1, 0.2), ry=0.35 * look + 0.04 * s(t, 1, 0.5))
    return p


def walk(t):
    return wade(t, 1.0, 1)


def run(t):
    """A lumbering charge: the body leaned forward, the swing shortened and quick, water slapping the front."""
    p = wade(t, 1.5, 2)
    add(p, "root", rx=-0.1)
    add(p, "spine", rx=-0.08)
    add(p, "head", rx=-0.06)
    return p


def carry(t):
    return wade(t, 0.7, 1)


def surge(t):
    """Attack: rears back as the water drains to the rear, then throws the whole tank forward, the head and its
    weight following with a wet slap."""
    wind = seq(t, [(0, 0), (0.34, 1), (0.42, 1), (0.5, 0), (1, 0)])
    hit = seq(t, [(0.4, 0), (0.52, 1), (0.66, 0.4), (0.84, 0), (1, 0)])
    p = {"root_at": (0, 0.03 * wind - 0.012 * hit, -0.06 * wind + 0.14 * hit)}
    p["root_sc"] = (1 + 0.03 * wind - 0.05 * hit, 1 + 0.06 * wind - 0.08 * hit, 1 - 0.06 * wind + 0.1 * hit)
    add(p, "root", rx=0.12 * wind - 0.2 * hit)
    add(p, "spine", rx=0.1 * wind - 0.2 * hit)
    add(p, "head", rx=LOOK + 0.2 * wind - 0.35 * hit, ry=0.1 * wind)
    return p


def spout(t):
    """Its E: sinks as the tank fills, the body swelling and trembling, then shoots up tall in one gush and settles
    back in waves."""
    fill = seq(t, [(0, 0), (0.36, 1), (0.6, 1), (0.68, 0), (1, 0)])
    gush = seq(t, [(0.58, 0), (0.7, 1), (0.84, 0.2), (1, 0)])
    shake = s(t, 11) * fill
    p = {"root_at": (0, -0.02 * fill + 0.03 * gush, 0)}
    p["root_sc"] = (
        1 + 0.1 * fill + 0.015 * shake - 0.06 * gush,
        1 - 0.1 * fill + 0.2 * gush,
        1 + 0.08 * fill - 0.04 * gush,
    )
    add(p, "spine", rx=-0.08 * fill + 0.12 * gush)
    add(p, "head", rx=LOOK - 0.1 * fill + 0.4 * gush)
    return p


def heavy_hop(t):
    """Hop: heaves the tank off the ground in a long crouch and a low jump, water sloshing, a wet thud on landing."""
    air = seq(t, [(0, 0), (0.25, -0.8), (0.42, 0.3), (0.55, 1), (0.7, 0.25), (0.8, -1), (0.92, -0.15), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.02 * down, 0)}
    p["root_sc"] = (1 + 0.12 * down - 0.03 * up, 1 - 0.18 * down + 0.08 * up, 1 + 0.05 * down + 0.04 * up)
    add(p, "root", rx=0.12 * seq(t, [(0.3, 0), (0.55, 1), (0.8, -0.8), (1, 0)]))
    add(p, "head", rx=LOOK + 0.12 * up - 0.1 * down)
    return p


def settle(t):
    """Sleep: lowers itself flat onto the ground, chin down, the water barely rippling with each long breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.1 + 0.01 * br, 0.82 + 0.02 * br, 1.06 + 0.012 * br)}
    add(p, "root", rz=0.02 * s(t, 1, 0.3))
    add(p, "spine", rx=-0.05, ry=0.04 * s(t, 1, 0.1))
    add(p, "head", rx=-0.32 + 0.01 * br, ry=0.2 + 0.05 * s(t, 1, 0.45))
    return p


def drink(t):
    """Eat: lowers the head and sucks the food in with a slow draught, the tank swelling as it swallows."""
    dip = seq(t, [(0, 0), (0.18, 1), (0.6, 1), (0.74, 0), (1, 0)])
    gulp = seq(t, [(0.6, 0), (0.68, 1), (0.8, 0), (0.88, 0.6), (1, 0)])
    p = {"root_sc": (1 + 0.03 * gulp, 1 + 0.04 * gulp - 0.04 * dip, 1 + 0.02 * dip)}
    add(p, "spine", rx=-0.12 * dip)
    add(p, "neck", rx=-0.15 * dip)
    add(p, "head", rx=LOOK - 0.45 * dip + 0.12 * gulp, ry=0.04 * s(t, 2) * dip)
    return p


def pet(t):
    """Big and gentle under the hand: it lowers its head into the stroke, the water in it purring in slow ripples."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.02 * lean, 1 - 0.02 * lean, 1 + 0.03 * s(t, 2))}
    add(p, "head", rx=LOOK - 0.1 * lean, rz=0.12 * lean, ry=0.1 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.8, True, idle),
        "walk": (1.4, True, walk),
        "run": (0.75, True, run),
        "hop": (1.1, True, heavy_hop),
        "carry": (1.5, True, carry),
        "pet": (2.8, True, pet),
        "attack": (1.0, False, surge),
        "ability": (1.6, False, spout),
        "sleep": (4.8, True, settle),
        "eat": (2.4, True, drink),
    }
)

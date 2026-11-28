"""Geyserbara's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a huge, placid
capybara with a steam vent on its back. Unhurried and loyal: it waddles with its whole weight rolling from side to
side, never rushes, and sits down hard. The vent breathes with it, the steam lagging the body, and it builds to an
eruption: squats and rumbles, then shoots up tall with the plume."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def vent(p, t, amp, n=1.0):
    """The steam plume rides the back a beat behind the body (spine and hips roll against each other)."""
    add(p, "spine", rz=amp * s(t, n, -0.12), rx=0.5 * amp * s(t, n, -0.3))
    add(p, "hips", rz=-0.5 * amp * s(t, n, -0.05))


def idle(t):
    """Slow, heavy breaths, the head drifting half asleep; every so often the vent hiccups: the back arches and the
    head lifts as a puff of steam goes up."""
    br = s(t, 1)
    puff = seq(t, [(0, 0), (0.6, 0), (0.66, 1), (0.8, 0.3), (0.9, 0)])
    p = {"root_at": (0, 0.01 * puff, 0), "root_sc": (1 + 0.012 * br, 1 + 0.02 * br + 0.03 * puff, 1 + 0.012 * br)}
    vent(p, t, 0.02 + 0.03 * puff)
    add(p, "spine", rx=-0.06 * puff)
    add(p, "head", rx=LOOK + 0.04 * br + 0.12 * puff, ry=0.1 * s(t, 1, 0.2), rz=0.05 * s(t, 1, 0.5))
    return p


def c2(t):
    """1 at each footfall (twice a cycle), -1 between."""
    return seq(t % 0.5 * 2, [(0, 1), (0.25, -1), (0.6, -0.5), (1, 1)])


def waddle(t, amp, bounce):
    """A heavy side-to-side roll, one lurch per step: the body rolls onto its far side, the rump swings against the
    shoulders, and the head counter-rolls to stay level."""
    p = {"root_at": (0, bounce * abs(s(t, 2, 0.1)), 0)}
    p["root_sc"] = (1 + 0.025 * amp * c2(t), 1 - 0.035 * amp * c2(t), 1)
    add(p, "root", rz=0.07 * amp * s(t, 2), rx=-0.02 * amp)
    add(p, "hips", ry=0.1 * amp * s(t, 2, 0.25), rz=-0.04 * amp * s(t, 2))
    add(p, "spine", ry=-0.06 * amp * s(t, 2, 0.25))
    add(p, "head", rx=LOOK + 0.04 * amp * s(t, 4, 0.1), rz=-0.06 * amp * s(t, 2))
    vent(p, t, 0.05 * amp, 2)
    return p


def walk(t):
    return waddle(t, 1.0, 0.012)


def run(t):
    """A lumbering gallop: it throws its weight forward, the body rocking over each heavy bound, the steam trailing."""
    air = max(0.0, s(t, 2, 0.0))
    land = seq(t % 0.5 * 2, [(0, 0.5), (0.1, 1), (0.4, 0), (1, 0.5)])
    p = {"root_at": (0, 0.05 * air, -0.015 * land)}
    p["root_sc"] = (1 + 0.06 * land, 1 - 0.09 * land + 0.04 * air, 1 - 0.02 * land)
    add(p, "root", rx=0.06 * s(t, 2, 0.25), rz=0.04 * s(t, 1))
    add(p, "hips", rx=-0.1 * s(t, 2, 0.1), ry=0.06 * s(t, 1, 0.25))
    add(p, "spine", rx=0.1 * s(t, 2, 0.35))
    add(p, "head", rx=LOOK - 0.1 + 0.08 * s(t, 2, 0.4), rz=-0.03 * s(t, 1))
    vent(p, t, 0.1, 2)
    return p


def barge(t):
    """Attack: rocks back on its rump, then throws its whole bulk forward in a shoulder charge; the vent pops as it
    lands."""
    k = seq(t, [(0, 0), (0.3, 1), (0.42, -1), (0.62, -0.8), (1, 0)])
    wind = max(k, 0)
    hit = max(-k, 0)
    p = {"root_at": (0, 0.01 * wind, 0.04 * wind - 0.1 * hit)}
    p["root_sc"] = (1 - 0.05 * wind + 0.07 * hit, 1 + 0.07 * wind - 0.1 * hit, 1 - 0.04 * wind + 0.06 * hit)
    add(p, "root", rx=0.25 * wind - 0.2 * hit)
    add(p, "hips", rx=-0.1 * wind + 0.15 * hit)
    add(p, "spine", rx=0.1 * wind - 0.12 * hit)
    add(p, "head", rx=LOOK + 0.15 * wind - 0.3 * hit)
    vent(p, t, 0.1 * (wind + hit), 3)
    return p


def erupt(t):
    """Its E: squats and rumbles until the vent shakes, then shoots up tall, the head thrown back and the plume
    streaming, and sinks back down shuddering."""
    squat = seq(t, [(0, 0), (0.3, 1), (0.55, 1), (0.62, 0), (1, 0)])
    shoot = seq(t, [(0.55, 0), (0.68, 1), (0.82, 0.7), (1, 0)])
    rumble = s(t, 14) * (squat + 0.4 * shoot)
    p = {"root_at": (0, -0.025 * squat + 0.07 * shoot, 0)}
    p["root_sc"] = (1 + 0.12 * squat - 0.08 * shoot, 1 - 0.18 * squat + 0.2 * shoot, 1 + 0.12 * squat - 0.08 * shoot)
    add(p, "root", rz=0.04 * rumble, rx=0.1 * shoot)
    add(p, "spine", rz=-0.08 * rumble, rx=0.2 * shoot)
    add(p, "hips", ry=0.04 * rumble)
    add(p, "head", rx=LOOK - 0.15 * squat + 0.45 * shoot, rz=0.04 * rumble)
    return p


def heavy_hop(t):
    """Hop: a deep slow crouch, a short hang in the air with the vent flaring, and a thud that bounces the steam."""
    air = seq(t, [(0, 0), (0.28, -0.8), (0.46, 0.3), (0.58, 1), (0.72, 0.3), (0.82, -1), (0.92, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.13 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.13 * down - 0.03 * up, 1 - 0.2 * down + 0.06 * up, 1 + 0.09 * down)
    add(p, "root", rx=0.1 * seq(t, [(0.3, 0), (0.58, 1), (0.82, -0.6), (1, 0)]))
    vent(p, t, 0.08 * (up + down), 2)
    add(p, "head", rx=LOOK + 0.1 * up - 0.1 * down)
    return p


def pet(t):
    """It leans its whole weight into the hand, eyes closed, rumbling like a kettle coming up to the boil."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.03 * lean, 1)}
    add(p, "root", rz=0.05 * lean)
    add(p, "head", rx=LOOK + 0.1 * lean + 0.02 * s(t, 8), rz=0.2 * lean, ry=0.08 * lean)
    vent(p, t, 0.03 + 0.03 * lean, 3)
    return p


def carry(t):
    """A steadier, shorter waddle with the load, head held up."""
    p = waddle(t, 0.6, 0.008)
    add(p, "head", rx=0.1)
    return p


def eat(t):
    """Snout down on the berry, a slow grind of the jaw and a long swallow."""
    chew = 0.5 + 0.5 * s(t, 3)
    p = {"root_at": (0, -0.012, -0.02), "prop_berry": "on"}
    vent(p, t, 0.02, 3)
    add(p, "spine", rx=-0.12)
    add(p, "head", rx=-0.35 - 0.1 * chew, rz=0.04 * s(t, 3, 0.25))
    return p


def sit(t):
    """Sleep: it sinks onto its belly, the head on the ground, and every slow breath lets a thread of steam out."""
    br = s(t, 1)
    p = {"root_at": (0, -0.04, 0), "root_sc": (1.1 + 0.01 * br, 0.86 + 0.02 * br, 1.06)}
    add(p, "hips", rx=0.05)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.4 + 0.03 * br, ry=0.3, rz=0.1)
    vent(p, t, 0.015, 1)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.6, True, idle),
        "walk": (1.1, True, walk),
        "run": (0.7, True, run),
        "hop": (1.1, True, heavy_hop),
        "carry": (1.1, True, carry),
        "pet": (2.6, True, pet),
        "attack": (0.95, False, barge),
        "ability": (1.8, False, erupt),
        "sleep": (4.6, True, sit),
        "eat": (2.2, True, eat),
    }
)

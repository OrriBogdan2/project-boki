"""Kilnbadger's (Anvilbrock's) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
honey badger that stays low and swaggers like it is looking for a fight, headbutts with the red-hot anvil on its back
ringing behind it, and bristles up and rings the whole anvil as its ability."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
HEAD_LOW = -0.14  # the head carried lower than a Boki looks up from (rx): a glare from under the brow


def ring(p, t, rate, amp):
    """The anvil's ring: a fast shiver down the spine that the clip's own beat rides on."""
    add(p, "spine", rz=amp * s(t, rate), rx=0.4 * amp * s(t, rate, 0.25))


def swagger(t, amp):
    """Short quick steps, the low body rolling shoulder to shoulder, the head thrust out looking for trouble."""
    w = s(t, 1)
    p = {"root_at": (0, 0.008 * amp * s(t, 2), 0)}
    add(p, "root", rz=0.06 * amp * w, rx=0.02 * amp * s(t, 2, 0.5))
    add(p, "spine", ry=0.08 * amp * w, rx=-0.03 * amp * s(t, 2))
    add(p, "hips", ry=-0.07 * amp * w, rz=-0.03 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.6 + HEAD_LOW + 0.04 * amp * s(t, 2, 0.5), ry=-0.12 * amp * w)
    return p


def idle(t):
    """Hunched and glaring: breathing hard through its nose, the head swinging round to check each side, now and then
    a sharp shake and a stamp."""
    br = s(t, 2)
    shake = seq(t, [(0, 0), (0.7, 0), (0.73, 1), (0.77, -1), (0.81, 0.7), (0.85, -0.5), (0.9, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br, 1 + 0.02 * br, 1 + 0.012 * br)}
    add(p, "root", rz=0.05 * shake)
    add(p, "spine", rz=0.04 * shake)
    look = seq(t, [(0, 0), (0.2, 1), (0.4, 1), (0.55, -1), (0.7, -1), (1, 0)])
    add(p, "head", rx=LOOK_UP * 0.6 + HEAD_LOW + 0.03 * br, ry=0.3 * look)
    return p


def walk(t):
    return swagger(t, 1.0)


def run(t):
    """A bulldozing scurry: very low, the spine bunching and stretching each bound, head down like a ram."""
    p = swagger(t, 0.5)
    stride = s(t, 1)
    p["root_at"] = (0, 0.02 + 0.015 * s(t, 2), 0)
    add(p, "root", rx=-0.08, rz=0.04 * stride)
    add(p, "spine", rx=-0.16 * stride)
    add(p, "hips", rx=0.13 * stride)
    add(p, "head", rx=-0.3 + 0.08 * s(t, 1, 0.2))
    return p


def carry(t):
    p = swagger(t, 0.8)
    add(p, "head", rx=0.1)
    return p


def headbutt(t):
    """Attack: backs off a step, lowers its head, drives it forward into whatever stands there and the anvil rings
    on the stop."""
    wind = seq(t, [(0, 0), (0.28, 1), (0.4, 0), (1, 0)])
    drive = seq(t, [(0.28, 0), (0.4, 1), (0.52, 1), (0.8, 0.2), (1, 0)])
    stop = seq(t, [(0, 0), (0.42, 0), (0.46, 1), (0.54, -0.8), (0.62, 0.5), (0.7, -0.3), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0, 0.07 * wind - 0.16 * drive)}
    p["root_sc"] = (1, 1 - 0.07 * wind, 1 + 0.06 * drive)
    add(p, "root", rx=-0.1 * wind - 0.08 * drive)
    add(p, "hips", rx=0.15 * wind)
    add(p, "spine", rx=-0.12 * wind - 0.12 * drive)
    add(p, "head", rx=-0.3 * wind - 0.4 * drive)
    ring(p, t, 14, 0.07 * abs(stop))
    return p


def clang(t):
    """Its E: rears up bristling, then slams down and the anvil rings out, shuddering the whole badger."""
    k = seq(t, [(0, 0), (0.35, 1), (0.45, 1), (0.52, -1), (0.7, -0.3), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    peal = seq(t, [(0, 0), (0.52, 0), (0.56, 1), (0.75, 0.6), (0.95, 0.15), (1, 0)])
    p = {"root_at": (0, 0.05 * up, 0.04 * up - 0.03 * down)}
    p["root_sc"] = (1 + 0.1 * down + 0.04 * up, 1 - 0.14 * down + 0.06 * up, 1 + 0.06 * down + 0.04 * up)
    add(p, "root", rx=0.45 * up - 0.04 * down)
    add(p, "hips", rx=-0.08 * up)
    add(p, "spine", rx=0.12 * up - 0.12 * down)
    add(p, "head", rx=0.15 * up - 0.3 * down)
    ring(p, t, 16, 0.09 * peal)
    return p


def stomp_hop(t):
    """Hop: a quick tight spring, head down, an indignant little stamp on landing."""
    air = seq(t, [(0, 0), (0.18, -0.7), (0.34, 0.4), (0.5, 1), (0.66, 0.3), (0.76, -1), (0.88, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.13 * up - 0.04 * down, 0)}
    p["root_sc"] = (1 + 0.14 * down - 0.03 * up, 1 - 0.2 * down + 0.07 * up, 1 + 0.08 * down)
    add(p, "root", rx=0.08 * up - 0.06 * down)
    add(p, "spine", rx=0.08 * up - 0.1 * down)
    add(p, "head", rx=LOOK_UP * 0.6 + HEAD_LOW + 0.12 * up - 0.1 * down)
    return p


def gnash(t):
    """Eat: wolfs it down, head jerking at the food, nose scrunched and snorting."""
    p = eat_ground(t)
    add(p, "spine", rx=-0.14)
    add(p, "head", rx=-0.06 + 0.1 * s(t, 5), ry=0.1 * s(t, 5, 0.25))
    return p


def sulk(t):
    """Sleep: curled flat on its belly, head on its paws, one grumpy snort now and then."""
    br = s(t, 1)
    snort = seq(t, [(0, 0), (0.78, 0), (0.82, 1), (0.88, 0), (1, 0)])
    p = {"root_at": (0, -0.09, 0), "root_sc": (1.1 + 0.02 * br, 0.8 + 0.03 * br + 0.03 * snort, 1.04)}
    add(p, "spine", rx=-0.06)
    add(p, "head", rx=-0.32 + 0.01 * br - 0.05 * snort, ry=0.2, rz=0.1)
    return p


def pet(t):
    """Puts up with it: leans into the hand for a moment, then jerks back, grumpy, and leans again."""
    lean = max(s(t, 1), -0.3)
    p = {}
    add(p, "root", rz=0.05 * lean)
    add(p, "head", rx=LOOK_UP * 0.3 + HEAD_LOW + 0.05 * lean, rz=0.16 * lean, ry=0.08 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.0, True, idle),
        "walk": (0.8, True, walk),
        "run": (0.44, True, run),
        "hop": (0.85, True, stomp_hop),
        "carry": (0.9, True, carry),
        "pet": (2.0, True, pet),
        "attack": (0.8, False, headbutt),
        "ability": (1.4, False, clang),
        "sleep": (4.0, True, sulk),
        "eat": (1.8, True, gnash),
    }
)

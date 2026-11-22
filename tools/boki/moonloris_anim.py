"""Moonloris's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a slow loris with a
paper lantern for a belly. It moves with deliberate, hand-over-hand patience, the big-eyed head turning to look at
everything, then strikes in a flash; when it is scared it floats up like a balloon."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def clamber(t, amp):
    """The loris creep: each side reaches and takes hold in turn, the body leaning over the held side and sinking a
    little, the head swinging round to look where the next hold is."""
    w = s(t, 1)
    p = {"root_at": (0, -0.006 * amp * abs(w), 0)}
    add(p, "root", rz=0.07 * amp * w, rx=0.02 * amp * s(t, 2))
    add(p, "spine", rz=-0.05 * amp * w, ry=0.08 * amp * w)
    add(p, "hips", ry=-0.1 * amp * w)
    add(p, "head", rx=LOOK + 0.03 * amp * s(t, 2, 0.3), ry=-0.16 * amp * s(t, 1, 0.25))
    return p


def idle(t):
    """Drowsy: the head droops and sways, then jerks up wide awake, blinks round the room and slowly sinks again."""
    br = s(t, 1)
    start = seq(t, [(0, 0), (0.6, 0), (0.64, 1), (0.74, 1), (0.9, 0.2), (1, 0)])
    p = {"root_sc": (1 + 0.02 * br, 1 + 0.03 * br, 1 + 0.02 * br)}
    add(p, "spine", rx=0.03 * br - 0.03 * (1 - start))
    add(p, "head", rx=LOOK - 0.12 * (1 - start) + 0.1 * start, ry=0.22 * s(t, 1, 0.1) * start + 0.05 * s(t, 1))
    return p


def walk(t):
    return clamber(t, 1.0)


def run(t):
    """A hurried scurry: still the same grip-and-reach, but quick, the body hunched low and the head forward."""
    p = clamber(t, 0.8)
    stride = s(t, 2)
    p["root_at"] = (0, 0.012 * stride, 0)
    add(p, "root", rx=-0.12)
    add(p, "spine", rx=-0.1 + 0.06 * stride)
    add(p, "head", rx=-0.05)
    return p


def carry(t):
    p = clamber(t, 0.7)
    add(p, "head", rx=0.06)
    return p


def snap(t):
    """Attack: a long, patient freeze with the head drawn back, then a bite so quick it is over before it shows."""
    freeze = seq(t, [(0, 0), (0.45, 1), (0.6, 1), (0.64, 0), (1, 0)])
    bite = seq(t, [(0.58, 0), (0.66, 1), (0.78, 0.2), (1, 0)])
    p = {"root_at": (0, -0.01 * freeze, -0.03 * freeze + 0.09 * bite)}
    p["root_sc"] = (1 + 0.02 * freeze - 0.03 * bite, 1 - 0.03 * freeze, 1 - 0.02 * freeze + 0.07 * bite)
    add(p, "root", rx=0.1 * freeze - 0.25 * bite)
    add(p, "spine", rx=0.15 * freeze - 0.3 * bite)
    add(p, "head", rx=LOOK + 0.2 * freeze - 0.45 * bite)
    return p


def moon_mark(t):
    """Its mark: rises on tiptoe, the lantern belly swelling bright, the head tipping back to the sky, then settles
    and points the whole body at what it marked."""
    rise = seq(t, [(0, 0), (0.35, 1), (0.7, 1), (0.85, 0), (1, 0)])
    point = seq(t, [(0.6, 0), (0.72, 1), (0.9, 0.4), (1, 0)])
    glow = s(t, 3) * rise
    p = {"root_at": (0, 0.07 * rise, 0)}
    p["root_sc"] = (1 + 0.05 * rise + 0.015 * glow, 1 + 0.06 * rise + 0.02 * glow, 1 + 0.05 * rise + 0.015 * glow)
    add(p, "spine", rx=0.18 * rise - 0.3 * point)
    add(p, "head", rx=LOOK + 0.4 * rise - 0.5 * point, ry=0.15 * s(t, 1) * rise)
    return p


def balloon_hop(t):
    """Hop: not a jump but a float: a small push, a long hang in the air with the body round and the head tipped
    up, and a soft sinking landing."""
    air = seq(t, [(0, 0), (0.18, -0.4), (0.38, 1), (0.62, 1), (0.82, 0.1), (0.9, -0.25), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.14 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.05 * up + 0.06 * down, 1 + 0.04 * up - 0.1 * down, 1 + 0.05 * up + 0.06 * down)
    add(p, "root", rx=-0.06 * up, rz=0.05 * s(t, 1.5) * up)
    add(p, "head", rx=LOOK + 0.1 * up - 0.08 * down, ry=0.1 * s(t, 1) * up)
    return p


def curl_up(t):
    """Sleep: rolled into a ball by day, the head tucked down on its chest, the lantern belly dimming and glowing
    with every slow breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.04 + 0.025 * br, 0.86 + 0.03 * br, 1.04 + 0.025 * br)}
    add(p, "spine", rx=-0.2)
    add(p, "head", rx=-0.4, rz=0.1)
    return p


def pet(t):
    """Wraps itself round the hand and clings, head tucked in, trembling a little."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.03 * lean, 1 + 0.03 * lean)}
    add(p, "root", rz=0.05 * lean)
    add(p, "spine", rx=0.05 + 0.05 * lean)
    add(p, "head", rx=LOOK - 0.1 * lean, rz=0.2 * lean, ry=0.12 * s(t, 2) * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.6, True, idle),
        "walk": (1.6, True, walk),
        "run": (0.8, True, run),
        "hop": (1.2, True, balloon_hop),
        "carry": (1.6, True, carry),
        "pet": (2.4, True, pet),
        "attack": (1.1, False, snap),
        "ability": (1.6, False, moon_mark),
        "sleep": (4.4, True, curl_up),
    }
)

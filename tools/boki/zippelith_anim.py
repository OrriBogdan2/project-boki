"""Zippelith's skeleton and clips (caecilith). The serpent rig (Zephyrak's chain: hips, spine, neck, head out one way,
tail1..N the other) on the ground: the front half stands up in a column, the tail lies flat behind it. The shared clips
are for legs, so all are its own. Column bones lean with rz (sideways) and rx (rx > 0 tips the top back); tail bones
on the ground swing with ry and lift with rx < 0."""
import math

import boki_clips
import zippelith
from boki_clips import LOOK_UP, add, ease, s, seq
from zippelith import SPINE

TAIL_N = zippelith.TAIL_N
boki_clips.TAIL_N = TAIL_N
COLUMN = ("hips", "spine", "neck")
TAILS = ["tail%d" % (i + 1) for i in range(TAIL_N)]


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": (tuple(SPINE[3]), tuple(SPINE[2]), "root"),
        "spine": (tuple(SPINE[2]), tuple(SPINE[1]), "hips"),
        "neck": (tuple(SPINE[1]), tuple(SPINE[0]), "spine"),
        "head": (tuple(SPINE[0]), tuple(zippelith.HEAD_TOP), "neck"),
        "prop_axe": (tuple(zippelith.GRIP), tuple(zippelith.GRIP + zippelith.AXIS * 0.1), "head"),
        "prop_pick": (tuple(zippelith.GRIP), tuple(zippelith.GRIP + zippelith.AXIS * 0.1), "head"),
        "prop_berry": (tuple(zippelith.BERRY_C), tuple(zippelith.BERRY_C + zippelith.v3(0, 0.1, 0)), "root"),
    }
    parent = "hips"
    for i, n in enumerate(TAILS):
        b[n] = (tuple(SPINE[3 + i]), tuple(SPINE[4 + i]), parent)
        parent = n
    b.update(boki_clips.part_bones(zippelith.grown_parts()))
    return b


BONES = _bones()


def sway(p, t, amp, waves=1.0, lag=0.11, grow=1.6, tail_amp=None):
    """A wave sent from the head down the body: the column leans side to side, the tail swings on the ground."""
    for i, bone in enumerate(reversed(COLUMN)):
        add(p, bone, rz=amp * 0.6 * s(t, waves, -i * lag))
    ta = amp if tail_amp is None else tail_amp
    for i, bone in enumerate(TAILS):
        k = 1 + grow * i / max(TAIL_N - 1, 1)
        add(p, bone, ry=ta * k * s(t, waves, -(i + 3) * lag))
    add(p, "head", rz=-amp * 0.5 * s(t, waves, -2 * lag))


def lean(p, back=0.0, curl=0.0):
    """back > 0 tips the column back (its face up), < 0 bows it forward; curl rolls the top of it over more."""
    add(p, "hips", rx=back * 0.5)
    add(p, "spine", rx=back * 0.3 + curl * 0.4)
    add(p, "neck", rx=back * 0.2 + curl * 0.6)


def tail_lift(p, amp):
    """Raises the tail end off the ground (amp > 0), most at the pull tag."""
    for i, bone in enumerate(TAILS):
        add(p, bone, rx=-amp * (0.2 + i / max(TAIL_N - 1, 1)) * 0.5)


def idle(t):
    """Stands tall and sways a little, looking up, the pull tag ticking behind it."""
    p = {}
    sway(p, t, 0.035, tail_amp=0.02)
    lean(p, back=0.02 * s(t, 2, 0.1))
    add(p, "head", rx=LOOK_UP * 0.5 + 0.03 * s(t, 2, -0.1), ry=0.08 * s(t, 1, 0.25))
    add(p, TAILS[-1], rx=-0.12 * max(s(t, 2, 0.3), 0))
    p["root_sc"] = (1 + 0.012 * s(t, 2), 1 - 0.015 * s(t, 2), 1)
    return p


def _slither(t, amp, bob, pitch, waves=1.0):
    p = {}
    sway(p, t, amp, waves=waves)
    lean(p, back=-pitch + 0.03 * s(t, 2 * waves))
    add(p, "head", rx=LOOK_UP * 0.35 + pitch * 0.6, ry=-amp * 0.8 * s(t, waves, 0.1))
    p["root_at"] = (0, bob * max(s(t, 2 * waves), 0), 0)
    p["root_sc"] = (1, 1 - 0.03 * s(t, 2 * waves, 0.25), 1 + 0.04 * s(t, 2 * waves, 0.25))
    return p


def walk(t):
    """Slithers: an S down the body, the column rocking over it."""
    return _slither(t, 0.16, 0.01, 0.05)


def run(t):
    """Low and fast: bowed forward, a quicker, fuller S."""
    p = _slither(t, 0.22, 0.02, 0.32)
    tail_lift(p, 0.05)
    return p


def hop(t):
    """A happy spring off its tail: coils down, pops up straight, grinning, lands in a squash."""
    p = {}
    air = seq(t, [(0, 0), (0.2, -0.8), (0.32, 0.3), (0.5, 1), (0.68, 0.3), (0.8, -0.6), (1, 0)])
    up, down = max(air, 0), max(-air, 0)
    lean(p, back=-0.1 * down, curl=0.25 * down)
    tail_lift(p, 0.4 * up)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.25 * up - 0.15 * down, rz=0.2 * s(t, 1) * up)
    p["root_at"] = (0, 0.24 * up, 0)
    p["root_sc"] = (1 + 0.1 * down - 0.04 * up, 1 - 0.18 * down + 0.08 * up, 1 + 0.05 * down)
    return p


def sleep(t):
    """Lies down along the ground in a curl, its chin on its tail, breathing slow."""
    br = s(t, 1)
    p = {}
    add(p, "hips", rx=-0.55, ry=0.5)
    add(p, "spine", rx=-0.55, ry=0.45)
    add(p, "neck", rx=-0.35, ry=0.4)
    add(p, "head", rx=0.45 + 0.02 * br, rz=0.3)
    for i, bone in enumerate(TAILS):
        add(p, bone, ry=0.32 + 0.04 * i)
    p["root_at"] = (0, 0.004 * br, 0.03)
    p["root_sc"] = (1 + br * 0.015, 1 + br * 0.025, 1)
    return p


def eat(t):
    """Bows its column down to the berry on the ground three times, nibbling, rising half up between."""
    p = {}
    dart = seq(t, [(0, 0.3), (0.08, 1), (0.25, 1), (0.33, 0.35), (0.41, 1), (0.58, 1), (0.66, 0.35), (0.74, 1),
                   (0.91, 1), (1, 0.3)])
    chomp = (0.5 + 0.5 * s(t, 9)) * ease((dart - 0.6) / 0.4)
    lean(p, back=-0.75 * dart, curl=0.3 * dart)
    add(p, "head", rx=-0.25 * dart - 0.1 * chomp)
    sway(p, t, 0.02)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans its head into the hand, eyes shut, the pull tag wiggling fast."""
    p = {}
    k = 0.5 + 0.5 * s(t, 1)
    add(p, "spine", rz=0.08 * k)
    add(p, "neck", rx=0.06 + k * 0.05, rz=0.12 * k)
    add(p, "head", rx=LOOK_UP * 0.6 + k * 0.06, rz=0.22 + k * 0.18, ry=0.12 * k)
    for i, bone in enumerate(TAILS):
        w = 0.15 + 0.85 * i / max(TAIL_N - 1, 1)
        add(p, bone, ry=0.2 * w * math.sin(math.tau * (4 * t - i * 0.1)))
    return p


def attack(t):
    """A head-butt bite: rears back, snaps the column forward, settles."""
    p = {}
    wind = seq(t, [(0, 0), (0.3, 1), (0.42, -1), (0.56, -1), (1, 0)])
    back, out = max(wind, 0), max(-wind, 0)
    lean(p, back=0.35 * back - 0.6 * out, curl=0.2 * back)
    add(p, "head", rx=0.2 * back - 0.25 * out)
    p["root_at"] = (0, 0, 0.05 * back - 0.12 * out)
    tail_lift(p, 0.15 * back)
    return p


def ability(t):
    """Moon Swap: shivers, unzips a seam and dives into it head first, gone, then pops up somewhere else."""
    p = {}
    shake = seq(t, [(0, 0), (0.15, 1), (0.25, 0), (1, 0)]) * s(t, 16)
    dive = seq(t, [(0, 0), (0.2, 0), (0.42, 1), (0.6, 1), (0.82, 0), (1, 0)])
    rise = seq(t, [(0, 0), (0.6, 0), (0.78, 1), (0.9, -0.3), (1, 0)])
    lean(p, back=-1.1 * dive + 0.2 * rise, curl=0.3 * dive)
    add(p, "hips", rz=0.08 * shake)
    tail_lift(p, 0.6 * dive)
    p["root_at"] = (0, -0.42 * dive, -0.08 * dive)
    p["root_sc"] = (1 - 0.15 * dive + 0.06 * max(rise, 0), 1 + 0.1 * max(rise, 0) - 0.08 * max(-rise, 0), 1)
    add(p, "head", rx=0.3 * max(rise, 0) - 0.2 * dive, rz=0.15 * shake)
    return p


def mouth_tool(t, keys, tool, rear, dip):
    """A tool in its teeth: rears the column back, then brings it down hard on the work."""
    p = {}
    v = seq(t, keys)
    up, down = max(v, 0), max(-v, 0)
    lean(p, back=rear * up - dip * down, curl=0.25 * down)
    add(p, "head", rx=LOOK_UP * 0.3 + up * 0.2 - down * dip * 0.6)
    tail_lift(p, 0.1 * up)
    p["root_at"] = (0, 0, 0.02 * up - 0.04 * down)
    p[tool] = "on"
    return p


def chop(t):
    return mouth_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.45, 0.8)


def mine(t):
    return mouth_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.4, 0.9)


def carry(t):
    """Slithers home with the load riding on its back, head up and pleased."""
    p = _slither(t, 0.1, 0.006, 0.0)
    add(p, "head", rx=0.1)
    return p


def tend(t):
    """Any other farm job: bowed over the work, nudging it, the tag ticking along."""
    p = {}
    bob = s(t, 2)
    lean(p, back=-0.6 + 0.08 * bob, curl=0.2)
    add(p, "head", rx=-0.15 + bob * 0.08, ry=0.12 * s(t, 1))
    sway(p, t, 0.02)
    return p


CLIPS = {
    "idle": (2.8, True, idle), "walk": (0.9, True, walk), "run": (0.55, True, run), "hop": (1.0, True, hop),
    "sleep": (3.4, True, sleep), "eat": (2.0, True, eat), "pet": (2.2, True, pet), "attack": (0.8, False, attack),
    "ability": (1.4, False, ability), "chop": (1.1, True, chop), "mine": (1.0, True, mine), "carry": (0.9, True, carry),
    "tend": (1.3, True, tend),
}
HIDE_AT = {"prop_berry": (0, 0.10, 0.28)}

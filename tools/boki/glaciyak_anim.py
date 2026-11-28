"""Prowyak's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head, plus the file's legs):
a yak with an icebreaker's iron prow for horns. Steady and warm-hearted, it never hurries and never stops: head low,
shoulders rolling, it ploughs through whatever is in front of it. It scrapes the ground with a front hoof, snorts
frost, and sleeps folded down like a haystack."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq
from vespyx_sides import SIDES

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4
PLOUGH = -0.3  # the prow carried low: how far the head hangs below the line of the back when it works


def idle(t):
    """Chewing slowly with its head low, the shaggy coat rising with each breath; now and then it scrapes the snow
    with one front hoof, and lifts its head in a snort of frost."""
    br = s(t, 2)
    scrape = seq(t, [(0.2, 0), (0.26, 1), (0.34, 0.2), (0.4, 1), (0.48, 0)])
    snort = seq(t, [(0.66, 0), (0.7, -0.5), (0.76, 1), (0.84, 1), (0.94, 0), (1, 0)])
    p = {"root_at": (0, 0.003 * br, 0), "root_sc": (1 + 0.01 * br, 1 + 0.02 * br, 1 + 0.01 * br)}
    add(p, "spine", rx=-0.02 + 0.03 * snort)
    add(p, "head", rx=LOOK + PLOUGH * 0.4 + 0.5 * snort + 0.02 * s(t, 5), ry=0.12 * s(t, 1, 0.1) * (1 - snort))
    add(p, "fleg1.L", rx=-0.5 * scrape)
    add(p, "fleg2.L", rx=0.5 * scrape)
    add(p, "fpaw.L", rx=-0.3 * scrape)
    add(p, "root", rx=0.02 * scrape)
    return p


def plough(t):
    """Attack: rears the prow up and back, then drops it and charges: head down and shoulders heaving, ploughing a
    furrow, and flings its head up to toss whatever it caught."""
    k = seq(t, [(0, 0), (0.28, 1), (0.42, -1), (0.62, -1), (0.76, 0.6), (1, 0)])
    wind = max(k, 0)
    hit = max(-k, 0)
    toss = max(k, 0) * seq(t, [(0.6, 0), (0.76, 1), (1, 0)])
    p = {"root_at": (0, 0.02 * wind - 0.01 * hit, 0.03 * wind - 0.12 * hit)}
    p["root_sc"] = (1 - 0.03 * wind + 0.04 * hit, 1 + 0.04 * wind - 0.06 * hit, 1 - 0.02 * wind + 0.06 * hit)
    add(p, "root", rx=0.12 * wind - 0.1 * hit)
    add(p, "spine", rx=0.05 * wind - 0.1 * hit)
    add(p, "head", rx=LOOK + 0.3 * wind + (PLOUGH - 0.1) * hit + 0.5 * toss)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-0.25 * wind + 0.5 * hit)
        add(p, "fleg2." + sd, rx=0.2 * wind - 0.2 * hit)
        add(p, "hleg1." + sd, rx=0.15 * wind - 0.3 * hit)
        add(p, "hleg2." + sd, rx=-0.15 * wind + 0.2 * hit)
    return p


def icebreak(t):
    """Its E: stamps one front hoof, then the other, rears its head back and snorts a plume of frost, then drives
    the prow down and forward like a ship's bow through ice."""
    stamp = {"L": seq(t, [(0.05, 0), (0.14, 1), (0.22, 0), (1, 0)]), "R": seq(t, [(0.2, 0), (0.29, 1), (0.37, 0), (1, 0)])}
    snort = seq(t, [(0.38, 0), (0.55, 1), (0.64, 1), (0.7, 0), (1, 0)])
    drive = seq(t, [(0.62, 0), (0.7, 1), (0.84, 0.8), (1, 0)])
    p = {"root_at": (0, -0.012 * snort + 0.01 * (stamp["L"] + stamp["R"]), -0.1 * drive)}
    p["root_sc"] = (1 + 0.04 * snort + 0.04 * drive, 1 - 0.04 * snort - 0.06 * drive, 1)
    add(p, "root", rx=0.12 * snort - 0.12 * drive, rz=0.03 * (stamp["R"] - stamp["L"]))
    add(p, "spine", rx=0.08 * snort - 0.1 * drive)
    add(p, "head", rx=LOOK + 0.5 * snort + (PLOUGH - 0.15) * drive + 0.04 * s(t, 14) * snort)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.5 * stamp[sd] + 0.3 * drive)
        add(p, "fleg2." + sd, rx=-0.6 * stamp[sd])
        add(p, "fpaw." + sd, rx=0.3 * stamp[sd])
        add(p, "hleg1." + sd, rx=-0.2 * drive)
    return p


def lumber_hop(t):
    """Hop: a deep settle, then front hooves up first and the heavy rump after, and a thud that rolls the shaggy
    coat."""
    air = seq(t, [(0, 0), (0.28, -0.8), (0.46, 0.3), (0.58, 1), (0.72, 0.3), (0.82, -1), (0.92, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.08 * down, 1 - 0.14 * down + 0.04 * up, 1 + 0.06 * down)
    add(p, "root", rx=0.1 * seq(t, [(0.3, 0), (0.58, 1), (0.82, -0.6), (1, 0)]))
    add(p, "head", rx=LOOK + 0.1 * up - 0.1 * down)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.6 * up - 0.2 * down)
        add(p, "fleg2." + sd, rx=-0.7 * up)
        add(p, "hleg1." + sd, rx=-0.4 * up + 0.2 * down)
        add(p, "hleg2." + sd, rx=0.4 * up)
    return p


def pet(t):
    """It lowers the heavy prow into the hand and leans its weight on it, snuffing warm frosty breaths."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.02 * lean, 1 - 0.02 * lean, 1)}
    add(p, "root", rz=0.04 * lean)
    add(p, "head", rx=LOOK + PLOUGH * 0.3 * lean + 0.02 * s(t, 5), rz=0.14 * lean, ry=0.1 * lean)
    return p


def carry(t):
    """Walks on with the load, head up and steady."""
    p = {"root_sc": (1, 1 + 0.01 * s(t, 2), 1)}
    add(p, "head", rx=0.1 + 0.03 * s(t, 2, 0.2))
    return p


def graze(t):
    """Head down to the berry, tearing it with slow, even bites, ears and shaggy fringe swaying."""
    chew = 0.5 + 0.5 * s(t, 3)
    p = {"root_at": (0, -0.005, -0.015), "prop_berry": "on"}
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.55 - 0.08 * chew, ry=0.06 * s(t, 3, 0.25))
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.1)
    return p


def haystack(t):
    """Sleep: folds its legs and sinks down in a heap, the prow resting on the ground, breathing slow under its coat."""
    br = s(t, 1)
    p = {"root_at": (0, -0.1, 0), "root_sc": (1.04 + 0.01 * br, 0.96 + 0.02 * br, 1.03)}
    add(p, "spine", rx=-0.05)
    add(p, "head", rx=-0.55 + 0.03 * br, ry=0.4, rz=0.12)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.2, rz=-sx * 0.1)
        add(p, "fleg2." + sd, rx=-2.0)
        add(p, "fpaw." + sd, rx=0.8)
        add(p, "hleg1." + sd, rx=0.8, rz=-sx * 0.12)
        add(p, "hleg2." + sd, rx=-1.2)
        add(p, "hpaw." + sd, rx=0.4)
    return p


def gait(t, amp):
    """Walk and run on top of the planted-paw trot (`gait_layer.py`): the prow carried low and nodding with each
    stride, the shoulders rolling, the back swaying against the rump."""
    p = {}
    add(p, "root", rz=0.025 * amp * s(t, 1))
    add(p, "hips", ry=-0.05 * amp * s(t, 1, 0.25))
    add(p, "spine", ry=0.05 * amp * s(t, 1, 0.25), rx=0.03 * amp * s(t, 2, 0.1))
    add(p, "head", rx=PLOUGH * 0.25 * amp + 0.06 * amp * s(t, 2, 0.1), ry=-0.06 * amp * s(t, 1, 0.3))
    return p


GAIT = {"walk": lambda t: gait(t, 1.0), "run": lambda t: gait(t, 1.7)}


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.2, True, idle),
        "hop": (1.05, True, lumber_hop),
        "carry": (0.9, True, carry),
        "pet": (2.4, True, pet),
        "attack": (0.9, False, plough),
        "ability": (1.7, False, icebreak),
        "sleep": (4.6, True, haystack),
        "eat": (2.2, True, graze),
    }
)

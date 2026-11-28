"""Glaciyak's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a yak that lumbers,
with its head low and its weight rolling from shoulder to shoulder, ploughs into things with its prow horns and rears
up to slam the ground."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
HEAD_LOW = -0.1  # the head hangs below the level a Boki looks up from (rx)


def lumber(t, amp):
    """Four heavy footfalls a stride: the shoulders roll against the hips, the back rises and sinks, the head nods."""
    w = s(t, 1)
    p = {"root_at": (0, 0.012 * amp * s(t, 2), 0)}
    add(p, "root", rz=0.045 * amp * w, rx=0.03 * amp * s(t, 2, 0.5))
    add(p, "spine", rx=-0.04 * amp * s(t, 2), ry=0.05 * amp * w)
    add(p, "hips", rz=-0.04 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.6 + HEAD_LOW + 0.05 * amp * s(t, 2, 0.5), ry=-0.06 * amp * w)
    return p


def idle(t):
    br = s(t, 1)
    snort = seq(t, [(0, 0), (0.66, 0), (0.7, 1), (0.76, -0.2), (0.84, 0), (1, 0)])
    p = {"root_sc": (1 + 0.01 * br, 1 + 0.025 * br + 0.03 * snort, 1 + 0.01 * br)}
    add(p, "spine", rx=0.03 * br)
    add(p, "head", rx=LOOK_UP * 0.6 + HEAD_LOW + 0.05 * s(t, 1, 0.25) + 0.2 * snort, ry=0.1 * s(t, 1, 0.6))
    return p


def walk(t):
    return lumber(t, 1.0)


def run(t):
    """A thundering gallop: head lowered like a ram, the spine bunching and stretching, every stride a bound."""
    p = lumber(t, 0.4)
    stride = s(t, 1)
    p["root_at"] = (0, 0.025 + 0.015 * s(t, 2), 0)
    add(p, "root", rx=-0.06, rz=0.05 * stride)
    add(p, "spine", rx=-0.12 * stride)
    add(p, "hips", rx=0.1 * stride)
    add(p, "head", rx=-0.25 + 0.08 * s(t, 1, 0.2))
    return p


def carry(t):
    p = lumber(t, 0.8)
    add(p, "head", rx=0.1)
    return p


def gore(t):
    """Attack: sets its back legs and tucks its prow, charges, then tosses its head up through whatever it hit."""
    wind = seq(t, [(0, 0), (0.28, 1), (0.42, 0), (1, 0)])
    lunge = seq(t, [(0.28, 0), (0.42, 1), (0.62, 0.8), (1, 0)])
    toss = seq(t, [(0.4, 0), (0.52, 1), (0.7, 0.2), (1, 0)])
    p = {"root_at": (0, 0, 0.05 * wind - 0.22 * lunge)}
    p["root_sc"] = (1, 1 - 0.06 * wind, 1 + 0.05 * lunge)
    add(p, "root", rx=-0.12 * wind - 0.1 * lunge + 0.3 * toss)
    add(p, "hips", rx=0.15 * wind)
    add(p, "spine", rx=-0.18 * wind - 0.1 * lunge + 0.2 * toss)
    add(p, "head", rx=-0.35 * wind - 0.35 * lunge + 0.75 * toss)
    return p


def slam(t):
    """Its ground slam: rears up on its hind legs, drops its whole front onto the ground and shakes the earth."""
    k = seq(t, [(0, 0), (0.4, 1), (0.5, 1), (0.58, -1), (0.75, -0.4), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    shake = seq(t, [(0, 0), (0.58, 0), (0.64, 1), (0.7, -1), (0.76, 0.6), (0.82, -0.3), (0.9, 0), (1, 0)])
    p = {"root_at": (0, 0.07 * up, 0.06 * up - 0.05 * down)}
    p["root_sc"] = (1 + 0.14 * down, 1 - 0.18 * down, 1 + 0.1 * down)
    add(p, "root", rx=0.55 * up - 0.05 * down, rz=0.03 * shake)
    add(p, "hips", rx=-0.1 * up)
    add(p, "spine", rx=0.15 * up - 0.15 * down)
    add(p, "head", rx=0.2 * up - 0.35 * down)
    return p


def heavy_hop(t):
    """Hop: a deep crouch, a low heavy leap with the head thrown up, and a landing that squashes it flat."""
    air = seq(t, [(0, 0), (0.2, -0.6), (0.36, 0.3), (0.52, 1), (0.7, 0.3), (0.8, -0.8), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.13 * up - 0.05 * down, 0)}
    p["root_sc"] = (1 + 0.16 * down - 0.03 * up, 1 - 0.2 * down + 0.06 * up, 1 + 0.08 * down)
    add(p, "root", rx=0.1 * up - 0.06 * down)
    add(p, "spine", rx=0.1 * up - 0.1 * down)
    add(p, "head", rx=LOOK_UP * 0.6 + HEAD_LOW + 0.2 * up - 0.1 * down)
    return p


def lie_down(t):
    """Sleep: folds down onto its belly in the snow, its head laid sideways on the ground, breathing deep."""
    br = s(t, 1)
    p = {"root_at": (0, -0.11, 0), "root_sc": (1.08 + 0.02 * br, 0.82 + 0.03 * br, 1.04)}
    add(p, "spine", rx=-0.05)
    add(p, "head", rx=-0.3 + 0.01 * br, ry=0.25, rz=0.18)
    return p


def pet(t):
    """Lowers its head into a hand and leans on it, a slow contented blow."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    add(p, "root", rz=0.04 * lean)
    add(p, "spine", rx=0.03)
    add(p, "head", rx=LOOK_UP * 0.2 + HEAD_LOW + 0.05 * lean, rz=0.2 * lean, ry=0.1 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.0, True, idle),
        "walk": (1.1, True, walk),
        "run": (0.6, True, run),
        "hop": (1.0, True, heavy_hop),
        "carry": (1.2, True, carry),
        "pet": (2.4, True, pet),
        "attack": (1.0, False, gore),
        "ability": (1.4, False, slam),
        "sleep": (4.0, True, lie_down),
    }
)

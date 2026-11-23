"""Nimbostrich's (Boltstrich's) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
tall skittish ostrich that high-steps, snaps its neck round at every noise, sprints with its neck stretched flat
out, and bristles with static before it casts."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT


def stride(t, amp):
    """Long springy strides: the body rises on each step, the head glides level while the neck pumps behind it."""
    w = s(t, 1)
    p = {"root_at": (0, 0.02 * amp * s(t, 2), 0)}
    add(p, "root", rz=0.03 * amp * w, rx=0.03 * amp * s(t, 2, 0.5))
    add(p, "hips", rz=-0.03 * amp * w, rx=-0.04 * amp * s(t, 2))
    add(p, "spine", rx=0.03 * amp * s(t, 2, 0.25))
    add(p, "neck", rx=0.1 * amp * s(t, 2, 0.5), ry=0.05 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.5 - 0.1 * amp * s(t, 2, 0.5), ry=-0.06 * amp * w)
    return p


def idle(t):
    """Jumpy: it stands tall and bobs, then its neck snaps round to one side and the other, as if something moved."""
    br = s(t, 1)
    look = seq(t, [(0, 0), (0.3, 0), (0.34, 1), (0.5, 1), (0.54, -1), (0.68, -1), (0.72, 0), (1, 0)])
    start = seq(t, [(0.5, 0), (0.53, 1), (0.6, 0), (1, 0)])
    p = {"root_sc": (1, 1 + 0.012 * br + 0.02 * start, 1)}
    add(p, "spine", rx=0.02 * br)
    add(p, "neck", rx=0.04 * s(t, 2, 0.1) + 0.1 * start, ry=0.4 * look)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.03 * s(t, 2, 0.4), ry=0.3 * look)
    return p


def walk(t):
    return stride(t, 1.0)


def run(t):
    """A flat-out sprint: it leans into it, the neck stretched out ahead, every stride a long bound off the ground."""
    p = stride(t, 0.5)
    p["root_at"] = (0, 0.03 + 0.03 * s(t, 2), 0)
    add(p, "root", rx=-0.12)
    add(p, "spine", rx=-0.06 * s(t, 1))
    add(p, "neck", rx=-0.35, ry=0.0)
    add(p, "head", rx=-0.1)
    return p


def carry(t):
    p = stride(t, 0.8)
    add(p, "neck", rx=0.1)
    return p


def leap(t):
    """Hop: a quick crouch, then a tall kicking jump with the neck thrown up, and a stiff-legged landing."""
    air = seq(t, [(0, 0), (0.16, -0.7), (0.32, 0.4), (0.5, 1), (0.68, 0.3), (0.78, -0.6), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.16 * up - 0.04 * down, 0)}
    p["root_sc"] = (1 + 0.05 * down, 1 - 0.1 * down + 0.04 * up, 1 + 0.05 * down)
    add(p, "root", rx=0.1 * up - 0.08 * down)
    add(p, "spine", rx=-0.1 * down + 0.05 * up)
    add(p, "neck", rx=0.35 * up - 0.2 * down)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.1 * up)
    return p


def peck(t):
    """Attack: rears its neck back, strikes forward with a hammer-peck, and shakes its head before it recovers."""
    back = seq(t, [(0, 0), (0.3, 1), (0.4, 1), (0.48, 0), (1, 0)])
    strike = seq(t, [(0.3, 0), (0.44, 1), (0.56, 0.9), (0.8, 0), (1, 0)])
    shake = seq(t, [(0.5, 0), (0.56, 1), (0.62, -1), (0.68, 0.6), (0.74, -0.3), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0, 0.03 * back - 0.14 * strike)}
    add(p, "root", rx=-0.1 * strike)
    add(p, "spine", rx=0.15 * back - 0.15 * strike)
    add(p, "neck", rx=0.5 * back - 0.9 * strike, ry=0.15 * shake)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.2 * back - 0.3 * strike, ry=0.3 * shake)
    return p


def charge_up(t):
    """Its spell: rears up and goes rigid, shaking harder as the static builds, then stamps and sends it all out."""
    build = seq(t, [(0, 0), (0.45, 1), (0.6, 1), (0.66, 0), (1, 0)])
    stamp = seq(t, [(0.6, 0), (0.66, 1), (0.8, -0.3), (1, 0)])
    shake = s(t, 14) * build
    p = {"root_at": (0, 0.03 * build - 0.05 * stamp, 0)}
    p["root_sc"] = (1 + 0.04 * stamp, 1 + 0.03 * build - 0.06 * stamp, 1 + 0.04 * stamp)
    add(p, "root", rx=0.1 * build, rz=0.035 * shake)
    add(p, "spine", rx=0.1 * build - 0.1 * stamp)
    add(p, "neck", rx=0.3 * build - 0.4 * stamp, rz=0.06 * shake)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.3 * build - 0.3 * stamp, rz=0.06 * s(t, 17) * build)
    return p


def sit(t):
    """Sleep: folds down onto its belly, its neck curled low along its back and its head tucked in."""
    br = s(t, 1)
    p = {"root_at": (0, -0.1, 0), "root_sc": (1.04, 0.84 + 0.02 * br, 1.0)}
    add(p, "neck", rx=-0.5, ry=0.5)
    add(p, "head", rx=-0.4 + 0.01 * br, ry=0.4, rz=0.2)
    return p


def pet(t):
    """Skittish at first: it flinches back, then bows its head into the hand, a tremor running up its neck."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    add(p, "root", rz=0.03 * lean)
    add(p, "neck", rx=-0.3 * lean, rz=0.1 * lean + 0.02 * s(t, 9))
    add(p, "head", rx=LOOK_UP * 0.2 - 0.1 * lean, rz=0.15 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (2.6, True, idle),
        "walk": (0.8, True, walk),
        "run": (0.4, True, run),
        "hop": (0.9, True, leap),
        "carry": (0.9, True, carry),
        "pet": (2.2, True, pet),
        "attack": (0.8, False, peck),
        "ability": (1.5, False, charge_up),
        "sleep": (4.0, True, sit),
    }
)

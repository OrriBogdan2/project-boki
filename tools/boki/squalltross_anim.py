"""Squalltross's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): an albatross with
sail-cloth wings. The rig has no wing bones, so the wings are the spine's width: `wings` pulses the spine's lateral
scale (the neck takes the inverse so the head keeps its shape) and the body rises as they open, a beat you read from
the front. It waddles with the wings held out for balance, lunges bill-first, and sleeps with its head under a
folded sail."""

import glomwort_anim
from boki_clips import LOOK_UP, add, c, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
SCALED = ("spine", "neck")
KEEP_LEGS = ("walk", "run")  # reclip_own keeps the file's leg curves and root height for these


def wings(p, k):
    """The wings' spread, 1 at rest: the spine's width, the neck's undone."""
    p["spine_sc"] = (k, 1, 1)
    p["neck_sc"] = (1 / k, 1, 1)


def idle(t):
    """Breathes with its sails loose, looks round with the whole neck, now and then dips its bill to preen and
    gives the wings a shiver."""
    br = s(t, 1)
    preen = seq(t, [(0, 0), (0.3, 0), (0.38, 1), (0.5, 0.6), (0.58, 1), (0.68, 0), (1, 0)])
    shiver = seq(t, [(0, 0), (0.78, 0), (0.82, 1), (0.88, -0.7), (0.94, 0.4), (1, 0)])
    p = {"root_at": (0, 0.004 * br, 0)}
    wings(p, 1 + 0.03 * br - 0.06 * shiver)
    add(p, "spine", rx=0.02 * br)
    add(p, "neck", rx=-0.12 * preen, ry=0.16 * s(t, 1, 0.2) - 0.25 * preen)
    add(
        p,
        "head",
        rx=LOOK_UP - 0.2 * preen + 0.04 * br,
        rz=0.05 * s(t, 1, 0.1),
        ry=0.1 * s(t, 1, 0.55) + 0.12 * preen * s(t, 3),
    )
    return p


def waddle(t, amp, bob, flare):
    """A flat-footed roll from side to side, the head pecking forward on each step, the sails held out for balance."""
    w = s(t, 1)
    p = {"root_at": (0, bob * abs(c(t, 1)) - bob * 0.3, 0)}
    wings(p, 1 + flare + 0.04 * amp * s(t, 2))
    add(p, "root", rz=0.07 * amp * w, ry=0.04 * amp * w)
    add(p, "spine", rx=-0.04 * amp, rz=-0.03 * amp * w)
    add(p, "neck", rx=0.05 * amp * s(t, 2), ry=-0.06 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.7 - 0.05 * amp + 0.08 * amp * s(t, 2, 0.5), ry=-0.05 * amp * w)
    return p


def walk(t):
    return waddle(t, 1.0, 0.012, 0.03)


def run(t):
    """A flapping sprint: the wings beat fast and wide for lift, the neck stretched out in front of a leaning body."""
    f = s(t, 2)
    p = waddle(t, 0.7, 0.03, 0.06)
    p["root_at"] = (0, 0.03 + 0.03 * max(f, 0), 0)
    wings(p, 1.06 + 0.16 * f)
    add(p, "root", rx=-0.12)
    add(p, "spine", rx=-0.06)
    add(p, "neck", rx=-0.12)
    add(p, "head", rx=-0.1)
    return p


def carry(t):
    p = waddle(t, 0.8, 0.01, 0.0)
    add(p, "head", rx=0.12)
    return p


def jab(t):
    """Attack: draws the neck back and the sails up and out, stabs the bill forward with the wings snapping in, and
    shakes the head."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.42, 0), (1, 0)])
    stab = seq(t, [(0.3, 0), (0.42, 1), (0.58, 0.8), (0.85, 0), (1, 0)])
    p = {"root_at": (0, 0.01 * wind, -0.14 * stab + 0.03 * wind)}
    wings(p, 1 + 0.14 * wind - 0.16 * stab)
    add(p, "root", rx=0.1 * wind - 0.14 * stab)
    add(p, "spine", rx=0.1 * wind - 0.08 * stab)
    add(p, "neck", rx=0.3 * wind - 0.55 * stab)
    add(p, "head", rx=LOOK_UP * (1 - stab) + 0.12 * wind - 0.4 * stab, ry=0.2 * stab * s(t, 6))
    return p


def gust(t):
    """Its E: rears up, spreads the sails to their widest, beats them twice to call the squall (the body riding up
    on each beat), then folds them down."""
    rear = seq(t, [(0, 0), (0.22, 1), (0.8, 1), (1, 0)])
    beat = max(0.0, s(t, 2, -0.1)) * seq(t, [(0, 0), (0.28, 0), (0.34, 1), (0.74, 1), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0.025 * rear + 0.05 * beat, -0.02 * rear)}
    wings(p, 1 + 0.1 * rear + 0.2 * beat - 0.1 * seq(t, [(0.8, 0), (0.88, 1), (1, 0)]))
    add(p, "root", rx=0.22 * rear - 0.08 * beat)
    add(p, "spine", rx=0.12 * rear)
    add(p, "neck", rx=0.2 * rear)
    add(p, "head", rx=LOOK_UP + 0.5 * rear - 0.1 * beat)
    return p


def flap_hop(t):
    """Hop: a crouch, a launch on one big beat, a short hang with the wings wide, and a flat-footed landing."""
    air = seq(t, [(0, 0), (0.2, -0.7), (0.34, 0.4), (0.5, 1), (0.68, 0.4), (0.8, -1), (0.92, -0.3), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.12 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.06 * down, 1 - 0.1 * down + 0.03 * up, 1)
    wings(p, 1 + 0.2 * seq(t, [(0, 0), (0.3, -0.5), (0.42, 1), (0.6, 0.6), (0.78, 1), (1, 0)]) - 0.12 * down)
    add(p, "root", rx=0.1 * up - 0.06 * down)
    add(p, "neck", rx=0.1 * up)
    add(p, "head", rx=LOOK_UP + 0.15 * up - 0.12 * down)
    return p


def tuck(t):
    """Sleep: settles on its belly, the sails folded in, the bill turned back under a wing, a slow breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.07, 0), "root_sc": (1.02, 0.86 + 0.025 * br, 1.02)}
    wings(p, 0.8 + 0.015 * br)
    add(p, "spine", rx=0.04)
    add(p, "neck", rx=-0.3, ry=0.9)
    add(p, "head", rx=-0.25, ry=0.55, rz=0.3)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.0, True, idle),
        "walk": (0.9, True, walk),
        "run": (0.5, True, run),
        "hop": (0.9, True, flap_hop),
        "carry": (0.9, True, carry),
        "attack": (0.8, False, jab),
        "ability": (1.5, False, gust),
        "sleep": (4.0, True, tuck),
    }
)

"""Anchorhorn's (Harpwhal's) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
narwhal with a harpoon for a horn, dignified and stern. It glides rather than walks, the whole length of it swimming
over the ground in a slow wave, holds its horn level like a lance, and its strike is a thrust that stops dead, with
the slam of its ability driving the point into the ground to pin whatever stands there."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5  # a stern, level gaze: it does not look up at you


def swim(t, amp, lean):
    """The wave of a swimmer along the ground: hips lead, spine follows a beat late, the head stays steady on its
    horn and the whole body rises a little on each stroke."""
    w = s(t, 1)
    p = {"root_at": (0, 0.01 * amp * s(t, 2, 0.25), 0)}
    add(p, "root", rz=0.03 * amp * w, rx=-lean)
    add(p, "hips", ry=0.14 * amp * w, rx=0.04 * amp * s(t, 2))
    add(p, "spine", ry=-0.18 * amp * s(t, 1, -0.12), rx=-0.03 * amp * s(t, 2, 0.1))
    add(p, "neck", ry=0.1 * amp * s(t, 1, -0.25))
    add(p, "head", rx=LOOK - 0.5 * lean - 0.03 * amp * s(t, 2, 0.2), ry=-0.12 * amp * w)
    return p


def idle(t):
    """Floats upright and still, a long slow breath; now and then a formal turn of the head to one side, held, then
    back and a single nod, as if a petitioner had been heard."""
    br = s(t, 1)
    turn = seq(t, [(0, 0), (0.5, 0), (0.6, 1), (0.78, 1), (0.88, 0), (1, 0)])
    nod = seq(t, [(0, 0), (0.88, 0), (0.93, 1), (0.98, 0), (1, 0)])
    p = {"root_at": (0, 0.006 * br, 0), "root_sc": (1 + 0.008 * br, 1 + 0.014 * br, 1 + 0.008 * br)}
    add(p, "hips", ry=0.03 * s(t, 1, 0.3))
    add(p, "spine", rx=0.015 * br, ry=0.05 * turn)
    add(p, "head", rx=LOOK + 0.02 * br - 0.12 * nod, ry=0.3 * turn)
    return p


def walk(t):
    return swim(t, 1.0, 0.0)


def run(t):
    """A charge with the horn couched like a lance: leaned far forward, the wave quick and tight, head low and level."""
    p = swim(t, 1.5, 0.12)
    add(p, "spine", rx=-0.06)
    p["root_at"] = (0, 0.012 + 0.014 * s(t, 2, 0.25), 0)
    return p


def carry(t):
    return swim(t, 0.7, -0.04)


def thrust(t):
    """Attack: draws the horn back and low, holds it a heartbeat, then drives the whole body forward behind the
    point and stops dead on the end of it."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.4, 1), (0.46, 0), (1, 0)])
    drive = seq(t, [(0.38, 0), (0.46, 1), (0.58, 1), (0.82, 0.15), (1, 0)])
    p = {"root_at": (0, -0.012 * wind, 0.07 * wind - 0.19 * drive)}
    p["root_sc"] = (1, 1 - 0.04 * wind, 1 + 0.05 * wind + 0.05 * drive)
    add(p, "root", rx=0.14 * wind - 0.2 * drive)
    add(p, "hips", rx=0.1 * wind - 0.05 * drive)
    add(p, "spine", rx=0.12 * wind - 0.14 * drive)
    add(p, "head", rx=LOOK + 0.18 * wind - 0.36 * drive)
    return p


def slam(t):
    """Its E: rears up on its tail with the horn raised to the sky, trembles at the top, then crashes down and
    drives the point into the earth; it holds there a moment, pinned, before easing back."""
    k = seq(t, [(0, 0), (0.34, 1), (0.46, 1), (0.54, -1), (0.72, -0.9), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    top = seq(t, [(0, 0), (0.34, 0), (0.4, 1), (0.46, 1), (0.5, 0), (1, 0)])
    p = {"root_at": (0, 0.06 * up - 0.01 * down, 0.03 * up - 0.14 * down)}
    p["root_sc"] = (1 - 0.04 * up + 0.07 * down, 1 + 0.07 * up - 0.1 * down, 1 + 0.03 * up + 0.06 * down)
    add(p, "root", rx=0.55 * up - 0.28 * down, rz=0.012 * top * s(t, 14))
    add(p, "hips", rx=0.12 * up - 0.05 * down)
    add(p, "spine", rx=0.2 * up - 0.18 * down)
    add(p, "head", rx=LOOK + 0.26 * up - 0.42 * down)
    return p


def breach(t):
    """Hop: a breach: crouches, throws itself up nose first in a long arc with the body curving over the top, then
    comes down head first and lands level with a soft thud."""
    air = seq(t, [(0, 0), (0.2, -0.8), (0.36, 0.3), (0.52, 1), (0.7, 0.3), (0.8, -1), (0.92, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    arc = seq(t, [(0.25, 0), (0.4, 1), (0.52, 0), (0.64, -1), (0.8, -0.3), (1, 0)])
    p = {"root_at": (0, 0.14 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down - 0.02 * up, 1 - 0.14 * down + 0.05 * up, 1 + 0.06 * down)
    add(p, "root", rx=0.3 * arc)
    add(p, "spine", rx=0.12 * arc - 0.04 * down)
    add(p, "head", rx=LOOK + 0.1 * arc - 0.08 * down)
    return p


def sip(t):
    """Eat: lowers the horn gravely to the food, picks at it with small nods, straightens up to swallow."""
    p = eat_ground(t)
    add(p, "spine", rx=-0.05)
    add(p, "head", ry=0.06 * s(t, 3, 0.25))
    return p


def drift(t):
    """Sleep: settles onto its belly with the horn resting on the ground, a slow breath swelling the whole length."""
    br = s(t, 1)
    p = {"root_at": (0, -0.04, 0), "root_sc": (1.08 + 0.01 * br, 0.9 + 0.02 * br, 1.04)}
    add(p, "hips", ry=-0.1)
    add(p, "spine", rx=-0.05, ry=0.12)
    add(p, "head", rx=-0.3 + 0.01 * br, ry=0.18, rz=0.06)
    return p


def bow(t):
    """Pet: bows its head to the hand, formal and grateful, and holds it."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.01 * lean, 1 - 0.015 * lean, 1)}
    add(p, "spine", rx=-0.04 * lean)
    add(p, "head", rx=LOOK - 0.12 * lean, rz=0.1 * lean, ry=0.06 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.6, True, idle),
        "walk": (1.1, True, walk),
        "run": (0.6, True, run),
        "hop": (1.0, True, breach),
        "carry": (1.1, True, carry),
        "pet": (2.8, True, bow),
        "attack": (0.8, False, thrust),
        "ability": (1.3, False, slam),
        "sleep": (4.6, True, drift),
        "eat": (2.0, True, sip),
    }
)

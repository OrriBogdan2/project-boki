"""Barostorm's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a meerkat with a
storm barometer, alert, bossy and loyal. It stands up tall like a sentry and scans, the head snapping from one side
to the other and holding; walks briskly with the head up, barks its attack in a lunge, and booms its ability from
its full height with the barometer's needle racing."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.6
SENTRY = 0.22  # how far its body is stood up from level (root rx) on watch


def march(t, amp, lean):
    """A brisk, upright trot: short quick steps, the shoulders rolling, the head up and scanning ahead."""
    w = s(t, 1)
    p = {"root_at": (0, 0.01 * amp * abs(s(t, 1, 0.1)), 0)}
    add(p, "root", rz=0.05 * amp * w, rx=SENTRY * 0.4 - lean)
    add(p, "hips", rx=0.05 * amp * s(t, 2, 0.15))
    add(p, "spine", ry=0.06 * amp * w)
    add(p, "head", rx=LOOK - 0.3 * lean + 0.03 * amp * s(t, 2, 0.4), ry=0.08 * amp * s(t, 0.5, 0.25))
    return p


def idle(t):
    """On watch: stands up on its hind legs and holds, the head snapping to look right, freezing, snapping left;
    every so often a hard look straight up at the sky, the way a meerkat does for a hawk."""
    br = s(t, 2)
    look = seq(t, [(0, 0), (0.08, 0), (0.12, 1), (0.3, 1), (0.34, -1), (0.52, -1), (0.56, 0), (1, 0)])
    sky = seq(t, [(0, 0), (0.7, 0), (0.75, 1), (0.9, 1), (0.95, 0), (1, 0)])
    stand = 1.0 - 0.7 * sky
    p = {"root_at": (0, 0.004 * br, 0), "root_sc": (1 + 0.006 * br, 1 + 0.012 * br, 1 + 0.006 * br)}
    add(p, "root", rx=SENTRY * stand + 0.1 * sky)
    add(p, "spine", rx=0.03 * br, ry=0.1 * look)
    add(p, "neck", rx=0.08 * sky, ry=0.14 * look)
    add(p, "head", rx=LOOK * (1 - sky) + 0.45 * sky, ry=0.34 * look)
    return p


def walk(t):
    return march(t, 1.0, 0.0)


def run(t):
    """A low, fast scurry for cover or for the fight: nose forward, the body bunching and stretching each bound."""
    p = march(t, 1.5, 0.12)
    stride = s(t, 1)
    p["root_at"] = (0, 0.018 + 0.016 * s(t, 2, 0.25), 0)
    add(p, "root", rx=-SENTRY * 0.3)
    add(p, "spine", rx=-0.1 * stride)
    add(p, "hips", rx=0.1 * stride)
    return p


def carry(t):
    return march(t, 0.8, -0.03)


def bark(t):
    """Attack: rises tall and sucks in a breath, then lunges forward and down with a booming bark and snaps back
    up to stand."""
    wind = seq(t, [(0, 0), (0.26, 1), (0.36, 1), (0.4, 0), (1, 0)])
    lunge = seq(t, [(0.34, 0), (0.44, 1), (0.54, 1), (0.8, 0.1), (1, 0)])
    p = {"root_at": (0, 0.03 * wind - 0.01 * lunge, 0.02 * wind - 0.17 * lunge)}
    p["root_sc"] = (1 - 0.04 * wind + 0.03 * lunge, 1 + 0.08 * wind - 0.06 * lunge, 1 + 0.07 * lunge)
    add(p, "root", rx=0.3 * wind - 0.4 * lunge)
    add(p, "spine", rx=0.1 * wind - 0.12 * lunge)
    add(p, "head", rx=LOOK + 0.22 * wind - 0.3 * lunge)
    return p


def boom(t):
    """Its E: draws up to its full height on tiptoe, throws the head back and booms a storm warning; the whole
    body shudders with it as the barometer rattles, then it drops back to its feet."""
    k = seq(t, [(0, 0), (0.3, 1), (0.74, 1), (0.88, 0), (1, 0)])
    roar = seq(t, [(0, 0), (0.38, 0), (0.44, 1), (0.7, 1), (0.82, 0), (1, 0)])
    shake = s(t, 11) * roar
    p = {"root_at": (0, 0.05 * k, 0.01 * k)}
    p["root_sc"] = (1 - 0.05 * k + 0.02 * roar, 1 + 0.12 * k, 1 - 0.04 * k)
    add(p, "root", rx=0.38 * k, rz=0.04 * shake)
    add(p, "spine", rx=0.1 * k, rz=0.025 * shake)
    add(p, "neck", rx=0.1 * k + 0.1 * roar)
    add(p, "head", rx=LOOK + 0.16 * k + 0.4 * roar, rz=0.03 * shake)
    return p


def pop_up(t):
    """Hop: startles straight up like a meerkat off the mark, body held vertical, then lands back on its feet and
    turns its head to see what spooked it."""
    air = seq(t, [(0, 0), (0.16, -0.8), (0.3, 0.3), (0.46, 1), (0.64, 0.3), (0.76, -0.9), (0.88, -0.15), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.17 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down - 0.03 * up, 1 - 0.15 * down + 0.07 * up, 1 + 0.06 * down)
    add(p, "root", rx=0.2 * up - 0.06 * down)
    add(p, "head", rx=LOOK + 0.1 * up - 0.06 * down, ry=0.25 * seq(t, [(0.6, 0), (0.8, 1), (1, 0)]))
    return p


def nibble(t):
    """Eat: sits up and holds the food in its paws, head bobbing as it nibbles, an alert glance up now and then."""
    nib = 0.5 + 0.5 * s(t, 5)
    glance = seq(t, [(0, 0), (0.6, 0), (0.68, 1), (0.8, 1), (0.88, 0), (1, 0)])
    p = eat_ground(t)
    p["root_at"] = (0, -0.006, 0)
    add(p, "root", rx=SENTRY * 0.7)
    add(p, "spine", rx=0.1)
    add(p, "neck", rx=0.22 * glance)
    add(p, "head", rx=0.34 + 0.08 * nib + 0.2 * glance, ry=0.18 * glance)
    return p


def doze(t):
    """Sleep: slumps sitting up, the head dropping slowly towards the chest and jerking back up when it nods off,
    then sinks again."""
    br = s(t, 1)
    nod = seq(t, [(0, 0), (0.55, 1), (0.62, 1), (0.66, -0.2), (0.7, 0.1), (0.72, 0), (1, 0)])
    p = {"root_at": (0, -0.04, 0), "root_sc": (1.06 + 0.01 * br, 0.88 + 0.02 * br, 1.04)}
    add(p, "root", rx=0.12)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.1 - 0.3 * (1 - nod) + 0.02 * br, rz=0.1)
    return p


def salute(t):
    """Pet: puffs up proudly and leans into the hand, head high, then gives the hand a bossy little nudge."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.02 * lean, 1 + 0.02 * lean, 1)}
    add(p, "root", rx=SENTRY * 0.5, rz=0.04 * lean)
    add(p, "head", rx=LOOK + 0.08 * lean, rz=0.14 * lean, ry=0.06 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.2, True, idle),
        "walk": (0.72, True, walk),
        "run": (0.4, True, run),
        "hop": (0.85, True, pop_up),
        "carry": (0.8, True, carry),
        "pet": (2.4, True, salute),
        "attack": (0.7, False, bark),
        "ability": (1.4, False, boom),
        "sleep": (4.2, True, doze),
        "eat": (1.9, True, nibble),
    }
)

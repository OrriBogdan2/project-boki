"""Arcestrel's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a kestrel with a
lightning-rod crest, proud and always on the move. The head stays dead steady while the body shifts under it (a
kestrel hovers on a held gaze), it walks with a bird's head-thrust, strikes in a stoop that drops from high on the
beat, and its ability stands it up on its toes with its crest crackling."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def pace(t, amp, lean):
    """A bird's walk: the head thrusts forward and then holds still in space while the body catches up, the body
    pecking down and up on each step."""
    w = s(t, 1)
    thrust = seq(t, [(0, 0), (0.12, 1), (0.5, 1), (0.62, 0), (1, 0)])
    p = {"root_at": (0, 0.012 * amp * abs(s(t, 1, 0.1)), -0.03 * amp * thrust + 0.015 * amp)}
    add(p, "root", rz=0.05 * amp * w, rx=-lean)
    add(p, "hips", rx=0.06 * amp * s(t, 2, 0.1))
    add(p, "spine", rx=-0.05 * amp * thrust, ry=0.06 * amp * w)
    add(p, "neck", rx=-0.1 * amp * thrust)
    add(p, "head", rx=LOOK - 0.04 * amp - 0.5 * lean + 0.08 * amp * thrust, ry=-0.1 * amp * w)
    return p


def idle(t):
    """Alert and jittery: the body ruffles and settles while the head snaps to look one way, freezes, snaps the
    other, with a quick preening shake of the feathers between."""
    br = s(t, 3)
    look = seq(t, [(0, 0), (0.1, 0), (0.14, 1), (0.34, 1), (0.38, -1), (0.6, -1), (0.64, 0), (1, 0)])
    shake = seq(t, [(0, 0), (0.72, 0), (0.75, 1), (0.78, -1), (0.81, 0.8), (0.84, -0.6), (0.88, 0), (1, 0)])
    p = {"root_at": (0, 0.004 * br, 0), "root_sc": (1 + 0.012 * br + 0.03 * abs(shake), 1 - 0.015 * br, 1)}
    add(p, "root", rz=0.05 * shake, rx=0.03 * s(t, 1))
    add(p, "spine", rz=0.03 * shake)
    add(p, "neck", ry=0.1 * look)
    add(p, "head", rx=LOOK + 0.02 * br + 0.04 * abs(look), ry=0.4 * look)
    return p


def walk(t):
    return pace(t, 1.0, 0.0)


def run(t):
    """A fast, low, forward-leaning scurry, the head thrust out ahead and level, the body bobbing on its quick feet."""
    p = pace(t, 1.7, 0.16)
    p["root_at"] = (0, 0.02 * abs(s(t, 2, 0.1)), p["root_at"][2])
    add(p, "spine", rx=-0.08)
    return p


def carry(t):
    return pace(t, 0.8, -0.03)


def stoop(t):
    """Attack: rears back and up on the beat with the head cocked, then drops forward and down in one stoop and
    strikes with its beak low to the ground, bounding back up."""
    wind = seq(t, [(0, 0), (0.28, 1), (0.38, 1), (0.42, 0), (1, 0)])
    dive = seq(t, [(0.34, 0), (0.46, 1), (0.54, 1), (0.74, 0.1), (1, 0)])
    p = {"root_at": (0, 0.05 * wind - 0.03 * dive, -0.02 * wind - 0.2 * dive)}
    p["root_sc"] = (1 - 0.03 * wind, 1 + 0.05 * wind - 0.07 * dive, 1 + 0.08 * dive)
    add(p, "root", rx=0.3 * wind - 0.55 * dive)
    add(p, "hips", rx=0.1 * wind)
    add(p, "spine", rx=0.18 * wind - 0.16 * dive)
    add(p, "neck", rx=0.1 * wind - 0.15 * dive)
    add(p, "head", rx=LOOK + 0.2 * wind - 0.45 * dive, rz=0.15 * wind)
    return p


def arc_flash(t):
    """Its E: drops onto its toes and shivers as the charge climbs the rod, then stretches up tall with the crest
    throwing out its chain of sparks and shakes the charge off in a flurry."""
    charge = seq(t, [(0, 0), (0.36, 1), (0.42, 1), (0.5, 0), (1, 0)])
    fire = seq(t, [(0.4, 0), (0.46, 1), (0.6, 0.7), (0.8, 0.15), (1, 0)])
    shiver = s(t, 12) * charge + 0.7 * s(t, 16) * fire
    p = {"root_at": (0, -0.012 * charge + 0.05 * fire, 0)}
    p["root_sc"] = (1 + 0.06 * charge - 0.04 * fire, 1 - 0.09 * charge + 0.14 * fire, 1 + 0.04 * charge)
    add(p, "root", rx=-0.1 * charge + 0.4 * fire, rz=0.04 * shiver)
    add(p, "spine", rx=-0.08 * charge + 0.12 * fire, rz=0.03 * shiver)
    add(p, "neck", rx=-0.1 * charge + 0.2 * fire)
    add(p, "head", rx=LOOK - 0.14 * charge + 0.3 * fire, rz=0.05 * shiver)
    return p


def flap_hop(t):
    """Hop: a quick crouch, a springy leap high with a flurry of wing beats, then a neat landing on both feet."""
    air = seq(t, [(0, 0), (0.14, -0.7), (0.28, 0.4), (0.5, 1), (0.72, 0.3), (0.82, -0.8), (0.92, -0.1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    flutter = s(t, 5)
    p = {"root_at": (0, 0.2 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.08 * down - 0.02 * up, 1 - 0.12 * down + 0.05 * up, 1 + 0.04 * down)
    add(p, "root", rx=0.12 * up - 0.06 * down, rz=0.07 * flutter * up)
    add(p, "spine", rx=0.05 * up)
    add(p, "head", rx=LOOK + 0.12 * up - 0.08 * down, rz=-0.05 * flutter * up)
    return p


def peck(t):
    """Eat: pecks quick and sharp, four jabs and a lift of the head to look about between."""
    p = eat_ground(t)
    jab = max(s(t, 4), 0.0)
    add(p, "spine", rx=-0.04 * jab)
    add(p, "head", rx=-0.16 * jab + 0.04 * s(t, 2, 0.25), ry=0.05 * s(t, 1, 0.3))
    return p


def tuck(t):
    """Sleep: hunched into a round ball of feathers with the head turned back and tucked, the breath fluffing it."""
    br = s(t, 1)
    p = {"root_at": (0, -0.025, 0), "root_sc": (1.06 + 0.012 * br, 0.92 + 0.02 * br, 1.04)}
    add(p, "spine", rx=-0.08)
    add(p, "neck", ry=0.5, rx=-0.15)
    add(p, "head", rx=-0.3 + 0.01 * br, ry=0.9, rz=0.2)
    return p


def preen(t):
    """Pet: pleased, it fluffs up and tilts its head into the hand, then gives a quick proud shake."""
    lean = 0.5 + 0.5 * s(t, 1)
    shake = seq(t, [(0, 0), (0.82, 0), (0.85, 1), (0.88, -1), (0.92, 0.5), (0.96, 0), (1, 0)])
    p = {"root_sc": (1 + 0.03 * lean, 1 + 0.02 * lean, 1 + 0.03 * lean)}
    add(p, "root", rz=0.05 * shake)
    add(p, "head", rx=LOOK + 0.05 * lean, rz=0.2 * lean, ry=0.08 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (2.4, True, idle),
        "walk": (0.7, True, walk),
        "run": (0.36, True, run),
        "hop": (0.8, True, flap_hop),
        "carry": (0.75, True, carry),
        "pet": (2.2, True, preen),
        "attack": (0.6, False, stoop),
        "ability": (1.1, False, arc_flash),
        "sleep": (3.8, True, tuck),
        "eat": (1.6, True, peck),
    }
)

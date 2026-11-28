"""Citadoad's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a fortress toad in
spiked plates, loyal and stubborn, with a mace for a tail. It squats low and waddles on its stumps, throat pulsing,
and fights by turning its back and swinging the mace round."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def throat(t, n=6):
    """The toad's quick throat pulse, a little squash of the front."""
    return 0.5 + 0.5 * s(t, n)


def waddle(t, amp, rate):
    """Short heavy steps: it rolls over each stump in turn, the plates rocking, and sinks at every footfall."""
    w = s(t, rate)
    p = {"root_at": (0, -0.01 * amp * abs(w), 0)}
    p["root_sc"] = (1 + 0.015 * amp * abs(w), 1 - 0.025 * amp * abs(w), 1)
    add(p, "root", rz=0.1 * amp * w, ry=0.05 * amp * w)
    add(p, "hips", ry=-0.08 * amp * w)
    add(p, "spine", rz=-0.06 * amp * w, rx=-0.03 * amp)
    add(p, "head", rx=LOOK, ry=-0.06 * amp * s(t, rate, 0.25))
    return p


def idle(t):
    """Squatting like a bunker, the throat pulsing fast under a slow breath; every so often it blinks hard and swivels
    to glare at the left, then the right."""
    br = s(t, 1)
    glare = seq(t, [(0, 0), (0.45, 0), (0.52, 1), (0.6, 1), (0.68, -1), (0.78, -1), (0.86, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br, 1 - 0.012 * br - 0.012 * throat(t), 1 + 0.012 * br)}
    add(p, "spine", rx=0.01 * br)
    add(p, "head", rx=LOOK + 0.03 * throat(t), ry=0.3 * glare)
    return p


def walk(t):
    return waddle(t, 1.0, 1)


def run(t):
    """A waddling bulldoze: faster, rolling harder, the whole fort tilted forward."""
    p = waddle(t, 1.6, 2)
    add(p, "root", rx=-0.1)
    add(p, "spine", rx=-0.08)
    add(p, "head", rx=-0.06)
    return p


def carry(t):
    return waddle(t, 0.7, 1)


def mace(t):
    """Attack: winds up by twisting away, the mace tail coiled behind, then spins on its stumps and swings it round."""
    wind = seq(t, [(0, 0), (0.36, 1), (0.44, 1), (0.52, 0), (1, 0)])
    swing = seq(t, [(0.42, 0), (0.56, 1), (0.74, 0.3), (0.92, 0), (1, 0)])
    p = {"root_at": (0, -0.012 * wind, -0.02 * wind + 0.03 * swing)}
    p["root_sc"] = (1 + 0.04 * wind, 1 - 0.05 * wind + 0.02 * swing, 1 - 0.03 * wind)
    add(p, "root", ry=-0.5 * wind + 1.1 * swing, rz=0.08 * wind - 0.1 * swing)
    add(p, "hips", ry=-0.3 * wind + 0.5 * swing)
    add(p, "head", rx=LOOK, ry=0.4 * wind - 0.7 * swing)
    return p


def brace(t):
    """Its E: plants and puffs itself up behind its plates, trembling, then slams the whole body down so the ground
    jumps."""
    puff = seq(t, [(0, 0), (0.3, 1), (0.58, 1), (0.64, 0), (1, 0)])
    slam = seq(t, [(0.58, 0), (0.64, 1), (0.78, 0.3), (1, 0)])
    shake = s(t, 10) * puff
    p = {"root_at": (0, 0.025 * puff - 0.03 * slam, 0)}
    p["root_sc"] = (
        1 + 0.14 * puff + 0.01 * shake + 0.1 * slam,
        1 + 0.12 * puff - 0.2 * slam,
        1 + 0.14 * puff + 0.1 * slam,
    )
    add(p, "head", rx=LOOK + 0.2 * puff - 0.25 * slam)
    return p


def toad_hop(t):
    """Hop: the real toad hop: a deep squat, a big launch with the legs trailing, a belly-flop landing and a gulp."""
    air = seq(t, [(0, 0), (0.24, -1), (0.4, 0.4), (0.52, 1), (0.68, 0.3), (0.78, -1), (0.9, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.14 * up - 0.025 * down, 0.03 * up)}
    p["root_sc"] = (1 + 0.15 * down - 0.04 * up, 1 - 0.25 * down + 0.08 * up, 1 + 0.1 * down + 0.05 * up)
    add(p, "root", rx=-0.1 * up + 0.12 * down)
    add(p, "head", rx=LOOK + 0.15 * up - 0.12 * down)
    return p


def hunker(t):
    """Sleep: tucks its chin, sinks flat under its plates like a bunker with the shutters down, throat barely moving."""
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.12, 0.78 + 0.02 * throat(t, 2), 1.1)}
    add(p, "spine", rx=-0.05 + 0.015 * s(t, 2))
    add(p, "head", rx=-0.35 + 0.04 * s(t, 1, 0.2), rz=0.06 + 0.03 * s(t, 1, 0.6))
    return p


def snap(t):
    """Eat: sits very still, then the head lunges out and back; the throat gulps three times."""
    lunge = seq(t, [(0, 0), (0.3, 0), (0.38, 1), (0.46, 0), (1, 0)])
    gulp = seq(t, [(0.46, 0), (0.52, 1), (0.58, 0), (0.64, 1), (0.7, 0), (0.76, 1), (0.84, 0), (1, 0)])
    p = {"root_at": (0, 0, 0.04 * lunge)}
    p["root_sc"] = (1, 1 + 0.03 * gulp - 0.04 * lunge, 1 + 0.06 * lunge)
    add(p, "root", rx=-0.12 * lunge)
    add(p, "head", rx=LOOK - 0.3 * lunge + 0.1 * gulp)
    return p


def pet(t):
    """It shuts its eyes and puffs its throat out, flat with content, and slowly rocks on its stumps."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.03 * lean + 0.015 * throat(t, 3), 1 + 0.03 * lean)}
    add(p, "root", rz=0.05 * s(t, 1))
    add(p, "head", rx=LOOK - 0.08 * lean, rz=0.1 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.0, True, idle),
        "walk": (1.0, True, walk),
        "run": (0.6, True, run),
        "hop": (1.0, True, toad_hop),
        "carry": (1.2, True, carry),
        "pet": (2.4, True, pet),
        "attack": (1.0, False, mace),
        "ability": (1.5, False, brace),
        "sleep": (4.0, True, hunker),
        "eat": (2.0, True, snap),
    }
)

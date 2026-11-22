"""Threadwyrm's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a knotted rope of
a wyrm with no legs. It moves on a travelling S-wave: the head yaws first and each segment behind it repeats the
turn a little later, so a bend runs from the head down to the tail. Idle sways like a charmed rope, the run is a
fast flat slither, the strike coils then lashes, and sleep is a tight spiral."""
import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
CHAIN = ("head", "neck", "spine", "hips")        # front to back: each bone's wave is LAG later than the one before
LAG = 0.14


def wave(p, t, n, amp, ph=0.0, roll=0.0, fade=(1.0, 1.0, 1.0, 1.0)):
    """The S-wave: yaw on every segment, the tail end swinging widest, the roll leaning into each bend."""
    for i, bone in enumerate(CHAIN):
        k = amp * (0.7 + 0.3 * i) * fade[i]
        add(p, bone, ry=k * s(t, n, ph - i * LAG), rz=roll * k * s(t, n, ph - i * LAG - 0.25))
    add(p, "root", ry=-0.25 * amp * s(t, n, ph - 4 * LAG))


def idle(t):
    """Sways its raised head like a charmed rope, the coils shifting a beat behind, and now and then flicks the head."""
    br = s(t, 1)
    flick = seq(t, [(0, 0), (0.7, 0), (0.74, 1), (0.8, -0.5), (0.86, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br, 1 + 0.02 * br, 1)}
    wave(p, t, 1, 0.16, roll=0.3)
    add(p, "spine", rx=0.05)
    add(p, "neck", rx=0.1 + 0.03 * br)
    add(p, "head", rx=LOOK_UP + 0.05 * br + 0.1 * flick, ry=0.12 * flick)
    return p


def slither(t, n, amp, low, stretch):
    p = {"root_at": (0, 0.004 * s(t, 2 * n), 0),
         "root_sc": (1 - 0.02 * stretch, 1, 1 + stretch * (0.5 + 0.5 * s(t, 2 * n)))}
    wave(p, t, n, amp, roll=0.4)
    add(p, "spine", rx=-0.05 * low)
    add(p, "neck", rx=0.1 - 0.08 * low)
    add(p, "head", rx=LOOK_UP * (1 - 0.7 * low))
    return p


def walk(t):
    return slither(t, 1, 0.4, 0.0, 0.03)


def run(t):
    """Flat out: the head down and level, the wave twice as fast and the body stretched thin along the ground."""
    p = slither(t, 2, 0.42, 1.0, 0.06)
    p["root_at"] = (0, -0.01, 0)
    return p


def carry(t):
    p = slither(t, 1, 0.3, 0.0, 0.03)
    add(p, "head", rx=0.12)
    return p


def lash(t):
    """Attack: coils into a tight S (the bends deepen as the head draws back), then the S snaps straight and the
    head lashes forward and down, the wave running out down the tail."""
    coil = seq(t, [(0, 0), (0.32, 1), (0.42, 1), (0.5, 0), (1, 0)])
    lunge = seq(t, [(0.32, 0), (0.46, 1), (0.6, 0.9), (0.85, 0), (1, 0)])
    p = {"root_at": (0, 0, 0.05 * coil - 0.24 * lunge),
         "root_sc": (1, 1 + 0.06 * coil - 0.04 * lunge, 1 + 0.12 * lunge)}
    for i, bone in enumerate(CHAIN):
        add(p, bone, ry=(0.55 - 0.1 * i) * coil * (1 if i % 2 else -1) + 0.2 * lunge * s(t, 5, -i * LAG))
    add(p, "spine", rx=0.2 * coil - 0.1 * lunge)
    add(p, "neck", rx=0.45 * coil - 0.7 * lunge)
    add(p, "head", rx=LOOK_UP * (1 - lunge) + 0.3 * coil - 0.5 * lunge)
    return p


def corkscrew(t):
    """Its E: rears the front of the body up, spins the wave round three times as fast with the bends opening, and
    drops it back down in one slap."""
    rear = seq(t, [(0, 0), (0.25, 1), (0.7, 1), (0.8, -0.4), (1, 0)])
    up = max(rear, 0)
    p = {"root_at": (0, 0.05 * up - 0.02 * max(-rear, 0), 0), "root_sc": (1, 1 + 0.06 * up, 1 - 0.05 * up)}
    wave(p, t, 3, 0.3 * up, roll=0.2)
    add(p, "spine", rx=0.5 * up - 0.15 * max(-rear, 0))
    add(p, "neck", rx=0.5 * up)
    add(p, "head", rx=LOOK_UP + 0.5 * up - 0.3 * max(-rear, 0))
    return p


def spring(t):
    """Hop: bunches into an S, springs straight up and arches, and lands in a loose coil."""
    air = seq(t, [(0, 0), (0.24, -0.8), (0.4, 0.4), (0.52, 1), (0.68, 0.4), (0.8, -0.9), (0.92, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.14 * up, 0), "root_sc": (1 + 0.05 * down, 1 - 0.1 * down + 0.08 * up, 1 + 0.05 * down)}
    wave(p, t, 1, 0.1 + 0.3 * down - 0.08 * up)
    add(p, "spine", rx=0.18 * up - 0.12 * down)
    add(p, "neck", rx=0.2 * up)
    add(p, "head", rx=LOOK_UP + 0.2 * up - 0.2 * down)
    return p


def spiral(t):
    """Sleep: coils down into a spiral, the bends all one way, the head laid on the topmost loop, slow breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.05, 0), "root_sc": (1.05 + 0.02 * br, 0.8 + 0.03 * br, 0.95)}
    for i, bone in enumerate(CHAIN):
        add(p, bone, ry=0.65 - 0.05 * i)
    add(p, "head", rx=-0.35 + 0.015 * br, rz=0.2)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update({
    "idle": (3.4, True, idle),
    "walk": (1.0, True, walk),
    "run": (0.5, True, run),
    "hop": (0.95, True, spring),
    "carry": (1.0, True, carry),
    "attack": (0.8, False, lash),
    "ability": (1.5, False, corkscrew),
    "sleep": (4.4, True, spiral),
})

"""Barokat's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a meerkat on watch that
cannot relax. It stands tall and sweeps its head side to side, marches brisk and stiff, bolts low when it runs, springs
up to strike, and its barometer belly pulses when lightning is near."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def sweep_look(t):
    """The sentry's scan: a hard turn to one side, a hold, a snap to the other, a hold (yaw of the head)."""
    return seq(t, [(0, 0), (0.18, 1), (0.42, 1), (0.52, -1), (0.8, -1), (0.9, 0), (1, 0)])


def idle(t):
    """On watch: stretched tall, the head sweeping left and right in stops, the chest lifted, never quite still."""
    sw = sweep_look(t)
    br = s(t, 2)
    jerk = seq(t, [(0, 0), (0.46, 0), (0.5, 1), (0.56, 0), (1, 0)])
    p = {"root_sc": (1, 1 + 0.02 * br, 1)}
    add(p, "spine", rx=0.07 + 0.015 * br, ry=0.06 * sw)
    add(p, "neck", ry=0.2 * sw, rx=0.03 * jerk)
    add(p, "head", rx=LOOK + 0.12 + 0.06 * jerk, ry=0.5 * sw)
    return p


def march(t, amp):
    """Brisk and stiff: quick small steps (two a stride), the body upright and level, the head held steady while the
    shoulders trade a little roll, a glance to the side every stride."""
    w = s(t, 1)
    step = s(t, 2)
    p = {"root_at": (0, 0.01 * amp * abs(s(t, 2, 0.25)), 0)}
    add(p, "root", rz=0.04 * amp * w, rx=0.04 + 0.02 * amp * step)
    add(p, "spine", rx=0.05, ry=0.06 * amp * w)
    add(p, "hips", rz=-0.04 * amp * w, ry=-0.05 * amp * w)
    add(p, "head", rx=LOOK + 0.08 - 0.03 * amp * step, ry=0.18 * amp * s(t, 1, 0.25) - 0.05 * amp * w)
    return p


def walk(t):
    return march(t, 1.0)


def run(t):
    """Bolts for cover: drops onto its forepaws, the body stretched flat and bounding fast, the head up and fixed
    ahead, and the back arching and straightening on every bound."""
    p = march(t, 0.4)
    st = s(t, 2)
    p["root_at"] = (0, 0.025 + 0.022 * s(t, 2, 0.25), 0)
    add(p, "root", rx=-0.12 + 0.06 * st)
    add(p, "spine", rx=-0.14 * st)
    add(p, "hips", rx=0.12 * s(t, 2, 0.25))
    add(p, "head", rx=LOOK + 0.12 + 0.08 * st, ry=0)
    return p


def carry(t):
    p = march(t, 0.8)
    add(p, "head", rx=0.04)
    add(p, "spine", rx=0.04)
    return p


def strike(t):
    """Attack: springs up to full height with its chest out (it looks bigger), holds a heartbeat, and slaps down
    on the target with its whole forebody."""
    up = seq(t, [(0, 0), (0.28, 1), (0.4, 1), (0.5, 0), (1, 0)])
    hit = seq(t, [(0.38, 0), (0.5, 1), (0.64, 0.9), (0.86, 0), (1, 0)])
    p = {"root_at": (0, 0.04 * up - 0.01 * hit, 0.02 * up - 0.14 * hit)}
    p["root_sc"] = (1 - 0.03 * hit, 1 + 0.06 * up - 0.1 * hit, 1 + 0.08 * hit)
    add(p, "root", rx=0.16 * up - 0.3 * hit)
    add(p, "hips", rx=-0.1 * up + 0.1 * hit)
    add(p, "spine", rx=0.12 * up - 0.28 * hit)
    add(p, "head", rx=LOOK + 0.12 * up - 0.5 * hit)
    return p


def pulse(t):
    """Its E: rises to full height as the barometer needle spins up, the belly pulsing in three bright beats
    while the head snaps round to the storm, then a flash shudder from the nose to the tail and it stands down."""
    stand = seq(t, [(0, 0), (0.2, 1), (0.75, 1), (1, 0)])
    beat = seq(t, [(0.2, 0), (0.28, 1), (0.36, 0), (0.44, 1), (0.52, 0), (0.6, 1), (0.68, 0), (1, 0)])
    flash = seq(t, [(0.64, 0), (0.68, 1), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0.03 * stand + 0.025 * flash, 0)}
    p["root_sc"] = (1 + 0.1 * beat - 0.03 * flash, 1 + 0.04 * stand - 0.05 * beat + 0.06 * flash, 1 + 0.1 * beat)
    add(p, "root", rx=0.1 * stand, rz=0.05 * flash * s(t, 12))
    add(p, "spine", rx=0.1 * stand, ry=0.09 * flash * s(t, 14, 0.3))
    add(
        p,
        "head",
        rx=LOOK + 0.14 * stand + 0.2 * flash,
        ry=0.45 * seq(t, [(0, 0), (0.3, 0.8), (0.62, 0.8), (0.74, -0.5), (1, 0)]),
    )
    return p


def pop_hop(t):
    """Hop: a startled meerkat jump straight up, stretched tall, the head spinning to check behind it, a stiff landing."""
    air = seq(t, [(0, 0), (0.2, -0.5), (0.34, 0.3), (0.5, 1), (0.68, 0.3), (0.78, -0.6), (0.9, -0.1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.14 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 - 0.05 * up + 0.1 * down, 1 + 0.1 * up - 0.14 * down, 1 - 0.05 * up + 0.08 * down)
    add(p, "root", rx=0.06 * up - 0.05 * down)
    add(p, "spine", rx=0.1 * up)
    add(p, "head", rx=LOOK + 0.18 * up - 0.1 * down, ry=0.8 * seq(t, [(0.3, 0), (0.6, 1), (0.8, 0)]))
    return p


def nod_off(t):
    """Sleep: it will not lie down. It slumps sat up, the head sinking by degrees, then jerks awake, glares around,
    and starts to sink again."""
    br = s(t, 2)
    sink = seq(t, [(0, 0), (0.62, 1), (0.68, 1), (0.72, 0), (0.82, 0), (1, 0)])
    glare = seq(t, [(0.7, 0), (0.76, 1), (0.9, 1), (0.97, 0), (1, 0)])
    p = {"root_at": (0, -0.035 - 0.02 * sink, 0)}
    p["root_sc"] = (1 + 0.015 * br, 1 - 0.1 + 0.02 * br, 1.04)
    add(p, "spine", rx=-0.12 * sink)
    add(p, "head", rx=-0.15 - 0.45 * sink + 0.4 * glare, ry=0.5 * glare * s(t, 1.5, 0.1))
    return p


def pet(t):
    """Allows exactly one pat: leans into the hand a little, the head tilting, one eye still on the horizon."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    add(p, "root", rz=0.03 * lean)
    add(p, "spine", rx=0.06)
    add(p, "head", rx=LOOK + 0.06 - 0.05 * lean, rz=0.16 * lean, ry=0.1 * lean + 0.12 * s(t, 0.5))
    return p


def eat(t):
    """Nibbles the berry in its forepaws sat upright: two bites, then the head snaps up to check around, then a third."""
    bite = s(t, 3)
    look = seq(t, [(0, 0), (0.55, 0), (0.62, 1), (0.8, 1), (0.88, 0), (1, 0)])
    p = {}
    add(p, "spine", rx=-0.06 + 0.05 * look)
    add(p, "head", rx=-0.28 * (1 - look) + 0.1 * bite * (1 - look) + 0.3 * look, ry=0.5 * look * s(t, 1, 0.1))
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.0, True, idle),
        "walk": (0.7, True, walk),
        "run": (0.4, True, run),
        "hop": (0.9, True, pop_hop),
        "carry": (0.8, True, carry),
        "pet": (2.2, True, pet),
        "attack": (0.8, False, strike),
        "ability": (1.5, False, pulse),
        "sleep": (4.0, True, nod_off),
        "eat": (2.4, True, eat),
    }
)

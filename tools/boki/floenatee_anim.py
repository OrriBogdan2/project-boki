"""Floenatee's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a manatee-seal propped
on its flippers hauls itself along in slow humps, flops its belly down to attack, and hums its ice wall up."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def wallow(t, amp):
    """The haul: the chest heaves up and forward, the rump drags after it, the whole barrel rolling a little onto the
    flipper that pushes, the tail trailing a beat behind."""
    u = s(t, 1)
    p = {"root_at": (0, 0.005 * amp * (1 + s(t, 2)), -0.03 * amp * u)}
    p["root_sc"] = (1 - 0.03 * amp * u, 1 - 0.04 * amp * u, 1 + 0.05 * amp * u)
    add(p, "root", rz=0.05 * amp * s(t, 1, 0.5), rx=0.02 * amp * u)
    add(p, "spine", rx=0.14 * amp * u)
    add(p, "hips", rx=-0.1 * amp * u, ry=0.12 * amp * s(t, 1, 0.5))
    add(p, "head", rx=LOOK - 0.1 * amp * u, ry=-0.05 * amp * s(t, 1, 0.5))
    return p


def idle(t):
    br = s(t, 1)
    p = {"root_sc": (1 + 0.02 * br, 1 + 0.03 * br, 1)}
    flick = seq(t, [(0, 0), (0.78, 0), (0.84, 1), (0.9, -0.6), (1, 0)])
    add(p, "spine", rx=0.03 * br)
    add(p, "neck", ry=0.06 * s(t, 1, 0.1))
    add(p, "head", rx=LOOK + 0.04 * s(t, 1, 0.2), ry=0.12 * s(t, 1), rz=0.04 * s(t, 1, 0.35))
    add(p, "hips", ry=0.03 * s(t, 1, 0.5) + 0.3 * flick)
    return p


def walk(t):
    return wallow(t, 1.0)


def run(t):
    """A belly-slide rush: the same haul, bigger and quicker, the chest held up out of the snow."""
    p = wallow(t, 1.9)
    add(p, "root", rx=0.05)
    add(p, "head", rx=0.08)
    return p


def carry(t):
    p = wallow(t, 0.7)
    add(p, "spine", rx=-0.04)
    return p


def bellyflop(t):
    """Attack: rears its chest up, then drops forward onto its belly with all its weight and flicks its tail."""
    k = seq(t, [(0, 0), (0.32, 1), (0.45, -1), (0.6, -0.8), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    p = {"root_at": (0, 0.05 * up - 0.02 * down, 0.04 * up - 0.14 * down)}
    p["root_sc"] = (1 - 0.05 * up + 0.14 * down, 1 + 0.1 * up - 0.2 * down, 1 - 0.03 * up + 0.1 * down)
    add(p, "root", rx=0.22 * up - 0.12 * down)
    add(p, "spine", rx=0.2 * up - 0.2 * down)
    add(p, "hips", rx=0.2 * up, ry=0.4 * seq(t, [(0, 0), (0.45, 0), (0.55, 1), (0.72, -0.7), (0.9, 0), (1, 0)]))
    add(p, "head", rx=0.3 * up - 0.2 * down)
    return p


def hum(t):
    """Its wall of ice: the chest swells and rises, a low hum shudders through it, then it pushes the wall out."""
    rise = seq(t, [(0, 0), (0.3, 1), (0.82, 1), (1, 0)])
    push = seq(t, [(0, 0), (0.4, 0), (0.48, 1), (0.62, 0), (1, 0)])
    buzz = s(t, 8) * rise
    p = {"root_at": (0, 0.02 * rise, -0.04 * push)}
    p["root_sc"] = (1 + 0.04 * rise + 0.015 * buzz, 1 + 0.07 * rise + 0.02 * buzz, 1 + 0.03 * push)
    add(p, "spine", rx=0.35 * rise - 0.1 * push)
    add(p, "hips", rx=-0.15 * rise)
    add(p, "head", rx=LOOK + 0.3 * rise + 0.05 * buzz, ry=0.1 * s(t, 1.5) * rise)
    return p


def flop_hop(t):
    """Hop: a seal's bounce, arching up with the tail flicking, then belly down with a squash."""
    air = seq(t, [(0, 0), (0.2, -0.55), (0.34, 0.3), (0.5, 1), (0.68, 0.3), (0.8, -0.5), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.16 * up - 0.06 * down, 0)}
    p["root_sc"] = (1 + 0.12 * down - 0.04 * up, 1 - 0.18 * down + 0.08 * up, 1 + 0.06 * down)
    add(p, "root", rx=seq(t, [(0.2, 0), (0.42, 0.3), (0.7, -0.25), (0.85, 0)]))
    add(p, "spine", rx=0.2 * up - 0.15 * down)
    add(p, "hips", ry=0.25 * s(t, 3) * up)
    add(p, "head", rx=LOOK + 0.15 * up - 0.12 * down)
    return p


def snooze(t):
    """Sleep: slumps flat on the ice, chin down on one flipper, a slow deep breath, the tail curled round."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.06 + 0.02 * br, 0.88 + 0.03 * br, 1.06)}
    add(p, "spine", rx=-0.12)
    add(p, "neck", rx=-0.1)
    add(p, "head", rx=-0.28 + 0.01 * br, rz=0.12)
    add(p, "hips", ry=0.15)
    return p


def pet(t):
    """Leans into a hand and rumbles, the tail thumping."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.03 * lean, 1)}
    add(p, "spine", rx=0.06 + 0.06 * lean)
    add(p, "head", rx=LOOK + 0.1 + 0.12 * lean, rz=0.16 + 0.12 * lean, ry=0.1 * lean)
    add(p, "hips", ry=0.2 * s(t, 3))
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.0, True, idle),
        "walk": (1.1, True, walk),
        "run": (0.6, True, run),
        "hop": (0.95, True, flop_hop),
        "carry": (1.2, True, carry),
        "pet": (2.2, True, pet),
        "attack": (0.9, False, bellyflop),
        "ability": (1.6, False, hum),
        "sleep": (4.0, True, snooze),
    }
)

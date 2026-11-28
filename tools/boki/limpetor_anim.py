"""Limpetor's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a giant limpet under a
riveted iron shield, stubborn as rock. It creeps on its foot with the shell rocking over it, clamps down to the ground
when it braces and heaves the whole boulder up when it fights."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def creep(t, amp):
    """The foot ripples forward under a shell that barely moves: it rocks side to side and dips with every pulse, the
    skirt stretching and squashing under it, the head leading low."""
    u = s(t, 1)
    p = {"root_at": (0, 0.006 * amp * s(t, 2, 0.25), 0)}
    p["root_sc"] = (1 + 0.02 * amp * s(t, 2), 1 - 0.03 * amp * s(t, 2), 1 - 0.02 * amp * s(t, 2))
    add(p, "root", rz=0.09 * amp * u, rx=0.04 * amp * s(t, 2, 0.5))
    add(p, "spine", rz=-0.06 * amp * u, rx=-0.04 * amp * s(t, 2))
    add(p, "head", rx=LOOK - 0.06 * amp, ry=-0.1 * amp * s(t, 1, 0.25))
    return p


def idle(t):
    """Sits clamped and still, a long slow breath swelling the shell, now and then a grudging look to the side."""
    br = s(t, 1)
    glance = seq(t, [(0, 0), (0.55, 0), (0.62, 1), (0.8, 1), (0.88, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br, 1 + 0.02 * br, 1 + 0.012 * br)}
    add(p, "spine", rx=0.015 * br)
    add(p, "head", rx=LOOK + 0.03 * s(t, 1, 0.2), ry=0.3 * glance + 0.03 * s(t, 1, 0.4))
    return p


def walk(t):
    return creep(t, 1.0)


def run(t):
    """A bulldozer's charge: shell tipped forward over the foot, the whole boulder shoving along in short pulses."""
    p = creep(t, 1.8)
    add(p, "root", rx=-0.08)
    add(p, "spine", rx=-0.06)
    add(p, "head", rx=-0.06)
    return p


def carry(t):
    return creep(t, 0.7)


def bash(t):
    """Attack: rocks the shell back on its foot, then drops it forward and down like a shield slammed on the ground."""
    wind = seq(t, [(0, 0), (0.34, 1), (0.42, 0.9), (0.5, 0), (1, 0)])
    slam = seq(t, [(0.38, 0), (0.5, 1), (0.64, 0.4), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0.03 * wind - 0.01 * slam, -0.03 * wind + 0.08 * slam)}
    p["root_sc"] = (1 - 0.03 * wind + 0.08 * slam, 1 + 0.05 * wind - 0.1 * slam, 1 - 0.03 * wind + 0.06 * slam)
    add(p, "root", rx=-0.3 * wind + 0.4 * slam)
    add(p, "spine", rx=-0.12 * wind + 0.15 * slam)
    add(p, "head", rx=LOOK - 0.1 * wind + 0.1 * slam)
    return p


def heave(t):
    """Its boulder heave: clamps flat and braces, the shell shuddering with the strain, then straightens and hurls the
    weight up and forward in one push."""
    brace = seq(t, [(0, 0), (0.28, 1), (0.62, 1), (0.7, 0), (1, 0)])
    push = seq(t, [(0.6, 0), (0.72, 1), (0.86, 0.3), (1, 0)])
    strain = s(t, 9) * brace
    p = {"root_at": (0, -0.02 * brace + 0.1 * push, 0.07 * push)}
    p["root_sc"] = (1 + 0.1 * brace + 0.01 * strain - 0.04 * push, 1 - 0.12 * brace + 0.2 * push, 1 + 0.06 * brace)
    add(p, "root", rx=0.04 * brace - 0.35 * push, rz=0.015 * strain)
    add(p, "spine", rx=0.08 * brace - 0.2 * push)
    add(p, "head", rx=LOOK - 0.1 * brace + 0.3 * push)
    return p


def heavy_hop(t):
    """Hop: a boulder's hop: a long crouch, a small lift with the shell staying level and the landing a flat thud."""
    air = seq(t, [(0, 0), (0.25, -0.7), (0.4, 0.25), (0.55, 1), (0.7, 0.25), (0.8, -1), (0.9, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.14 * down - 0.03 * up, 1 - 0.2 * down + 0.06 * up, 1 + 0.1 * down)
    add(p, "root", rz=0.04 * seq(t, [(0.3, 0), (0.55, 1), (0.8, -0.5), (1, 0)]))
    add(p, "head", rx=LOOK + 0.1 * up - 0.08 * down)
    return p


def clamp(t):
    """Sleep: presses itself flat to the ground under the shell, the head pulled in, a breath that hardly shows."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.1 + 0.01 * br, 0.8 + 0.015 * br, 1.1 + 0.01 * br)}
    add(p, "spine", rx=-0.06)
    add(p, "head", rx=-0.3 + 0.01 * br, rz=0.08)
    return p


def pet(t):
    """Not that it would say so, but it leans its shell into the hand and holds still for as long as it lasts."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.02 * lean, 1 - 0.025 * lean, 1 + 0.02 * lean)}
    add(p, "root", rz=0.04 * lean)
    add(p, "head", rx=LOOK + 0.06 * lean, rz=0.14 * lean, ry=0.08 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.4, True, idle),
        "walk": (1.3, True, walk),
        "run": (0.7, True, run),
        "hop": (1.0, True, heavy_hop),
        "carry": (1.4, True, carry),
        "pet": (2.6, True, pet),
        "attack": (1.0, False, bash),
        "ability": (1.5, False, heave),
        "sleep": (4.4, True, clamp),
    }
)

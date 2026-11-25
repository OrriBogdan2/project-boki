"""Heatherhorn's (Crofthorn's) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
highland cow that carries a walled garden, so the back stays level and the plod is slow and stately; it sweeps its long
horns sideways, bellows proudly with its chest out and, being stubborn, grazes whenever it likes."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
GRAZE = -0.32  # the head dropped to the grass (rx)


def plod(t, amp):
    """Four slow footfalls a stride: the garden barely tilts, the shoulders sway, the heavy head nods."""
    w = s(t, 1)
    p = {"root_at": (0, 0.01 * amp * s(t, 2), 0)}
    add(p, "root", rz=0.025 * amp * w, rx=0.015 * amp * s(t, 2, 0.5))
    add(p, "spine", ry=0.03 * amp * w, rx=-0.02 * amp * s(t, 2))
    add(p, "hips", ry=-0.03 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.5 - 0.06 + 0.05 * amp * s(t, 2, 0.5), ry=-0.05 * amp * w)
    return p


def idle(t):
    """Chews its cud: a slow breath, the head swaying a little, and now and then it lowers it for a mouthful."""
    br = s(t, 1)
    dip = seq(t, [(0, 0), (0.55, 0), (0.64, 1), (0.8, 1), (0.9, 0), (1, 0)])
    p = {"root_sc": (1 + 0.01 * br, 1 + 0.02 * br, 1 + 0.01 * br)}
    add(p, "spine", rx=-0.04 * dip)
    add(
        p,
        "head",
        rx=LOOK_UP * 0.5 + 0.03 * br + (GRAZE - LOOK_UP * 0.5) * dip + 0.04 * dip * s(t, 6),
        ry=0.12 * s(t, 1, 0.6) * (1 - dip),
    )
    return p


def walk(t):
    return plod(t, 1.0)


def run(t):
    """A heavy canter: the whole cow rocks front to back, the garden riding steady, the horns tossing."""
    p = plod(t, 0.5)
    rock = s(t, 1)
    p["root_at"] = (0, 0.02 + 0.015 * s(t, 2), 0)
    add(p, "root", rx=-0.07 * rock)
    add(p, "spine", rx=-0.07 * rock)
    add(p, "hips", rx=0.06 * rock)
    add(p, "head", rx=-0.05 + 0.1 * s(t, 1, 0.3), ry=0.08 * s(t, 2))
    return p


def carry(t):
    p = plod(t, 0.7)
    add(p, "head", rx=0.05)
    return p


def sweep(t):
    """Attack: sets its feet and lowers its head to one side, then hooks both horns across in one wide arc."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.4, 1), (0.5, 0), (1, 0)])
    arc = seq(t, [(0.3, -1), (0.4, -1), (0.55, 1), (0.72, 0.6), (1, 0)])
    p = {"root_at": (0, 0, 0.03 * wind - 0.08 * max(arc, 0))}
    p["root_sc"] = (1, 1 - 0.04 * wind, 1 + 0.03 * max(arc, 0))
    add(p, "root", rx=-0.06 * wind, rz=-0.05 * arc)
    add(p, "spine", ry=0.2 * arc, rx=-0.1 * wind)
    add(p, "hips", ry=-0.08 * arc)
    add(p, "head", rx=-0.32 * wind - 0.12 * max(arc, 0), ry=0.55 * arc, rz=-0.12 * arc)
    return p


def bellow(t):
    """Its E: plants its feet, swells its chest and throws its head back for a long proud bellow, then settles."""
    k = seq(t, [(0, 0), (0.25, 1), (0.7, 1), (0.85, -0.2), (1, 0)])
    up = max(k, 0)
    shake = s(t, 9) * seq(t, [(0, 0), (0.3, 0), (0.4, 1), (0.7, 1), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0.03 * up, -0.02 * up)}
    p["root_sc"] = (1 + 0.05 * up, 1 + 0.07 * up, 1 + 0.04 * up)
    add(p, "root", rx=0.08 * up)
    add(p, "spine", rx=0.1 * up)
    add(p, "head", rx=0.45 * up + 0.03 * shake, rz=0.03 * shake)
    return p


def lumber_hop(t):
    """Hop: a slow knees-bent heave off the ground and a heavy landing, the garden hardly rocking."""
    air = seq(t, [(0, 0), (0.22, -0.6), (0.4, 0.4), (0.55, 1), (0.72, 0.3), (0.82, -0.8), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.12 * up - 0.04 * down, 0)}
    p["root_sc"] = (1 + 0.12 * down - 0.02 * up, 1 - 0.15 * down + 0.05 * up, 1 + 0.06 * down)
    add(p, "spine", rx=0.08 * up - 0.06 * down)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.18 * up - 0.1 * down)
    return p


def graze(t):
    """Eat: nose down in the grass, tearing off a mouthful with a jerk, then chewing it slowly."""
    p = eat_ground(t)
    tear = seq(t, [(0, 0), (0.3, 0), (0.4, 1), (0.5, 0), (1, 0)])
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.1 + 0.15 * tear, ry=0.06 * s(t, 3))
    return p


def lie_down(t):
    """Sleep: folds its legs under it, its head resting low and turned in along its flank, breathing slowly."""
    br = s(t, 1)
    p = {"root_at": (0, -0.09, 0), "root_sc": (1.06 + 0.015 * br, 0.86 + 0.025 * br, 1.03)}
    add(p, "spine", rx=-0.04)
    add(p, "head", rx=-0.28 + 0.01 * br, ry=0.55, rz=0.15)
    return p


def pet(t):
    """Leans into a hand and chews on, a placid half-closed-eye sway."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    add(p, "root", rz=0.03 * lean)
    add(p, "head", rx=LOOK_UP * 0.2 - 0.12 + 0.03 * s(t, 3), rz=0.16 * lean, ry=0.1 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (4.0, True, idle),
        "walk": (1.3, True, walk),
        "run": (0.7, True, run),
        "hop": (1.1, True, lumber_hop),
        "carry": (1.4, True, carry),
        "pet": (2.8, True, pet),
        "attack": (1.1, False, sweep),
        "ability": (1.8, False, bellow),
        "sleep": (4.5, True, lie_down),
        "eat": (2.4, True, graze),
    }
)

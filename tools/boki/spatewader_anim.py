"""Barrelmander's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head, plus the file's
legs): a giant salamander with a rain barrel strapped to its back. A lazy wader: it moves in long S-bends, the
barrel sloshing a beat behind it, it lunges with a whole-body whip, bursts the barrel with a heave, and sprawls out
flat like a puddle to doze."""

import boki_clips
import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq
from vespyx_sides import SIDES

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def slosh(p, t, amp, n=1.0, ph=0.0):
    """The water in the barrel rolls the load: the spine tips against the body, a beat late."""
    add(p, "spine", rz=amp * s(t, n, ph - 0.15), rx=0.4 * amp * s(t, n, ph - 0.4))
    add(p, "root", rz=-0.4 * amp * s(t, n, ph))


def idle(t):
    """Lazy and good-natured: a slow breath, the head drifting up and down like it is half asleep, the barrel water
    lapping, and an occasional long gulp of the throat."""
    br = s(t, 1)
    gulp = seq(t, [(0.6, 0), (0.64, 1), (0.7, 0), (1, 0)])
    p = {"root_at": (0, 0.003 * br, 0), "root_sc": (1 + 0.012 * br, 1 + 0.02 * br, 1 + 0.012 * br)}
    slosh(p, t, 0.02)
    add(p, "hips", ry=0.05 * s(t, 1, 0.3))
    add(p, "neck", rx=0.03 * s(t, 1, 0.1), ry=0.08 * s(t, 1))
    add(p, "head", rx=LOOK + 0.05 * br - 0.08 * gulp, ry=0.1 * s(t, 1, 0.2))
    return p


def whip(t):
    """Attack: coils into an S, then snaps straight and lunges, the head striking out ahead of the body and the
    barrel slopping over after it."""
    k = seq(t, [(0, 0), (0.34, 1), (0.46, -1), (0.62, -0.7), (1, 0)])
    coil = max(k, 0)
    lunge = max(-k, 0)
    p = {"root_at": (0, -0.02 * coil, 0.05 * coil - 0.14 * lunge)}
    p["root_sc"] = (1 + 0.04 * coil - 0.04 * lunge, 1 - 0.04 * coil, 1 - 0.05 * coil + 0.08 * lunge)
    add(p, "hips", ry=0.3 * coil - 0.1 * lunge)
    add(p, "spine", ry=-0.28 * coil + 0.1 * lunge, rx=0.08 * coil - 0.12 * lunge)
    add(p, "neck", ry=-0.3 * coil, rx=-0.1 * lunge)
    add(p, "head", rx=LOOK + 0.1 * coil - 0.3 * lunge, ry=0.2 * coil)
    slosh(p, t, 0.05 * (0.5 + lunge), 2)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.4 * coil - 0.5 * lunge, rz=-sx * 0.1 * coil)
        add(p, "hleg1." + sd, rx=-0.2 * lunge)
    return p


def flood(t):
    """Its E: squats and the barrel water swirls, then heaves its front up and slams it down so the barrel bursts."""
    squat = seq(t, [(0, 0), (0.3, 1), (0.52, 1), (0.6, 0), (1, 0)])
    rear = seq(t, [(0.5, 0), (0.62, 1), (0.74, -1), (0.9, 0), (1, 0)])
    heave = max(rear, 0)
    slam = max(-rear, 0)
    p = {"root_at": (0, -0.03 * squat + 0.05 * heave - 0.02 * slam, 0)}
    p["root_sc"] = (1 + 0.1 * squat + 0.06 * slam, 1 - 0.14 * squat + 0.1 * heave - 0.1 * slam, 1 + 0.04 * squat)
    slosh(p, t, 0.1 * (squat + heave + slam), 3)
    add(p, "root", rx=0.3 * heave - 0.18 * slam)
    add(p, "spine", rx=0.1 * heave - 0.12 * slam)
    add(p, "head", rx=LOOK - 0.1 * squat + 0.3 * heave - 0.2 * slam)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.5 * heave - 0.3 * slam, rz=-sx * 0.25 * squat)
        add(p, "hleg1." + sd, rz=-sx * 0.2 * squat)
    return p


def splash_hop(t):
    """Hop: a flop-hop: the front pushes off first, the body bending into a long arc and the barrel lagging, a wet
    splat on landing."""
    air = seq(t, [(0, 0), (0.25, -0.7), (0.42, 0.3), (0.55, 1), (0.72, 0.3), (0.82, -1), (0.92, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.13 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.14 * down - 0.03 * up, 1 - 0.2 * down + 0.06 * up, 1 + 0.1 * down)
    slosh(p, t, 0.08 * (up + down), 2, 0.1)
    add(p, "root", rx=0.14 * seq(t, [(0.3, 0), (0.55, 1), (0.8, -0.6), (1, 0)]))
    add(p, "hips", ry=0.18 * s(t, 1) * up)
    add(p, "head", rx=LOOK + 0.1 * up - 0.1 * down)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=0.4 * up - 0.2 * down)
        add(p, "hleg1." + sd, rx=-0.5 * up + 0.2 * down)
    return p


def sprawl(t):
    """Sleep: spread out flat like a puddle, chin on the ground and legs splayed, the barrel rising on each breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.07, 0), "root_sc": (1.1 + 0.01 * br, 0.78 + 0.03 * br, 1.08)}
    add(p, "hips", ry=-0.2)
    add(p, "spine", ry=0.14)
    add(p, "neck", rx=-0.2, ry=0.2)
    add(p, "head", rx=-0.3 + 0.02 * br, ry=0.25, rz=0.15)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.9, rz=-sx * 0.6)
        add(p, "hleg1." + sd, rx=-0.9, rz=-sx * 0.6)
    return p


def pet(t):
    """It leans its broad head into the hand with a slow, pleased blink-nod, the barrel water lapping."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.03 * lean, 1)}
    slosh(p, t, 0.03)
    add(p, "neck", rx=0.08 * lean, rz=0.1 * lean)
    add(p, "head", rx=LOOK + 0.05 * lean, rz=0.2 * lean, ry=0.1 * lean)
    return p


def carry(t):
    """The shared trot with a salamander's sway: the body bends side to side, the barrel slopping behind."""
    p = boki_clips.carry(t)
    add(p, "spine", ry=0.12 * s(t, 1))
    add(p, "hips", ry=-0.12 * s(t, 1))
    slosh(p, t, 0.03, 2)
    return p


def eat(t):
    """Head down, a wide mouth gulp at the berry and three swallows, the barrel water lapping."""
    gulp = 0.5 + 0.5 * s(t, 3)
    p = {"root_at": (0, -0.015, -0.02), "prop_berry": "on"}
    slosh(p, t, 0.02, 3)
    add(p, "spine", rx=-0.12)
    add(p, "neck", rx=-0.2)
    add(p, "head", rx=-0.3 - 0.15 * gulp + LOOK * 0.5)
    return p


def gait(t, amp):
    """Walk and run on top of the planted-paw trot (`gait_layer.py`): the body bends in a long S, the head swinging
    against the hips, the barrel water slopping behind."""
    p = {}
    add(p, "hips", ry=-0.1 * amp * s(t, 1))
    add(p, "spine", ry=0.12 * amp * s(t, 1, 0.08))
    add(p, "neck", ry=0.06 * amp * s(t, 1, 0.2))
    add(p, "head", rx=-0.06 * (amp - 1), ry=0.1 * amp * s(t, 1, 0.3))
    slosh(p, t, 0.025 * amp, 2)
    return p


GAIT = {"walk": lambda t: gait(t, 1.0), "run": lambda t: gait(t, 1.7)}


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.4, True, idle),
        "hop": (1.05, True, splash_hop),
        "carry": (1.0, True, carry),
        "pet": (2.6, True, pet),
        "attack": (0.9, False, whip),
        "ability": (1.7, False, flood),
        "sleep": (4.6, True, sprawl),
        "eat": (2.2, True, eat),
    }
)

"""Murmurling's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head, plus the file's two
legs): a starling with pan-pipes for a tail. Small, quick and never still: the head snaps from side to side, it
darts at things and pecks, its tail pipes tip as it sings, and it tucks its head under to sleep."""

import boki_clips
import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq
from vespyx_sides import SIDES

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def idle(t):
    """A bird's fidget: the head freezes, snaps round to look, freezes again and tilts, the chest puffing and the
    pipe tail twitching up between looks."""
    look = seq(t, [(0, 0), (0.12, 0), (0.16, 1), (0.34, 1), (0.38, -0.8), (0.58, -0.8), (0.62, 0), (0.8, 0), (0.84, 0.5), (0.92, 0.5), (0.96, 0), (1, 0)])
    twitch = seq(t, [(0.7, 0), (0.73, 1), (0.78, 0), (0.81, 0.6), (0.86, 0), (1, 0)])
    br = s(t, 2)
    p = {"root_at": (0, 0.004 * br, 0), "root_sc": (1 + 0.025 * br, 1 + 0.03 * br, 1 + 0.02 * br)}
    add(p, "hips", rx=0.18 * twitch)
    add(p, "neck", ry=0.35 * look)
    add(p, "head", rx=LOOK + 0.03 * br, ry=0.35 * look, rz=0.2 * look * abs(look))
    return p


def dart(t):
    """Attack: shrinks back on its legs, then darts its whole body at the foe with a hard peck and flicks back."""
    k = seq(t, [(0, 0), (0.3, 1), (0.4, -1), (0.52, -0.2), (0.62, -1), (0.74, 0), (1, 0)])
    wind = max(k, 0)
    hit = max(-k, 0)
    p = {"root_at": (0, -0.02 * wind + 0.01 * hit, 0.04 * wind - 0.14 * hit)}
    p["root_sc"] = (1 + 0.04 * wind, 1 - 0.06 * wind + 0.03 * hit, 1 - 0.03 * hit)
    add(p, "root", rx=0.12 * wind - 0.3 * hit)
    add(p, "spine", rx=0.1 * wind - 0.15 * hit)
    add(p, "neck", rx=0.15 * wind - 0.2 * hit)
    add(p, "head", rx=LOOK + 0.2 * wind - 0.55 * hit)
    add(p, "hips", rx=0.2 * hit)
    for sd, _ in SIDES:
        add(p, "hleg1." + sd, rx=0.3 * wind - 0.15 * hit)
        add(p, "hleg2." + sd, rx=0.3 * wind)
    return p


def sing(t):
    """Its E: puffs its chest, throws its head back and trembles, the tail pipes fanning up and shaking, then bursts
    open as every note flies off as a bird."""
    puff = seq(t, [(0, 0), (0.28, 1), (0.62, 1), (0.7, -0.6), (0.85, 0), (1, 0)])
    on = max(puff, 0)
    burst = max(-puff, 0)
    note = s(t, 12) * on
    p = {"root_at": (0, 0.02 * on + 0.03 * burst, 0)}
    p["root_sc"] = (1 + 0.1 * on - 0.06 * burst, 1 + 0.1 * on - 0.08 * burst, 1 + 0.1 * on)
    add(p, "spine", rx=0.1 * on - 0.08 * burst)
    add(p, "hips", rx=0.35 * on - 0.15 * burst, ry=0.12 * note)
    add(p, "neck", rx=0.2 * on)
    add(p, "head", rx=LOOK + 0.45 * on - 0.2 * burst, rz=0.05 * note)
    for sd, _ in SIDES:
        add(p, "hleg1." + sd, rx=-0.1 * on + 0.2 * burst)
    return p


def flutter_hop(t):
    """Hop: a flapping hop, tail pipes streaming behind, the head tilting this way and that in the air."""
    air = seq(t, [(0, 0), (0.2, -0.6), (0.36, 0.3), (0.5, 1), (0.66, 0.3), (0.78, -0.5), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.24 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.08 * down - 0.04 * up, 1 - 0.14 * down + 0.08 * up, 1 + 0.06 * down)
    add(p, "root", rx=0.25 * seq(t, [(0.2, 0), (0.45, 1), (0.7, -0.5), (1, 0)]), rz=0.12 * s(t, 2) * up)
    add(p, "hips", rx=0.3 * up + 0.12 * s(t, 5) * up)
    add(p, "head", rx=LOOK + 0.2 * up - 0.1 * down, rz=0.25 * s(t, 2, 0.2) * up)
    for sd, _ in SIDES:
        add(p, "hleg1." + sd, rx=0.9 * up - 0.4 * down)
        add(p, "hleg2." + sd, rx=0.9 * up + 0.3 * down)
    return p


def tuck(t):
    """Sleep: a round ball of feathers on folded legs, the head turned back and buried in the shoulder."""
    br = s(t, 1)
    p = {"root_at": (0, -0.05, 0), "root_sc": (1.12 + 0.015 * br, 0.86 + 0.025 * br, 1.1 + 0.015 * br)}
    add(p, "spine", rx=-0.05)
    add(p, "neck", rx=-0.3, ry=0.9)
    add(p, "head", rx=-0.3, ry=0.9, rz=0.25)
    add(p, "hips", rx=-0.12)
    for sd, _ in SIDES:
        add(p, "hleg1." + sd, rx=1.0)
        add(p, "hleg2." + sd, rx=-1.2)
    return p


def pet(t):
    """It cocks its head into the stroke and ruffles up, the pipe tail wagging fast."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.05 * lean, 1 + 0.03 * lean, 1 + 0.05 * lean)}
    add(p, "hips", ry=0.2 * s(t, 3), rx=0.12)
    add(p, "neck", rz=0.15 * lean)
    add(p, "head", rx=LOOK + 0.05 * lean, rz=0.3 * lean, ry=0.12 * lean)
    return p


def carry(t):
    """The shared two-legged scurry, the load held to its chest and the head up over it."""
    p = boki_clips.carry(t)
    add(p, "head", rx=0.1)
    return p


def eat(t):
    """Pecks at the berry: three sharp dips of the head, the body rocking over its legs, a swallow between."""
    peck = max(s(t, 3), 0) ** 0.5
    p = {"root_at": (0, -0.01, -0.01 * peck), "prop_berry": "on"}
    add(p, "root", rx=-0.12 * peck)
    add(p, "spine", rx=-0.1)
    add(p, "neck", rx=-0.2 * peck)
    add(p, "head", rx=-0.55 - 0.5 * peck + LOOK * 0.5, ry=0.04 * s(t, 3))
    add(p, "hips", rx=0.15 * peck)
    return p


def gait(t, amp):
    """Walk and run on top of the trot (`gait_layer.py`): the head nods and thrusts with each step like a starling's,
    the body waddles over its legs and the pipe tail pumps."""
    p = {}
    add(p, "root", rz=0.04 * amp * s(t, 1), rx=-0.06 * (amp - 1))
    add(p, "hips", rx=0.1 * amp * s(t, 2, 0.25) + 0.12 * (amp - 1), ry=-0.06 * amp * s(t, 1))
    add(p, "neck", rx=-0.1 * amp * s(t, 2, 0.1) - 0.08 * (amp - 1))
    add(p, "head", rx=0.12 * amp * s(t, 2, 0.35), ry=0.05 * amp * s(t, 1, 0.25))
    return p


GAIT = {"walk": lambda t: gait(t, 1.0), "run": lambda t: gait(t, 1.7)}


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (2.4, True, idle),
        "hop": (0.8, True, flutter_hop),
        "carry": (0.7, True, carry),
        "pet": (2.0, True, pet),
        "attack": (0.7, False, dart),
        "ability": (1.5, False, sing),
        "sleep": (3.6, True, tuck),
        "eat": (2.0, True, eat),
    }
)

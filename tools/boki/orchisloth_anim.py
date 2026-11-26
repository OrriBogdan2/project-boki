"""Terrasloth's (orchisloth) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
three-toed sloth that carries a glass greenhouse on its back. Nothing is hurried: each step is a long reach and a
slow hauling of the weight over it, the greenhouse swaying a beat behind, a swipe takes a whole breath, and its
wall goes up as a tall, unhurried stretch."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def haul(t, amp, lean, cycles=1):
    """The sloth's step: the weight rolls onto one side, the far shoulder reaches out and forward, then the body is
    hauled after it; the hips (and the greenhouse on them) swing the other way and arrive late."""
    a = s(t, cycles)
    reach = s(t, cycles * 2, 0.15)
    p = {"root_at": (0, 0.004 * amp * (1 + reach), -0.02 * amp * reach)}
    p["root_sc"] = (1 + 0.02 * amp * reach, 1 - 0.03 * amp * reach, 1 - 0.02 * amp * reach)
    add(p, "root", rz=0.08 * amp * a, rx=lean * 0.5, ry=0.03 * amp * a)
    add(p, "spine", rx=-lean + 0.05 * amp * reach, ry=0.14 * amp * a, rz=0.05 * amp * a)
    add(p, "hips", ry=-0.1 * amp * s(t, cycles, 0.12), rz=-0.06 * amp * s(t, cycles, 0.12), rx=0.03 * amp * reach)
    add(p, "neck", ry=-0.06 * amp * a)
    add(p, "head", rx=LOOK - lean * 0.5 + 0.05 * amp * reach, ry=-0.1 * amp * a, rz=0.04 * amp * s(t, cycles, 0.3))
    return p


def idle(t):
    """Dreamy: a long slow breath, the head drifting round and drooping, one big yawn that sets the greenhouse
    swaying, then the eyelids sag again."""
    br = s(t, 1)
    yawn = seq(t, [(0, 0), (0.5, 0), (0.62, 1), (0.74, 1), (0.88, 0), (1, 0)])
    nod = seq(t, [(0, 0), (0.2, 1), (0.34, 0.2), (0.44, 0.9), (0.5, 0), (1, 0)])
    p = {"root_sc": (1 + 0.02 * br + 0.02 * yawn, 1 - 0.03 * br + 0.04 * yawn, 1 + 0.02 * br)}
    add(p, "spine", rx=0.03 * br + 0.18 * yawn)
    add(p, "neck", ry=0.1 * s(t, 1, 0.1))
    add(p, "head", rx=LOOK + 0.03 * br - 0.16 * nod + 0.35 * yawn, ry=0.18 * s(t, 1, 0.15), rz=0.08 * s(t, 1, 0.4))
    add(p, "hips", rz=0.04 * s(t, 1, 0.3) + 0.04 * yawn * s(t, 3), ry=0.03 * s(t, 1, 0.6))
    return p


def walk(t):
    return haul(t, 1.0, 0.0)


def run(t):
    """As fast as a sloth gets: the same reaching haul, quicker and bigger, the head low, a stumble in it."""
    p = haul(t, 1.5, 0.12, 2)
    add(p, "root", rx=0.04)
    add(p, "head", rx=-0.05)
    return p


def carry(t):
    return haul(t, 0.7, -0.04)


def drift(t):
    """Hop: a deliberate squat, then a slow floaty rise with the limbs spread like a falling leaf, and a soft landing."""
    air = seq(t, [(0, 0), (0.25, -0.6), (0.45, 0.5), (0.58, 1), (0.74, 0.4), (0.9, -0.35), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.12 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down - 0.04 * up, 1 - 0.14 * down + 0.07 * up, 1 + 0.1 * down - 0.04 * up)
    add(p, "root", rz=0.1 * up * s(t, 1), rx=0.1 * up)
    add(p, "spine", rx=0.12 * up - 0.12 * down)
    add(p, "hips", rz=-0.1 * up * s(t, 1, 0.1))
    add(p, "head", rx=LOOK + 0.1 * up - 0.12 * down, rz=0.08 * up)
    return p


def swipe(t):
    """Attack: it takes a long time to get going. The claw is raised and held back, the whole body leaning after
    it, then comes round in one heavy sweep that carries the shoulders with it, and sags back."""
    k = seq(t, [(0, 0), (0.4, 1), (0.52, 1), (0.64, -1), (0.8, -0.6), (1, 0)])
    wind = max(k, 0)
    hit = max(-k, 0)
    p = {"root_at": (0, 0.02 * wind, 0.02 * wind - 0.05 * hit)}
    p["root_sc"] = (1 - 0.04 * wind + 0.06 * hit, 1 + 0.1 * wind - 0.1 * hit, 1 - 0.04 * wind + 0.06 * hit)
    add(p, "root", rx=0.14 * wind - 0.1 * hit, rz=-0.1 * wind + 0.12 * hit)
    add(p, "spine", rx=0.24 * wind - 0.26 * hit, ry=0.34 * wind - 0.3 * hit)
    add(p, "hips", ry=-0.18 * wind + 0.14 * hit, rz=0.05 * hit)
    add(p, "head", rx=LOOK + 0.12 * wind - 0.14 * hit, ry=-0.2 * wind + 0.12 * hit)
    return p


def open_glass(t):
    """Cast (its glass wall): draws itself up tall, shoulders back, and holds there while the greenhouse on its back
    rattles open, then lets the mist out with a long exhale, drooping back down."""
    k = seq(t, [(0, 0), (0.35, 1), (0.7, 1), (0.9, -0.3), (1, 0)])
    tall = max(k, 0)
    sag = max(-k, 0)
    open_ = seq(t, [(0, 0), (0.4, 0), (0.5, 1), (0.7, 1), (0.82, 0), (1, 0)])
    p = {"root_at": (0, 0.03 * tall, -0.02 * tall)}
    p["root_sc"] = (1 - 0.04 * tall + 0.06 * sag, 1 + 0.16 * tall - 0.1 * sag, 1 - 0.04 * tall + 0.06 * sag)
    add(p, "root", rx=0.2 * tall - 0.06 * sag)
    add(p, "spine", rx=0.34 * tall - 0.14 * sag)
    add(p, "hips", rx=-0.16 * tall, rz=0.05 * open_ * s(t, 7))
    add(p, "neck", rx=0.1 * tall)
    add(p, "head", rx=LOOK + 0.3 * tall - 0.12 * sag, rz=0.12 * s(t, 1, 0.2) * tall)
    return p


def hang(t):
    """Sleep: rolled forward into a ball like a sloth asleep on its branch, head tucked on its chest, a very slow
    breath, the greenhouse rising and falling on its back."""
    br = s(t, 1)
    p = {"root_at": (0, -0.025, 0), "root_sc": (1.06 + 0.025 * br, 0.86 + 0.035 * br, 1.06 + 0.025 * br)}
    add(p, "spine", rx=-0.38 + 0.02 * br)
    add(p, "hips", rx=0.12)
    add(p, "neck", rx=-0.3)
    add(p, "head", rx=-0.4 + 0.01 * br, rz=0.1)
    return p


def pet(t):
    """Melts under a hand: tips its head into it, eyes shut, the whole body going slack and swaying."""
    lean = 0.5 + 0.5 * s(t, 0.5)
    p = {"root_sc": (1 + 0.04 * lean, 1 - 0.05 * lean, 1 + 0.04 * lean)}
    add(p, "root", rz=0.05 * s(t, 0.5))
    add(p, "spine", rx=0.05 + 0.05 * lean)
    add(p, "head", rx=LOOK + 0.08 * lean, rz=0.2 + 0.12 * lean, ry=0.08 * s(t, 0.5, 0.2))
    add(p, "hips", ry=0.1 * s(t, 0.5, 0.3))
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (4.2, True, idle),
        "walk": (1.7, True, walk),
        "run": (0.95, True, run),
        "hop": (1.2, True, drift),
        "carry": (1.7, True, carry),
        "pet": (3.0, True, pet),
        "attack": (1.2, False, swipe),
        "ability": (2.0, False, open_glass),
        "sleep": (5.0, True, hang),
    }
)

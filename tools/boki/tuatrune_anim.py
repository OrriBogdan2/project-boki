"""Tuatrune's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head), over the four-legged
rig `auto_legs.py` gave it: a spiny tuatara with a giant key for a tail. A lizard goes by bending its spine from side
to side against its steps, the head held level by turning against the bend; the tail (skinned to the hips) whips
the other way. `reclip_own.py` keeps the file's planted-paw leg curves and root height for walk and run, so those two
clips here are the body only: spine, hips, neck, head, root turn."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LEGS = tuple(p + "leg1." + sd for p in "fh" for sd in "LR")
KEEP_LEGS = ("walk", "run")  # reclip_own keeps the file's leg curves and root_at for these


def slink(t, n, bend, pitch, head_down):
    """The lizard's spine-bend: the shoulders and the hips turn opposite ways once a stride, the head turning back
    against the shoulders so it stays pointing ahead, the whole body rolling a touch the other way."""
    w = s(t, n)
    p = {}
    add(p, "root", rz=0.02 * bend * w)
    add(p, "hips", ry=0.07 * bend * w)
    add(p, "spine", ry=-0.07 * bend * w, rx=-pitch)
    add(p, "neck", ry=0.05 * bend * w + 0.025 * bend * s(t, n * 2), rx=pitch * 0.6)
    add(p, "head", rx=LOOK_UP * 0.8 - head_down + 0.04 * s(t, n * 2, 0.5), ry=0.04 * bend * w)
    return p


def idle(t):
    """The tuatara's still watchfulness: slow throat-breaths, a head that turns in jerks to look, and now and then a
    push-up on the front of the body (the spine tips, the key tail lifting behind it)."""
    br = s(t, 1)
    look = seq(t, [(0, 0), (0.25, 0), (0.3, 1), (0.52, 1), (0.58, -0.7), (0.76, -0.7), (0.82, 0), (1, 0)])
    push = seq(t, [(0, 0), (0.84, 0), (0.88, 1), (0.92, 0), (0.96, 1), (1, 0)])
    p = {"root_at": (0, 0.004 * push, 0), "root_sc": (1 + 0.01 * br, 1 + 0.018 * br, 1)}
    add(p, "hips", rx=-0.04 * push)
    add(p, "spine", rx=0.03 + 0.05 * push + 0.015 * br)
    add(p, "neck", ry=0.2 * look, rx=0.04 * push)
    add(p, "head", rx=LOOK_UP + 0.06 * push + 0.03 * br, ry=0.22 * look, rz=0.08 * look)
    return p


def walk(t):
    return slink(t, 1, 1.0, 0.0, 0.0)


def run(t):
    """A sprint: the spine bends hard twice as fast, the head low and the chest dropped."""
    p = slink(t, 2, 1.6, 0.06, 0.25)
    add(p, "root", rx=-0.04)
    return p


def carry(t):
    p = slink(t, 1, 0.8, 0.0, 0.0)
    add(p, "head", rx=0.12)
    return p


def snap(t):
    """Attack: freezes, lowers the front and bends the spine back like a bowstring, then whips it straight and
    snaps the jaws, the key tail lashing the other way."""
    wind = seq(t, [(0, 0), (0.32, 1), (0.44, 0), (1, 0)])
    hit = seq(t, [(0.32, 0), (0.44, 1), (0.58, 0.6), (0.82, 0), (1, 0)])
    p = {"root_at": (0, -0.02 * wind + 0.01 * hit, 0.04 * wind - 0.2 * hit)}
    add(p, "hips", ry=0.18 * wind - 0.2 * hit, rx=0.1 * wind)
    add(p, "spine", ry=-0.2 * wind + 0.15 * hit, rx=-0.15 * wind - 0.05 * hit)
    add(p, "neck", ry=-0.1 * wind, rx=-0.15 * wind + 0.15 * hit)
    add(p, "head", rx=LOOK_UP * (1 - 0.5 * wind) + 0.35 * hit - 0.15 * wind, ry=0.15 * hit * s(t, 7))
    for leg in LEGS:
        add(p, leg, rx=(0.25 if leg[0] == "f" else -0.2) * hit)
    return p


def rune_flare(t):
    """Its E: rears onto its hind legs, spine arched, and shakes the key tail till the runes along it glow,
    then drops to all fours."""
    rear = seq(t, [(0, 0), (0.24, 1), (0.74, 1), (0.9, 0), (1, 0)])
    shake = rear * seq(t, [(0.3, 0), (0.36, 1), (0.7, 1), (0.76, 0)])
    p = {"root_at": (0, 0.03 * rear, 0)}
    add(p, "root", rx=0.38 * rear)
    add(p, "hips", ry=0.16 * shake * s(t, 6), rx=-0.15 * rear)
    add(p, "spine", rx=0.2 * rear, ry=-0.12 * shake * s(t, 6))
    add(p, "neck", rx=0.15 * rear)
    add(p, "head", rx=LOOK_UP + 0.25 * rear - 0.05 * shake, ry=0.05 * shake * s(t, 3))
    for leg in LEGS:
        add(p, leg, rx=(0.55 if leg[0] == "f" else -0.15) * rear)
    return p


def scuttle_hop(t):
    """Hop: coils the spine, springs with the front legs thrown out and the key tail swung round for balance, and
    lands splayed, then straightens."""
    air = seq(t, [(0, 0), (0.22, -0.7), (0.38, 0.4), (0.5, 1), (0.68, 0.4), (0.8, -0.9), (0.92, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.025 * down, 0)}
    p["root_sc"] = (1 + 0.05 * down, 1 - 0.1 * down + 0.03 * up, 1)
    add(p, "root", rx=0.12 * up - 0.06 * down)
    add(p, "hips", ry=0.3 * up * s(t, 1, 0.1) + 0.08 * down)
    add(p, "spine", ry=-0.25 * up * s(t, 1, 0.1), rx=-0.12 * down + 0.05 * up)
    add(p, "neck", rx=0.1 * up)
    add(p, "head", rx=LOOK_UP + 0.15 * up - 0.1 * down)
    for leg in LEGS:
        add(p, leg, rx=(0.7 if leg[0] == "f" else -0.6) * up)
    return p


def sprawl(t):
    """Sleep: flat on its belly with the legs splayed, the spine bent into a lazy C and the chin on the ground."""
    br = s(t, 1)
    p = {"root_at": (0, -0.06, 0), "root_sc": (1.04, 0.86 + 0.025 * br, 1)}
    add(p, "hips", ry=0.3)
    add(p, "spine", ry=-0.18)
    add(p, "neck", rx=-0.15, ry=0.3)
    add(p, "head", rx=-0.3 + 0.015 * br, ry=0.35, rz=0.15)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.2, True, idle),
        "walk": (0.9, True, walk),
        "run": (0.5, True, run),
        "hop": (0.9, True, scuttle_hop),
        "carry": (0.9, True, carry),
        "attack": (0.8, False, snap),
        "ability": (1.5, False, rune_flare),
        "sleep": (4.2, True, sprawl),
    }
)

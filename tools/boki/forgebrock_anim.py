"""Forgebrock's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a big bear-built badger
that stands upright with a furnace on its back and hammer-heads for paws. It is heavy and deliberate: a rolling
shoulder-to-shoulder tread that thuds, a two-fisted hammer-blow for the attack and the furnace belching up as its
ability, the chest glowing with each breath."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT


def furnace(p, k):
    """The furnace chest swelling with its glow: `k` 0..1."""
    p["root_sc"] = (1 + 0.03 * k, 1 + 0.05 * k, 1 + 0.03 * k)


def idle(t):
    """Stands square with its weight on its fists, the furnace breathing in and out; every so often it clenches and
    rolls its shoulders."""
    br = s(t, 1)
    roll = seq(t, [(0, 0), (0.6, 0), (0.68, 1), (0.78, -1), (0.88, 0), (1, 0)])
    p = {}
    furnace(p, 0.5 + 0.5 * br)
    add(p, "spine", rx=0.02 * br, rz=0.05 * roll)
    add(p, "hips", rz=-0.03 * roll)
    add(p, "head", rx=LOOK_UP * 0.3 + 0.03 * br, ry=0.12 * s(t, 1, 0.2) + 0.15 * roll)
    return p


def plod(t, amp):
    """A tread you hear: each step the whole body drops onto the planted foot (a dip and a thud), the shoulders
    rolling over it."""
    w = s(t, 1)
    p = {"root_at": (0, -0.015 * amp * abs(s(t, 1, 0.25)) + 0.008 * amp, 0)}
    add(p, "root", rz=0.06 * amp * w, rx=0.02 * amp * s(t, 2, 0.5))
    add(p, "spine", ry=0.08 * amp * w, rz=-0.03 * amp * w)
    add(p, "hips", ry=-0.07 * amp * w, rz=0.03 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.3 - 0.04 * amp + 0.02 * amp * s(t, 2), ry=-0.1 * amp * w)
    return p


def walk(t):
    return plod(t, 1.0)


def run(t):
    """A charging stomp: leaning hard into it, fists pumping, each footfall a hard dip."""
    p = plod(t, 1.5)
    add(p, "root", rx=-0.16)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.12)
    return p


def carry(t):
    p = plod(t, 0.9)
    add(p, "head", rx=0.1)
    return p


def hop(t):
    """A heavy, short jump: a deep crouch, a push up with a grunt, and a landing that shudders the furnace."""
    air = seq(t, [(0, 0), (0.22, -0.9), (0.38, 0.3), (0.52, 1), (0.66, 0.3), (0.78, -1), (0.92, 0.1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    shake = seq(t, [(0, 0), (0.78, 0), (0.84, 1), (0.92, -0.6), (1, 0)])
    p = {"root_at": (0, 0.09 * up - 0.04 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down, 1 - 0.14 * down + 0.06 * up, 1 + 0.1 * down)
    add(p, "root", rx=0.06 * up - 0.06 * down)
    add(p, "spine", rz=0.05 * shake)
    add(p, "head", rx=LOOK_UP * 0.3 + 0.1 * up - 0.12 * down)
    return p


def hammer(t):
    """Attack: both fists up over the head, a wind-up that rocks it back, then the double blow slammed down and
    the furnace flaring on the stop."""
    wind = seq(t, [(0, 0), (0.35, 1), (0.46, 1), (0.52, 0), (1, 0)])
    blow = seq(t, [(0.44, 0), (0.54, 1), (0.64, 1), (0.84, 0.15), (1, 0)])
    p = {"root_at": (0, 0.04 * wind - 0.03 * blow, 0.03 * wind - 0.1 * blow)}
    furnace(p, 0.2 * wind + 0.9 * blow)
    add(p, "root", rx=-0.22 * wind + 0.4 * blow)
    add(p, "spine", rx=-0.1 * wind + 0.18 * blow)
    add(p, "head", rx=-0.06 * wind - 0.25 * blow)
    return p


def stoke(t):
    """Its E: hunches, sucks the air in until the furnace chest swells and glows, then rears up and roars it out in
    a belch of heat that shudders the whole body."""
    k = seq(t, [(0, 0), (0.4, -1), (0.5, -1), (0.6, 1), (0.82, 0.4), (1, 0)])
    dn = max(-k, 0)
    up = max(k, 0)
    roar = seq(t, [(0, 0), (0.56, 0), (0.62, 1), (0.84, 0.6), (1, 0)])
    p = {"root_at": (0, 0.05 * up - 0.02 * dn, 0.02 * up)}
    p["root_sc"] = (1 + 0.12 * dn + 0.03 * roar * s(t, 12), 1 + 0.1 * dn + 0.06 * up, 1 + 0.12 * dn)
    add(p, "root", rx=0.3 * up - 0.1 * dn, rz=0.04 * roar * s(t, 12))
    add(p, "spine", rx=0.12 * up - 0.12 * dn)
    add(p, "head", rx=LOOK_UP * 0.3 + 0.35 * up - 0.2 * dn)
    return p


def gobble(t):
    """Eat: hunched over the food, bolting it in great jerking mouthfuls."""
    p = eat_ground(t)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=0.07 * s(t, 4), ry=0.06 * s(t, 4, 0.25))
    return p


def pet(t):
    """Gruff but pleased: ducks its big head down into the hand, the furnace glowing warmer, a slow shoulder shrug."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    furnace(p, 0.3 + 0.7 * lean)
    add(p, "spine", rx=-0.05 * lean, rz=0.03 * s(t, 1, 0.25))
    add(p, "head", rx=LOOK_UP * 0.2 - 0.06 + 0.08 * lean, rz=0.14 * lean, ry=0.08 * lean)
    return p


def bank(t):
    """Sleep: settled flat down like a banked fire, head on its fists, the furnace glow dimming slowly with each
    breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.08, 0)}
    p["root_sc"] = (1.08 + 0.02 * br, 0.82 + 0.03 * br, 1.06)
    add(p, "spine", rx=-0.12)
    add(p, "head", rx=-0.3 + 0.01 * br, ry=0.15, rz=0.08)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.2, True, idle),
        "walk": (1.0, True, walk),
        "run": (0.55, True, run),
        "hop": (1.0, True, hop),
        "carry": (1.0, True, carry),
        "pet": (2.2, True, pet),
        "attack": (1.0, False, hammer),
        "ability": (1.5, False, stoke),
        "sleep": (4.0, True, bank),
        "eat": (1.8, True, gobble),
    }
)

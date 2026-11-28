"""Embrook's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a rook with a coal-bed
back that is all quick, jerky bird: it cocks its head at everything, struts with the head bobbing against the body,
bounds low on the run, stabs its beak in as the attack and flares its cinder wings and breathes the embers up as its
ability."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT


def glow(p, k):
    """The coal bed under the feathers swelling: the body breathes out by `k` (0..1) of its glow."""
    p["root_sc"] = (1 + 0.05 * k, 1 + 0.07 * k, 1 + 0.05 * k)


def idle(t):
    """Perched and wary: the head snaps to one side, holds, snaps to the other; the coals breathe, and now and then
    it ruffles every feather at once."""
    br = s(t, 2)
    p = {}
    glow(p, 0.5 + 0.5 * br)
    look = seq(t, [(0, 0), (0.1, 0), (0.14, 1), (0.34, 1), (0.38, -1), (0.56, -1), (0.6, 0.4), (0.7, 0.4), (0.74, 0), (1, 0)])
    tilt = seq(t, [(0, 0), (0.1, 0), (0.14, 1), (0.34, 1), (0.38, -0.6), (0.56, -0.6), (0.6, 0), (1, 0)])
    ruffle = seq(t, [(0, 0), (0.8, 0), (0.83, 1), (0.86, -1), (0.89, 0.8), (0.92, -0.5), (0.96, 0), (1, 0)])
    add(p, "head", rx=LOOK_UP * 0.5 + 0.03 * br, ry=0.55 * look, rz=0.28 * tilt)
    add(p, "neck", ry=0.15 * look)
    add(p, "root", rz=0.05 * ruffle)
    add(p, "spine", rz=0.04 * ruffle)
    return p


def strut(t, amp):
    """A bird's walk: the head bobs forward and snaps back against the body each step, the body rocking foot to foot."""
    w = s(t, 1)
    snap = seq(t % 0.5 * 2, [(0, -1), (0.55, 1), (0.6, 1), (0.75, -1), (1, -1)])
    p = {"root_at": (0, 0.006 * amp * abs(s(t, 1)), 0)}
    add(p, "root", rz=0.07 * amp * w, rx=-0.03 * amp)
    add(p, "spine", rx=0.05 * amp * snap)
    add(p, "neck", rx=-0.1 * amp * snap)
    add(p, "head", rx=LOOK_UP * 0.4 - 0.12 * amp * snap, ry=-0.1 * amp * w)
    return p


def walk(t):
    return strut(t, 1.0)


def run(t):
    """A low bounding scuttle: leaning right in, wings half-spread (the body widened), the whole bird skipping."""
    air = max(s(t, 2), 0.0)
    p = strut(t, 0.6)
    p["root_at"] = (0, 0.045 * air, 0)
    p["root_sc"] = (1 + 0.05 * air, 1 - 0.03 * air, 1 + 0.04 * air)
    add(p, "root", rx=-0.22 + 0.05 * s(t, 2, 0.25), rz=0.05 * s(t, 1))
    add(p, "spine", rx=-0.08)
    add(p, "head", rx=-0.1)
    return p


def carry(t):
    p = strut(t, 0.8)
    add(p, "head", rx=0.1)
    add(p, "neck", rx=0.06)
    return p


def hop(t):
    """Crouch, a flap-assisted spring with the body stretched tall, wings snapped out, a flutter down."""
    air = seq(t, [(0, 0), (0.16, -0.8), (0.32, 0.3), (0.5, 1), (0.68, 0.5), (0.8, -0.6), (0.9, 0.1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    flap = s(t, 4) * up
    p = {"root_at": (0, 0.16 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down + 0.08 * abs(flap), 1 - 0.14 * down + 0.08 * up, 1 + 0.05 * down)
    add(p, "root", rx=0.14 * up - 0.1 * down, rz=0.06 * flap)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.12 * up - 0.1 * down)
    return p


def peck(t):
    """Attack: rears the head back, then stabs the beak down and in, the whole bird lunging after it; the coals flash."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.4, 0.8), (0.46, 0), (1, 0)])
    stab = seq(t, [(0.36, 0), (0.46, 1), (0.58, 1), (0.8, 0.15), (1, 0)])
    p = {"root_at": (0, 0.01 * wind - 0.025 * stab, 0.04 * wind - 0.13 * stab)}
    glow(p, 0.2 * wind + 0.9 * stab)
    add(p, "root", rx=0.12 * wind - 0.3 * stab)
    add(p, "spine", rx=0.1 * wind - 0.1 * stab)
    add(p, "neck", rx=0.3 * wind - 0.5 * stab)
    add(p, "head", rx=LOOK_UP * 0.4 + 0.3 * wind - 0.55 * stab)
    return p


def blaze(t):
    """Its E: draws up tall with the wings flared wide and the coals swelling, then beats down and the embers burst
    out of the feathers (a rippling shudder through the whole body)."""
    k = seq(t, [(0, 0), (0.38, 1), (0.48, 1), (0.56, -1), (0.76, -0.3), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    burst = seq(t, [(0, 0), (0.54, 0), (0.6, 1), (0.8, 0.4), (1, 0)])
    p = {"root_at": (0, 0.06 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.22 * up - 0.04 * down + 0.05 * burst, 1 + 0.08 * up - 0.12 * down + 0.06 * burst,
                    1 + 0.06 * up)
    add(p, "root", rx=0.32 * up - 0.08 * down, rz=0.05 * burst * s(t, 14))
    add(p, "spine", rx=0.15 * up - 0.1 * down, rz=0.06 * burst * s(t, 14, 0.25))
    add(p, "neck", rx=0.2 * up - 0.2 * down)
    add(p, "head", rx=LOOK_UP * 0.4 + 0.3 * up - 0.2 * down)
    return p


def peck_eat(t):
    """Eat: three hard stabs at the food and a toss of the head to swallow, coals flickering with each."""
    stab = seq(t * 4 % 1.0, [(0, 0), (0.25, 1), (0.45, 0), (1, 0)]) if t < 0.75 else 0.0
    toss = seq(t, [(0.75, 0), (0.82, 1), (0.92, 0), (1, 0)])
    p = {"root_at": (0, -0.01, 0)}
    add(p, "root", rx=-0.12 * stab)
    add(p, "neck", rx=-0.2 - 0.3 * stab + 0.35 * toss)
    add(p, "head", rx=-0.15 - 0.35 * stab + 0.3 * toss)
    glow(p, 0.5 * stab)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Fluffs up under a hand: the head tips into it, the feathers swelling, a slow content rock."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    glow(p, 0.6 + 0.4 * lean)
    add(p, "root", rz=0.04 * s(t, 1, 0.25))
    add(p, "head", rx=LOOK_UP * 0.4 + 0.08 * lean, rz=0.25 * lean)
    return p


def roost(t):
    """Sleep: the body drawn into a round of fluffed feathers, the head tucked back under, the coals dimming with the
    breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.05, 0)}
    p["root_sc"] = (1.08 + 0.02 * br, 0.86 + 0.03 * br, 1.06)
    add(p, "root", rx=0.05)
    add(p, "neck", rx=-0.2, ry=0.5)
    add(p, "head", rx=-0.25, ry=1.1, rz=0.2)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.2, True, idle),
        "walk": (0.7, True, walk),
        "run": (0.4, True, run),
        "hop": (0.85, True, hop),
        "carry": (0.8, True, carry),
        "pet": (2.2, True, pet),
        "attack": (0.7, False, peck),
        "ability": (1.4, False, blaze),
        "sleep": (3.6, True, roost),
        "eat": (1.6, True, peck_eat),
    }
)

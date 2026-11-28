"""Anchorbill's (casquebill) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
dignified hornbill whose casque is a ship's anchor. It carries itself like a bird that knows its weight: a measured
strut with the head riding level, a bill that clacks when it disagrees, and a drop out of the sky for a fight."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def clack(t, at, n=3):
    """n quick bill snaps from `at` on: 1 while the bill is open."""
    snaps = [(at + i * 0.04 + d, v) for i in range(n) for d, v in ((0.01, 1), (0.03, 0))]
    return seq(t, [(0, 0), (at, 0), *snaps, (1, 0)])


def strut(t, amp, rate):
    """A bird's march: the body rolls over each planted side, the head held level and darting ahead on every step,
    the heavy casque making it dip a little at each footfall."""
    w = s(t, rate)
    p = {"root_at": (0, -0.008 * amp * abs(s(t, rate)), 0.012 * amp * s(t, 2 * rate, 0.25))}
    add(p, "root", rz=0.06 * amp * w, rx=0.03 * amp * s(t, 2 * rate))
    add(p, "spine", rz=-0.05 * amp * w, rx=-0.03 * amp)
    add(p, "neck", rx=0.1 * amp * s(t, 2 * rate, 0.1))
    add(p, "head", rx=LOOK - 0.1 * amp * s(t, 2 * rate, 0.1), ry=-0.05 * amp * w)
    return p


def idle(t):
    """Upright and stern, a slow breath; now and then the head turns away as if offended and the bill clacks."""
    br = s(t, 1)
    away = seq(t, [(0, 0), (0.5, 0), (0.58, 1), (0.84, 1), (0.92, 0), (1, 0)])
    p = {"root_sc": (1 + 0.01 * br, 1 + 0.015 * br, 1 + 0.01 * br)}
    add(p, "spine", rx=0.02 * br)
    add(p, "neck", rx=0.05 * away)
    add(p, "head", rx=LOOK + 0.03 * s(t, 1, 0.3) + 0.12 * clack(t, 0.64), ry=0.55 * away)
    return p


def walk(t):
    return strut(t, 1.0, 1)


def run(t):
    """A heavy forward run, body tipped down onto the bill, quick short strides."""
    p = strut(t, 1.5, 2)
    add(p, "root", rx=-0.12)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.08)
    return p


def carry(t):
    return strut(t, 0.7, 1)


def dive(t):
    """Attack: rears up, bill high, then drops like an anchor, the casque leading the plunge, and hauls itself up."""
    up = seq(t, [(0, 0), (0.3, 1), (0.4, 1), (0.46, 0), (1, 0)])
    drop = seq(t, [(0.38, 0), (0.48, 1), (0.6, 0.85), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0.05 * up - 0.03 * drop, -0.03 * up + 0.1 * drop)}
    p["root_sc"] = (1 - 0.03 * up + 0.03 * drop, 1 + 0.06 * up - 0.1 * drop, 1 + 0.04 * drop)
    add(p, "root", rx=-0.25 * up + 0.5 * drop)
    add(p, "spine", rx=-0.1 * up + 0.2 * drop)
    add(p, "head", rx=LOOK + 0.25 * up - 0.5 * drop)
    return p


def slam(t):
    """Its Gravity Slam: floats up with the casque glowing, hangs a breath, then comes down all at once and the
    landing squashes it flat, the bill clacking twice."""
    air = seq(t, [(0, 0), (0.3, 1), (0.55, 1), (0.64, -1), (0.76, 0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.16 * up, 0)}
    p["root_sc"] = (1 - 0.04 * up + 0.2 * down, 1 + 0.06 * up - 0.3 * down, 1 - 0.04 * up + 0.2 * down)
    add(p, "root", rx=0.12 * up - 0.3 * down)
    add(p, "spine", rx=0.1 * up - 0.15 * down)
    add(p, "head", rx=LOOK + 0.2 * up - 0.3 * down + 0.15 * clack(t, 0.78, 2))
    return p


def heavy_hop(t):
    """Hop: a short vertical flap-less jump, the heavy head dipping at the top and the landing a firm thud."""
    air = seq(t, [(0, 0), (0.22, -0.6), (0.42, 1), (0.6, 0.2), (0.72, -0.8), (0.86, 0.1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up, 0)}
    p["root_sc"] = (1 + 0.08 * down, 1 - 0.12 * down + 0.04 * up, 1 + 0.08 * down)
    add(p, "head", rx=LOOK - 0.12 * up + 0.08 * down)
    return p


def tuck(t):
    """Sleep: settles low, the bill laid back along the body and the casque's weight let down, a deep slow breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.02, 0), "root_sc": (1.06 + 0.012 * br, 0.9 + 0.02 * br, 1.04 + 0.012 * br)}
    add(p, "spine", rx=-0.1)
    add(p, "neck", rx=-0.2)
    add(p, "head", rx=-0.45 + 0.01 * br, ry=0.5, rz=0.1)
    return p


def peck(t):
    """Eat: pecks the ground with the bill, lifts it, tosses its head back to swallow, and clacks once."""
    dip = seq(t, [(0, 0), (0.12, 1), (0.22, 0), (0.34, 1), (0.44, 0.1), (1, 0)])
    toss = seq(t, [(0.4, 0), (0.5, 1), (0.7, 1), (0.82, 0), (1, 0)])
    p = {"root_at": (0, -0.02 * dip, 0.01 * dip)}
    add(p, "root", rx=-0.12 * dip)
    add(p, "spine", rx=-0.2 * dip)
    add(p, "head", rx=LOOK - 0.5 * dip + 0.45 * toss + 0.1 * clack(t, 0.86, 1))
    return p


def pet(t):
    """Slow to trust: it stiffens at the touch, eyes front, and only then, very slightly, leans into the hand."""
    lean = seq(t, [(0, 0), (0.25, 0), (0.55, 1), (0.9, 1), (1, 0)])
    p = {"root_sc": (1 + 0.01 * lean, 1 - 0.015 * lean, 1 + 0.01 * lean)}
    add(p, "root", rz=0.03 * lean)
    add(p, "head", rx=LOOK + 0.05 * lean, rz=0.1 * lean, ry=0.06 * lean + 0.02 * s(t, 1))
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.6, True, idle),
        "walk": (1.1, True, walk),
        "run": (0.55, True, run),
        "hop": (1.0, True, heavy_hop),
        "carry": (1.2, True, carry),
        "pet": (2.8, True, pet),
        "attack": (0.9, False, dive),
        "ability": (1.6, False, slam),
        "sleep": (4.6, True, tuck),
        "eat": (2.2, True, peck),
    }
)

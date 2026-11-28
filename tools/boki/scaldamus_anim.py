"""Chuggamus's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a hippo that is half
steam engine. It plods on a two-beat piston chug, thunders along head-down like a runaway train, rams with its
cowcatcher jaw, builds boiler pressure and vents it in a long blast, and yawns steam when it is pleased."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.35  # a lazy hippo does not look up at you as far as the others


def chug(t, amp, beats=2):
    """The drive: `beats` heavy pulses a stride. Each one dips the front and lifts the boiler, the weight rolling
    from side to side on the long stroke, the head nodding like a piston rod."""
    w = s(t, 1)
    pulse = s(t, beats)
    p = {"root_at": (0, 0.012 * amp * pulse, 0)}
    add(p, "root", rz=0.05 * amp * w, rx=0.025 * amp * s(t, beats, 0.25))
    add(p, "spine", rx=-0.05 * amp * pulse, ry=0.05 * amp * w)
    add(p, "hips", rz=-0.04 * amp * w, ry=-0.04 * amp * w)
    add(p, "head", rx=LOOK - 0.06 + 0.07 * amp * s(t, beats, 0.45), ry=-0.05 * amp * w)
    return p


def idle(t):
    """Idles like a banked fire: the boiler belly swells and sags, the head hangs, and now and then it blows a
    sleepy huff of steam (a short heave and a shake of the head)."""
    br = s(t, 1)
    huff = seq(t, [(0, 0), (0.62, 0), (0.68, 1), (0.76, -0.3), (0.84, 0), (1, 0)])
    p = {"root_sc": (1 + 0.018 * br, 1 + 0.03 * br + 0.025 * huff, 1 + 0.012 * br)}
    add(p, "spine", rx=0.07 + 0.03 * br)  # the boiler hump sits a little high, so no frame of it is the bind pose
    add(p, "head", rx=LOOK - 0.15 + 0.04 * s(t, 1, 0.3) + 0.14 * huff, ry=0.07 * s(t, 1, 0.55) + 0.06 * huff * s(t, 6))
    return p


def walk(t):
    return chug(t, 1.0)


def run(t):
    """The runaway: head down like the cowcatcher, the body low and rocking on four fast chuffs a stride, the
    whole frame shuddering with the weight behind it."""
    p = chug(t, 0.35, 4)
    w = s(t, 1)
    p["root_at"] = (0, 0.02 + 0.018 * s(t, 2), 0)
    add(p, "root", rx=-0.08, rz=0.05 * w)
    add(p, "spine", rx=-0.09 * s(t, 2), ry=0.04 * w)
    add(p, "hips", rx=0.09 * s(t, 2, 0.25))
    add(p, "head", rx=-0.28 + 0.06 * s(t, 2, 0.2))
    return p


def carry(t):
    p = chug(t, 0.8)
    add(p, "head", rx=0.12)
    return p


def ram(t):
    """Attack: backs onto its haunches and pulls its head up and in (pressure), drives forward with its whole mass
    into the cowcatcher jaw, and rocks back when it hits."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.44, 0), (1, 0)])
    drive = seq(t, [(0.3, 0), (0.44, 1), (0.6, 0.9), (0.82, 0), (1, 0)])
    recoil = seq(t, [(0.44, 0), (0.54, 1), (0.74, 0), (1, 0)])
    p = {"root_at": (0, 0, 0.06 * wind - 0.28 * drive + 0.05 * recoil)}
    p["root_sc"] = (1, 1 - 0.07 * wind, 1 + 0.07 * drive)
    add(p, "root", rx=0.12 * wind - 0.14 * drive + 0.1 * recoil)
    add(p, "hips", rx=0.18 * wind - 0.1 * drive)
    add(p, "spine", rx=-0.1 * wind - 0.1 * drive)
    add(p, "head", rx=0.3 * wind - 0.55 * drive + 0.3 * recoil, ry=0.05 * recoil * s(t, 7))
    return p


def vent(t):
    """Its E: sinks and shudders as the boiler fills (the shake grows), then rears up, throws its head back and blows
    one long blast, and eases down."""
    fill = seq(t, [(0, 0), (0.1, 0.2), (0.5, 1), (0.56, 0), (1, 0)])
    blast = seq(t, [(0, 0), (0.5, 0), (0.58, 1), (0.8, 1), (1, 0)])
    shake = fill * (1 if t < 0.52 else 0)
    p = {"root_at": (0, -0.04 * fill * (1 - blast) + 0.06 * blast, 0.03 * blast)}
    p["root_sc"] = (
        1 + 0.1 * fill * (1 - blast) - 0.04 * blast,
        1 - 0.12 * fill * (1 - blast) + 0.1 * blast,
        1 + 0.05 * fill * (1 - blast),
    )
    add(p, "root", rx=0.35 * blast, rz=0.04 * shake * s(t, 11))
    add(p, "hips", rx=-0.1 * blast, rz=0.04 * shake * s(t, 13, 0.3))
    add(p, "spine", rx=0.12 * blast - 0.06 * fill * (1 - blast))
    add(p, "head", rx=LOOK - 0.1 * fill * (1 - blast) + 0.7 * blast, ry=0.1 * shake * s(t, 9) + 0.06 * blast * s(t, 7))
    return p


def heavy_hop(t):
    """Hop: a deep crouch, a short heavy leap that barely clears the ground, a landing that jolts the whole boiler."""
    air = seq(t, [(0, 0), (0.22, -0.7), (0.38, 0.3), (0.52, 1), (0.7, 0.3), (0.8, -1), (0.92, -0.3), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.045 * down, 0)}
    p["root_sc"] = (1 + 0.16 * down - 0.03 * up, 1 - 0.2 * down + 0.06 * up, 1 + 0.08 * down)
    add(p, "root", rx=0.12 * up - 0.05 * down)
    add(p, "spine", rx=0.08 * up - 0.1 * down)
    add(p, "head", rx=LOOK + 0.22 * up - 0.14 * down)
    return p


def lie_down(t):
    """Sleep: slumps flat on its belly with its jaw on the ground, a long slow snore swelling its flanks."""
    br = s(t, 1)
    p = {"root_at": (0, -0.12, 0), "root_sc": (1.07 + 0.025 * br, 0.8 + 0.04 * br, 1.03)}
    add(p, "spine", rx=-0.04)
    add(p, "head", rx=-0.35 + 0.015 * br, ry=0.2, rz=0.12)
    return p


def pet(t):
    """Leans its whole weight into the hand and rumbles, head heavy and tipped, eyes half shut."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    add(p, "root", rz=0.05 * lean)
    add(p, "spine", rx=0.03)
    add(p, "head", rx=LOOK - 0.05 + 0.05 * lean, rz=0.2 * lean, ry=0.12 * lean)
    p["root_sc"] = (1 + 0.012 * s(t, 3), 1 + 0.02 * s(t, 3), 1)
    return p


def eat(t):
    """Plants its jaw on the berry and chews it down: three heavy mouthfuls and a satisfied rumble."""
    chew = s(t, 3)
    p = {}
    add(p, "spine", rx=-0.16)
    add(p, "head", rx=-0.4 + 0.1 * chew, ry=0.04 * s(t, 3, 0.25))
    p["root_sc"] = (1, 1 - 0.015 * chew, 1.03)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.2, True, idle),
        "walk": (1.2, True, walk),
        "run": (0.62, True, run),
        "hop": (1.0, True, heavy_hop),
        "carry": (1.2, True, carry),
        "pet": (2.4, True, pet),
        "attack": (1.0, False, ram),
        "ability": (1.6, False, vent),
        "sleep": (4.2, True, lie_down),
        "eat": (2.2, True, eat),
    }
)

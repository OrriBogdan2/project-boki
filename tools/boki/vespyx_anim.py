"""Vespyx's skeleton and the clips that are its own: pincers, and tools in the tail."""
import boki_clips
import boki_react
import vespyx
from boki_clips import LOOK_UP, add, ear_pose, s, seq, tail_wave, TAU
from boki_clips import SHARED, idle
from vespyx import SIDES, STING_C, TAIL_PTS

# the tail reaching forward over the head, joint by joint: base swings forward, the tip unrolls
STAB = (-0.35, -0.45, -0.5, -0.25, 0.25, 0.5, 0.55)
HACK = (-0.42, -0.46, -0.46, -0.22, 0.28, 0.5, 0.6)
GROUND = (-0.6, -0.6, -0.6, -0.42, 0.4, 0.5, 0.6)


def p3(x, y, z):
    return (x, y, z)


def _bones():
    b = {
        "root": (p3(0, 0, 0), p3(0, 0.12, 0), None),
        "hips": (p3(0, 0.24, 0.11), p3(0, 0.25, 0.0), "root"),
        "spine": (p3(0, 0.25, 0.0), p3(0, 0.28, -0.08), "hips"),
        "neck": (p3(0, 0.30, -0.06), p3(0, 0.40, -0.10), "spine"),
        "head": (p3(0, 0.40, -0.10), p3(0, 0.56, -0.13), "neck"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = (p3(sx * 0.118, 0.60, -0.105), p3(sx * 0.178, 0.745, -0.095), "head")
        b["ear2." + sd] = (p3(sx * 0.178, 0.745, -0.095), p3(sx * 0.235, 0.905, -0.085), "ear1." + sd)
        b["fleg1." + sd] = (p3(sx * 0.082, 0.235, -0.075), p3(sx * 0.090, 0.125, -0.080), "spine")
        b["fleg2." + sd] = (p3(sx * 0.090, 0.125, -0.080), p3(sx * 0.094, 0.040, -0.084), "fleg1." + sd)
        b["fpaw." + sd] = (p3(sx * 0.094, 0.040, -0.084), p3(sx * 0.096, 0.020, -0.16), "fleg2." + sd)
        b["hleg1." + sd] = (p3(sx * 0.095, 0.215, 0.195), p3(sx * 0.108, 0.115, 0.175), "hips")
        b["hleg2." + sd] = (p3(sx * 0.108, 0.115, 0.175), p3(sx * 0.108, 0.040, 0.205), "hleg1." + sd)
        b["hpaw." + sd] = (p3(sx * 0.108, 0.040, 0.205), p3(sx * 0.110, 0.020, 0.13), "hleg2." + sd)
        b["arm." + sd] = (p3(sx * 0.070, 0.250, -0.130), p3(sx * 0.118, 0.232, -0.195), "spine")
        b["claw." + sd] = (p3(sx * 0.118, 0.232, -0.195), p3(sx * 0.14, 0.235, -0.33), "arm." + sd)
        b["nip." + sd] = (p3(sx * 0.102, 0.230, -0.285), p3(sx * 0.092, 0.234, -0.335), "claw." + sd)
    parent = "hips"
    for i in range(7):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b["sting"] = (tuple(TAIL_PTS[7]), tuple(STING_C + (STING_C - TAIL_PTS[7])), "tail7")
    b["prop_axe"] = (tuple(STING_C), tuple(STING_C + vespyx.AXIS * 0.1), "sting")
    b["prop_pick"] = (tuple(STING_C), tuple(STING_C + vespyx.AXIS * 0.1), "sting")
    b["prop_berry"] = (tuple(vespyx.BERRY_C), tuple(vespyx.BERRY_C + vespyx.v3(0, 0.1, 0)), "spine")
    b.update(boki_clips.part_bones(vespyx.grown_parts()))
    return b


BONES = _bones()

def attack(t):
    """A pounce with both pincers: rear back, snap forward, settle."""
    p = {}
    wind = seq(t, [(0, 0), (0.28, 1), (0.36, -0.9), (0.52, -1.0), (1, 0)])
    add(p, "spine", rx=wind * 0.3)
    add(p, "hips", rx=wind * 0.1)
    p["root_at"] = (0, -0.05 * max(wind, 0) + 0.02 * max(-wind, 0), 0.14 * max(wind, 0) - 0.18 * max(-wind, 0))
    add(p, "neck", rx=-wind * 0.18)
    add(p, "head", rx=-wind * 0.12)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=max(wind, 0) * 0.9 + max(-wind, 0) * 0.15, ry=-sx * max(wind, 0) * 0.8 + sx * max(-wind, 0) * 0.35)
        add(p, "claw." + sd, rx=max(wind, 0) * 0.3, ry=sx * 0.5 * max(wind, 0))
        gap = seq(t, [(0, 0.2), (0.28, 0.9), (0.38, 0), (0.6, 0), (1, 0.15)])
        add(p, "nip." + sd, ry=sx * gap)
        add(p, "fleg1." + sd, rx=-wind * 0.34)
        add(p, "hleg1." + sd, rx=wind * 0.25)
        add(p, "hleg2." + sd, rx=-max(wind, 0) * 0.4)
    ear_pose(p, back=0.32 + max(wind, 0) * 0.4)
    tail_wave(p, t * 2, 0.04, up=wind * 0.22)
    return p


def tail_strike(pose, t, keys, reach, back, lag):
    """Plates follow the key curve, each a little late: above zero cocked back by `back`, below it out along `reach`."""
    for i in range(7):
        v = seq(t - lag * i, keys)
        k = 0.5 + 0.5 * i / 6
        add(pose, "tail%d" % (i + 1), rx=v * back * k if v > 0 else -v * reach[i])


def ability(t):
    """Stinger strike: the tail cocks back, whips over the head and stabs, a venom flick, then recoils."""
    p = {}
    keys = [(0, 0), (0.32, 1), (0.40, -1), (0.56, -1.1), (0.8, -0.1), (1, 0)]
    cock = seq(t, keys)
    tail_strike(p, t, keys, STAB, back=0.22, lag=0.012)
    add(p, "sting", rx=max(0, -cock) * 0.35)
    crouch = seq(t, [(0, 0), (0.32, 0.7), (0.42, 1), (0.6, 1), (1, 0)])
    p["root_at"] = (0, -0.045 * crouch, 0.05 * max(cock, 0) - 0.05 * max(-cock, 0))
    add(p, "spine", rx=-0.12 * crouch + cock * 0.08)
    add(p, "hips", rx=0.12 * crouch)
    add(p, "neck", rx=-0.18 * max(-cock, 0))
    add(p, "head", rx=-0.28 * max(-cock, 0) + 0.1 * max(cock, 0))
    ear_pose(p, back=0.55 * crouch)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=-0.3 * crouch, rz=-sx * 0.3 * crouch)
        add(p, "fleg1." + sd, rx=0.12 * crouch)
    return p


def curled(t, br):
    """Lying down: legs folded under, chin on the ground beside its forepaws, the tail laid round to its nose."""
    p = {}
    p["root_at"] = (0, -0.128, 0)
    add(p, "hips", rx=-0.04, rz=-0.14)
    add(p, "spine", rx=-0.06, ry=0.36 + br * 0.008)
    add(p, "neck", rx=-0.80, ry=0.5)
    add(p, "head", rx=0.30 + br * 0.03, ry=0.3, rz=0.34)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.25)
        add(p, "fleg2." + sd, rx=-2.0)
        add(p, "fpaw." + sd, rx=0.5)
        add(p, "hleg1." + sd, rx=-0.9)
        add(p, "hleg2." + sd, rx=1.55)
        add(p, "hpaw." + sd, rx=-0.5)
        add(p, "arm." + sd, rx=-0.65, rz=-sx * 0.15)
    ear_pose(p, back=0.72, out=0.3)
    add(p, "tail1", rx=0.42, rz=1.32)
    for i in range(1, 7):
        add(p, "tail%d" % (i + 1), rx=-0.2, ry=br * 0.01)
    add(p, "sting", rx=0.2)
    return p


def sleep(t):
    br = s(t, 1)
    p = curled(t, br)
    add(p, "hips", rz=br * 0.012)
    p["root_sc"] = (1 + br * 0.018, 1 + br * 0.03, 1)
    return p


def eat(t):
    """Holds a berry in its left pincer and nibbles: to the mouth, three chomps, then a pleased chew."""
    p = idle(t)
    lift = seq(t, [(0, 0.8), (0.12, 1), (0.88, 1), (1, 0.8)])
    chomp = (0.5 + 0.5 * s(t, 3)) * lift
    add(p, "head", rx=-LOOK_UP - 0.20 - chomp * 0.14)
    add(p, "neck", rx=-0.06 - chomp * 0.05)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=0.22 * lift, ry=sx * 0.34 * lift)
        add(p, "claw." + sd, rx=0.12 * lift, ry=sx * 0.2 * lift)
    ear_pose(p, back=0.14 - chomp * 0.1)
    p["prop_berry"] = "on"
    return p


def chop(t):
    """Hefts a hatchet on its tail and hacks it down at a trunk ahead, leaning its whole weight in."""
    p = {}
    keys = [(0, 0.2), (0.40, 1), (0.52, -1), (0.70, -1), (1, 0.2)]
    v = seq(t, keys)
    tail_strike(p, t, keys, HACK, back=0.20, lag=0.012)
    add(p, "tail1", ry=-0.34)
    add(p, "sting", rx=max(0, -v) * 0.5)
    add(p, "root", rz=0.07 * v)
    add(p, "spine", rx=0.1 * max(v, 0) - 0.12 * max(-v, 0), ry=-0.14 * v)
    add(p, "hips", ry=0.12 * v)
    add(p, "neck", ry=0.1 * v)
    add(p, "head", rx=LOOK_UP * 0.5, ry=0.1 * v)
    p["root_at"] = (0, -0.022 * max(-v, 0), 0.05 * v)
    ear_pose(p, back=0.28)
    p["prop_axe"] = "on"
    return p


def mine(t):
    """Swings a pick from high over its back down into the rock at its feet, and rebounds off each strike."""
    p = {}
    keys = [(0, 0), (0.38, 1), (0.50, -1), (0.58, -0.75), (1, 0)]
    v = seq(t, keys)
    tail_strike(p, t, keys, GROUND, back=0.26, lag=0.012)
    add(p, "sting", rx=max(0, -v) * 0.5)
    add(p, "spine", rx=-0.14 * max(0, -v) + 0.14 * max(0, v))
    add(p, "neck", rx=-0.16 * max(0, -v))
    add(p, "head", rx=-0.1 * max(0, -v) + 0.1 * max(0, v))
    p["root_at"] = (0, -0.03 * max(0, -v), 0.03 * max(0, v))
    ear_pose(p, back=0.2 + 0.3 * max(0, -v))
    p["prop_pick"] = "on"
    return p


CLIPS = dict(SHARED)
CLIPS.update({
    "attack": (0.8, False, attack),
    "ability": (1.1, False, ability),
    "sleep": (3.4, True, sleep),
    "eat": (2.0, True, eat),
    "chop": (1.1, True, chop),
    "mine": (1.0, True, mine),
})
CLIPS.update(boki_react.react())
HIDE_AT = {"prop_berry": (0, -0.09, 0.40)}

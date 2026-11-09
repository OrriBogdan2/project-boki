"""Chuggamus' skeleton and the clips that are its own: the heavy plod, the charge with the grille down, Gravity Slam's
stamp, and sleep set down on its belly."""
import boki_clips
import chuggamus as ch
from boki_clips import SHARED, add, chop_mouth, ear_pose, eat_ground, mine_mouth, s, seq, tail_wave
from vespyx_sides import SIDES

boki_clips.TAIL_N = 2


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.28, 0.2), (0, 0.28, 0.02), "root"),
        "spine": ((0, 0.28, 0.02), (0, 0.31, -0.13), "hips"),
        "neck": ((0, 0.32, -0.14), (0, 0.37, -0.22), "spine"),
        "head": ((0, 0.37, -0.22), (0, 0.5, -0.3), "neck"),
        "prop_axe": (tuple(ch.GRIP), tuple(ch.GRIP + ch.AXIS * 0.1), "head"),
        "prop_pick": (tuple(ch.GRIP), tuple(ch.GRIP + ch.AXIS * 0.1), "head"),
        "prop_berry": (tuple(ch.BERRY_C), tuple(ch.BERRY_C + ch.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.11, 0.5, -0.23), (sx * 0.13, 0.55, -0.235), "head")
        for leg, x, z, par in (("f", ch.FRONT_X, ch.FRONT_Z, "spine"), ("h", ch.HIND_X, ch.HIND_Z, "hips")):
            b["%sleg1.%s" % (leg, sd)] = ((sx * x, ch.LEG_TOP, z), (sx * x, ch.KNEE, z), par)
            b["%sleg2.%s" % (leg, sd)] = ((sx * x, ch.KNEE, z), (sx * x, ch.ANKLE, z), "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = ((sx * x, ch.ANKLE, z), (sx * x, 0.02, z - 0.07), "%sleg2.%s" % (leg, sd))
    parent = "hips"
    for i in range(len(ch.TAIL_PTS) - 1):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(ch.TAIL_PTS[i]), tuple(ch.TAIL_PTS[i + 1]), parent)
        parent = n
    b.update(boki_clips.part_bones(ch.grown_parts()))
    return b


BONES = _bones()


def plod(t):
    """A heavy short-legged walk: the barrel rolls over each step and the head bobs a beat late."""
    p = boki_clips.trot(t, 0.38, 0.008, 0.0, 0.0)
    add(p, "root", rz=s(t, 1) * 0.045)
    add(p, "head", rz=-s(t, 1, 0.1) * 0.04)
    return p


def charge(t):
    """Attack: rocks back, then drives forward head low, the grille leading like a cowcatcher, and settles."""
    p = {}
    v = seq(t, [(0, 0), (0.25, -1), (0.45, 1), (0.6, 1), (1, 0)])
    back, drive = max(-v, 0), max(v, 0)
    p["root_at"] = (0, -0.015 * drive, 0.05 * back - 0.14 * drive)
    add(p, "root", rx=0.08 * back - 0.1 * drive)
    add(p, "neck", rx=0.15 * back - 0.25 * drive)
    add(p, "head", rx=0.2 * back - 0.3 * drive)
    ear_pose(p, back=0.5 * drive + 0.1)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=-0.25 * back + 0.45 * drive)
        add(p, "hleg1." + sd, rx=0.2 * back - 0.45 * drive)
    tail_wave(p, t * 2, 0.08, up=0.4 * drive)
    return p


def slam(t):
    """Gravity Slam: rears up on its hind legs, hangs, and stamps both front feet down; the barrel squashes on the
    landing and shudders."""
    p = {}
    rear = seq(t, [(0, 0), (0.3, 1), (0.42, 1.05), (0.52, 0), (1, 0)])
    land = seq(t, [(0.5, 0), (0.55, 1), (0.7, 0.4), (0.9, 0)])
    p["root_at"] = (0, 0.06 * rear - 0.04 * land, 0.04 * rear)
    p["root_sc"] = (1 + 0.1 * land, 1 - 0.12 * land, 1 + 0.06 * land)
    add(p, "root", rx=0.55 * rear)
    add(p, "neck", rx=-0.2 * rear + 0.1 * land)
    add(p, "head", rx=-0.15 * rear - 0.2 * land, rz=0.06 * land * s(t, 10))
    ear_pose(p, back=0.3 * rear, out=0.25 * land)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.5 * rear - 0.2 * land, rz=-sx * 0.2 * land)
        add(p, "fleg2." + sd, rx=-0.6 * rear)
        add(p, "hleg1." + sd, rx=-0.55 * rear, rz=-sx * 0.1 * land)
    add(p, "root", rz=0.04 * land * s(t, 12))
    tail_wave(p, t, 0.06, up=-0.3 * rear)
    return p


def loaf(t):
    """Sleep: belly on the ground, legs folded, chin down, a slow deep breath through the barrel."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.07, 0)
    p["root_sc"] = (1 + br * 0.02, 1 + br * 0.03, 1)
    add(p, "neck", rx=-0.2, ry=0.1)
    add(p, "head", rx=-0.05 + br * 0.03, ry=0.1, rz=0.1)
    ear_pose(p, back=0.4, out=0.15)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.1, rz=-sx * 0.2)
        add(p, "fleg2." + sd, rx=-0.6)
        add(p, "hleg1." + sd, rx=-1.0, rz=-sx * 0.25)
        add(p, "hleg2." + sd, rx=0.5)
    for i in range(boki_clips.TAIL_N):
        add(p, "tail%d" % (i + 1), ry=-0.2 + br * 0.01)
    return p


CLIPS = dict(SHARED)
CLIPS.update({
    "walk": (0.8, True, plod),
    "attack": (0.8, False, charge),
    "ability": (1.1, False, slam),
    "sleep": (3.6, True, loaf),
    "eat": (2.0, True, eat_ground),
    "chop": (1.1, True, chop_mouth),
    "mine": (1.0, True, mine_mouth),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.40)}

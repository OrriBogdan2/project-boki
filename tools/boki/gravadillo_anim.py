"""Gravadillo's skeleton and the clips that are its own: the horn, and the curl into a heavy ball."""
import math

import boki_clips
import gravadillo
from boki_clips import SHARED, add, chop_mouth, ear_pose, eat_ground, mine_mouth, s, seq, tail_wave
from gravadillo import HORN_PTS, SIDES, TAIL_PTS

boki_clips.TAIL_N = 4
BALL_C = (0.0, 0.25, 0.02)       # the curled ball's centre (m, rest pose): it spins about this
HORN_LAG = 1.1                   # how far the horn trails the head's swing (rad per rad moved over LAG_S)
LAG_S = 0.05                     # clip time (0..1) the horn looks back over


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.22, 0.14), (0, 0.22, 0.0), "root"),
        "spine": ((0, 0.22, 0.0), (0, 0.225, -0.1), "hips"),
        "neck": ((0, 0.225, -0.12), (0, 0.26, -0.22), "spine"),
        "head": ((0, 0.26, -0.22), (0, 0.38, -0.3), "neck"),
        "horn": (tuple(HORN_PTS[0]), tuple(HORN_PTS[2]), "head"),
        "prop_axe": (tuple(gravadillo.GRIP), tuple(gravadillo.GRIP + gravadillo.AXIS * 0.1), "head"),
        "prop_pick": (tuple(gravadillo.GRIP), tuple(gravadillo.GRIP + gravadillo.AXIS * 0.1), "head"),
        "prop_berry": (tuple(gravadillo.BERRY_C), tuple(gravadillo.BERRY_C + gravadillo.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.115, 0.39, -0.28), (sx * 0.137, 0.47, -0.30), "head")
        for leg, z, par in (("f", -0.12, "spine"), ("h", 0.2, "hips")):
            b["%sleg1.%s" % (leg, sd)] = ((sx * 0.13, 0.17, z), (sx * 0.148, 0.09, z - 0.008), par)
            b["%sleg2.%s" % (leg, sd)] = ((sx * 0.148, 0.09, z - 0.008), (sx * 0.152, 0.036, z - 0.014),
                                          "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = ((sx * 0.152, 0.036, z - 0.014), (sx * 0.154, 0.02, z - 0.09),
                                         "%sleg2.%s" % (leg, sd))
    parent = "hips"
    for i in range(4):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b.update(boki_clips.part_bones(gravadillo.grown_parts()))
    return b


BONES = _bones()


def _nod(pose):
    return sum(pose.get(bn, (0, 0, 0))[0] for bn in ("root", "spine", "neck", "head"))


def horn_follow(fn):
    """The clip with the heavy horn swinging a beat behind every nod of the head."""
    def clip(t):
        p = fn(t)
        lag = (_nod(p) - _nod(fn(t - LAG_S))) * HORN_LAG
        add(p, "horn", rx=-max(-0.35, min(0.35, lag)))
        return p
    return clip


def spin_about(pose, angle, lift=0.0):
    """Turns the whole Boki nose-down by `angle` about the ball's centre, raised by `lift` (m)."""
    _, cy, cz = BALL_C
    ry = cy * math.cos(angle) - cz * math.sin(angle)
    rz = cy * math.sin(angle) + cz * math.cos(angle)
    add(pose, "root", rx=angle)
    at = pose.get("root_at", (0, 0, 0))
    pose["root_at"] = (at[0], at[1] + cy - ry + lift, at[2] + cz - rz)


def curl(pose, k):
    """Rolled up by k (0..1): head tucked under the front of the shell, legs folded in, tail wrapped under."""
    add(pose, "hips", rx=0.4 * k)
    add(pose, "spine", rx=-0.7 * k)
    add(pose, "neck", rx=-1.2 * k)
    add(pose, "head", rx=-1.1 * k)
    add(pose, "horn", rx=-0.4 * k)
    ear_pose(pose, back=0.5 * k)
    for sd, sx in SIDES:
        add(pose, "fleg1." + sd, rx=-1.3 * k, rz=sx * 0.2 * k)
        add(pose, "fleg2." + sd, rx=1.6 * k)
        add(pose, "hleg1." + sd, rx=1.4 * k, rz=sx * 0.2 * k)
        add(pose, "hleg2." + sd, rx=-1.6 * k)
    for i in range(4):
        add(pose, "tail%d" % (i + 1), rx=-0.7 * k)


def ability(t):
    """Gravity slam: tucks into a ball, flips over through the air, unrolls and lands like a meteor, then shakes off."""
    p = {}
    roll = seq(t, [(0, 0), (0.08, 0), (0.16, 1), (0.42, 1), (0.48, 0)])
    crouch = seq(t, [(0, 0), (0.08, 1), (0.14, 0), (0.46, 0), (0.5, 1.1), (0.58, 0.7), (0.72, 0.15), (0.86, 0)])
    air = seq(t, [(0.1, 0), (0.28, 1), (0.46, 0)])
    curl(p, roll)
    spin_about(p, -math.tau * seq(t, [(0.12, 0), (0.46, 1)]), lift=0.16 * air)
    at = p["root_at"]
    p["root_at"] = (at[0], at[1] - 0.06 * crouch, at[2])
    p["root_sc"] = (1 + 0.16 * crouch, 1 - 0.2 * crouch, 1 + 0.1 * crouch)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rz=-sx * 0.35 * crouch)
        add(p, "hleg1." + sd, rz=-sx * 0.3 * crouch)
    shake = seq(t, [(0.62, 0), (0.7, 1), (0.9, 0)])
    add(p, "root", rz=0.07 * shake * s(t, 9))
    add(p, "head", rx=0.15 * crouch, rz=0.12 * shake * s(t, 9, 0.2))
    ear_pose(p, back=0.3 * crouch, out=0.2 * shake * s(t, 9, 0.1))
    tail_wave(p, t, 0.05, up=0.3 * crouch)
    return p


def horn_toss(t):
    """Head low, a short heavy charge, then the horn flicks up through whatever is in front."""
    p = {}
    v = seq(t, [(0, 0), (0.3, 1), (0.42, -0.6), (0.5, -1), (0.62, -1), (1, 0)])
    low = max(v, 0)
    toss = max(-v, 0)
    p["root_at"] = (0, -0.03 * low + 0.03 * toss, 0.06 * low - 0.16 * toss)
    add(p, "root", rx=-0.12 * low + 0.12 * toss)
    add(p, "neck", rx=-0.3 * low + 0.3 * toss)
    add(p, "head", rx=-0.35 * low + 0.6 * toss)
    ear_pose(p, back=0.45 * low + 0.2)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=-0.4 * low + 0.3 * toss)
        add(p, "hleg1." + sd, rx=-0.35 * low - 0.3 * toss)
    tail_wave(p, t * 2, 0.05, up=0.3 * low)
    return p


def waddle(t):
    """A short-legged trot: the heavy shell rocks side to side over each step."""
    p = boki_clips.walk(t)
    add(p, "root", rz=s(t, 1) * 0.05)
    add(p, "head", rz=-s(t, 1) * 0.05)
    return p


def loaf(t):
    """Sleep: the shell set down on its belly, legs tucked, chin on its paws, the horn tip nodding with each breath."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.075, 0)
    p["root_sc"] = (1 + br * 0.015, 1 + br * 0.03, 1)
    add(p, "neck", rx=-0.22, ry=0.12)
    add(p, "head", rx=0.02 + br * 0.03, ry=0.1, rz=0.12)
    add(p, "horn", rx=-0.1 + br * 0.04)
    ear_pose(p, back=0.4, out=0.15)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.2, rz=-sx * 0.25)
        add(p, "fleg2." + sd, rx=-0.6)
        add(p, "hleg1." + sd, rx=-1.1, rz=-sx * 0.3)
        add(p, "hleg2." + sd, rx=0.5)
    for i in range(4):
        add(p, "tail%d" % (i + 1), ry=-0.22 + br * 0.01, rx=0.05)
    return p


CLIPS = {name: (secs, loop, horn_follow(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "walk": (0.72, True, horn_follow(waddle)),
    "attack": (0.8, False, horn_follow(horn_toss)),
    "ability": (1.2, False, ability),
    "sleep": (3.4, True, loaf),
    "eat": (2.0, True, horn_follow(eat_ground)),
    "chop": (1.1, True, horn_follow(chop_mouth)),
    "mine": (1.0, True, horn_follow(mine_mouth)),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.40)}

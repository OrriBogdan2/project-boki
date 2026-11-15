"""Glintmole's skeleton and the clips that are its own: it digs with its spade paws rather than with tools."""
import boki_clips
import glintmole
from boki_clips import SHARED, add, chop_mouth, ear_pose, eat_ground, s, seq, tail_wave
from glintmole import SIDES, TAIL_PTS

boki_clips.TAIL_N = 2
boki_clips.DROP = -0.06


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.25, 0.14), (0, 0.25, 0.0), "root"),
        "spine": ((0, 0.25, 0.0), (0, 0.26, -0.08), "hips"),
        "neck": ((0, 0.26, -0.07), (0, 0.26, -0.15), "spine"),
        "head": ((0, 0.26, -0.15), (0, 0.37, -0.2), "neck"),
        "prop_axe": (tuple(glintmole.GRIP), tuple(glintmole.GRIP + glintmole.AXIS * 0.1), "head"),
        "prop_pick": (tuple(glintmole.GRIP), tuple(glintmole.GRIP + glintmole.AXIS * 0.1), "head"),
        "prop_berry": (tuple(glintmole.BERRY_C), tuple(glintmole.BERRY_C + glintmole.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.14, 0.37, -0.14), (sx * 0.16, 0.43, -0.15), "head")
        b["fleg1." + sd] = ((sx * 0.15, 0.17, -0.12), (sx * 0.17, 0.095, -0.135), "spine")
        b["fleg2." + sd] = ((sx * 0.17, 0.095, -0.135), (sx * 0.18, 0.04, -0.15), "fleg1." + sd)
        b["fpaw." + sd] = ((sx * 0.18, 0.04, -0.15), (sx * 0.2, 0.025, -0.25), "fleg2." + sd)
        b["hleg1." + sd] = ((sx * 0.14, 0.16, 0.22), (sx * 0.145, 0.085, 0.216), "hips")
        b["hleg2." + sd] = ((sx * 0.145, 0.085, 0.216), (sx * 0.147, 0.03, 0.212), "hleg1." + sd)
        b["hpaw." + sd] = ((sx * 0.147, 0.03, 0.212), (sx * 0.149, 0.02, 0.14), "hleg2." + sd)
    b["tail1"] = (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips")
    b["tail2"] = (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1")
    b.update(boki_clips.part_bones(glintmole.grown_parts()))
    return b


BONES = _bones()


def dig(p, t, rate, reach, sd_first="L"):
    """Paws scooping in turn: reach forward and down, rake back under the belly."""
    for sd, sx in SIDES:
        ph = 0.0 if sd == sd_first else 0.5
        a = s(t, rate, ph)
        add(p, "fleg1." + sd, rx=0.25 + a * reach, rz=-sx * 0.15)
        add(p, "fleg2." + sd, rx=-max(0.0, a) * reach * 0.8)
        add(p, "fpaw." + sd, rx=-0.35 - a * reach * 0.6, ry=sx * 0.2)


def swipe(t):
    """Attack: rears a little and rakes down with one spade paw, then the other."""
    p = {}
    rear = seq(t, [(0, 0), (0.25, 1), (0.4, 0.2), (0.55, 1), (0.7, 0.1), (1, 0)])
    p["root_at"] = (0, 0.02 * rear, 0.02 * rear)
    add(p, "root", rx=0.22 * rear)
    add(p, "head", rx=0.12 * rear)
    for sd, sx in SIDES:
        k = seq(t, [(0, 0), (0.22, 1), (0.36, -1), (0.6, 0), (1, 0)] if sd == "R" else
                [(0, 0), (0.42, 1), (0.56, -1), (0.8, 0), (1, 0)])
        add(p, "fleg1." + sd, rx=0.5 * rear + 0.7 * k, rz=-sx * 0.25 * max(k, 0))
        add(p, "fpaw." + sd, rx=-0.6 * k)
        add(p, "hleg1." + sd, rx=-0.3 * rear)
    ear_pose(p, back=0.3)
    tail_wave(p, t * 2, 0.06, up=0.3 * rear)
    return p


def ability(t):
    """Geode mines: digs in hard, nose down, then pops up shaking the quartz on its back."""
    p = {}
    dig_in = seq(t, [(0, 0), (0.12, 1), (0.55, 1), (0.66, 0), (1, 0)])
    pop = seq(t, [(0, 0), (0.55, 0), (0.66, 1), (0.8, -0.3), (1, 0)])
    up = max(pop, 0)
    p["root_at"] = (0, -0.03 * dig_in + 0.07 * up, 0)
    p["root_sc"] = (1 + 0.06 * dig_in - 0.05 * up, 1 - 0.1 * dig_in + 0.12 * up, 1)
    add(p, "root", rx=-0.18 * dig_in + 0.15 * up, ry=0.12 * up * s(t, 8))
    add(p, "neck", rx=-0.25 * dig_in)
    add(p, "head", rx=-0.3 * dig_in + 0.35 * up)
    dig(p, t, 7, 0.55 * dig_in)
    ear_pose(p, back=0.3 * dig_in)
    tail_wave(p, t * 4, 0.1 * dig_in, up=0.2)
    return p


def mine_claws(t):
    """Mining: it needs no pick; head up, it tears into the rock with both paws."""
    p = {}
    bob = s(t, 2)
    add(p, "root", rx=0.28)
    add(p, "spine", rx=0.1)
    add(p, "head", rx=0.1 + bob * 0.05)
    p["root_at"] = (0, 0.03, 0)
    dig(p, t, 2, 0.5)
    for sd in "LR":
        add(p, "hleg1." + sd, rx=-0.35)
    tail_wave(p, t * 2, 0.04)
    return p


def ball(t):
    """Sleep: curled round its nose, paws tucked, the quartz up like a little hill."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.07, 0)
    p["root_sc"] = (1 + br * 0.02, 1 + br * 0.03, 1)
    add(p, "spine", rx=-0.12)
    add(p, "neck", rx=-0.42)
    add(p, "head", rx=-0.3 + br * 0.03)
    ear_pose(p, back=0.2)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.2, rz=sx * 0.2)
        add(p, "fleg2." + sd, rx=-1.6)
        add(p, "hleg1." + sd, rx=-1.0)
        add(p, "hleg2." + sd, rx=1.5)
    add(p, "tail1", rx=0.4, ry=0.3)
    return p


def sniff(fn):
    """Its star wiggles all the time: the head jitters in tiny quick sniffs over any clip."""
    def clip(t):
        p = fn(t)
        add(p, "head", rx=0.025 * s(t, 11), ry=0.02 * s(t, 7, 0.3))
        return p
    return clip


CLIPS = {name: (secs, loop, sniff(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "attack": (0.8, False, swipe),
    "ability": (1.3, False, ability),
    "sleep": (3.4, True, ball),
    "eat": (2.0, True, sniff(eat_ground)),
    "chop": (1.1, True, chop_mouth),
    "mine": (0.9, True, mine_claws),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

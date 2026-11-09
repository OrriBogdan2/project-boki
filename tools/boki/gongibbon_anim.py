"""Gongibbon's skeleton and the clips that are its own: a two-fist knuckle slam, Echo Chain (the tail mallet strikes
the chest gong), a hunched sitting doze. It walks on its knuckles with the shared four-leg clips."""
import boki_clips
import gongibbon
from boki_clips import SHARED, add, chop_mouth, ear_pose, eat_ground, mine_mouth, part_bones, s, seq, tail_wave
from gongibbon import EAR, EAR_TIP, LIMBS, SIDES, TAIL_N, TAIL_PTS, v3

boki_clips.TAIL_N = TAIL_N
boki_clips.DROP = -0.06


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.22, 0.1), (0, 0.33, 0.05), "root"),
        "spine": ((0, 0.33, 0.05), (0, 0.45, 0.0), "hips"),
        "neck": ((0, 0.45, 0.0), (0, 0.5, -0.04), "spine"),
        "head": ((0, 0.5, -0.04), (0, 0.64, -0.08), "neck"),
        "prop_axe": (tuple(gongibbon.GRIP), tuple(gongibbon.GRIP + gongibbon.AXIS * 0.1), "head"),
        "prop_pick": (tuple(gongibbon.GRIP), tuple(gongibbon.GRIP + gongibbon.AXIS * 0.1), "head"),
        "prop_berry": (tuple(gongibbon.BERRY_C), tuple(gongibbon.BERRY_C + v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        m = v3(sx, 1, 1)
        b["ear1." + sd] = (tuple(EAR * m), tuple(EAR_TIP * m), "head")
        b["ear2." + sd] = (tuple(EAR_TIP * m), tuple((EAR_TIP + v3(0.01, 0.01, 0)) * m), "ear1." + sd)
        for leg, paw, pts, _ in LIMBS:
            top, mid, low, tip = (tuple(q * m) for q in pts)
            b["%s1.%s" % (leg, sd)] = (top, mid, "spine" if leg == "fleg" else "hips")
            b["%s2.%s" % (leg, sd)] = (mid, low, "%s1.%s" % (leg, sd))
            b["%s.%s" % (paw, sd)] = (low, tip, "%s2.%s" % (leg, sd))
    parent = "hips"
    for i in range(TAIL_N):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b.update(part_bones(gongibbon.grown_parts()))
    return b


BONES = _bones()


def knuckle_slam(t):
    """Attack: rears up with both fists high, then brings them down together on the ground with a squash."""
    p = {}
    up = seq(t, [(0, 0), (0.35, 1), (0.48, -0.3), (0.62, -0.3), (1, 0)])
    hit = seq(t, [(0, 0), (0.45, 0), (0.5, 1), (0.66, 0), (1, 0)])
    p["root_at"] = (0, 0.05 * max(up, 0) - 0.03 * hit, -0.08 * hit)
    p["root_sc"] = (1 + 0.08 * hit, 1 - 0.1 * hit, 1)
    add(p, "root", rx=0.35 * max(up, 0) - 0.12 * hit)
    add(p, "spine", rx=0.2 * max(up, 0) - 0.15 * hit)
    add(p, "head", rx=0.3 * max(up, 0) - 0.1 * hit)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=2.2 * max(up, 0) - 0.3 * hit, rz=-sx * 0.25 * max(up, 0))
        add(p, "fleg2." + sd, rx=-0.6 * max(up, 0))
        add(p, "hleg1." + sd, rx=-0.35 * max(up, 0))
    ear_pose(p, back=0.3 * max(up, 0))
    tail_wave(p, t * 2, 0.05, up=0.3 * hit)
    return p


def echo_chain(t):
    """Echo Chain: it sits up and puffs its chest, the tail swings the mallet over its shoulder onto the gong, twice,
    and the whole body rings."""
    p = {}
    sit = seq(t, [(0, 0), (0.15, 1), (0.85, 1), (1, 0)])
    swing = seq(t, [(0, 0), (0.25, 1), (0.36, 1.25), (0.42, 0.9), (0.58, 1.25), (0.64, 0.9), (0.85, 1), (1, 0)])
    ring = seq(t, [(0, 0), (0.35, 0), (0.37, 1), (0.5, 0), (0.57, 0), (0.59, 1), (0.75, 0), (1, 0)])
    p["root_at"] = (0, 0.03 * sit, 0.02 * sit)
    p["root_sc"] = (1 + 0.04 * ring * s(t, 14), 1 + 0.03 * sit, 1)
    add(p, "root", rx=0.45 * sit)
    add(p, "spine", rx=0.1 * sit - 0.1 * ring)
    add(p, "head", rx=0.15 * sit + 0.12 * ring)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.3 * sit, rz=sx * 0.35 * sit)     # arms out: the gong shows
        add(p, "fleg2." + sd, rx=-0.3 * sit)
        add(p, "hleg1." + sd, rx=-0.45 * sit)
        add(p, "hleg2." + sd, rx=0.2 * sit)
    add(p, "tail1", ry=1.3 * swing)
    for i in range(2, TAIL_N + 1):
        add(p, "tail%d" % i, rx=(-0.7 if i > 3 else 0.3) * swing, ry=0.15 * swing)     # the tip arcs over onto the gong
    ear_pose(p, back=0.1, out=0.3 * ring)
    return p


def doze(t):
    """Sleep: sat back on its haunches, hunched over its folded arms, chin on its gong, the mallet laid round."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, boki_clips.DROP, 0.03)
    p["root_sc"] = (1 + br * 0.015, 1 + br * 0.025, 1)
    add(p, "root", rx=0.3)
    add(p, "spine", rx=-0.35)
    add(p, "neck", rx=-0.3)
    add(p, "head", rx=-0.35 + br * 0.02, rz=0.12)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.7, rz=sx * 0.2)
        add(p, "fleg2." + sd, rx=-1.3)
        add(p, "hleg1." + sd, rx=-0.9, rz=-sx * 0.15)
        add(p, "hleg2." + sd, rx=1.2)
    ear_pose(p, back=0.2)
    for i in range(TAIL_N):
        add(p, "tail%d" % (i + 1), ry=0.25, rx=-0.15 + br * 0.02)
    return p


CLIPS = dict(SHARED)
CLIPS.update({
    "attack": (0.8, False, knuckle_slam),
    "ability": (1.8, False, echo_chain),
    "sleep": (3.2, True, doze),
    "eat": (2.0, True, eat_ground),
    "chop": (1.1, True, chop_mouth),
    "mine": (1.0, True, mine_mouth),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

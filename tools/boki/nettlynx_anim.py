"""Nettlynx's skeleton and the clips that are its own: a kitten's swat-and-bite, the Nettle Pounce, a curled nap."""
import boki_clips
import nettlynx
from boki_clips import SHARED, add, bite, chop_mouth, ear_pose, eat_ground, mine_mouth, part_bones, s, seq, tail_wave
from nettlynx import EAR_BASE, EAR_LEAF_TIP, EAR_TIP, LEGS, SIDES, TAIL_PTS, v3

boki_clips.TAIL_N = 3
boki_clips.DROP = -0.07


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.235, 0.2), (0, 0.235, 0.04), "root"),
        "spine": ((0, 0.235, 0.04), (0, 0.245, -0.06), "hips"),
        "neck": ((0, 0.25, -0.06), (0, 0.29, -0.13), "spine"),
        "head": ((0, 0.29, -0.13), (0, 0.42, -0.2), "neck"),
        "prop_axe": (tuple(nettlynx.GRIP), tuple(nettlynx.GRIP + nettlynx.AXIS * 0.1), "head"),
        "prop_pick": (tuple(nettlynx.GRIP), tuple(nettlynx.GRIP + nettlynx.AXIS * 0.1), "head"),
        "prop_berry": (tuple(nettlynx.BERRY_C), tuple(nettlynx.BERRY_C + v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        m = v3(sx, 1, 1)
        b["ear1." + sd] = (tuple(EAR_BASE * m), tuple(EAR_TIP * m), "head")
        b["ear2." + sd] = (tuple(EAR_TIP * m), tuple(EAR_LEAF_TIP * m), "ear1." + sd)
        for leg, paw, z in LEGS:
            par = "spine" if leg == "fleg" else "hips"
            hind = leg == "hleg"
            top = (sx * 0.1, 0.19, z)
            knee = (sx * 0.11, 0.11, z + (0.02 if hind else -0.005))
            ankle = (sx * 0.115, 0.05, z - 0.005)
            b["%s1.%s" % (leg, sd)] = (top, knee, par)
            b["%s2.%s" % (leg, sd)] = (knee, ankle, "%s1.%s" % (leg, sd))
            b["%s.%s" % (paw, sd)] = (ankle, (ankle[0], 0.04, ankle[2] - 0.08), "%s2.%s" % (leg, sd))
    parent = "hips"
    for i in range(3):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b.update(part_bones(nettlynx.grown_parts()))
    return b


BONES = _bones()


def prickly(fn):
    """Its nettle tufts never quite settle: a flick of one ear leaf now and then over any clip."""
    def clip(t):
        p = fn(t)
        flick = seq(t, [(0, 0), (0.55, 0), (0.6, 1), (0.66, 0), (1, 0)])
        add(p, "ear2.L", rz=0.35 * flick)
        add(p, "ear2.R", rx=0.06 * s(t, 1))
        return p
    return clip


def swat_bite(t):
    """Attack: bites first: a quick swat of the right paw, then the lunge and the snap."""
    p = bite(t)
    swat = seq(t, [(0, 0), (0.18, 1), (0.3, -0.4), (0.45, 0), (1, 0)])
    add(p, "fleg1.R", rx=1.1 * max(swat, 0) - 0.3 * max(-swat, 0), rz=0.25 * max(swat, 0))
    add(p, "fpaw.R", rx=-0.7 * swat)
    add(p, "head", ry=0.12 * max(swat, 0))
    return p


def pounce(t):
    """Nettle Pounce: crouched low, a butt wiggle that builds, then a big leap with paws out and a squash landing."""
    p = {}
    crouch = seq(t, [(0, 0), (0.12, 1), (0.44, 1), (0.5, 0), (0.68, 0), (0.74, 1), (0.82, 0.3), (1, 0)])
    wiggle = seq(t, [(0, 0), (0.15, 0), (0.4, 1), (0.44, 0)]) * s(t, 9)
    air = seq(t, [(0, 0), (0.46, 0), (0.58, 1), (0.7, 0), (1, 0)])
    reach = seq(t, [(0, 0), (0.45, 0), (0.5, 1), (0.66, 0.8), (0.72, 0), (1, 0)])
    land = seq(t, [(0, 0), (0.68, 0), (0.73, 1), (0.84, 0), (1, 0)])
    travel = seq(t, [(0, 0), (0.46, 0.06), (0.72, -0.26), (0.84, -0.26), (1, 0)])
    p["root_at"] = (0, -0.05 * crouch + 0.26 * air, travel)
    p["root_sc"] = (1 + 0.06 * crouch + 0.16 * land - 0.06 * reach, 1 - 0.1 * crouch - 0.24 * land + 0.08 * reach,
                    1 + 0.12 * reach + 0.06 * land)
    pitch = seq(t, [(0, 0), (0.46, 0), (0.52, 0.3), (0.62, 0), (0.7, -0.2), (0.8, 0), (1, 0)])
    add(p, "root", rx=pitch - 0.1 * crouch)
    add(p, "hips", rx=-0.15 * crouch, ry=0.22 * wiggle, rz=0.12 * wiggle)
    add(p, "spine", rx=0.1 * crouch)
    add(p, "neck", rx=-0.25 * crouch + 0.1 * reach)
    add(p, "head", rx=0.25 * crouch + 0.1 * reach - 0.1 * land)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-0.45 * crouch + 1.2 * reach + 0.3 * land, rz=sx * 0.35 * (reach + land))
        add(p, "fleg2." + sd, rx=0.6 * crouch - 0.3 * reach - 0.5 * land)
        add(p, "fpaw." + sd, rx=0.3 * crouch - 0.5 * reach + 0.3 * land, ry=sx * 0.3 * reach)
        add(p, "hleg1." + sd, rx=0.5 * crouch - 1.0 * reach - 0.3 * land)
        add(p, "hleg2." + sd, rx=-0.7 * crouch + 0.6 * reach + 0.5 * land)
        add(p, "hpaw." + sd, rx=0.3 * crouch + 0.5 * reach)
    ear_pose(p, back=0.15 * crouch + 0.5 * reach, out=0.15 * land)
    tail_wave(p, t * 6, 0.08 * crouch + 0.04, up=0.3 * crouch + 0.4 * reach - 0.3 * land, side=1.2 * wiggle,
              lag=0.12)
    return p


def curl(t):
    """Sleep: a kitten curl, nose under its paws, the nettle sprig drawn over its face."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.075, 0)
    p["root_sc"] = (1 + br * 0.02, 1 + br * 0.03, 1)
    add(p, "spine", rx=-0.15, ry=0.3)
    add(p, "neck", rx=-0.35, ry=0.35)
    add(p, "head", rx=-0.25 + br * 0.02, ry=0.35, rz=0.3)
    ear_pose(p, back=0.35, out=0.15)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.25)
        add(p, "fleg2." + sd, rx=-1.7)
        add(p, "hleg1." + sd, rx=-1.0, rz=-sx * 0.1)
        add(p, "hleg2." + sd, rx=1.5)
    for i in range(3):
        add(p, "tail%d" % (i + 1), ry=-0.7, rx=-0.25 + br * 0.02)
    return p


CLIPS = {name: (secs, loop, prickly(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "attack": (0.75, False, swat_bite),
    "ability": (1.7, False, pounce),
    "sleep": (3.2, True, curl),
    "eat": (2.0, True, prickly(eat_ground)),
    "chop": (1.1, True, chop_mouth),
    "mine": (1.0, True, mine_mouth),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

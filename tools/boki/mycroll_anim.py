"""Mycroll's skeleton and the clips that are its own."""
import boki_clips
import mycroll
from boki_clips import SHARED, add, bite, chop_mouth, ear_pose, eat_ground, mine_mouth, s, seq
from mycroll import SIDES, TAIL_PTS

boki_clips.TAIL_N = 2
boki_clips.DROP = -0.06


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.25, 0.14), (0, 0.25, 0.0), "root"),
        "spine": ((0, 0.25, 0.0), (0, 0.26, -0.08), "hips"),
        "neck": ((0, 0.25, -0.07), (0, 0.25, -0.15), "spine"),
        "head": ((0, 0.25, -0.15), (0, 0.36, -0.2), "neck"),
        "prop_axe": (tuple(mycroll.GRIP), tuple(mycroll.GRIP + mycroll.AXIS * 0.1), "head"),
        "prop_pick": (tuple(mycroll.GRIP), tuple(mycroll.GRIP + mycroll.AXIS * 0.1), "head"),
        "prop_berry": (tuple(mycroll.BERRY_C), tuple(mycroll.BERRY_C + mycroll.v3(0, 0.1, 0)), "root"),
        "cap0": ((-0.1, 0.42, 0.02), (-0.1, 0.52, 0.02), "spine"),
        "cap1": ((0.05, 0.45, 0.0), (0.05, 0.55, 0.0), "spine"),
        "cap2": ((0.14, 0.42, 0.08), (0.14, 0.52, 0.08), "hips"),
        "cap3": ((0.0, 0.38, 0.24), (0.0, 0.48, 0.24), "hips"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.13, 0.335, -0.14), (sx * 0.17, 0.43, -0.14), "head")
        for leg, z in (("f", -0.09), ("h", 0.21)):
            par = "spine" if leg == "f" else "hips"
            b["%sleg1.%s" % (leg, sd)] = ((sx * 0.14, 0.16, z), (sx * 0.145, 0.085, z - 0.004), par)
            b["%sleg2.%s" % (leg, sd)] = ((sx * 0.145, 0.085, z - 0.004), (sx * 0.147, 0.032, z - 0.008), "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = ((sx * 0.147, 0.032, z - 0.008), (sx * 0.149, 0.02, z - 0.09), "%sleg2.%s" % (leg, sd))
    b["tail1"] = (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips")
    b["tail2"] = (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1")
    b.update(boki_clips.part_bones(mycroll.grown_parts()))
    return b


BONES = _bones()


def caps_sway(fn, amp=0.05, rate=2.0):
    """Every clip with the toadstools nodding along behind the body."""
    def clip(t):
        p = fn(t)
        for i in range(4):
            add(p, "cap%d" % i, rx=amp * s(t, rate, i * 0.23), rz=amp * 0.8 * s(t, rate, i * 0.23 + 0.25))
        return p
    return clip


def ability(t):
    """Puffcap mines: gathers itself, shakes hard, and bursts up, shedding spores off its back."""
    p = {}
    gather = seq(t, [(0, 0), (0.28, 1), (0.42, 1), (0.5, -1), (0.66, -0.3), (1, 0)])
    shake = seq(t, [(0, 0), (0.14, 0), (0.28, 1), (0.42, 1), (0.5, 0)])
    down = max(gather, 0)
    up = max(-gather, 0)
    p["root_at"] = (0, -0.05 * down + 0.08 * up, 0)
    p["root_sc"] = (1 + 0.14 * down - 0.06 * up, 1 - 0.18 * down + 0.14 * up, 1 + 0.08 * down)
    add(p, "root", ry=0.2 * shake * s(t, 9))
    add(p, "head", rx=-0.25 * down + 0.3 * up)
    ear_pose(p, back=0.4 * down)
    for i in range(4):
        add(p, "cap%d" % i, rx=0.18 * shake * s(t, 11, i * 0.2) - 0.2 * up, rz=0.16 * shake * s(t, 13, i * 0.3))
    return p


def ball(t):
    """Sleep: rolled into a ball, nose tucked to its belly, toadstools out, breathing."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.075, 0)
    p["root_sc"] = (1 + br * 0.02, 1 + br * 0.03, 1)
    add(p, "spine", rx=-0.12)
    add(p, "neck", rx=-0.42)
    add(p, "head", rx=-0.3 + br * 0.03)
    ear_pose(p, back=0.3)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.3)
        add(p, "fleg2." + sd, rx=-1.9)
        add(p, "hleg1." + sd, rx=-1.0)
        add(p, "hleg2." + sd, rx=1.6)
    add(p, "tail1", rx=0.4)
    return p


CLIPS = {name: (secs, loop, caps_sway(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "attack": (0.8, False, caps_sway(bite, 0.1, 2)),
    "ability": (1.2, False, ability),
    "sleep": (3.4, True, caps_sway(ball, 0.02, 1)),
    "eat": (2.0, True, caps_sway(eat_ground)),
    "chop": (1.1, True, caps_sway(chop_mouth, 0.08)),
    "mine": (1.0, True, caps_sway(mine_mouth, 0.08)),
})
import boki_react
CLIPS.update({n: (sec, lp, caps_sway(fn)) for n, (sec, lp, fn) in boki_react.react().items()})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

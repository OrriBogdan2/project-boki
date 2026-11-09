"""Rimeshrew's skeleton and the clips that are its own: everything a little quicker and twitchier than the others."""
import boki_clips
import rimeshrew
from boki_clips import SHARED, add, bite, chop_mouth, ear_pose, eat_ground, mine_mouth, s, seq, tail_wave
from rimeshrew import SIDES, TAIL_PTS

boki_clips.TAIL_N = 5
boki_clips.DROP = -0.06


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.215, 0.14), (0, 0.215, 0.0), "root"),
        "spine": ((0, 0.215, 0.0), (0, 0.225, -0.07), "hips"),
        "neck": ((0, 0.235, -0.06), (0, 0.255, -0.15), "spine"),
        "head": ((0, 0.255, -0.15), (0, 0.35, -0.2), "neck"),
        "prop_axe": (tuple(rimeshrew.GRIP), tuple(rimeshrew.GRIP + rimeshrew.AXIS * 0.1), "head"),
        "prop_pick": (tuple(rimeshrew.GRIP), tuple(rimeshrew.GRIP + rimeshrew.AXIS * 0.1), "head"),
        "prop_berry": (tuple(rimeshrew.BERRY_C), tuple(rimeshrew.BERRY_C + rimeshrew.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.1, 0.34, -0.15), (sx * 0.11, 0.43, -0.16), "head")
        for leg, z in (("f", -0.08), ("h", 0.2)):
            par = "spine" if leg == "f" else "hips"
            b["%sleg1.%s" % (leg, sd)] = ((sx * 0.1, 0.15, z), (sx * 0.11, 0.085, z - 0.008), par)
            b["%sleg2.%s" % (leg, sd)] = ((sx * 0.11, 0.085, z - 0.008), (sx * 0.115, 0.028, z - 0.012),
                                          "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = ((sx * 0.115, 0.028, z - 0.012), (sx * 0.115, 0.018, z - 0.08),
                                         "%sleg2.%s" % (leg, sd))
    parent = "hips"
    for i in range(5):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b.update(boki_clips.part_bones(rimeshrew.grown_parts()))
    return b


BONES = _bones()


def twitch(fn, amp=1.0):
    """The nose never stops: quick sniffs and ear flicks over any clip."""
    def clip(t):
        p = fn(t)
        add(p, "head", rx=0.03 * amp * s(t, 13), ry=0.025 * amp * s(t, 5, 0.2))
        for sd, sx in SIDES:
            add(p, "ear1." + sd, rz=-sx * 0.06 * amp * max(0.0, s(t, 3, 0.1 if sd == "L" else 0.4)))
        return p
    return clip


def ability(t):
    """Hoarfrost breath: rears and fills its chest, then breathes a long cold cone, head sweeping, plumes up."""
    p = {}
    fill = seq(t, [(0, 0), (0.28, 1), (0.36, 1), (0.42, -1), (0.85, -1), (1, 0)])
    draw = max(fill, 0)
    blow = max(-fill, 0)
    p["root_at"] = (0, 0.02 * draw - 0.015 * blow, 0.03 * draw - 0.03 * blow)
    p["root_sc"] = (1 + 0.1 * draw, 1 + 0.06 * draw - 0.04 * blow, 1)
    add(p, "root", rx=0.25 * draw - 0.08 * blow)
    add(p, "spine", rx=0.1 * draw)
    add(p, "neck", rx=0.15 * draw - 0.1 * blow)
    add(p, "head", rx=0.3 * draw + 0.05 * blow, ry=0.35 * blow * s(t * 1.6, 1, 0.1))
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.45 * draw - 0.25 * blow)
        add(p, "hleg1." + sd, rx=-0.25 * draw + 0.2 * blow)
    ear_pose(p, back=0.6 * blow - 0.1 * draw, out=0.15 * blow)
    tail_wave(p, t * 3, 0.06, up=0.5 * blow + 0.2 * draw)
    return p


def curl(t):
    """Sleep: a tight ball, nose under its tail, breathing fast and shallow."""
    br = s(t, 2)
    p = {}
    p["root_at"] = (0, -0.06, 0)
    p["root_sc"] = (1 + br * 0.02, 1 + br * 0.03, 1)
    add(p, "spine", rx=-0.15, ry=0.25)
    add(p, "neck", rx=-0.4, ry=0.35)
    add(p, "head", rx=-0.25 + br * 0.02, ry=0.3, rz=0.25)
    ear_pose(p, back=0.4)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.2)
        add(p, "fleg2." + sd, rx=-1.7)
        add(p, "hleg1." + sd, rx=-1.0)
        add(p, "hleg2." + sd, rx=1.5)
    for i in range(5):
        add(p, "tail%d" % (i + 1), ry=-0.45, rx=-0.12)
    return p


def squeak(t):
    """Attack: a fearless little lunge and snap, then straight back on guard."""
    p = bite(t)
    add(p, "head", rz=0.12 * seq(t, [(0, 0), (0.42, 0), (0.5, 1), (0.6, -1), (0.7, 0)]))
    return p


CLIPS = {name: (secs * 0.85, loop, twitch(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "attack": (0.7, False, squeak),
    "ability": (1.4, False, ability),
    "sleep": (3.0, True, curl),
    "eat": (1.8, True, twitch(eat_ground, 0.5)),
    "chop": (1.0, True, chop_mouth),
    "mine": (0.9, True, mine_mouth),
})
import boki_react
CLIPS.update({n: (sec, lp, twitch(fn)) for n, (sec, lp, fn) in boki_react.react().items()})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

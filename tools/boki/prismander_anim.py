"""Prismander's skeleton and the clips that are its own."""
import boki_clips
import prismander
from boki_clips import SHARED, add, ear_pose, s, seq, tail_wave, bite, chop_mouth, eat_ground, flop, mine_mouth
from prismander import SIDES, TAIL_PTS

boki_clips.TAIL_N = 5
boki_clips.DROP = -0.075


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.215, 0.14), (0, 0.215, 0.0), "root"),
        "spine": ((0, 0.215, 0.0), (0, 0.22, -0.08), "hips"),
        "neck": ((0, 0.22, -0.08), (0, 0.26, -0.16), "spine"),
        "head": ((0, 0.26, -0.16), (0, 0.36, -0.22), "neck"),
        "prop_axe": (tuple(prismander.v3(0, 0.235, -0.44)), (0, 0.285, -0.53), "head"),
        "prop_pick": (tuple(prismander.v3(0, 0.235, -0.44)), (0, 0.285, -0.53), "head"),
        "prop_berry": (tuple(prismander.BERRY_C), tuple(prismander.BERRY_C + prismander.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.2, 0.34, -0.2), (sx * 0.34, 0.42, -0.16), "head")
        b["fleg1." + sd] = ((sx * 0.125, 0.17, -0.095), (sx * 0.178, 0.11, -0.115), "spine")
        b["fleg2." + sd] = ((sx * 0.178, 0.11, -0.115), (sx * 0.205, 0.035, -0.13), "fleg1." + sd)
        b["fpaw." + sd] = ((sx * 0.205, 0.035, -0.13), (sx * 0.21, 0.02, -0.2), "fleg2." + sd)
        b["hleg1." + sd] = ((sx * 0.125, 0.17, 0.27), (sx * 0.178, 0.11, 0.285), "hips")
        b["hleg2." + sd] = ((sx * 0.178, 0.11, 0.285), (sx * 0.205, 0.035, 0.30), "hleg1." + sd)
        b["hpaw." + sd] = ((sx * 0.205, 0.035, 0.30), (sx * 0.21, 0.02, 0.22), "hleg2." + sd)
    parent = "hips"
    for i in range(5):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b.update(boki_clips.part_bones(prismander.grown_parts()))
    return b


BONES = _bones()


def ability(t):
    """Prism wall: rears up, gills flared, and stamps both forefeet down to raise it."""
    p = {}
    up = seq(t, [(0, 0), (0.3, 1), (0.46, 1), (0.54, -0.6), (0.72, -0.4), (1, 0)])
    rise = max(up, 0)
    low = max(-up, 0)
    add(p, "root", rx=0.34 * rise - 0.06 * low)
    add(p, "spine", rx=0.2 * rise)
    add(p, "head", rx=0.12 * rise - 0.2 * low + 0.2)
    p["root_at"] = (0, 0.05 * rise - 0.02 * low, 0)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.8 * rise - 0.2 * low, rz=-sx * 0.2 * rise)
        add(p, "hleg1." + sd, rx=-0.45 * rise)
        add(p, "ear1." + sd, rx=-0.1 * rise, rz=sx * (0.42 * rise - 0.2 * low))
    tail_wave(p, t, 0.05, up=-0.35 * rise)
    return p


CLIPS = dict(SHARED)
CLIPS.update({
    "attack": (0.8, False, bite),
    "ability": (1.1, False, ability),
    "sleep": (3.4, True, flop),
    "eat": (2.0, True, eat_ground),
    "chop": (1.1, True, chop_mouth),
    "mine": (1.0, True, mine_mouth),
})
import boki_react
CLIPS.update(boki_react.react())
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

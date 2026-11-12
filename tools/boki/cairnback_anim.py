"""Cairnback's skeleton and the clips that are its own: a slow, heavy gait, the cairn rocking on its back, and the
rune-stone it heaves off the top."""
import boki_clips
import cairnback
from boki_clips import SHARED, add, chop_mouth, ear_pose, eat_ground, mine_mouth, s, seq, tail_wave, trot
from cairnback import HORN_PTS, SIDES, STONE_C, TAIL_PTS

boki_clips.TAIL_N = 2
CAIRN_LAG = 1.4                  # how far the cairn trails the shell's sway (rad per rad moved over LAG_S)
LAG_S = 0.06                     # clip time (0..1) the cairn looks back over
THROW = (0, 0.34, -0.3)          # m the rune-stone has flown from the cairn when the heave lets it go


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.21, 0.14), (0, 0.21, 0.0), "root"),
        "spine": ((0, 0.21, 0.0), (0, 0.215, -0.1), "hips"),
        "neck": ((0, 0.225, -0.12), (0, 0.27, -0.24), "spine"),
        "head": ((0, 0.27, -0.24), (0, 0.39, -0.32), "neck"),
        "cairn": ((0, 0.49, 0.06), (0, 0.6, 0.06), "hips"),
        "prop_stone": (tuple(STONE_C), tuple(STONE_C + cairnback.v3(0, 0.1, 0)), "cairn"),
        "prop_axe": (tuple(cairnback.GRIP), tuple(cairnback.GRIP + cairnback.AXIS * 0.1), "head"),
        "prop_pick": (tuple(cairnback.GRIP), tuple(cairnback.GRIP + cairnback.AXIS * 0.1), "head"),
        "prop_berry": (tuple(cairnback.BERRY_C), tuple(cairnback.BERRY_C + cairnback.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["horn." + sd] = ((HORN_PTS[0][0] * sx, HORN_PTS[0][1], HORN_PTS[0][2]),
                           (HORN_PTS[2][0] * sx, HORN_PTS[2][1], HORN_PTS[2][2]), "head")
        b["ear1." + sd] = ((sx * 0.16, 0.375, -0.27), (sx * 0.24, 0.355, -0.26), "head")
        for leg, z, par in (("f", -0.12, "spine"), ("h", 0.22, "hips")):
            b["%sleg1.%s" % (leg, sd)] = ((sx * 0.15, 0.17, z), (sx * 0.165, 0.09, z - 0.005), par)
            b["%sleg2.%s" % (leg, sd)] = ((sx * 0.165, 0.09, z - 0.005), (sx * 0.168, 0.036, z - 0.01),
                                          "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = ((sx * 0.168, 0.036, z - 0.01), (sx * 0.17, 0.02, z - 0.09),
                                         "%sleg2.%s" % (leg, sd))
    b["tail1"] = (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips")
    b["tail2"] = (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1")
    b.update(boki_clips.part_bones(cairnback.grown_parts()))
    return b


BONES = _bones()


def _sway(pose):
    rx = sum(pose.get(bn, (0, 0, 0))[0] for bn in ("root", "hips"))
    return rx, pose.get("root", (0, 0, 0))[2], pose.get("root_at", (0, 0, 0))[1]


def cairn_rocks(fn):
    """The clip with the cairn rocking a beat behind the shell, its rune-stone on top."""
    def clip(t):
        p = fn(t)
        now, before = _sway(p), _sway(fn(t - LAG_S))
        rock_x = -(now[0] - before[0]) * CAIRN_LAG + (now[2] - before[2]) * 3.0
        rock_z = -(now[1] - before[1]) * CAIRN_LAG
        add(p, "cairn", rx=max(-0.3, min(0.3, rock_x)), rz=max(-0.3, min(0.3, rock_z)))
        if not p.pop("stone_thrown", False):
            p["prop_stone"] = "on"
        return p
    return clip


def lumber(t):
    """Walk: a slow, sure tread, the shell rolling from side to side over each foot."""
    p = trot(t, 0.36, 0.012, 0.0, 0.0)
    add(p, "root", rz=s(t, 1) * 0.06)
    add(p, "head", rz=-s(t, 1) * 0.05)
    return p


def trundle(t):
    """Run: as fast as a tortoise goes, head out, the shell bouncing and rolling."""
    p = trot(t, 0.62, 0.034, 0.0, 0.05)
    add(p, "root", rz=s(t, 1) * 0.08)
    add(p, "neck", rx=-0.12)
    add(p, "head", rx=-0.1)
    ear_pose(p, back=0.3)
    return p


def ram(t):
    """Rears back on its hind legs, then drops its horns onto whatever is in front."""
    p = {}
    v = seq(t, [(0, 0), (0.32, 1), (0.44, -1), (0.6, -1), (1, 0)])
    up = max(v, 0)
    down = max(-v, 0)
    add(p, "root", rx=0.22 * up - 0.1 * down)
    p["root_at"] = (0, 0.03 * up - 0.02 * down, 0.05 * up - 0.12 * down)
    add(p, "neck", rx=0.2 * up - 0.22 * down)
    add(p, "head", rx=0.25 * up - 0.32 * down)
    ear_pose(p, back=0.2 + 0.3 * down)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=0.6 * up - 0.2 * down)
        add(p, "hleg1." + sd, rx=-0.25 * up)
    tail_wave(p, t * 2, 0.04)
    return p


def heave(t):
    """Boulder heave: sinks low, then bucks its whole shell so the rune-stone flies off the cairn; a new one rises."""
    p = {}
    v = seq(t, [(0, 0), (0.28, 1), (0.36, -1), (0.46, -0.8), (0.58, 0.5), (0.7, 0), (1, 0)])
    low = max(v, 0)
    buck = max(-v, 0)
    p["root_at"] = (0, -0.045 * low + 0.07 * buck, 0)
    p["root_sc"] = (1 + 0.1 * low - 0.04 * buck, 1 - 0.14 * low + 0.08 * buck, 1 + 0.05 * low)
    add(p, "root", rx=0.05 * low - 0.2 * buck)
    add(p, "neck", rx=-0.25 * low + 0.3 * buck)
    add(p, "head", rx=-0.3 * low + 0.5 * buck)
    ear_pose(p, back=0.4 * low, out=0.2 * buck)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.2 * low, rz=-sx * 0.2 * low)
        add(p, "hleg1." + sd, rx=-0.2 * low - 0.4 * buck, rz=-sx * 0.2 * low)
        add(p, "hleg2." + sd, rx=0.5 * buck)
    tail_wave(p, t, 0.05, up=0.4 * buck)
    fly = seq(t, [(0.3, 0), (0.42, 1)])
    rise = seq(t, [(0.74, -0.06), (0.84, 0.018), (0.9, 0)])
    if t < 0.42:
        p["prop_stone_at"] = tuple(a * fly for a in THROW)
    elif t >= 0.74:
        p["prop_stone_at"] = (0, rise, 0)
    else:
        p["stone_thrown"] = True
    return p


def tucked(t):
    """Sleep: shell down on the ground, legs drawn in, chin resting on the earth just out of its shell."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.07, 0)
    p["root_sc"] = (1 + br * 0.012, 1 + br * 0.025, 1)
    add(p, "neck", rx=-0.32, ry=0.08)
    add(p, "head", rx=0.12 + br * 0.03, ry=0.06, rz=0.1)
    ear_pose(p, back=0.3, out=-0.3)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.0, rz=-sx * 0.35)
        add(p, "fleg2." + sd, rx=-0.7)
        add(p, "hleg1." + sd, rx=-1.0, rz=-sx * 0.35)
        add(p, "hleg2." + sd, rx=0.6)
    add(p, "tail1", ry=-0.3)
    return p


CLIPS = {name: (secs, loop, cairn_rocks(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "walk": (0.9, True, cairn_rocks(lumber)),
    "run": (0.5, True, cairn_rocks(trundle)),
    "attack": (0.85, False, cairn_rocks(ram)),
    "ability": (1.2, False, cairn_rocks(heave)),
    "sleep": (3.6, True, cairn_rocks(tucked)),
    "eat": (2.0, True, cairn_rocks(eat_ground)),
    "chop": (1.1, True, cairn_rocks(chop_mouth)),
    "mine": (1.0, True, cairn_rocks(mine_mouth)),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.40), "prop_stone": (0, -0.1, 0)}

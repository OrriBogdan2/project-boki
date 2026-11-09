"""Lockatara's skeleton and the clips that are its own: an unhurried, heavy lizard's gait, the shackle rocking a beat
behind its back, and the stone it scoops up and throws like a lock's bolt."""
import boki_clips
import lockatara
from boki_clips import SHARED, add, chop_mouth, mine_mouth, eat_ground, s, seq, tail_wave, trot
from lockatara import GRIP, AXIS, BERRY_C, LEGS, SHACKLE_C, SIDES, STONE_C, TAIL_PTS, leg_pts, v3

boki_clips.TAIL_N = 4
SHACKLE_LAG = 1.2                # how far the shackle trails the body's pitch (rad per rad moved over LAG_S)
LAG_S = 0.06                     # clip time (0..1) the shackle looks back over
THROW = (0, 0.12, -0.45)         # m the stone has flown from the jaws when the heave lets it go


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.22, 0.08), (0, 0.22, -0.05), "root"),
        "spine": ((0, 0.22, -0.05), (0, 0.23, -0.2), "hips"),
        "neck": ((0, 0.23, -0.22), (0, 0.26, -0.32), "spine"),
        "head": ((0, 0.26, -0.32), (0, 0.38, -0.40), "neck"),
        "shackle": (tuple(SHACKLE_C), tuple(SHACKLE_C + v3(0, 0.2, 0)), "spine"),
        "prop_stone": (tuple(STONE_C), tuple(STONE_C + v3(0, 0.1, 0)), "head"),
        "prop_axe": (tuple(GRIP), tuple(GRIP + AXIS * 0.1), "head"),
        "prop_pick": (tuple(GRIP), tuple(GRIP + AXIS * 0.1), "head"),
        "prop_berry": (tuple(BERRY_C), tuple(BERRY_C + v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        for leg, z, xh, xf in LEGS:
            top, knee, ankle = leg_pts(z, xh, xf, sx)
            par = "spine" if leg == "f" else "hips"
            b["%sleg1.%s" % (leg, sd)] = (tuple(top), tuple(knee), par)
            b["%sleg2.%s" % (leg, sd)] = (tuple(knee), tuple(ankle), "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = (tuple(ankle), tuple(ankle + v3(0, -0.015, -0.07)), "%sleg2.%s" % (leg, sd))
    for i in range(4):
        b["tail%d" % (i + 1)] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), "hips" if i == 0 else "tail%d" % i)
    b.update(boki_clips.part_bones(lockatara.grown_parts()))
    return b


BONES = _bones()


def _pitch(pose):
    return sum(pose.get(bn, (0, 0, 0))[0] for bn in ("root", "hips", "spine")), pose.get("root_at", (0, 0, 0))[1]


def shackle_rocks(fn):
    """The clip with the shackle rocking fore and aft a beat behind the back."""
    def clip(t):
        p = fn(t)
        now, before = _pitch(p), _pitch(fn(t - LAG_S))
        rock = -(now[0] - before[0]) * SHACKLE_LAG + (now[1] - before[1]) * 2.0
        add(p, "shackle", rx=max(-0.15, min(0.15, rock)) + p.pop("click", 0.0))
        return p
    return clip


def plod(t):
    """Walk: slow and sure, the body swinging from side to side over each foot like a lizard's."""
    p = trot(t, 0.4, 0.01, 0.0, 0.0)
    add(p, "spine", ry=s(t, 1) * 0.08)
    add(p, "hips", ry=-s(t, 1) * 0.06)
    add(p, "head", ry=-s(t, 1) * 0.06)
    tail_wave(p, t, 0.1)
    return p


def scuttle(t):
    """Run: low and quick, the body snaking and the tail swinging wide behind."""
    p = trot(t, 0.66, 0.026, 0.0, 0.04)
    add(p, "spine", ry=s(t, 1) * 0.14)
    add(p, "hips", ry=-s(t, 1) * 0.1)
    add(p, "neck", rx=-0.1, ry=-s(t, 1) * 0.06)
    tail_wave(p, t, 0.16)
    return p


def bash(t):
    """Swings its iron shackle down on whatever is in front: rears up, then drops its whole front with a clang."""
    p = {}
    v = seq(t, [(0, 0), (0.34, 1), (0.46, -1), (0.62, -1), (1, 0)])
    up = max(v, 0)
    down = max(-v, 0)
    add(p, "root", rx=0.2 * up - 0.12 * down)
    p["root_at"] = (0, 0.03 * up - 0.02 * down, 0.04 * up - 0.1 * down)
    add(p, "neck", rx=0.15 * up - 0.2 * down)
    add(p, "head", rx=0.2 * up - 0.3 * down)
    p["click"] = 0.25 * up - 0.3 * down
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=0.6 * up - 0.2 * down)
        add(p, "hleg1." + sd, rx=-0.25 * up)
    tail_wave(p, t * 2, 0.06)
    return p


def heave(t):
    """Boulder heave: dips its head for a stone, the shackle clicks shut, then it flings the stone ahead like a bolt
    shot home; the shackle clicks again."""
    p = {}
    v = seq(t, [(0, 0), (0.22, -1), (0.36, -0.6), (0.5, 1), (0.58, 0.8), (0.75, 0), (1, 0)])
    dip = max(-v, 0)
    fling = max(v, 0)
    add(p, "root", rx=-0.08 * dip + 0.1 * fling)
    p["root_at"] = (0, -0.02 * dip + 0.02 * fling, -0.03 * fling)
    add(p, "neck", rx=-0.35 * dip + 0.35 * fling)
    add(p, "head", rx=-0.3 * dip + 0.25 * fling)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-0.15 * dip + 0.3 * fling, rz=-sx * 0.1 * dip)
        add(p, "hleg1." + sd, rx=-0.15 * fling)
    p["click"] = seq(t, [(0.3, 0), (0.34, -0.2), (0.4, 0), (0.56, 0), (0.6, -0.22), (0.68, 0)])
    tail_wave(p, t, 0.06, up=0.3 * fling)
    if 0.18 <= t < 0.62:
        fly = seq(t, [(0.5, 0), (0.62, 1)])
        p["prop_stone"] = "on"
        p["prop_stone_at"] = tuple(a * fly for a in THROW)
    return p


def bask(t):
    """Sleep: belly flat on warm ground, legs splayed, chin down and the tail curled round to the side."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.06, 0)
    p["root_sc"] = (1 + br * 0.012, 1 + br * 0.025, 1)
    add(p, "neck", rx=-0.2, ry=0.1)
    add(p, "head", rx=0.05 + br * 0.03, ry=0.08)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.6, rz=-sx * 0.5)
        add(p, "fleg2." + sd, rx=-0.5)
        add(p, "hleg1." + sd, rx=-0.7, rz=-sx * 0.5)
        add(p, "hleg2." + sd, rx=0.5)
    for i in range(1, 5):
        add(p, "tail%d" % i, ry=0.18)
    return p


CLIPS = {name: (secs, loop, shackle_rocks(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "walk": (0.95, True, shackle_rocks(plod)),
    "run": (0.5, True, shackle_rocks(scuttle)),
    "attack": (0.85, False, shackle_rocks(bash)),
    "ability": (1.2, False, shackle_rocks(heave)),
    "sleep": (3.6, True, shackle_rocks(bask)),
    "eat": (2.0, True, shackle_rocks(eat_ground)),
    "chop": (1.1, True, shackle_rocks(chop_mouth)),
    "mine": (1.0, True, shackle_rocks(mine_mouth)),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.40), "prop_stone": (0, -0.1, 0)}

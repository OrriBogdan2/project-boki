"""Soakybara's skeleton and the clips that are its own: the tusk shove, the steam stomp and the loaf.
The pool on its back rides one `saddle` bone (a rider sits on its floor); the two lily pads at its neck sway a beat
behind the head."""
import boki_clips
import soakybara
from boki_clips import SHARED, add, chop_mouth, ear_pose, eat_ground, mine_mouth, s, seq, tail_wave
from soakybara import LEG_X, LEGS, PAD, SADDLE, SIDES, TAIL_PTS

boki_clips.TAIL_N = 2
PAD_LAG = 1.4            # how far the pads trail the head's swing (rad per rad moved over LAG_S)
LAG_S = 0.06


def _bones():
    g, a = soakybara.GRIP, soakybara.AXIS
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.27, 0.24), (0, 0.27, 0.06), "root"),
        "spine": ((0, 0.27, 0.06), (0, 0.29, -0.12), "hips"),
        "saddle": (tuple(SADDLE), tuple(SADDLE + soakybara.v3(0, 0.1, 0)), "spine"),
        "neck": ((0, 0.30, -0.13), (0, 0.36, -0.23), "spine"),
        "head": ((0, 0.36, -0.23), (0, 0.42, -0.40), "neck"),
        "prop_axe": (tuple(g), tuple(g + a * 0.1), "head"),
        "prop_pick": (tuple(g), tuple(g + a * 0.1), "head"),
        "prop_berry": (tuple(soakybara.BERRY_C), tuple(soakybara.BERRY_C + soakybara.v3(0, 0.1, 0)), "root"),
    }
    for (sd, sx), (base, pad) in zip(SIDES, PAD):
        b["ear1." + sd] = ((sx * 0.105, 0.50, -0.22), (sx * 0.11, 0.56, -0.23), "head")
        b["pad." + sd] = (tuple(base), tuple(pad), "neck")
        for leg, z, par in LEGS:
            x = sx * LEG_X
            b["%sleg1.%s" % (leg, sd)] = ((x, 0.17, z), (x, 0.08, z), par)
            b["%sleg2.%s" % (leg, sd)] = ((x, 0.08, z), (x, 0.03, z), "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = ((x, 0.03, z), (x, 0.015, z - 0.07), "%sleg2.%s" % (leg, sd))
    b["tail1"] = (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips")
    b["tail2"] = (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1")
    b.update(boki_clips.part_bones(soakybara.grown_parts()))
    return b


BONES = _bones()


def _nod(pose):
    return sum(pose.get(bn, (0, 0, 0))[0] for bn in ("root", "spine", "neck", "head"))


def pads_follow(fn):
    """The clip with the lily pads swinging a beat behind every nod."""
    def clip(t):
        p = fn(t)
        lag = max(-0.4, min(0.4, (_nod(p) - _nod(fn(t - LAG_S))) * PAD_LAG))
        for sd, sx in SIDES:
            add(p, "pad." + sd, rx=-lag, rz=sx * 0.04 * s(t, 1))
        return p
    return clip


def tusk_shove(t):
    """Head down, a short barrel charge, then the tusks shove up and forward."""
    p = {}
    v = seq(t, [(0, 0), (0.3, 1), (0.42, -0.6), (0.5, -1), (0.62, -1), (1, 0)])
    low = max(v, 0)
    hit = max(-v, 0)
    p["root_at"] = (0, -0.025 * low + 0.02 * hit, 0.05 * low - 0.14 * hit)
    add(p, "root", rx=-0.08 * low + 0.08 * hit)
    add(p, "neck", rx=-0.25 * low + 0.2 * hit)
    add(p, "head", rx=-0.3 * low + 0.45 * hit)
    add(p, "saddle", rx=0.06 * low - 0.05 * hit)      # the pool keeps level
    ear_pose(p, back=0.45 * low + 0.2)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=-0.35 * low + 0.3 * hit)
        add(p, "hleg1." + sd, rx=-0.3 * low - 0.25 * hit)
    tail_wave(p, t * 2, 0.05, up=0.3 * low)
    return p


def steam_stomp(t):
    """Prism Wall: rears up on its hind legs, stamps both forefeet down, the pool sloshing and the pads shaking."""
    p = {}
    rear = seq(t, [(0, 0), (0.25, 1), (0.38, 1), (0.46, -0.25), (0.6, 0), (1, 0)])
    up, slam = max(rear, 0), max(-rear, 0)
    shake = seq(t, [(0.44, 0), (0.5, 1), (0.85, 0)])
    p["root_at"] = (0, 0.05 * up - 0.03 * slam, 0.05 * up)
    add(p, "root", rx=0.38 * up - 0.06 * slam)
    add(p, "spine", rx=-0.08 * up)
    add(p, "neck", rx=-0.12 * up + 0.1 * slam)
    add(p, "head", rx=-0.1 * up + 0.12 * slam, rz=0.08 * shake * s(t, 9))
    add(p, "saddle", rx=-0.25 * up + 0.05 * shake * s(t, 7))      # the water stays level-ish while it rears
    ear_pose(p, back=0.35 * up, out=0.25 * shake * s(t, 9, 0.2))
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-0.7 * up + 0.2 * slam, rz=-sx * 0.15 * slam)
        add(p, "fleg2." + sd, rx=0.9 * up)
        add(p, "hleg1." + sd, rx=-0.38 * up, rz=-sx * 0.2 * slam)
        add(p, "pad." + sd, rx=0.25 * shake * s(t, 8, 0.3 if sx > 0 else 0))
    p["root_sc"] = (1 + 0.08 * slam, 1 - 0.1 * slam, 1 + 0.05 * slam)
    tail_wave(p, t, 0.05, up=0.4 * up)
    return p


def loaf(t):
    """Sleep: settled on its belly in a warm loaf, legs tucked, chin low, the pool steaming on its back."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.05, 0)
    p["root_sc"] = (1 + br * 0.012, 1 + br * 0.025, 1)
    add(p, "neck", rx=-0.18)
    add(p, "head", rx=-0.06 + br * 0.03)
    ear_pose(p, back=0.3, out=0.15)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.1, rz=-sx * 0.2)
        add(p, "fleg2." + sd, rx=-0.6)
        add(p, "hleg1." + sd, rx=-1.0, rz=-sx * 0.25)
        add(p, "hleg2." + sd, rx=0.5)
        add(p, "pad." + sd, rx=0.1 + br * 0.04, rz=sx * 0.12)
    return p


CLIPS = {name: (secs, loop, pads_follow(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "attack": (0.8, False, pads_follow(tusk_shove)),
    "ability": (1.3, False, steam_stomp),
    "sleep": (3.6, True, loaf),
    "eat": (2.0, True, pads_follow(eat_ground)),
    "chop": (1.1, True, pads_follow(chop_mouth)),
    "mine": (1.0, True, pads_follow(mine_mouth)),
})
HIDE_AT = {"prop_berry": (0, 0.2, 0.12)}

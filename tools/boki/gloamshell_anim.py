"""Gloamshell's skeleton and its clips: no legs, so it glides on a ripple of its foot, its shell riding on top."""
import boki_clips
import gloamshell
from boki_clips import SHARED, add, chop_mouth, ear_pose, eat_ground, mine_mouth, s, seq, tail_wave
from gloamshell import SIDES, STALK_TIP

boki_clips.TAIL_N = 2
boki_clips.DROP = -0.03


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.09, 0.16), (0, 0.09, 0.0), "root"),
        "spine": ((0, 0.09, 0.0), (0, 0.11, -0.1), "hips"),
        "neck": ((0, 0.12, -0.12), (0, 0.25, -0.21), "spine"),
        "head": ((0, 0.25, -0.21), (0, 0.38, -0.25), "neck"),
        "shell": ((0, 0.18, 0.08), (0, 0.33, 0.1), "spine"),
        "tail1": ((0, 0.075, 0.24), (0, 0.06, 0.33), "hips"),
        "tail2": ((0, 0.06, 0.33), (0, 0.04, 0.42), "tail1"),
        "prop_axe": (tuple(gloamshell.GRIP), tuple(gloamshell.GRIP + gloamshell.AXIS * 0.1), "head"),
        "prop_pick": (tuple(gloamshell.GRIP), tuple(gloamshell.GRIP + gloamshell.AXIS * 0.1), "head"),
        "prop_berry": (tuple(gloamshell.BERRY_C), tuple(gloamshell.BERRY_C + gloamshell.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.045, 0.4, -0.25), (sx * STALK_TIP[0], STALK_TIP[1], STALK_TIP[2]), "head")
    b.update(boki_clips.part_bones(gloamshell.grown_parts()))
    return b


BONES = _bones()


def feelers(p, t, rate=1.0, amp=0.12, back=0.0):
    """The two feelers wave on their own, a little out of step."""
    for sd, sx in SIDES:
        ph = 0.0 if sd == "L" else 0.37
        add(p, "ear1." + sd, rx=-back + amp * s(t, rate, ph), rz=-sx * amp * 0.6 * s(t, rate, ph + 0.25))


def glide(t, pace, reach, head_low):
    """A ripple runs down the foot: the body stretches and gathers, the shell lags and rocks."""
    p = {}
    w = s(t, 1)
    p["root_at"] = (0, 0.004 * max(0.0, w), -0.02 * w * reach)
    p["root_sc"] = (1 - 0.03 * w * reach, 1 - 0.04 * w * reach, 1 + 0.07 * w * reach)
    add(p, "spine", rx=0.03 * s(t, 1, 0.15))
    add(p, "hips", rx=-0.03 * s(t, 1, 0.3))
    add(p, "neck", rx=-head_low + 0.06 * s(t, 1, 0.1), ry=0.06 * s(t, 0.5 * pace))
    add(p, "head", rx=boki_clips.LOOK_UP * 0.8 + head_low * 0.5 + 0.05 * s(t, 1, 0.2))
    add(p, "shell", rx=0.06 * s(t, 1, 0.35) * reach, rz=0.04 * s(t, 0.5 * pace, 0.2))
    tail_wave(p, t, 0.08 * reach, lag=0.12)
    feelers(p, t, 1, 0.08, back=0.15 + head_low)
    return p


def walk(t):
    return glide(t, 1, 1.0, 0.0)


def run(t):
    return glide(t, 1, 1.6, 0.25)


def carry(t):
    p = glide(t, 1, 0.8, -0.1)
    add(p, "shell", rx=-0.04)
    return p


def idle(t):
    p = SHARED["idle"][2](t)
    add(p, "shell", rx=0.02 * s(t, 2, 0.2))
    feelers(p, t, 2, 0.1)
    return p


def hop(t):
    p = SHARED["hop"][2](t)
    up = max(seq(t, [(0, 0), (0.3, 0.2), (0.48, 1), (0.66, 0.2), (1, 0)]), 0)
    add(p, "shell", rx=-0.25 * up + 0.12 * s(t, 2, 0.3) * (1 - up))
    feelers(p, t, 3, 0.25)
    return p


def headbutt(t):
    """Attack: draws its head back into the shell's shadow, then a smug little shove forward."""
    p = {}
    k = seq(t, [(0, 0), (0.3, 1), (0.42, -1), (0.6, -1), (1, 0)])
    back = max(k, 0)
    fwd = max(-k, 0)
    p["root_at"] = (0, 0, 0.03 * back - 0.08 * fwd)
    p["root_sc"] = (1, 1 - 0.05 * back, 1 - 0.06 * back + 0.08 * fwd)
    add(p, "neck", rx=-0.35 * back + 0.2 * fwd)
    add(p, "head", rx=0.3 * back - 0.25 * fwd)
    add(p, "shell", rx=-0.1 * fwd + 0.05 * back)
    feelers(p, t, 2, 0.1, back=0.5 * back)
    return p


def ability(t):
    """Its E: hunkers into its shell, the shell spins half round and back as the violet glow wells up, then it
    sweeps its head to lay the trail."""
    p = {}
    hunker = seq(t, [(0, 0), (0.2, 1), (0.6, 1), (0.72, 0), (1, 0)])
    spin = seq(t, [(0, 0), (0.2, 0), (0.4, 1), (0.6, 0), (1, 0)])
    sweep = seq(t, [(0, 0), (0.62, 0), (0.78, 1), (0.92, -1), (1, 0)])
    p["root_at"] = (0, -0.02 * hunker, 0)
    p["root_sc"] = (1 + 0.06 * hunker, 1 - 0.1 * hunker, 1 - 0.04 * hunker)
    add(p, "neck", rx=-0.4 * hunker, ry=0.4 * sweep)
    add(p, "head", rx=-0.2 * hunker, ry=0.2 * sweep)
    add(p, "shell", ry=0.6 * spin, rz=0.12 * s(t, 6) * hunker)
    feelers(p, t, 2, 0.06, back=0.9 * hunker)
    tail_wave(p, t * 2, 0.08, side=0.6 * sweep)
    return p


def retreat(t):
    """Sleep: drawn down low behind the shell, feelers folded back, breathing slow."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.02, 0.02)
    p["root_sc"] = (1 + br * 0.015, 1 + br * 0.02, 1 - 0.06)
    add(p, "neck", rx=-0.75, ry=0.15)
    add(p, "head", rx=-0.15 + br * 0.02, rz=0.15)
    add(p, "shell", rx=0.06, rz=-0.05)
    ear_pose(p, back=1.0, out=-0.2)
    for i in range(2):
        add(p, "tail%d" % (i + 1), ry=0.25)
    return p


CLIPS = dict(SHARED)
CLIPS.update({
    "idle": (3.2, True, idle),
    "walk": (1.0, True, walk),
    "run": (0.6, True, run),
    "hop": (1.0, True, hop),
    "carry": (1.0, True, carry),
    "attack": (0.8, False, headbutt),
    "ability": (1.5, False, ability),
    "sleep": (4.0, True, retreat),
    "eat": (2.2, True, eat_ground),
    "chop": (1.2, True, chop_mouth),
    "mine": (1.1, True, mine_mouth),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

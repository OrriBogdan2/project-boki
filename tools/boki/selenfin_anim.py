"""Selenfin's skeleton and its clips: it floats upright and swims through the air, the tail sweeping side to side."""
import math

import boki_clips
import selenfin
from boki_clips import SHARED, add, chop_mouth, eat_ground, mine_mouth, s, seq, tail_wave
from selenfin import SIDES, TAIL_PTS

boki_clips.TAIL_N = 3
boki_clips.DROP = -0.12


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.4, 0.14), (0, 0.4, 0.0), "root"),
        "spine": ((0, 0.4, 0.0), (0, 0.42, -0.08), "hips"),
        "neck": ((0, 0.42, -0.08), (0, 0.45, -0.12), "spine"),
        "head": ((0, 0.45, -0.12), (0, 0.56, -0.16), "neck"),
        "prop_axe": (tuple(selenfin.GRIP), tuple(selenfin.GRIP + selenfin.AXIS * 0.1), "head"),
        "prop_pick": (tuple(selenfin.GRIP), tuple(selenfin.GRIP + selenfin.AXIS * 0.1), "head"),
        "prop_berry": (tuple(selenfin.BERRY_C), tuple(selenfin.BERRY_C + selenfin.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.09, 0.37, -0.07), (sx * 0.19, 0.36, -0.03), "spine")
    parent = "hips"
    for i in range(3):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b.update(boki_clips.part_bones(selenfin.grown_parts()))
    return b


BONES = _bones()


def fins(p, t, rate, amp):
    """Pectoral fins paddle in turn, the way a hovering fish holds its place."""
    for sd, sx in SIDES:
        add(p, "ear1." + sd, ry=sx * amp * s(t, rate, 0.0 if sd == "L" else 0.5), rz=-sx * amp * 0.5 * s(t, rate, 0.25))


def swim(t, beat, sweep, lean, bob):
    """The body curves against the tail: the tail sweeps side to side, the head answers a little the other way."""
    p = {}
    p["root_at"] = (0, bob * s(t, 2), 0)
    add(p, "root", rx=-lean)
    add(p, "spine", ry=-0.06 * sweep * s(t, beat, 0.1))
    add(p, "hips", ry=0.12 * sweep * s(t, beat))
    add(p, "head", rx=boki_clips.LOOK_UP * 0.6 + lean * 0.5, ry=-0.05 * sweep * s(t, beat, 0.2))
    tail_wave(p, t * beat, 0.0, roll=0.35 * sweep, lag=0.12)
    fins(p, t, beat * 2, 0.25)
    return p


def idle(t):
    p = swim(t, 1, 0.35, 0.0, 0.012)
    add(p, "head", ry=0.08 * s(t, 1, 0.3))
    return p


def walk(t):
    return swim(t, 1, 1.0, 0.08, 0.01)


def run(t):
    p = swim(t, 1, 1.5, 0.22, 0.006)
    for sd, sx in SIDES:
        add(p, "ear1." + sd, ry=sx * 0.5)       # fins swept back
    return p


def carry(t):
    return swim(t, 1, 0.8, -0.05, 0.01)


def hop(t):
    """A happy leap: dips, springs up curling into a little arc, a shimmy at the top, settles."""
    p = {}
    air = seq(t, [(0, 0), (0.18, -0.6), (0.48, 1), (0.75, -0.25), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p["root_at"] = (0, 0.18 * up - 0.05 * down, 0)
    p["root_sc"] = (1 + 0.06 * down, 1 - 0.12 * down + 0.06 * up, 1 + 0.04 * down)
    add(p, "root", rx=0.35 * seq(t, [(0.2, 0), (0.42, 1), (0.62, -0.6), (0.8, 0)]))
    add(p, "head", rx=0.2 * up)
    tail_wave(p, t * 3, 0.15 * up, roll=0.3, lag=0.1)
    fins(p, t, 6, 0.5 * up + 0.15)
    return p


def settle(t):
    """Sleep: sinks to the ground, tips onto its keel a little, fins barely moving, a slow breath."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, boki_clips.DROP, 0)
    p["root_sc"] = (1 + br * 0.015, 1 + br * 0.02, 1)
    add(p, "root", rz=0.18)
    add(p, "head", rx=-0.1 + br * 0.02)
    tail_wave(p, t, 0.0, roll=0.06, lag=0.2)
    fins(p, t, 1, 0.06)
    return p


def nip(t):
    """Attack: draws back, darts forward with a snap, glides back to its place."""
    p = {}
    k = seq(t, [(0, 0), (0.28, 1), (0.4, -1), (0.6, -1), (1, 0)])
    back = max(k, 0)
    fwd = max(-k, 0)
    p["root_at"] = (0, 0.02 * back, 0.06 * back - 0.16 * fwd)
    p["root_sc"] = (1, 1, 1 - 0.05 * back + 0.06 * fwd)
    add(p, "root", rx=0.12 * back - 0.08 * fwd)
    tail_wave(p, t * 3, 0.0, roll=0.25 + 0.3 * back, lag=0.1)
    fins(p, t, 4, 0.3)
    return p


def ability(t):
    """Its E: rises, turns slowly once round to show the moonstone, the fins flared wide, then sinks back."""
    p = {}
    rise = seq(t, [(0, 0), (0.2, 1), (0.8, 1), (1, 0)])
    turn = seq(t, [(0, 0), (0.2, 0), (0.8, 1), (1, 1)])
    p["root_at"] = (0, 0.12 * rise, 0)
    p["root_sc"] = (1 + 0.04 * rise, 1 + 0.04 * rise, 1 + 0.04 * rise)
    add(p, "root", ry=math.tau * turn, rx=0.1 * rise)
    add(p, "head", rx=0.2 * rise)
    for sd, sx in SIDES:
        add(p, "ear1." + sd, rz=-sx * 0.6 * rise)
    tail_wave(p, t * 2, 0.0, roll=0.2, lag=0.12)
    return p


def lean_in(t):
    """Pet: tips its head into the hand, eyes shut, the tail fluttering."""
    p = idle(t)
    lean = 0.5 + 0.5 * s(t, 1)
    add(p, "root", rz=0.18 * lean)
    add(p, "head", rx=0.1 * lean)
    tail_wave(p, t * 4, 0.0, roll=0.2, lag=0.06)
    return p


def eat(t):
    """Noses down to the berry on the ground and nibbles."""
    p = eat_ground(t)
    p["root_at"] = (0, -0.1, -0.04)
    add(p, "root", rx=-0.55)
    fins(p, t, 3, 0.2)
    return p


def with_fins(fn):
    def clip(t):
        p = fn(t)
        fins(p, t, 3, 0.2)
        tail_wave(p, t * 2, 0.0, roll=0.15, lag=0.12)
        return p
    return clip


CLIPS = dict(SHARED)
CLIPS.update({
    "idle": (3.0, True, idle),
    "walk": (0.9, True, walk),
    "run": (0.5, True, run),
    "hop": (1.0, True, hop),
    "carry": (0.9, True, carry),
    "pet": (2.2, True, lean_in),
    "tend": (1.3, True, with_fins(SHARED["tend"][2])),
    "attack": (0.8, False, nip),
    "ability": (1.6, False, ability),
    "sleep": (4.0, True, settle),
    "eat": (2.0, True, eat),
    "chop": (1.1, True, with_fins(chop_mouth)),
    "mine": (1.0, True, with_fins(mine_mouth)),
})
import boki_react


def _win(p, t, a):
    fins(p, t, 4, 0.6 * a)


def _sulk(p, t, a):
    fins(p, t, 0.5, 0.1)


def _push(p, t, a):
    fins(p, t, 3, 0.35)


CLIPS.update(boki_react.react(extra_win=_win, extra_sulk=_sulk, extra_push=_push))
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

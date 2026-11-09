"""Kindlewren's skeleton and clips: a two-legged wren that hops everywhere, so every clip is its own."""
import math

import numpy as np

import boki_clips
import kindlewren as kw
from boki_clips import add, s, seq
from kindlewren import SIDES, TAIL_PTS, ankle, on_wing, v3, wing_frame

LOOK_UP = 0.32     # tips the face up to the high cameras


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.16, 0.03), (0, 0.28, 0.0), "root"),
        "spine": ((0, 0.28, 0.0), (0, 0.34, -0.04), "hips"),
        "neck": ((0, 0.34, -0.04), (0, 0.37, -0.05), "spine"),
        "head": ((0, 0.37, -0.05), (0, 0.55, -0.07), "neck"),
        "tail1": (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips"),
        "tail2": (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1"),
        "prop_axe": (tuple(kw.GRIP), tuple(kw.GRIP + kw.AXIS * 0.1), "head"),
        "prop_pick": (tuple(kw.GRIP), tuple(kw.GRIP + kw.AXIS * 0.1), "head"),
        "prop_berry": (tuple(kw.BERRY_C), tuple(kw.BERRY_C + v3(0, 0.1, 0)), "root"),
        "prop_blaze": (tuple(kw.COAL_C), tuple(kw.COAL_C + v3(0, 0.1, 0)), "tail2"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = (kw.TUFTS[sd][0], kw.TUFTS[sd][1], "head")
        b["wing1." + sd] = (tuple(on_wing(sx, 0, 0)), tuple(on_wing(sx, 0.1, 0)), "spine")
        b["wing2." + sd] = (tuple(on_wing(sx, 0.1, 0)), tuple(on_wing(sx, 0.22, 0)), "wing1." + sd)
        knee = (sx * 0.08, 0.075, -0.004)
        b["hleg1." + sd] = ((sx * 0.076, 0.13, 0.015), knee, "root")
        b["hleg2." + sd] = (knee, tuple(ankle(sx)), "hleg1." + sd)
        b["hpaw." + sd] = (tuple(ankle(sx)), tuple(ankle(sx) + v3(0, -0.014, -0.07)), "hleg2." + sd)
    b.update(boki_clips.part_bones(kw.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- wings
def _turn(axis, angle):
    """Rotation matrix about a unit axis (right hand)."""
    a = np.asarray(axis, float) / np.linalg.norm(axis)
    k = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(angle) * k + (1 - math.cos(angle)) * (k @ k)


def _part_way(rot, k):
    """`rot` scaled down to k of its angle about the same axis."""
    angle = math.acos(max(-1.0, min(1.0, (np.trace(rot) - 1) * 0.5)))
    if angle < 1e-6:
        return np.eye(3)
    axis = np.array([rot[2, 1] - rot[1, 2], rot[0, 2] - rot[2, 0], rot[1, 0] - rot[0, 1]])
    return _turn(axis, angle * k)


def _euler(rot):
    """The (rx, ry, rz) a clip writes for a rotation: boki_rig applies them as Ry Rx Rz."""
    rx = math.asin(max(-1.0, min(1.0, -rot[1, 2])))
    return rx, math.atan2(rot[0, 2], rot[2, 2]), math.atan2(rot[1, 0], rot[1, 1])


def _open(sx):
    """From the folded wing to spread flat out to its side, leading edge forward, a little swept back."""
    rest = wing_frame(sx)
    span = v3(sx, 0.2, 0.22)
    span /= np.linalg.norm(span)
    lead = v3(0, 0.0, -1.0) - span * (-span[2])
    lead /= np.linalg.norm(lead)
    third = np.cross(span, lead)
    out = np.stack([span, lead, third])
    if np.linalg.det(out) * np.linalg.det(rest) < 0:
        out[2] = -third
    return out.T @ rest


OPEN = {sd: _open(sx) for sd, sx in SIDES}


def wings(p, spread=0.0, beat=0.0, lift=0.0, flick=0.0):
    """Both wings: `spread` opens them out to the side (1 is flat out), `beat` swings them up about the body,
    `lift` raises them folded (a shrug off the back), `flick` snaps the primaries out a little behind."""
    for sd, sx in SIDES:
        rot = _turn((0, 0, 1), sx * beat) @ _part_way(OPEN[sd], spread)
        rx, ry, rz = _euler(rot)
        add(p, "wing1." + sd, rx=rx, ry=ry, rz=rz + sx * lift)
        add(p, "wing2." + sd, ry=-sx * flick * 0.5, rz=sx * flick)


def buzz(p, t, n, spread, amp, ph=0.0):
    """A wren's whirr: quick shallow beats from half-open wings."""
    wings(p, spread, amp * s(t, n, ph), flick=amp * 0.4 * s(t, n, ph - 0.15))


# ---------------------------------------------------------------- body-part helpers
def look(p, k=1.0):
    add(p, "neck", rx=LOOK_UP * k * 0.4)
    add(p, "head", rx=LOOK_UP * k * 0.6)


def cock(p, up=0.0, wag=0.0, roll=0.0):
    """The tail: `up` cocks it forward over the back (below 0 lays it back), `wag` sways it side to side."""
    add(p, "tail1", rx=-up * 0.6, rz=wag * 0.6, ry=roll)
    add(p, "tail2", rx=-up * 0.4, rz=wag * 0.5)


def tufts(p, back=0.0, out=0.0):
    for sd, sx in SIDES:
        add(p, "ear1." + sd, rx=-back, rz=-sx * out)


def legs(p, sd, swing=0.0, lift=0.0):
    """One leg: `swing` forward from the hip, `lift` folds the shank up and curls the toes."""
    add(p, "hleg1." + sd, rx=swing + lift * 0.5)
    add(p, "hleg2." + sd, rx=-lift * 1.1)
    add(p, "hpaw." + sd, rx=lift * 0.5 - swing * 0.6)


def both_legs(p, swing=0.0, lift=0.0):
    for sd, _ in SIDES:
        legs(p, sd, swing, lift)


def bounce(p, t, n, height, crouch):
    """Two-footed hops, n a clip: a crouch, a spring, a squashy landing; returns the air (0..1) of the hop."""
    ph = (t * n) % 1.0
    air = math.sin(math.pi * min(ph / 0.55, 1.0)) if ph < 0.55 else 0.0
    sq = math.sin(math.pi * (ph - 0.55) / 0.45) if ph >= 0.55 else 0.0
    p["root_at"] = (0, height * air - crouch * sq, 0)
    p["root_sc"] = (1 + 0.1 * sq - 0.03 * air, 1 - 0.13 * sq + 0.07 * air, 1 + 0.08 * sq)
    both_legs(p, -0.2 * air + 0.25 * sq, 0.8 * air)
    return air, sq


# ---------------------------------------------------------------- clips
def idle(t):
    """Never still: breathes, jerks its head about, flicks its tail up, taps a foot, flirts its wings."""
    p = {}
    br = s(t, 3)
    p["root_sc"] = (1 + br * 0.012, 1 + br * 0.016, 1 + br * 0.012)
    turn = seq(t, [(0, 0), (0.3, 0), (0.33, 0.45), (0.46, 0.45), (0.49, -0.35), (0.62, -0.35), (0.65, 0.1),
                   (0.8, 0.1), (0.83, 0), (1, 0)])
    tilt = seq(t, [(0, 0), (0.66, 0), (0.7, -0.3), (0.78, -0.3), (0.82, 0), (1, 0)])
    look(p)
    add(p, "neck", ry=turn * 0.5)
    add(p, "head", ry=turn * 0.5, rz=tilt)
    flick = seq(t, [(0, 0), (0.2, 0), (0.23, 1), (0.3, 0.2), (0.33, 0.8), (0.42, 0), (0.8, 0), (0.83, 1), (0.95, 0),
                    (1, 0)])
    cock(p, 0.35 * flick + br * 0.03, 0.05 * s(t, 2))
    tap = max(0.0, s(t, 8)) * seq(t, [(0, 0), (0.55, 0), (0.6, 1), (0.74, 1), (0.78, 0), (1, 0)])
    legs(p, "R", 0.15 * tap, 0.4 * tap)
    flirt = seq(t, [(0, 0), (0.86, 0), (0.88, 1), (0.91, 0.1), (0.93, 0.9), (0.97, 0), (1, 0)])
    wings(p, 0.12 * flirt, 0.25 * flirt, br * 0.02)
    tufts(p, 0.1 * flick, 0.08 * tilt)
    return p


def walk(t):
    """Wrens hop, they don't walk: two bouncy hops a cycle, the tail jerking up on every landing."""
    p = {}
    air, sq = bounce(p, t, 2, 0.05, 0.02)
    add(p, "hips", rx=-0.1 + 0.08 * sq)
    look(p, 1.0 - 0.3 * sq)
    cock(p, 0.35 * sq - 0.15 * air)
    wings(p, 0.05 * air, 0.1 * air, 0.04 * sq)
    tufts(p, 0.15 * air, 0.05)
    return p


def run(t):
    """A skittering dash: quick low hops, body pitched forward, tail laid back, wings whirring."""
    p = {}
    air, sq = bounce(p, t, 2, 0.07, 0.025)
    add(p, "hips", rx=-0.55 + 0.06 * sq)
    look(p, 1.6)
    cock(p, -1.1 + 0.25 * sq)
    buzz(p, t, 4, 0.55, 0.45)
    tufts(p, 0.45, 0.05)
    return p


def hop(t):
    """A cheeky happy twirl: crouch, spring, a whole turn in the air with the wings buzzing, a squashy landing."""
    p = {}
    air = seq(t, [(0, 0), (0.16, -0.6), (0.28, 0.2), (0.48, 1), (0.66, 0.2), (0.76, -0.55), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p["root_at"] = (0, 0.2 * up - 0.045 * down, 0)
    p["root_sc"] = (1 + 0.13 * down - 0.04 * up, 1 - 0.18 * down + 0.09 * up, 1 + 0.1 * down)
    add(p, "root", ry=math.tau * seq(t, [(0, 0), (0.26, 0), (0.7, 1), (1, 1)]))
    look(p, 1 + 0.6 * up - 0.4 * down)
    beat = seq(t, [(0, 0), (0.22, 0), (0.28, 1), (0.66, 1), (0.74, 0), (1, 0)])
    wings(p, 0.15 * down + 0.6 * beat, beat * 0.55 * s(t, 6), flick=0.2 * beat)
    cock(p, 0.5 * down - 0.2 * up, 0.15 * s(t, 2) * up)
    tufts(p, 0.3 * up - 0.1 * down, 0.2 * down)
    both_legs(p, -0.2 * up + 0.15 * down, 0.9 * up)
    return p


def sleep(t):
    """Fluffed into a ball on its belly, head turned back into its shoulder, the coal tail lowered over it."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.06, 0)
    p["root_sc"] = (1.07 + br * 0.015, 0.95 + br * 0.025, 1.05 + br * 0.012)
    both_legs(p, 0.9, 1.4)
    add(p, "hips", rx=-0.05)
    add(p, "neck", rx=-0.15, ry=0.55, rz=0.12)
    add(p, "head", rx=-0.25 + br * 0.02, ry=0.55, rz=0.22)
    wings(p, 0.0, 0.0, -0.08)
    cock(p, -0.9 + br * 0.02, 0.1)
    tufts(p, 0.4, 0.2)
    return p


def eat(t):
    """Pecks the berry in quick jabs, flicks its tail, then tosses its head back to gulp."""
    p = {}
    peck = seq(t, [(0, 0.3), (0.07, 1), (0.12, 0.5), (0.18, 1), (0.23, 0.5), (0.29, 1), (0.36, 0.5), (0.42, 1),
                   (0.52, 0.3), (0.62, 0), (0.72, -0.5), (0.84, 0), (1, 0.3)])
    dip = max(peck, 0)
    toss = max(-peck, 0)
    add(p, "hips", rx=-0.6 * dip + 0.1 * toss)
    add(p, "neck", rx=-0.3 * dip + 0.25 * toss)
    look(p, 1 - dip)
    add(p, "head", rx=-0.35 * dip + 0.3 * toss, rz=0.12 * toss)
    p["root_at"] = (0, 0, -0.025 * dip)
    cock(p, 0.3 * dip + 0.2 * toss, 0.06 * s(t, 3))
    wings(p, 0.0, 0.1 * toss, 0.05 * dip)
    tufts(p, 0.1 * dip, 0.05)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans up into the hand with its eyes shut, fluffing out; the tail wags slow, the wings shiver."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    fluff = 0.03 + 0.03 * lean
    p["root_sc"] = (1 + fluff, 1 + fluff * 0.3, 1 + fluff)
    add(p, "hips", rz=0.06 * lean)
    add(p, "neck", rx=0.08 + lean * 0.06, rz=0.12 * lean)
    look(p, 1 + 0.3 * lean)
    add(p, "head", rz=0.16 + lean * 0.18, ry=lean * 0.08)
    wings(p, 0.04, 0.04 * s(t, 9), 0.03)
    cock(p, 0.2, 0.2 * s(t, 2))
    tufts(p, 0.3 - lean * 0.2, 0.25)
    return p


def beak_tool(t, keys, tool, back, strike):
    """A tool in its beak: rocks back on its tail, then throws its whole round body forward into the blow."""
    p = {}
    v = seq(t, keys)
    up = max(v, 0)
    down = max(-v, 0)
    add(p, "hips", rx=up * back - down * strike)
    add(p, "neck", rx=up * 0.12 - down * strike * 0.35)
    look(p, 0.5 + up * 0.8)
    add(p, "head", rx=-down * strike * 0.4)
    p["root_at"] = (0, -0.01 * down, 0.03 * up - 0.04 * down)
    wings(p, 0.25 * up, 0.3 * up - 0.1 * down, flick=0.2 * down)
    cock(p, 0.4 * down - 0.2 * up)
    both_legs(p, 0.12 * up, 0)
    tufts(p, 0.1 + 0.3 * down, 0.1 * down)
    p[tool] = "on"
    return p


def chop(t):
    return beak_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.35, 0.5)


def mine(t):
    return beak_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.3, 0.9)


def carry(t):
    """Hops along with the load balanced on its head, wings half out to steady it, the tail laid back."""
    p = {}
    air, sq = bounce(p, t, 2, 0.035, 0.02)
    add(p, "hips", rx=0.05 * sq)
    look(p, 0.6)
    cock(p, -0.35 + 0.15 * sq)
    wings(p, 0.25, 0.15 * air, flick=0.1 * sq)
    tufts(p, -0.1, 0.2)
    return p


def tend(t):
    """Any other farm job: bent over the work, pecking at it in bursts, tail ticking, hopping round it."""
    p = {}
    bob = max(0.0, s(t, 3))
    add(p, "hips", rx=-0.4 - bob * 0.12)
    add(p, "neck", rx=-0.15)
    add(p, "head", rx=-bob * 0.25, ry=s(t, 1) * 0.14)
    shuffle = max(0.0, s(t, 1, 0.25))
    p["root_at"] = (0, 0.02 * shuffle, 0)
    add(p, "root", ry=0.18 * s(t, 1))
    both_legs(p, 0, 0.3 * shuffle)
    cock(p, 0.25 * bob, 0.08 * s(t, 2))
    wings(p, 0.05, 0.06 * s(t, 3))
    tufts(p, 0.15)
    return p


def attack(t):
    """First in: a crouch, a lunge beak-first with the wings thrown up, two quick jabs, a hop back."""
    p = {}
    wind = seq(t, [(0, 0), (0.22, 1), (0.32, -1), (0.4, -0.6), (0.48, -1), (0.6, -0.4), (1, 0)])
    load = max(wind, 0)
    strike = max(-wind, 0)
    p["root_at"] = (0, -0.03 * load + 0.04 * strike, 0.04 * load - 0.17 * strike)
    p["root_sc"] = (1 + 0.08 * load, 1 - 0.1 * load + 0.04 * strike, 1 + 0.06 * strike)
    add(p, "hips", rx=0.12 * load - 0.45 * strike)
    look(p, 0.8 + 0.4 * load)
    add(p, "head", rx=-0.3 * strike)
    wings(p, 0.2 * load + 0.5 * strike, 0.5 * strike + 0.2 * load, flick=0.3 * strike)
    cock(p, 0.5 * load - 0.4 * strike)
    both_legs(p, -0.35 * strike + 0.1 * load, 0.3 * load + 0.4 * strike)
    tufts(p, 0.3 * load + 0.4 * strike, 0.1)
    return p


def ability(t):
    """Coal Dart: crouches with the coal tail swinging up, then streaks forward flat out, the coal blazing behind
    it, skids, and flicks its tail high."""
    p = {}
    crouch = seq(t, [(0, 0), (0.22, 1), (0.3, 0), (1, 0)])
    dash = seq(t, [(0, 0), (0.24, 0), (0.34, 1), (0.6, 1), (0.72, 0), (1, 0)])
    skid = seq(t, [(0, 0), (0.58, 0), (0.68, 1), (0.82, 0), (1, 0)])
    go = seq(t, [(0, 0), (0.24, 0), (0.4, 1), (0.62, 1), (1, 0)])
    p["root_at"] = (0, -0.045 * crouch + 0.04 * dash, 0.03 * crouch - 0.4 * go)
    p["root_sc"] = (1 + 0.1 * crouch - 0.06 * dash, 1 - 0.14 * crouch - 0.06 * dash, 1 + 0.06 * crouch + 0.2 * dash)
    add(p, "hips", rx=0.08 * crouch - 0.9 * dash + 0.25 * skid)
    look(p, 1 + 0.4 * crouch + 2.2 * dash - 0.4 * skid)
    cock(p, 0.45 * crouch - 2.4 * dash + 0.7 * skid, 0.08 * s(t, 6) * dash)
    wings(p, 0.15 * crouch + 0.3 * dash, -0.25 * dash + 0.3 * skid, -0.1 * dash, 0.2 * skid)
    both_legs(p, 0.1 * crouch - 0.7 * dash + 0.5 * skid, 0.6 * crouch + 1.1 * dash)
    tufts(p, 0.9 * dash + 0.2 * crouch, 0.1)
    if 0.22 < t < 0.78:
        p["prop_blaze"] = "on"
    return p


CLIPS = {"idle": (3.0, True, idle), "walk": (0.6, True, walk), "run": (0.42, True, run), "hop": (1.0, True, hop),
         "pet": (2.4, True, pet), "carry": (0.66, True, carry), "tend": (1.2, True, tend),
         "attack": (0.7, False, attack), "ability": (1.1, False, ability), "sleep": (3.6, True, sleep),
         "eat": (2.0, True, eat), "chop": (1.1, True, chop), "mine": (1.0, True, mine)}
import boki_react


def _win(p, t, a):
    buzz(p, t, 5, 0.5, 0.4 * a)


def _sulk(p, t, a):
    wings(p, lift=-0.1)


def _push(p, t, a):
    wings(p, 0.12, flick=0.2)


CLIPS.update(boki_react.react(hop=1.2, slump=0.9, brace=0.8, extra_win=_win, extra_sulk=_sulk, extra_push=_push))
HIDE_AT = {"prop_berry": (0, 0.2, 0.28)}

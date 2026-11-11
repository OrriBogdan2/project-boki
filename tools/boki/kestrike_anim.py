"""Kestrike's skeleton and clips: an upright two-legged kestrel with long folding wings and a fanning tail, whose
signature is a short hover (hop, ability)."""
import math

import numpy as np

import boki_clips
import kestrike as ks
from boki_clips import add, s, seq
from kestrike import EAR_PTS, ROD, SIDES, SPARK_C, TAIL_PTS, ankle, on_wing, v3, wing_frame

LOOK_UP = 0.3      # tips the face up to the high cameras


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.16, 0.04), (0, 0.3, 0.0), "root"),
        "spine": ((0, 0.3, 0.0), (0, 0.4, -0.04), "hips"),
        "neck": ((0, 0.4, -0.04), (0, 0.43, -0.05), "spine"),
        "head": ((0, 0.43, -0.05), (0, 0.6, -0.06), "neck"),
        "crest": (tuple(ROD[0]), tuple(ROD[2]), "head"),
        "tail1": (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips"),
        "tail2": (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1"),
        "prop_axe": (tuple(ks.GRIP), tuple(ks.GRIP + ks.AXIS * 0.1), "head"),
        "prop_pick": (tuple(ks.GRIP), tuple(ks.GRIP + ks.AXIS * 0.1), "head"),
        "prop_berry": (tuple(ks.BERRY_C), tuple(ks.BERRY_C + v3(0, 0.1, 0)), "root"),
        "prop_charge": (tuple(SPARK_C), tuple(SPARK_C + v3(0, 0.1, 0)), "crest"),
        "prop_bolt": (tuple(SPARK_C), tuple(SPARK_C + v3(0, 0, -0.1)), "crest"),
    }
    for sd, sx in SIDES:
        b["tfan." + sd] = (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2] + v3(sx * 0.03, 0, 0)), "tail2")
        b["ear1." + sd] = ((sx * EAR_PTS[0][0], EAR_PTS[0][1], EAR_PTS[0][2]),
                           (sx * EAR_PTS[2][0], EAR_PTS[2][1], EAR_PTS[2][2]), "head")
        b["wing1." + sd] = (tuple(on_wing(sx, 0, 0)), tuple(on_wing(sx, 0.12, 0)), "spine")
        b["wing2." + sd] = (tuple(on_wing(sx, 0.12, 0)), tuple(on_wing(sx, 0.34, 0)), "wing1." + sd)
        knee = (sx * 0.072, 0.07, 0.01)
        b["hleg1." + sd] = ((sx * 0.068, 0.12, 0.03), knee, "root")
        b["hleg2." + sd] = (knee, tuple(ankle(sx)), "hleg1." + sd)
        b["hpaw." + sd] = (tuple(ankle(sx)), tuple(ankle(sx) + v3(0, -0.014, -0.07)), "hleg2." + sd)
    b.update(boki_clips.part_bones(ks.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- wings and tail
def _turn(axis, angle):
    """Rotation matrix about an axis (right hand)."""
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
    """From folded down its back to spread out to its side, leading edge forward, the long tips swept back."""
    rest = wing_frame(sx)
    span = v3(sx, 0.18, 0.2)
    span /= np.linalg.norm(span)
    lead = v3(0, 0.0, -1.0) - span * (-span[2])
    lead /= np.linalg.norm(lead)
    third = np.cross(span, lead)
    out = np.stack([span, lead, third])
    if np.linalg.det(out) * np.linalg.det(rest) < 0:
        out[2] = -third
    return out.T @ rest


OPEN = {sd: _open(sx) for sd, sx in SIDES}
FAN_AXIS = np.cross(TAIL_PTS[2] - TAIL_PTS[1], v3(1, 0, 0))     # the tail's own plane: its feathers fan in it


def wings(p, spread=0.0, beat=0.0, lift=0.0, sweep=0.0):
    """Both wings: `spread` opens them out to the side (1 is flat out), `beat` swings them up about the body,
    `lift` raises them folded, `sweep` draws the long hand back (a stoop) or, below 0, reaches it forward."""
    for sd, sx in SIDES:
        rot = _turn((0, 0, 1), sx * beat) @ _part_way(OPEN[sd], spread)
        rx, ry, rz = _euler(rot)
        add(p, "wing1." + sd, rx=rx, ry=ry, rz=rz + sx * lift)
        add(p, "wing2." + sd, ry=-sx * sweep)


def flap(p, t, n, spread, amp, lift=0.0, ph=0.0):
    """Wing beats, n a clip: the hand trails the arm a little (follow-through)."""
    wings(p, spread, amp * s(t, n, ph) + lift, sweep=0.25 * amp * s(t, n, ph - 0.15))


def fan(p, k):
    """Spreads the tail's outer feathers out to a fan."""
    for sd, sx in SIDES:
        rx, ry, rz = _euler(_turn(FAN_AXIS, sx * 0.5 * k))
        add(p, "tfan." + sd, rx=rx, ry=ry, rz=rz)


# ---------------------------------------------------------------- body-part helpers
def look(p, k=1.0):
    add(p, "neck", rx=LOOK_UP * k * 0.4)
    add(p, "head", rx=LOOK_UP * k * 0.6)


def tail(p, down=0.0, wag=0.0):
    """`down` presses the tail down and under (below 0 lifts it out behind)."""
    add(p, "tail1", rx=-down * 0.6, ry=wag * 0.5)
    add(p, "tail2", rx=-down * 0.4, ry=wag * 0.5)


def ears(p, back=0.0, out=0.0):
    for sd, sx in SIDES:
        add(p, "ear1." + sd, rx=back, ry=-sx * out)


def legs(p, sd, swing=0.0, lift=0.0):
    """One leg: `swing` forward from the hip, `lift` folds the shank up and curls the toes."""
    add(p, "hleg1." + sd, rx=swing + lift * 0.5)
    add(p, "hleg2." + sd, rx=-lift * 1.1)
    add(p, "hpaw." + sd, rx=lift * 0.5 - swing * 0.6)


def both_legs(p, swing=0.0, lift=0.0):
    for sd, _ in SIDES:
        legs(p, sd, swing, lift)


def hover(p, t, k, beats, height):
    """The kestrel's hang in the air: body lifted and tipped up, wings beating in a high V, tail fanned and pressed
    down, feet dangling, while the head holds still (it bobs against the body)."""
    bob = s(t, beats, 0.25) * 0.012 * k
    p["root_at"] = (0, height * k + bob, 0)
    add(p, "hips", rx=0.25 * k)
    add(p, "neck", rx=-0.15 * k)
    add(p, "head", rx=-0.1 * k)
    flap(p, t, beats, 0.95 * k, 0.5 * k, lift=0.1 * k)
    tail(p, 0.45 * k)
    fan(p, k)
    both_legs(p, 0.2 * k, 0.35 * k)


# ---------------------------------------------------------------- clips
def idle(t):
    """Stands tall and watches: slow breaths, sharp head turns with long held stares, a pump of the tail, a rouse."""
    p = {}
    br = s(t, 2)
    rouse = seq(t, [(0, 0), (0.82, 0), (0.85, 1), (0.92, 1), (0.96, 0), (1, 0)])
    shiver = s(t, 18) * rouse
    fluff = br * 0.01 + 0.05 * rouse
    p["root_sc"] = (1 + fluff, 1 + br * 0.014 + 0.02 * rouse, 1 + fluff)
    add(p, "spine", rx=0.04 + br * 0.015)
    turn = seq(t, [(0, 0), (0.24, 0), (0.27, 0.6), (0.44, 0.6), (0.47, -0.45), (0.62, -0.45), (0.65, 0), (1, 0)])
    tilt = seq(t, [(0, 0), (0.5, 0), (0.53, 0.25), (0.58, 0.25), (0.61, 0), (1, 0)])
    look(p)
    add(p, "neck", ry=turn * 0.45)
    add(p, "head", ry=turn * 0.55, rz=tilt)
    pump = seq(t, [(0, 0), (0.12, 0), (0.15, 1), (0.2, 0), (0.7, 0), (0.73, 1), (0.78, 0), (1, 0)])
    tail(p, 0.25 * pump, 0.08 * shiver)
    wings(p, 0.0, 0.0, 0.06 * rouse + 0.04 * shiver)
    ears(p, 0.15 * rouse, 0.2 * rouse)
    add(p, "crest", rz=0.1 * shiver)
    return p


def walk(t):
    """A proud strut: chest out, a step a beat, the head bobbing forward and back over each one."""
    p = {}
    sw = s(t, 1)
    add(p, "hips", rz=sw * 0.08)
    add(p, "spine", rx=0.06)
    look(p)
    add(p, "neck", rx=-0.12 * s(t, 2, 0.1))
    add(p, "head", rx=0.1 * s(t, 2, 0.1), rz=-sw * 0.06)
    p["root_at"] = (0, abs(s(t, 1)) * 0.012 - 0.003, 0)
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        legs(p, sd, s(t, 1, ph) * 0.45, max(0.0, s(t, 1, ph + 0.25)) * 0.75)
    tail(p, 0.1 * abs(sw), 0.08 * sw)
    wings(p, 0.0, 0.0, 0.03)
    ears(p, 0.05)
    return p


def run(t):
    """Skims low: a kick off, two quick wingbeats with the feet tucked, a light touch-down."""
    p = {}
    air = seq(t, [(0, 0), (0.12, 0), (0.48, 1), (0.86, 0), (1, 0)])
    land = seq(t, [(0, 1), (0.1, 0), (0.88, 0), (1, 1)])
    p["root_at"] = (0, 0.1 * air - 0.012 * land, 0)
    p["root_sc"] = (1 + 0.05 * land, 1 - 0.07 * land + 0.03 * air, 1 + 0.04 * land)
    add(p, "hips", rx=-0.5 - 0.06 * land)
    look(p, 1.6 + 0.3 * land)
    flap(p, t, 2, 0.75, 0.55, ph=0.1)
    tail(p, -0.3, 0.0)
    fan(p, 0.3)
    k = seq(t, [(0, 0), (0.14, 0), (0.24, 1), (0.74, 1), (0.88, 0), (1, 0)])
    both_legs(p, -0.5 * k + 0.25 * land, 1.0 * k)
    ears(p, 0.4)
    return p


def hop(t):
    """Happy, it shows off its hover: a crouch, a spring, a hang in the air on beating wings, a squashy landing."""
    p = {}
    hang = seq(t, [(0, 0), (0.18, 0), (0.3, 1), (0.72, 1), (0.84, 0), (1, 0)])
    crouch = seq(t, [(0, 0), (0.14, 1), (0.22, 0), (0.82, 0), (0.88, 0.8), (1, 0)])
    hover(p, t, hang, 6, 0.2)
    at = p["root_at"]
    p["root_at"] = (at[0], at[1] - 0.045 * crouch, at[2])
    p["root_sc"] = (1 + 0.12 * crouch, 1 - 0.16 * crouch + 0.05 * hang, 1 + 0.1 * crouch)
    look(p, 1 + 0.4 * hang)
    add(p, "head", rz=0.12 * s(t, 1) * hang)
    wings(p, 0.15 * crouch, 0.4 * crouch)
    ears(p, -0.15 * hang + 0.2 * crouch, 0.15 * crouch)
    return p


def sleep(t):
    """Asleep on one leg, the other tucked up, fluffed out, head turned right round into the feathers of its back."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.012, 0)
    p["root_sc"] = (1.08 + br * 0.015, 0.96 + br * 0.02, 1.06 + br * 0.012)
    legs(p, "R", 0.5, 1.5)
    add(p, "hips", rz=-0.04)
    add(p, "neck", rx=-0.2, ry=0.9, rz=0.1)
    add(p, "head", rx=-0.35 + br * 0.02, ry=1.1, rz=0.3)
    wings(p, 0.0, 0.0, -0.04)
    tail(p, 0.15, 0.04)
    ears(p, 0.3, 0.1)
    add(p, "crest", rx=-0.3)
    return p


def eat(t):
    """Raptor manners: bends to the berry, tugs a piece off with a jerk of the head, twice, then gulps."""
    p = {}
    v = seq(t, [(0, 0), (0.1, 1), (0.16, 1), (0.22, 0.4), (0.3, 1), (0.36, 1), (0.42, 0.4), (0.55, 0),
                (0.66, -0.6), (0.78, 0), (1, 0)])
    dip = max(v, 0)
    toss = max(-v, 0)
    tug = seq(t, [(0, 0), (0.16, 0), (0.2, 1), (0.24, 0), (0.36, 0), (0.4, 1), (0.44, 0), (1, 0)])
    add(p, "hips", rx=-0.7 * dip + 0.1 * toss)
    add(p, "neck", rx=-0.3 * dip + 0.3 * toss + 0.25 * tug)
    look(p, 1 - dip)
    add(p, "head", rx=-0.3 * dip + 0.3 * toss + 0.2 * tug, rz=0.15 * tug)
    p["root_at"] = (0, 0, -0.02 * dip)
    wings(p, 0.0, 0.12 * dip, 0.05 * dip)
    tail(p, -0.3 * dip, 0.06 * tug)
    ears(p, 0.1 * dip)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Proud, but it leans into the hand: eyes shut, fluffing out, wings drooping a little, the tail wagging slow."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    fluff = 0.03 + 0.03 * lean
    p["root_sc"] = (1 + fluff, 1 + fluff * 0.3, 1 + fluff)
    add(p, "neck", rx=0.08 + lean * 0.06, rz=0.12 * lean)
    look(p, 1 + 0.3 * lean)
    add(p, "head", rz=0.16 + lean * 0.18, ry=lean * 0.08)
    wings(p, 0.0, 0.0, -0.04 * lean)
    tail(p, 0.0, 0.15 * s(t, 2))
    ears(p, 0.35, 0.2 * lean)
    return p


def beak_tool(t, keys, tool, back, strike):
    """A tool in its beak: rears back on spread wings, then throws its weight forward into the blow."""
    p = {}
    v = seq(t, keys)
    up = max(v, 0)
    down = max(-v, 0)
    add(p, "hips", rx=up * back - down * strike)
    add(p, "neck", rx=up * 0.12 - down * strike * 0.35)
    look(p, 0.5 + up * 0.8)
    add(p, "head", rx=-down * strike * 0.4)
    p["root_at"] = (0, -0.01 * down, 0.03 * up - 0.04 * down)
    wings(p, 0.35 * up, 0.3 * up, sweep=0.2 * down)
    tail(p, -0.3 * down + 0.2 * up)
    both_legs(p, 0.12 * up, 0)
    ears(p, 0.1 + 0.3 * down)
    p[tool] = "on"
    return p


def chop(t):
    return beak_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.35, 0.5)


def mine(t):
    return beak_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.3, 0.9)


def carry(t):
    """Struts leaning forward with the load on its back, wings held a little out to steady it."""
    p = walk(t)
    add(p, "hips", rx=-0.2)
    look(p, 0.5)
    wings(p, 0.2, 0.15 + 0.05 * s(t, 2))
    ears(p, -0.1, 0.15)
    return p


def tend(t):
    """Any other farm job: bent over the work, pecking at it, stepping round it."""
    p = {}
    bob = max(0.0, s(t, 2))
    add(p, "hips", rx=-0.45 - bob * 0.12)
    add(p, "neck", rx=-0.15)
    add(p, "head", rx=-bob * 0.25, ry=s(t, 1) * 0.12)
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        legs(p, sd, 0.0, max(0.0, s(t, 1, ph)) * 0.35)
    tail(p, -0.35, 0.06 * s(t, 1))
    wings(p, 0.05, 0.05 * s(t, 2))
    ears(p, 0.15)
    return p


def attack(t):
    """A stoop: wings up and then swept back tight, a dive forward with the talons thrown out, a flare, a settle."""
    p = {}
    wind = seq(t, [(0, 0), (0.26, 1), (0.36, -1), (0.54, -1), (1, 0)])
    load = max(wind, 0)
    strike = max(-wind, 0)
    flare = seq(t, [(0, 0), (0.44, 0), (0.52, 1), (0.66, 1), (0.85, 0), (1, 0)])
    p["root_at"] = (0, -0.03 * load + 0.06 * strike, 0.04 * load - 0.22 * strike)
    p["root_sc"] = (1 + 0.08 * load, 1 - 0.1 * load + 0.04 * strike, 1)
    add(p, "hips", rx=0.1 * load - 0.35 * strike + 0.3 * flare)
    look(p, 0.6 + 0.3 * strike)
    add(p, "head", rx=-0.25 * strike)
    wings(p, 0.55 * load + 0.85 * flare, 0.6 * load + 0.3 * flare, sweep=0.5 * strike * (1 - flare))
    tail(p, -0.4 * strike + 0.4 * flare)
    fan(p, flare)
    both_legs(p, 1.0 * strike - 0.2 * load, 0.4 * load)
    for sd, _ in SIDES:
        add(p, "hpaw." + sd, rx=0.5 * strike)
    ears(p, 0.5 * strike + 0.2 * load)
    return p


def ability(t):
    """Rod Strike: up into a hover, wings spread, the crest rod charging; the head drawn back, then a snap forward
    that flings the bolt; a beat to hang there, and down."""
    p = {}
    hang = seq(t, [(0, 0), (0.06, 0), (0.22, 1), (0.74, 1), (0.88, 0), (1, 0)])
    hover(p, t, hang, 7, 0.16)
    draw = seq(t, [(0, 0), (0.3, 0), (0.46, 1), (0.5, 1), (0.54, 0), (1, 0)])
    snap = seq(t, [(0, 0), (0.5, 0), (0.54, 1), (0.64, 1), (0.76, 0), (1, 0)])
    land = seq(t, [(0, 0), (0.86, 0), (0.92, 1), (1, 0)])
    at = p["root_at"]
    p["root_at"] = (at[0], at[1] - 0.03 * land, at[2] + 0.03 * draw - 0.04 * snap)
    p["root_sc"] = (1 + 0.1 * land, 1 - 0.13 * land, 1 + 0.08 * land)
    look(p, 1.0 + 0.6 * draw)
    add(p, "neck", rx=0.2 * draw - 0.25 * snap)
    add(p, "head", rx=0.25 * draw - 0.45 * snap)
    add(p, "crest", rx=-0.25 * draw + 0.35 * snap)
    wings(p, 0.1 * snap, 0.25 * draw - 0.3 * snap)
    ears(p, 0.4 * draw + 0.2 * snap, 0.15)
    if 0.16 < t < 0.54:
        p["prop_charge"] = "on"
    if 0.53 < t < 0.68:
        p["prop_bolt"] = "on"
    return p


CLIPS = {"idle": (3.6, True, idle), "walk": (0.7, True, walk), "run": (0.5, True, run), "hop": (1.3, True, hop),
         "pet": (2.4, True, pet), "carry": (0.75, True, carry), "tend": (1.3, True, tend),
         "attack": (0.8, False, attack), "ability": (1.5, False, ability), "sleep": (3.6, True, sleep),
         "eat": (2.2, True, eat), "chop": (1.1, True, chop), "mine": (1.0, True, mine)}
import boki_react


def _win(p, t, a):
    wings(p, 0.55 * a, 0.45 * a, sweep=0.2 * a)


def _sulk(p, t, a):
    wings(p, 0.0, 0.0, -0.12)


def _push(p, t, a):
    wings(p, 0.1, 0.0, 0.0, 0.3)


CLIPS.update(boki_react.react(hop=1.1, slump=1.0, brace=0.9, extra_win=_win, extra_sulk=_sulk, extra_push=_push))
HIDE_AT = {"prop_berry": (0, 0.2, 0.26)}

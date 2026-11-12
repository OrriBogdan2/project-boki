"""Thrumbird's skeleton and clips. A hummingbird hovers: every clip but sleep holds it up on a buzz of its wings, so
all are its own. The beat is a blur: a painted fan (prop_blur) under each wing, and the wing itself swapping between
the fan's front and back edge on every frame of the 15 fps review sampling (BUZZ beats per second)."""
import math

import boki_clips
import thrumbird
from boki_clips import add, c, s, seq
from thrumbird import SIDES, mir, v3

LOOK_UP = 0.3        # the face tips up toward the high cameras
LIFT = 0.3           # m: how high it hovers, feet to ground
BUZZ = 7.5           # wing beats per second: one swap of the wing per review frame at 15 fps
RINGS = 3


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.2, 0.08), (0, 0.25, -0.02), "root"),
        "spine": ((0, 0.25, -0.02), (0, 0.31, -0.045), "hips"),
        "neck": ((0, 0.31, -0.045), (0, 0.38, -0.06), "spine"),
        "head": ((0, 0.38, -0.06), (0, 0.58, -0.07), "neck"),
        "tail1": (tuple(thrumbird.TAIL_ROOT), tuple(thrumbird.YOKE), "hips"),
        "prop_axe": (tuple(thrumbird.GRIP), tuple(thrumbird.GRIP + thrumbird.AXIS * 0.1), "hips"),
        "prop_pick": (tuple(thrumbird.GRIP), tuple(thrumbird.GRIP + thrumbird.AXIS * 0.1), "hips"),
        "prop_berry": (tuple(thrumbird.BERRY_C), tuple(thrumbird.BERRY_C + v3(0, 0.1, 0)), None),  # stays on the ground
    }
    for i in range(RINGS):
        b["prop_ring%d" % (i + 1)] = (tuple(thrumbird.RING_C), tuple(thrumbird.RING_C + v3(0, 0.1, 0)), "root")
    for sd, sx in SIDES:
        sh = mir(thrumbird.SHOULDER, sx)
        b["ear1." + sd] = ((sx * 0.016, 0.578, -0.05), (sx * 0.036, 0.63, 0.14), "head")
        b["wing." + sd] = (tuple(sh), tuple(mir(thrumbird.WING_TIP, sx)), "spine")
        b["prop_blur." + sd] = (tuple(sh), tuple(sh + (mir(thrumbird.WING_TIP, sx) - sh) * 0.3), "spine")
        b["fork." + sd] = (tuple(thrumbird.YOKE + v3(sx * thrumbird.PRONG_X, 0, 0)),
                           tuple(mir(thrumbird.PRONG_END, sx)), "tail1")
        knee = (sx * 0.055, 0.072, 0.03)
        ankle = (sx * 0.056, 0.024, 0.0)
        b["hleg1." + sd] = ((sx * 0.05, 0.13, 0.05), knee, "hips")
        b["hleg2." + sd] = (knee, ankle, "hleg1." + sd)
        b["hpaw." + sd] = (ankle, (sx * 0.056, 0.014, -0.05), "hleg2." + sd)
    b.update(boki_clips.part_bones(thrumbird.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- body-part helpers
def look(p, k=1.0):
    add(p, "neck", rx=LOOK_UP * k * 0.4)
    add(p, "head", rx=LOOK_UP * k * 0.6)


def legs(p, sd, swing=0.0, fold=0.0):
    """One leg: `swing` forward from the hip, `fold` bends the shank back and curls the toes."""
    add(p, "hleg1." + sd, rx=swing + fold * 0.5)
    add(p, "hleg2." + sd, rx=-fold * 1.2)
    add(p, "hpaw." + sd, rx=fold * 0.7 - swing * 0.5)


def tuck(p, k=1.0):
    """In flight the feet fold up under the belly."""
    for sd, _ in SIDES:
        legs(p, sd, 0.5 * k, 0.9 * k)


def crest(p, back=0.0, flick=0.0):
    for sd, sx in SIDES:
        add(p, "ear1." + sd, rx=-back, rz=sx * flick)


def fork(p, spread=0.0, ring=0.0, t=0.0, beats=1):
    """The prongs open (spread) and, ringing, shiver against each other once per frame."""
    v = ring * c(t, beats)
    for sd, sx in SIDES:
        add(p, "fork." + sd, ry=sx * (spread + v))


def buzz(p, t, beats, amp=0.42, lift=0.0, fwd=0.0):
    """The wings swap between the front and back of their blur each sampled frame; the blur fans are out."""
    b = c(t, beats)
    for sd, sx in SIDES:
        add(p, "wing." + sd, ry=sx * (fwd + amp * b), rz=sx * (lift + 0.08 * b))
        p["prop_blur." + sd] = "on"


def hover(p, t, beats, lift=LIFT, pitch=0.12, amp=0.42, tail=0.0):
    """Holds it up in the air: lift (m), the body's pitch (nose up > 0) with the tail balancing it."""
    p["root_at"] = (0, lift, 0)
    add(p, "root", rx=pitch)
    add(p, "tail1", rx=-tail + pitch * 0.4)
    buzz(p, t, beats, amp)
    tuck(p)


def beats(seconds):
    return int(round(seconds * BUZZ))


def at(p, x=0.0, y=0.0, z=0.0):
    o = p.get("root_at", (0, 0, 0))
    p["root_at"] = (o[0] + x, o[1] + y, o[2] + z)


# ---------------------------------------------------------------- clips
IDLE_S, WALK_S, RUN_S, HOP_S, PET_S, CARRY_S, TEND_S = 1.2, 0.8, 0.4, 1.2, 2.4, 0.8, 1.2
ATTACK_S, ABILITY_S, EAT_S, WORK_S, SLEEP_S = 0.8, 1.6, 2.0, 1.2, 3.6


def idle(t):
    """Hangs in the air, never still: a bob, a drift, the head darting this way and that."""
    p = {}
    hover(p, t, beats(IDLE_S), pitch=0.14 + 0.03 * s(t, 1))
    at(p, x=0.018 * s(t, 1, 0.3), y=0.016 * s(t, 1))
    turn = seq(t, [(0, 0), (0.08, 0.5), (0.3, 0.5), (0.36, 0), (0.62, 0), (0.68, -0.4), (0.86, -0.4), (0.92, 0),
                   (1, 0)])
    tilt = seq(t, [(0, 0), (0.68, 0), (0.74, -0.2), (0.84, -0.2), (0.9, 0), (1, 0)])
    look(p)
    add(p, "neck", ry=turn * 0.4)
    add(p, "head", ry=turn * 0.5, rz=tilt)
    add(p, "tail1", rx=0.08 * s(t, 2))
    fork(p, 0.03 * s(t, 2, 0.2))
    crest(p, 0.05, 0.1 * s(t, 2))
    return p


def flight(t, seconds, pitch, lift, tail):
    """Forward flight: the body tips forward with speed, the head held up to see, the tail streaming."""
    p = {}
    hover(p, t, beats(seconds), lift=lift, pitch=pitch, amp=0.46, tail=tail)
    at(p, y=0.012 * s(t, 1))
    add(p, "root", rz=0.05 * s(t, 1, 0.25))
    look(p, 1 - pitch * 2.2)
    add(p, "head", rz=-0.05 * s(t, 1, 0.25))
    fork(p, -0.02)
    crest(p, 0.25 - pitch * 0.6)
    return p


def walk(t):
    return flight(t, WALK_S, -0.22, 0.28, 0.15)


def run(t):
    return flight(t, RUN_S, -0.46, 0.32, 0.35)


def hop(t):
    """A happy loop: a dip, a zip up, a whole spin on the spot, a bobbing settle."""
    p = {}
    air = seq(t, [(0, 0), (0.15, -0.5), (0.3, 1), (0.7, 1), (0.85, -0.3), (1, 0)])
    hover(p, t, beats(HOP_S), lift=LIFT + 0.16 * max(air, 0) - 0.06 * max(-air, 0), pitch=0.2 + 0.15 * max(air, 0))
    add(p, "root", ry=math.tau * seq(t, [(0, 0), (0.28, 0), (0.72, 1), (1, 1)]))
    look(p, 1.2)
    add(p, "head", rz=0.12 * s(t, 2))
    add(p, "tail1", rx=-0.25 * max(air, 0))
    fork(p, 0.12 * max(air, 0))
    crest(p, -0.1, 0.25 * max(air, 0))
    return p


def attack(t):
    """Rears back, then darts in beak first."""
    p = {}
    wind = seq(t, [(0, 0), (0.3, 1), (0.4, -1), (0.58, -1), (1, 0)])
    load, jab = max(wind, 0), max(-wind, 0)
    hover(p, t, beats(ATTACK_S), pitch=0.12 + 0.35 * load - 0.55 * jab, amp=0.48)
    at(p, y=0.03 * load, z=0.08 * load - 0.24 * jab)
    look(p, 1 - 0.4 * load + 0.6 * jab)
    add(p, "neck", rx=0.15 * load - 0.1 * jab)
    add(p, "tail1", rx=0.3 * load - 0.3 * jab)
    fork(p, 0.08 * load)
    crest(p, 0.4 * jab, 0.1 * load)
    return p


RING_ON = ((0.3, 0.44), (0.38, 0.52), (0.46, 0.6), (0.58, 0.72), (0.66, 0.8), (0.74, 0.88))   # ring 1, 2, 3, 1, 2, 3


def ability(t):
    """Sound Wall: rises high, sits up, and its fork rings: the prongs shiver and rings of hum pulse out."""
    p = {}
    rise = seq(t, [(0, 0), (0.24, 1), (0.88, 1), (1, 0)])
    ring = seq(t, [(0, 0), (0.28, 0), (0.32, 1), (0.84, 1), (0.9, 0), (1, 0)])
    hover(p, t, beats(ABILITY_S), lift=LIFT + 0.24 * rise, pitch=0.12 + 0.32 * rise, amp=0.38, tail=-0.25 * rise)
    at(p, y=0.01 * ring * c(t, 12))
    look(p, 1 + 0.6 * rise)
    add(p, "head", rz=0.06 * ring * s(t, 4))
    fork(p, 0.1 * rise, 0.14 * ring, t, beats(ABILITY_S))
    crest(p, -0.2 * rise, 0.15 * ring * s(t, 6))
    for i, (a, b) in enumerate(RING_ON):
        if a <= t < b:
            p["prop_ring%d" % (i % RINGS + 1)] = "on"
    return p


def sleep(t):
    """Perched on the ground, fluffed into a ball, its beak tucked into its back; wings folded, the buzz off."""
    br = s(t, 1)
    p = {"root_at": (0, -0.02, 0), "root_sc": (1.08 + br * 0.015, 0.95 + br * 0.022, 1.06 + br * 0.012)}
    add(p, "root", rx=-0.12)
    for sd, sx in SIDES:
        legs(p, sd, 0.5, 0.8)
        add(p, "wing." + sd, rx=-0.15, ry=-sx * 1.05, rz=-sx * 0.55)
    add(p, "neck", rx=-0.2, ry=0.5)
    add(p, "head", rx=-0.25 + br * 0.02, ry=0.9, rz=0.25)
    add(p, "tail1", rx=-0.05)
    crest(p, 0.5)
    return p


def eat(t):
    """Hovers low over a berry and sips it with its needle beak: three dips, a lift to swallow."""
    p = {}
    sip = seq(t, [(0, 0.2), (0.1, 1), (0.18, 0.7), (0.26, 1), (0.34, 0.7), (0.42, 1), (0.54, 0.2), (0.7, -0.4),
                  (0.86, 0), (1, 0.2)])
    dip, gulp = max(sip, 0), max(-sip, 0)
    hover(p, t, beats(EAT_S), lift=0.07 + 0.1 * gulp, pitch=-0.4 * dip + 0.15 * gulp)
    look(p, 0.3 - 0.4 * dip + 0.5 * gulp)
    add(p, "neck", rx=-0.3 * dip)
    add(p, "head", rx=-0.25 * dip, rz=0.1 * gulp)
    add(p, "tail1", rx=-0.25 * dip)
    crest(p, 0.1)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Floats into the hand, eyes shut, rolling its head against it, the buzz gone soft."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    hover(p, t, beats(PET_S), lift=0.24 + 0.02 * lean, pitch=0.2 + 0.05 * lean, amp=0.34)
    look(p, 1.2 + 0.3 * lean)
    add(p, "neck", rz=0.12 * lean)
    add(p, "head", rz=0.16 + 0.18 * lean, ry=0.1 * lean)
    add(p, "tail1", ry=0.12 * s(t, 2))
    fork(p, 0.05 * lean)
    crest(p, 0.45, 0.1)
    return p


def foot_tool(t, keys, tool):
    """A tool in its feet: rears up with the tool raised, then pitches forward and brings it down on the work."""
    p = {}
    v = seq(t, keys)
    up, down = max(v, 0), max(-v, 0)
    hover(p, t, beats(WORK_S), lift=0.18 + 0.05 * up, pitch=0.45 * up - 0.62 * down, amp=0.46)
    for sd, _ in SIDES:     # the feet hold it out in front, not tucked
        legs(p, sd, -0.3 - 0.2 * down, -0.9 + 0.3 * up)
    at(p, z=0.04 * up - 0.06 * down)
    look(p, 0.6 - 0.3 * up + 0.5 * down)
    add(p, "tail1", rx=0.25 * up - 0.3 * down)
    crest(p, 0.3 * down)
    p[tool] = "on"
    return p


def chop(t):
    return foot_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe")


def mine(t):
    return foot_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick")


def carry(t):
    """Hauls the load hanging from its feet: working hard, the body upright, a heavy bob."""
    p = {}
    hover(p, t, beats(CARRY_S), pitch=0.05, amp=0.5)
    for sd, _ in SIDES:
        legs(p, sd, -0.5, -0.9)
    at(p, y=0.02 * s(t, 1))
    look(p, 1.1)
    add(p, "tail1", rx=0.1 * s(t, 1, 0.2))
    crest(p, 0.2)
    return p


def tend(t):
    """Any other farm job: hovering low over the work, pecking at it, sidling across."""
    p = {}
    peck = max(0.0, s(t, 2))
    hover(p, t, beats(TEND_S), lift=0.16, pitch=-0.25 - 0.15 * peck)
    at(p, x=0.03 * s(t, 1), z=-0.02 * peck)
    look(p, 0.2)
    add(p, "neck", rx=-0.15 * peck)
    add(p, "head", rx=-0.25 * peck, ry=0.12 * s(t, 1))
    crest(p, 0.15)
    return p


CLIPS = {"idle": (IDLE_S, True, idle), "walk": (WALK_S, True, walk), "run": (RUN_S, True, run),
         "hop": (HOP_S, True, hop), "pet": (PET_S, True, pet), "carry": (CARRY_S, True, carry),
         "tend": (TEND_S, True, tend), "attack": (ATTACK_S, False, attack), "ability": (ABILITY_S, False, ability),
         "sleep": (SLEEP_S, True, sleep), "eat": (EAT_S, True, eat), "chop": (WORK_S, True, chop),
         "mine": (WORK_S, True, mine)}
import boki_react


def _win(p, t, a):
    buzz(p, t, 8, 0.42 * a)


def _sulk(p, t, a):
    crest(p, -0.2)


def _push(p, t, a):
    crest(p, 0.3)


CLIPS.update(boki_react.react(hop=1.0, slump=0.9, brace=0.8, extra_win=_win, extra_sulk=_sulk, extra_push=_push))
HIDE_AT = {"prop_berry": (0, -0.3, 0.47)}     # off, it waits under the ground

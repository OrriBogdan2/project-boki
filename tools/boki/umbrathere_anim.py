"""Umbrathere's skeleton and clips: a hunched two-legged ground sloth with long hanging arms and hooked claws, a heavy
tail, and an umbrella canopy on its back (bone `canopy`, scaled open in hop and Gravity Slam)."""
import boki_clips
import umbrathere as um
from boki_clips import add, s, seq
from vespyx_sides import SIDES

boki_clips.TAIL_N = 3
LOOK_UP = 0.28      # tips the face up to the high cameras
SCALED = {"canopy"}


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": (tuple(um.PELVIS), tuple(um.CHEST), "root"),
        "spine": (tuple(um.CHEST), tuple(um.NECK), "hips"),
        "neck": (tuple(um.NECK), tuple(um.HEAD_BASE), "spine"),
        "head": (tuple(um.HEAD_BASE), tuple(um.HEAD_TOP), "neck"),
        "canopy": (tuple(um.CANOPY_BASE), tuple(um.CANOPY_TOP), "spine"),
        "prop_axe": (tuple(um.GRIP), tuple(um.GRIP + um.AXIS * 0.1), "hand.R"),
        "prop_pick": (tuple(um.GRIP), tuple(um.GRIP + um.AXIS * 0.1), "hand.R"),
        "prop_berry": (tuple(um.BERRY_C), tuple(um.BERRY_C + um.v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        sh, el, wr, tip = (um.mir(p, sx) for p in um.ARM_PTS)
        b["arm1." + sd] = (sh, el, "spine")
        b["arm2." + sd] = (el, wr, "arm1." + sd)
        b["hand." + sd] = (wr, tip, "arm2." + sd)
        hip, knee, ankle, toe = (um.mir(p, sx) for p in um.LEG_PTS)
        b["hleg1." + sd] = (hip, knee, "root")
        b["hleg2." + sd] = (knee, ankle, "hleg1." + sd)
        b["hpaw." + sd] = (ankle, toe, "hleg2." + sd)
    parent = "hips"
    for i in range(len(um.TAIL_PTS) - 1):
        name = "tail%d" % (i + 1)
        b[name] = (tuple(um.TAIL_PTS[i]), tuple(um.TAIL_PTS[i + 1]), parent)
        parent = name
    b.update(boki_clips.part_bones(um.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- helpers
def look(p, k=1.0):
    add(p, "neck", rx=LOOK_UP * k * 0.4)
    add(p, "head", rx=LOOK_UP * k * 0.6)


def arm(p, sd, sx, swing=0.0, out=0.0, bend=0.0, curl=0.0):
    """One arm: `swing` forward from the shoulder, `out` away from the body, `bend` folds the elbow forward, `curl`
    hooks the claws in."""
    add(p, "arm1." + sd, rx=swing, rz=sx * out)
    add(p, "arm2." + sd, rx=bend)
    add(p, "hand." + sd, rx=curl)


def arms(p, swing=0.0, out=0.0, bend=0.0, curl=0.0):
    for sd, sx in SIDES:
        arm(p, sd, sx, swing, out, bend, curl)


def leg(p, sd, swing=0.0, lift=0.0):
    """One leg: `swing` forward from the hip, `lift` folds the knee and lifts the foot."""
    add(p, "hleg1." + sd, rx=swing + lift * 0.6)
    add(p, "hleg2." + sd, rx=-lift * 1.2)
    add(p, "hpaw." + sd, rx=lift * 0.6 - swing)


def tail(p, t, amp, up=0.0):
    boki_clips.tail_wave(p, t, amp, up=up, roll=amp * 1.4, lag=0.12)


def canopy(p, open_=0.0, sway=0.0):
    """`open_` spreads the umbrella wide and flat (1 is fully open), `sway` rocks it side to side."""
    p["canopy_sc"] = (1 + 0.3 * open_, 1 - 0.08 * open_, 1 + 0.3 * open_)
    add(p, "canopy", rx=-0.12 * open_, rz=sway)


def plod(t, stride, bob, lean, arm_k):
    """The sloth's heavy two-legged walk: the body rolls over each planted foot, the arms swing low and late."""
    p = {}
    for sd, sx in SIDES:
        ph = 0.0 if sd == "L" else 0.5
        leg(p, sd, s(t, 1, ph) * stride, max(0.0, s(t, 1, ph + 0.25)) * stride * 1.2)
        arm(p, sd, sx, -s(t, 1, ph + 0.08) * stride * arm_k, 0.06, 0.1, 0.1)
    p["root_at"] = (0, abs(s(t, 1, 0.25)) * bob - bob, 0)
    add(p, "root", rz=s(t, 1) * 0.07, ry=s(t, 1) * 0.05)
    add(p, "hips", rx=-lean)
    add(p, "spine", rx=-lean * 0.5, rz=-s(t, 1, 0.1) * 0.04)
    look(p, 1.0 + lean)
    add(p, "head", rz=-s(t, 1, 0.2) * 0.05)
    canopy(p, 0.0, -s(t, 1, 0.2) * 0.06)
    tail(p, t, 0.08, up=0.1)
    return p


# ---------------------------------------------------------------- clips
def idle(t):
    """Stands brooding: slow deep breaths under the canopy, the claws swaying, a slow look round, a heavy sigh."""
    p = {}
    br = s(t, 2)
    sigh = seq(t, [(0, 0), (0.6, 0), (0.7, 1), (0.8, 1), (0.9, 0), (1, 0)])
    p["root_sc"] = (1 + br * 0.012 + 0.02 * sigh, 1 + br * 0.01, 1 + br * 0.012)
    p["root_at"] = (0, -0.01 * sigh, 0)
    add(p, "spine", rx=0.03 * br - 0.08 * sigh)
    turn = seq(t, [(0, 0), (0.15, 0), (0.25, 0.5), (0.4, 0.5), (0.5, 0), (1, 0)])
    look(p, 1.0 - 0.6 * sigh)
    add(p, "neck", ry=turn * 0.3)
    add(p, "head", ry=turn * 0.35, rz=turn * 0.12)
    arms(p, s(t, 1) * 0.04, 0.04, 0.08, 0.1 + 0.05 * s(t, 2, 0.3))
    canopy(p, 0.02 * br, s(t, 1, 0.3) * 0.03)
    tail(p, t * 2, 0.03)
    return p


def walk(t):
    return plod(t, 0.42, 0.016, 0.04, 0.5)


def run(t):
    """A lumbering charge: leaning forward, long strides, the claws swinging wide, the canopy bouncing."""
    p = plod(t, 0.7, 0.04, 0.28, 0.9)
    add(p, "canopy", rx=s(t, 2) * 0.08)
    return p


def attack(t):
    """A two-handed rake: rears back with both claws up, then sweeps them down and across in front of it."""
    p = {}
    v = seq(t, [(0, 0), (0.3, -1), (0.42, -1.05), (0.55, 1), (0.7, 0.9), (1, 0)])
    up, rake = max(-v, 0), max(v, 0)
    p["root_at"] = (0, 0.02 * up - 0.02 * rake, 0.04 * up - 0.1 * rake)
    add(p, "hips", rx=0.12 * up - 0.2 * rake)
    add(p, "spine", rx=0.1 * up - 0.25 * rake)
    look(p, 1.0 + 0.5 * rake)
    arms(p, 2.3 * up + 0.6 * rake, 0.3 * up - 0.1 * rake, 0.5 * up, 0.3 * up + 0.8 * rake)
    for sd, _ in SIDES:
        leg(p, sd, -0.1 * up + 0.15 * rake if sd == "L" else 0.1 * up - 0.2 * rake)
    canopy(p, 0.1 * up)
    tail(p, t, 0.05, up=0.2 * up)
    return p


def slam(t):
    """Gravity Slam: heaves both arms overhead with the canopy flaring open, hangs, and brings both claws down onto
    the ground; the body squashes on the impact and the canopy shudders."""
    p = {}
    rise = seq(t, [(0, 0), (0.3, 1), (0.42, 1.05), (0.52, 0), (1, 0)])
    hit = seq(t, [(0.48, 0), (0.54, 1), (0.75, 0.8), (1, 0)])
    p["root_at"] = (0, 0.04 * rise - 0.06 * hit, 0.03 * rise - 0.06 * hit)
    p["root_sc"] = (1 + 0.08 * hit, 1 - 0.1 * hit, 1 + 0.06 * hit)
    add(p, "hips", rx=0.15 * rise - 0.35 * hit)
    add(p, "spine", rx=0.15 * rise - 0.4 * hit)
    look(p, 1.0 - 0.3 * rise + 0.4 * hit)
    arms(p, 2.8 * rise + 0.9 * hit, 0.15 * rise, 0.3 * rise, 0.4 * rise + 0.6 * hit)
    for sd, _ in SIDES:
        leg(p, sd, 0.3 * hit, 0.25 * hit)
    canopy(p, rise + 0.6 * hit, 0.05 * hit * s(t, 10))
    tail(p, t, 0.06, up=-0.2 * hit)
    return p


def hop(t):
    """Happy: a heavy little bounce on both feet, arms flung up, the canopy popping open at the top."""
    p = {}
    air = seq(t, [(0, 0), (0.2, -0.6), (0.32, 0.2), (0.48, 1), (0.64, 0.2), (0.76, -0.5), (1, 0)])
    up, down = max(air, 0), max(-air, 0)
    p["root_at"] = (0, 0.12 * up - 0.05 * down, 0)
    p["root_sc"] = (1 + 0.08 * down - 0.03 * up, 1 - 0.1 * down + 0.06 * up, 1 + 0.05 * down)
    look(p, 1.0 + 0.4 * up)
    arms(p, 1.6 * up + 0.2 * down, 0.4 * up, 0.2 * up, 0.2)
    for sd, _ in SIDES:
        leg(p, sd, 0.1 * up, 0.4 * up + 0.3 * down)
    canopy(p, 0.8 * up)
    tail(p, t, 0.08, up=0.3 * up - 0.2 * down)
    return p


def sleep(t):
    """Sits down on its haunches and tail with the canopy folded low over it like a shell, arms hugging its belly."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, um.SIT_DROP, 0.02)
    p["root_sc"] = (1 + br * 0.015, 1 + br * 0.02, 1)
    add(p, "hips", rx=-0.1)
    add(p, "spine", rx=-0.3 + br * 0.02)
    add(p, "neck", rx=-0.3)
    add(p, "head", rx=-0.25 + br * 0.02, rz=0.12)
    arms(p, 0.45, -0.55, 1.2, 0.5)
    for sd, sx in SIDES:
        add(p, "hleg1." + sd, rx=1.3, rz=sx * 0.25)
        add(p, "hleg2." + sd, rx=-1.2)
        add(p, "hpaw." + sd, rx=-0.1)
    canopy(p, -0.15)
    add(p, "canopy", rx=-0.2)
    for i in range(boki_clips.TAIL_N):
        add(p, "tail%d" % (i + 1), ry=-0.25)
    return p


def eat(t):
    """A berry on the ground: bends at the hips, hooks it with a claw, nibbles three times and chews."""
    p = {}
    chomp = 0.5 + 0.5 * s(t, 3)
    add(p, "hips", rx=-0.35)
    add(p, "spine", rx=-0.3)
    add(p, "neck", rx=-0.2)
    add(p, "head", rx=-0.2 - chomp * 0.1)
    p["root_at"] = (0, -0.03, 0)
    arm(p, "R", 1.0, 0.7 + 0.08 * chomp, 0.0, 0.5, 0.4)
    arm(p, "L", -1.0, 0.3, 0.05, 0.2, 0.2)
    for sd, _ in SIDES:
        leg(p, sd, 0.2, 0.15)
    canopy(p, 0.0, 0.02 * s(t, 1))
    tail(p, t * 2, 0.03)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans its big head into the hand, eyes shut, the canopy lowered over the both of you, the tail swaying."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    look(p, 0.6)
    add(p, "neck", rz=lean * 0.12)
    add(p, "head", rz=0.12 + lean * 0.18, ry=lean * 0.1)
    add(p, "spine", rx=-0.06)
    arms(p, 0.1, 0.0, 0.2, 0.15)
    canopy(p, 0.25, 0.04 * lean)
    tail(p, t * 3, 0.05)
    return p


def tool(t, keys, name):
    """A tool in the right hand: lifted high over the shoulder, then brought down with its whole weight."""
    p = {}
    v = seq(t, keys)
    up, down = max(v, 0), max(-v, 0)
    add(p, "hips", rx=-0.1 * down)
    add(p, "spine", rx=0.1 * up - 0.3 * down)
    look(p, 0.7)
    arm(p, "R", 1.0, 2.4 * up + 0.7 * down, 0.1, 0.4 * up, 0.0)
    arm(p, "L", -1.0, 0.3 * down, 0.05, 0.3, 0.2)
    p["root_at"] = (0, -0.015 * down, 0)
    canopy(p, 0.0, 0.05 * down)
    tail(p, t, 0.04)
    p[name] = "on"
    return p


def chop(t):
    return tool(t, [(0, 0), (0.4, 1), (0.52, -1), (0.62, -0.8), (1, 0)], "prop_axe")


def mine(t):
    return tool(t, [(0, 0), (0.36, 1), (0.48, -1), (0.56, -0.7), (1, 0)], "prop_pick")


def carry(t):
    """Plods with the load hugged to its chest in both arms (BokiRig.CARRY_AT)."""
    p = plod(t, 0.36, 0.012, -0.04, 0.0)
    arms(p, 0.9, -0.12, 0.9, 0.4)
    return p


def tend(t):
    """Any other farm job: bent over the work, raking at it with one claw then the other."""
    p = {}
    bob = s(t, 2)
    add(p, "hips", rx=-0.3)
    add(p, "spine", rx=-0.2 + bob * 0.03)
    look(p, 0.4)
    add(p, "head", ry=s(t, 1) * 0.1)
    p["root_at"] = (0, -0.02, 0)
    for sd, sx in SIDES:
        ph = 0.0 if sd == "L" else 0.5
        arm(p, sd, sx, 0.6 + 0.35 * max(0.0, s(t, 2, ph)), 0.05, 0.3, 0.3 + 0.4 * max(0.0, s(t, 2, ph)))
        leg(p, sd, 0.15, 0.1)
    canopy(p, 0.0, 0.03 * bob)
    tail(p, t * 2, 0.03)
    return p


CLIPS = {"idle": (3.2, True, idle), "walk": (1.0, True, walk), "run": (0.6, True, run), "attack": (0.9, False, attack),
         "ability": (1.2, False, slam), "hop": (1.0, True, hop), "sleep": (3.6, True, sleep), "eat": (2.0, True, eat),
         "pet": (2.4, True, pet), "chop": (1.1, True, chop), "mine": (1.0, True, mine), "carry": (1.0, True, carry),
         "tend": (1.4, True, tend)}
HIDE_AT = {"prop_berry": (0, 0.2, 0.36)}

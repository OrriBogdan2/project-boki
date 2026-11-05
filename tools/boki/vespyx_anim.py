"""Vespyx's skeleton and clips. A clip is a function of t (0..1) returning bone -> (rx, ry, rz) in the creature's own
axes: rx lifts the nose (or lifts a limb forward), ry turns it toward its right (-z towards +x is negative), rz rolls.
Keys: "root_at" / "hips_at" (metres), "root_sc" (squash), and prop bones set to "on"."""
import math

import vespyx
from vespyx import SIDES, STING_C, TAIL_PTS

TAU = math.tau


def p3(x, y, z):
    return (x, y, z)


def _bones():
    b = {
        "root": (p3(0, 0, 0), p3(0, 0.12, 0), None),
        "hips": (p3(0, 0.24, 0.11), p3(0, 0.25, 0.0), "root"),
        "spine": (p3(0, 0.25, 0.0), p3(0, 0.28, -0.08), "hips"),
        "neck": (p3(0, 0.30, -0.06), p3(0, 0.40, -0.10), "spine"),
        "head": (p3(0, 0.40, -0.10), p3(0, 0.56, -0.13), "neck"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = (p3(sx * 0.118, 0.60, -0.105), p3(sx * 0.178, 0.745, -0.095), "head")
        b["ear2." + sd] = (p3(sx * 0.178, 0.745, -0.095), p3(sx * 0.235, 0.905, -0.085), "ear1." + sd)
        b["fleg1." + sd] = (p3(sx * 0.082, 0.235, -0.075), p3(sx * 0.090, 0.125, -0.080), "spine")
        b["fleg2." + sd] = (p3(sx * 0.090, 0.125, -0.080), p3(sx * 0.094, 0.040, -0.084), "fleg1." + sd)
        b["fpaw." + sd] = (p3(sx * 0.094, 0.040, -0.084), p3(sx * 0.096, 0.020, -0.16), "fleg2." + sd)
        b["hleg1." + sd] = (p3(sx * 0.095, 0.215, 0.195), p3(sx * 0.108, 0.115, 0.175), "hips")
        b["hleg2." + sd] = (p3(sx * 0.108, 0.115, 0.175), p3(sx * 0.108, 0.040, 0.205), "hleg1." + sd)
        b["hpaw." + sd] = (p3(sx * 0.108, 0.040, 0.205), p3(sx * 0.110, 0.020, 0.13), "hleg2." + sd)
        b["arm." + sd] = (p3(sx * 0.070, 0.250, -0.130), p3(sx * 0.118, 0.232, -0.195), "spine")
        b["claw." + sd] = (p3(sx * 0.118, 0.232, -0.195), p3(sx * 0.14, 0.235, -0.33), "arm." + sd)
        b["nip." + sd] = (p3(sx * 0.102, 0.230, -0.285), p3(sx * 0.092, 0.234, -0.335), "claw." + sd)
    parent = "hips"
    for i in range(7):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL_PTS[i]), tuple(TAIL_PTS[i + 1]), parent)
        parent = n
    b["sting"] = (tuple(TAIL_PTS[7]), tuple(STING_C + (STING_C - TAIL_PTS[7])), "tail7")
    b["prop_axe"] = (tuple(STING_C), tuple(STING_C + vespyx.AXIS * 0.1), "sting")
    b["prop_pick"] = (tuple(STING_C), tuple(STING_C + vespyx.AXIS * 0.1), "sting")
    b["prop_log"] = (p3(0, 0.30, -0.30), p3(0, 0.40, -0.30), "spine")
    b["prop_berry"] = (p3(-0.095, 0.30, -0.335), p3(-0.095, 0.40, -0.335), "claw.L")
    return b


BONES = _bones()
LEGS = [s + "." + d for s in ("fleg1", "hleg1") for d in "LR"]


def s(t, n=1.0, ph=0.0):
    return math.sin(TAU * (n * t + ph))


def c(t, n=1.0, ph=0.0):
    return math.cos(TAU * (n * t + ph))


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def seq(t, keys):
    """keys: (t, value), eased between. Values may be numbers."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            k = ease((t - t0) / max(t1 - t0, 1e-6))
            return v0 + (v1 - v0) * k
    return keys[-1][1]


def add(pose, bone, rx=0.0, ry=0.0, rz=0.0):
    o = pose.get(bone, (0, 0, 0))
    pose[bone] = (o[0] + rx, o[1] + ry, o[2] + rz)


def tail_wave(pose, phase, amp, up=0.0, side=0.0, roll=0.0, lag=0.09):
    """Sends a wave down the tail: each plate repeats the one before, a little late (follow-through)."""
    for i in range(7):
        k = 0.45 + 0.55 * i / 6
        add(pose, "tail%d" % (i + 1), rx=up / 7 + amp * math.sin(TAU * (phase - i * lag)) * k,
            ry=side / 7 + roll * math.sin(TAU * (phase - i * lag - 0.15)) * k)


def ear_pose(pose, back=0.0, out=0.0, flick=0.0):
    for sd, sx in SIDES:
        add(pose, "ear1." + sd, rx=-back, rz=-sx * out + (flick if sd == "R" else 0))
        add(pose, "ear2." + sd, rx=-back * 0.6)


def idle(t):
    p = {}
    br = s(t, 2)
    add(p, "spine", rx=br * 0.02)
    add(p, "neck", rx=-br * 0.01, ry=s(t, 1) * 0.05, rz=s(t, 1, 0.2) * 0.02)
    add(p, "head", rx=br * 0.03, ry=s(t, 1, 0.1) * 0.08, rz=s(t, 1, 0.3) * 0.04)
    p["root_at"] = (0, -0.006 + br * 0.004, 0)
    tw = seq(t, [(0, 0), (0.7, 0), (0.74, 1), (0.8, 0), (0.84, 1), (0.9, 0), (1, 0)])
    ear_pose(p, back=0.02 + br * 0.015, flick=tw * 0.22)
    tail_wave(p, t * 2, 0.022, roll=0.04)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=br * 0.04)
        add(p, "nip." + sd, ry=sx * seq(t, [(0, 0), (0.3, 0), (0.34, 0.5), (0.38, 0), (0.42, 0.5), (0.46, 0), (1, 0)]))
    for leg, sgn in (("fleg1.L", 1), ("fleg1.R", 1), ("hleg1.L", 1), ("hleg1.R", 1)):
        add(p, leg, rx=br * 0.012 * sgn)
    return p


def trot(t, swing, bob, tail_up, pitch):
    p = {}
    # diagonal pairs
    phases = {"fleg1.L": 0.0, "hleg1.R": 0.0, "fleg1.R": 0.5, "hleg1.L": 0.5}
    for leg, ph in phases.items():
        a = s(t, 1, ph)
        add(p, leg, rx=a * swing)
        low = leg.replace("1.", "2.")
        add(p, low, rx=-max(0.0, -c(t, 1, ph)) * swing * 1.2 if leg[0] == "f" else max(0.0, -c(t, 1, ph)) * swing * 1.2)
        paw = leg.replace("leg1.", "paw.")
        add(p, paw, rx=-a * swing * 0.5)
    p["root_at"] = (0, abs(c(t, 1)) * bob - bob * 0.3, 0)
    add(p, "root", rz=s(t, 1) * 0.035, ry=s(t, 1) * 0.04)
    add(p, "spine", rx=-pitch)
    add(p, "neck", rx=pitch * 0.6 + c(t, 2) * 0.03)
    add(p, "head", rx=pitch * 0.4 + c(t, 2, 0.1) * 0.04, ry=-s(t, 1) * 0.04)
    ear_pose(p, back=0.14, out=0.03)
    tail_wave(p, t * 2, 0.05, up=tail_up, roll=0.06)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=-s(t, 1, 0.5 if sd == "L" else 0) * 0.12)
    return p


def walk(t):
    return trot(t, 0.5, 0.012, 0.0, 0.0)


def run(t):
    """A bounding gallop: the spine bunches and stretches, ears pinned, tail streaming back."""
    p = {}
    fr = s(t, 1, 0.0)
    hi = s(t, 1, 0.5)
    for sd, sx in SIDES:
        off = 0.05 if sd == "R" else 0.0
        a = s(t, 1, off)
        b = s(t, 1, 0.42 + off)
        add(p, "fleg1." + sd, rx=a * 0.95)
        add(p, "fleg2." + sd, rx=-max(0.0, -c(t, 1, off)) * 0.9)
        add(p, "fpaw." + sd, rx=-a * 0.45)
        add(p, "hleg1." + sd, rx=b * 0.85)
        add(p, "hleg2." + sd, rx=max(0.0, -c(t, 1, 0.42 + off)) * 0.8)
        add(p, "hpaw." + sd, rx=-b * 0.4)
        add(p, "arm." + sd, rx=-0.25, rz=-sx * 0.2)
    p["root_at"] = (0, 0.012 + 0.05 * max(0.0, s(t, 1, 0.2)), 0)
    add(p, "hips", rx=fr * 0.2)
    add(p, "spine", rx=-fr * 0.34)
    add(p, "root", rx=fr * 0.08)
    add(p, "neck", rx=fr * 0.2 - 0.12)
    add(p, "head", rx=fr * 0.14 - 0.04)
    ear_pose(p, back=0.62 + fr * 0.08, out=0.08)
    tail_wave(p, t, 0.09, up=0.95, roll=0.03, lag=0.07)
    return p


def attack(t):
    """A pounce with both pincers: rear back, snap forward, settle."""
    p = {}
    wind = seq(t, [(0, 0), (0.28, 1), (0.36, -0.9), (0.52, -1.0), (1, 0)])
    add(p, "spine", rx=wind * 0.3)
    add(p, "hips", rx=wind * 0.1)
    p["root_at"] = (0, -0.05 * max(wind, 0) + 0.02 * max(-wind, 0), 0.10 * wind)
    add(p, "neck", rx=-wind * 0.18)
    add(p, "head", rx=-wind * 0.12)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=wind * 0.8, ry=-sx * wind * 0.5)
        add(p, "claw." + sd, rx=wind * 0.3, ry=sx * 0.5 * max(wind, 0))
        gap = seq(t, [(0, 0.2), (0.28, 0.9), (0.38, 0), (0.6, 0), (1, 0.15)])
        add(p, "nip." + sd, ry=sx * gap)
        add(p, "fleg1." + sd, rx=-wind * 0.34)
        add(p, "hleg1." + sd, rx=wind * 0.25)
        add(p, "hleg2." + sd, rx=-max(wind, 0) * 0.4)
    ear_pose(p, back=0.32 + max(wind, 0) * 0.4)
    tail_wave(p, t * 2, 0.04, up=wind * 0.22)
    return p


def ability(t):
    """Stinger strike: the tail cocks back, whips over the head and stabs, a venom flick, then recoils."""
    p = {}
    cock = seq(t, [(0, 0), (0.32, 1), (0.40, -1), (0.56, -1.1), (0.8, -0.1), (1, 0)])
    n = 7
    for i in range(n):
        k = 0.5 + 0.5 * i / (n - 1)
        lag = 0.012 * i
        v = seq(t - lag, [(0, 0), (0.32, 1), (0.40, -1), (0.56, -1.1), (0.8, -0.1), (1, 0)])
        add(p, "tail%d" % (i + 1), rx=v * 0.30 * k if v > 0 else v * 0.33 * k)
    add(p, "sting", rx=-max(0, -cock) * 0.4)
    crouch = seq(t, [(0, 0), (0.32, 0.7), (0.42, 1), (0.6, 1), (1, 0)])
    p["root_at"] = (0, -0.045 * crouch, 0.05 * max(cock, 0) - 0.05 * max(-cock, 0))
    add(p, "spine", rx=-0.12 * crouch + cock * 0.08)
    add(p, "hips", rx=0.12 * crouch)
    add(p, "neck", rx=-0.18 * max(-cock, 0))
    add(p, "head", rx=-0.28 * max(-cock, 0) + 0.1 * max(cock, 0))
    ear_pose(p, back=0.55 * crouch)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=-0.3 * crouch, rz=-sx * 0.3 * crouch)
        add(p, "fleg1." + sd, rx=0.12 * crouch)
    return p


def hop(t):
    """A happy hop: down, up with the legs tucked and a spin of the tail, a soft landing."""
    p = {}
    air = seq(t, [(0, 0), (0.18, -0.55), (0.3, 0.2), (0.48, 1), (0.66, 0.2), (0.76, -0.45), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p["root_at"] = (0, 0.30 * up - 0.08 * down, 0)
    p["root_sc"] = (1 + 0.14 * down - 0.05 * up, 1 - 0.20 * down + 0.10 * up, 1 + 0.06 * down)
    add(p, "root", rx=0.22 * (seq(t, [(0.2, 0), (0.4, 1), (0.6, -0.8), (0.75, 0)])))
    add(p, "head", rx=0.22 * up - 0.14 * down, rz=s(t, 2) * 0.1)
    add(p, "neck", rx=0.08 * up)
    ear_pose(p, back=-0.2 * up + 0.5 * down + 0.2, out=0.26 * down)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-0.7 * up + 0.3 * down)
        add(p, "fleg2." + sd, rx=-0.9 * up - 0.5 * down)
        add(p, "hleg1." + sd, rx=0.7 * up - 0.3 * down)
        add(p, "hleg2." + sd, rx=0.9 * up + 0.5 * down)
        add(p, "arm." + sd, rx=0.8 * up, rz=sx * 0.6 * up)
        add(p, "nip." + sd, ry=sx * up * 0.5)
    tail_wave(p, t, 0.09, up=0.15 * up - 0.3 * down, roll=0.12, lag=0.05)
    return p


def curled(t, br):
    """Lying down: legs folded under, head on its side on the forepaws, tail wrapped round."""
    p = {}
    p["root_at"] = (0, -0.125, 0)
    add(p, "hips", rx=-0.06, rz=0.28)
    add(p, "spine", rx=0.12, ry=-0.45 + br * 0.008)
    add(p, "neck", rx=-0.32, ry=-0.45)
    add(p, "head", rx=-0.46 + br * 0.03, ry=-0.3, rz=-0.3)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.25)
        add(p, "fleg2." + sd, rx=-2.0)
        add(p, "fpaw." + sd, rx=0.5)
        add(p, "hleg1." + sd, rx=-0.9)
        add(p, "hleg2." + sd, rx=1.55)
        add(p, "hpaw." + sd, rx=-0.5)
        add(p, "arm." + sd, rx=-0.75, rz=-sx * 0.15)
    ear_pose(p, back=0.72, out=0.3)
    for i in range(7):
        add(p, "tail%d" % (i + 1), rx=-0.46 + i * 0.03, ry=0.42)
    add(p, "sting", rx=-0.2)
    return p


def sleep(t):
    br = s(t, 1)
    p = curled(t, br)
    add(p, "hips", rz=br * 0.012)
    p["root_sc"] = (1 + br * 0.018, 1 + br * 0.03, 1)
    return p


def eat(t):
    """Holds a berry in its left pincer and nibbles: to the mouth, three chomps, then a pleased chew."""
    p = idle(t)
    lift = seq(t, [(0, 0.8), (0.12, 1), (0.88, 1), (1, 0.8)])
    chomp = (0.5 + 0.5 * s(t, 3)) * lift
    add(p, "head", rx=-0.26 + chomp * 0.10)
    add(p, "neck", rx=-0.06 - chomp * 0.05)
    add(p, "arm.L", rx=0.85 * lift, rz=0.3 * lift, ry=-0.35 * lift)
    add(p, "arm.R", rx=0.52 * lift, ry=0.32 * lift)
    add(p, "claw.L", rx=0.5 * lift, ry=-0.5)
    ear_pose(p, back=0.14 - chomp * 0.1)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans up into a hand, eyes shut: a slow push of the head, ears flat, the tail wagging."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    add(p, "neck", rx=0.22 + lean * 0.1, rz=lean * 0.12)
    add(p, "head", rx=0.2 + lean * 0.12, rz=0.1 + lean * 0.16, ry=lean * 0.08)
    ear_pose(p, back=0.6 - lean * 0.15, out=0.5)
    add(p, "spine", rx=0.05)
    p["root_at"] = (0, 0.012 * lean, 0)
    for i in range(7):
        k = 0.4 + 0.6 * i / 6
        add(p, "tail%d" % (i + 1), ry=0.17 * k * math.sin(TAU * (3 * t - i * 0.06)), rx=-0.02)
    for sd, sx in SIDES:
        add(p, "hleg1." + sd, rx=0.07)
        add(p, "fleg1." + sd, rx=-0.06)
    return p


def chop(t):
    """Holds a hatchet in its tail and swings it flat at the trunk, the whole body twisting behind it."""
    p = {}
    v = seq(t, [(0, 0), (0.42, 1), (0.54, -1), (0.66, -1), (1, 0)])
    twist = v * 0.46
    add(p, "root", ry=twist * 0.3)
    add(p, "hips", ry=twist * 0.45)
    add(p, "spine", ry=-twist * 0.2)
    add(p, "neck", ry=-twist * 0.3)
    add(p, "head", ry=-twist * 0.3, rx=-0.1)
    # tail swung forward past the shoulder, then whipped across
    for i in range(7):
        lag = 0.016 * i
        w = seq(t - lag, [(0, 0), (0.42, 1), (0.54, -1), (0.66, -1), (1, 0)])
        add(p, "tail%d" % (i + 1), rx=-0.20, ry=w * 0.26)
    add(p, "sting", rx=-0.3)
    for sd, sx in SIDES:
        add(p, "hleg1." + sd, rx=0.1 * v * sx)
        add(p, "fleg1." + sd, rx=-0.1 * v * sx)
    ear_pose(p, back=0.28)
    p["root_at"] = (0, -0.018 * abs(v), 0)
    p["prop_axe"] = "on"
    return p


def mine(t):
    """Raises a pick on its tail and brings it down over its head into the rock, recoiling from each hit."""
    p = {}
    v = seq(t, [(0, 0), (0.40, 1), (0.52, -1), (0.60, -0.8), (1, 0)])
    for i in range(7):
        lag = 0.012 * i
        w = seq(t - lag, [(0, 0), (0.40, 1), (0.52, -1), (0.60, -0.8), (1, 0)])
        k = 0.5 + 0.5 * i / 6
        add(p, "tail%d" % (i + 1), rx=(w * 0.30 if w > 0 else w * 0.20) * k - 0.02)
    add(p, "sting", rx=-max(0, -v) * 0.6)
    add(p, "spine", rx=-0.10 * max(0, -v) + 0.1 * max(0, v))
    add(p, "neck", rx=-0.14 * max(0, -v))
    add(p, "head", rx=-0.12 * max(0, -v) + 0.1 * max(0, v))
    p["root_at"] = (0, -0.032 * max(0, -v), 0.03 * max(0, v))
    ear_pose(p, back=0.2 + 0.3 * max(0, -v))
    p["prop_pick"] = "on"
    return p


def carry(t):
    """Trots with a log hugged in both pincers, the head up and leaning back from the weight."""
    p = trot(t, 0.42, 0.010, -0.14, -0.05)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=0.6, rz=-sx * 0.08)
        add(p, "claw." + sd, rx=0.25, ry=sx * 0.25)
    add(p, "neck", rx=0.1)
    add(p, "head", rx=0.1)
    p["prop_log"] = "on"
    return p


CLIPS = {
    "idle": (2.8, True, idle),
    "walk": (0.7, True, walk),
    "run": (0.44, True, run),
    "attack": (0.8, False, attack),
    "ability": (1.1, False, ability),
    "hop": (0.95, True, hop),
    "sleep": (3.4, True, sleep),
    "eat": (2.0, True, eat),
    "pet": (2.2, True, pet),
    "chop": (1.1, True, chop),
    "mine": (1.0, True, mine),
    "carry": (0.8, True, carry),
}

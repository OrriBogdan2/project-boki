"""Hivara's skeleton and clips: a bee's buzzing wings, a mantis's blades and a little swarm that never stops circling."""
import math

import boki_clips
import hivara
from boki_clips import LOOK_UP, SHARED, add, ear_pose, flop, idle, s, seq, tail_wave, trot
from hivara import ANT_PTS, BEES, BLADE, SIDES, SWARM_C, TAIL_PTS, WINGS, mirror

boki_clips.TAIL_N = 2
boki_clips.DROP = -0.075
FPS = 30


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.27, 0.17), (0, 0.27, 0.0), "root"),
        "spine": ((0, 0.27, 0.0), (0, 0.29, -0.08), "hips"),
        "neck": ((0, 0.29, -0.08), (0, 0.36, -0.13), "spine"),
        "head": ((0, 0.36, -0.13), (0, 0.52, -0.17), "neck"),
        "tail1": (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips"),
        "tail2": (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1"),
    }
    for sd, sx in SIDES:
        ant = [tuple(mirror(p, sx)) for p in ANT_PTS]
        b["ear1." + sd] = (ant[0], ant[1], "head")
        b["ear2." + sd] = (ant[1], ant[2], "ear1." + sd)
        for i, (root, tip, _) in enumerate(WINGS):
            b["wing%d.%s" % (i + 1, sd)] = (tuple(mirror(root, sx)), tuple(mirror(tip, sx)), "spine")
        sh, el, tip = [tuple(mirror(p, sx)) for p in BLADE]
        b["arm." + sd] = (sh, el, "spine")
        b["claw." + sd] = (el, tip, "arm." + sd)
        for leg, z, par in (("f", -0.04, "spine"), ("h", 0.12, "hips")):
            b["%sleg1.%s" % (leg, sd)] = ((sx * 0.09, 0.18, z), (sx * 0.155, 0.115, z - 0.01), par)
            b["%sleg2.%s" % (leg, sd)] = ((sx * 0.155, 0.115, z - 0.01), (sx * 0.165, 0.035, z - 0.015),
                                          "%sleg1.%s" % (leg, sd))
            b["%spaw.%s" % (leg, sd)] = ((sx * 0.165, 0.035, z - 0.015), (sx * 0.17, 0.02, z - 0.08), "%sleg2.%s" % (leg, sd))
    for i in range(len(BEES)):
        b["bee%d" % (i + 1)] = (tuple(SWARM_C), tuple(SWARM_C + hivara.v3(0, 0.1, 0)), "root")
    b["prop_pick"] = (tuple(hivara.GRIP), tuple(hivara.GRIP + hivara.AXIS * 0.1), "claw.R")
    b["prop_berry"] = (tuple(hivara.BERRY_C), tuple(hivara.BERRY_C + hivara.v3(0, 0.1, 0)), "claw.R")
    b.update(boki_clips.part_bones(hivara.grown_parts()))
    return b


BONES = _bones()
TILT = ((0.16, 0.0), (-0.2, 0.12), (0.06, -0.18))      # each bee's orbit, tipped (rx, rz) so the paths cross


def buzz(t, frames):
    """A wingbeat three frames long: fast enough to blur, slow enough to read at any frame rate."""
    return s(t, max(1, round(frames / 3)))


def hive(fn, seconds, wing=0.2, turns=1, rest=0.0):
    """A clip with the wings buzzing (`wing` rad, `rest` folded back) and the swarm circling `turns` times."""
    frames = round(seconds * FPS)

    def clip(t):
        p = fn(t)
        bz = buzz(t, frames)
        for sd, sx in SIDES:
            add(p, "wing1." + sd, rz=sx * (wing * bz + 0.1), ry=sx * 0.2 * rest)
            add(p, "wing2." + sd, rz=-sx * wing * bz, ry=sx * 0.2 * rest)
        for i, (rx, rz) in enumerate(TILT):
            way = -1 if i == 1 else 1
            add(p, "bee%d" % (i + 1), ry=way * math.tau * turns * t, rx=rx + 0.06 * s(t, 2 * turns, i * 0.3),
                rz=rz + 0.05 * s(t, 3, i * 0.2))
        return p
    return clip


def run(t):
    """A skitter: legs a blur, body low, wings working to help it along."""
    p = trot(t, 0.75, 0.03, 0.15, 0.1)
    ear_pose(p, back=0.5)
    return p


def mantis_strike(t):
    """Rears with both blades cocked open, then snaps them shut on the target in a lunge, and settles."""
    p = {}
    wind = seq(t, [(0, 0), (0.3, 1), (0.38, -1), (0.56, -1), (1, 0)])
    up = max(wind, 0.0)
    out = max(-wind, 0.0)
    p["root_at"] = (0, -0.03 * up + 0.02 * out, 0.06 * up - 0.16 * out)
    add(p, "root", rx=0.25 * up - 0.08 * out)
    add(p, "spine", rx=0.1 * up)
    add(p, "head", rx=LOOK_UP * 0.4 - 0.1 * up + 0.08 * out)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=0.9 * up + 0.5 * out, ry=-sx * 0.25 * up)
        add(p, "claw." + sd, rx=1.9 * up + 0.5 * out)
        add(p, "fleg1." + sd, rx=-wind * 0.3)
        add(p, "hleg1." + sd, rx=wind * 0.3)
    ear_pose(p, back=0.4 + 0.3 * up, out=0.2)
    tail_wave(p, t * 2, 0.06, up=0.2 * up)
    return p


def ability(t):
    """Hive swarm: buzzes up to a roar with its blades raised, then flings them wide and looses the swarm ahead."""
    p = {}
    gather = seq(t, [(0, 0), (0.32, 1), (0.4, 0), (1, 0)])
    loose = seq(t, [(0, 0), (0.34, 0), (0.44, 1), (0.78, 1), (1, 0)])
    p["root_at"] = (0, -0.03 * gather, 0.04 * gather - 0.08 * loose)
    add(p, "root", rx=0.18 * gather - 0.05 * loose)
    add(p, "head", rx=LOOK_UP * 0.5 - 0.1 * gather)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=0.8 * gather + 0.6 * loose, ry=-sx * 0.8 * loose)
        add(p, "claw." + sd, rx=1.4 * gather + 1.0 * loose)
        add(p, "fleg1." + sd, rx=0.2 * gather - 0.3 * loose)
        add(p, "wing1." + sd, rz=sx * 0.5 * gather)
        add(p, "wing2." + sd, rz=sx * 0.4 * gather)
    ear_pose(p, back=-0.25 * loose + 0.3 * gather, out=0.3 * loose)
    tail_wave(p, t * 3, 0.08, up=0.4 * gather)
    for i, (turn, _, _) in enumerate(BEES):
        spin = math.tau * 2.5 * min(t / 0.36, 1.0)
        ahead = math.tau * (0.5 - turn) + (i - 1) * 0.5
        add(p, "bee%d" % (i + 1), ry=spin * (1 - loose) + ahead * loose, rx=-0.45 * loose)
    return p


def eat(t):
    """Holds the berry up in both blades and nibbles: to the mouth, three bites, a pleased chew."""
    p = idle(t)
    lift = seq(t, [(0, 0.8), (0.12, 1), (0.88, 1), (1, 0.8)])
    chomp = (0.5 + 0.5 * s(t, 3)) * lift
    add(p, "head", rx=-LOOK_UP * 0.6 - chomp * 0.1)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=0.62 * lift, ry=-sx * 0.12 * lift)
        add(p, "claw." + sd, rx=0.15 * lift + 0.06 * chomp)
    ear_pose(p, back=0.1 - chomp * 0.1)
    p["prop_berry"] = "on"
    return p


def chop(t):
    """Hacks at the trunk with its blades, right then left, rising into each cut."""
    p = {}
    cut = {"R": seq(t, [(0, 0), (0.15, 1), (0.25, -1), (0.4, -0.6), (0.5, 0), (1, 0)]),
           "L": seq(t, [(0, 0), (0.5, 0), (0.65, 1), (0.75, -1), (0.9, -0.6), (1, 0)])}
    for sd, sx in SIDES:
        up = max(cut[sd], 0.0)
        down = max(-cut[sd], 0.0)
        add(p, "arm." + sd, rx=0.4 + 1.7 * up - 0.2 * down, ry=sx * 0.5 * down, rz=-sx * 0.8 * up)
        add(p, "claw." + sd, rx=0.9 + 1.3 * up + 0.8 * down)
    swing = cut["R"] - cut["L"]
    add(p, "root", rx=0.22 + 0.08 * abs(swing), ry=0.2 * swing)
    add(p, "spine", ry=0.18 * swing)
    add(p, "head", rx=LOOK_UP * 0.4, ry=-0.08 * swing)
    p["root_at"] = (0, 0.01, -0.02 * abs(swing))
    ear_pose(p, back=0.3, out=0.1)
    tail_wave(p, t * 2, 0.04)
    return p


def mine(t):
    """The pick in its right blade, the left one bracing: rears back and swings it down into the rock."""
    p = {}
    v = seq(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)])
    up = max(v, 0.0)
    down = max(-v, 0.0)
    add(p, "root", rx=0.2 * up - 0.1 * down)
    add(p, "spine", rx=0.1 * up - 0.12 * down)
    add(p, "head", rx=LOOK_UP * 0.4 + 0.1 * up - 0.2 * down)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=0.5 + 0.9 * up - 0.5 * down)
        add(p, "claw." + sd, rx=0.9 + 0.8 * up - 0.5 * down)
    p["root_at"] = (0, 0.02 * up - 0.02 * down, 0.03 * up - 0.03 * down)
    ear_pose(p, back=0.2 + 0.3 * down)
    tail_wave(p, t * 2, 0.04, up=0.2 * up)
    p["prop_pick"] = "on"
    return p


def _clips():
    plain = dict(SHARED)
    plain.update({"run": (0.44, True, run), "attack": (0.8, False, mantis_strike), "ability": (1.2, False, ability),
                  "sleep": (3.4, True, flop), "eat": (2.0, True, eat), "chop": (1.1, True, chop),
                  "mine": (1.0, True, mine)})
    wings = {"idle": (0.18, 1), "walk": (0.12, 1), "run": (0.45, 1), "hop": (0.55, 2), "attack": (0.3, 1),
             "ability": (0.6, 0), "sleep": (0.0, 1), "pet": (0.1, 1), "eat": (0.1, 1)}
    out = {}
    for name, (secs, loop, fn) in plain.items():
        wing, turns = wings.get(name, (0.15, 1))
        out[name] = (secs, loop, hive(fn, secs, wing, turns, 1.0 if name == "sleep" else 0.0))
    return out


CLIPS = _clips()
import boki_react
CLIPS.update({n: (sec, lp, hive(fn, sec, 0.15, 1, 0.0)) for n, (sec, lp, fn) in boki_react.react().items()})
# unused props tucked inside the right blade they ride (m from their rest place), so no pose shows their ink
HIDE_AT = {"prop_berry": (0.101, 0.034, 0.102), "prop_pick": (0.026, 0.074, 0.002)}

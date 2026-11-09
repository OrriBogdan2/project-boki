"""Marchleaf's skeleton and its own clips. The leaf rides two bones that lag behind every move of the head; the three
tiny workers stand on free bones of their own (off the ground only when they hop) and march along in step."""
import boki_clips
import marchleaf
from boki_clips import (add, bite, chop_mouth, ear_pose, eat_ground, flop, mine_mouth, pet, s, seq, tail_wave, tend,
                        trot, walk)
from marchleaf import FEELER, GASTER_PTS, LEAF_BASE, LEAF_C, LEGS, MINIS, SIDES, STEM, v3

boki_clips.TAIL_N = 1
boki_clips.DROP = -0.08
CHAIN = ("root", "hips", "spine", "neck", "head")     # what the leaf hangs from


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.215, 0.08), (0, 0.215, -0.02), "root"),
        "spine": ((0, 0.215, -0.02), (0, 0.225, -0.08), "hips"),
        "neck": ((0, 0.22, -0.08), (0, 0.26, -0.14), "spine"),
        "head": ((0, 0.26, -0.14), (0, 0.4, -0.2), "neck"),
        "tail1": (tuple(GASTER_PTS[0]), tuple(GASTER_PTS[1]), "hips"),
        "leaf1": (tuple(STEM[2]), tuple(STEM[3]), "head"),
        "leaf2": (tuple(LEAF_BASE), tuple(LEAF_C), "leaf1"),
        "prop_axe": (tuple(marchleaf.GRIP), tuple(marchleaf.GRIP + marchleaf.AXIS * 0.1), "head"),
        "prop_pick": (tuple(marchleaf.GRIP), tuple(marchleaf.GRIP + marchleaf.AXIS * 0.1), "head"),
        "prop_berry": (tuple(marchleaf.BERRY_C), tuple(marchleaf.BERRY_C + v3(0, 0.1, 0)), "root"),
    }
    for i, at in enumerate(MINIS):
        b["mini%d" % (i + 1)] = (tuple(at), tuple(at + v3(0, 0.1, 0)), None)
    for sd, sx in SIDES:
        base, elbow, tip = (f * v3(sx, 1, 1) for f in FEELER)
        b["ear1." + sd] = (tuple(base), tuple(elbow), "head")
        b["ear2." + sd] = (tuple(elbow), tuple(tip), "ear1." + sd)
        for (name, top, knee, ankle), parent in zip(LEGS, ("spine", "hips")):
            top, knee, ankle = (tuple(pt * v3(sx, 1, 1)) for pt in (top, knee, ankle))
            b["%s1.%s" % (name, sd)] = (top, knee, parent)
            b["%s2.%s" % (name, sd)] = (knee, ankle, "%s1.%s" % (name, sd))
            b["%spaw.%s" % (name[0], sd)] = (ankle, (ankle[0], ankle[1] - 0.01, ankle[2] - 0.06), "%s2.%s" % (name, sd))
    b.update(boki_clips.part_bones(marchleaf.grown_parts()))
    return b


BONES = _bones()


def _chain(p):
    rx = ry = rz = 0.0
    for bone in CHAIN:
        r = p.get(bone, (0, 0, 0))
        rx, ry, rz = rx + r[0], ry + r[1], rz + r[2]
    return rx + p.get("root_at", (0, 0, 0))[1] * 4.0, ry, rz


def _leaf_lag(p, fn, t, loop, lag):
    """The leaf repeats what the head did a moment ago: it sways and trails behind every move (follow-through)."""
    def at(k):
        u = t - lag * k
        return _chain(fn(u % 1.0 if loop else max(u, 0.0)))
    now, late, later = _chain(p), at(1), at(2)
    add(p, "leaf1", *((a - b) * 0.85 for a, b in zip(late, now)))
    add(p, "leaf2", *((a - b) * 0.5 for a, b in zip(later, late)))
    add(p, "leaf2", rz=0.03 * s(t, 2))


def march(p, t, steps, lift=0.012, rock=0.12):
    """The tiny workers stepping in place, each a little after the one in front: `steps` (even) per clip."""
    for i in range(len(MINIS)):
        ph = -0.3 * i
        p["mini%d_at" % (i + 1)] = (0, lift * abs(s(t, steps * 0.5, ph)), 0)
        add(p, "mini%d" % (i + 1), rz=rock * s(t, steps * 0.5, ph), rx=-0.05)


def crew(fn, steps=2, lift=0.012, loop=True, lag=0.07):
    """A clip with the leaf following through and the workers stepping along."""
    def clip(t):
        p = fn(t)
        _leaf_lag(p, fn, t, loop, lag)
        if "mini1_at" not in p:
            march(p, t, steps, lift)
        return p
    return clip


def idle(t):
    """Stands at its post and, now and then, turns round to count its workers off with three nods."""
    p = boki_clips.idle(t)
    back = seq(t, [(0, 0), (0.42, 0), (0.5, 1), (0.8, 1), (0.88, 0), (1, 0)])
    nod = back * max(0.0, s(t, 7.5, 0.1))
    add(p, "neck", ry=-0.45 * back)
    add(p, "head", ry=-0.5 * back, rx=-0.16 * nod, rz=0.12 * back)
    add(p, "spine", ry=-0.1 * back)
    ear_pose(p, back=-0.1 * back, flick=0.3 * nod)
    return p


def run(t):
    """A scurry: legs a blur, low and level, antennae laid back, the leaf streaming back like a sail."""
    p = trot(t, 0.8, 0.022, 0.0, 0.08)
    add(p, "leaf1", rx=0.3)
    add(p, "leaf2", rx=0.12 + 0.06 * s(t, 2))
    ear_pose(p, back=0.45)
    tail_wave(p, t, 0.08, up=0.15)
    return p


def hop(t):
    """A happy hop; the workers hop after it, one by one."""
    p = boki_clips.hop(t)
    for i in range(len(MINIS)):
        u = t - 0.1 * (i + 1)
        air = seq(u, [(0, 0), (0.18, 0), (0.42, 1), (0.6, 0), (1, 0)])
        p["mini%d_at" % (i + 1)] = (0, 0.07 * air, 0)
        add(p, "mini%d" % (i + 1), rx=0.25 * air)
    return p


def sleep(t):
    """Flat out with the leaf pulled back over itself like a blanket; the workers doze nodding where they stand."""
    p = flop(t)
    add(p, "leaf1", rx=0.9, rz=0.2)
    add(p, "leaf2", rx=0.35 + 0.02 * s(t, 1))
    for i in range(len(MINIS)):
        add(p, "mini%d" % (i + 1), rx=-0.25 - 0.06 * s(t, 1, 0.3 * i), rz=0.15 * (1 - i))
        p["mini%d_at" % (i + 1)] = (0, 0, 0)
    return p


def ability(t):
    """Column March: plants its feet, raises the leaf and points it ahead like a banner, and the three workers march
    out round its right side into a line in front."""
    p = {}
    plant = seq(t, [(0, 0), (0.12, 1), (0.82, 1), (1, 0)])
    raise_ = seq(t, [(0, 0), (0.1, -0.3), (0.3, 1), (0.82, 1), (0.96, 0), (1, 0)])
    up = max(raise_, 0)
    p["root_at"] = (0, -0.025 * plant, 0)
    p["root_sc"] = (1 + 0.06 * plant, 1 - 0.05 * plant + 0.04 * up, 1)
    add(p, "root", rx=0.12 * up)
    add(p, "neck", rx=0.1 * up)
    add(p, "head", rx=boki_clips.LOOK_UP + 0.05 * up, ry=-0.15 * up)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.2 * plant, rz=-sx * 0.25 * plant)
        add(p, "hleg1." + sd, rx=-0.15 * plant, rz=-sx * 0.2 * plant)
    ear_pose(p, back=-0.25 * up, out=0.25 * up)
    add(p, "leaf1", rx=-0.75 * up + 0.25 * max(-raise_, 0), rz=-0.3 * up)
    add(p, "leaf2", rx=-0.2 * up + 0.08 * up * s(t, 5), rz=0.06 * up * s(t, 5, 0.2))
    tail_wave(p, t * 2, 0.06, up=0.4 * up)
    for i, at in enumerate(MINIS):
        go = seq(t, [(0, 0), (0.12 + 0.06 * i, 0), (0.55 + 0.06 * i, 1), (0.82, 1), (0.97, 0), (1, 0)])
        side = seq(t, [(0, 0), (0.12 + 0.06 * i, 0), (0.3 + 0.06 * i, 1), (0.82, 1), (0.97, 0), (1, 0)])
        to = v3(0.32, 0, -0.42 + 0.15 * i) - at
        lift = 0.016 * abs(s(t, 9, -0.3 * i)) * (1 - abs(go - 0.5) * 1.6)
        p["mini%d_at" % (i + 1)] = (to[0] * side, lift, to[2] * go * 0.6 + to[2] * side * 0.4)
        add(p, "mini%d" % (i + 1), ry=-0.6 * side * (1 - go) - 0.15 * go, rz=0.14 * s(t, 4.5, -0.3 * i))
    return p


def attack(t):
    """A charge and a snap of the mandibles, the gaster flicked up behind."""
    p = bite(t)
    tail_wave(p, t, 0.1, up=0.3 * seq(t, [(0, 0), (0.42, 1), (0.6, 1), (1, 0)]))
    return p


def carry(t):
    """Trots with the load on its back, the leaf tipped forward over its head like a parasol."""
    p = trot(t, 0.42, 0.01, -0.1, -0.03)
    add(p, "leaf1", rx=-0.35)
    add(p, "neck", rx=0.08)
    return p


CLIPS = {
    "idle": (3.0, True, crew(idle, 4, 0.006)),
    "walk": (0.7, True, crew(walk, 2)),
    "run": (0.38, True, crew(run, 2, 0.02)),
    "hop": (0.95, True, crew(hop)),
    "pet": (2.2, True, crew(pet, 4, 0.008)),
    "carry": (0.8, True, crew(carry, 2)),
    "tend": (1.3, True, crew(tend, 2, 0.008)),
    "attack": (0.8, False, crew(attack, 2, 0.01, loop=False)),
    "ability": (1.6, False, crew(ability, loop=False)),
    "sleep": (3.4, True, crew(sleep)),
    "eat": (2.0, True, crew(eat_ground, 4, 0.008)),
    "chop": (1.1, True, crew(chop_mouth, 2, 0.01)),
    "mine": (1.0, True, crew(mine_mouth, 2, 0.01)),
}
import boki_react
CLIPS.update(boki_react.react())
HIDE_AT = {"prop_berry": (0, 0.14, 0.4)}

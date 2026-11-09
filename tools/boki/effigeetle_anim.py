"""Effigeetle's skeleton and clips. The six-legged walk, look and lean helpers are Lodestick's (the shared hexapod
rig); on top of them the two marble wing cases sit on their own bones and swing open for flight, amber wings out."""

import boki_clips
import effigeetle
from boki_clips import add, s, seq
from effigeetle import LEGS, SIDES, leg_pts, v3
from lodestick_anim import PARENT, all_legs, at, leg, look, tripod

HINGE = 0.03     # m: each case's hinge sits this far off the middle, at the front of the dome


def _bones():
    g = effigeetle
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.21, 0.12), (0, 0.22, 0.0), "root"),
        "spine": ((0, 0.22, 0.0), (0, 0.26, -0.15), "hips"),
        "neck": ((0, 0.26, -0.15), (0, 0.24, -0.26), "spine"),
        "head": ((0, 0.24, -0.26), (0, 0.4, -0.34), "neck"),
        "prop_axe": (tuple(g.GRIP), tuple(g.GRIP + g.AXIS * 0.1), "head"),
        "prop_pick": (tuple(g.GRIP), tuple(g.GRIP + g.AXIS * 0.1), "head"),
        "prop_berry": (tuple(g.BERRY_C), tuple(g.BERRY_C + v3(0, 0.1, 0)), None),  # stays on the ground
    }
    for sd, sx in SIDES:
        b["case." + sd] = ((sx * HINGE, 0.47, -0.1), (sx * HINGE, 0.56, 0.1), "hips")
        b["prop_wing." + sd] = (tuple(effigeetle.mir(g.WING[0], sx)), tuple(effigeetle.mir(g.WING[1], sx)), "spine")
        for lg in LEGS:
            pre = lg[0]
            hip, knee, foot = leg_pts(lg, sx)
            ankle = foot + (knee - foot) * 0.2
            b[pre + "1." + sd] = (tuple(hip), tuple(knee), PARENT[pre])
            b[pre + "2." + sd] = (tuple(knee), tuple(ankle), pre + "1." + sd)
            b[pre.replace("leg", "paw") + "." + sd] = (tuple(ankle), tuple(foot), pre + "2." + sd)
    b.update(boki_clips.part_bones(g.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- body-part helpers
def cases(p, up, out=None):
    """The wing cases lift at the back and swing apart from the nose seam; `up` 1 is open for flight."""
    out = up if out is None else out
    for sd, sx in SIDES:
        add(p, "case." + sd, rx=0.75 * up, rz=-sx * 0.5 * out)


def wings(p, t, rate=8):
    """The amber wings out and buzzing."""
    for sd, sx in SIDES:
        add(p, "prop_wing." + sd, rz=sx * 0.35 * s(t, rate))
        p["prop_wing." + sd] = "on"


def breathe(p, t, amp=0.012):
    b = s(t, 1)
    p["root_sc"] = (1 + amp * 0.5 * b, 1 + amp * b, 1)


def hooks(p, swing=0.0, lift=0.0, bend=0.0):
    for sd, _ in SIDES:
        leg(p, "fleg", sd, swing, lift, bend)


# ---------------------------------------------------------------- clips
def idle(t):
    """Calm as a statue: slow breaths, head turning to you, and now and then the cases settle with a little shrug."""
    p = {}
    breathe(p, t)
    turn = seq(t, [(0, 0), (0.3, 0), (0.4, 0.3), (0.7, 0.3), (0.8, 0), (1, 0)])
    look(p, 0.6)
    add(p, "head", ry=turn, rz=turn * 0.2)
    cases(p, 0.05 * max(0.0, s(t, 1, 0.6)), 0.0)
    hooks(p, 0.05 * s(t, 1), 0.05)
    return p


def gait(t, swing, lift, low, rock):
    p = {}
    at(p, y=-low + 0.006 * abs(s(t, 2)), z=0.012 * s(t, 1, 0.25))
    add(p, "root", rz=rock * s(t, 1), rx=0.015 * s(t, 2))
    tripod(p, t, swing, lift)
    look(p, 0.5)
    add(p, "head", rz=-rock * 0.6 * s(t, 1))
    return p


def walk(t):
    return gait(t, 0.24, 0.24, 0.0, 0.04)


def run(t):
    p = gait(t, 0.34, 0.3, 0.02, 0.03)
    cases(p, 0.06 * max(0.0, s(t, 2)), 0.0)
    return p


def attack(t):
    """Rears back on its marble legs and hooks both gold forelegs down onto the foe."""
    p = {}
    wind = seq(t, [(0, 0), (0.3, 1), (0.42, -1), (0.62, -1), (1, 0)])
    load, jab = max(wind, 0), max(-wind, 0)
    add(p, "root", rx=0.22 * load - 0.08 * jab)
    at(p, y=0.02 * load, z=0.04 * load - 0.1 * jab)
    hooks(p, 0.5 * load + 0.55 * jab, 0.8 * load - 0.3 * jab, -0.5 * load + 0.3 * jab)
    all_legs(p, -0.12 * load, -0.08 * load, only=("mleg",))
    look(p, 1 - 0.5 * load + 0.3 * jab)
    add(p, "head", rx=-0.2 * jab)
    cases(p, 0.12 * load, 0.0)
    return p


def ability(t):
    """Boulder Heave as a ramming dive: the cases split, the amber wings lift it, and it drops horn-first."""
    p = {}
    open_ = seq(t, [(0, 0), (0.15, 1), (0.82, 1), (1, 0)])
    rise = seq(t, [(0, 0), (0.15, 0), (0.45, 1), (0.6, 1), (0.74, -0.25), (0.85, 0), (1, 0)])
    dive = seq(t, [(0, 0), (0.5, 0), (0.62, 1), (0.74, 1), (0.88, 0), (1, 0)])
    up = max(rise, 0)
    at(p, y=0.2 * up - 0.03 * max(-rise, 0), z=-0.06 * up - 0.2 * dive)
    add(p, "root", rx=0.15 * up - 0.4 * dive)
    cases(p, open_)
    if 0.08 < t < 0.9:
        wings(p, t, 12)
    all_legs(p, 0.0, 0.25 * up, 0.5 * up, only=("mleg", "hleg"))
    hooks(p, 0.4 * up + 0.6 * dive, 0.5 * up, -0.4 * up)
    look(p, 1 - dive)
    add(p, "head", rx=-0.25 * dive)
    return p


def hop(t):
    """A short buzzing hop: the cases crack open, wings blur, and it thumps back down on six feet."""
    p = {}
    air = seq(t, [(0, 0), (0.18, -0.5), (0.3, 0.2), (0.5, 1), (0.68, 0.2), (0.8, -0.5), (1, 0)])
    up, down = max(air, 0), max(-air, 0)
    p["root_at"] = (0, 0.16 * up - 0.03 * down, 0)
    p["root_sc"] = (1 + 0.05 * down, 1 - 0.08 * down + 0.03 * up, 1 + 0.02 * down)
    cases(p, 0.6 * seq(t, [(0, 0), (0.25, 0), (0.35, 1), (0.7, 1), (0.8, 0), (1, 0)]))
    if 0.3 < t < 0.75:
        wings(p, t, 10)
    all_legs(p, 0.0, 0.35 * up - 0.12 * down, 0.3 * up)
    look(p, 0.6 + 0.4 * up)
    return p


def sleep(t):
    """Sinks onto its belly like a fallen statue, legs folded in, head drawn under the harness, slow breaths."""
    br = s(t, 1)
    p = {"root_at": (0, -0.1, 0), "root_sc": (1 + br * 0.008, 1 + br * 0.016, 1)}
    all_legs(p, 0.0, 0.6, 1.0, only=("mleg", "hleg"))
    hooks(p, -0.3, 0.3, 1.0)
    add(p, "neck", rx=-0.25)
    add(p, "head", rx=-0.3 + br * 0.02)
    return p


def eat(t):
    """Holds a berry in its hooks and nibbles, head bobbing, then a pleased chew looking up."""
    p = {}
    nib = seq(t, [(0, 0.3), (0.1, 1), (0.18, 0.7), (0.26, 1), (0.34, 0.7), (0.42, 1), (0.54, 0.3), (0.7, -0.3),
                  (0.86, 0), (1, 0.3)])
    dip, chew = max(nib, 0), max(-nib, 0)
    add(p, "root", rx=-0.12 * dip)
    hooks(p, 0.1, -0.1 * dip, 0.3 * dip)
    add(p, "neck", rx=-0.3 * dip + 0.1 * chew)
    look(p, 0.2 - 0.3 * dip + 0.8 * chew)
    add(p, "head", rx=-0.25 * dip)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Proud of its face: leans into the hand, the cases lifting a hair and shivering, one hook polishing the cheek."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    breathe(p, t, 0.02)
    add(p, "root", rx=0.05 * lean, rz=0.05 * s(t, 1))
    look(p, 1.0 + 0.3 * lean)
    add(p, "head", rz=0.1 + 0.12 * lean)
    cases(p, 0.08 + 0.03 * s(t, 8), 0.02 * s(t, 8))
    leg(p, "fleg", "R", 0.3 + 0.15 * s(t, 3), 0.7, 0.5)
    return p


def mouth_tool(t, keys, tool, rear, dip):
    """A tool in its jaws: rears back, hooks raised, then drops its front onto the work."""
    p = {}
    v = seq(t, keys)
    up, down = max(v, 0), max(-v, 0)
    add(p, "root", rx=up * rear - down * 0.08)
    add(p, "neck", rx=up * 0.15 - down * dip)
    look(p, 0.4 + up * 0.6)
    add(p, "head", rx=-down * dip)
    hooks(p, 0.3 * up, 0.7 * up - 0.1 * down)
    all_legs(p, -0.08 * up, -0.08 * up, only=("mleg",))
    at(p, y=0.02 * up - 0.02 * down)
    p[tool] = "on"
    return p


def chop(t):
    return mouth_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.3, 0.25)


def mine(t):
    return mouth_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.25, 0.35)


def carry(t):
    """Plods with a load on its back, slow and level."""
    return gait(t, 0.2, 0.2, 0.012, 0.02)


def tend(t):
    """Any other farm job: head down over the work, the hooks scraping at it in turn."""
    p = {}
    breathe(p, t)
    add(p, "root", rx=-0.08)
    add(p, "neck", rx=-0.2)
    look(p, 0.3)
    add(p, "head", ry=0.12 * s(t, 1))
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        pat = max(0.0, s(t, 2, ph))
        leg(p, "fleg", sd, 0.25, 0.4 * pat - 0.1, 0.3 * pat)
    return p


CLIPS = {"idle": (4.0, True, idle), "walk": (1.2, True, walk), "run": (0.6, True, run), "hop": (1.0, True, hop),
         "pet": (2.4, True, pet), "carry": (1.3, True, carry), "tend": (1.3, True, tend),
         "attack": (0.9, False, attack), "ability": (1.8, False, ability), "sleep": (4.0, True, sleep),
         "eat": (2.0, True, eat), "chop": (1.1, True, chop), "mine": (1.0, True, mine)}
HIDE_AT = {"prop_berry": (0, 0.16, 0.6)}

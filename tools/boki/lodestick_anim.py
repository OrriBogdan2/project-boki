"""Lodestick's skeleton and clips. Six legs (fleg, mleg, hleg pairs) walk in tripods while the twig body sways like a
branch in the wind; it sleeps by playing dead on its back. The shared clips are for four legs, so all are its own."""
import math

import boki_clips
import lodestick
from boki_clips import add, c, s, seq
from lodestick import LEGS, SIDES, leg_pts, mir, v3

LOOK_UP = 0.3      # the face tips up toward the high cameras
PARENT = {"fleg": "spine", "mleg": "hips", "hleg": "hips"}
TRIPOD = {("fleg", "L"): 0.0, ("mleg", "R"): 0.0, ("hleg", "L"): 0.0,
          ("fleg", "R"): 0.5, ("mleg", "L"): 0.5, ("hleg", "R"): 0.5}
TAIL = ("tail1", "tail2", "tail3")
FLIP_UP = 0.29     # m: on its back, the root lifts this much so its knuckles lie on the ground


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.2, 0.08), (0, 0.2, 0.0), "root"),
        "spine": ((0, 0.2, 0.0), (0, 0.21, -0.17), "hips"),
        "neck": ((0, 0.21, -0.17), (0, 0.27, -0.29), "spine"),
        "head": ((0, 0.27, -0.29), (0, 0.45, -0.36), "neck"),
        "tail1": ((0, 0.205, 0.14), (0, 0.215, 0.31), "hips"),
        "tail2": ((0, 0.215, 0.31), (0, 0.24, 0.45), "tail1"),
        "tail3": ((0, 0.24, 0.45), (0, 0.29, 0.55), "tail2"),
        "prop_axe": (tuple(lodestick.GRIP), tuple(lodestick.GRIP + lodestick.AXIS * 0.1), "head"),
        "prop_pick": (tuple(lodestick.GRIP), tuple(lodestick.GRIP + lodestick.AXIS * 0.1), "head"),
        "prop_berry": (tuple(lodestick.BERRY_C), tuple(lodestick.BERRY_C + v3(0, 0.1, 0)), None),  # stays on the ground
        "prop_lode": (tuple(lodestick.LODE_C), tuple(lodestick.LODE_C + v3(0, 0.1, 0)), "spine"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = (tuple(mir(lodestick.ANTENNA[0], sx)), tuple(mir(lodestick.ANTENNA[2], sx)), "head")
        for leg in LEGS:
            pre = leg[0]
            hip, knee, foot = leg_pts(leg, sx)
            ankle = foot + (knee - foot) * 0.16
            b[pre + "1." + sd] = (tuple(hip), tuple(knee), PARENT[pre])
            b[pre + "2." + sd] = (tuple(knee), tuple(ankle), pre + "1." + sd)
            b[pre.replace("leg", "paw") + "." + sd] = (tuple(ankle), tuple(foot), pre + "2." + sd)
    b.update(boki_clips.part_bones(lodestick.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- body-part helpers
def look(p, k=1.0):
    add(p, "neck", rx=LOOK_UP * k * 0.45)
    add(p, "head", rx=LOOK_UP * k * 0.55)


def leg(p, pre, sd, swing=0.0, lift=0.0, bend=0.0):
    """One leg: `swing` forward round the hip, `lift` raises the knee (and the foot with it), `bend` folds the shin
    in under it."""
    sx = -1.0 if sd == "L" else 1.0
    add(p, pre + "1." + sd, ry=sx * swing, rz=sx * lift)
    add(p, pre + "2." + sd, rz=-sx * bend)


def all_legs(p, swing=0.0, lift=0.0, bend=0.0, only=("fleg", "mleg", "hleg")):
    for sd, _ in SIDES:
        for pre in only:
            leg(p, pre, sd, swing, lift, bend)


def tripod(p, t, swing, lift):
    """Three legs on the ground pushing back while the other three swing forward in the air."""
    for (pre, sd), ph in TRIPOD.items():
        a = s(t, 1, ph)
        up = max(0.0, c(t, 1, ph))
        leg(p, pre, sd, swing * a, lift * up, lift * 0.6 * up)


def feelers(p, t, amp=0.08, back=0.0, rate=1):
    for sd, sx in SIDES:
        ph = 0.0 if sd == "L" else 0.31
        add(p, "ear1." + sd, rx=-back + amp * s(t, rate, ph), rz=sx * amp * 0.5 * s(t, rate, ph + 0.25))


def tail(p, t, amp=0.04, up=0.0, rate=1):
    for i, bone in enumerate(TAIL):
        add(p, bone, rx=-up / 3, ry=amp * s(t, rate, -0.12 * i) * (0.6 + 0.4 * i))


def sway(p, t, amp, rate=1):
    """A twig in the wind: the body leans side to side over its feet, the head kept level."""
    w = s(t, rate)
    p["root_at"] = (amp * 0.35 * w, 0, 0)
    add(p, "root", rz=-amp * w)
    add(p, "neck", rz=amp * 0.6 * w)
    add(p, "head", rz=amp * 0.3 * w)


def at(p, x=0.0, y=0.0, z=0.0):
    o = p.get("root_at", (0, 0, 0))
    p["root_at"] = (o[0] + x, o[1] + y, o[2] + z)


# ---------------------------------------------------------------- clips
def idle(t):
    """Still and patient: it sways like a twig in a breeze, turns its head to you, and slowly looks away again."""
    p = {}
    sway(p, t, 0.035)
    turn = seq(t, [(0, 0), (0.3, 0), (0.4, 0.35), (0.7, 0.35), (0.8, 0), (1, 0)])
    look(p)
    add(p, "head", ry=turn, rz=turn * 0.3)
    feelers(p, t, 0.07, rate=2)
    tail(p, t, 0.03)
    return p


def gait(t, swing, lift, sway_amp, low):
    p = {}
    sway(p, t, sway_amp)
    at(p, y=-low + 0.006 * abs(s(t, 2)), z=0.018 * s(t, 1, 0.25))      # it rocks to and fro as well
    add(p, "root", rx=0.02 * s(t, 2))
    tripod(p, t, swing, lift)
    look(p)
    feelers(p, t, 0.1, back=0.15 + low * 4, rate=2)
    tail(p, t, 0.05)
    return p


def walk(t):
    return gait(t, 0.26, 0.28, 0.1, 0.0)


def run(t):
    return gait(t, 0.36, 0.34, 0.03, 0.02)


def attack(t):
    """Rears up on its back legs and jabs both forelegs down like a pair of sticks."""
    p = {}
    wind = seq(t, [(0, 0), (0.3, 1), (0.4, -1), (0.6, -1), (1, 0)])
    load, jab = max(wind, 0), max(-wind, 0)
    add(p, "root", rx=0.32 * load - 0.08 * jab)
    at(p, y=0.03 * load, z=0.05 * load - 0.12 * jab)
    for sd, _ in SIDES:
        leg(p, "fleg", sd, 0.5 * load + 0.6 * jab, 0.9 * load - 0.3 * jab, -0.3 * load)
        leg(p, "mleg", sd, -0.15 * load, -0.1 * load)
    look(p, 1 - 0.5 * load + 0.3 * jab)
    add(p, "head", rx=-0.2 * jab)
    feelers(p, t, 0.05, back=0.4 * load - 0.2 * jab)
    tail(p, t, 0.03, up=0.4 * load)
    return p


def ability(t):
    """Lodestar: plants its six feet, raises its forelegs over a glowing lodestone, then yanks it all back."""
    p = {}
    plant = seq(t, [(0, 0), (0.18, 1), (0.9, 1), (1, 0)])
    raise_ = seq(t, [(0, 0), (0.15, 0), (0.38, 1), (0.6, 1), (0.66, 0.6), (0.9, 0.6), (1, 0)])
    yank = seq(t, [(0, 0), (0.58, 0), (0.66, 1), (0.82, 1), (1, 0)])
    at(p, y=-0.035 * plant, z=0.08 * yank)
    add(p, "root", rx=0.2 * raise_ - 0.06 * yank)
    all_legs(p, 0.0, -0.18 * plant, -0.2 * plant, only=("mleg", "hleg"))
    for sd, _ in SIDES:
        leg(p, "fleg", sd, 0.3 * raise_ - 0.6 * yank, 0.6 * raise_ - 0.2 * yank, -1.5 * raise_ + 0.8 * yank)
    look(p, 1 + 0.5 * raise_)
    add(p, "head", rx=-0.15 * yank)
    feelers(p, t, 0.04 + 0.05 * yank, back=-0.3 * raise_, rate=6)
    tail(p, t, 0.02 + 0.04 * yank, up=0.5 * plant, rate=4)
    if 0.24 < t < 0.92:
        p["prop_lode"] = "on"
    return p


def hop(t):
    """A deadpan boing: straight up, stiff as a stick, all six legs flung out in a star, then a squashy landing."""
    p = {}
    air = seq(t, [(0, 0), (0.18, -0.6), (0.3, 0.2), (0.48, 1), (0.66, 0.2), (0.78, -0.5), (1, 0)])
    up, down = max(air, 0), max(-air, 0)
    p["root_at"] = (0, 0.2 * up - 0.05 * down, 0)
    p["root_sc"] = (1 + 0.1 * down, 1 - 0.16 * down + 0.06 * up, 1 + 0.04 * down)
    add(p, "root", rz=0.2 * seq(t, [(0, 0), (0.3, 0), (0.48, 1), (0.66, -1), (0.8, 0), (1, 0)]))
    all_legs(p, 0.0, 0.5 * up - 0.2 * down, -0.3 * up)
    look(p, 1 + 0.4 * up)
    feelers(p, t, 0.1, back=-0.4 * up + 0.3 * down, rate=2)
    tail(p, t, 0.04, up=0.6 * up - 0.3 * down)
    return p


def sleep(t):
    """Plays dead: flat on its back, six legs stiff in the air, head lolled, one foot twitching now and then."""
    br = s(t, 1)
    p = {"root_at": (0, FLIP_UP, 0), "root_sc": (1 + br * 0.01, 1 + br * 0.02, 1)}
    add(p, "root", rz=math.pi)
    all_legs(p, 0.0, -0.3, 0.55)
    twitch = seq(t, [(0, 0), (0.62, 0), (0.65, 1), (0.68, 0), (0.71, 1), (0.74, 0), (1, 0)])
    leg(p, "mleg", "R", 0.0, 0.25 * twitch, -0.3 * twitch)
    add(p, "neck", rx=-0.3, rz=-0.2)
    add(p, "head", rx=-0.25 + br * 0.02, rz=-0.35)
    feelers(p, t, 0.01, back=0.6)
    tail(p, t, 0.0, up=-0.3)
    return p


def eat(t):
    """Lowers its head to a berry and nibbles at it, three bites and a pleased chew with the head up."""
    p = {}
    nib = seq(t, [(0, 0.3), (0.1, 1), (0.18, 0.7), (0.26, 1), (0.34, 0.7), (0.42, 1), (0.54, 0.3), (0.7, -0.3),
                  (0.86, 0), (1, 0.3)])
    dip, chew = max(nib, 0), max(-nib, 0)
    add(p, "root", rx=-0.18 * dip)
    all_legs(p, 0.0, -0.12 * dip, 0.25 * dip, only=("fleg",))
    add(p, "neck", rx=-0.35 * dip + 0.1 * chew)
    look(p, 0.2 - 0.3 * dip + 0.8 * chew)
    add(p, "head", rx=-0.3 * dip)
    feelers(p, t, 0.06, back=0.2 * dip, rate=3)
    tail(p, t, 0.03)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans its head up into the hand and rocks slowly, feelers laid flat, eyes shut."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    sway(p, t, 0.05)
    add(p, "root", rx=0.06 * lean)
    look(p, 1.2 + 0.3 * lean)
    add(p, "head", rz=0.12 + 0.15 * lean)
    feelers(p, t, 0.02, back=0.7)
    tail(p, t, 0.06, rate=2)
    return p


def mouth_tool(t, keys, tool, rear, dip):
    """A tool in its jaws: rears up on its back legs, forelegs high, and drops its whole front onto the work."""
    p = {}
    v = seq(t, keys)
    up, down = max(v, 0), max(-v, 0)
    add(p, "root", rx=up * rear - down * 0.1)
    add(p, "neck", rx=up * 0.15 - down * dip)
    look(p, 0.4 + up * 0.6)
    add(p, "head", rx=-down * dip)
    for sd, _ in SIDES:
        leg(p, "fleg", sd, 0.3 * up, 0.8 * up - 0.1 * down)
        leg(p, "mleg", sd, -0.1 * up, -0.1 * up)
    at(p, y=0.03 * up - 0.02 * down)
    feelers(p, t, 0.05, back=0.3 * down, rate=2)
    tail(p, t, 0.03, up=0.4 * up)
    p[tool] = "on"
    return p


def chop(t):
    return mouth_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.45, 0.25)


def mine(t):
    return mouth_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.35, 0.35)


def carry(t):
    """Walks its load along on its back, slow and level, the sway smaller under the weight."""
    p = gait(t, 0.22, 0.22, 0.035, 0.015)
    feelers(p, t, 0.04, back=-0.2)
    return p


def tend(t):
    """Any other farm job: head down over the work, the forelegs patting at it in turn."""
    p = {}
    sway(p, t, 0.02)
    add(p, "root", rx=-0.1)
    add(p, "neck", rx=-0.2)
    look(p, 0.4)
    add(p, "head", ry=0.12 * s(t, 1))
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        pat = max(0.0, s(t, 2, ph))
        leg(p, "fleg", sd, 0.25, 0.5 * pat - 0.1, 0.2 * pat)
    feelers(p, t, 0.06, back=0.2, rate=2)
    tail(p, t, 0.03)
    return p


CLIPS = {"idle": (4.0, True, idle), "walk": (1.0, True, walk), "run": (0.5, True, run), "hop": (1.0, True, hop),
         "pet": (2.4, True, pet), "carry": (1.1, True, carry), "tend": (1.3, True, tend),
         "attack": (0.8, False, attack), "ability": (1.6, False, ability), "sleep": (3.6, True, sleep),
         "eat": (2.0, True, eat), "chop": (1.1, True, chop), "mine": (1.0, True, mine)}
import boki_react
CLIPS.update(boki_react.react())
HIDE_AT = {"prop_berry": (0, 0.16, 0.62), "prop_lode": (0, -0.34, 0.5)}

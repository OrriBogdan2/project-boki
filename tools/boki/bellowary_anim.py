"""Bellowary's skeleton and clips: a tall cassowary that struts and sprints on two thick legs, a forge bellows on its
chest that pumps with each stride and wheezes before it charges (attack: Stinger Dash, a sprint and a spur kick;
ability: Gale Lance, a blast of ember air out of its brass nozzle beak). The saddle bone behind the neck is the
rider's seat (BIPED-L mount)."""
import boki_clips
import bellowary as bw
from bellowary import (ANKLE, BELLOWS, CHEST, EAR_PTS, HIP, HIP_JOINT, KNEE, NECK, NOZZLE, SADDLE, SHOULDER, SIDES,
                       TAIL_PTS, TOE, WING_TIP, mir, v3)
from boki_clips import add, s, seq

LOOK_UP = 0.2
SCALED = ("bellows",)


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": (tuple(HIP), tuple(CHEST), "root"),
        "spine": (tuple(CHEST), tuple(NECK[0]), "hips"),
        "neck": (tuple(NECK[0]), tuple(NECK[1]), "spine"),
        "neck2": (tuple(NECK[1]), tuple(NECK[2]), "neck"),
        "head": (tuple(NECK[2]), tuple(bw.HEAD_TOP), "neck2"),
        "bellows": (tuple(BELLOWS[0]), tuple(BELLOWS[1]), "spine"),
        "saddle": (tuple(SADDLE[0]), tuple(SADDLE[1]), "spine"),
        "tail1": (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips"),
        "prop_axe": (tuple(bw.GRIP), tuple(bw.GRIP + bw.AXIS * 0.1), "head"),
        "prop_pick": (tuple(bw.GRIP), tuple(bw.GRIP + bw.AXIS * 0.1), "head"),
        "prop_berry": (tuple(bw.BERRY_C), tuple(bw.BERRY_C + v3(0, 0.1, 0)), "root"),
        "prop_gust": (tuple(NOZZLE), tuple(NOZZLE + v3(0, 0, -0.1)), "head"),
    }
    for sd, sx in SIDES:
        b["ear1." + sd] = (tuple(mir(EAR_PTS[0], sx)), tuple(mir(EAR_PTS[1], sx)), "head")
        b["wing." + sd] = (tuple(mir(SHOULDER, sx)), tuple(mir(WING_TIP, sx)), "spine")
        b["hleg1." + sd] = (tuple(mir(HIP_JOINT, sx)), tuple(mir(KNEE, sx)), "hips")
        b["hleg2." + sd] = (tuple(mir(KNEE, sx)), tuple(mir(ANKLE, sx)), "hleg1." + sd)
        b["hpaw." + sd] = (tuple(mir(ANKLE, sx)), tuple(mir(TOE, sx)), "hleg2." + sd)
    b.update(boki_clips.part_bones(bw.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- body-part helpers
def look(p, k=1.0):
    add(p, "neck", rx=LOOK_UP * k * 0.3)
    add(p, "neck2", rx=LOOK_UP * k * 0.3)
    add(p, "head", rx=LOOK_UP * k * 0.4)


def pump(p, k):
    """The bellows: k 1 squeezes it flat against the chest, below 0 fills it out."""
    p["bellows_sc"] = (1 + 0.05 * k, 1 - 0.06 * k, 1 - 0.3 * k)


def wings(p, out=0.0, flap=0.0):
    """The stubby wings in the plumage: `out` lifts them away from the body, `flap` beats them."""
    for sd, sx in SIDES:
        add(p, "wing." + sd, rz=sx * (out + flap), rx=0.3 * out)


def tail(p, up=0.0, wag=0.0):
    add(p, "tail1", rx=up * 0.6, ry=wag * 0.5)


def legs(p, sd, swing=0.0, lift=0.0):
    """One leg: `swing` forward from the hip, `lift` folds the shank and curls the toes."""
    add(p, "hleg1." + sd, rx=swing + lift * 0.5)
    add(p, "hleg2." + sd, rx=-lift * 1.1)
    add(p, "hpaw." + sd, rx=lift * 0.5 - swing * 0.6)


def both_legs(p, swing=0.0, lift=0.0):
    for sd, _ in SIDES:
        legs(p, sd, swing, lift)


def stride(p, t, swing, lift, bob, k=1.0):
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        legs(p, sd, s(t, 1, ph) * swing * k, max(0.0, s(t, 1, ph + 0.25)) * lift * k)
    p["root_at"] = (0, abs(s(t, 1)) * bob * k - 0.004 * k, 0)


# ---------------------------------------------------------------- clips
def idle(t):
    """Stands tall: slow breaths through the bellows, a look round, a wheeze and a shake of the plumage."""
    p = {}
    br = s(t, 2)
    shake = seq(t, [(0, 0), (0.8, 0), (0.83, 1), (0.92, 1), (0.95, 0), (1, 0)])
    shiver = s(t, 16) * shake
    p["root_sc"] = (1 + br * 0.01 + 0.03 * shake, 1 + br * 0.012, 1 + br * 0.01 + 0.03 * shake)
    pump(p, 0.35 * br + 0.5 * shiver)
    add(p, "spine", rx=0.03 + br * 0.015)
    turn = seq(t, [(0, 0), (0.22, 0), (0.26, 0.5), (0.44, 0.5), (0.48, -0.4), (0.62, -0.4), (0.66, 0), (1, 0)])
    look(p)
    add(p, "neck", ry=turn * 0.4)
    add(p, "head", ry=turn * 0.5, rz=0.1 * shiver)
    tail(p, 0.1 * shake, 0.1 * shiver)
    wings(p, 0.08 * shake, 0.06 * shiver)
    return p


def walk(t):
    """A proud cassowary strut, the head bobbing over each step, the bellows puffing once a stride."""
    p = {}
    sw = s(t, 1)
    stride(p, t, 0.45, 0.75, 0.012)
    add(p, "hips", rz=sw * 0.06)
    add(p, "spine", rx=0.04)
    look(p)
    add(p, "neck", rx=-0.1 * s(t, 2, 0.1))
    add(p, "head", rx=0.08 * s(t, 2, 0.1), rz=-sw * 0.05)
    pump(p, 0.4 * s(t, 1, 0.1))
    tail(p, 0.05 * abs(sw), 0.08 * sw)
    wings(p, 0.02, 0.03 * sw)
    return p


def run(t):
    """A flat-out sprint: body tipped forward, neck stretched out, long strides, the bellows working hard."""
    p = {}
    stride(p, t, 0.85, 1.1, 0.03)
    add(p, "hips", rx=-0.35, rz=s(t, 1) * 0.05)
    add(p, "neck", rx=-0.15)
    look(p, 0.8)
    pump(p, 0.7 * s(t, 2))
    tail(p, 0.25, 0.1 * s(t, 1))
    wings(p, 0.15, 0.08 * s(t, 2))
    return p


def hop(t):
    """Happy: a crouch, a stiff-legged bounce with the stubby wings out, a puff of the bellows on landing."""
    p = {}
    up = seq(t, [(0, 0), (0.25, 0), (0.45, 1), (0.6, 0), (1, 0)])
    down = seq(t, [(0, 0), (0.15, 1), (0.25, 0), (0.6, 0), (0.7, 1), (0.85, 0), (1, 0)])
    p["root_at"] = (0, 0.1 * up - 0.03 * down, 0)
    p["root_sc"] = (1 + 0.08 * down, 1 - 0.12 * down + 0.04 * up, 1 + 0.06 * down)
    both_legs(p, 0.1 * up, 0.5 * down + 0.4 * up)
    look(p, 1 + 0.5 * up)
    wings(p, 0.4 * up, 0.15 * s(t, 4) * up)
    pump(p, down - 0.4 * up)
    tail(p, 0.4 * up)
    return p


def sleep(t):
    """Folded down on its legs, the neck curled back, the head tucked against the saddle, the bellows slow."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.16, 0)
    p["root_sc"] = (1.05 + br * 0.012, 0.98 + br * 0.015, 1.04)
    both_legs(p, 0.9, 1.5)
    add(p, "hips", rx=0.05)
    add(p, "neck", rx=0.5, ry=0.3)
    add(p, "neck2", rx=0.5, ry=0.4)
    add(p, "head", rx=-0.4 + br * 0.02, ry=0.5, rz=0.2)
    pump(p, 0.25 * br)
    tail(p, -0.1)
    return p


def eat(t):
    """Stoops on its long neck to the berry, pecks at it twice with the brass beak, throws its head back to gulp."""
    p = {}
    v = seq(t, [(0, 0), (0.12, 1), (0.2, 1), (0.25, 0.7), (0.3, 1), (0.38, 0.7), (0.43, 1), (0.55, 0),
                (0.66, -0.6), (0.78, 0), (1, 0)])
    dip = max(v, 0)
    toss = max(-v, 0)
    add(p, "hips", rx=-0.45 * dip + 0.1 * toss)
    add(p, "neck", rx=-0.4 * dip + 0.3 * toss)
    add(p, "neck2", rx=-0.3 * dip + 0.2 * toss)
    look(p, 1 - dip)
    add(p, "head", rx=-0.2 * dip + 0.3 * toss)
    tail(p, 0.3 * dip)
    pump(p, 0.5 * toss)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans its tall neck into the hand, a long contented wheeze out of the bellows, the tail swishing."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    p["root_sc"] = (1 + 0.03 * lean, 1, 1 + 0.03 * lean)
    add(p, "neck", rx=0.1 * lean, rz=0.12 * lean)
    add(p, "neck2", rz=0.1 * lean)
    look(p, 1 + 0.3 * lean)
    add(p, "head", rz=0.15 + 0.15 * lean)
    pump(p, lean * 0.6 - 0.2)
    tail(p, 0.1, 0.15 * s(t, 2))
    wings(p, 0.05 * lean)
    return p


def beak_tool(t, keys, tool, back, strike):
    """A tool in its beak: rears up on its legs, then swings its whole neck down into the blow."""
    p = {}
    v = seq(t, keys)
    up = max(v, 0)
    down = max(-v, 0)
    add(p, "hips", rx=up * back - down * strike * 0.6)
    add(p, "neck", rx=up * 0.2 - down * strike * 0.5)
    add(p, "neck2", rx=up * 0.1 - down * strike * 0.3)
    look(p, 0.5 + up * 0.5)
    p["root_at"] = (0, -0.01 * down, 0.02 * up - 0.03 * down)
    both_legs(p, 0.1 * up, 0)
    pump(p, down * 0.6)
    tail(p, 0.3 * down)
    wings(p, 0.15 * up)
    p[tool] = "on"
    return p


def chop(t):
    return beak_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.3, 0.6)


def mine(t):
    return beak_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.25, 0.9)


def carry(t):
    """Struts on with the load on the saddle, leaning into it."""
    p = walk(t)
    add(p, "hips", rx=-0.12)
    look(p, 0.6)
    pump(p, 0.2)
    return p


def tend(t):
    """Any other farm job: neck down over the work, pecking at it, stepping round it."""
    p = {}
    bob = max(0.0, s(t, 2))
    add(p, "hips", rx=-0.35 - bob * 0.08)
    add(p, "neck", rx=-0.3)
    add(p, "neck2", rx=-0.15)
    add(p, "head", rx=-bob * 0.25, ry=s(t, 1) * 0.12)
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        legs(p, sd, 0.0, max(0.0, s(t, 1, ph)) * 0.35)
    tail(p, 0.25, 0.06 * s(t, 1))
    return p


def attack(t):
    """Stinger Dash: the wheeze first (the bellows fills, it rears and crouches), then a dash forward that ends in a
    spur kick with the right leg thrown out, and a settle."""
    p = {}
    wheeze = seq(t, [(0, 0), (0.25, 1), (0.32, 0), (1, 0)])
    dash = seq(t, [(0, 0), (0.28, 0), (0.42, 1), (0.6, 1), (0.85, 0), (1, 0)])
    kick = seq(t, [(0, 0), (0.42, 0), (0.48, 1), (0.6, 1), (0.75, 0), (1, 0)])
    p["root_at"] = (0, -0.03 * wheeze + 0.04 * kick, 0.03 * wheeze - 0.24 * dash)
    p["root_sc"] = (1 + 0.04 * wheeze, 1 - 0.06 * wheeze, 1)
    pump(p, -0.6 * wheeze + 0.9 * dash)
    add(p, "hips", rx=0.15 * wheeze - 0.35 * dash + 0.25 * kick)
    add(p, "neck", rx=0.2 * wheeze - 0.2 * dash)
    look(p, 0.6 + 0.4 * wheeze)
    both_legs(p, -0.1 * wheeze, 0.5 * wheeze)
    legs(p, "R", 1.1 * kick, 0.2 * kick)
    legs(p, "L", -0.2 * kick, 0)
    wings(p, 0.2 * wheeze + 0.3 * kick)
    tail(p, 0.3 * dash)
    return p


def ability(t):
    """Gale Lance: rears back and draws a long breath into the bellows, then squeezes it flat and throws its head
    forward: a lance of ember air out of the brass nozzle."""
    p = {}
    draw = seq(t, [(0, 0), (0.1, 0), (0.42, 1), (0.48, 1), (0.52, 0), (1, 0)])
    blast = seq(t, [(0, 0), (0.48, 0), (0.53, 1), (0.75, 1), (0.88, 0), (1, 0)])
    p["root_at"] = (0, -0.01 * blast, 0.03 * draw - 0.03 * blast)
    p["root_sc"] = (1 + 0.04 * draw, 1 + 0.03 * draw, 1)
    pump(p, -0.7 * draw + 1.0 * blast)
    add(p, "hips", rx=0.2 * draw - 0.15 * blast)
    add(p, "neck", rx=0.25 * draw - 0.3 * blast)
    add(p, "neck2", rx=0.1 * draw - 0.2 * blast)
    look(p, 1 + 0.6 * draw)
    add(p, "head", rx=-0.1 * blast)
    both_legs(p, 0.1 * draw - 0.15 * blast, 0.2 * blast)
    wings(p, 0.3 * draw + 0.2 * blast, 0.1 * s(t, 6) * blast)
    tail(p, 0.3 * blast)
    if 0.5 < t < 0.8:
        p["prop_gust"] = "on"
    return p


CLIPS = {"idle": (3.6, True, idle), "walk": (0.8, True, walk), "run": (0.5, True, run), "hop": (1.2, True, hop),
         "pet": (2.4, True, pet), "carry": (0.85, True, carry), "tend": (1.3, True, tend),
         "attack": (0.9, False, attack), "ability": (1.4, False, ability), "sleep": (3.6, True, sleep),
         "eat": (2.2, True, eat), "chop": (1.1, True, chop), "mine": (1.0, True, mine)}
HIDE_AT = {"prop_berry": (0, 0.2, 0.26)}

"""Zephyrak's skeleton and clips. It has no legs: every clip is the eel chain swimming through the air (a curve sent
down the body, joint by joint), the swift's wings and the hover. The shared clips are for legs, so all are its own."""
import math

import boki_clips
import zephyrak
from boki_clips import LOOK_UP, TAU, add, ease, s, seq
from zephyrak import SIDES, SPINE

boki_clips.TAIL_N = zephyrak.TAIL_N
# each body bone with the middles (z, m) of the segment it turns from and the one it turns: the chain runs out both
# ways from the hips, so a joint's angle is the change in the body's heading across it
_MID = [(SPINE[i][2] + SPINE[i + 1][2]) * 0.5 for i in range(len(SPINE) - 1)]
JOINTS = [("hips", None, _MID[2]), ("spine", _MID[2], _MID[1]), ("neck", _MID[1], _MID[0])]
JOINTS += [("tail%d" % (i + 1), _MID[2 + i], _MID[3 + i]) for i in range(zephyrak.TAIL_N)]
HEAD_Z = _MID[0]
MID_Z = SPINE[3][2]     # the hips joint, where the chain splits
HOVER = 0.068      # m from its belly to the ground at rest: lowered by this, it lies down


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": (tuple(SPINE[3]), tuple(SPINE[2]), "root"),
        "spine": (tuple(SPINE[2]), tuple(SPINE[1]), "hips"),
        "neck": (tuple(SPINE[1]), tuple(SPINE[0]), "spine"),
        "head": (tuple(SPINE[0]), tuple(zephyrak.hd(0, 0.105, 0.085)), "neck"),
        "prop_axe": (tuple(zephyrak.GRIP), tuple(zephyrak.GRIP + zephyrak.AXIS * 0.1), "head"),
        "prop_pick": (tuple(zephyrak.GRIP), tuple(zephyrak.GRIP + zephyrak.AXIS * 0.1), "head"),
        "prop_berry": (tuple(zephyrak.BERRY_C), tuple(zephyrak.BERRY_C + zephyrak.v3(0, 0.1, 0)), "root"),
    }
    parent = "hips"
    for i in range(zephyrak.TAIL_N):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(SPINE[3 + i]), tuple(SPINE[4 + i]), parent)
        parent = n
    for sd, sx in SIDES:
        root, wrist, tip = ((sx * q[0], q[1], q[2]) for q in zephyrak.WING)
        b["wing1." + sd] = (root, wrist, "spine")
        b["wing2." + sd] = (wrist, tip, "wing1." + sd)
        base, tip, _ = zephyrak.ear_fin(sx)
        b["ear1." + sd] = (tuple(base), tuple(tip), "head")
    b.update(boki_clips.part_bones(zephyrak.grown_parts()))
    return b


BONES = _bones()


def bend(pose, side=None, lift=None, steady_head=True):
    """Lays the body along a curve: side(z) and lift(z) are its slopes (dx/dz, dy/dz) along the body (z, m)."""
    for bone, z0, z1 in JOINTS:
        if side:
            add(pose, bone, ry=side(z1) - (side(z0) if z0 is not None else 0.0))
        if lift:
            add(pose, bone, rx=-(lift(z1) - (lift(z0) if z0 is not None else 0.0)))
    if steady_head:
        if side:
            add(pose, "head", ry=-side(HEAD_Z))
        if lift:
            add(pose, "head", rx=lift(HEAD_Z))


def swim(t, amp, waves=1.0, length=0.62, grow=0.65):
    """dx/dz of a wave travelling from the head to the tail, swelling toward the tail; t in cycles."""
    def slope(z):
        k = TAU / length
        a = amp * ((1 - grow) + grow * min(max((z - SPINE[0][2]) / 0.6, 0.0), 1.0))
        return a * k * math.cos(k * z - TAU * waves * t)
    return slope


def arch(front, back=0.0, z0=MID_Z):
    """A heading curve for bend's lift: front > 0 raises the head end, back > 0 the tail, each bending from z0 out."""
    return lambda z: -front * max(z0 - z, 0.0) + back * max(z - z0, 0.0)


def wings(pose, flap=0.0, sweep=0.0, tip=0.0, twist=0.0):
    """flap > 0 raises them, sweep > 0 folds them back along the body, tip bends the outer half up."""
    for sd, sx in SIDES:
        add(pose, "wing1." + sd, rz=sx * flap, ry=-sx * sweep, rx=twist)
        add(pose, "wing2." + sd, rz=sx * tip, ry=-sx * sweep * 0.6)


def beat(pose, t, n, amp, sweep=0.0, lift=0.1):
    """Wingbeats: the outer half lags the inner, so the tips whip."""
    wings(pose, flap=lift + amp * s(t, n), sweep=sweep, tip=amp * 0.7 * s(t, n, -0.12))


def fins(pose, back=0.0, flick=0.0):
    """The ear fins: back lays them along the head, flick tips them up."""
    for sd, sx in SIDES:
        add(pose, "ear1." + sd, ry=-sx * back, rz=sx * flick)


def idle(t):
    """Hovering: a slow S drifting down the body, soft wingbeats, the head held still and looking up."""
    p = {}
    bend(p, side=swim(t, 0.03), lift=swim(t * 2, 0.008, length=0.5))
    p["root_at"] = (0, 0.012 * s(t, 2, 0.1), 0)
    add(p, "head", rx=LOOK_UP * 0.6 + 0.03 * s(t, 2, -0.1), rz=0.03 * s(t, 1, 0.2))
    beat(p, t, 3, 0.22, lift=0.12)
    fins(p, back=0.1, flick=0.12 * s(t, 3, 0.2))
    return p


def walk(t):
    """Swims slowly through the air: a fuller S, deeper beats, nose level."""
    p = {}
    bend(p, side=swim(t, 0.05), lift=swim(t * 2, 0.01, length=0.5))
    p["root_at"] = (0, 0.016 * s(t, 2, 0.15), 0)
    add(p, "root", ry=0.05 * s(t, 1, 0.05))
    add(p, "head", rx=LOOK_UP * 0.5 + 0.03 * s(t, 2), ry=0.03 * s(t, 1, 0.3))
    beat(p, t, 2, 0.36, sweep=0.1, lift=0.1)
    fins(p, back=0.25, flick=0.1 * s(t, 2))
    return p


def run(t):
    """Streamlined: wings swept back hard, the body nearly straight with a fast flick down to the tail."""
    p = {}
    bend(p, side=swim(t, 0.022, length=0.5, grow=0.9))
    add(p, "hips", rx=-0.06)
    add(p, "spine", rx=0.04)
    add(p, "neck", rx=0.04)
    add(p, "head", rx=LOOK_UP * 0.3)
    p["root_at"] = (0, 0.02 + 0.01 * s(t, 2), 0)
    wings(p, flap=0.12 + 0.12 * s(t, 2), sweep=0.95, tip=-0.1 + 0.15 * s(t, 2, -0.15), twist=-0.1)
    fins(p, back=0.8)
    for i in range(zephyrak.TAIL_N):
        add(p, "tail%d" % (i + 1), rx=0.02)
    return p


def _roll(p, angle, centre_y):
    """Rolls the whole body about its own length, round a point `centre_y` above the ground, not round its feet."""
    add(p, "root", rz=angle)
    x, y, z = p.get("root_at", (0, 0, 0))
    p["root_at"] = (x + centre_y * math.sin(angle), y + centre_y * (1 - math.cos(angle)), z)


def hop(t):
    """A happy corkscrew: dips, springs up into a barrel roll with the wings tucked, flares them to land soft."""
    p = {}
    air = seq(t, [(0, 0), (0.16, -0.6), (0.3, 0.3), (0.5, 1), (0.7, 0.3), (0.8, -0.5), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    spin = seq(t, [(0, 0), (0.24, 0), (0.72, 1), (1, 1)])
    bend(p, side=swim(t, 0.03 + 0.02 * down), lift=arch(0.8 * up))
    p["root_at"] = (0, 0.3 * up - 0.04 * down, 0)
    p["root_sc"] = (1 + 0.1 * down - 0.04 * up, 1 - 0.16 * down + 0.08 * up, 1 + 0.05 * down)
    _roll(p, TAU * spin, 0.26)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.2 * up - 0.1 * down)
    tuck = ease((up - 0.3) / 0.5)
    flare = seq(t, [(0, 0), (0.7, 0), (0.8, 1), (1, 0)])
    wings(p, flap=0.2 + 0.5 * down + 0.4 * flare * s(t, 3), sweep=0.85 * tuck, tip=0.3 * down)
    fins(p, back=0.2 + 0.5 * tuck, flick=0.3 * down)
    return p


def sleep(t):
    """Lies down in a coil on the ground, chin on its own tail, wings folded flat, breathing slow."""
    br = s(t, 1)
    p = {}
    bend(p, side=lambda z: 7.2 * (z - MID_Z - 0.03), lift=None, steady_head=False)
    for i, bone in enumerate(("tail4", "tail5", "tail6")):
        add(p, bone, rx=0.12 + 0.04 * i)
    add(p, "neck", rx=-0.3, ry=0.3)
    add(p, "head", rx=-0.12 + br * 0.02, rz=0.32, ry=0.25)
    p["root_at"] = (0, -HOVER + 0.004 * br, 0.02)
    p["root_sc"] = (1 + br * 0.015, 1 + br * 0.025, 1)
    wings(p, flap=-0.18, sweep=1.05, tip=-0.1)
    fins(p, back=0.6)
    return p


def eat(t):
    """Darts its head down to the berry on the ground three times, nibbling, bobbing half up between."""
    p = {}
    dart = seq(t, [(0, 0.3), (0.08, 1), (0.25, 1), (0.33, 0.35), (0.41, 1), (0.58, 1), (0.66, 0.35), (0.74, 1),
                   (0.91, 1), (1, 0.3)])
    chomp = (0.5 + 0.5 * s(t, 9)) * ease((dart - 0.6) / 0.4)
    bend(p, side=swim(t, 0.02), lift=arch(-2.0 * dart), steady_head=False)
    add(p, "hips", rx=-0.22 * dart)
    add(p, "head", rx=-0.3 * dart - 0.1 * chomp)
    for i in range(zephyrak.TAIL_N):
        add(p, "tail%d" % (i + 1), rx=0.05 * dart)
    p["root_at"] = (0, -0.04 * dart, -0.02 * dart)
    beat(p, t, 3, 0.14, lift=0.25)
    fins(p, back=0.2 + 0.2 * dart, flick=0.15 * chomp)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans its head into the hand, eyes shut, the tail wiggling fast."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    bend(p, side=lambda z: 0.25 * min(z - SPINE[1][2], 0.0) * -lean)
    add(p, "neck", rx=0.08 + lean * 0.05, rz=0.1 * lean)
    add(p, "head", rx=LOOK_UP * 0.6 + lean * 0.06, rz=0.22 + lean * 0.18, ry=0.12 * lean)
    for i in range(zephyrak.TAIL_N):
        k = 0.3 + 0.7 * i / (zephyrak.TAIL_N - 1)
        add(p, "tail%d" % (i + 1), ry=0.26 * k * math.sin(TAU * (4 * t - i * 0.1)))
    p["root_at"] = (0, -0.01 + 0.01 * lean, 0)
    wings(p, flap=-0.12, sweep=0.35 + 0.1 * lean, tip=0.1)
    fins(p, back=0.55, flick=-0.1)
    return p


def attack(t):
    """A lunge bite: draws back into an S, shoots forward with the wings swept, snaps, settles."""
    p = {}
    wind = seq(t, [(0, 0), (0.3, 1), (0.42, -1), (0.56, -1), (1, 0)])
    back = max(wind, 0)
    out = max(-wind, 0)
    bend(p, side=swim(0.25, 0.06 * back, length=0.45), lift=arch(0.25 * back))
    add(p, "head", rx=0.25 * back - 0.1 * out)
    p["root_at"] = (0, 0.02 * back, 0.1 * back - 0.22 * out)
    wings(p, flap=0.4 * back - 0.05 * out, sweep=0.2 * back + 0.9 * out, tip=0.25 * back)
    fins(p, back=0.3 + 0.5 * out)
    return p


def ability(t):
    """Gale Lance: coils tight and crackles, spears forward spinning with its wings swept, bursts open in a ring."""
    p = {}
    coil = seq(t, [(0, 0), (0.28, 1), (0.36, 0), (1, 0)])
    lance = seq(t, [(0, 0), (0.3, 0), (0.38, 1), (0.6, 1), (0.68, 0), (1, 0)])
    burst = seq(t, [(0, 0), (0.6, 0), (0.68, 1), (0.8, 1), (1, 0)])
    shake = coil * s(t, 14) * 0.5
    bend(p, side=swim(0.25, 0.08 * coil, length=0.4), lift=arch(0.3 * coil + 0.8 * burst, 0.6 * burst))
    add(p, "hips", ry=0.08 * shake, rx=0.1 * coil)
    p["root_at"] = (0, -0.03 * coil + 0.05 * burst, 0.08 * coil - 0.16 * lance - 0.1 * burst)
    p["root_sc"] = (1 - 0.06 * coil + 0.08 * burst, 1 - 0.1 * coil + 0.06 * burst, 1 + 0.12 * lance - 0.04 * burst)
    _roll(p, TAU * seq(t, [(0, 0), (0.34, 0), (0.62, 1), (1, 1)]), 0.24)
    add(p, "head", rx=0.2 * coil - 0.15 * lance + 0.25 * burst)
    wings(p, flap=-0.2 * coil + 0.75 * burst + 0.1 * burst * s(t, 6), sweep=0.4 * coil + 1.0 * lance - 0.25 * burst,
          tip=0.3 * burst)
    fins(p, back=0.4 * coil + 0.8 * lance - 0.2 * burst, flick=0.3 * shake)
    return p


def mouth_tool(t, keys, tool, rear, dip):
    """A tool in its teeth: rears its front up off the tail, then brings the whole head down on the work."""
    p = {}
    v = seq(t, keys)
    up = max(v, 0)
    down = max(-v, 0)
    bend(p, side=swim(t, 0.015), lift=arch(3.0 * (rear * up - dip * down), z0=MID_Z + 0.02), steady_head=False)
    add(p, "head", rx=LOOK_UP * 0.4 + up * 0.25 - down * dip * 1.2)
    for i in range(zephyrak.TAIL_N):
        add(p, "tail%d" % (i + 1), rx=-0.06 * up + 0.05 * down)
    p["root_at"] = (0, 0.02 * up - 0.02 * down, 0.03 * up - 0.03 * down)
    wings(p, flap=0.35 * up - 0.1 * down, sweep=0.2 + 0.3 * down, tip=0.2 * up)
    fins(p, back=0.3 + 0.3 * down)
    p[tool] = "on"
    return p


def chop(t):
    return mouth_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.5, 0.35)


def mine(t):
    return mouth_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.4, 0.45)


def carry(t):
    """Swims home with the load riding on its back between the wings, head up and pleased."""
    p = {}
    bend(p, side=swim(t, 0.025, grow=0.9), lift=swim(t * 2, 0.008, length=0.5))
    p["root_at"] = (0, 0.012 * s(t, 2, 0.15), 0)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.1 + 0.03 * s(t, 2))
    fins(p, back=0.25, flick=0.1 * s(t, 2))
    add(p, "hips", rx=0.04)
    beat(p, t, 2, 0.12, sweep=0.35, lift=0.05)
    return p


def tend(t):
    """Any other farm job: nose down over the work, nudging it, tail ticking along."""
    p = {}
    bob = s(t, 2)
    bend(p, side=swim(t, 0.025), lift=arch(-0.9), steady_head=False)
    add(p, "head", rx=-0.2 + bob * 0.08, ry=0.12 * s(t, 1))
    p["root_at"] = (0, -0.015 + 0.006 * bob, 0)
    beat(p, t, 2, 0.1, lift=0.15)
    fins(p, back=0.2, flick=0.1 * bob)
    return p


def win(t):
    """A spring: coils low, shoots up with the head high and the wings thrown wide, then rides down proud."""
    p = {}
    crouch = seq(t, [(0, 0), (0.15, 1), (0.25, 0), (1, 0)])
    air = seq(t, [(0, 0), (0.2, 0), (0.4, 1), (0.62, 0.2), (1, 0)])
    proud = seq(t, [(0, 0), (0.55, 0), (0.7, 1), (0.9, 1), (1, 0.7)])
    bend(p, side=swim(t, 0.03 * proud + 0.05 * air, waves=2), lift=arch(0.7 * air + 0.25 * proud - 0.5 * crouch))
    p["root_at"] = (0, 0.12 * air - 0.03 * crouch, 0)
    add(p, "head", rx=0.2 * air + 0.15 * proud)
    wings(p, flap=0.15 + 0.7 * air + 0.2 * proud - 0.1 * crouch, sweep=0.2 * crouch, tip=0.3 * air * s(t, 3))
    fins(p, back=0.0, flick=0.5 * (air + proud))
    return p


def sulk(t):
    """Low and turned away: the head hangs, the wings droop, the fins lie flat, a sigh now and then."""
    p = {}
    sigh = 0.5 + 0.5 * s(t, 1, -0.25)
    peek = seq(t, [(0, 0), (0.5, 0), (0.58, 1), (0.72, 1), (0.8, 0), (1, 0)])
    bend(p, side=swim(t, 0.03, waves=0.5), lift=arch(-0.8 - 0.1 * sigh))
    p["root_at"] = (0, -0.045 - 0.004 * sigh, 0)
    add(p, "root", ry=0.4 * (1 - 0.7 * peek))
    add(p, "head", rx=-0.3 + 0.12 * peek, ry=0.35 * (1 - 1.5 * peek))
    wings(p, flap=-0.35 - 0.04 * sigh, sweep=0.55, tip=-0.3)
    fins(p, back=0.9, flick=-0.2)
    return p


def push(t):
    """Braced and driving: the body straight and low, leaning into it, wings swept back and beating short."""
    p = {}
    thrust = 0.5 + 0.5 * s(t, 1, -0.25)
    bend(p, side=swim(t, 0.012, waves=2), lift=arch(-0.25 - 0.1 * thrust, 0.35))
    p["root_at"] = (0, -0.02, -0.06 * thrust)
    add(p, "head", rx=-0.15 - 0.05 * thrust)
    wings(p, flap=0.1 + 0.15 * thrust, sweep=0.9, tip=-0.1 + 0.2 * thrust, twist=-0.1)
    fins(p, back=0.8)
    return p


CLIPS = {
    "idle": (2.8, True, idle), "walk": (0.9, True, walk), "run": (0.5, True, run), "hop": (1.1, True, hop),
    "sleep": (3.4, True, sleep), "eat": (2.0, True, eat), "pet": (2.2, True, pet), "attack": (0.8, False, attack),
    "ability": (1.2, False, ability), "chop": (1.1, True, chop), "mine": (1.0, True, mine), "carry": (0.9, True, carry),
    "tend": (1.3, True, tend), "win": (1.0, False, win), "sulk": (2.8, True, sulk), "push": (0.9, True, push),
}
HIDE_AT = {"prop_berry": (0, 0.15, 0.62)}

"""Echolop's skeleton and clips: a hare's hopping gait, ears that never keep still, wings that flare."""
import math

import boki_clips
import echolop
from boki_clips import LOOK_UP, add, s, seq
from echolop import EAR_PTS, SIDES, TAIL_PTS, WING_UV, mirror, wing_at

boki_clips.TAIL_N = 2


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.22, 0.11), (0, 0.225, 0.0), "root"),
        "spine": ((0, 0.225, 0.0), (0, 0.25, -0.08), "hips"),
        "neck": ((0, 0.28, -0.07), (0, 0.37, -0.12), "spine"),
        "head": ((0, 0.37, -0.12), (0, 0.52, -0.15), "neck"),
        "tail1": (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips"),
        "tail2": (tuple(TAIL_PTS[1]), tuple(TAIL_PTS[2]), "tail1"),
    }
    for sd, sx in SIDES:
        pts = [tuple(mirror(p, sx)) for p in EAR_PTS]
        b["ear1." + sd] = (pts[0], pts[1], "head")
        b["ear2." + sd] = (pts[1], pts[2], "ear1." + sd)
        b["ear3." + sd] = (pts[2], pts[3], "ear2." + sd)
        wrist = tuple(wing_at(sx, WING_UV["W"]))
        b["wing1." + sd] = (tuple(wing_at(sx, WING_UV["S"])), wrist, "spine")
        b["wing2." + sd] = (wrist, tuple(wing_at(sx, WING_UV["T2"])), "wing1." + sd)
        b["fleg1." + sd] = ((sx * 0.072, 0.23, -0.10), (sx * 0.078, 0.12, -0.115), "spine")
        b["fleg2." + sd] = ((sx * 0.078, 0.12, -0.115), (sx * 0.080, 0.042, -0.125), "fleg1." + sd)
        b["fpaw." + sd] = ((sx * 0.080, 0.042, -0.125), (sx * 0.082, 0.02, -0.19), "fleg2." + sd)
        b["hleg1." + sd] = ((sx * 0.105, 0.20, 0.11), (sx * 0.112, 0.105, 0.06), "hips")
        b["hleg2." + sd] = ((sx * 0.112, 0.105, 0.06), (sx * 0.115, 0.04, 0.15), "hleg1." + sd)
        b["hpaw." + sd] = ((sx * 0.115, 0.04, 0.15), (sx * 0.115, 0.02, -0.03), "hleg2." + sd)
    grip = tuple(echolop.GRIP)
    tip = tuple(echolop.GRIP + echolop.AXIS * 0.1)
    b["prop_axe"] = (grip, tip, "fleg2.R")
    b["prop_pick"] = (grip, tip, "fleg2.R")
    b["prop_berry"] = (tuple(echolop.BERRY_C), tuple(echolop.BERRY_C + echolop.v3(0, 0.1, 0)), "fleg2.R")
    b.update(boki_clips.part_bones(echolop.grown_parts()))
    return b


BONES = _bones()
HEEL = (0.03, 0.15)        # (y, z) the body rocks about when it sits up on its haunches


def lift(p, x=0.0, y=0.0, z=0.0):
    o = p.get("root_at", (0, 0, 0))
    p["root_at"] = (o[0] + x, o[1] + y, o[2] + z)


def sit_up(p, th, look=1.0):
    """Rears onto its haunches by th (rad) about the heels, the long feet kept flat, the head kept on you."""
    add(p, "root", rx=th)
    y, z = HEEL
    lift(p, y=y * (1 - math.cos(th)) + z * math.sin(th), z=z * (1 - math.cos(th)) - y * math.sin(th))
    for sd, _ in SIDES:
        add(p, "hleg1." + sd, rx=-th * 0.55)
        add(p, "hleg2." + sd, rx=th * 0.2)
        add(p, "hpaw." + sd, rx=-th * 0.65)
    add(p, "neck", rx=-th * 0.35 * look)
    add(p, "head", rx=-th * 0.4 * look)


def ears(p, back=0.0, out=0.0, curl=0.0, turn=(0.0, 0.0), lag=None):
    """Both ears: tipped back, spread, the tips curled back (or flicked forward if < 0), each swivelled on its own.
    `lag` (L, R) adds a wave that runs up each ear a beat late: follow-through after the body moves."""
    for i, (sd, sx) in enumerate(SIDES):
        w = lag[i] if lag else 0.0
        add(p, "ear1." + sd, rx=back + w * 0.4, rz=-sx * out, ry=turn[i])
        add(p, "ear2." + sd, rx=back * 0.3 + curl * 0.5 + w * 0.8)
        add(p, "ear3." + sd, rx=back * 0.2 + curl + w * 1.1)


def wings(p, open_=0.0, lift_=0.0, flutter=0.0):
    """open_ 0 folded on the back .. 1 spread wide; lift_ raises them; flutter beats the fingers.
    Spreading rolls the web down under the arm, raises the arm and swings it out to the side."""
    for sd, sx in SIDES:
        add(p, "wing1." + sd, rz=-sx * 0.72 * open_, rx=-0.4 * open_ - lift_, ry=sx * 1.35 * open_)
        add(p, "wing2." + sd, ry=sx * 0.3 * open_, rz=sx * flutter)


def tail(p, t, amp=0.15, rate=2.0, up=0.0):
    add(p, "tail1", rx=up + amp * s(t, rate), ry=amp * 0.6 * s(t, rate, 0.25))
    add(p, "tail2", rx=amp * 0.6 * s(t, rate, -0.1))


def idle(t):
    """Sits and listens: one ear swivels to a sound, then the other; the nose twitches; the wings breathe."""
    p = {}
    br = s(t, 2)
    add(p, "spine", rx=br * 0.02)
    add(p, "neck", rx=-br * 0.01, ry=s(t, 1) * 0.05)
    twitch = seq(t, [(0, 0), (0.12, 0), (0.15, 1), (0.18, 0), (0.21, 1), (0.24, 0), (1, 0)])
    look = seq(t, [(0, 0), (0.3, 0), (0.4, 1), (0.62, 1), (0.72, 0), (1, 0)])
    add(p, "head", rx=LOOK_UP + br * 0.03 + twitch * 0.04, ry=0.16 * look + s(t, 1, 0.1) * 0.04, rz=-0.08 * look)
    lift(p, y=-0.004 + br * 0.003)
    p["root_sc"] = (1 - br * 0.012, 1 + br * 0.018, 1)
    left = seq(t, [(0, 0), (0.28, 0), (0.36, 1), (0.66, 1), (0.74, 0), (1, 0)])
    right = seq(t, [(0, 0), (0.05, 0), (0.12, -0.6), (0.2, -0.6), (0.27, 0), (0.78, 0), (0.84, 0.8), (0.9, 0.8),
                    (0.96, 0), (1, 0)])
    flick = seq(t, [(0, 0), (0.5, 0), (0.53, 1), (0.56, 0), (1, 0)])
    ears(p, back=-0.04 + br * 0.03, out=0.04, curl=0.06 - 0.05 * left, turn=(-0.7 * left, 0.6 * right),
         lag=(0.0, 0.25 * flick))
    wings(p, open_=0.04 + br * 0.03)
    tail(p, t, 0.08, 4)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=br * 0.012)
    return p


FORE = [(0, -0.5), (0.15, -0.3), (0.45, 0.75), (0.68, 0.3), (0.85, -0.5), (1, -0.5)]
TRAIL = [(0, -0.3), (0.2, 0.5), (0.6, 0.6), (0.8, -0.5), (1, -0.3)]      # the ears' lag behind a leap


def bound(t, height, reach, stretch):
    """One leap of a hare's gait, t 0..1: push off the long hind feet, fly with the forepaws reaching, land on the
    forepaws and swing the hind feet in past them, squash, go again. Ears and wings trail a beat behind."""
    p = {}
    air = max(0.0, math.sin(math.pi * min(max((t - 0.08) / 0.6, 0.0), 1.0)))
    push = seq(t, [(0, 0.3), (0.1, 1), (0.3, 0.2), (0.5, -0.4), (0.72, -0.9), (0.86, -0.4), (1, 0.3)])
    pitch = seq(t, [(0, 0), (0.12, 0.16), (0.4, 0.0), (0.68, -0.2), (0.82, -0.05), (1, 0)])
    land = seq(t, [(0, 0.6), (0.06, 0), (0.7, 0), (0.76, 0.5), (0.86, 1), (1, 0.6)])
    lift(p, y=height * air - 0.012 * land, z=-0.02 * reach * s(t, 1, 0.1))
    p["root_sc"] = (1 + 0.08 * land, 1 - 0.12 * land + 0.06 * air, 1 + 0.05 * land - 0.04 * air)
    add(p, "root", rx=pitch)
    add(p, "hips", rx=-stretch * push * 0.35)
    add(p, "spine", rx=stretch * push * 0.25)
    add(p, "neck", rx=-pitch * 0.5)
    add(p, "head", rx=LOOK_UP * 0.6 - pitch * 0.5)
    hind = seq(t, [(0, 0.2), (0.12, -0.9), (0.3, -0.6), (0.55, 0.5), (0.8, 0.8), (1, 0.2)])
    for sd, sx in SIDES:
        off = 0.04 if sd == "R" else 0.0
        f = seq((t - off) % 1.0, FORE)
        add(p, "fleg1." + sd, rx=f * reach)
        add(p, "fleg2." + sd, rx=-max(0.0, f) * 0.6 * reach)
        add(p, "fpaw." + sd, rx=-f * 0.4)
        add(p, "hleg1." + sd, rx=hind * reach)
        add(p, "hleg2." + sd, rx=-min(0.0, hind) * 0.5 * reach)
        add(p, "hpaw." + sd, rx=-hind * 0.6 * reach)
    trail = (seq((t - 0.1) % 1.0, TRAIL) * 0.3, seq((t - 0.14) % 1.0, TRAIL) * 0.3)
    ears(p, back=0.25 * reach + 0.15 * stretch, out=0.05, curl=0.1, lag=trail)
    wings(p, open_=0.08 + 0.3 * stretch * air, lift_=0.12 * air * stretch, flutter=0.1 * stretch * s(t, 2))
    add(p, "tail1", rx=0.3 * air - 0.2 * land)
    return p


def walk(t):
    """Little hops, two to a cycle."""
    return bound((t * 2) % 1.0, 0.04, 0.55, 0.2)


def run(t):
    """Bounding leaps: long and low, the body stretched out in the air and bunched on landing, ears streaming."""
    p = bound(t, 0.1, 1.45, 1.0)
    ears(p, back=0.2, curl=0.15)
    return p


def carry(t):
    """Little hops with the load on its back, head up, ears pricked."""
    p = bound((t * 2) % 1.0, 0.03, 0.45, 0.1)
    add(p, "head", rx=0.08)
    ears(p, back=-0.15)
    return p


def attack(t):
    """Boxes: rears up on its haunches, ears pinned, and lands a left-right one-two with the forepaws."""
    p = {}
    up = seq(t, [(0, 0), (0.1, -0.25), (0.26, 1), (0.66, 1), (0.82, -0.3), (1, 0)])
    sit_up(p, 0.75 * max(up, 0.0))
    lift(p, y=-0.03 * max(-up, 0.0), z=-0.06 * seq(t, [(0, 0), (0.3, 0), (0.4, 1), (0.6, 1), (0.75, 0)]))
    p["root_sc"] = (1 + 0.1 * max(-up, 0.0), 1 - 0.14 * max(-up, 0.0), 1)
    jab = {"L": seq(t, [(0, 0), (0.3, 0), (0.36, 1), (0.44, 0.1), (1, 0)]),
           "R": seq(t, [(0, 0), (0.42, 0), (0.48, 1), (0.56, 0.1), (1, 0)])}
    guard = max(up, 0.0)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=guard * (0.9 + 0.7 * jab[sd]), rz=sx * 0.15 * guard)
        add(p, "fleg2." + sd, rx=-guard * 1.1 * (1 - jab[sd]))
        add(p, "fpaw." + sd, rx=-0.3 * guard)
    add(p, "spine", ry=0.12 * (jab["R"] - jab["L"]))
    add(p, "head", ry=-0.08 * (jab["R"] - jab["L"]), rx=-0.12 * guard)
    ears(p, back=0.2 + 1.0 * guard, out=0.12 * guard, curl=0.15, lag=(0.2 * jab["L"], 0.2 * jab["R"]))
    wings(p, open_=0.25 * guard, lift_=0.1 * guard)
    tail(p, t, 0.1, 3, up=0.2 * guard)
    return p


def ability(t):
    """Echo pulse: gathers in low, ears and wings folded tight; then rises with its chest out, ears shooting up and
    apart, wings flung open, and rings: everything shivers with the pulse, then settles."""
    p = {}
    gather = seq(t, [(0, 0), (0.28, 1), (0.36, 0), (1, 0)])
    burst = seq(t, [(0, 0), (0.3, 0), (0.4, 1), (0.74, 1), (1, 0)])
    ring = burst * s(t, 14) * seq(t, [(0, 0), (0.4, 1), (0.75, 0.3), (1, 0)])
    sit_up(p, 0.42 * burst, look=0.5)
    lift(p, y=-0.035 * gather + 0.02 * burst)
    p["root_sc"] = (1 + 0.1 * gather + 0.04 * burst, 1 - 0.14 * gather + 0.06 * burst, 1 + 0.04 * gather)
    add(p, "spine", rx=0.18 * burst - 0.1 * gather)
    add(p, "neck", rx=0.1 * burst - 0.15 * gather)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.12 * burst - 0.2 * gather + 0.02 * ring)
    ears(p, back=0.9 * gather - 0.3 * burst, out=0.32 * burst - 0.1 * gather, curl=0.3 * gather - 0.2 * burst,
         lag=(0.12 * ring, -0.12 * ring))
    wings(p, open_=1.0 * burst, lift_=0.5 * burst, flutter=0.12 * ring)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.6 * burst, rz=sx * 0.25 * burst)
        add(p, "fleg2." + sd, rx=-0.7 * burst)
    tail(p, t, 0.06, 3, up=0.3 * burst)
    return p


def hop(t):
    """A happy binky: crouch, spring straight up with a twist and a flick of the hind feet, ears flung, wings out."""
    p = {}
    air = seq(t, [(0, 0), (0.16, -0.6), (0.28, 0.25), (0.46, 1), (0.64, 0.25), (0.74, -0.5), (1, 0)])
    up = max(air, 0.0)
    down = max(-air, 0.0)
    twist = seq(t, [(0, 0), (0.28, 0), (0.42, 1), (0.6, -0.3), (0.72, 0), (1, 0)])
    lift(p, y=0.2 * up - 0.06 * down)
    p["root_sc"] = (1 + 0.14 * down - 0.05 * up, 1 - 0.2 * down + 0.1 * up, 1 + 0.06 * down)
    add(p, "root", ry=0.45 * twist, rz=-0.25 * twist, rx=0.15 * up)
    add(p, "hips", ry=-0.5 * twist, rz=0.2 * twist)
    add(p, "head", rx=LOOK_UP * 0.6 + 0.1 * up - 0.12 * down, rz=0.12 * twist)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.5 * up - 0.2 * down)
        add(p, "fleg2." + sd, rx=-0.7 * up)
        add(p, "hleg1." + sd, rx=-0.7 * up + 0.3 * down, rz=sx * 0.35 * twist)
        add(p, "hleg2." + sd, rx=0.4 * up)
        add(p, "hpaw." + sd, rx=0.5 * up)
    fling = (seq((t - 0.06) % 1.0, FLING), seq((t - 0.1) % 1.0, FLING))
    ears(p, back=0.1 + 0.4 * down - 0.2 * up, out=0.35 * up + 0.15 * down, lag=fling)
    wings(p, open_=0.9 * up, lift_=0.4 * up, flutter=0.15 * up * s(t, 4))
    tail(p, t, 0.15, 4, up=0.2 * up)
    return p


FLING = [(0, 0), (0.2, -0.3), (0.4, 0.7), (0.6, -0.4), (0.78, 0.5), (0.9, -0.1), (1, 0)]      # ears after a binky


def sleep(t):
    """A loaf: legs tucked under, chin down, the long ears laid flat along its back, breathing slow."""
    br = s(t, 1)
    p = {}
    lift(p, y=-0.095)
    p["root_sc"] = (1.04 + br * 0.02, 1 + br * 0.03, 1)
    add(p, "spine", rx=-0.06)
    add(p, "neck", rx=-0.35)
    add(p, "head", rx=-0.05 + br * 0.03, rz=0.08)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.35)
        add(p, "fleg2." + sd, rx=-2.2)
        add(p, "fpaw." + sd, rx=0.8)
        add(p, "hleg1." + sd, rx=0.75, rz=-sx * 0.12)
        add(p, "hleg2." + sd, rx=-1.2)
        add(p, "hpaw." + sd, rx=0.45)
    ears(p, back=1.3, out=0.15, curl=0.25 + br * 0.03)
    wings(p, open_=-0.05)
    add(p, "tail1", rx=-0.2)
    return p


def eat(t):
    """Sits up with the berry in both forepaws and nibbles it fast, ears easy, a pause to chew."""
    p = {}
    nib = seq(t, [(0, 0), (0.5, 1), (0.62, 0), (1, 0)]) * (0.5 + 0.5 * s(t, 9))
    sit_up(p, 0.55, look=0.3)
    add(p, "neck", rx=-0.1)
    add(p, "head", rx=-0.25 - nib * 0.07)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.35, rz=sx * 0.05)
        add(p, "fleg2." + sd, rx=-1.4)
        add(p, "fpaw." + sd, rx=-0.4)
    ears(p, back=0.15, out=0.12, curl=0.15, turn=(0.2 * s(t, 1), -0.2 * s(t, 1, 0.3)), lag=(0.1 * nib, 0.0))
    wings(p, open_=0.03)
    tail(p, t, 0.06, 2)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Melts into the hand: ears laid back, eyes shut, leaning in, the tail going."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    lift(p, y=-0.02 - 0.01 * lean)
    add(p, "neck", rx=0.08 + lean * 0.05, rz=lean * 0.08)
    add(p, "head", rx=LOOK_UP * 0.5 + lean * 0.06, rz=0.14 + lean * 0.16, ry=lean * 0.08)
    ears(p, back=0.95 - lean * 0.15, out=0.25, curl=0.2)
    wings(p, open_=0.05 + 0.05 * lean)
    tail(p, t, 0.18, 3)
    for sd, _ in SIDES:
        add(p, "hleg1." + sd, rx=0.15)
        add(p, "hleg2." + sd, rx=-0.2)
        add(p, "fleg1." + sd, rx=0.1)
    return p


def paw_tool(t, keys, tool, high, low, lean):
    """Sits up with the tool in both forepaws: up over its head, then down on the work with its weight behind it."""
    p = {}
    v = seq(t, keys)
    up = max(v, 0.0)
    down = max(-v, 0.0)
    sit_up(p, 0.62 + 0.18 * up - lean * down, look=0.6)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.0 + high * up - low * down, rz=sx * 0.06)
        add(p, "fleg2." + sd, rx=-0.5 * up - 0.2 * down)
    add(p, "spine", rx=0.12 * up - 0.15 * down)
    add(p, "head", rx=-0.15 * down)
    lift(p, y=-0.02 * down)
    jolt = seq(t, [(0, 0), (0.5, 0), (0.54, 1), (0.7, 0), (1, 0)])
    ears(p, back=0.1 - 0.3 * down + 0.3 * up, out=0.1, lag=(0.5 * jolt, 0.6 * jolt))
    wings(p, open_=0.2 * up, lift_=0.1 * up)
    tail(p, t, 0.05, 2)
    p[tool] = "on"
    return p


def chop(t):
    return paw_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 1.3, 0.45, 0.27)


def mine(t):
    return paw_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 1.4, 0.5, 0.32)


def tend(t):
    """Nose down over the work, patting the soil with one forepaw then the other, ears turning to listen."""
    p = {}
    bob = s(t, 2)
    add(p, "spine", rx=-0.2)
    add(p, "neck", rx=-0.35 + bob * 0.03)
    add(p, "head", rx=-0.12 + bob * 0.05, ry=s(t, 1) * 0.1)
    lift(p, y=-0.02 + bob * 0.005)
    for sd, _ in SIDES:
        ph = 0.0 if sd == "L" else 0.5
        pat = max(0.0, s(t, 2, ph))
        add(p, "fleg1." + sd, rx=0.45 * pat)
        add(p, "fleg2." + sd, rx=-0.6 * pat)
        add(p, "fpaw." + sd, rx=0.3 * pat)
    ears(p, back=0.15, out=0.08, turn=(-0.4 * s(t, 1), 0.4 * s(t, 1, 0.2)), lag=(0.1 * bob, -0.1 * bob))
    wings(p, open_=0.05)
    tail(p, t, 0.12, 4)
    return p


CLIPS = {
    "idle": (2.8, True, idle), "walk": (0.7, True, walk), "run": (0.44, True, run), "attack": (0.8, False, attack),
    "ability": (1.1, False, ability), "hop": (0.95, True, hop), "sleep": (3.4, True, sleep), "eat": (2.0, True, eat),
    "pet": (2.2, True, pet), "chop": (1.1, True, chop), "mine": (1.0, True, mine), "carry": (0.8, True, carry),
    "tend": (1.3, True, tend),
}
# unused props tucked inside the right foreleg they ride (m from their rest place), so no pose shows their ink
import boki_react
CLIPS.update(boki_react.react())
HIDE_AT = {"prop_axe": (0.079, 0.04, 0.05), "prop_pick": (0.079, 0.04, 0.05), "prop_berry": (0.079, 0.01, 0.08)}

"""Lunowl's skeleton and clips: a two-legged owl with moth wings, so every clip is its own."""
import math

import boki_clips
import lunowl
from boki_clips import add, s, seq
from lunowl import SIDES, TAIL_PTS, antenna_pts, on_wing, streamer_pts, v3

LOOK_UP = 0.22     # its face is already a flat disc to the front: a little tilt up is enough for the high cameras


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.16, 0.02), (0, 0.28, 0.0), "root"),
        "spine": ((0, 0.28, 0.0), (0, 0.36, -0.02), "hips"),
        "neck": ((0, 0.36, -0.02), (0, 0.40, -0.03), "spine"),
        "head": ((0, 0.40, -0.03), (0, 0.58, -0.05), "neck"),
        "tail1": (tuple(TAIL_PTS[0]), tuple(TAIL_PTS[1]), "hips"),
        "prop_axe": (tuple(lunowl.GRIP), tuple(lunowl.GRIP + lunowl.AXIS * 0.1), "head"),
        "prop_pick": (tuple(lunowl.GRIP), tuple(lunowl.GRIP + lunowl.AXIS * 0.1), "head"),
        "prop_berry": (tuple(lunowl.BERRY_C), tuple(lunowl.BERRY_C + v3(0, 0.1, 0)), "root"),
    }
    for sd, sx in SIDES:
        a, _, c = antenna_pts(sx)
        b["ear1." + sd] = ((sx * 0.12, 0.565, -0.075), (sx * 0.215, 0.70, -0.04), "head")
        b["ant." + sd] = (tuple(a), tuple(c), "head")
        b["fwing." + sd] = (tuple(on_wing(sx, 0, 0)), tuple(on_wing(sx, 0.12, 0)), "spine")
        b["hwing." + sd] = (tuple(on_wing(sx, 0.0, 0.06)), tuple(on_wing(sx, 0.07, 0.15)), "fwing." + sd)
        pts = streamer_pts(sx)
        b["strm1." + sd] = (tuple(pts[0]), tuple(pts[1]), "hwing." + sd)
        b["strm2." + sd] = (tuple(pts[1]), tuple(pts[3]), "strm1." + sd)
        for bone, ws, wc, _ in lunowl.EYESPOTS:
            parent = "hwing." if bone == "prop_dazzleh." else "fwing."
            b[bone + sd] = (tuple(on_wing(sx, ws, wc)), tuple(on_wing(sx, ws + 0.1, wc)), parent + sd)
        knee = (sx * 0.09, 0.075, -0.015)
        ankle = (sx * 0.092, 0.026, -0.02)
        b["hleg1." + sd] = ((sx * 0.085, 0.15, 0.0), knee, "root")
        b["hleg2." + sd] = (knee, ankle, "hleg1." + sd)
        b["hpaw." + sd] = (ankle, (sx * 0.093, 0.012, -0.09), "hleg2." + sd)
    b.update(boki_clips.part_bones(lunowl.grown_parts()))
    return b


BONES = _bones()


# ---------------------------------------------------------------- body-part helpers
def wings(p, lift=0.0, fwd=0.0, pitch=0.0, hind=0.0):
    """Both wings from the shoulder: `lift` raises the tips over the back (below 0 spreads and lowers them), `fwd`
    swings them forward, `pitch` tips the trailing edge down; `hind` lifts the hind wing on its own (follow-through)."""
    for sd, sx in SIDES:
        add(p, "fwing." + sd, rx=pitch, ry=sx * fwd, rz=sx * lift)
        add(p, "hwing." + sd, rz=sx * hind)


def flap(p, t, n, amp, lift=0.0, fwd=0.0, ph=0.0):
    """Wing beats: n per clip, the hind wing and the tails a beat behind."""
    wings(p, lift + amp * s(t, n, ph), fwd, 0.0, amp * 0.35 * s(t, n, ph - 0.12))
    streamers(p, t * n, amp * 0.5, ph + 0.25)


def streamers(p, phase, amp, ph=0.0, droop=0.0):
    """The long moth tails swing after whatever the wings do."""
    for sd, sx in SIDES:
        add(p, "strm1." + sd, rx=droop * 0.5 + amp * math.sin(math.tau * (phase - ph)))
        add(p, "strm2." + sd, rx=droop * 0.5 + amp * 1.4 * math.sin(math.tau * (phase - ph - 0.12)))


def look(p, k=1.0):
    """Tips the face up toward the camera over the neck and the head, so the round back of the head never creases."""
    add(p, "neck", rx=LOOK_UP * k * 0.45)
    add(p, "head", rx=LOOK_UP * k * 0.55)


def tufts(p, back=0.0, out=0.0):
    for sd, sx in SIDES:
        add(p, "ear1." + sd, rx=back, rz=-sx * out)


def feelers(p, phase, amp, back=0.0):
    """The feathery antennae bob a little after the head."""
    for sd, sx in SIDES:
        add(p, "ant." + sd, rx=back + amp * math.sin(math.tau * (phase - 0.1)),
            rz=sx * amp * 0.5 * math.sin(math.tau * phase))


def legs(p, sd, swing=0.0, lift=0.0):
    """One leg: `swing` forward from the hip, `lift` folds the shank up behind it and curls the toes."""
    add(p, "hleg1." + sd, rx=swing + lift * 0.5)
    add(p, "hleg2." + sd, rx=-lift * 1.1)
    add(p, "hpaw." + sd, rx=lift * 0.5 - swing * 0.6)


def tuck_legs(p, k):
    for sd, _ in SIDES:
        legs(p, sd, -0.3 * k, 0.9 * k)


# ---------------------------------------------------------------- clips
def idle(t):
    """Breathes, fluffs, and turns its head the owl's way: a quick swivel, a held stare, a curious tilt."""
    p = {}
    br = s(t, 2)
    p["root_sc"] = (1 + br * 0.012, 1 + br * 0.018, 1 + br * 0.012)
    add(p, "hips", rx=br * 0.015)
    turn = seq(t, [(0, 0), (0.3, 0), (0.36, 0.55), (0.56, 0.55), (0.62, -0.2), (0.78, -0.2), (0.84, 0), (1, 0)])
    tilt = seq(t, [(0, 0), (0.4, 0), (0.46, 0.22), (0.54, 0.22), (0.6, 0), (1, 0)])
    add(p, "neck", ry=turn * 0.6)
    look(p)
    add(p, "head", rx=br * 0.02, ry=turn * 0.4, rz=tilt)
    shuffle = seq(t, [(0, 0), (0.86, 0), (0.9, 1), (0.95, -0.4), (1, 0)])
    wings(p, br * 0.02 + shuffle * 0.18, hind=shuffle * 0.1)
    streamers(p, t * 2, 0.04, droop=shuffle * -0.1)
    tufts(p, 0.03 + tilt * 0.2, tilt * 0.15)
    feelers(p, t * 2, 0.06 + tilt * 0.1)
    return p


def waddle(t, roll, lift, step):
    """Two steps a cycle, rocking onto each foot."""
    p = {}
    sw = s(t, 1)
    add(p, "hips", rx=-0.06, rz=sw * roll)
    look(p)
    add(p, "head", rz=-sw * roll * 0.7)
    p["root_at"] = (0, abs(s(t, 1)) * 0.014 - 0.004, 0)
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        a = s(t, 1, ph)
        legs(p, sd, a * step, max(0.0, s(t, 1, ph + 0.25)) * lift)
    tufts(p, 0.08, 0.03)
    feelers(p, t * 2, 0.08, 0.1)
    return p


def walk(t):
    p = waddle(t, 0.14, 0.7, 0.42)
    flap(p, t, 2, 0.05, -0.08)
    return p


def run(t):
    """A skittering flit: a kick off the ground, a glide on two quick beats with the legs tucked, a light touch-down."""
    p = {}
    air = seq(t, [(0, 0), (0.12, 0), (0.5, 1), (0.86, 0), (1, 0)])
    land = seq(t, [(0, 1), (0.1, 0), (0.88, 0), (1, 1)])
    p["root_at"] = (0, 0.11 * air - 0.012 * land, 0)
    p["root_sc"] = (1 + 0.06 * land, 1 - 0.08 * land + 0.04 * air, 1 + 0.04 * land)
    add(p, "hips", rx=-0.32 - 0.06 * land)
    add(p, "neck", rx=0.12)
    look(p, 1.4 + 0.2 * land)
    flap(p, t, 2, 0.6, -0.3, ph=0.15)
    streamers(p, t * 2, 0.06, droop=-0.7)
    tufts(p, 0.35, 0.05)
    feelers(p, t * 2, 0.1, 0.4)
    k = seq(t, [(0, 0), (0.14, 0), (0.24, 1), (0.74, 1), (0.88, 0), (1, 0)])
    for sd, _ in SIDES:
        legs(p, sd, -0.5 * k + 0.25 * land, 1.0 * k)
    add(p, "tail1", rx=-0.15 * air)
    return p


def hop(t):
    """A happy flap-hop: crouch with the wings up, spring, two big beats, a squashy landing."""
    p = {}
    air = seq(t, [(0, 0), (0.18, -0.6), (0.3, 0.2), (0.5, 1), (0.68, 0.2), (0.78, -0.5), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p["root_at"] = (0, 0.2 * up - 0.05 * down, 0)
    p["root_sc"] = (1 + 0.12 * down - 0.04 * up, 1 - 0.17 * down + 0.08 * up, 1 + 0.1 * down)
    look(p, 1 + 0.8 * up - 0.5 * down)
    add(p, "head", rz=s(t, 2) * 0.08)
    beat = seq(t, [(0, 0), (0.24, 0), (0.3, 1), (0.66, 1), (0.74, 0), (1, 0)])
    wings(p, 0.3 * down + beat * 0.7 * s(t, 4, 0.2) - beat * 0.2, hind=beat * 0.25 * s(t, 4, 0.08))
    streamers(p, t * 4, 0.1 * beat + 0.03, droop=-0.4 * up + 0.2 * down)
    tufts(p, -0.2 * up + 0.3 * down, 0.2 * down)
    feelers(p, t * 2, 0.16, -0.2 * up + 0.2 * down)
    tuck_legs(p, up)
    add(p, "tail1", rx=0.3 * up - 0.2 * down)
    return p


def sleep(t):
    """Fluffed into a ball on its belly, head sunk and turned into its shoulder, wings laid over its back."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.075, 0)
    p["root_sc"] = (1.07 + br * 0.015, 0.95 + br * 0.025, 1.05 + br * 0.012)
    for sd, _ in SIDES:
        legs(p, sd, 1.0, 1.4)
    add(p, "hips", rx=-0.08)
    add(p, "neck", rx=-0.12, ry=0.45, rz=0.1)
    add(p, "head", rx=-0.22 + br * 0.02, ry=0.45, rz=0.2)
    wings(p, 0.3, -0.3, 0.4)
    streamers(p, t, 0.01, droop=0.25)
    tufts(p, 0.6, 0.3)
    feelers(p, t, 0.02, 0.8)
    add(p, "tail1", rx=0.3)
    return p


def eat(t):
    """Pecks at a berry on the ground, three quick pecks and a gulp with its head tossed back."""
    p = {}
    peck = seq(t, [(0, 0.3), (0.08, 1), (0.14, 0.55), (0.22, 1), (0.28, 0.55), (0.36, 1), (0.46, 0.4), (0.6, 0),
                   (0.72, -0.4), (0.84, 0), (1, 0.3)])
    dip = max(peck, 0)
    toss = max(-peck, 0)
    add(p, "hips", rx=-0.62 * dip + 0.1 * toss)
    add(p, "neck", rx=-0.28 * dip + 0.25 * toss)
    look(p, 1 - dip)
    add(p, "head", rx=-0.38 * dip + 0.25 * toss, rz=0.1 * toss)
    p["root_at"] = (0, 0, -0.03 * dip)
    wings(p, -0.12 * dip + 0.06 * s(t, 6), 0, 0, 0.06 * dip)
    streamers(p, t * 3, 0.04, droop=-0.2 * dip)
    tufts(p, 0.15 * dip, 0.05)
    feelers(p, t * 3, 0.1)
    p["prop_berry"] = "on"
    return p


def pet(t):
    """Leans up into the hand with its eyes shut, fluffing out, the wings shivering with pleasure."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    fluff = 0.03 + 0.025 * lean
    p["root_sc"] = (1 + fluff, 1 + fluff * 0.3, 1 + fluff)
    add(p, "hips", rz=0.06 * lean)
    add(p, "neck", rx=0.1 + lean * 0.06, rz=0.1 * lean)
    look(p, 1 + 0.3 * lean)
    add(p, "head", rz=0.14 + lean * 0.18, ry=lean * 0.08)
    wings(p, 0.06 + 0.035 * s(t, 9), hind=0.04 * s(t, 9, 0.2))
    streamers(p, t * 3, 0.06)
    tufts(p, 0.45 - lean * 0.15, 0.3)
    feelers(p, t * 2, 0.06, 0.45)
    return p


def beak_tool(t, keys, tool, back, strike):
    """A tool in its beak: rocks back with the wings up, then throws its whole round body forward into the blow."""
    p = {}
    v = seq(t, keys)
    up = max(v, 0)
    down = max(-v, 0)
    add(p, "hips", rx=up * back - down * strike)
    add(p, "neck", rx=up * 0.12 - down * strike * 0.35)
    look(p, 0.5 + up * 0.8)
    add(p, "head", rx=-down * strike * 0.4)
    p["root_at"] = (0, -0.01 * down, 0.03 * up - 0.04 * down)
    wings(p, 0.3 * up - 0.45 * down, 0.25 * down, 0, 0.15 * up - 0.1 * down)
    streamers(p, t * 2, 0.05, droop=-0.3 * down + 0.15 * up)
    for sd, sx in SIDES:
        legs(p, sd, 0.12 * up, 0)
    tufts(p, 0.1 + 0.3 * down, 0.1 * down)
    feelers(p, t * 2, 0.08, 0.3 * down)
    p[tool] = "on"
    return p


def chop(t):
    return beak_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.35, 0.5)


def mine(t):
    return beak_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.3, 0.75)


def carry(t):
    """Waddles with the load balanced on its head, wings held out a little to steady it."""
    p = waddle(t, 0.09, 0.55, 0.34)
    look(p, -0.6)
    flap(p, t, 2, 0.08, 0.1)
    tufts(p, -0.15, 0.25)
    return p


def tend(t):
    """Any other farm job: bent over the work, pecking at it, shifting from foot to foot."""
    p = {}
    bob = max(0.0, s(t, 2))
    add(p, "hips", rx=-0.35 - bob * 0.12, rz=s(t, 1) * 0.06)
    add(p, "neck", rx=-0.15)
    add(p, "head", rx=-bob * 0.25, ry=s(t, 1) * 0.12)
    for sd, ph in (("L", 0.0), ("R", 0.5)):
        legs(p, sd, 0.0, max(0.0, s(t, 1, ph)) * 0.35)
    flap(p, t, 2, 0.04, -0.06)
    tufts(p, 0.15)
    feelers(p, t * 2, 0.1, 0.2)
    return p


def attack(t):
    """A talon pounce: wings mantled high, a spring forward with the feet thrown out, a buffet down, settle."""
    p = {}
    wind = seq(t, [(0, 0), (0.28, 1), (0.38, -1), (0.56, -1), (1, 0)])
    load = max(wind, 0)
    strike = max(-wind, 0)
    p["root_at"] = (0, -0.035 * load + 0.07 * strike, 0.05 * load - 0.2 * strike)
    p["root_sc"] = (1 + 0.08 * load, 1 - 0.1 * load + 0.04 * strike, 1)
    add(p, "hips", rx=0.1 * load + 0.38 * strike)
    look(p, 0.4)
    add(p, "head", rx=-0.3 * strike)
    wings(p, 0.38 * load - 0.6 * strike, 0.35 * strike, 0, 0.2 * load - 0.15 * strike)
    streamers(p, t * 2, 0.06, droop=-0.5 * strike + 0.2 * load)
    for sd, _ in SIDES:
        legs(p, sd, 1.15 * strike - 0.2 * load, 0.3 * load)
        add(p, "hpaw." + sd, rx=0.5 * strike)
    tufts(p, 0.5 * load + 0.2 * strike, 0.1)
    feelers(p, t * 2, 0.08, 0.4)
    return p


def ability(t):
    """Silver dazzle: gathers its wings tight, then flares them wide to the front and the eye-spots blaze."""
    p = {}
    gather = seq(t, [(0, 0), (0.26, 1), (0.36, -1), (0.8, -1), (1, 0)])
    tight = max(gather, 0)
    flare = max(-gather, 0)
    shimmer = 0.03 * s(t, 10) * flare
    p["root_at"] = (0, -0.03 * tight + 0.05 * flare, 0)
    p["root_sc"] = (1 - 0.04 * tight + 0.05 * flare, 1 - 0.06 * tight + 0.04 * flare, 1)
    add(p, "hips", rx=-0.12 * tight + 0.08 * flare)
    look(p, 1 - 0.7 * tight + 0.5 * flare)
    wings(p, 0.3 * tight - 0.6 * flare + shimmer, 0.5 * flare, 0.3 * flare, 0.1 * tight - 0.1 * flare)
    streamers(p, t * 3, 0.05, droop=-0.3 * flare + 0.2 * tight)
    tufts(p, 0.3 * tight - 0.15 * flare, 0.35 * flare)
    feelers(p, t * 3, 0.06, 0.4 * tight - 0.25 * flare)
    if 0.33 < t < 0.86:
        for sd, _ in SIDES:
            p["prop_dazzle." + sd] = "on"
            p["prop_dazzleh." + sd] = "on"
    return p


CLIPS = {"idle": (3.2, True, idle), "walk": (0.56, True, walk), "run": (0.5, True, run), "hop": (1.0, True, hop),
         "pet": (2.4, True, pet), "carry": (0.6, True, carry), "tend": (1.3, True, tend),
         "attack": (0.8, False, attack), "ability": (1.3, False, ability), "sleep": (3.6, True, sleep),
         "eat": (2.0, True, eat), "chop": (1.1, True, chop), "mine": (1.0, True, mine)}
HIDE_AT = {"prop_berry": (0, 0.2, 0.36)}

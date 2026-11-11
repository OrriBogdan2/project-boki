"""Mossgrade's skeleton and the clips that are its own: eight legs in a slow wave, flowers that bud and bloom."""
import mossgrade
from boki_clips import LOOK_UP, SHARED, add, c, ear_pose, eat_ground, mouth_tool, part_bones, pet, s, seq
from mossgrade import FLOWERS, LEGS, SIDES, v3

BUD = 0.6          # the flowers' size in everyday clips; 1 is the open bloom they are modelled as
LEG_OUT = 1.0      # rz that swings a leg out to its side, per unit of sx
SCALED = tuple("bloom%d" % i for i in range(len(FLOWERS)))


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.245, 0.22), (0, 0.25, 0.06), "root"),
        "spine": ((0, 0.25, 0.06), (0, 0.25, -0.04), "hips"),
        "neck": ((0, 0.25, -0.04), (0, 0.25, -0.12), "spine"),
        "head": ((0, 0.25, -0.12), (0, 0.36, -0.2), "neck"),
        "prop_axe": (tuple(mossgrade.GRIP), tuple(mossgrade.GRIP + mossgrade.AXIS * 0.1), "head"),
        "prop_pick": (tuple(mossgrade.GRIP), tuple(mossgrade.GRIP + mossgrade.AXIS * 0.1), "head"),
        "prop_berry": (tuple(mossgrade.BERRY_C), tuple(mossgrade.BERRY_C + v3(0, 0.1, 0)), "root"),
    }
    parent = {"fleg1": "neck", "m1leg": "spine", "m2leg": "hips", "hleg1": "hips"}
    for sd, sx in SIDES:
        b["ear1." + sd] = ((sx * 0.12, 0.37, -0.2), (sx * 0.13, 0.43, -0.2), "head")
        for leg, paw, z, back in LEGS:
            top = (sx * 0.12, 0.14, z)
            ankle = (sx * 0.172, 0.038, z + back * 0.06)
            b["%s.%s" % (leg, sd)] = (top, ankle, parent[leg])
            b["%s.%s" % (paw, sd)] = (ankle, (ankle[0], 0.03, ankle[2] - 0.07), "%s.%s" % (leg, sd))
    for i, (_, _, bone) in enumerate(FLOWERS):
        base = mossgrade.flower_base(i)
        b["bloom%d" % i] = (tuple(base), tuple(base + v3(0, 0.06, 0)), bone)
    b.update(part_bones(mossgrade.grown_parts()))
    return b


def legs(p, t, rate, swing, lift, spread=0.0):
    """Eight legs in a wave from the back pair to the front, the two sides half a step apart; a stepping foot lifts
    out to the side and its toes curl up."""
    for sd, sx in SIDES:
        for k, (leg, paw, _, _) in enumerate(LEGS):
            ph = (3 - k) * 0.22 + (0.5 if sd == "R" else 0.0)
            a = s(t, rate, ph)
            up = max(0.0, c(t, rate, ph))
            add(p, "%s.%s" % (leg, sd), rx=a * swing, rz=sx * LEG_OUT * (up * lift + spread))
            add(p, "%s.%s" % (paw, sd), rx=-a * swing * 0.6 + up * lift * 1.2)


def buds(p, t, size=BUD, sway=0.08, rate=1.0):
    """Flowers nodding in the moss, each a little behind the one before."""
    for i in range(len(FLOWERS)):
        add(p, "bloom%d" % i, rx=sway * s(t, rate, i * 0.17), rz=sway * 0.8 * s(t, rate, i * 0.17 + 0.25))
        p.setdefault("bloom%d_sc" % i, (size, size, size))


def eight(fn, size=BUD, sway=0.08):
    """A shared four-legged clip on eight legs: the middle pairs follow the end pair nearest them."""
    def clip(t):
        p = fn(t)
        for sd in "LR":
            for mid, src in (("m1leg", "fleg1"), ("m2leg", "hleg1")):
                if src + "." + sd in p:
                    p.setdefault(mid + "." + sd, p[src + "." + sd])
            for mid, src in (("m1paw", "fpaw"), ("m2paw", "hpaw")):
                if src + "." + sd in p:
                    p.setdefault(mid + "." + sd, p[src + "." + sd])
        buds(p, t, size, sway)
        return p
    return clip


def shuffle(t):
    """Walk: a slow, contented eight-legged shuffle, the barrel rolling a little, the head swaying along."""
    p = {}
    legs(p, t, 1, 0.38, 0.22)
    p["root_at"] = (0, 0.004 * s(t, 2, 0.1), 0)
    add(p, "root", ry=0.035 * s(t, 1), rz=0.03 * s(t, 1, 0.25))
    add(p, "spine", ry=-0.04 * s(t, 1, 0.1), rx=0.015 * s(t, 2))
    add(p, "neck", ry=-0.03 * s(t, 1, 0.2))
    add(p, "head", rx=LOOK_UP * 0.8 + 0.03 * s(t, 2, 0.2), ry=0.08 * s(t, 1, 0.3), rz=0.05 * s(t, 1, 0.45))
    ear_pose(p, back=0.05 * s(t, 2))
    buds(p, t, sway=0.12, rate=2)
    return p


def scurry(t):
    """Run: its idea of hurrying, the same wave at a bustle, the whole barrel jiggling on top of it."""
    p = {}
    legs(p, t, 2, 0.55, 0.32)
    bounce = abs(s(t, 4))
    p["root_at"] = (0, 0.016 * bounce, 0)
    p["root_sc"] = (1 - 0.03 * bounce, 1 + 0.05 * bounce, 1 - 0.02 * bounce)
    add(p, "root", ry=0.05 * s(t, 2), rz=0.045 * s(t, 2, 0.25), rx=0.04)
    add(p, "spine", ry=-0.05 * s(t, 2, 0.1), rx=0.03 * s(t, 4))
    add(p, "head", rx=LOOK_UP * 0.6 + 0.05 * s(t, 4, 0.15), ry=0.06 * s(t, 2, 0.3))
    ear_pose(p, back=0.35)
    buds(p, t, sway=0.2, rate=4)
    return p


def bump(t):
    """Attack: rears its front end up, then flops forward on it with all its weight: a belly bump."""
    p = {}
    v = seq(t, [(0, 0), (0.32, 1), (0.44, -1), (0.6, -0.8), (1, 0)])
    up = max(v, 0)
    down = max(-v, 0)
    p["root_at"] = (0, 0.02 * up - 0.03 * down, 0.05 * up - 0.1 * down)
    p["root_sc"] = (1 - 0.05 * up + 0.14 * down, 1 + 0.08 * up - 0.18 * down, 1 - 0.04 * up + 0.06 * down)
    add(p, "root", rx=0.38 * up - 0.1 * down)
    add(p, "hips", rx=-0.1 * up)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.1 * up - 0.12 * down)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.7 * up, rz=sx * LEG_OUT * 0.35 * down)
        add(p, "m1leg." + sd, rx=0.45 * up, rz=sx * LEG_OUT * 0.35 * down)
        add(p, "m2leg." + sd, rx=-0.25 * up, rz=sx * LEG_OUT * 0.3 * down)
        add(p, "hleg1." + sd, rx=-0.4 * up, rz=sx * LEG_OUT * 0.3 * down)
    ear_pose(p, back=0.3 * up)
    buds(p, t, sway=0.06 + 0.25 * down, rate=3)
    return p


def bloom(i, t):
    """Flower i's size through the ability: bud, a pop past full, open, and folding back at the end."""
    t0 = 0.33 + i * 0.045
    return seq(t, [(0, BUD), (t0, BUD * 0.8), (t0 + 0.08, 1.5), (t0 + 0.16, 1.2), (0.84, 1.2), (1, BUD)])


def cushion(t):
    """Moss Cushion: gathers itself, plops down flat, and the moss on its back blooms flower by flower."""
    p = {}
    v = seq(t, [(0, 0), (0.18, 1), (0.28, -1), (0.36, -0.75), (0.84, -0.65), (1, 0)])
    up = max(v, 0)
    down = max(-v, 0)
    p["root_at"] = (0, 0.02 * up - 0.055 * down, 0)
    p["root_sc"] = (1 - 0.04 * up + 0.12 * down, 1 + 0.08 * up - 0.16 * down, 1 + 0.06 * down)
    content = seq(t, [(0, 0), (0.4, 0), (0.5, 1), (0.82, 1), (0.92, 0)])
    add(p, "root", rx=0.06 * up, ry=0.05 * content * s(t, 3))
    add(p, "spine", rx=-0.06 * down)
    add(p, "head", rx=LOOK_UP + 0.12 * up - 0.05 * down + 0.06 * content, rz=0.08 * content * s(t, 3, 0.25))
    for sd, sx in SIDES:
        for leg, paw, _, _ in LEGS:
            add(p, "%s.%s" % (leg, sd), rz=sx * LEG_OUT * (0.75 * down - 0.1 * up))
            add(p, "%s.%s" % (paw, sd), rx=0.25 * down)
    ear_pose(p, back=-0.2 * up + 0.3 * down)
    for i in range(len(FLOWERS)):
        k = bloom(i, t)
        p["bloom%d_sc" % i] = (k, k, k)
    buds(p, t, sway=0.05 + 0.1 * content, rate=3)
    return p


def boneless(t):
    """Sleep: flops wherever it is and goes boneless, flat as a cushion, legs out, the head lolled over."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, -0.07, 0)
    p["root_sc"] = (1.12 + br * 0.015, 0.84 + br * 0.03, 1.04)
    add(p, "root", rz=0.06)
    add(p, "spine", ry=0.08, rz=0.04)
    add(p, "neck", rx=-0.08, ry=0.12)
    add(p, "head", rx=-0.16 + br * 0.02, ry=0.16, rz=0.28)
    for sd, sx in SIDES:
        for k, (leg, paw, _, _) in enumerate(LEGS):
            add(p, "%s.%s" % (leg, sd), rx=(0.5, 0.15, -0.15, -0.5)[k], rz=sx * LEG_OUT * 1.25)
            add(p, "%s.%s" % (paw, sd), rx=0.3)
    ear_pose(p, back=0.2, out=0.2)
    buds(p, t, size=BUD * 0.7, sway=0.03)
    return p


def lug(t):
    """Carry: the load on its back, the same slow shuffle, head up and proud of it."""
    p = shuffle(t)
    add(p, "head", rx=0.1)
    add(p, "spine", rx=-0.04)
    return p


def chop(t):
    """Chop: the axe in its teeth, it lifts only its front end, a barrel does not rear, and lets its weight fall."""
    return mouth_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.26, 0.2)


def mine(t):
    return mouth_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.2, 0.3)


CLIPS = {name: (secs * 1.15, loop, eight(fn)) for name, (secs, loop, fn) in SHARED.items()}
CLIPS.update({
    "walk": (1.3, True, shuffle),
    "run": (0.7, True, scurry),
    "carry": (1.3, True, lug),
    "pet": (2.6, True, eight(pet, size=0.9, sway=0.05)),     # petted, the flowers on its back open up
    "attack": (0.85, False, bump),
    "ability": (1.7, False, cushion),
    "sleep": (4.0, True, boneless),
    "eat": (2.2, True, eight(eat_ground)),
    "chop": (1.2, True, eight(chop)),
    "mine": (1.1, True, eight(mine)),
})
import boki_react
CLIPS.update({n: (sec, lp, eight(fn)) for n, (sec, lp, fn) in boki_react.react().items()})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}
BONES = _bones()

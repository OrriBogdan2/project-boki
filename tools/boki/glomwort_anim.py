"""Glomwort's skeleton and its clips: a blob that oozes on its pseudopods and jiggles behind every move."""
import boki_clips
import glomwort
from boki_clips import SHARED, add, chop_mouth, eat_ground, mine_mouth, s, seq
from glomwort import LOBES, LOBE_R0, PUFFS, lobe_dir

boki_clips.TAIL_N = 0
boki_clips.DROP = -0.04


def _bones():
    b = {
        "root": ((0, 0, 0), (0, 0.12, 0), None),
        "hips": ((0, 0.15, 0.14), (0, 0.15, 0.0), "root"),
        "spine": ((0, 0.15, 0.0), (0, 0.16, -0.08), "hips"),
        "neck": ((0, 0.16, -0.06), (0, 0.18, -0.1), "spine"),
        "head": ((0, 0.18, -0.1), (0, 0.3, -0.12), "neck"),
        "prop_axe": (tuple(glomwort.GRIP), tuple(glomwort.GRIP + glomwort.AXIS * 0.1), "head"),
        "prop_pick": (tuple(glomwort.GRIP), tuple(glomwort.GRIP + glomwort.AXIS * 0.1), "head"),
        "prop_berry": (tuple(glomwort.BERRY_C), tuple(glomwort.BERRY_C + glomwort.v3(0, 0.1, 0)), "root"),
    }
    for i in range(LOBES):
        a = glomwort.v3(0, 0.05, 0.02) + lobe_dir(i) * LOBE_R0
        b["lobe%d" % i] = (tuple(a), tuple(a + lobe_dir(i) * 0.1), "root")
    for i, (c, r, bone) in enumerate(PUFFS):
        base = c - glomwort.v3(0, r * 1.1, 0)
        b[bone] = (tuple(base), tuple(c + glomwort.v3(0, r, 0)), "hips" if c[2] > 0.15 else "spine")
    b.update(boki_clips.part_bones(glomwort.grown_parts()))
    return b


BONES = _bones()


def jiggle(p, t, rate, amp):
    """The puffballs wobble on their stems a beat behind the body."""
    for i in range(len(PUFFS)):
        add(p, "puff%d" % i, rx=amp * s(t, rate, 0.15 + i * 0.2), rz=amp * 0.8 * s(t, rate, 0.4 + i * 0.27))


def ripple(p, t, rate, amp):
    """A wave runs round the rim: each lobe reaches and curls in turn."""
    for i in range(LOBES):
        add(p, "lobe%d" % i, rx=amp * s(t, rate, -i / LOBES))


def ooze(t, reach, lean):
    """It moves by surging: stretches forward, then the back catches up, the face riding on top."""
    p = {}
    w = s(t, 1)
    p["root_sc"] = (1 - 0.04 * w * reach, 1 - 0.07 * w * reach, 1 + 0.1 * w * reach)
    p["root_at"] = (0, 0.0, -0.025 * w * reach)
    add(p, "spine", rx=-lean + 0.05 * s(t, 1, 0.1) * reach)
    add(p, "hips", rx=0.05 * s(t, 1, 0.3) * reach)
    add(p, "head", rx=boki_clips.LOOK_UP * 0.5 + 0.06 * s(t, 1, 0.2) * reach)
    ripple(p, t, 1, 0.3 * reach)
    jiggle(p, t, 1, 0.12 * reach)
    return p


def idle(t):
    p = {}
    br = s(t, 2)
    p["root_sc"] = (1 + 0.025 * br, 1 - 0.035 * br, 1 + 0.025 * br)
    add(p, "head", rx=boki_clips.LOOK_UP * 0.5 + 0.04 * s(t, 1, 0.2), ry=0.1 * s(t, 1))
    ripple(p, t, 1, 0.12)
    jiggle(p, t, 2, 0.06)
    return p


def walk(t):
    return ooze(t, 1.0, 0.0)


def run(t):
    return ooze(t, 1.6, 0.12)


def carry(t):
    return ooze(t, 0.8, -0.05)


def hop(t):
    p = SHARED["hop"][2](t)
    up = max(seq(t, [(0, 0), (0.3, 0.2), (0.48, 1), (0.66, 0.2), (1, 0)]), 0)
    jiggle(p, t, 3, 0.15 + 0.2 * up)
    ripple(p, t, 2, 0.4 * up)
    return p


def puddle(t):
    """Sleep: melts into a puddle, the puffballs drooping, a slow breath."""
    br = s(t, 1)
    p = {"root_sc": (1.14 + br * 0.02, 0.72 + br * 0.03, 1.12 + br * 0.02), "root_at": (0, 0, 0)}
    add(p, "head", rx=-0.15)
    for i in range(len(PUFFS)):
        add(p, "puff%d" % i, rx=0.25, rz=(0.3 if i == 0 else -0.25))
    for i in range(LOBES):
        add(p, "lobe%d" % i, rx=-0.25)
    return p


def slap(t):
    """Attack: rears up tall, then slaps down forward with its whole front."""
    p = {}
    k = seq(t, [(0, 0), (0.3, 1), (0.42, -1), (0.62, -1), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    p["root_sc"] = (1 - 0.08 * up + 0.1 * down, 1 + 0.2 * up - 0.18 * down, 1 - 0.05 * up + 0.12 * down)
    p["root_at"] = (0, 0, 0.03 * up - 0.06 * down)
    add(p, "spine", rx=0.25 * up - 0.3 * down)
    add(p, "head", rx=0.2 * up - 0.1 * down)
    jiggle(p, t, 3, 0.25)
    ripple(p, t, 2, 0.3)
    return p


def ability(t):
    """Its E: squeezes down, the puffballs swell and shudder, then everything bursts up and settles."""
    p = {}
    sq = seq(t, [(0, 0), (0.35, 1), (0.5, -1), (0.65, -0.2), (1, 0)])
    down = max(sq, 0)
    up = max(-sq, 0)
    p["root_sc"] = (1 + 0.12 * down - 0.05 * up, 1 - 0.2 * down + 0.16 * up, 1 + 0.12 * down - 0.05 * up)
    add(p, "head", rx=-0.1 * down + 0.25 * up)
    jiggle(p, t, 9, 0.12 * down + 0.3 * up)
    ripple(p, t, 3, 0.35)
    return p


def pet(t):
    p = SHARED["pet"][2](t)
    lean = 0.5 + 0.5 * s(t, 1)
    p["root_sc"] = (1 + 0.04 * lean, 1 - 0.06 * lean, 1 + 0.04 * lean)
    jiggle(p, t, 3, 0.08)
    return p


def eat(t):
    """Flows over the berry: leans its front down onto it and gulps."""
    p = eat_ground(t)
    add(p, "spine", rx=-0.3)
    p["root_sc"] = (1, 1 - 0.06 * (0.5 + 0.5 * s(t, 3)), 1 + 0.06)
    jiggle(p, t, 3, 0.08)
    return p


CLIPS = dict(SHARED)
CLIPS.update({
    "idle": (2.6, True, idle),
    "walk": (0.9, True, walk),
    "run": (0.55, True, run),
    "hop": (0.95, True, hop),
    "carry": (0.9, True, carry),
    "pet": (2.2, True, pet),
    "attack": (0.8, False, slap),
    "ability": (1.3, False, ability),
    "sleep": (3.6, True, puddle),
    "eat": (2.0, True, eat),
    "chop": (1.1, True, chop_mouth),
    "mine": (1.0, True, mine_mouth),
})
HIDE_AT = {"prop_berry": (0, 0.14, 0.60)}

"""Glomwort's skeleton and its clips. The scan has no weighted lobes or puffballs (boki_scan.py drops the puffs and merges
the lobes into root), so the whole body moves as one wet mass: root squash and stretch, with the spine, neck and head
riding it. A slime mold is curious (0.95) and creeps: it surges, feels ahead with its head, and never stands still.
Other scans borrow this rig (BONES); their own clips live in <id>_anim.py."""
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


def ooze(t, reach, lean):
    """It moves by surging: stretches forward, then the back catches up, the head feeling the way ahead."""
    p = {}
    w = s(t, 1)
    p["root_sc"] = (1 - 0.04 * w * reach, 1 - 0.07 * w * reach, 1 + 0.1 * w * reach)
    add(p, "spine", rx=-lean + 0.06 * s(t, 1, 0.1) * reach)
    add(p, "hips", rx=0.06 * s(t, 1, 0.3) * reach)
    add(p, "neck", ry=0.1 * s(t, 1, 0.5) * reach)
    add(p, "head", rx=boki_clips.LOOK_UP * 0.5 + 0.07 * s(t, 1, 0.2) * reach, ry=0.18 * s(t, 1, 0.5) * reach)
    return p


def idle(t):
    """Never still: a slow swell, and its head sweeps left then right to feel out what is nearby."""
    p = {}
    br = s(t, 2)
    feel = seq(t, [(0, 0), (0.2, 1), (0.4, 0.2), (0.6, -1), (0.8, -0.2), (1, 0)])
    p["root_sc"] = (1 + 0.03 * br + 0.02 * feel, 1 - 0.04 * br, 1 + 0.03 * br - 0.02 * feel)
    add(p, "spine", rx=0.03 * s(t, 1, 0.2), ry=0.1 * feel)
    add(p, "head", rx=boki_clips.LOOK_UP * 0.5 + 0.05 * s(t, 1, 0.2), ry=0.3 * feel)
    return p


def walk(t):
    return ooze(t, 1.0, 0.0)


def run(t):
    return ooze(t, 1.6, 0.12)


def carry(t):
    return ooze(t, 0.8, -0.05)


def hop(t):
    """A springy bounce: squashes flat, shoots up stretched tall, splats on landing."""
    air = seq(t, [(0, 0), (0.22, -0.8), (0.4, 0.5), (0.55, 1), (0.72, 0.3), (0.82, -1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.14 * up, 0)}
    p["root_sc"] = (1 + 0.2 * down - 0.08 * up, 1 - 0.28 * down + 0.2 * up, 1 + 0.2 * down - 0.08 * up)
    add(p, "spine", rx=0.12 * up - 0.1 * down)
    add(p, "head", rx=boki_clips.LOOK_UP * 0.5 + 0.2 * up - 0.1 * down)
    return p


def puddle(t):
    """Sleep: melts into a puddle, the head sunk in, a slow breath."""
    br = s(t, 1)
    p = {"root_sc": (1.14 + br * 0.02, 0.72 + br * 0.03, 1.12 + br * 0.02), "root_at": (0, 0, 0)}
    add(p, "head", rx=-0.15)
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
    return p


def ability(t):
    """Its E: squeezes down, swells and shudders as the spores build, then bursts up and settles."""
    p = {}
    sq = seq(t, [(0, 0), (0.35, 1), (0.5, -1), (0.65, -0.2), (1, 0)])
    shudder = seq(t, [(0, 0), (0.1, 0), (0.3, 1), (0.42, 1), (0.5, 0)])
    down = max(sq, 0)
    up = max(-sq, 0)
    p["root_sc"] = (1 + 0.12 * down - 0.05 * up, 1 - 0.2 * down + 0.16 * up, 1 + 0.12 * down - 0.05 * up)
    add(p, "root", rz=0.05 * shudder * s(t, 9))
    add(p, "head", rx=-0.1 * down + 0.25 * up)
    return p


def pet(t):
    p = SHARED["pet"][2](t)
    lean = 0.5 + 0.5 * s(t, 1)
    p["root_sc"] = (1 + 0.04 * lean, 1 - 0.06 * lean, 1 + 0.04 * lean)
    return p


def eat(t):
    """Flows over the berry: leans its front down onto it and gulps."""
    p = eat_ground(t)
    add(p, "spine", rx=-0.3)
    p["root_sc"] = (1, 1 - 0.06 * (0.5 + 0.5 * s(t, 3)), 1 + 0.06)
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

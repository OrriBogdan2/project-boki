"""Bubblisk's (opalisk) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a basilisk
lizard and a show-off. It scurries in sprawling, side-to-side steps, bolts up on its hind legs when frightened (run
first, pose later), freezes mid-stride to strike a pose, and blows its soap-bubble twin out with a swell and a puff."""
import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.6


def scurry(t, cycles, amp, lift, bob):
    """A lizard's gait: the spine bends into an S that flips sideways at each step, the hips swinging against the
    shoulders, the whole body rolling onto the planted side; the head snaps round at the end of a step."""
    a = s(t, cycles)
    p = {"root_at": (0, bob * abs(s(t, cycles, 0.25)), -0.012 * amp * s(t, cycles * 2))}
    add(p, "root", rz=0.07 * amp * a, ry=-0.06 * amp * a, rx=lift)
    add(p, "spine", ry=0.2 * amp * a, rx=-0.06 * lift)
    add(p, "hips", ry=-0.26 * amp * a, rz=-0.04 * amp * a)
    add(p, "neck", ry=-0.1 * amp * a)
    add(p, "head", rx=LOOK - lift * 0.6, ry=-0.12 * amp * a + 0.07 * amp * s(t, cycles * 2, 0.1))
    return p


def idle(t):
    """Preens: breath in, a held pose with the chin high, a flick of the head to check who is watching, and a
    startled shiver before it settles back."""
    br = s(t, 2)
    pose = seq(t, [(0, 0), (0.2, 0), (0.32, 1), (0.58, 1), (0.7, 0), (1, 0)])
    glance = seq(t, [(0, 0), (0.72, 0), (0.76, 1), (0.84, 1), (0.88, -0.6), (0.94, 0), (1, 0)])
    start = seq(t, [(0, 0), (0.08, 0), (0.1, 1), (0.14, -0.4), (0.18, 0), (1, 0)])
    p = {"root_sc": (1 + 0.02 * br + 0.05 * pose, 1 - 0.025 * br + 0.06 * pose + 0.07 * start, 1 + 0.02 * br)}
    p["root_at"] = (0, 0.012 * start, 0)
    add(p, "root", rx=0.1 * pose, rz=0.03 * s(t, 1))
    add(p, "spine", rx=0.03 * br + 0.14 * pose)
    add(p, "neck", ry=0.1 * glance)
    add(p, "head", rx=LOOK + 0.03 * br + 0.2 * pose - 0.1 * start, ry=0.25 * glance + 0.08 * s(t, 1, 0.1),
        rz=0.12 * pose + 0.05 * glance)
    add(p, "hips", ry=0.04 * s(t, 1, 0.5))
    return p


def walk(t):
    return scurry(t, 2, 0.9, 0.0, 0.006)


def run(t):
    """Bolts: up on its hind legs like a basilisk on water, chest high, hips thrashing, the bounce quick."""
    p = scurry(t, 3, 1.5, 0.3, 0.02)
    add(p, "spine", rx=-0.12)
    add(p, "head", rx=0.1)
    return p


def carry(t):
    p = scurry(t, 2, 0.6, 0.1, 0.004)
    add(p, "head", rx=0.1)
    return p


def leap(t):
    """Hop: a skittish crouch, then straight up with a twirl for show, a flat-footed landing."""
    air = seq(t, [(0, 0), (0.18, -0.7), (0.34, 0.4), (0.5, 1), (0.68, 0.4), (0.82, -0.5), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    spin = seq(t, [(0.3, 0), (0.62, 1), (1, 1)]) * 0.9
    p = {"root_at": (0, 0.2 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down - 0.05 * up, 1 - 0.16 * down + 0.1 * up, 1 + 0.08 * down - 0.03 * up)
    add(p, "root", ry=spin, rx=0.25 * up - 0.12 * down)
    add(p, "spine", rx=0.18 * up - 0.15 * down)
    add(p, "hips", rz=0.12 * up * s(t, 2))
    add(p, "head", rx=LOOK + 0.2 * up - 0.15 * down)
    return p


def snap(t):
    """Attack: the head draws back and the body coils, then it lunges, jaws first, the whole body swelling in a
    flash as it lands."""
    k = seq(t, [(0, 0), (0.28, 1), (0.4, -1), (0.55, -0.7), (0.8, 0), (1, 0)])
    coil = max(k, 0)
    lunge = max(-k, 0)
    flash = seq(t, [(0, 0), (0.38, 0), (0.44, 1), (0.6, 0), (1, 0)])
    p = {"root_at": (0, 0, 0.04 * coil - 0.1 * lunge)}
    p["root_sc"] = (1 + 0.06 * coil + 0.1 * flash, 1 - 0.06 * coil + 0.08 * flash, 1 - 0.1 * coil + 0.08 * lunge)
    add(p, "root", rx=0.08 * coil - 0.14 * lunge)
    add(p, "spine", rx=0.22 * coil - 0.3 * lunge, ry=0.3 * coil)
    add(p, "hips", ry=-0.25 * coil + 0.15 * lunge)
    add(p, "neck", rx=0.1 * coil - 0.1 * lunge)
    add(p, "head", rx=LOOK + 0.28 * coil - 0.3 * lunge, ry=-0.15 * coil)
    return p


def blow(t):
    """Cast (its bubble twin): rears up and breathes in until it is swollen and quivering, then puffs hard, the body
    deflating forward as the bubble leaves, and strikes a pose over it."""
    k = seq(t, [(0, 0), (0.45, 1), (0.6, 1), (0.7, -1), (0.82, -0.3), (1, 0)])
    swell = max(k, 0)
    puff = max(-k, 0)
    shiver = seq(t, [(0, 0), (0.3, 0), (0.45, 1), (0.6, 1), (0.66, 0), (1, 0)]) * s(t, 9)
    posed = seq(t, [(0, 0), (0.72, 0), (0.85, 1), (1, 0)])
    p = {"root_at": (0, 0.03 * swell, -0.03 * puff)}
    p["root_sc"] = (1 + 0.18 * swell + 0.02 * shiver - 0.08 * puff, 1 + 0.16 * swell + 0.02 * shiver - 0.1 * puff,
                    1 + 0.18 * swell + 0.02 * shiver + 0.08 * puff)
    add(p, "root", rx=0.12 * swell - 0.1 * puff)
    add(p, "spine", rx=0.3 * swell - 0.24 * puff)
    add(p, "hips", rx=-0.1 * swell)
    add(p, "head", rx=LOOK + 0.4 * swell - 0.3 * puff + 0.1 * posed, rz=0.14 * posed, ry=0.05 * shiver)
    return p


def sprawl(t):
    """Sleep: sprawled flat on its belly, chin on the ground, one slow breath after another, the head turned aside."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.08 + 0.02 * br, 0.84 + 0.03 * br, 1.08)}
    add(p, "spine", rx=-0.1, ry=0.12)
    add(p, "neck", rx=-0.1)
    add(p, "head", rx=-0.3 + 0.01 * br, ry=0.35, rz=0.15)
    add(p, "hips", ry=-0.2)
    return p


def pet(t):
    """Preens under a hand: sticks its chest out and tips its head into it, quivering with pleasure."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.04 * lean, 1 + 0.03 * lean, 1)}
    add(p, "spine", rx=0.1 + 0.08 * lean)
    add(p, "head", rx=LOOK + 0.15 + 0.1 * lean, rz=0.18 * lean + 0.03 * s(t, 6), ry=0.1 * lean)
    add(p, "hips", ry=0.15 * s(t, 3))
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update({
    "idle": (3.2, True, idle),
    "walk": (0.7, True, walk),
    "run": (0.38, True, run),
    "hop": (0.85, True, leap),
    "carry": (0.8, True, carry),
    "pet": (2.0, True, pet),
    "attack": (0.7, False, snap),
    "ability": (1.5, False, blow),
    "sleep": (3.4, True, sprawl),
})

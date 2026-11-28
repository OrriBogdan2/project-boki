"""Floenatee's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a kind, slow manatee
with an old icebox on its back, propped up on its tail and flippers. It heaves itself along in long, slow lurches, rolls
its great weight on every one, hums (a gentle swell through the body) as its idle and ability, and the crystal-and-icebox
back rocks a beat behind it."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT


def hum(p, t, rate, amp):
    """A low song you feel through your boots: the whole body swells and settles."""
    w = s(t, rate)
    p["root_sc"] = (1 + 0.6 * amp * w, 1 - 0.5 * amp * w, 1 + 0.6 * amp * w)


def sway(p, t, amp):
    """The icebox on its back lags the body: the spine rolls a beat behind the hips."""
    add(p, "spine", rz=0.5 * amp * s(t, 1, -0.12), rx=0.3 * amp * s(t, 2, -0.1))


def idle(t):
    """Sits up easy on its tail, humming: a slow swell of the chest, the head nodding along, an unhurried look round."""
    p = {}
    hum(p, t, 2, 0.02)
    look = seq(t, [(0, 0), (0.25, 0), (0.4, 1), (0.6, 1), (0.75, -0.8), (0.9, 0), (1, 0)])
    add(p, "spine", rx=0.02 * s(t, 2))
    add(p, "head", rx=LOOK_UP * 0.4 + 0.04 * s(t, 2, 0.2), ry=0.35 * look, rz=0.04 * s(t, 1))
    return p


def lurch(t, amp):
    """It moves by heaving: the body rears back, throws forward onto its flippers and slumps down, the icebox
    rocking behind."""
    w = s(t, 1)
    reach = seq(t, [(0, 0), (0.35, 1), (0.55, 1), (0.85, 0), (1, 0)])
    p = {"root_at": (0, 0.02 * amp * reach, -0.03 * amp * reach)}
    p["root_sc"] = (1 - 0.02 * amp * reach, 1 + 0.04 * amp * reach, 1 - 0.02 * amp * reach)
    add(p, "root", rx=-0.1 * amp * reach + 0.05 * amp, rz=0.05 * amp * w)
    add(p, "hips", rx=0.06 * amp * reach)
    sway(p, t, amp)
    add(p, "head", rx=LOOK_UP * 0.4 + 0.05 * amp * (1 - reach), ry=-0.08 * amp * w)
    return p


def walk(t):
    return lurch(t, 1.0)


def run(t):
    """A wallowing rush, as fast as a manatee gets: shorter heaves, the head thrust out and the body low."""
    p = lurch(t, 0.75)
    add(p, "root", rx=-0.1)
    add(p, "spine", rx=-0.06)
    add(p, "head", rx=-0.12)
    return p


def carry(t):
    p = lurch(t, 0.7)
    add(p, "head", rx=0.08)
    return p


def hop(t):
    """A heavy, happy bounce: sinks into its tail, pushes up tall, comes down with a belly-wobble and a soft thud."""
    air = seq(t, [(0, 0), (0.2, -0.8), (0.36, 0.3), (0.5, 1), (0.64, 0.3), (0.76, -1), (0.9, 0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    wobble = seq(t, [(0, 0), (0.76, 0), (0.82, 1), (0.9, -0.6), (1, 0)])
    p = {"root_at": (0, 0.1 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down + 0.04 * wobble, 1 - 0.14 * down + 0.07 * up, 1 + 0.08 * down)
    add(p, "root", rx=0.1 * up - 0.04 * down, rz=0.05 * wobble)
    add(p, "spine", rz=0.06 * wobble)
    add(p, "head", rx=LOOK_UP * 0.4 + 0.1 * up - 0.06 * down)
    return p


def bellyflop(t):
    """Attack: rears up tall on its tail, then drops the whole great weight forward onto its flippers with a thud."""
    k = seq(t, [(0, 0), (0.4, 1), (0.5, 1), (0.58, -1), (0.76, -0.25), (1, 0)])
    up = max(k, 0)
    down = max(-k, 0)
    p = {"root_at": (0, 0.05 * up - 0.02 * down, 0.03 * up - 0.12 * down)}
    p["root_sc"] = (1 - 0.04 * up + 0.12 * down, 1 + 0.1 * up - 0.16 * down, 1 - 0.03 * up + 0.08 * down)
    add(p, "root", rx=-0.3 * up + 0.4 * down)
    add(p, "spine", rx=-0.1 * up + 0.14 * down, rz=0.05 * s(t, 7) * down)
    add(p, "head", rx=0.2 * up - 0.3 * down)
    return p


def song(t):
    """Its E: draws a big breath, rears up and sings one long low note; the body swells and the icebox drawers rattle,
    the whole chest humming."""
    k = seq(t, [(0, 0), (0.3, 1), (0.82, 1), (1, 0)])
    note = seq(t, [(0, 0), (0.32, 0), (0.4, 1), (0.8, 1), (0.92, 0), (1, 0)])
    p = {"root_at": (0, 0.03 * k, 0)}
    p["root_sc"] = (1 + 0.1 * k + 0.05 * note * s(t, 10), 1 + 0.08 * k + 0.07 * note * s(t, 10), 1 + 0.1 * k)
    add(p, "root", rx=-0.12 * k)
    add(p, "spine", rx=0.1 * k, rz=0.07 * note * s(t, 13))
    add(p, "neck", rx=0.15 * k)
    add(p, "head", rx=LOOK_UP * 0.4 + 0.45 * k, rz=0.04 * note * s(t, 5))
    return p


def graze(t):
    """Eat: tips down onto its flippers to mouth the food, slow contented chews with the whiskers working."""
    p = eat_ground(t)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=0.04 * s(t, 3))
    return p


def pet(t):
    """Everyone's friend: leans its whole big head into the hand and hums, the body swelling with it."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    hum(p, t, 3, 0.025)
    add(p, "root", rz=0.03 * s(t, 1, 0.25))
    add(p, "head", rx=LOOK_UP * 0.3 + 0.06 * lean, rz=0.18 * lean, ry=0.1 * lean)
    return p


def doze(t):
    """Sleep: sags onto its belly, the head lowered on its flippers, snoring slowly, a hum in its sleep."""
    br = s(t, 1)
    p = {"root_at": (0, -0.05, 0)}
    p["root_sc"] = (1.08 + 0.02 * br, 0.86 + 0.04 * br, 1.06)
    add(p, "spine", rx=-0.08)
    add(p, "head", rx=-0.3 + 0.02 * br, ry=0.2, rz=0.08)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.4, True, idle),
        "walk": (1.0, True, walk),
        "run": (0.6, True, run),
        "hop": (1.0, True, hop),
        "carry": (1.0, True, carry),
        "pet": (2.4, True, pet),
        "attack": (0.95, False, bellyflop),
        "ability": (1.8, False, song),
        "sleep": (4.2, True, doze),
        "eat": (2.2, True, graze),
    }
)

"""Goliathite's (Effigeetle) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a
cart-sized goliath beetle in a marble face. Earnest and gentle, so it plods with its weight rocking side to side, shoves
rather than strikes, and holds its head up proud. The shell splits down the nose when it flies you over a gap."""

import boki_clips
import glomwort_anim
from boki_clips import LOOK_UP, add, c, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT

boki_clips.DROP = -0.05


def plod(t, amp):
    """Six stumps, two heavy beats a stride: the shell rocks onto each side in turn and thumps down between."""
    w = s(t, 1)
    p = {"root_at": (0, 0.006 * amp * (1 - c(t, 2)), 0)}
    add(p, "root", rz=0.05 * amp * w, rx=0.025 * amp * s(t, 2, 0.5))
    add(p, "hips", rz=-0.03 * amp * w)
    add(p, "spine", ry=0.04 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.03 * amp * s(t, 2, 0.25), ry=-0.05 * amp * w)
    return p


def idle(t):
    """Slow deep breaths, a proud tilt of the face, now and then a glance down at its own shell."""
    br = s(t, 1)
    glance = seq(t, [(0, 0), (0.55, 0), (0.65, 1), (0.82, 1), (0.92, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br, 1 + 0.02 * br, 1 + 0.012 * br)}
    add(p, "spine", rx=0.02 * br)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.05 + 0.03 * br - 0.22 * glance, ry=0.08 * s(t, 1, 0.3), rz=0.05 * glance)
    return p


def walk(t):
    return plod(t, 1.0)


def run(t):
    """A trundling charge: the front dips, the shell rolls hard from side to side, each beat shakes the ground."""
    p = plod(t, 1.5)
    p["root_at"] = (0, 0.02 + 0.015 * s(t, 2), 0)
    add(p, "root", rx=-0.07)
    add(p, "spine", rx=-0.08 * s(t, 2, 0.25))
    add(p, "head", rx=-0.1)
    return p


def carry(t):
    p = plod(t, 0.8)
    add(p, "head", rx=0.06)
    return p


def shove(t):
    """Attack: sets its stumps, leans back, then drives its whole shell face first and pushes through."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.42, 0), (1, 0)])
    drive = seq(t, [(0.3, 0), (0.42, 1), (0.64, 0.8), (1, 0)])
    p = {"root_at": (0, 0, 0.06 * wind - 0.2 * drive)}
    p["root_sc"] = (1 + 0.03 * wind, 1 - 0.04 * wind, 1 - 0.02 * wind + 0.05 * drive)
    add(p, "root", rx=-0.14 * wind - 0.08 * drive)
    add(p, "spine", rx=0.1 * wind - 0.12 * drive)
    add(p, "head", rx=0.25 * wind - 0.2 * drive)
    return p


def split_open(t):
    """Its E: braces low, the shell swells and its nose splits, it lifts off with a hum and settles back shut."""
    k = seq(t, [(0, 0), (0.3, 1), (0.5, 0), (0.62, -1), (0.85, -0.4), (1, 0)])
    brace = max(k, 0)
    lift = max(-k, 0)
    hum = seq(t, [(0, 0), (0.55, 0), (0.62, 1), (0.85, 1), (1, 0)])
    p = {"root_at": (0, -0.04 * brace + 0.16 * lift, 0)}
    p["root_sc"] = (1 + 0.12 * brace + 0.1 * lift, 1 - 0.14 * brace + 0.06 * lift, 1 + 0.06 * brace)
    add(p, "root", rz=0.025 * hum * s(t, 12), rx=-0.1 * lift)
    add(p, "spine", rx=-0.08 * brace + 0.1 * lift)
    add(p, "head", rx=-0.1 * brace + 0.3 * lift)
    return p


def heavy_hop(t):
    """Hop: a slow crouch, a short low leap, a landing that thuds."""
    air = seq(t, [(0, 0), (0.25, -0.7), (0.42, 0.3), (0.55, 1), (0.72, 0.3), (0.82, -0.8), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down - 0.02 * up, 1 - 0.14 * down + 0.04 * up, 1 + 0.05 * down)
    add(p, "root", rx=0.08 * up - 0.04 * down)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.12 * up - 0.08 * down)
    return p


def settle(t):
    """Sleep: lowers itself flat with the face tucked down, slow breaths."""
    br = s(t, 1)
    p = {"root_at": (0, -0.05, 0), "root_sc": (1.06 + 0.015 * br, 0.9 + 0.025 * br, 1.04)}
    add(p, "spine", rx=-0.05)
    add(p, "head", rx=-0.35 + 0.01 * br, ry=0.1)
    return p


def pet(t):
    """Lifts its face into the hand and holds still, then a proud rock: it likes being polished."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    add(p, "root", rz=0.03 * lean)
    add(p, "head", rx=LOOK_UP * 0.5 + 0.12 * lean, rz=0.1 * lean, ry=0.08 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.4, True, idle),
        "walk": (1.1, True, walk),
        "run": (0.62, True, run),
        "hop": (1.1, True, heavy_hop),
        "carry": (1.2, True, carry),
        "pet": (2.4, True, pet),
        "attack": (1.0, False, shove),
        "ability": (1.5, False, split_open),
        "sleep": (4.2, True, settle),
    }
)

"""Nacrolin's (Mirrolin's) own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a timid
pangolin that creeps low with its head tucked, scurries when pushed, and curls into a mirror-tiled ball for its
hop, its ram and its disco-ball spell."""
import math

import glomwort_anim
from boki_clips import LOOK_UP, TAU, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
HEAD_LOW = -0.12    # its head hangs low, under the level a Boki looks up from (rx)


def curl(p, k):
    """Rolls itself up, k 0..1: the back arches over, the head and belly tuck in, the whole ball a little smaller."""
    p["root_sc"] = (1 + 0.08 * k, 1 - 0.18 * k, 1 - 0.14 * k)
    add(p, "spine", rx=-0.4 * k)
    add(p, "hips", rx=0.3 * k)
    add(p, "head", rx=-0.55 * k)


def creep(t, amp):
    """Small tentative steps: the body sways side to side, the head low and scanning, the back dipping on each step."""
    w = s(t, 1)
    p = {"root_at": (0, 0.008 * amp * s(t, 2), 0)}
    add(p, "root", rz=0.05 * amp * w, rx=0.02 * amp * s(t, 2, 0.5))
    add(p, "spine", ry=0.06 * amp * w, rx=0.02 * amp * s(t, 2))
    add(p, "hips", ry=-0.05 * amp * w)
    add(p, "head", rx=LOOK_UP * 0.4 + HEAD_LOW + 0.04 * amp * s(t, 2, 0.5), ry=-0.12 * amp * w)
    return p


def idle(t):
    """Hunched and wary: it breathes small, glances at a sound and shivers, its tiles chattering."""
    br = s(t, 1)
    glance = seq(t, [(0, 0), (0.4, 0), (0.46, 1), (0.6, 1), (0.68, -0.6), (0.78, -0.6), (0.86, 0), (1, 0)])
    shiver = seq(t, [(0.46, 0), (0.48, 1), (0.5, -1), (0.52, 1), (0.54, -1), (0.56, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br, 1 + 0.02 * br, 1 + 0.012 * br)}
    add(p, "root", rz=0.02 * shiver)
    add(p, "spine", rx=-0.04 + 0.02 * br)
    add(p, "head", rx=LOOK_UP * 0.3 + HEAD_LOW + 0.03 * s(t, 1, 0.3), ry=0.35 * glance)
    return p


def walk(t):
    return creep(t, 1.0)


def run(t):
    """A scurry: it bunches up and runs low, the body rocking nose to tail on every quick stride."""
    p = creep(t, 0.5)
    stride = s(t, 1)
    p["root_at"] = (0, 0.012 + 0.012 * s(t, 2), 0)
    add(p, "root", rx=-0.07)
    add(p, "spine", rx=-0.1 * stride)
    add(p, "hips", rx=0.08 * stride)
    add(p, "head", rx=-0.12)
    return p


def carry(t):
    p = creep(t, 0.8)
    add(p, "head", rx=0.08)
    return p


def tuck_hop(t):
    """Hop: a nervous crouch, then it curls up mid-air and tumbles once over before it lands and uncurls."""
    air = seq(t, [(0, 0), (0.18, -0.5), (0.34, 0.3), (0.5, 1), (0.7, 0.3), (0.8, -0.6), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    ball = seq(t, [(0, 0), (0.3, 0), (0.42, 1), (0.68, 1), (0.78, 0), (1, 0)])
    roll = seq(t, [(0.3, 0), (0.7, 1), (1, 1)])
    p = {"root_at": (0, 0.1 * up - 0.025 * down, 0)}
    curl(p, ball)
    add(p, "root", rx=-TAU * roll)
    p["root_sc"] = (p["root_sc"][0] + 0.08 * down, p["root_sc"][1] - 0.1 * down, p["root_sc"][2] + 0.05 * down)
    return p


def ram(t):
    """Attack: coils up tight, then rolls into the target as a ball and uncurls behind it."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.4, 1), (0.52, 0), (1, 0)])
    ball = seq(t, [(0, 0), (0.3, 1), (0.66, 1), (0.82, 0), (1, 0)])
    lunge = seq(t, [(0.3, 0), (0.46, 1), (0.66, 0.9), (1, 0)])
    spin = seq(t, [(0.38, 0), (0.7, 1), (1, 1)])
    p = {"root_at": (0, 0.02 * lunge, 0.04 * wind - 0.3 * lunge)}
    curl(p, ball)
    add(p, "root", rx=-TAU * spin)
    return p


def disco(t):
    """Its spell: curls into a ball, rises and spins like a disco ball, its tiles flashing, then drops and opens."""
    ball = seq(t, [(0, 0), (0.22, 1), (0.8, 1), (0.92, 0), (1, 0)])
    rise = seq(t, [(0.2, 0), (0.4, 1), (0.74, 1), (0.88, 0), (1, 0)])
    spin = seq(t, [(0.3, 0), (0.78, 1), (1, 1)])
    p = {"root_at": (0, 0.14 * rise, 0)}
    curl(p, ball)
    add(p, "root", ry=TAU * 2 * spin, rz=0.05 * rise * s(t, 6))
    return p


def curled_up(t):
    """Sleep: a tight ball with its head in, breathing slowly."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0)}
    curl(p, 1.0)
    p["root_sc"] = (p["root_sc"][0] + 0.01 * br, p["root_sc"][1] + 0.02 * br, p["root_sc"][2] + 0.01 * br)
    return p


def pet(t):
    """Shy: it flinches half into a curl, then unrolls a little into the hand, over and over."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    curl(p, 0.25 * (1 - lean))
    add(p, "root", rz=0.04 * lean)
    add(p, "head", rx=LOOK_UP * 0.2 + HEAD_LOW + 0.06 * lean, rz=0.15 * lean)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update({
    "idle": (3.2, True, idle),
    "walk": (0.9, True, walk),
    "run": (0.5, True, run),
    "hop": (1.0, True, tuck_hop),
    "carry": (1.0, True, carry),
    "pet": (2.4, True, pet),
    "attack": (0.9, False, ram),
    "ability": (1.6, False, disco),
    "sleep": (4.0, True, curled_up),
})

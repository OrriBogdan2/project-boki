"""Spirevark's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head, plus the file's legs):
an aardvark with a termite spire on its back. A digger: nose to the ground and always sniffing, it rakes with its
front claws, rears up and shudders to call the swarm out, and sleeps curled into a mound. The spire lags its body."""

import boki_clips
import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq
from vespyx_sides import SIDES

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4
SNOUT_DOWN = -0.35  # an aardvark carries its snout low: the head hangs this far below the line of the back


def spire_sway(p, t, amp, n=1.0):
    """The spire rocks on the back a beat behind the body (root and spine roll against each other)."""
    add(p, "root", rz=amp * s(t, n))
    add(p, "spine", rz=-amp * 1.4 * s(t, n, -0.12))


def idle(t):
    """Snout low and working: it sniffs in quick bursts, the nose sweeping the ground, and now and then scrapes the
    dirt with one front claw."""
    br = s(t, 2)
    sniff = seq(t, [(0, 0), (0.1, 1), (0.3, 1), (0.36, 0), (0.62, 0), (0.68, 1), (0.86, 1), (0.92, 0), (1, 0)])
    scrape = seq(t, [(0.36, 0), (0.42, 1), (0.62, 1), (0.68, 0)]) * (0.5 + 0.5 * s(t, 4, -0.25))
    p = {"root_at": (0, -0.004 + 0.003 * br, 0), "root_sc": (1 + 0.01 * br, 1 + 0.015 * br, 1)}
    spire_sway(p, t, 0.012)
    add(p, "spine", rx=-0.03)
    add(p, "neck", rx=-0.08, ry=0.1 * s(t, 1))
    add(p, "head", rx=LOOK + SNOUT_DOWN * 0.5 + 0.05 * sniff * s(t, 6), ry=0.28 * sniff * s(t, 1, 0.1))
    add(p, "fleg1.L", rx=0.5 * scrape)
    add(p, "fleg2.L", rx=-0.6 * scrape)
    add(p, "fpaw.L", rx=0.5 * scrape)
    return p


def rake(t):
    """Attack: rears back with both claws up, then drops its whole front and rakes them down and back through the
    dirt, the spire whipping forward over it."""
    k = seq(t, [(0, 0), (0.3, 1), (0.4, -1), (0.58, -1), (1, 0)])
    wind = max(k, 0)
    hit = max(-k, 0)
    p = {"root_at": (0, 0.03 * wind - 0.02 * hit, 0.04 * wind - 0.12 * hit)}
    p["root_sc"] = (1 - 0.03 * wind + 0.05 * hit, 1 + 0.04 * wind - 0.07 * hit, 1)
    add(p, "root", rx=0.3 * wind - 0.22 * hit)
    add(p, "spine", rx=0.1 * wind - 0.14 * hit)
    add(p, "head", rx=LOOK + 0.1 * wind - 0.3 * hit)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=1.0 * wind - 0.9 * hit)
        add(p, "fleg2." + sd, rx=-0.3 * wind + 0.5 * hit)
        add(p, "fpaw." + sd, rx=0.5 * wind - 0.8 * hit)
        add(p, "hleg1." + sd, rx=-0.15 * wind + 0.2 * hit)
    return p


def call_swarm(t):
    """Its E: braces and trembles until the spire buzzes, then rears up with its claws out and the swarm pours off."""
    brace = seq(t, [(0, 0), (0.3, 1), (0.6, 1), (0.68, 0), (1, 0)])
    rear = seq(t, [(0.55, 0), (0.7, 1), (0.88, 0.5), (1, 0)])
    buzz = s(t, 14) * (brace + 0.4 * rear)
    p = {"root_at": (0, -0.03 * brace + 0.05 * rear, 0.03 * rear)}
    p["root_sc"] = (1 + 0.06 * brace - 0.03 * rear, 1 - 0.1 * brace + 0.08 * rear, 1 + 0.03 * brace)
    add(p, "root", rz=0.05 * buzz, rx=0.4 * rear)
    add(p, "spine", rz=-0.06 * buzz, rx=0.1 * rear)
    add(p, "hips", ry=0.04 * buzz)
    add(p, "head", rx=LOOK - 0.12 * brace + 0.35 * rear, rz=0.04 * buzz)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.2 * brace + 0.9 * rear, rz=-sx * 0.3 * (brace + rear))
        add(p, "fleg2." + sd, rx=-0.4 * rear)
        add(p, "hleg1." + sd, rx=-0.25 * rear, rz=-sx * 0.15 * brace)
    return p


def heavy_hop(t):
    """Hop: a digger's hop: a deep crouch, a short spring with the claws tucked, and a thud that shakes the spire."""
    air = seq(t, [(0, 0), (0.25, -0.8), (0.42, 0.3), (0.55, 1), (0.7, 0.3), (0.8, -1), (0.9, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.14 * up - 0.04 * down, 0)}
    p["root_sc"] = (1 + 0.12 * down - 0.03 * up, 1 - 0.18 * down + 0.06 * up, 1 + 0.08 * down)
    add(p, "root", rx=0.12 * seq(t, [(0.3, 0), (0.55, 1), (0.8, -0.6), (1, 0)]))
    add(p, "spine", rz=0.08 * s(t, 2, 0.8) * (up + down))
    add(p, "head", rx=LOOK + 0.12 * up - 0.12 * down)
    for sd, _ in SIDES:
        add(p, "fleg1." + sd, rx=-0.5 * up + 0.2 * down)
        add(p, "hleg1." + sd, rx=0.5 * up - 0.2 * down)
        add(p, "fpaw." + sd, rx=0.3 * up)
    return p


def mound(t):
    """Sleep: curled low into a mound, the snout tucked between its front claws, the spire rising with each breath."""
    br = s(t, 1)
    p = {"root_at": (0, -0.05, 0), "root_sc": (1.08 + 0.01 * br, 0.84 + 0.02 * br, 1.06 + 0.01 * br)}
    add(p, "spine", rx=-0.08, ry=0.1)
    add(p, "neck", rx=-0.25, ry=0.3)
    add(p, "head", rx=-0.45, ry=0.35, rz=0.1)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.9, rz=-sx * 0.3)
        add(p, "fleg2." + sd, rx=-0.7)
        add(p, "hleg1." + sd, rx=-0.8, rz=-sx * 0.3)
    return p


def pet(t):
    """It pushes its long snout up into the hand, the nose wrinkling, and leans its whole weight on it."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.02 * lean, 1 - 0.02 * lean, 1)}
    add(p, "root", rz=0.05 * lean)
    add(p, "neck", rx=0.1 * lean, rz=0.1 * lean)
    add(p, "head", rx=LOOK + 0.12 * lean + 0.03 * s(t, 5), rz=0.18 * lean, ry=0.1 * lean)
    return p


def carry(t):
    """The shared trot with the load held: snout up, the spire steadied."""
    p = boki_clips.carry(t)
    add(p, "head", rx=0.1)
    return p


def eat(t):
    """Snout down on the berry, a long tongue-slurp and three hard chews."""
    chew = 0.5 + 0.5 * s(t, 3)
    p = {"root_at": (0, -0.012, -0.02), "prop_berry": "on"}
    spire_sway(p, t, 0.01, 3)
    add(p, "spine", rx=-0.16)
    add(p, "neck", rx=-0.25)
    add(p, "head", rx=-0.4 - 0.1 * chew, ry=0.06 * s(t, 3, 0.25))
    return p


def gait(t, amp):
    """Walk and run on top of the planted-paw trot (`gait_layer.py`): snout low and nodding with each footfall, nose
    sweeping side to side, the spire rolling a beat behind."""
    p = {}
    spire_sway(p, t, 0.03 * amp)
    add(p, "neck", ry=0.1 * amp * s(t, 1, 0.25))
    add(p, "head", rx=SNOUT_DOWN * 0.5 * (2 - amp) + 0.05 * amp * s(t, 2, 0.1), ry=-0.08 * amp * s(t, 1, 0.25))
    add(p, "spine", rx=-0.04 * (amp - 1))
    return p


GAIT = {"walk": lambda t: gait(t, 1.0), "run": lambda t: gait(t, 1.7)}


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.0, True, idle),
        "hop": (1.0, True, heavy_hop),
        "carry": (0.9, True, carry),
        "pet": (2.4, True, pet),
        "attack": (0.85, False, rake),
        "ability": (1.6, False, call_swarm),
        "sleep": (4.2, True, mound),
        "eat": (2.0, True, eat),
    }
)

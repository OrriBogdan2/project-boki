"""Gongibbon's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a gibbon whose
belly is a temple bell. A loud, joyful show-off that never keeps still: it moves in swinging arcs like a gibbon on
a branch, the bell belly rocking like a clapper under it, and it ends everything with a clang: the whole body rings
and shivers, then settles, grinning."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.5


def ring(p, t, amp, n=16):
    """The bell rings: the body shivers against itself at a high rate (belly on hips, chest on spine)."""
    add(p, "hips", rz=0.5 * amp * s(t, n), rx=0.3 * amp * s(t, n, 0.25))
    add(p, "spine", rz=-0.6 * amp * s(t, n, 0.1))
    add(p, "head", rz=0.3 * amp * s(t, n, 0.2))


def idle(t):
    """Bouncing on the spot: weight shifting from side to side, the bell belly swaying under it, the head turning to
    find an audience, and now and then a hoot: chest puffed, head thrown back."""
    bob = s(t, 2)
    hoot = seq(t, [(0, 0), (0.58, 0), (0.64, 1), (0.82, 1), (0.9, 0)])
    p = {"root_at": (0, 0.006 * abs(bob) + 0.012 * hoot, 0)}
    p["root_sc"] = (1 + 0.015 * bob - 0.03 * hoot, 1 - 0.015 * bob + 0.05 * hoot, 1)
    add(p, "root", rz=0.05 * s(t, 1))
    add(p, "hips", rz=-0.08 * s(t, 1, 0.2), ry=0.05 * s(t, 1, 0.1))
    add(p, "spine", rx=0.12 * hoot, rz=0.03 * s(t, 1, 0.3))
    add(p, "head", rx=LOOK + 0.35 * hoot, ry=0.3 * s(t, 1, 0.1) * (1 - hoot), rz=0.1 * s(t, 1, 0.4))
    return p


def swing(t, amp, rate, lean):
    """A brachiating gait: each stride the body hangs and swings through an arc: low at the bottom of the swing, up
    and forward at the ends, rolling toward the arm it is on, the bell belly lagging behind like a clapper."""
    arc = s(t, rate, 0.25)
    p = {"root_at": (0, 0.03 * amp * (1 - abs(s(t, rate))) * 0.6 + 0.01, 0)}
    p["root_sc"] = (1 - 0.02 * amp * abs(arc), 1 + 0.03 * amp * abs(arc), 1)
    add(p, "root", rz=0.13 * amp * s(t, rate / 2), rx=-lean)
    add(p, "hips", rz=-0.16 * amp * s(t, rate / 2, -0.1), rx=0.1 * amp * s(t, rate, 0.4))
    add(p, "spine", rz=0.06 * amp * s(t, rate / 2, 0.1), ry=0.1 * amp * s(t, rate / 2, 0.25))
    add(p, "head", rx=LOOK + 0.05 * amp * s(t, rate, 0.1), rz=-0.1 * amp * s(t, rate / 2))
    return p


def walk(t):
    return swing(t, 1.0, 2, 0.04)


def run(t):
    return swing(t, 1.6, 2, 0.12)


def clang(t):
    """Attack: swings its whole body back on its arms, then heaves it forward so the bell belly slams the target;
    the hit rings through it."""
    k = seq(t, [(0, 0), (0.32, 1), (0.44, -1), (0.6, -0.5), (1, 0)])
    wind = max(k, 0)
    hit = max(-k, 0)
    p = {"root_at": (0, 0.03 * wind, 0.05 * wind - 0.1 * hit)}
    p["root_sc"] = (1 - 0.04 * wind + 0.06 * hit, 1 + 0.06 * wind - 0.08 * hit, 1 - 0.03 * wind + 0.06 * hit)
    add(p, "root", rx=0.28 * wind - 0.2 * hit)
    add(p, "hips", rx=-0.25 * wind + 0.3 * hit)
    add(p, "spine", rx=0.12 * wind - 0.15 * hit)
    add(p, "head", rx=LOOK + 0.2 * wind - 0.25 * hit)
    ring(p, t, 0.08 * hit * seq(t, [(0.44, 1), (1, 0)]), 18)
    return p


def gong(t):
    """Its E: sucks in a huge breath, chest and bell swelling, head thrown back, then bellows and clangs: the whole
    body rings like a struck gong and settles, grinning."""
    breath = seq(t, [(0, 0), (0.38, 1), (0.52, 1), (0.58, 0), (1, 0)])
    blast = seq(t, [(0.52, 0), (0.6, 1), (0.8, 0.5), (1, 0)])
    p = {"root_at": (0, 0.02 * breath + 0.04 * blast, 0)}
    p["root_sc"] = (1 + 0.1 * breath + 0.05 * blast, 1 + 0.06 * breath - 0.06 * blast, 1 + 0.1 * breath + 0.05 * blast)
    add(p, "root", rx=-0.05 * breath)
    add(p, "spine", rx=0.2 * breath + 0.12 * blast)
    add(p, "hips", rx=-0.15 * breath)
    add(p, "head", rx=LOOK + 0.4 * breath + 0.3 * blast)
    ring(p, t, 0.12 * blast * seq(t, [(0.6, 1), (1, 0.15)]), 16)
    return p


def swing_hop(t):
    """Hop: a crouch, a spring with a twist, tucked in the air like a gibbon letting go of a branch, a bouncy land
    that sets the bell swinging."""
    air = seq(t, [(0, 0), (0.2, -0.7), (0.34, 0.3), (0.5, 1), (0.66, 0.3), (0.78, -0.8), (0.88, 0.1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    twist = seq(t, [(0.25, 0), (0.5, 1), (0.72, 0)])
    p = {"root_at": (0, 0.15 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.1 * down - 0.04 * up, 1 - 0.15 * down + 0.07 * up, 1 + 0.06 * down)
    add(p, "root", ry=0.5 * twist, rz=0.15 * twist)
    add(p, "hips", rz=-0.1 * s(t, 2, 0.4) * (up + down), rx=-0.2 * up)
    add(p, "head", rx=LOOK + 0.15 * up - 0.1 * down)
    ring(p, t, 0.05 * down, 12)
    return p


def pet(t):
    """It melts into the hand, grinning, then bounces happily: the bell belly goes 'dong' with each chuckle."""
    lean = 0.5 + 0.5 * s(t, 1)
    chuckle = max(0.0, s(t, 3))
    p = {"root_at": (0, 0.004 * chuckle, 0), "root_sc": (1 + 0.02 * lean, 1 - 0.03 * lean + 0.02 * chuckle, 1)}
    add(p, "root", rz=0.06 * lean)
    add(p, "head", rx=LOOK + 0.08 * lean, rz=0.18 * lean, ry=0.08 * lean)
    add(p, "hips", rz=0.03 * s(t, 3, 0.2))
    return p


def carry(t):
    """A rolling, bouncy walk with the load held in both arms, chin up."""
    p = swing(t, 0.6, 2, 0.0)
    add(p, "head", rx=0.1)
    return p


def eat(t):
    """Hunched over the berry, picking at it with both hands, chewing with its cheeks working, a pleased wiggle."""
    chew = 0.5 + 0.5 * s(t, 4)
    p = {"root_at": (0, -0.01, -0.01), "prop_berry": "on"}
    add(p, "spine", rx=-0.15)
    add(p, "head", rx=-0.3 - 0.07 * chew, rz=0.06 * s(t, 2, 0.25))
    add(p, "hips", rz=0.05 * s(t, 2))
    return p


def curl(t):
    """Sleep: curled into a ball around the bell, arms hugging it, head tucked in, rocking slightly as it breathes."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.06 + 0.01 * br, 0.88 + 0.02 * br, 1.04)}
    add(p, "spine", rx=-0.15)
    add(p, "hips", rx=0.08, rz=0.02 * br)
    add(p, "head", rx=-0.55, ry=0.2, rz=0.12)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (2.6, True, idle),
        "walk": (0.9, True, walk),
        "run": (0.55, True, run),
        "hop": (0.9, True, swing_hop),
        "carry": (0.9, True, carry),
        "pet": (2.2, True, pet),
        "attack": (0.85, False, clang),
        "ability": (1.6, False, gong),
        "sleep": (4.0, True, curl),
        "eat": (2.0, True, eat),
    }
)

"""Velvorm's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a velvet-purple worm
with a funnel snout and a ridge of mushroom caps. It has no legs, so it inches: a hump of the back runs from the tail
to the head (hips, spine, neck lift in turn, the body stretching as they reach and bunching as they land), the way a
caterpillar goes. Idle sniffs, the strike hammers the funnel down, its E inhales and sprays."""
import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LAG = 0.16
LOOK = LOOK_UP * 0.4         # the funnel snout points ahead rather than up


def inch(t, n, hump, reach, head):
    """The peristalsis: the arch passes hips -> spine -> neck -> head, LAG apart; the root stretches as it reaches
    and bunches as the hips catch up."""
    p = {"root_at": (0, 0.004 * s(t, n), 0)}
    for i, bone in enumerate(("hips", "spine", "neck")):
        add(p, bone, rx=hump * max(s(t, n, -i * LAG), -0.3) * (1 - 0.15 * i))
    p["root_sc"] = (1 - 0.03 * reach * s(t, n, 0.25), 1 + 0.04 * reach * s(t, n, 0.25),
                    1 + 0.07 * reach * s(t, n, 0.05))
    add(p, "root", ry=0.03 * hump * s(t, n, 0.1), rz=0.025 * hump * s(t, n))
    add(p, "head", rx=LOOK + head * s(t, n, -3 * LAG), ry=0.05 * hump * s(t, n, 0.4))
    return p


def idle(t):
    """Breathes slowly and sniffs: the funnel swings low then up, left then right, dribbling nothing yet."""
    br = s(t, 1)
    sniff = seq(t, [(0, 0), (0.5, 0), (0.56, 1), (0.64, 0.2), (0.72, 1), (0.8, 0), (1, 0)])
    p = {"root_sc": (1 + 0.012 * br, 1 + 0.025 * br, 1 - 0.005 * br)}
    add(p, "hips", rx=0.03 * br)
    add(p, "spine", rx=0.06 + 0.02 * br)
    add(p, "neck", rx=0.04 * sniff)
    add(p, "head", rx=LOOK - 0.1 + 0.03 * br - 0.1 * sniff, ry=0.12 * s(t, 1, 0.2) + 0.15 * sniff * s(t, 2))
    return p


def walk(t):
    return inch(t, 1, 0.13, 1.0, 0.07)


def run(t):
    """The scrunch-and-launch: the hump twice as quick and tall, the body flattening as it flings itself forward."""
    p = inch(t, 2, 0.18, 1.6, 0.1)
    p["root_at"] = (0, 0.012 + 0.012 * s(t, 2, 0.2), 0)
    add(p, "root", rx=-0.05)
    add(p, "head", rx=-0.12)
    return p


def carry(t):
    p = inch(t, 1, 0.1, 0.8, 0.05)
    add(p, "head", rx=0.1)
    return p


def hammer(t):
    """Attack: bunches the back up and the funnel high, slams the snout down and forward with the whole length
    behind it, and bounces off the hit."""
    wind = seq(t, [(0, 0), (0.34, 1), (0.46, 0), (1, 0)])
    hit = seq(t, [(0.34, 0), (0.46, 1), (0.58, 0.7), (0.8, 0), (1, 0)])
    p = {"root_at": (0, 0.01 * wind, -0.12 * hit + 0.03 * wind)}
    p["root_sc"] = (1 + 0.03 * wind, 1 + 0.1 * wind - 0.08 * hit, 1 - 0.08 * wind + 0.12 * hit)
    add(p, "hips", rx=0.2 * wind - 0.1 * hit)
    add(p, "spine", rx=0.3 * wind - 0.2 * hit)
    add(p, "neck", rx=0.3 * wind - 0.4 * hit)
    add(p, "head", rx=LOOK + 0.35 * wind - 0.55 * hit)
    return p


def spray(t):
    """Its E: sucks air until it swells round (the back caps swell with it), rears the funnel up and blows a long
    spray, then sags back flat."""
    fill = seq(t, [(0, 0), (0.1, 0.1), (0.46, 1), (0.52, 0), (1, 0)])
    blow = seq(t, [(0, 0), (0.46, 0), (0.54, 1), (0.82, 1), (1, 0)])
    p = {"root_at": (0, 0.03 * fill * (1 - blow), 0)}
    p["root_sc"] = (1 + 0.14 * fill * (1 - blow) - 0.04 * blow, 1 + 0.18 * fill * (1 - blow) - 0.08 * blow,
                    1 + 0.08 * fill * (1 - blow) + 0.06 * blow)
    add(p, "hips", rx=-0.1 * blow)
    add(p, "spine", rx=0.1 * fill * (1 - blow) + 0.3 * blow)
    add(p, "neck", rx=0.35 * blow)
    add(p, "head", rx=LOOK + 0.6 * blow - 0.1 * fill * (1 - blow), ry=0.12 * blow * s(t, 4))
    return p


def bunch_hop(t):
    """Hop: scrunches into a tight hump, flings itself up flat and long, lands in a heap and wobbles."""
    air = seq(t, [(0, 0), (0.26, -1), (0.42, 0.4), (0.54, 1), (0.7, 0.4), (0.8, -0.9), (0.92, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.01 * down, 0)}
    p["root_sc"] = (1 + 0.06 * down - 0.05 * up, 1 + 0.12 * down - 0.06 * up, 1 - 0.14 * down + 0.16 * up)
    add(p, "hips", rx=0.3 * down - 0.1 * up)
    add(p, "spine", rx=0.3 * down - 0.15 * up)
    add(p, "neck", rx=0.15 * down)
    add(p, "head", rx=LOOK - 0.15 * down + 0.15 * up)
    return p


def heap(t):
    """Sleep: slumps flat into a heap, the funnel resting on the ground, a long slow breath swelling the flanks."""
    br = s(t, 1)
    p = {"root_at": (0, -0.05, 0), "root_sc": (1.1 + 0.03 * br, 0.78 + 0.04 * br, 1.02)}
    add(p, "spine", rx=-0.02)
    add(p, "head", rx=-0.3 + 0.015 * br, ry=0.25, rz=0.1)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update({
    "idle": (3.4, True, idle),
    "walk": (1.3, True, walk),
    "run": (0.7, True, run),
    "hop": (1.0, True, bunch_hop),
    "carry": (1.3, True, carry),
    "attack": (0.9, False, hammer),
    "ability": (1.6, False, spray),
    "sleep": (4.6, True, heap),
})

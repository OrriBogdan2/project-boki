"""The three clips every Boki has for a minigame result: win, sulk and push. Written for the shared four-legged
bones (a bone a species lacks is ignored); a species tunes them with three numbers and adds its own limbs
(wings, fins, shell, caps) through `extra(pose, t, amount)`, which `react` calls once per clip with the amount that
matters for it: `extra_win`, `extra_sulk` and `extra_push`.

win  (1 s, once): crouch, spring with the head thrown back, a landing, then up on its toes with its chest out.
sulk (2.8 s, loop): turned away, head low, ears flat, a sigh, a scuff of one forefoot, one glance back.
push (0.9 s, loop): braced, shoulders low, hind legs driving, the whole body leaning in on every beat."""
import boki_clips
from boki_clips import SIDES, add, ear_pose, s, seq, tail_wave


def win(t, hop=1.0, extra=None):
    p = {}
    crouch = seq(t, [(0, 0), (0.15, 1), (0.25, 0), (1, 0)])
    air = seq(t, [(0, 0), (0.2, 0), (0.36, 1), (0.5, 0), (1, 0)])
    land = seq(t, [(0, 0), (0.5, 0), (0.56, 1), (0.68, 0), (1, 0)])
    proud = seq(t, [(0, 0), (0.54, 0), (0.68, 1), (0.9, 1), (1, 0.7)])
    p["root_at"] = (0, hop * 0.15 * air - 0.045 * crouch - 0.035 * land, 0)
    p["root_sc"] = (1 + 0.12 * (crouch + land) - 0.04 * air, 1 - 0.18 * (crouch + land) + 0.08 * air + 0.03 * proud,
                    1 + 0.05 * (crouch + land))
    add(p, "root", rx=hop * 0.16 * air + 0.1 * proud - 0.1 * crouch)
    add(p, "spine", rx=0.08 * proud - 0.06 * crouch)
    add(p, "neck", rx=0.1 * proud + 0.1 * air - 0.12 * crouch)
    add(p, "head", rx=0.3 * proud + 0.22 * air - 0.16 * (crouch + land), rz=0.1 * s(t, 3) * proud)
    ear_pose(p, back=-0.25 * (proud + air) + 0.4 * (crouch + land), out=0.1 * proud)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-0.55 * air * hop + 0.35 * crouch - 0.12 * proud)
        add(p, "fleg2." + sd, rx=-0.6 * air * hop - 0.3 * crouch)
        add(p, "hleg1." + sd, rx=0.55 * air * hop - 0.3 * crouch)
        add(p, "hleg2." + sd, rx=0.6 * air * hop + 0.3 * crouch)
        add(p, "arm." + sd, rx=0.6 * air + 0.3 * proud, rz=sx * 0.4 * air)
    tail_wave(p, 3 * t, 0.0, up=0.55 * proud, roll=0.3 * proud, lag=0.05)
    if extra:
        extra(p, t, max(air, proud, crouch))
    return p


def sulk(t, slump=1.0, extra=None):
    p = {}
    sigh = 0.5 + 0.5 * s(t, 1, -0.25)
    peek = seq(t, [(0, 0), (0.5, 0), (0.58, 1), (0.72, 1), (0.8, 0), (1, 0)])
    scuff = seq(t, [(0, 0), (0.18, 0), (0.24, 1), (0.31, 0), (0.37, 1), (0.44, 0), (1, 0)])
    p["root_at"] = (0, boki_clips.DROP * 0.3 * slump - 0.004 * sigh, 0)
    p["root_sc"] = (1 + 0.03 * slump, 1 - (0.06 + 0.02 * sigh) * slump, 1 + 0.02 * slump)
    add(p, "root", ry=0.45 * (1 - 0.7 * peek))
    add(p, "spine", rx=-0.12 * slump, ry=0.1)
    add(p, "neck", rx=-0.28 * slump - 0.04 * sigh, ry=0.3 * (1 - 1.4 * peek))
    add(p, "head", rx=-0.32 * slump - 0.05 * sigh + 0.12 * peek, ry=0.4 * (1 - 1.5 * peek), rz=0.12)
    ear_pose(p, back=0.55 * slump + 0.1 * peek, out=-0.2 * slump)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=0.08 + (0.45 * scuff if sd == "R" else 0.0))
        add(p, "fleg2." + sd, rx=-0.3 * scuff if sd == "R" else 0.0)
        add(p, "hleg1." + sd, rx=0.06)
        add(p, "arm." + sd, rx=-0.2, rz=-sx * 0.1)
    tail_wave(p, t, 0.012, up=-0.6 * slump, side=0.35, roll=0.03, lag=0.12)
    if extra:
        extra(p, t, 1.0)
    return p


def push(t, brace=1.0, extra=None):
    p = {}
    thrust = 0.5 + 0.5 * s(t, 1, -0.25)
    p["root_at"] = (0, -0.03 * brace, -0.07 * brace * thrust)
    add(p, "root", rx=-(0.13 + 0.05 * thrust) * brace, ry=0.025 * s(t, 3))
    add(p, "hips", rx=0.1 * brace)
    add(p, "spine", rx=-(0.16 + 0.07 * thrust) * brace)
    add(p, "neck", rx=-0.2 * brace)
    add(p, "head", rx=-(0.12 + 0.05 * thrust) * brace, ry=0.03 * s(t, 3))
    ear_pose(p, back=0.5)
    for sd, sx in SIDES:
        ph = 0.0 if sd == "L" else 0.12
        dig = 0.5 + 0.5 * s(t, 1, -0.25 + ph)
        add(p, "fleg1." + sd, rx=(0.5 - 0.15 * dig) * brace, rz=-sx * 0.08)
        add(p, "fleg2." + sd, rx=-0.35 * brace)
        add(p, "hleg1." + sd, rx=-(0.5 + 0.12 * dig) * brace)
        add(p, "hleg2." + sd, rx=(0.55 - 0.1 * dig) * brace)
        add(p, "arm." + sd, rx=0.9 * brace, rz=sx * 0.12)
    tail_wave(p, t, 0.02, up=0.15, roll=0.04, lag=0.1)
    if extra:
        extra(p, t, thrust)
    return p


def react(hop=1.0, slump=1.0, brace=1.0, extra_win=None, extra_sulk=None, extra_push=None):
    """The three clips, as CLIPS rows: name -> (seconds, loops, function of t)."""
    return {"win": (1.0, False, lambda t: win(t, hop, extra_win)),
            "sulk": (2.8, True, lambda t: sulk(t, slump, extra_sulk)),
            "push": (0.9, True, lambda t: push(t, brace, extra_push))}

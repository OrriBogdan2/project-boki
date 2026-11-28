"""Glaciatee's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a huge, gentle
manatee that sits upright on its tail like an ice vault, an aurora cape on its back. Slow, serene and loyal: it
drifts as if still in water, inches along in heaves of its whole body, and builds the aurora up slowly, the cape
rippling after the body in waves."""

import glomwort_anim
from boki_clips import LOOK_UP, add, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT
LOOK = LOOK_UP * 0.4


def cape(p, t, amp, n=1.0):
    """The aurora cape ripples on the back a beat behind the body: a wave runs up spine and head."""
    add(p, "spine", rz=amp * s(t, n, -0.15), rx=0.4 * amp * s(t, n, -0.35))
    add(p, "hips", rz=-0.5 * amp * s(t, n, -0.05))


def idle(t):
    """Drifts as if floating: a slow sway of the whole body, the head turning on a long breath, the cape trailing,
    and now and then a lazy nod as the aurora brightens."""
    br = s(t, 1)
    nod = seq(t, [(0, 0), (0.5, 0), (0.6, 1), (0.78, 0), (1, 0)])
    p = {"root_at": (0, 0.006 * s(t, 1, 0.25), 0), "root_sc": (1 + 0.012 * br, 1 + 0.02 * br, 1 + 0.012 * br)}
    add(p, "root", rz=0.03 * s(t, 1, 0.1))
    cape(p, t, 0.04)
    add(p, "head", rx=LOOK + 0.03 * br - 0.1 * nod, ry=0.18 * s(t, 1, 0.2), rz=0.06 * s(t, 1, 0.45))
    return p


def heave(t, amp, rate):
    """It moves by hitching along on its tail: the body rears back, the chest drops and the whole mass slides ahead,
    then settles with a thud that sets the cape rolling."""
    ph = (t * rate) % 1.0
    reach = seq(ph, [(0, 0), (0.35, 1), (0.6, 0), (1, 0)])
    thud = seq(ph, [(0.55, 0), (0.62, 1), (0.85, 0), (1, 0)])
    p = {"root_at": (0, 0.02 * amp * reach - 0.006 * amp * thud, -0.025 * amp * reach)}
    p["root_sc"] = (1 - 0.03 * amp * reach + 0.05 * amp * thud, 1 + 0.04 * amp * reach - 0.06 * amp * thud, 1)
    add(p, "root", rx=-0.05 * amp * reach + 0.04 * amp * thud, rz=0.04 * amp * s(t, rate / 2))
    add(p, "hips", rx=0.1 * amp * reach, ry=0.05 * amp * s(t, rate / 2, 0.25))
    add(p, "spine", rx=-0.12 * amp * reach + 0.06 * amp * thud)
    add(p, "head", rx=LOOK - 0.08 * amp * reach + 0.06 * amp * thud, rz=-0.04 * amp * s(t, rate / 2))
    cape(p, t, 0.06 * amp, rate)
    return p


def walk(t):
    return heave(t, 1.0, 2)


def run(t):
    """A quick flopping scoot: the same hitch, bigger and twice as often."""
    return heave(t, 1.8, 3)


def bash(t):
    """Attack: rears up tall on its tail, then crashes its whole front down on the target, the ice cracking."""
    k = seq(t, [(0, 0), (0.34, 1), (0.46, -1), (0.66, -0.7), (1, 0)])
    wind = max(k, 0)
    hit = max(-k, 0)
    p = {"root_at": (0, 0.03 * wind - 0.01 * hit, 0.02 * wind - 0.1 * hit)}
    p["root_sc"] = (1 - 0.05 * wind + 0.08 * hit, 1 + 0.12 * wind - 0.14 * hit, 1 - 0.04 * wind + 0.08 * hit)
    add(p, "root", rx=0.22 * wind - 0.22 * hit)
    add(p, "spine", rx=0.14 * wind - 0.2 * hit)
    add(p, "head", rx=LOOK + 0.2 * wind - 0.4 * hit)
    cape(p, t, 0.08 * (wind + hit), 3)
    return p


def aurora(t):
    """Its E: draws itself up, rising a little off the ground, the head lifting and the whole cape billowing in slow
    waves, then lets the light burst out in a shiver and settles."""
    rise = seq(t, [(0, 0), (0.45, 1), (0.7, 1), (1, 0)])
    burst = seq(t, [(0.45, 0), (0.55, 1), (0.8, 0.4), (1, 0)])
    shiver = s(t, 12) * burst
    p = {"root_at": (0, 0.05 * rise, 0)}
    p["root_sc"] = (1 - 0.04 * rise + 0.04 * burst, 1 + 0.12 * rise, 1 - 0.04 * rise + 0.04 * burst)
    add(p, "root", rx=0.08 * rise, rz=0.03 * shiver)
    add(p, "spine", rx=0.12 * rise)
    add(p, "head", rx=LOOK + 0.35 * rise + 0.15 * burst, rz=0.05 * shiver, ry=0.15 * s(t, 1) * rise)
    cape(p, t, 0.1 * rise + 0.08 * burst, 2)
    return p


def flop_hop(t):
    """Hop: a slow crouch, then it throws itself up with a sweep of the tail and comes down with a belly-flop thud
    that rolls the cape."""
    air = seq(t, [(0, 0), (0.3, -0.8), (0.5, 0.3), (0.6, 1), (0.74, 0.3), (0.84, -1), (0.94, -0.2), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p = {"root_at": (0, 0.1 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.14 * down - 0.03 * up, 1 - 0.2 * down + 0.06 * up, 1 + 0.1 * down)
    add(p, "root", rx=0.14 * seq(t, [(0.3, 0), (0.6, 1), (0.84, -0.5), (1, 0)]))
    add(p, "head", rx=LOOK + 0.1 * up - 0.1 * down)
    cape(p, t, 0.1 * (up + down), 2)
    return p


def pet(t):
    """It pushes its whiskered muzzle into the hand and sighs: the whole body leans in, slow and heavy."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {"root_sc": (1 + 0.03 * lean, 1 - 0.03 * lean, 1)}
    add(p, "root", rz=0.05 * lean)
    add(p, "head", rx=LOOK + 0.1 * lean, rz=0.2 * lean, ry=0.1 * lean)
    cape(p, t, 0.04, 1)
    return p


def carry(t):
    """A slow hitching shuffle with the load held against its chest."""
    p = heave(t, 0.6, 2)
    add(p, "head", rx=0.08)
    return p


def eat(t):
    """Lowers its muzzle over the berry, whiskers working, and takes slow mouthfuls."""
    chew = 0.5 + 0.5 * s(t, 3)
    p = {"root_at": (0, -0.012, -0.02), "prop_berry": "on"}
    cape(p, t, 0.02, 3)
    add(p, "spine", rx=-0.14)
    add(p, "head", rx=-0.35 - 0.1 * chew)
    return p


def drift_off(t):
    """Sleep: settles low onto its tail, the head sinking to its chest, the cape rising and falling like the tide."""
    br = s(t, 1)
    p = {"root_at": (0, -0.03, 0), "root_sc": (1.08 + 0.01 * br, 0.88 + 0.02 * br, 1.06)}
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.45 + 0.03 * br, rz=0.1, ry=0.2)
    cape(p, t, 0.03, 1)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (4.0, True, idle),
        "walk": (1.3, True, walk),
        "run": (0.85, True, run),
        "hop": (1.15, True, flop_hop),
        "carry": (1.3, True, carry),
        "pet": (2.8, True, pet),
        "attack": (1.0, False, bash),
        "ability": (2.0, False, aurora),
        "sleep": (5.0, True, drift_off),
        "eat": (2.4, True, eat),
    }
)

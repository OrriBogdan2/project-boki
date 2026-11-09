"""Each Hunter's weapon hit (OWNER_REVIEW_1103 item 96.4): the short sound your hit makes on a target, one per
weapon so you can hear whose hit landed (docs/AUDIO.md, docs/HUD.md "Hit feedback"). Match.on_damage plays
it through HeroSfx.hit_sound in place of the shared tick. Neve's is her dart hit (gen_sfx_claire.py).

    cd tools && python3 gen_sfx_hits.py      (then: godot --headless --import)

Short (under 0.3 s), a crisp front and a small body, never a boom: the heavy layer (hit_heavy) and the
crit tick sit on top when a hit is empowered or critical. Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail, ring, grains

S.reseed(9604)
P = [1.0, 1.06, 0.95, 1.1]          # each take's pitch


def g(x, k): return np.asarray(x) * k


def archer(i):
    """Lace's arrow: a dry shaft thunk with the red thread's short pluck."""
    p = P[i]
    return mix(g(click(0.003, 3000, 8000, 0.001), 0.6), g(kick(420 * p, 170, 0.12, 0.012, 0.035, 2.2), 0.8),
               g(ring([660 * p, 1320 * p], 0.22, [0.06, 0.03], [0.25, 0.1]), 1.0))


def ashwick(i):
    """Cinder's flame: a soft whump and a sizzle that pops."""
    p = P[i]
    return mix(g(kick(180 * p, 90, 0.16, 0.02, 0.05, 1.6), 0.6), g(crack(0.2, 1800 * p, 7000, 0.05), 0.5),
               g(grains(0.2, 120, 2500, 8000, fall=0.05), 0.35))


def bulwark(i):
    """Albert's barnacle mace: a blunt clank of shell on plate."""
    p = P[i]
    return mix(g(kick(150 * p, 70, 0.2, 0.02, 0.06, 2.6), 0.9), g(crack(0.05, 900, 3500, 0.012), 0.6),
               g(ring([520 * p, 1190 * p, 1870 * p], 0.25, [0.07, 0.05, 0.03], [0.25, 0.15, 0.08]), 1.0))


def dolm(i):
    """Tenzo's stone fist: a knuckle-on-rock crack and a gritty thud."""
    p = P[i]
    return mix(g(kick(200 * p, 80, 0.16, 0.015, 0.045, 2.4), 0.85), g(crack(0.04, 1200, 5000, 0.01), 0.7),
               g(grains(0.16, 160, 1500, 5000, fall=0.03), 0.4))


def dredge(i):
    """Grimble's scrap slug: a dull pock into the body, a little rattle of scrap."""
    p = P[i]
    return mix(g(kick(260 * p, 110, 0.12, 0.01, 0.03, 2.0), 0.8), g(click(0.004, 1500, 5000, 0.0015), 0.6),
               g(grains(0.12, 90, 2000, 6000, fall=0.025), 0.3))


def gunslinger(i):
    """Vex's rotary round: a sharp metal smack and a hot spit."""
    p = P[i]
    return mix(g(click(0.003, 3500, 10000, 0.0008), 0.8), g(kick(320 * p, 140, 0.1, 0.008, 0.025, 2.4), 0.7),
               g(crack(0.08, 2500 * p, 8000, 0.018), 0.35))


def juggernaut(i):
    """Kael's greatsword: the edge biting in, a short steel shing over a heavy body."""
    p = P[i]
    return mix(g(crack(0.06, 1500, 6000, 0.012), 0.7), g(kick(140 * p, 65, 0.2, 0.025, 0.06, 2.4), 0.85),
               g(ring([1480 * p, 2310 * p], 0.25, [0.05, 0.035], [0.18, 0.1]), 1.0))


def mage(i):
    """Sparkle's lightning: a bright zap snap and a short crackle."""
    p = P[i]
    buzz = np.sign(np.sin(2 * np.pi * 180 * p * np.arange(N(0.08)) / S.SR)) * env(N(0.08), 0.001, 0.02)
    return mix(g(click(0.003, 4000, 11000, 0.0008), 0.8), g(hpf(buzz, 400), 0.35),
               g(grains(0.14, 220, 3000, 10000, fall=0.03), 0.45), g(kick(300 * p, 150, 0.08, 0.01, 0.02, 1.5), 0.4))


def ostra(i):
    """Motley's void orb: a hollow pop that drops in pitch."""
    p = P[i]
    return mix(g(kick(700 * p, 160, 0.18, 0.03, 0.05, 1.4), 0.8), g(click(0.003, 1500, 4500, 0.001), 0.5),
               g(at(lpf(noise(0.1), 1200) * env(N(0.1), 0.004, 0.03), 0.01), 0.3))


def tender(i):
    """Meeko's ember: a soft warm puff with a little spark."""
    p = P[i]
    return mix(g(kick(260 * p, 140, 0.14, 0.02, 0.04, 1.2), 0.7), g(tail(0.14, 2200, 0.035), 0.4),
               g(click(0.003, 3000 * p, 7000, 0.001), 0.35))


def thief(i):
    """Sable's bolt: a crisp steel tick and a short cut."""
    p = P[i]
    return mix(g(click(0.002, 5000, 12000, 0.0006), 0.8), g(crack(0.07, 3000 * p, 9000, 0.014), 0.45),
               g(kick(380 * p, 180, 0.08, 0.008, 0.022, 1.8), 0.55), g(ring([2650 * p], 0.15, [0.03], [0.15]), 1.0))


HEAVY = {"bulwark", "dredge", "gunslinger", "juggernaut"}    # the damage carries (content/rules/sfx_levels.json)

if __name__ == '__main__':
    for fn in (archer, ashwick, bulwark, dolm, dredge, gunslinger, juggernaut, mage, ostra, tender, thief):
        S.takes_cat(fn.__name__ + '_hit', fn, 3, 'heavy_impact' if fn.__name__ in HEAVY else 'impact')
        print('wrote', fn.__name__ + '_hit')

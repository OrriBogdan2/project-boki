"""What a hit landed on: the short target layer that sits quietly under the weapon's own hit sound
(Juice.hit; the class comes from HitClass.of, docs/AUDIO.md "Hit by target"). Five sounds, four takes each (a base file and three more):
  hit_armour   a bright crack and a short metal ring       hit_body     a dull fleshy thump
  hit_boki     a soft squeak in a Boki's voice range        hit_monster  a wet crunch with a low growl-thud
  hit_wall     a dull thud of earth or stone, no ring
Under 0.25 s each, levelled to their category (content/rules/sfx_levels.json). Original synthesis.

    cd tools && python3 gen_sfx_targets.py      (then: godot --headless --import)
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, noise, lpf, env, mix, kick, click, crack, ring, tail, grains
from gen_sfx_boki import squeak, vowel

S.reseed(7721)
P = [1.0, 1.07, 0.93, 1.12]      # each take's pitch


def g(x, k): return np.asarray(x) * k


def armour(i):
    p = P[i]
    return mix(g(click(0.003, 3500, 11000, 0.0008), 0.9), g(crack(0.05, 2200 * p, 8000, 0.012), 0.6),
               g(ring([1900 * p, 3100 * p], 0.2, [0.05, 0.03], [0.3, 0.15]), 1.0))


def body(i):
    p = P[i]
    return mix(g(kick(170 * p, 80, 0.16, 0.02, 0.05, 1.6), 0.9), g(tail(0.1, 900, 0.03), 0.4))


def boki(i):
    p = P[i]
    return mix(squeak(780 * p, 0.12, -0.12, 0.03, tail_d=0.07), 0.4 * vowel(420 * p, 380 * p, 0.12, 'uh', 1.4))


def monster(i):
    p = P[i]
    return mix(g(crack(0.07, 500 * p, 3000, 0.02), 0.6), g(kick(130 * p, 55, 0.2, 0.025, 0.07, 2.0), 0.9),
               g(grains(0.12, 90, 600, 2500, fall=0.03), 0.3))


def wall(i):
    p = P[i]
    return mix(g(kick(110 * p, 50, 0.18, 0.02, 0.06, 1.8), 0.9), g(lpf(noise(0.1), 700) * env(N(0.1), 0.002, 0.03), 0.5))


if __name__ == '__main__':
    for fn in (armour, body, boki, monster, wall):
        S.takes_cat('hit_' + fn.__name__, fn, 3, 'boki' if fn is boki else 'impact')
        print('wrote hit_' + fn.__name__)

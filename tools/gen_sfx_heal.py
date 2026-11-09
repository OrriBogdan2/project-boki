"""The heal and shield family (docs/AUDIO.md). Run from tools/: python3 gen_sfx_heal.py

heal_chime   a soft rising chime, two small bells a third apart (scaled by the amount at the call site)
shield_gain  a glassy hum: bowed-glass partials swelling in and shimmering
armor_refill a plate click, then a short metal ring
shield_pop   a bubble pop with a falling glass tick
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(5521)


def heal_chime(i):
    f = 880 * (1.0 + (0 if i == 0 else S.rng.uniform(-0.02, 0.02)))
    low = S.chime(f, 0.45, 0.22, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1)))
    high = S.chime(f * 1.26, 0.6, 0.3, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1)))
    return lpf(mix(low * 0.8, at(high, 0.07)), 5200)


def shield_gain(i):
    d = 0.7; t = T(d)
    glass = sum(g * np.sin(2 * np.pi * f * t * (1.0 + 0.002 * i) + k) for k, (f, g) in enumerate(((620, 1.0), (1247, 0.5), (1871, 0.28), (2490, 0.14))))
    shimmer = 1.0 + 0.25 * np.sin(2 * np.pi * 9.0 * t)
    return lpf(glass * shimmer * S.shape(d, 0.18, 0.1, 0.42), 4800)


def armor_refill(i):
    plate = mix(S.click(0.006, 1800, 6500, 0.002) * 1.4, S.kick(220, 110, 0.06, 0.02, 0.025) * 0.5)
    ring = S.ring([1180 + 40 * i, 1760, 2650], 0.4, [0.12, 0.08, 0.04], [0.7, 0.35, 0.15])
    return lpf(mix(plate, at(ring, 0.03)), 6000)


def shield_pop(i):
    pop = S.sweep(900, 220, 0.09) * env(N(0.09), 0.001, 0.025)
    puff = bpf(noise(0.06), 1500, 6000) * env(N(0.06), 0.0005, 0.015) * 0.6
    tick = at(S.chime(1650 - 60 * i, 0.18, 0.06, ((1.0, 1.0), (2.76, 0.4))), 0.02) * 0.35
    return lpf(mix(pop, puff, tick), 6500)


def main():
    S.takes_cat('heal_chime', heal_chime, 2, 'cast')
    S.takes_cat('shield_gain', shield_gain, 2, 'cast')
    S.takes_cat('armor_refill', armor_refill, 2, 'cast')
    S.takes_cat('shield_pop', shield_pop, 2, 'cast')


if __name__ == '__main__':
    main()

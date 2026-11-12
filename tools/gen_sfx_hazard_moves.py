"""The two ice footing sounds (scripts/match/hazard_move_sfx.gd). Run from tools/. Original synthesis.

  hazard_skid   (3 takes) boots losing their grip on ice: a short bright scrape with a low rub under it
  hazard_catch  (3 takes) footing coming back: a small dry tick of boots biting, one squeak in it
The water sounds (splash, swim, drip) are the farm's own set (HomeWater).
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, bpf, env, mix, at, crack, shape, soft_in

S.reseed(6112)


def skid(_i):
    d = 0.45
    wob = 0.65 + 0.35 * np.sin(2 * np.pi * (22 + 6 * S.rng.random()) * T(d))
    scrape = bpf(noise(d), 2400, 7800) * shape(d, 0.02, 0.14, 0.26) * wob * 0.7
    rub = bpf(noise(d), 300, 1100) * shape(d, 0.03, 0.1, 0.28) * 0.35
    return soft_in(mix(scrape, rub), 1.0)


def catch(_i):
    d = 0.22
    tick = crack(0.06, 1500, 7000, 0.006) * 1.1
    f = 2300 + 500 * S.rng.random()
    squeak = np.sin(2 * np.pi * f * T(d)) * env(N(d), 0.004, 0.05) * 0.12
    return soft_in(mix(tick, at(squeak, 0.01)), 0.5)


def build():
    S.takes_cat('hazard_skid', skid, 3, 'dash')
    S.takes_cat('hazard_catch', catch, 3, 'impact')


if __name__ == '__main__':
    build()
    print('gen_sfx_hazard_moves: done')

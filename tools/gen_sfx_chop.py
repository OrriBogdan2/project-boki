"""Chop and mine sounds (docs/AUDIO.md): the farm's axe and pickaxe work. Run from tools/.

  axe_bite     the blade biting into wood: a dull knock with a short woody ring (3 takes)
  trunk_creak  the trunk straining; the game plays it pitched higher and louder on the last hits
  tree_down    the felled tree: a whoosh of air, then the thud of the trunk landing
  pick_strike  the pick head on stone: a sharp tick, a ring and a low knock (3 takes)
  rock_crack   the stone splitting; the game plays it lower and louder as the boulder weakens
  rock_break   the boulder giving way: a crack, a rumble and rubble settling
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(3302)


def axe(i):
    d = 0.22
    knock = S.kick(190 - 12 * i, 80, d, drop=0.025, decay=0.05, drive=1.6)
    bite = S.crack(0.05, 500 + 120 * i, 3200, 0.012)
    ring = S.chime(520 + 70 * i, 0.16, 0.035, partials=((1.0, 1.0), (2.4, 0.3)))
    return mix(knock, 0.9 * bite, 0.25 * ring)


def creak():
    return S.creak(0.7, 130, 210, roughness=0.5, bright=1800)


def tree_down():
    whoosh = S.hiss(0.6, 300, 1400, a=0.25, decay=0.3) * np.linspace(0.4, 1.0, N(0.6))
    land = mix(S.kick(120, 42, 0.45, drop=0.06, decay=0.14, drive=2.2), S.tail(0.4, 500, 0.12),
               0.5 * S.grains(0.3, 60, 800, 3500, fall=0.08))
    return mix(0.7 * whoosh, at(land, 0.55))


def pick(i):
    d = 0.2
    tick = S.crack(0.03, 2500, 8000, 0.006)
    ring = S.chime(1400 + 160 * i, d, 0.05, partials=((1.0, 1.0), (2.7, 0.4), (4.1, 0.15)))
    return mix(tick, 0.5 * ring, 0.8 * S.kick(150, 70, d, drop=0.02, decay=0.04, drive=1.8))


def split():
    d = 0.5
    snap = S.crack(0.25, 800, 6000, 0.05)
    rub = S.grains(d, 90, 1500, 6500, fall=0.15)
    return mix(snap, 0.7 * rub, 0.5 * S.kick(110, 55, d, drop=0.04, decay=0.1, drive=1.5))


def rock_break():
    d = 0.9
    return mix(S.crack(0.2, 600, 5000, 0.05), S.kick(90, 36, 0.6, drop=0.07, decay=0.2, drive=2.4),
               S.tail(0.8, 700, 0.3, delay=0.03) * 0.6, 0.8 * S.grains(d, 140, 1000, 6000, fall=0.3))


S.takes_cat('axe_bite', axe, 2, 'impact')
S.save_cat('trunk_creak', creak(), 'cast')
S.save_cat('tree_down', tree_down(), 'impact')
S.takes_cat('pick_strike', pick, 2, 'impact')
S.save_cat('rock_crack', split(), 'cast')
S.save_cat('rock_break', rock_break(), 'impact')
print('chop and mine sounds written')

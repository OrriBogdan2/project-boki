"""The Blight tide's sounds (docs/decisions/0023-heartspark.md; scripts/match/tide_sfx.gd). Run from tools/.

The wall of Blight closing on the Heart, heard before it is seen. All our own synthesis, low and dark so the
Heart's bright glass (gen_sfx_heart.py) and the Ways Out calls read over it:
  tide_onset   cast  the tide starts: a rising sub swell under a widening wash, ending on one deep thud (3.2 s)
  tide_rumble  loop  the wall itself, placed on the nearest point of the ring and carrying 70 m: a beating
                     sub drone with a grumbling mid wash; the distance roll-off makes it rise as it nears you
  tide_warn    cast  the ring starts a new close: two short falling horn notes a tritone apart over a thud (0.9 s)
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, mix, at, lpf, bpf

S.reseed(2411)


def onset():
    d = 3.2
    swell = (S.sweep(34.0, 62.0, d) + 0.6 * S.sweep(68.0, 124.0, d)) * S.shape(d, 2.4, 0.2, 0.6)
    wash = bpf(S.noise(d), 90, 900) * S.shape(d, 2.2, 0.2, 0.8) * 0.5
    thud = S.kick(90.0, 38.0, 0.9, drop=0.06, decay=0.22, drive=1.4)
    return mix(swell * 0.9, wash, at(thud * 1.3, 2.3))


def rumble():
    d = 4.0; t = T(d)                      # whole cycles in 4 s, so the loop is seamless
    drone = sum(g * np.sin(2 * np.pi * f * t) for f, g in [(36.0, 1.0), (54.0, 0.7), (72.25, 0.45), (108.0, 0.2)])
    beat = 0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t)
    grumble = lpf(S.noise(d), 220) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.75 * t + 1.0)) * 2.0
    return drone * beat + grumble


def horn(f0, f1, d=0.45):
    tone = S.sweep(f0, f1, d) + 0.5 * S.sweep(2 * f0, 2 * f1, d)
    return lpf(tone, 900) * S.shape(d, 0.04, 0.12, 0.28)


def warn():
    notes = mix(horn(196.0, 185.0), at(horn(139.0, 131.0), 0.4))
    thud = S.kick(80.0, 44.0, 0.3, drop=0.03, decay=0.09, drive=1.5) * S.shape(0.3, 0.001, 0.12, 0.17)
    return mix(notes * 0.9, thud * 0.9)


def main():
    S.save_cat('tide_onset', onset(), 'cast')
    S.save_loop('tide_rumble', rumble(), 'loop')
    S.save_cat('tide_warn', warn(), 'cast')


if __name__ == '__main__':
    main()

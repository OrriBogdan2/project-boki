"""Boki wisp sounds (DECISIONS 2026-11-09 Soul-linked Boki, docs/AUDIO.md). Run from tools/.

A Boki wisp chirps (a bright little squeak, higher for a small body) and a Hunter Wisp hums (low, round:
tools/gen_wisp_sfx.py), so round = Hunter and critter = Boki read by ear as well as by eye.
  wisp_chirp_<size>  the Boki's own voice, small / medium / large, 3 takes (Sfx pitches it per individual)
  wisp_bloom         the wisp opening into the full Boki: a rising shimmer and a soft pop
  wisp_shrink        the Boki folding back into its wisp: a falling shimmer and a tick
  wisp_ready         the cooldown is over: two soft bell notes
  wisp_grab          a thief catches a loose wisp: a quick snatch and a tether twang
Call sites: KinSummon (popped, tick); wisp_grab waits for the steal rule (no code path yet).
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf
from gen_sfx_boki import squeak, soft, j

S.reseed(5411)
CHIRP_HZ = {'small': 2300, 'medium': 1600, 'large': 1050}


def chirp(size):
    def make(i):
        f = CHIRP_HZ[size] * j(i, 0.05)
        up = squeak(f * 0.9, 0.05, 0.2, 0.01)
        return soft(mix(up, at(squeak(f * 1.25, 0.07, 0.1, 0.02), 0.055)), 7000)
    return make


def shimmer(f0, f1, d, bright=1.0):
    """Three slightly detuned sines gliding f0 -> f1: the glow breathing in or out."""
    x = sum(S.sweep(f0 * k, f1 * k, d) * g for k, g in ((1.0, 1.0), (1.007, 0.7), (1.51, 0.3 * bright)))
    return x * env(N(d), 0.02, d * 0.5)


def bloom(i):
    pop = S.sweep(520, 260, 0.08) * env(N(0.08), 0.002, 0.03)
    return soft(mix(shimmer(500, 1500, 0.3), at(pop, 0.2) * 0.8, at(S.chime(1900, 0.25, 0.1), 0.2) * 0.25))


def shrink(i):
    tick = S.sweep(1400, 2200, 0.04) * env(N(0.04), 0.002, 0.012)
    return soft(mix(shimmer(1500, 520, 0.3), at(tick, 0.25) * 0.5))


def ready(i):
    return mix(S.chime(1320, 0.5, 0.22), at(S.chime(1760, 0.6, 0.28), 0.12) * 0.9) * 0.8


def grab(i):
    snatch = S.sweep(500, 1900, 0.12) * env(N(0.12), 0.004, 0.06)
    twang = S.fm(740, 1.5, 3.0, 0.3, 0.12)
    return hpf(mix(snatch, at(twang, 0.1) * 0.6), 200)


def main():
    for size in CHIRP_HZ:
        S.takes_cat('wisp_chirp_' + size, chirp(size), 3, 'boki')
    S.takes_cat('wisp_bloom', bloom, 0, 'boki')
    S.takes_cat('wisp_shrink', shrink, 0, 'boki')
    S.takes_cat('wisp_ready', ready, 0, 'boki')
    S.takes_cat('wisp_grab', grab, 0, 'boki')


if __name__ == '__main__':
    main()

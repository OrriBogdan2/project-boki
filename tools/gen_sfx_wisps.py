"""Boki wisp sounds (DECISIONS 2026-11-09 Soul-linked Boki, docs/AUDIO.md). Run from tools/.

A Boki wisp chirps (a bright little squeak, higher for a small body) and a Hunter Wisp hums (low, round:
tools/gen_wisp_sfx.py), so round = Hunter and critter = Boki read by ear as well as by eye.
  wisp_chirp_<size>  the Boki's own voice, small / medium / large, 3 takes (Sfx pitches it per individual)
  summon_burst_<size>   the wisp opening into the full Boki: a rising shimmer, a soft pop and a low body
  summon_end_<size>     the summon ending, the Boki folding back into its wisp: a falling shimmer and a tick
  summon_killed_<size>  a killed summon: a faint thin sigh and a sparkle drifting away, the wisp leaving
  (small / medium / large by the body: higher and shorter for a small one, lower, longer and weightier for a
  large one; the low body keeps it audible through the far muffle, "reach" 35 m so a rival's carries 25 m)
  wisp_ready         the cooldown is over: two soft bell notes
  wisp_grab          a thief catches a loose wisp: a quick snatch and a tether twang
Call sites: KinSummon (render, popped, tick); wisp_grab waits for the steal rule (no code path yet).
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


# body size -> (pitch factor, length factor, low body Hz, body gain)
BODY = {'small': (1.5, 0.8, 190, 0.35), 'medium': (1.0, 1.0, 120, 0.55), 'large': (0.66, 1.3, 75, 0.85)}


def body(size, hz_to, d, gain):
    """The low thump under a summon cue: what still carries through the far muffle."""
    hz = BODY[size][2]
    return S.sweep(hz * hz_to, hz, d) * env(N(d), 0.006, d * 0.7) * gain * BODY[size][3]


def burst(size):
    k, ds = BODY[size][:2]

    def make(i):
        d = 0.3 * ds
        pop = S.sweep(520 * k, 260 * k, 0.08 * ds) * env(N(0.08 * ds), 0.002, 0.03)
        spark = S.chime(1900 * k, 0.25, 0.1)
        return soft(mix(shimmer(500 * k * j(i, 0.04), 1500 * k, d), at(pop, 0.2 * ds) * 0.8,
                        at(spark, 0.2 * ds) * 0.25, at(body(size, 1.6, 0.2 * ds, 1.0), 0.18 * ds)))
    return make


def end(size):
    k, ds = BODY[size][:2]

    def make(i):
        d = 0.3 * ds
        tick = S.sweep(1400 * k, 2200 * k, 0.04) * env(N(0.04), 0.002, 0.012)
        return soft(mix(shimmer(1500 * k * j(i, 0.04), 520 * k, d), at(tick, 0.25 * ds) * 0.5,
                        body(size, 1.3, 0.16 * ds, 0.6)))
    return make


def killed(size):
    k, ds = BODY[size][:2]

    def make(i):
        d = 0.6 * ds
        sigh = squeak(1100 * k * j(i, 0.05), d, -0.25, 0.03, 0.05, 0.04, d * 0.9) * 0.5
        away = S.sweep(900 * k, 2000 * k, 0.5 * ds) * env(N(0.5 * ds), 0.05, 0.4 * ds) * 0.18
        return soft(mix(sigh, at(away, 0.1 * ds), body(size, 1.0, 0.3 * ds, 0.5)), 4200)
    return make


def ready(i):
    return mix(S.chime(1320, 0.5, 0.22), at(S.chime(1760, 0.6, 0.28), 0.12) * 0.9) * 0.8


def grab(i):
    snatch = S.sweep(500, 1900, 0.12) * env(N(0.12), 0.004, 0.06)
    twang = S.fm(740, 1.5, 3.0, 0.3, 0.12)
    return hpf(mix(snatch, at(twang, 0.1) * 0.6), 200)


def main():
    for size in CHIRP_HZ:
        S.takes_cat('wisp_chirp_' + size, chirp(size), 3, 'boki')
    for size in BODY:
        S.takes_cat('summon_burst_' + size, burst(size), 2, 'boki')
        S.takes_cat('summon_end_' + size, end(size), 2, 'boki')
        S.takes_cat('summon_killed_' + size, killed(size), 2, 'boki')
    S.takes_cat('wisp_ready', ready, 0, 'boki')
    S.takes_cat('wisp_grab', grab, 0, 'boki')


if __name__ == '__main__':
    main()

"""Glint Fishing's sounds (scripts/home/glint_sfx.gd, docs/AUDIO.md), our own synthesis. Run from tools/.

  glint_cast        a line whip: a fast airy swish with a thin rising whistle
  glint_plop        the bobber landing: a low water drop under a small splash of noise
  glint_water       loop, soft lapping water for the wait (Ambience bus, quiet and dull so the bite stands out)
  glint_bite        the cue to press: a sharp bright double tick over a high, ringing tug; most of its
                    energy sits at 2-6 kHz, where the garden beds have little
  glint_reel        loop, a reel ratchet: even dry clicks, seamless
  glint_catch_small / _medium / _large   the catch sting: one, two or three rising bells over a splash
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf

S.reseed(4217)


def cast():
    d = 0.4
    swish = bpf(S.noise(d), 1200, 6500) * S.shape(d, 0.12, 0.0, 0.25) * 0.8
    whistle = S.sweep(900.0, 2600.0, d) * S.shape(d, 0.1, 0.0, 0.25) * 0.15
    return mix(swish, whistle)


def plop(i):
    d = 0.45
    drop = S.sweep(520.0 + 40 * i, 210.0, 0.18) * env(N(0.18), 0.002, 0.06)
    splash = bpf(S.noise(0.3), 500, 4500) * env(N(0.3), 0.003, 0.08) * 0.5
    return S.pad(mix(drop, at(splash, 0.01)), d)


def water():
    d = 4.0                                  # whole cycles of the 0.5 Hz lap, so it loops seamlessly
    t = T(d)
    bed = lpf(S.noise(d), 700) * (0.55 + 0.45 * np.sin(2 * np.pi * 0.5 * t))
    glints = bpf(S.noise(d), 1500, 3500) * 0.12 * (0.5 + 0.5 * np.sin(2 * np.pi * 1.0 * t + 1.0)) ** 3
    return bed + glints


def bite(i):
    tick = S.click(0.006, 3000, 8000, 0.003)
    ticks = mix(tick * 1.4, at(tick * 1.1, 0.07))
    ring = S.chime(2349.0, 0.35, 0.12, ((1.0, 1.0), (1.5, 0.5), (2.0, 0.35)))
    tug = bpf(S.noise(0.12), 2000, 6000) * env(N(0.12), 0.002, 0.04) * 0.6
    return S.pad(mix(ticks, at(ring, 0.01) * 0.8, tug), 0.4)


def reel():
    d = 0.5                                  # four clicks a half second
    out = np.zeros(N(d))
    click = mix(S.click(0.006, 1800, 5500, 0.004), lpf(S.noise(0.02), 900) * env(N(0.02), 0.0005, 0.006) * 0.5)
    for k in range(4):
        out = mix(out, at(click * (1.0 if k % 2 == 0 else 0.8), 0.125 * k))
    return S.pad(out, d)[:N(d)]


def catch(notes):
    d = 0.5 + 0.18 * len(notes)
    splash = bpf(S.noise(0.35), 600, 5000) * env(N(0.35), 0.004, 0.09) * 0.4
    bells = [at(S.chime(f, 0.9, 0.4), 0.11 * k) for k, f in enumerate(notes)]
    return S.pad(mix(splash, *bells), d)


def main():
    S.takes_cat('glint_cast', lambda i: cast(), 2, 'ui')
    S.takes_cat('glint_plop', plop, 2, 'ui')
    S.save_loop('glint_water', water(), 'loop')
    S.takes_cat('glint_bite', bite, 2, 'signature')
    S.save_loop('glint_reel', reel(), 'loop', 0.02)
    S.takes_cat('glint_catch_small', lambda i: catch((784.0,)), 0, 'boki')
    S.takes_cat('glint_catch_medium', lambda i: catch((659.0, 880.0)), 0, 'boki')
    S.takes_cat('glint_catch_large', lambda i: catch((523.0, 659.0, 1047.0)), 0, 'boki')


if __name__ == '__main__':
    main()

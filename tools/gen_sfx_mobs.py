"""Monster sounds (docs/AUDIO.md): a death cue per kind in that kind's voice family (the v_<kind> sounds of
tools/gen_sfx.py), plus the stagger pair for elites and bosses. Run from tools/: python3 gen_sfx_mobs.py

mdie_<kind>: the creature's own voice falling away, then what it is made of letting go (skitter: a last
chitter; spitter: a gurgle and splat; brute: a groan and a slump; bomber: a hiss that fizzles out; sentinel:
a hum cracking into rubble; glimmer: a glass chime breaking; warden: a long roar sinking into rumble).
mstag_open: a small bright tick when a stagger window opens. mstag_hit: the landing, a hard crack over a
low thump with a glassy ring.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise, kick, click, crack, sub, tail

S.reseed(6117)


def skitter(i):
    clicks = [at(click(0.02, 900, 3500, 0.006), 0.045 * k * (1 + 0.1 * i)) for k in range(5)]
    return mix(S.voice(0.22, 330 + 20 * i, 140, 'eh', 0.2, 0.5, 0.0, 1.2, 0.01), *clicks) * 0.8


def spitter(i):
    d = 0.5; gur = S.voice(d, 150 + 8 * i, 80, 'uh', 0.35, 0.3, 0.0, 1.0, 0.03) * (0.55 + 0.45 * np.sin(2 * np.pi * (18 + 3 * i) * T(d)))
    return mix(gur, at(bpf(noise(0.18), 300, 2200) * env(N(0.18), 0.003, 0.05), 0.3))


def brute(i):
    d = 0.7
    return mix(S.voice(d, 110 + 6 * i, 52, 'oh', 0.15, 0.6, 0.0, 0.85, 0.04, 0.3), at(kick(110, 45, 0.3, 0.05, 0.1) * 0.9, 0.42), at(tail(0.3, 500, 0.1), 0.42) * 0.5)


def bomber(i):
    d = 0.6; sw = S.sweep(420 + 25 * i, 120, d, 'sin', 0.6) * env(N(d), 0.01, 0.2) * 0.4
    return mix(sw, S.hiss(d, 700, 4000, 0.02, 0.22) * 0.7, at(click(0.01, 600, 2500, 0.004), 0.5))


def sentinel(i):
    return mix(S.voice(0.5, 90 + 5 * i, 62, 'uh', 0.1, 0.1, 0.0, 0.8, 0.03, 0.25) * 0.8, at(crack(0.12, 300, 3000, 0.02), 0.2) * 0.9,
               at(S.rattle(0.35, 60, 400, 2200, 0.5, 0.12), 0.25) * 0.6, at(kick(100, 50, 0.3, 0.05, 0.09), 0.3) * 0.7)


def glimmer(i):
    f = (880, 988, 784)[i % 3]
    return mix(S.chime(f, 0.9, 0.3), at(S.chime(f * 1.5, 0.7, 0.22), 0.06) * 0.5, at(S.rattle(0.3, 50, 3500, 8000, 0.5, 0.1), 0.1) * 0.5)


def warden(i):
    return mix(S.voice(1.1, 82 + 4 * i, 38, 'oh', 0.12, 0.7, 0.0, 0.8, 0.12, 0.5), at(kick(80, 32, 0.6, 0.08, 0.2), 0.7) * 0.9, at(tail(0.7, 350, 0.25), 0.7) * 0.6)


def stag_open(i):
    return mix(S.chime(1568 + 40 * i, 0.22, 0.05), click(0.006, 3000, 9000, 0.002) * 0.6)


def stag_hit(i):
    return mix(crack(0.12, 1500, 7000, 0.02) * 1.2, kick(160, 55, 0.35, 0.04, 0.12) * 1.1, S.chime(659 + 30 * i, 0.5, 0.12) * 0.5, at(tail(0.3, 900, 0.08), 0.02) * 0.4)


def main():
    for kind, fn in [('skitter', skitter), ('spitter', spitter), ('brute', brute), ('bomber', bomber),
                     ('sentinel', sentinel), ('glimmer', glimmer), ('warden', warden)]:
        S.takes_cat('mdie_' + kind, fn, 3, 'grunt')
    S.takes_cat('mstag_open', stag_open, 2, 'ui')
    S.takes_cat('mstag_hit', stag_hit, 2, 'impact')


if __name__ == '__main__':
    main()
